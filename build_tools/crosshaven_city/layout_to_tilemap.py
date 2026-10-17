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
        root, "art", "world", "crosshaven_tiles", "placeholder", "kit.json")
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

    def foot_cells(kind, ax, ay):
        fw, fh = kit["pieces"][kind]["footprint"]
        return [(ax - i, ay - j) for i in range(fw) for j in range(fh)]

    def free(kind, ax, ay, strict=True):
        if not kit["pieces"][kind]["blocks"]:
            return all(0 <= x < W and 0 <= y < H and terr[y][x] != "." for x, y in foot_cells(kind, ax, ay)) and (ax, ay) not in occupied
        for x, y in foot_cells(kind, ax, ay):
            if not (0 <= x < W and 0 <= y < H) or (x, y) in occupied:
                return False
            if strict and terr[y][x] in ("w.d" if kind in ("fountain", "stall", "well") else "cpw.d"):
                return False
            if (x, y) in gate_cells:
                return False
        return True

    def put(kind, ax, ay, extra=None, nudge=4, strict=True):
        best = None
        for r in range(nudge + 1):
            for dx in range(-r, r + 1):
                for dy in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    if free(kind, ax + dx, ay + dy, strict):
                        best = (ax + dx, ay + dy)
                        break
                if best:
                    break
            if best:
                break
        if best is None:
            return None
        rec = {"kind": kind, "cell": list(best)}
        if extra:
            rec.update(extra)
        pieces.append(rec)
        for c in foot_cells(kind, *best):
            if kit["pieces"][kind]["blocks"]:
                occupied[c] = len(pieces) - 1
        if not kit["pieces"][kind]["blocks"]:
            occupied[best] = len(pieces) - 1
        return rec

    # ---- gates: passage tiles from the gate's passage line (plate px)
    gate_cells = {}
    gates_out = []
    for g in city["gates"]:
        pa, pb = g["passage"][0], g["passage"][-1]
        cells = []
        n = int(math.dist(pa, pb) / 8) + 1
        for k in range(n + 1):
            p = (pa[0] + (pb[0] - pa[0]) * k / n, pa[1] + (pb[1] - pa[1]) * k / n)
            c = L.tile_of_plate(p)
            for dx, dy in ((0, 0), (1, 0), (0, 1)):
                cc = (c[0] + dx, c[1] + dy)
                if cc not in cells and 0 <= cc[0] < W and 0 <= cc[1] < H:
                    cells.append(cc)
        for c in cells:
            gate_cells[c] = g["id"]
            if terr[c[1]][c[0]] in "g.":
                terr[c[1]][c[0]] = "c" if in_poly(L.world_to_plate(L.tile_to_world(c)), poly) else "d"
        arch = L.tile_of_plate(tuple(g["arch"]))
        outside = [c for c in cells if not in_poly(L.world_to_plate(L.tile_to_world(c)), poly)]
        inside = [c for c in cells if in_poly(L.world_to_plate(L.tile_to_world(c)), poly)]
        gates_out.append({"id": g["id"], "arch_cell": list(arch), "cells": [list(c) for c in cells],
                          "outside": [list(c) for c in outside], "inside": [list(c) for c in inside]})

    # ---- walls: tiles near the ring polygon (not the gate passages)
    band = float(ring_cfg.get("tile_wall_band_px", 30.0))
    wall_cells = []
    for y in range(H):
        for x in range(W):
            if terr[y][x] == ".":
                continue
            pp = L.world_to_plate(L.tile_to_world((x, y)))
            d = min(seg_dist(pp, a, b) for a, b in zip(poly, poly[1:] + poly[:1]))
            if d <= band and (x, y) not in gate_cells:
                wall_cells.append((x, y))
    # towers first (they replace the wall under them)
    for rec in layers:
        if rec["tag"] == "tower" and rec.get("wall_point"):
            c = L.tile_of_plate(tuple(rec["wall_point"]))
            fw, fh = kit["pieces"]["tower"]["footprint"]
            ax, ay = c[0] + fw // 2, c[1] + fh // 2
            for cc in foot_cells("tower", ax, ay):
                occupied.pop(cc, None)
            pieces.append({"kind": "tower", "cell": [ax, ay], "name": rec.get("name", ""), "tower_kind": rec.get("tower_kind", "")})
            for cc in foot_cells("tower", ax, ay):
                occupied[cc] = len(pieces) - 1
    for c in wall_cells:
        if c in occupied:
            continue
        if terr[c[1]][c[0]] == "w":
            # the river runs under the wall: a water tunnel (open, not walkable)
            pieces.append({"kind": "wall", "cell": list(c), "tunnel": True})
            occupied[c] = len(pieces) - 1
            continue
        pieces.append({"kind": "wall", "cell": list(c)})
        occupied[c] = len(pieces) - 1
    for g in gates_out:
        pieces.append({"kind": "gate", "cell": g["arch_cell"], "gate": g["id"]})

    # ---- bridges: walk over the water on the old deck cells
    bridge_cells = []
    for b in city["bridges"]:
        # the deck: every tile along the line between the two landings
        (ax_, ay_), (bx_, by_) = b["ends"]
        wa = (32.0 * (ax_ - ay_), 16.0 * (ax_ + ay_))
        wb = (32.0 * (bx_ - by_), 16.0 * (bx_ + by_))
        n = int(math.dist(wa, wb) / (L.th / 3.0)) + 1
        for k in range(n + 1):
            wp = (wa[0] + (wb[0] - wa[0]) * k / n, wa[1] + (wb[1] - wa[1]) * k / n)
            c = L.world_to_tile_f(wp)
            cc = (int(round(c[0])), int(round(c[1])))
            for d in ((0, 0), (1, 0), (0, 1), (-1, 0), (0, -1)):
                c2 = (cc[0] + d[0], cc[1] + d[1])
                if 0 <= c2[0] < W and 0 <= c2[1] < H and c2 not in bridge_cells:
                    bridge_cells.append(c2)
    for c in bridge_cells:
        if terr[c[1]][c[0]] == "w":
            pieces.append({"kind": "bridge", "cell": list(c)})

    # ---- buildings, props, deco from the plate layout (biggest first)
    recs = [r for r in layers if (r.get("building") or r.get("deco")) and r["tag"] in KIND_OF_TAG]
    order = ["castle", "cathedral", "townhall", "bank", "mill", "workshop", "fountain", "stall", "well", "house", "lamp", "bush"]
    recs.sort(key=lambda r: order.index(KIND_OF_TAG[r["tag"]]))
    dropped = []
    for r in recs:
        kind = KIND_OF_TAG[r["tag"]]
        foot = (r["x"] + r["w"] / 2.0, float(r["sort_y"]))
        c = L.tile_of_plate((foot[0], foot[1] - 10.0))
        got = put(kind, c[0], c[1], {"source": r.get("building", r.get("file", ""))},
                  nudge=6 if kind in ("castle", "cathedral", "townhall", "bank", "mill") else 4)
        if got is None:
            dropped.append(r.get("building", r["file"]))
    # ---- player plots
    plots_out = []
    for p in city["plots"]:
        c = L.tile_of_plate(tuple(p["anchor_px"]))
        kind = "plot_" + p["tier"]
        got = put(kind, c[0], c[1], {"plot": p["id"], "tier": p["tier"]}, nudge=6)
        if got is None:
            dropped.append(p["id"])
            continue
        # entrance: the walkable tile in front (south) of the anchor
        plots_out.append({"id": p["id"], "tier": p["tier"], "cell": got["cell"],
                          "front": [got["cell"][0] + 1, got["cell"][1] + 1]})

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
    json.dump(out, open(os.path.join(data, "tilemap.json"), "w"), separators=(",", ":"))
    kinds = {}
    for p in pieces:
        kinds[p["kind"]] = kinds.get(p["kind"], 0) + 1
    print("tilemap", W, "x", H, "tile", round(L.tw, 1), "x", round(L.th, 1), "pieces", kinds, "dropped", dropped)


if __name__ == "__main__":
    main()
