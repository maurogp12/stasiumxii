#!/usr/bin/env python3
"""Convert the approved Crosshaven layout into the modular tile map.

Reads data/world/crosshaven_city/city.json + layers.json (the HD plate build:
ring, gates, river, bridges, plots, building spots) and the tile kit, and
writes data/world/crosshaven_city/tilemap.json for backend/tile_city.gd.

- Tile grid: iso 2:1, kit tile_px at kit hero_px; in world px a tile is
  tile_px * hero_world / hero_px wide (the hero keeps his size).
- Ground: each tile takes the old walk grid's terrain under its centre
  (road -> cobble inside the ring, dirt outside; water; grass), plazas from
  ring_v4.json.
- Walls: tiles whose centre is within a band of the ring polygon get a wall
  piece, except the gate passages (gate piece at the arch, passage open);
  the kept towers and the water tunnels come from the layout.
- Buildings, props, lamps, bushes, player plots: one piece each at the tile
  under its foot, nudged (up to 4 tiles) so a blocking footprint never covers
  a road, the plaza, water, a gate or another piece.

Usage: python3 layout_to_tilemap.py <repo root> [--kit <kit.json>]
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# round 26: props that may stand on the plaza or a street edge
SMALL_PROPS = {"fountain", "stall", "well", "bench_iron", "bench_stone", "crate", "crate_stack", "barrel", "barrel_b",
               "cart_hay", "signpost", "notice_board", "lamp_post", "lamp_hanging", "fence_picket", "fence_rail", "fence_stone"}
WORKSHOP_OF_TAG = {"smithy2": "workshop_smithy", "forge": "workshop_forge", "potter": "workshop_potter",
                   "weaver": "workshop_weaver", "carpenter": "workshop_carpenter", "tailor": "workshop_tailor"}
STALLS = ["stall_fruit", "stall_cloth", "stall_bakery"]
LAMPS = ["lamp_post", "lamp_post", "lamp_hanging"]

KIND_OF_TAG = {
    "castle": "castle", "cathedral": "cathedral", "townhall": "townhall", "bank": "bank",
    "house": "house", "smithy2": "workshop", "forge": "workshop", "potter": "workshop", "weaver": "workshop",
    "carpenter": "workshop", "tailor": "workshop", "mill": "mill", "stall": "stall", "fountain": "fountain",
    "well": "well", "lamp": "lamp", "bush": "bush",
}


def seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    vx, vy = bx - ax, by - ay
    L = vx * vx + vy * vy
    t = 0.0 if L == 0 else max(0.0, min(1.0, ((p[0] - ax) * vx + (p[1] - ay) * vy) / L))
    return math.hypot(p[0] - ax - t * vx, p[1] - ay - t * vy)


def in_poly(pt, poly):
    x, y = pt
    c = False
    for (x1, y1), (x2, y2) in zip(poly, poly[1:] + poly[:1]):
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            c = not c
    return c


class Lattice:
    def __init__(self, city, kit, hero_world):
        p = city["plate"]
        self.sc = float(p["scale"])
        self.c0 = p["cell00_px"]
        self.size = p["size"]
        k = hero_world / float(kit["hero_px"])
        self.tw = kit["tile_px"][0] * k
        self.th = kit["tile_px"][1] * k
        # world rect of the plate; origin chosen so tile (0, 0) is the min corner
        x0, y0 = self.plate_to_world((0, 0))
        x1, y1 = self.plate_to_world(tuple(self.size))
        self.rect = (x0, y0, x1, y1)
        self.ox, self.oy = 0.0, 0.0
        cs = [self.world_to_tile_f((x, y)) for x in (x0, x1) for y in (y0, y1)]
        mx = math.floor(min(c[0] for c in cs))
        my = math.floor(min(c[1] for c in cs))
        self.ox, self.oy = self.tile_to_world((mx, my))
        cs = [self.world_to_tile_f((x, y)) for x in (x0, x1) for y in (y0, y1)]
        self.w = int(math.ceil(max(c[0] for c in cs))) + 1
        self.h = int(math.ceil(max(c[1] for c in cs))) + 1

    def plate_to_world(self, p):
        return ((p[0] - self.c0[0]) * self.sc, (p[1] - self.c0[1]) * self.sc)

    def world_to_plate(self, w):
        return (w[0] / self.sc + self.c0[0], w[1] / self.sc + self.c0[1])

    def tile_to_world(self, t):
        return (self.ox + (t[0] - t[1]) * self.tw / 2.0, self.oy + (t[0] + t[1]) * self.th / 2.0)

    def world_to_tile_f(self, w):
        a = (w[0] - self.ox) / (self.tw / 2.0)
        b = (w[1] - self.oy) / (self.th / 2.0)
        return ((a + b) / 2.0, (b - a) / 2.0)

    def tile_of_plate(self, p):
        x, y = self.world_to_tile_f(self.plate_to_world(p))
        return int(round(x)), int(round(y))

    def in_rect(self, w):
        return self.rect[0] <= w[0] <= self.rect[2] and self.rect[1] <= w[1] <= self.rect[3]


def main():
    root = sys.argv[1]
    kit_path = sys.argv[sys.argv.index("--kit") + 1] if "--kit" in sys.argv else os.path.join(
        root, "art", "world", "crosshaven_tiles", "kit_a", "kit.json")
    data = os.path.join(root, "data", "world", "crosshaven_city")
    city = json.load(open(os.path.join(data, "city.json")))
    layers = json.load(open(os.path.join(data, "layers.json")))["layers"]
    ring_cfg = json.load(open(os.path.join(HERE, "ring_v4.json")))
    kit = json.load(open(kit_path))
    hero_world = float(ring_cfg.get("hero_world_px", 62.7))
    L = Lattice(city, kit, hero_world)
    W, H = L.w, L.h
    old_rows = city["grid"]["rows"]
    ow, oh = city["grid"]["width"], city["grid"]["height"]
    poly = [tuple(p) for p in city["wall_polygon"]]

    def old_sym(wp):
        # nearest old walk cell (64x32 world lattice)
        a, b = wp[0] / 32.0, wp[1] / 16.0
        x, y = int(round((a + b) / 2.0)), int(round((b - a) / 2.0))
        if 0 <= x < ow and 0 <= y < oh:
            return old_rows[y][x]
        return "."

    plazas = [[v * 4 for v in pz] for pz in ring_cfg.get("buildings", {}).get("plazas", [])]
    # streets and river from the plate's own masks (image px = plate / 4)
    import numpy as np
    from PIL import Image
    from scipy import ndimage as ndi
    streets = np.asarray(Image.open(os.path.join(data, "streets.png")).convert("L")) > 100
    gimg = np.asarray(Image.open(os.path.join(root, "art", "world", "crosshaven_city", "ground_lite.jpg")).convert("RGB")
                      .resize((streets.shape[1], streets.shape[0]), Image.BILINEAR)).astype(int)
    water_m = (gimg[..., 2] > gimg[..., 0] + 45) & (gimg[..., 1] > gimg[..., 0] + 25)
    water_m = ndi.binary_closing(ndi.binary_opening(water_m, iterations=1), iterations=2)
    st_frac = ndi.uniform_filter(streets.astype(np.float32), 5)
    wa_frac = ndi.uniform_filter(water_m.astype(np.float32), 5)

    def mask_sym(pp):
        ix, iy = int(pp[0] / 4), int(pp[1] / 4)
        if not (0 <= ix < streets.shape[1] and 0 <= iy < streets.shape[0]):
            return None
        if wa_frac[iy, ix] > 0.45:
            return "~"
        if st_frac[iy, ix] > 0.4:
            return "r"
        return "g"
    terr = [["."] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            wp = L.tile_to_world((x, y))
            if not L.in_rect(wp):
                continue
            pp = L.world_to_plate(wp)
            s = mask_sym(pp) or old_sym(wp)
            if old_sym(wp) == "~":
                s = "~"
            inside = in_poly(pp, poly)
            if s == "~":
                t = "w"
            elif s == "r":
                t = "c" if inside else "d"
            elif s == ".":
                t = "g"
            else:
                t = "g"
            for pz in plazas:
                if ((pp[0] - pz[0]) / pz[2]) ** 2 + ((pp[1] - pz[1]) / pz[3]) ** 2 <= 1.0:
                    t = "p"
            terr[y][x] = t

    pieces = []
    occupied = {}

    def foot_cells(kind, ax, ay, flip=False):
        fw, fh = kit["pieces"][kind]["footprint"]
        if flip:
            fw, fh = fh, fw
        return [(ax - i, ay - j) for i in range(fw) for j in range(fh)]

    def free(kind, ax, ay, strict=True, flip=False):
        if not kit["pieces"][kind]["blocks"]:
            return all(0 <= x < W and 0 <= y < H and terr[y][x] != "." for x, y in foot_cells(kind, ax, ay)) and (ax, ay) not in occupied
        for x, y in foot_cells(kind, ax, ay, flip):
            if not (0 <= x < W and 0 <= y < H) or (x, y) in occupied:
                return False
            if strict and terr[y][x] in ("w.d" if (kind in SMALL_PROPS or kind.startswith("stall")) else "cpw.d"):
                return False
            if (x, y) in gate_cells:
                return False
        return True

    def road(c):
        return 0 <= c[0] < W and 0 <= c[1] < H and terr[c[1]][c[0]] in "cdp" and c not in occupied

    def door_side(kind, ax, ay, prefer_flip):
        """Round 26: a house's door (kit door_side SW face; mirrored, SE face)
        must open onto a street: returns (flip, door cell) or None."""
        fw, fh = kit["pieces"][kind]["footprint"]
        sw = [(ax - i, ay + 1) for i in range(fw)]
        se = [(ax + 1, ay - j) for j in range(fw)]
        opts = []
        for flip, face in ((False, sw), (True, se)):
            far = [(c[0] + (0 if not flip else 1), c[1] + (1 if not flip else 0)) for c in face]
            hits = [c for c in face + far if road(c)]
            if hits:
                opts.append((flip, hits[0]))
        if not opts:
            return None
        for o in opts:
            if o[0] == prefer_flip:
                return o
        return opts[0]

    def put(kind, ax, ay, extra=None, nudge=4, strict=True, door=False, prefer_flip=False):
        best = None
        for r in range(nudge + 1):
            for dx in range(-r, r + 1):
                for dy in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    cx, cy = ax + dx, ay + dy
                    flip, dcell = False, None
                    if door:
                        ds = door_side(kind, cx, cy, prefer_flip)
                        if ds is None:
                            continue
                        flip, dcell = ds
                    if free(kind, cx, cy, strict, flip):
                        best = (cx, cy, flip, dcell)
                        break
                if best:
                    break
            if best:
                break
        if best is None:
            return None
        rec = {"kind": kind, "cell": [best[0], best[1]]}
        if best[2]:
            rec["flip"] = True
        if best[3] is not None:
            rec["door_cell"] = list(best[3])
            occupied[tuple(best[3])] = -2
        if extra:
            rec.update(extra)
        pieces.append(rec)
        for c in foot_cells(kind, best[0], best[1], best[2]):
            if kit["pieces"][kind]["blocks"]:
                occupied[c] = len(pieces) - 1
        if not kit["pieces"][kind]["blocks"]:
            occupied[(best[0], best[1])] = len(pieces) - 1
        return rec

    # ---- the ring on the kit's three wall directions (round 26): every edge
    # snapped to screen slope 0 or +/-0.5 through its midpoint; neighbours
    # that snap alike merge; corners where the snapped lines meet
    def snap_poly(pl):
        edges = []
        for p0, p1 in zip(pl, pl[1:] + pl[:1]):
            dx, dy = p1[0] - p0[0], p1[1] - p0[1]
            sl = 0.0 if abs(dx) < 1e-6 else dy / dx
            t = min((0.0, 0.5, -0.5), key=lambda c: abs(math.atan(sl) - math.atan(c)))
            ln = math.hypot(dx, dy)
            mid = ((p0[0] + p1[0]) / 2.0, (p0[1] + p1[1]) / 2.0)
            if edges and edges[-1][0] == t:
                # merged run: the longer edge's line wins (a short kink folds in)
                pt, m0, pl_ = edges[-1]
                edges[-1] = (t, m0 if pl_ >= ln else mid, max(pl_, ln))
            else:
                edges.append((t, mid, ln))
        if len(edges) > 1 and edges[0][0] == edges[-1][0]:
            t, m0, l0 = edges[0]
            _, m1, l1 = edges.pop()
            edges[0] = (t, m0 if l0 >= l1 else m1, max(l0, l1))
        verts = []
        for (t1, m1, _), (t2, m2, _) in zip(edges, edges[1:] + edges[:1]):
            # y = m1y + t1 (x - m1x) = m2y + t2 (x - m2x)
            x = (m2[1] - m1[1] + t1 * m1[0] - t2 * m2[0]) / (t1 - t2)
            verts.append((x, m1[1] + t1 * (x - m1[0])))
        return [verts[-1]] + verts[:-1], [e[0] for e in edges]

    poly, slopes = snap_poly(poly)
    # keep the snapped ring on the plate with room for the roads out: scale
    # it about its centre (slopes stay) until every corner is inside a margin
    mg = float(ring_cfg.get("tile_ring_margin_px", 260.0))
    cx_ = sum(p_[0] for p_ in poly) / len(poly)
    cy_ = sum(p_[1] for p_ in poly) / len(poly)
    f_ = 1.0
    for p_ in poly:
        for v, c_, lo, hi in ((p_[0], cx_, mg, L.size[0] - mg), (p_[1], cy_, mg * 0.5, L.size[1] - mg * 0.5)):
            if v > hi:
                f_ = min(f_, (hi - c_) / (v - c_))
            if v < lo:
                f_ = min(f_, (c_ - lo) / (c_ - v))
    poly = [(cx_ + (p_[0] - cx_) * f_, cy_ + (p_[1] - cy_) * f_) for p_ in poly]
    edges_ = list(zip(poly, poly[1:] + poly[:1]))

    def project(pt):
        best = None
        for i, (a, b) in enumerate(edges_):
            vx, vy = b[0] - a[0], b[1] - a[1]
            L2 = vx * vx + vy * vy
            u = max(0.0, min(1.0, ((pt[0] - a[0]) * vx + (pt[1] - a[1]) * vy) / L2))
            q = (a[0] + u * vx, a[1] + u * vy)
            d = math.dist(q, pt)
            if best is None or d < best[0]:
                best = (d, i, u * math.sqrt(L2), q)
        return best[1], best[2], best[3]

    k = L.tw / float(kit["tile_px"][0])  # world px per kit px

    def kind_dir(slope):
        return "h" if slope == 0.0 else ("diag_se" if slope > 0 else "diag_ne")

    def along_len(kind, slope):
        # a piece's run along the wall line, plate px
        w_ = float(kit["pieces"][kind].get("size", [409, 600])[0]) * k / L.sc
        return w_ / math.cos(math.atan(abs(slope)))

    # ---- gates: the arch projected onto its edge; the passage keeps the old
    # direction through the new point
    gate_cells = {}
    gates_out = []
    feats = {i: [] for i in range(len(edges_))}
    for g in city["gates"]:
        ei, u, q = project(tuple(g["arch"]))
        pa, pb = g["passage"][0], g["passage"][-1]
        vx, vy = pb[0] - pa[0], pb[1] - pa[1]
        half = math.hypot(vx, vy) / 2.0
        nx, ny = vx / (2 * half), vy / (2 * half)
        pa = (q[0] - nx * half, q[1] - ny * half)
        pb = (q[0] + nx * half, q[1] + ny * half)
        cells = []
        n = int(math.dist(pa, pb) / 8) + 1
        for kk in range(n + 1):
            p = (pa[0] + (pb[0] - pa[0]) * kk / n, pa[1] + (pb[1] - pa[1]) * kk / n)
            c = L.tile_of_plate(p)
            for dx, dy in ((0, 0), (1, 0), (0, 1)):
                cc = (c[0] + dx, c[1] + dy)
                if cc not in cells and 0 <= cc[0] < W and 0 <= cc[1] < H:
                    cells.append(cc)
        for c in cells:
            gate_cells[c] = g["id"]
            if terr[c[1]][c[0]] in "g.":
                terr[c[1]][c[0]] = "c" if in_poly(L.world_to_plate(L.tile_to_world(c)), poly) else "d"
        kind = "gate_" + kind_dir(slopes[ei])
        feats[ei].append(("gate", u, along_len(kind, slopes[ei]), g["id"], q))
        outside = [c for c in cells if not in_poly(L.world_to_plate(L.tile_to_world(c)), poly)]
        inside = [c for c in cells if in_poly(L.world_to_plate(L.tile_to_world(c)), poly)]
        gates_out.append({"id": g["id"], "arch_cell": list(L.tile_of_plate(q)), "cells": [list(c) for c in cells],
                          "outside": [list(c) for c in outside], "inside": [list(c) for c in inside],
                          "arch_plate": [round(q[0], 1), round(q[1], 1)]})

    # ---- water tunnels: where an edge crosses the river
    for ei, (a, b) in enumerate(edges_):
        L_ = math.dist(a, b)
        run = []
        for kk in range(int(L_ / 6) + 1):
            u = kk * 6.0
            p = (a[0] + (b[0] - a[0]) * u / L_, a[1] + (b[1] - a[1]) * u / L_)
            c = L.tile_of_plate(p)
            wet = any(0 <= c[0] + dx < W and 0 <= c[1] + dy < H and terr[c[1] + dy][c[0] + dx] == "w"
                      for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)))
            if wet:
                run.append(u)
            elif run:
                if run[-1] - run[0] > 20:
                    um = (run[0] + run[-1]) / 2.0
                    kind = "tunnel_" + kind_dir(slopes[ei])
                    q = (a[0] + (b[0] - a[0]) * um / L_, a[1] + (b[1] - a[1]) * um / L_)
                    feats[ei].append(("tunnel", um, along_len(kind, slopes[ei]), "", q))
                run = []

    # the layout's own water gates (where the painted ring had its tunnels)
    for wg in city.get("water_gates", []):
        ei, u, q = project(tuple(wg["at"]))
        if any(t_ == "tunnel" and abs(u_ - u) < 200 for t_, u_, _, _, _ in feats[ei]):
            continue
        kind = "tunnel_" + kind_dir(slopes[ei])
        feats[ei].append(("tunnel", u, along_len(kind, slopes[ei]), "", q))
    # ---- walls: tiles near the snapped ring (not the gate passages) block
    band = float(ring_cfg.get("tile_wall_band_px", 30.0))
    wall_cells = []
    for y in range(H):
        for x in range(W):
            if terr[y][x] == ".":
                continue
            pp = L.world_to_plate(L.tile_to_world((x, y)))
            d = min(seg_dist(pp, a, b) for a, b in edges_)
            if d <= band and (x, y) not in gate_cells:
                wall_cells.append((x, y))

    def ring_piece(kind, q, extra=None, drop_px=0.0):
        wf = L.plate_to_world(q)
        rec = {"kind": kind, "cell": list(L.tile_of_plate(q)), "world_foot": [round(wf[0], 2), round(wf[1] + drop_px * k, 2)], "solid": False}
        if extra:
            rec.update(extra)
        pieces.append(rec)

    # walls fill each edge between its gates and tunnels
    for ei, (a, b) in enumerate(edges_):
        L_ = math.dist(a, b)
        sl = slopes[ei]
        wk = "wall_" + kind_dir(sl)
        step = kit["pieces"][wk].get("tile_step_px")
        step_len = (math.hypot(step[0], step[1]) if step else 309.0) * k / L.sc
        cuts = sorted([(u - ln / 2.0, u + ln / 2.0) for _, u, ln, _, _ in feats[ei]])
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
            for kk in range(n):
                u = s0 + st * (kk + 0.5)
                q = (a[0] + (b[0] - a[0]) * u / L_, a[1] + (b[1] - a[1]) * u / L_)
                ring_piece(wk, q, {"edge": ei})
        for typ, u, ln, gid, q in feats[ei]:
            if typ == "gate":
                ring_piece("gate_" + kind_dir(sl), q, {"gate": gid, "edge": ei})
            else:
                ring_piece("tunnel_" + kind_dir(sl), q, {"edge": ei})
    # the 12 towers, on the snapped ring, their plinth a little below the wall foot
    for rec in layers:
        if rec["tag"] == "tower" and rec.get("wall_point"):
            ei, u, q = project(tuple(rec["wall_point"]))
            ring_piece("tower", q, {"name": rec.get("name", ""), "tower_kind": rec.get("tower_kind", "")},
                       drop_px=float(ring_cfg.get("tower_drop_kit_px", 50.0)))
    for c in wall_cells:
        occupied[c] = -1

    # ---- bridges: walk over the water on the old deck cells
    bridge_cells = []
    for b in city["bridges"]:
        # the deck: every tile along the line between the two landings
        (ax_, ay_), (bx_, by_) = b["ends"]
        wa = (32.0 * (ax_ - ay_), 16.0 * (ax_ + ay_))
        wb = (32.0 * (bx_ - by_), 16.0 * (bx_ + by_))
        n = int(math.dist(wa, wb) / (L.th / 3.0)) + 1
        for kk in range(n + 1):
            wp = (wa[0] + (wb[0] - wa[0]) * kk / n, wa[1] + (wb[1] - wa[1]) * kk / n)
            c = L.world_to_tile_f(wp)
            cc = (int(round(c[0])), int(round(c[1])))
            for d in ((0, 0), (1, 0), (0, 1), (-1, 0), (0, -1)):
                c2 = (cc[0] + d[0], cc[1] + d[1])
                if 0 <= c2[0] < W and 0 <= c2[1] < H and c2 not in bridge_cells:
                    bridge_cells.append(c2)
    for b in city["bridges"]:
        (ax_, ay_), (bx_, by_) = b["ends"]
        wa = (32.0 * (ax_ - ay_), 16.0 * (ax_ + ay_))
        wb = (32.0 * (bx_ - by_), 16.0 * (bx_ + by_))
        mid = ((wa[0] + wb[0]) / 2.0, (wa[1] + wb[1]) / 2.0)
        sp = kit["pieces"]["bridge"]
        size = sp.get("size", [740, 393])
        # sprite centre on the deck midpoint; ne art, mirrored for a se span
        lift = (float(sp["foot"][1]) - float(size[1]) / 2.0) * k
        ne = (wb[0] - wa[0]) * (wb[1] - wa[1]) < 0
        pieces.append({"kind": "bridge", "cell": list(L.tile_of_plate(L.world_to_plate(mid))), "world_foot": [round(mid[0], 2), round(mid[1] + lift, 2)],
                       "flip": not ne, "under": True, "solid": False, "bridge": b["id"]})

    # ---- buildings, props, deco from the plate layout (biggest first)
    recs = [r for r in layers if (r.get("building") or r.get("deco")) and r["tag"] in KIND_OF_TAG]
    order = ["castle", "cathedral", "townhall", "bank", "mill", "workshop", "fountain", "stall", "well", "house", "lamp", "bush"]
    recs.sort(key=lambda r: order.index(KIND_OF_TAG[r["tag"]]))
    dropped = []
    npc_variants = sorted(k_ for k_ in kit["pieces"] if k_.startswith("house_npc_"))
    n_house = 0
    n_stall = 0
    n_lamp = 0
    big = ("castle", "cathedral", "townhall", "bank", "mill")

    def mill_ok(ax, ay, flip):
        # the wheel (SE side; SW when mirrored) over the water
        fw, fh = kit["pieces"]["mill"]["footprint"]
        side = [(ax + d, ay - j) for j in range(fh) for d in (1, 2)] if not flip else [(ax - i, ay + d) for i in range(fw) for d in (1, 2)]
        return any(0 <= x < W and 0 <= y < H and terr[y][x] == "w" for x, y in side)

    for r in recs:
        kind = KIND_OF_TAG[r["tag"]]
        door = False
        prefer = False
        if kind == "house" and npc_variants:
            kind = npc_variants[n_house % len(npc_variants)]
            door = True
            prefer = (n_house // len(npc_variants)) % 2 == 1
            n_house += 1
        elif kind == "workshop" and WORKSHOP_OF_TAG.get(r["tag"]) in kit["pieces"]:
            kind = WORKSHOP_OF_TAG[r["tag"]]
        elif kind == "stall" and STALLS[n_stall % 3] in kit["pieces"]:
            kind = STALLS[n_stall % 3]
            n_stall += 1
        elif kind == "lamp" and LAMPS[n_lamp % 3] in kit["pieces"]:
            kind = LAMPS[n_lamp % 3]
            n_lamp += 1
        if kind in ("castle", "cathedral", "townhall", "bank") and "door_side" in kit["pieces"][kind]:
            door = True
        foot = (r["x"] + r["w"] / 2.0, float(r["sort_y"]))
        c = L.tile_of_plate((foot[0], foot[1] - 10.0))
        src_ = {"source": r.get("building", r.get("file", ""))}
        if kind == "mill":
            got = None
            for rr in range(0, 16):
                for dx in range(-rr, rr + 1):
                    for dy in range(-rr, rr + 1):
                        if got or max(abs(dx), abs(dy)) != rr:
                            continue
                        for fl in (False, True):
                            if not got and mill_ok(c[0] + dx, c[1] + dy, fl) and free("mill", c[0] + dx, c[1] + dy, True, fl):
                                got = put("mill", c[0] + dx, c[1] + dy, src_, nudge=0)
                                if got and fl:
                                    got["flip"] = True
        else:
            got = put(kind, c[0], c[1], src_, nudge=8 if kind in big else (10 if door else 4), door=door, prefer_flip=prefer)
            if got is None and kind in big:
                # a landmark too big for the old spot: look further, then let it
                # cover a minor street (never a gate, water or the plaza)
                got = put(kind, c[0], c[1], src_, nudge=16, door=False)
                if got is None:
                    got = put(kind, c[0], c[1], src_, nudge=10, strict=False)
        if got is None:
            dropped.append(r.get("building", r["file"]))

    # ---- round 26 dressing (props group): benches round the fountain, crates
    # and barrels by the workshops and stalls, a hay cart and a signpost inside
    # the S gate, the notice board by the town hall
    def piece_of(kind_prefix):
        return [p_ for p_ in pieces if str(p_["kind"]).startswith(kind_prefix)]

    def dress(kind, near, count, r0=2):
        if kind not in kit["pieces"]:
            return 0
        n_ = 0
        for p_ in near:
            if n_ >= count:
                break
            ax, ay = p_
            if put(kind, ax, ay, {"dressing": True}, nudge=r0 + 2):
                n_ += 1
        return n_

    for f_ in piece_of("fountain"):
        ax, ay = f_["cell"]
        dress("bench_stone", [(ax + 3, ay), (ax - 4, ay), (ax, ay + 3), (ax, ay - 4)], 4)
    for w_ in piece_of("workshop_") + piece_of("stall_"):
        ax, ay = w_["cell"]
        dress("crate_stack" if hash(w_["kind"]) % 2 else "barrel", [(ax + 2, ay - 1), (ax - 1, ay + 2)], 1)
        dress("barrel_b" if hash(w_["kind"]) % 2 else "crate", [(ax + 2, ay - 2), (ax - 2, ay + 2)], 1)
    for g in gates_out:
        if g["id"] == "S" and g["inside"]:
            ix, iy = g["inside"][-1]
            dress("cart_hay", [(ix - 3, iy - 1), (ix + 1, iy - 3)], 1)
            dress("signpost", [(ix + 2, iy), (ix - 1, iy + 2)], 1)
    for t_ in piece_of("townhall"):
        d_ = t_.get("door_cell") or [t_["cell"][0] + 1, t_["cell"][1] + 1]
        dress("notice_board", [(d_[0] + 2, d_[1]), (d_[0], d_[1] + 2)], 1)
    # ---- player plots
    plots_out = []
    for p in city["plots"]:
        c = L.tile_of_plate(tuple(p["anchor_px"]))
        kind = "plot_" + p["tier"]
        got = put(kind, c[0], c[1], {"plot": p["id"], "tier": p["tier"]}, nudge=14, door="door_side" in kit["pieces"][kind])
        if got is None:
            dropped.append(p["id"])
            continue
        # entrance: the door cell on the street (or the tile south of the anchor)
        plots_out.append({"id": p["id"], "tier": p["tier"], "cell": got["cell"],
                          "front": got.get("door_cell", [got["cell"][0] + 1, got["cell"][1] + 1])})

    # picket fences along the plots' street faces, the door left open
    if "fence_picket" in kit["pieces"]:
        for pl in plots_out:
            pc = next(p_ for p_ in pieces if p_.get("plot") == pl["id"])
            fw_, fh_ = kit["pieces"][pc["kind"]]["footprint"]
            if pc.get("flip"):
                fw_, fh_ = fh_, fw_
            ax, ay = pc["cell"]
            door_c = tuple(pl["front"])
            for i in range(0, fw_ + 1, 2):
                c_ = (ax - i, ay + 1)
                if c_ == door_c or abs(c_[0] - door_c[0]) + abs(c_[1] - door_c[1]) <= 1:
                    continue
                if free("fence_picket", c_[0], c_[1], True):
                    put("fence_picket", c_[0], c_[1], {"dressing": True, "plot_fence": pl["id"]}, nudge=0)

    spawn = L.tile_of_plate(L.world_to_plate((32.0 * (city["spawn"][0] - city["spawn"][1]), 16.0 * (city["spawn"][0] + city["spawn"][1]))))
    out = {
        "format": "stasium.tile_city", "format_version": 1, "zone_id": "crosshaven_city",
        "kit": os.path.relpath(kit_path, root).replace(os.sep, "/"),
        "tile_world_px": [round(L.tw, 3), round(L.th, 3)], "hero_world_px": hero_world,
        "origin_world": [round(L.ox, 2), round(L.oy, 2)],
        "grid": {"width": W, "height": H, "legend": {".": "void", "g": "grass", "d": "dirt", "c": "cobble", "p": "plaza", "w": "water"},
                 "rows": ["".join(r) for r in terr]},
        "terrain_ids": {"g": "grass", "d": "dirt", "c": "cobble", "p": "plaza", "w": "water"},
        "pieces": pieces, "gates": gates_out, "plots": plots_out,
        "walk_over": [list(c) for c in bridge_cells],
        "spawn": list(spawn),
        "source": "layout_to_tilemap.py from city.json (%s)" % city.get("source", ""),
        "dropped": dropped,
    }
    out["wall_cells"] = [list(c) for c in wall_cells]
    out["wall_polygon_plate"] = [[round(p[0], 1), round(p[1], 1)] for p in poly]
    json.dump(out, open(os.path.join(data, "tilemap.json"), "w"), separators=(",", ":"))
    kinds = {}
    for p in pieces:
        kinds[p["kind"]] = kinds.get(p["kind"], 0) + 1
    print("tilemap", W, "x", H, "tile", round(L.tw, 1), "x", round(L.th, 1), "pieces", kinds, "dropped", dropped)


if __name__ == "__main__":
    main()
