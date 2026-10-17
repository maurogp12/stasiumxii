#!/usr/bin/env python3
"""Crosshaven as a planned Wakfu-like town on the tile grid (round M3).

Replaces every painted-plate mask with a street plan in data:

1. The ring: the approved octagon snapped to the kit's wall directions
   (screen slope 0 / +-0.5), centred on the plate with an even margin.
   Every layout point (gates, towers, water gates, plaza, building spots,
   the old river) moves with it.
2. data/world/crosshaven_city/streetplan.json (written once, then read;
   --replan writes it again): plaza (tile rect), avenues gate -> plaza (4 wide,
   routed along the two iso axes), ring road (3 wide, 1 tile inside the wall
   band), side streets (a grid on the iso axes, blocks about 8x6), the river
   (a smooth channel through both water tunnels, out to the map edges),
   outside dirt roads (3 wide, gate to map edge), bridges where a road
   crosses the river.
3. tilemap.json: ground from the plan, the ring pieces, and the town:
   landmarks with paved forecourts (cathedral and bank face the plaza from
   the north, the town hall from the west, the castle by the N avenue), the
   mill on the river, workshops in the W quarter, the player plots with
   fenced yards, NPC houses filling the blocks (door on a street, a tile of
   grass round each), back yards (trees, crates), lamps, plaza dressing,
   trees along the ring road and in clumps outside, gardens in the east.

Usage: python3 city_plan.py <repo root> [--kit <kit.json>] [--replan]
"""
import json
import math
import os
import random
import sys

import numpy as np
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from layout_to_tilemap import Lattice, in_poly, seg_dist  # noqa: E402

STALLS = ["stall_fruit", "stall_cloth", "stall_bakery"]
WORKSHOPS = ["workshop_smithy", "workshop_forge", "workshop_potter", "workshop_weaver", "workshop_carpenter", "workshop_tailor"]
TREES = ["tree_oak", "tree_elm", "tree_maple", "tree_cherry"]
BUSHES = ["bush_green", "bush_pink", "bush_yellow"]
FLOWERS = ["flowers_blue_purple", "flowers_red_white"]


# ------------------------------------------------------------------ ring

def snap_poly(pl):
    """Each edge to slope 0 / +-0.5 through its midpoint; runs that snap alike
    merge (the longer edge's line wins); corners where the lines meet."""
    edges = []
    for p0, p1 in zip(pl, pl[1:] + pl[:1]):
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        sl = 0.0 if abs(dx) < 1e-6 else dy / dx
        t = min((0.0, 0.5, -0.5), key=lambda c: abs(math.atan(sl) - math.atan(c)))
        ln = math.hypot(dx, dy)
        mid = ((p0[0] + p1[0]) / 2.0, (p0[1] + p1[1]) / 2.0)
        if edges and edges[-1][0] == t:
            _, m0, l0 = edges[-1]
            edges[-1] = (t, m0 if l0 >= ln else mid, max(l0, ln))
        else:
            edges.append((t, mid, ln))
    if len(edges) > 1 and edges[0][0] == edges[-1][0]:
        t, m0, l0 = edges[0]
        _, m1, l1 = edges.pop()
        edges[0] = (t, m0 if l0 >= l1 else m1, max(l0, l1))
    verts = []
    for (t1, m1, _), (t2, m2, _) in zip(edges, edges[1:] + edges[:1]):
        x = (m2[1] - m1[1] + t1 * m1[0] - t2 * m2[0]) / (t1 - t2)
        verts.append((x, m1[1] + t1 * (x - m1[0])))
    return [verts[-1]] + verts[:-1], [e[0] for e in edges]


def chaikin(pts, n=3):
    for _ in range(n):
        out = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
            out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        out.append(pts[-1])
        pts = out
    return pts


def main():
    root = sys.argv[1]
    kit_path = sys.argv[sys.argv.index("--kit") + 1] if "--kit" in sys.argv else os.path.join(
        root, "art", "world", "crosshaven_tiles", "kit_a", "kit.json")
    data = os.path.join(root, "data", "world", "crosshaven_city")
    city = json.load(open(os.path.join(data, "city.json")))
    layers = json.load(open(os.path.join(data, "layers.json")))["layers"]
    cfg = json.load(open(os.path.join(HERE, "ring_v4.json")))
    kit = json.load(open(kit_path))
    pk = kit["pieces"]
    hero_world = float(cfg.get("hero_world_px", 62.7))
    L = Lattice(city, kit, hero_world)
    W, H = L.w, L.h
    PW, PH = L.size
    rng = random.Random(33)
    k = L.tw / float(kit["tile_px"][0])

    # ---- 1. the ring, snapped, centred and scaled; T moves every layout point
    poly0 = [tuple(p) for p in city["wall_polygon"]]
    poly, slopes = snap_poly(poly0)
    mg = float(cfg.get("tile_ring_margin_px", 300.0))
    xs, ys = [p[0] for p in poly], [p[1] for p in poly]
    bc = ((min(xs) + max(xs)) / 2.0, (min(ys) + max(ys)) / 2.0)
    f_ = min((PW - 2 * mg) / (max(xs) - min(xs)), (PH - mg) / (max(ys) - min(ys)), 1.0)
    pc = (PW / 2.0, PH / 2.0)

    def T(p):
        return (pc[0] + (p[0] - bc[0]) * f_, pc[1] + (p[1] - bc[1]) * f_)

    poly = [T(p) for p in poly]
    edges = list(zip(poly, poly[1:] + poly[:1]))

    def tile_f(p):
        return L.world_to_tile_f(L.plate_to_world(p))

    def tile_of(p):
        x, y = tile_f(p)
        return int(round(x)), int(round(y))

    def plate_of(c):
        return L.world_to_plate(L.tile_to_world(c))

    tpoly = [tile_f(p) for p in poly]
    tedges = list(zip(tpoly, tpoly[1:] + tpoly[:1]))

    def project(pt):
        best = None
        for i, (a, b) in enumerate(edges):
            vx, vy = b[0] - a[0], b[1] - a[1]
            L2 = vx * vx + vy * vy
            u = max(0.0, min(1.0, ((pt[0] - a[0]) * vx + (pt[1] - a[1]) * vy) / L2))
            q = (a[0] + u * vx, a[1] + u * vy)
            d = math.dist(q, pt)
            if best is None or d < best[0]:
                best = (d, i, u * math.sqrt(L2), q)
        return best[1], best[2], best[3]

    # ---- grids (numpy [y, x])
    yy, xx = np.mgrid[0:H, 0:W]
    in_rect = np.zeros((H, W), bool)
    inside = np.zeros((H, W), bool)
    dist_ring = np.full((H, W), 99.0)
    for y in range(H):
        for x in range(W):
            wp = L.tile_to_world((x, y))
            if not L.in_rect(wp):
                continue
            in_rect[y, x] = True
            inside[y, x] = in_poly((x, y), tpoly)
            dist_ring[y, x] = min(seg_dist((x, y), a, b) for a, b in tedges)
    band = float(cfg.get("tile_wall_band_tiles", 1.6))
    wall_band = in_rect & (dist_ring <= band)

    # ---- gates (layout arches projected onto the ring) and their passages
    gates = []
    for g in city["gates"]:
        ei, u, q = project(T(tuple(g["arch"])))
        sl = slopes[ei]
        a_t = tile_f(q)
        # the passage runs across the wall: along y for the x-axis (+0.5)
        # edges, along x for the y-axis (-0.5) edges, along the diagonal for flat ones
        if sl > 0:
            d = (0, 1)
        elif sl < 0:
            d = (1, 0)
        else:
            d = (1, 1)
        # inward: the side the polygon's centre is on
        ctr = (sum(p[0] for p in tpoly) / len(tpoly), sum(p[1] for p in tpoly) / len(tpoly))
        if (ctr[0] - a_t[0]) * d[0] + (ctr[1] - a_t[1]) * d[1] < 0:
            d = (-d[0], -d[1])
        gates.append({"id": g["id"], "edge": ei, "slope": sl, "q": q, "at": a_t, "in": d})

    # ---- 2. the street plan (data; written once unless --replan)
    plan_path = os.path.join(data, "streetplan.json")
    if os.path.exists(plan_path) and "--replan" not in sys.argv:
        plan = json.load(open(plan_path))
    else:
        plan = make_plan(cfg, city, T, tile_f, tile_of, gates, tpoly, inside, in_rect, wall_band, dist_ring, band, W, H, L)
        json.dump(plan, open(plan_path, "w"), indent=1)

    # ---- 3. rasterise the plan
    terr = np.full((H, W), "g", dtype="<U1")
    terr[~in_rect] = "."
    road_in = np.zeros((H, W), bool)
    road_out = np.zeros((H, W), bool)
    paved = np.zeros((H, W), bool)
    water = np.zeros((H, W), bool)

    def stamp(mask, cells, width):
        lo = -(int(width) - 1) // 2
        for (x, y) in cells:
            for i in range(lo, lo + int(width)):
                for j in range(lo, lo + int(width)):
                    if 0 <= x + i < W and 0 <= y + j < H:
                        mask[y + j, x + i] = True

    def line_cells(pts):
        out = []
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = max(abs(x1 - x0), abs(y1 - y0), 1)
            for s in range(int(n) + 1):
                c = (int(round(x0 + (x1 - x0) * s / n)), int(round(y0 + (y1 - y0) * s / n)))
                if not out or out[-1] != c:
                    out.append(c)
        return out

    px0, py0, px1, py1 = plan["plaza"]
    paved[py0:py1 + 1, px0:px1 + 1] = True
    for av in plan["avenues"]:
        stamp(road_in, line_cells([tuple(p) for p in av["pts"]]), av["width"])
    rr = plan["ring_road"]
    road_in |= inside & (dist_ring >= rr["from"]) & (dist_ring < rr["to"])
    keep_free = np.zeros((H, W), bool)
    for rs in plan.get("reserved", []):
        x0, y0, x1, y1 = rs["rect"]
        keep_free[max(0, y0):y1 + 1, max(0, x0):x1 + 1] = True
    for st in plan["streets"]:
        m = np.zeros((H, W), bool)
        stamp(m, line_cells([tuple(p) for p in st["pts"]]), st["width"])
        road_in |= m & inside & (dist_ring >= rr["from"]) & ~keep_free
    for rd in plan["outside_roads"]:
        stamp(road_out, line_cells([tuple(p) for p in rd["pts"]]), rd["width"])
    road_out &= ~inside
    rv = plan["river"]
    pts = [tuple(p) for p in rv["pts"]]
    rw = float(rv["width"]) / 2.0
    for y in range(H):
        for x in range(W):
            if in_rect[y, x]:
                d = min(seg_dist((x, y), a, b) for a, b in zip(pts, pts[1:]))
                if d <= rw:
                    water[y, x] = True
    road_in &= inside & ~wall_band
    paved &= inside & ~wall_band
    terr[road_out & in_rect] = "d"
    terr[road_in] = "c"
    terr[paved] = "p"
    # gate passages: through the wall band, cobble in, dirt out
    gate_cells = {}
    gates_out = []
    for g in gates:
        # every cell within 1.6 tiles of the passage line (4-connected for
        # the diagonal passages of the flat edges too), 7 tiles each way
        cells = []
        a = g["at"]
        dl = math.hypot(*g["in"])
        ux, uy = g["in"][0] / dl, g["in"][1] / dl
        pa = (a[0] - ux * 7.0, a[1] - uy * 7.0)
        pb = (a[0] + ux * 7.0, a[1] + uy * 7.0)
        for y in range(int(min(pa[1], pb[1])) - 3, int(max(pa[1], pb[1])) + 4):
            for x in range(int(min(pa[0], pb[0])) - 3, int(max(pa[0], pb[0])) + 4):
                if 0 <= x < W and 0 <= y < H and seg_dist((x, y), pa, pb) <= 1.6:
                    cells.append((x, y))
        cells.sort(key=lambda c: (c[0] - pa[0]) * ux + (c[1] - pa[1]) * uy)
        for c in cells:
            gate_cells[c] = g["id"]
            terr[c[1], c[0]] = "c" if inside[c[1], c[0]] else "d"
        ins = [list(c) for c in cells if inside[c[1], c[0]] and not wall_band[c[1], c[0]]]
        outs = [list(c) for c in cells if not inside[c[1], c[0]] and not wall_band[c[1], c[0]]]
        gates_out.append({"id": g["id"], "arch_cell": list(tile_of(g["q"])), "cells": [list(c) for c in cells],
                          "inside": ins, "outside": outs, "arch_plate": [round(g["q"][0], 1), round(g["q"][1], 1)]})
    terr[water] = "w"
    # bridges: road over the river
    road_any = road_in | road_out | paved
    for c in gate_cells:
        road_any[c[1], c[0]] = True
    cross = water & road_any
    walk_over = [(int(x), int(y)) for y, x in zip(*np.nonzero(cross))]
    wall_cells = [(int(x), int(y)) for y, x in zip(*np.nonzero(wall_band)) if (int(x), int(y)) not in gate_cells]

    # ---- pieces
    pieces = []
    occ = np.zeros((H, W), bool)       # blocking footprints
    halo = np.zeros((H, W), bool)      # footprints grown by the grass gap
    for (x, y) in wall_cells:
        occ[y, x] = True

    def ring_piece(kind, q, extra=None, drop_px=0.0):
        wf = L.plate_to_world(q)
        rec = {"kind": kind, "cell": list(tile_of(q)), "world_foot": [round(wf[0], 2), round(wf[1] + drop_px * k, 2)], "solid": False}
        if extra:
            rec.update(extra)
        pieces.append(rec)

    def kind_dir(s):
        return "h" if s == 0.0 else ("diag_se" if s > 0 else "diag_ne")

    def along_len(kind, s):
        w_ = float(pk[kind].get("size", [409, 600])[0]) * k / L.sc
        return w_ / math.cos(math.atan(abs(s)))

    def feature(kind, s, u_open):
        """A gate or tunnel whose opening must sit at u_open along its edge:
        (u of its foot, cut start, cut end), from the art's opening and its
        opaque run (kit px -> plate px along the edge)."""
        sp = pk[kind]
        c = 1.0 / math.cos(math.atan(abs(s))) * k / L.sc
        fx = float(sp["foot"][0])
        ax_ = float(sp.get("arch_x", fx))
        ox = sp.get("opaque_x", [0, sp.get("size", [409])[0]])
        u_foot = u_open + (fx - ax_) * c
        return u_foot, u_foot + (ox[0] - fx) * c + 2.0, u_foot + (ox[1] - fx) * c - 2.0

    feats = {i: [] for i in range(len(edges))}

    def add_feat(typ, ei, u_open, gid):
        a, b = edges[ei]
        L_ = math.dist(a, b)
        kind = typ + "_" + kind_dir(slopes[ei])
        u_f, c0, c1 = feature(kind, slopes[ei], u_open)
        q = (a[0] + (b[0] - a[0]) * u_f / L_, a[1] + (b[1] - a[1]) * u_f / L_)
        feats[ei].append((typ, u_f, (c0, c1), gid, q))

    for g in gates:
        ei, u, q = project(g["q"])
        add_feat("gate", ei, u, g["id"])
    # the water tunnels: where the river crosses the ring
    for ei, (a, b) in enumerate(edges):
        L_ = math.dist(a, b)
        run = []
        for s in range(int(L_ / 6) + 1):
            u = s * 6.0
            q = (a[0] + (b[0] - a[0]) * u / L_, a[1] + (b[1] - a[1]) * u / L_)
            c = tile_of(q)
            wet = 0 <= c[0] < W and 0 <= c[1] < H and water[c[1], c[0]]
            if wet:
                run.append(u)
            if (not wet or s == int(L_ / 6)) and run:
                add_feat("tunnel", ei, (run[0] + run[-1]) / 2.0, "")
                run = []
    for ei, (a, b) in enumerate(edges):
        L_ = math.dist(a, b)
        sl = slopes[ei]
        wk = "wall_" + kind_dir(sl)
        step = pk[wk].get("tile_step_px")
        step_len = (math.hypot(step[0], step[1]) if step else 309.0) * k / L.sc
        cuts = sorted([cut for _, u, cut, _, _ in feats[ei]])
        spans, cur = [], 0.0
        for c0, c1 in cuts:
            if c0 > cur:
                spans.append((cur, c0))
            cur = max(cur, c1)
        if cur < L_:
            spans.append((cur, L_))
        for s0, s1 in spans:
            n = max(1, int(math.ceil((s1 - s0) / step_len)))
            st = (s1 - s0) / n
            variants = [v for v in (wk, wk + "_b", wk + "_c") if v in pk]
            for s in range(n):
                u = s0 + st * (s + 0.5)
                vk = variants[rng.randint(0, len(variants) - 1)]
                ring_piece(vk, (a[0] + (b[0] - a[0]) * u / L_, a[1] + (b[1] - a[1]) * u / L_), {"edge": ei})
        for typ, u, ln, gid, q in feats[ei]:
            if typ == "gate":
                ring_piece("gate_" + kind_dir(sl), q, {"gate": gid, "edge": ei})
            else:
                ring_piece("tunnel_" + kind_dir(sl), q, {"edge": ei})
    for rec in layers:
        if rec["tag"] == "tower" and rec.get("wall_point"):
            ei, u, q = project(T(tuple(rec["wall_point"])))
            ring_piece("tower", q, {"name": rec.get("name", ""), "tower_kind": rec.get("tower_kind", "")},
                       drop_px=float(cfg.get("tower_drop_kit_px", 50.0)))
    # bridges: one piece per crossing (oriented along the road)
    lab, n_b = ndi.label(cross)
    bridge_info = []
    for i_b in range(1, n_b + 1):
        cy_, cx_ = np.nonzero(lab == i_b)
        if len(cx_) < 3:
            continue
        mx, my = float(cx_.mean()), float(cy_.mean())
        along_y = (cy_.max() - cy_.min()) >= (cx_.max() - cx_.min())
        wf = L.tile_to_world((mx, my))
        sp = pk["bridge"]
        size = sp.get("size", [740, 393])
        lift = (float(sp["foot"][1]) - float(size[1]) / 2.0) * k
        pieces.append({"kind": "bridge", "cell": [int(round(mx)), int(round(my))], "world_foot": [round(wf[0], 2), round(wf[1] + lift, 2)],
                       "flip": not along_y, "under": True, "solid": False})
        bridge_info.append({"at": [round(mx, 1), round(my, 1)], "cells": int(len(cx_))})

    # ---- placement helpers
    def fp_cells(kind, ax, ay, flip=False):
        fw, fh = pk[kind]["footprint"]
        if flip:
            fw, fh = fh, fw
        return [(ax - i, ay - j) for i in range(fw) for j in range(fh)]

    def is_road(x, y):
        return 0 <= x < W and 0 <= y < H and terr[y, x] in ("c", "p", "d")

    def can_place(kind, ax, ay, flip=False, gap=True, on=("g",), allow_inside_only=True):
        for x, y in fp_cells(kind, ax, ay, flip):
            if not (0 <= x < W and 0 <= y < H):
                return False
            if occ[y, x] or (gap and halo[y, x]) or terr[y, x] not in on or (x, y) in gate_cells:
                return False
            if allow_inside_only and not inside[y, x]:
                return False
        return True

    def take(kind, ax, ay, flip=False, gap=1, extra=None, solid=None):
        rec = {"kind": kind, "cell": [ax, ay]}
        if flip:
            rec["flip"] = True
        if extra:
            rec.update(extra)
        pieces.append(rec)
        cells = fp_cells(kind, ax, ay, flip)
        if pk[kind].get("blocks", True) and solid is not False:
            for x, y in cells:
                occ[y, x] = True
        for x, y in cells:
            for dx in range(-gap, gap + 1):
                for dy in range(-gap, gap + 1):
                    if 0 <= x + dx < W and 0 <= y + dy < H:
                        halo[y + dy, x + dx] = True
        return rec

    def door_face(kind, ax, ay, flip):
        """Cells just outside the door face (SW; mirrored SE)."""
        fw, fh = pk[kind]["footprint"]
        if flip:
            fw, fh = fh, fw
            return [(ax + 1, ay - j) for j in range(fh)]
        return [(ax - i, ay + 1) for i in range(fw)]

    def door_on_road(kind, ax, ay, flip):
        face = door_face(kind, ax, ay, flip)
        hits = [c for c in face if is_road(*c)]
        return hits[len(hits) // 2] if len(hits) >= max(1, len(face) // 3) else None

    def search(kind, target, radius, door=True, flips=(False, True), **kw):
        tx, ty = target
        best = None
        for r in range(radius + 1):
            for dx in range(-r, r + 1):
                for dy in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    for fl in flips:
                        ax, ay = int(tx + dx), int(ty + dy)
                        if not can_place(kind, ax, ay, fl, **kw):
                            continue
                        dc = door_on_road(kind, ax, ay, fl) if door else None
                        if door and dc is None:
                            continue
                        return ax, ay, fl, dc
        return best

    def pave(cells):
        for x, y in cells:
            if 0 <= x < W and 0 <= y < H and terr[y, x] == "g" and inside[y, x] and not occ[y, x]:
                terr[y, x] = "p"

    targets = {}
    for r in layers:
        if r.get("building"):
            targets.setdefault(r["tag"], []).append(tile_of(T((r["x"] + r["w"] / 2.0, float(r["sort_y"])))))
    plot_targets = [(p["id"], p["tier"], tile_of(T(tuple(p["anchor_px"])))) for p in city["plots"]]
    dropped = []

    # ---- landmarks round the plaza (forecourts paved, nothing in front)
    cxp, cyp = (px0 + px1) // 2, (py0 + py1) // 2
    placed = {}
    # cathedral: north of the plaza, door (SW face) onto it over a 2-row forecourt
    fw, fh = pk["cathedral"]["footprint"]
    for off in range(0, 8):
        for sx in (0, -1, 1, -2, 2):
            ax, ay = cxp + fw // 2 + sx, py0 - 3 - off
            if can_place("cathedral", ax, ay, False, gap=False, on=("g", "c")):
                fc = [(ax - i, ay + j) for i in range(fw) for j in (1, 2)]
                placed["cathedral"] = take("cathedral", ax, ay, False, 1, {"door_cell": [ax - fw // 2, ay + 3]})
                for x, y in fp_cells("cathedral", ax, ay):
                    terr[y, x] = "g"
                pave(fc + [(x, y) for x in range(ax - fw + 1, ax + 1) for y in range(ay + 1, py0)])
                break
        if "cathedral" in placed:
            break
    # town hall: west of the plaza, mirrored (door on the SE face) onto it
    fw, fh = pk["townhall"]["footprint"]
    for off in range(0, 8):
        for sy in (0, 1, -1, 2, -2):
            ax, ay = px0 - 3 - off, cyp + fh // 2 + sy
            if can_place("townhall", ax, ay, True, gap=False, on=("g", "c")):
                placed["townhall"] = take("townhall", ax, ay, True, 1, {"door_cell": [ax + 3, ay - fh // 2]})
                for x, y in fp_cells("townhall", ax, ay, True):
                    terr[y, x] = "g"
                pave([(x, y) for x in range(ax + 1, px0) for y in range(ay - fh + 1, ay + 1)])
                break
        if "townhall" in placed:
            break
    # bank: north of the plaza beside the cathedral, facing the plaza
    fw, fh = pk["bank"]["footprint"]
    cath_left = placed["cathedral"]["cell"][0] - pk["cathedral"]["footprint"][0] if "cathedral" in placed else cxp
    for off in range(0, 10):
        ax, ay = cath_left - 1 - off, py0 - 3
        if can_place("bank", ax, ay, False, gap=False, on=("g", "c")):
            placed["bank"] = take("bank", ax, ay, False, 1, {"door_cell": [ax - fw // 2, ay + 3]})
            for x, y in fp_cells("bank", ax, ay):
                terr[y, x] = "g"
            pave([(x, y) for x in range(ax - fw + 1, ax + 1) for y in range(ay + 1, py0)])
            break
    # castle: by the N avenue, a 3-row forecourt to the road
    rs = next((r_ for r_ in plan.get("reserved", []) if r_["what"] == "castle"), None)
    fw, fh = pk["castle"]["footprint"]
    ct = ((rs["rect"][0] + rs["rect"][2]) // 2 + fw // 2, (rs["rect"][1] + rs["rect"][3]) // 2 + fh // 2 - 2) if rs else tile_of(T(city["gates"][0]["arch"]))
    best = None
    for r in range(0, 20):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if best or max(abs(dx), abs(dy)) != r:
                    continue
                ax, ay = ct[0] + dx, ct[1] + dy
                if not can_place("castle", ax, ay, False, gap=True, on=("g",)):
                    continue
                fc = [(ax - i, ay + j) for i in range(fw) for j in (1, 2, 3)]
                if any(not (0 <= x < W and 0 <= y < H) or occ[y, x] or not inside[y, x] or water[y, x] for x, y in fc):
                    continue
                best = (ax, ay)
    if best:
        ax, ay = best
        placed["castle"] = take("castle", ax, ay, False, 1, {"door_cell": [ax - fw // 2, ay + 2]})
        pave([(ax - i, ay + j) for i in range(fw) for j in (1, 2, 3)])
        # the forecourt's way out: a paved lane straight on to the nearest road
        mx = ax - fw // 2
        for lane in (mx - 1, mx, mx + 1):
            for yy2 in range(ay + 4, ay + 30):
                if is_road(lane, yy2) or not (0 <= yy2 < H) or not inside[yy2, lane]:
                    break
                if not occ[yy2, lane]:
                    terr[yy2, lane] = "p"
    else:
        dropped.append("castle")
    # mill: on the river bank, the wheel (SE face; SW mirrored) over the water
    mt = targets.get("mill", [(cxp + 12, cyp - 10)])[0]
    fw, fh = pk["mill"]["footprint"]
    got = None
    for r in range(0, 40):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if got or max(abs(dx), abs(dy)) != r:
                    continue
                for fl in (False, True):
                    ax, ay = mt[0] + dx, mt[1] + dy
                    if got or not can_place("mill", ax, ay, fl, gap=True):
                        continue
                    side = [(ax + 1, ay - j) for j in range(fh)] if not fl else [(ax - i, ay + 1) for i in range(fw)]
                    if sum(1 for x, y in side if 0 <= x < W and 0 <= y < H and water[y, x]) >= 2:
                        near_road = any(is_road(x + dx2, y + dy2) for x, y in fp_cells("mill", ax, ay, fl) for dx2, dy2 in ((2, 0), (0, 2), (-2, 0), (0, -2)))
                        if near_road:
                            got = (ax, ay, fl)
    if got:
        placed["mill"] = take("mill" if "mill" in pk else "workshop", got[0], got[1], got[2], 1)
    else:
        dropped.append("mill")

    # ---- the plaza: fountain at the centre, stalls round it, benches, flowerbeds
    fk = "fountain"
    take(fk, cxp + 1, cyp + 1, False, 0, solid=True)
    stall_spots = [(cxp - 3, cyp - 2), (cxp + 4, cyp - 2), (cxp - 3, cyp + 4), (cxp + 4, cyp + 4)]
    for i, (sx, sy) in enumerate(stall_spots[:3]):
        kind = STALLS[i] if STALLS[i] in pk else "stall"
        if can_place(kind, sx, sy, False, gap=False, on=("p",)):
            take(kind, sx, sy, False, 0)
        else:
            dropped.append(kind)
    for (bx, by) in [(cxp + 1, cyp - 3), (cxp + 1, cyp + 5), (cxp - 4, cyp + 1), (cxp + 5, cyp + 1)]:
        if "bench_stone" in pk and can_place("bench_stone", bx, by, False, gap=False, on=("p",)):
            take("bench_stone", bx, by, False, 0)
    beds = [k_ for k_ in ("flowerbed_tulips", "flowerbed_roses_round") if k_ in pk]
    if beds:
        for i, (bx, by) in enumerate([(px0 + 1, py0 + 1), (px1, py0 + 1), (px0 + 1, py1), (px1, py1)]):
            if can_place(beds[i % len(beds)], bx, by, False, gap=False, on=("p",)):
                take(beds[i % len(beds)], bx, by, False, 0)

    # ---- workshops: the W quarter (near the W avenue), doors on a street
    wg = next(g for g in gates if g["id"] == "W")
    wt = tile_of(wg["q"])
    w_targets = [(wt[0] + wg["in"][0] * 10 + dx, wt[1] + wg["in"][1] * 10 + dy) for dx, dy in ((-6, -4), (6, -4), (-6, 6), (6, 6), (-12, 0), (12, 0))]
    for i, wk in enumerate([w_ for w_ in WORKSHOPS if w_ in pk]):
        got = search(wk, w_targets[i % len(w_targets)], 22)
        if got:
            r_ = take(wk, got[0], got[1], got[2], 1, {"door_cell": list(got[3])})
            # crates and barrels by the workshop
            for dk, (ox, oy) in zip(("crate_stack", "barrel"), ((2, -1), (1, -3))):
                if dk in pk:
                    cx_, cy_ = got[0] + ox, got[1] + oy
                    if can_place(dk, cx_, cy_, False, gap=False):
                        take(dk, cx_, cy_, False, 0)
        else:
            dropped.append(wk)

    # ---- player plots: their tier house, door on a street, a fenced yard behind
    plots_out = []
    for pid, tier, t_ in plot_targets:
        kind = "plot_" + tier
        got = search(kind, t_, 30)
        if not got:
            dropped.append(pid)
            continue
        ax, ay, fl, dc = got
        take(kind, ax, ay, fl, 2, {"plot": pid, "tier": tier, "door_cell": list(dc)})
        plots_out.append({"id": pid, "tier": tier, "cell": [ax, ay], "front": list(dc)})
        fw, fh = pk[kind]["footprint"]
        if fl:
            fw, fh = fh, fw
        # fences along the back faces (NW: x = ax-fw, NE: y = ay-fh), corner at the back
        fx, fy = ax - fw, ay - fh
        if "fence_picket" in pk:
            for j in range(0, fh, 2):
                c = (fx, ay - j)
                if 0 <= c[0] < W and 0 <= c[1] < H and terr[c[1], c[0]] == "g" and not occ[c[1], c[0]] and inside[c[1], c[0]]:
                    take("fence_picket", c[0], c[1], False, 0, {"plot_fence": pid})
            for i in range(0, fw, 2):
                c = (ax - i, fy)
                if 0 <= c[0] < W and 0 <= c[1] < H and terr[c[1], c[0]] == "g" and not occ[c[1], c[0]] and inside[c[1], c[0]]:
                    take("fence_picket", c[0], c[1], True, 0, {"plot_fence": pid})
            ck = "fence_picket_corner" if "fence_picket_corner" in pk else None
            if ck and 0 <= fx < W and 0 <= fy < H and terr[fy, fx] == "g" and not occ[fy, fx] and inside[fy, fx]:
                take(ck, fx, fy, False, 0, {"plot_fence": pid})

    # ---- NPC houses: fill the blocks (door on a street, a tile of grass round)
    variants = sorted(k_ for k_ in pk if k_.startswith("house_npc_"))
    cand = [(x, y) for y in range(H) for x in range(W) if inside[y, x] and terr[y, x] == "g" and not occ[y, x]]
    rng.shuffle(cand)
    # nearer the streets first
    road_d = ndi.distance_transform_cdt(~road_any, metric="taxicab")
    cand.sort(key=lambda c: road_d[c[1], c[0]])
    n_h = 0
    target_h = int(cfg.get("tile_npc_houses", 60))
    homes = []
    for (ax, ay) in cand:
        if n_h >= target_h:
            break
        kind = variants[n_h % len(variants)]
        for fl in ((n_h // len(variants)) % 2 == 1, (n_h // len(variants)) % 2 == 0):
            if not can_place(kind, ax, ay, fl, gap=True):
                continue
            dc = door_on_road(kind, ax, ay, fl)
            if dc is None:
                continue
            take(kind, ax, ay, fl, 1, {"door_cell": list(dc)})
            homes.append((ax, ay, fl, kind))
            n_h += 1
            break
    # back yards: a tree or crates behind some houses
    for i, (ax, ay, fl, kind) in enumerate(homes):
        fw, fh = pk[kind]["footprint"]
        if fl:
            fw, fh = fh, fw
        bx, by = ax - fw - 1, ay - fh - 1
        if i % 3 == 0:
            tk = TREES[i % len(TREES)]
            if tk in pk and can_place(tk, bx, by, False, gap=False):
                take(tk, bx, by, bool(i % 2), 0)
        elif i % 3 == 1 and "crate" in pk and can_place("crate", bx + 1, by + 1, False, gap=False):
            take("crate", bx + 1, by + 1, False, 0)

    # ---- the well in the east, the gazebo garden (hedges, rose arch)
    eg = next(g for g in gates if g["id"] == "E")
    et = tile_of(eg["q"])
    e_in = (et[0] + eg["in"][0] * 10, et[1] + eg["in"][1] * 10)
    got = search("well", (e_in[0] - 3, e_in[1] + 4), 25, door=False, flips=(False,))
    if got:
        take("well", got[0], got[1], False, 1)
    if "gazebo" in pk:
        got = search("gazebo", (e_in[0] - 8, e_in[1] - 6), 30, door=False, flips=(False,))
        if got:
            gx, gy = got[0], got[1]
            take("gazebo", gx, gy, False, 1, {"garden": True})
            if "hedge_section" in pk:
                for j in range(-4, 3, 2):
                    for cx_, fl in ((gx - 5, False), (gx + 2, False)):
                        if can_place("hedge_section", cx_, gy + j, fl, gap=False):
                            take("hedge_section", cx_, gy + j, fl, 0, {"garden": True})
            if "rose_arch" in pk and can_place("rose_arch", gx + 1, gy + 2, False, gap=False):
                take("rose_arch", gx + 1, gy + 2, False, 0, {"garden": True}, solid=False)
            for i, (fx, fy) in enumerate([(gx - 3, gy + 2), (gx + 2, gy - 4), (gx - 4, gy - 4)]):
                fk2 = FLOWERS[i % 2]
                if fk2 in pk and can_place(fk2, fx, fy, False, gap=False):
                    take(fk2, fx, fy, False, 0)

    # ---- S gate inside: hay cart and signpost; notice board by the town hall
    sg = next(g for g in gates_out if g["id"] == "S")
    if sg["inside"]:
        ix, iy = sg["inside"][-1]
        for dk, cands in (("cart_hay", [(ix - 4, iy - 2), (ix + 2, iy - 4), (ix - 4, iy + 2)]), ("signpost", [(ix + 3, iy), (ix, iy + 3), (ix - 3, iy)])):
            for c in cands:
                if dk in pk and can_place(dk, c[0], c[1], False, gap=False):
                    take(dk, c[0], c[1], False, 0)
                    break
    if "townhall" in placed and "notice_board" in pk:
        d_ = placed["townhall"]["door_cell"]
        for c in [(d_[0], d_[1] + 3), (d_[0], d_[1] - 3), (d_[0] + 1, d_[1] + 3)]:
            if can_place("notice_board", c[0], c[1], False, gap=False, on=("g", "p")):
                take("notice_board", c[0], c[1], False, 0)
                break

    # ---- lamps: along the avenues, the ring road and round the plaza
    lamp_kinds = [k_ for k_ in ("lamp_post", "lamp_hanging") if k_ in pk] or ["lamp"]
    edge = road_any & ~ndi.binary_erosion(road_any) & inside
    lamp_at = []
    ys_, xs_ = np.nonzero(edge)
    order = list(range(len(xs_)))
    rng.shuffle(order)
    for i in order:
        x, y = int(xs_[i]), int(ys_[i])
        if any(abs(x - a) + abs(y - b) < 7 for a, b in lamp_at):
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c = (x + dx, y + dy)
            if 0 <= c[0] < W and 0 <= c[1] < H and terr[c[1], c[0]] == "g" and not occ[c[1], c[0]] and not halo[c[1], c[0]] and inside[c[1], c[0]]:
                take(lamp_kinds[len(lamp_at) % len(lamp_kinds)], c[0], c[1], False, 0)
                lamp_at.append((x, y))
                break
        if len(lamp_at) >= int(cfg.get("tile_lamps", 44)):
            break

    # ---- trees: cypresses by the cathedral, along the ring road, clumps outside
    if "cathedral" in placed and "tree_cypress" in pk:
        ax, ay = placed["cathedral"]["cell"]
        fw, fh = pk["cathedral"]["footprint"]
        for c in [(ax + 2, ay - 1), (ax + 2, ay - fh + 1), (ax - fw - 1, ay - 1), (ax - fw - 1, ay - fh + 1), (ax + 2, ay - fh // 2)]:
            if can_place("tree_cypress", c[0], c[1], False, gap=False):
                take("tree_cypress", c[0], c[1], False, 0)
    ring_in = inside & (dist_ring >= rr["to"]) & (dist_ring < rr["to"] + 2.5) & (terr == "g")
    ys_, xs_ = np.nonzero(ring_in)
    order = list(range(len(xs_)))
    rng.shuffle(order)
    trees_ring = []
    for i in order:
        x, y = int(xs_[i]), int(ys_[i])
        if any(abs(x - a) + abs(y - b) < 6 for a, b in trees_ring):
            continue
        tk = TREES[len(trees_ring) % len(TREES)]
        if tk in pk and can_place(tk, x, y, False, gap=False):
            take(tk, x, y, bool(len(trees_ring) % 2), 0)
            trees_ring.append((x, y))
    outside_g = in_rect & ~inside & (terr == "g") & (dist_ring > band + 2)
    ys_, xs_ = np.nonzero(outside_g)
    clumps = 0
    for i in rng.sample(range(len(xs_)), min(len(xs_), 400)):
        if clumps >= int(cfg.get("tile_outside_clumps", 22)):
            break
        cx_, cy_ = int(xs_[i]), int(ys_[i])
        n_t = 0
        for t in range(6):
            x, y = cx_ + rng.randint(-4, 4), cy_ + rng.randint(-4, 4)
            tk = TREES[rng.randint(0, len(TREES) - 1)] if rng.random() < 0.8 else "tree_cypress"
            if tk in pk and can_place(tk, x, y, False, gap=False, allow_inside_only=False) and not inside[min(H - 1, max(0, y)), min(W - 1, max(0, x))]:
                take(tk, x, y, rng.random() < 0.5, 0)
                n_t += 1
        if n_t:
            clumps += 1
            for t in range(3):
                x, y = cx_ + rng.randint(-6, 6), cy_ + rng.randint(-6, 6)
                bk = BUSHES[rng.randint(0, 2)]
                if bk in pk and can_place(bk, x, y, False, gap=False, allow_inside_only=False):
                    take(bk, x, y, False, 0)
            if "rock_large" in pk and rng.random() < 0.4:
                x, y = cx_ + rng.randint(-6, 6), cy_ + rng.randint(-6, 6)
                if can_place("rock_large", x, y, False, gap=False, allow_inside_only=False):
                    take("rock_large", x, y, False, 0)
    # bushes and flower patches in the leftover grass inside
    ys_, xs_ = np.nonzero(inside & (terr == "g") & ~occ & ~halo)
    order = list(range(len(xs_)))
    rng.shuffle(order)
    n_b = 0
    for i in order[:900]:
        if n_b >= int(cfg.get("tile_bushes", 70)):
            break
        x, y = int(xs_[i]), int(ys_[i])
        kind = (BUSHES + FLOWERS)[n_b % 5]
        if kind in pk and can_place(kind, x, y, False, gap=False):
            take(kind, x, y, False, 0)
            n_b += 1

    # ---- the river: rowboat on the water, a quay on a bank
    wys, wxs = np.nonzero(water & inside & ~cross)
    if len(wxs) and "rowboat" in pk:
        for i in rng.sample(range(len(wxs)), min(60, len(wxs))):
            x, y = int(wxs[i]), int(wys[i])
            if can_place("rowboat", x, y, False, gap=False, on=("w",)):
                take("rowboat", x, y, False, 0, solid=False)
                break
    if "quay_section" in pk:
        bank = inside & (terr == "g") & ndi.binary_dilation(water, iterations=1) & ~occ
        ys_, xs_ = np.nonzero(bank)
        for i in rng.sample(range(len(xs_)), min(80, len(xs_))):
            x, y = int(xs_[i]), int(ys_[i])
            if can_place("quay_section", x, y, False, gap=False) and is_road(x - 3, y) or is_road(x, y + 2):
                take("quay_section", x, y, False, 0, solid=False)
                break

    # ---- chimney smoke on ~40% of the houses
    if "smoke_chimney" in pk:
        for i, p in enumerate(pieces):
            if str(p["kind"]).startswith("house_npc") and i % 5 in (0, 2):
                chim = pk[p["kind"]].get("chimney")
                if chim:
                    pieces.append({"kind": "smoke_chimney", "cell": p["cell"], "on": i, "solid": False, "above": True})

    # ---- spawn and exits: on each gate's road outside
    exits = {}
    for g in gates_out:
        o = g["outside"]
        if not o:
            continue
        gd = next(x for x in gates if x["id"] == g["id"])
        far = max(o, key=lambda c: -(c[0] * gd["in"][0] + c[1] * gd["in"][1]))
        exits[g["id"]] = [int(far[0] - gd["in"][0] * 3), int(far[1] - gd["in"][1] * 3)]
    spawn = exits.get("S", [W // 2, H - 10])
    exit_c = [spawn[0] - next(x for x in gates if x["id"] == "S")["in"][0] * 3, spawn[1] - next(x for x in gates if x["id"] == "S")["in"][1] * 3]
    for c in (spawn, exit_c):
        if 0 <= c[0] < W and 0 <= c[1] < H and terr[c[1], c[0]] in ("g", "."):
            terr[c[1], c[0]] = "d"

    out = {
        "format": "stasium.tile_city", "format_version": 1, "zone_id": "crosshaven_city",
        "kit": os.path.relpath(kit_path, root).replace(os.sep, "/"),
        "tile_world_px": [round(L.tw, 3), round(L.th, 3)], "hero_world_px": hero_world,
        "origin_world": [round(L.ox, 2), round(L.oy, 2)],
        "grid": {"width": W, "height": H, "legend": {".": "void", "g": "grass", "d": "dirt", "c": "cobble", "p": "plaza", "w": "water"},
                 "rows": ["".join(terr[y]) for y in range(H)]},
        "terrain_ids": {"g": "grass", "d": "dirt", "c": "cobble", "p": "plaza", "w": "water"},
        "pieces": pieces, "gates": gates_out, "plots": plots_out,
        "walk_over": [list(c) for c in walk_over],
        "wall_cells": [list(c) for c in wall_cells],
        "wall_polygon_plate": [[round(p[0], 1), round(p[1], 1)] for p in poly],
        "spawn": spawn, "exit": exit_c, "exits": exits,
        "bridges": bridge_info,
        "streetplan": "streetplan.json",
        "source": "city_plan.py: streetplan.json + the approved layout (ring, gates, towers, plots, landmarks)",
        "dropped": dropped,
    }
    json.dump(out, open(os.path.join(data, "tilemap.json"), "w"), separators=(",", ":"))
    kinds = {}
    for p in pieces:
        kk = p["kind"]
        kk = "house_npc" if kk.startswith("house_npc") else kk
        kinds[kk] = kinds.get(kk, 0) + 1
    print("tilemap", W, "x", H, "pieces", kinds, "bridges", len(bridge_info), "dropped", dropped)


def make_plan(cfg, city, T, tile_f, tile_of, gates, tpoly, inside, in_rect, wall_band, dist_ring, band, W, H, L):
    """The street plan, in tile coordinates (x, y), on the two iso axes."""
    pz = cfg["buildings"]["plazas"][0]
    pc = tile_of(T((pz[0] * 4.0, pz[1] * 4.0)))
    pw, ph = int(cfg.get("tile_plaza", [14, 10])[0]), int(cfg.get("tile_plaza", [14, 10])[1])
    plaza = [pc[0] - pw // 2, pc[1] - ph // 2, pc[0] + pw // 2 - 1, pc[1] + ph // 2 - 1]
    ring_road = {"from": round(band + 1.0, 2), "to": round(band + 4.0, 2), "width": 3}

    def toward_plaza(g):
        """Gate -> plaza along the iso axes: first leg straight in from the
        gate (its passage axis or, for a flat edge, the axis that closes the
        bigger gap), then the second leg to the plaza edge."""
        a = (int(round(g["at"][0])), int(round(g["at"][1])))
        tx = min(max(a[0], plaza[0] + 2), plaza[2] - 2)
        ty = min(max(a[1], plaza[1] + 2), plaza[3] - 2)
        if g["in"][0] and g["in"][1]:
            first_x = abs(tx - a[0]) >= abs(ty - a[1])
        else:
            first_x = g["in"][0] != 0
        mid = (tx, a[1]) if first_x else (a[0], ty)
        return [list(a), list(mid), [tx, ty]]

    avenues = [{"gate": g["id"], "width": 4, "pts": toward_plaza(g)} for g in gates]
    # side streets: a grid on the iso axes through the plaza corners
    streets = []
    xs = [x for x in range(plaza[0] - 2, -1, -10)] + [x for x in range(plaza[2] + 2, W, 10)]
    ys = [y for y in range(plaza[1] - 2, -1, -8)] + [y for y in range(plaza[3] + 2, H, 8)]
    ins = np.nonzero(inside)
    xmin, xmax, ymin, ymax = int(ins[1].min()), int(ins[1].max()), int(ins[0].min()), int(ins[0].max())
    for x in xs:
        if xmin < x < xmax:
            streets.append({"axis": "y", "width": 2, "pts": [[x, ymin], [x, ymax]]})
    for y in ys:
        if ymin < y < ymax:
            streets.append({"axis": "x", "width": 2, "pts": [[xmin, y], [xmax, y]]})
    # the river: the old river's course, binned along its main direction,
    # through both water tunnels, smoothed, out to the map edges
    rows = city["grid"]["rows"]
    pts = []
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == "~":
                wp = (32.0 * (x - y), 16.0 * (x + y))
                pts.append(tile_f(T(L.world_to_plate(wp))))
    P = np.array(pts)
    mu = P.mean(axis=0)
    u, s_, vt = np.linalg.svd(P - mu, full_matrices=False)
    axis = vt[0]
    t = (P - mu) @ axis
    bins = np.linspace(t.min(), t.max(), 12)
    cl = []
    for b0, b1 in zip(bins, bins[1:]):
        m = (t >= b0) & (t < b1)
        if m.sum() > 2:
            cl.append(tuple(P[m].mean(axis=0)))
    # pull the course through the layout's water tunnels
    for wg in city.get("water_gates", []):
        wt = tile_f(T(tuple(wg["at"])))
        j = int(np.argmin([math.dist(c, wt) for c in cl]))
        cl[j] = wt
    # extend both ends to the map edges
    d0 = np.array(cl[0]) - np.array(cl[1])
    d1 = np.array(cl[-1]) - np.array(cl[-2])
    cl = [tuple(np.array(cl[0]) + d0 / np.linalg.norm(d0) * 80)] + cl + [tuple(np.array(cl[-1]) + d1 / np.linalg.norm(d1) * 80)]
    river = {"width": float(cfg.get("tile_river_width", 3.5)), "pts": [[round(a, 2), round(b, 2)] for a, b in chaikin(cl, 3)]}
    # outside dirt roads: from each gate straight out to the map edge
    outside = []
    for g in gates:
        a = (g["at"][0], g["at"][1])
        e = (a[0] - g["in"][0] * 200, a[1] - g["in"][1] * 200)
        outside.append({"gate": g["id"], "width": 3, "pts": [[round(a[0]), round(a[1])], [round(e[0]), round(e[1])]]})
    # the castle's ground, kept free of side streets: inside the N gate,
    # beside its avenue
    ng = next(g for g in gates if g["id"] == "N")
    side = (1, -1) if ng["in"][0] and ng["in"][1] else (ng["in"][1], ng["in"][0])
    cc = (ng["at"][0] + ng["in"][0] * 11 - side[0] * 9, ng["at"][1] + ng["in"][1] * 11 - side[1] * 9)
    reserved = [{"what": "castle", "rect": [int(cc[0] - 7), int(cc[1] - 7), int(cc[0] + 7), int(cc[1] + 7)]}]
    return {"format": "stasium.streetplan", "format_version": 1, "units": "tile cells (x, y) on the iso grid",
            "reserved": reserved,
            "note": "Round M3: the town's streets in data. Edit and run city_plan.py (without --replan) to rebuild.",
            "plaza": plaza, "avenues": avenues, "ring_road": ring_road, "streets": streets, "river": river,
            "outside_roads": outside}


if __name__ == "__main__":
    main()
