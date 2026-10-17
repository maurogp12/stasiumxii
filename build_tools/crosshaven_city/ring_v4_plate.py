#!/usr/bin/env python3
"""Crosshaven city from Mauro's ring v4 concept image (round 18).

Mauro: "use this one, just with fewer towers". His 1280x720 image becomes the
city plate (x4 = 5120x2880, the plate size the zone already uses):

1. Fewer towers: the towers not on the keep list are painted out by cloning
   the same image's wall (and the grass around it) along the wall line, one
   half from each neighbouring wall, so the wall runs on where a tower stood.
2. The cleaned image, upscaled (LANCZOS + light unsharp), is the ground.
3. Walls and kept towers are cut back out of it as y-sorted layers: wall
   strips with the foot line as their sort line, one layer per tower.
4. The cell grid is read from the image: walls and towers block, the river
   blocks, gates are carved through the wall, bridges are walkable.

All geometry is image px (1280x720) in ring_v4.json; the plate is x4.

Usage: python3 ring_v4_plate.py <repo root> [--debug <dir>] [--sheet <jpg>]
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_city as BC  # noqa: E402  (alpha_bits, MASK_STEP, Grid)

UP = 4  # image px -> plate px


def load_cfg():
    return json.load(open(os.path.join(HERE, "ring_v4.json")))


def green_mask(a):
    """Grass and foliage (kept as is by the clone, cut away from the layers)."""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (g > r + 4) & (g > b + 12)


def water_mask(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (b > r + 45) & (g > r + 25)


def path_mask(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (r > g + 6) & (r > b + 40) & (r > 120)


def shifted(a, dx, dy):
    """a sampled at (x + dx, y + dy), bilinear, edge clamped."""
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    out = np.empty_like(a)
    for c in range(a.shape[2]):
        out[..., c] = ndi.map_coordinates(a[..., c], [yy + dy, xx + dx], order=1, mode="nearest")
    return out


def remove_towers(img, cfg):
    """Paint out every tower in cfg['remove']: left half cloned from the wall to
    its left (along that wall's slope), right half from the wall to its right,
    a short cross-fade in the middle. Grass and foliage pixels stay (trees in
    front of a tower and the grass behind its roof are already right)."""
    a = img.astype(np.float32)
    h, w = a.shape[:2]
    keep_boxes = [t["box"] for t in cfg["towers"] if t.get("keep")]
    green = green_mask(img)
    for t in cfg["towers"]:
        if t.get("keep"):
            continue
        x0, y0, x1, y1 = t["box"]
        xc = (x0 + x1) / 2.0
        half = (x1 - x0) / 2.0
        d = half + float(t.get("margin", 4))
        sl, sr = float(t["slope_left"]), float(t["slope_right"])
        left = shifted(a, -d, -sl * d)
        right = shifted(a, d, sr * d)
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        wr = np.clip((xx - (xc - 6.0)) / 12.0, 0.0, 1.0)[..., None]
        fill = left * (1.0 - wr) + right * wr
        m = np.zeros((h, w), bool)
        m[y0:y1, x0:x1] = True
        # stone and roof only (not grass/foliage), grown 2 px to take the outline
        m &= ndi.binary_dilation(~green, iterations=2) | ~green
        # a kept tower in front stays: its roof (red) and its body below the roof
        r_, g_, b_ = img[..., 0].astype(int), img[..., 1].astype(int), img[..., 2].astype(int)
        roof = ndi.binary_dilation((r_ > g_ + 35) & (r_ > b_ + 45), iterations=2)
        for kb in keep_boxes:
            sub = np.zeros((h, w), bool)
            sub[kb[1]:kb[3], kb[0]:kb[2]] = True
            body = np.zeros((h, w), bool)
            body[kb[1] + 48:kb[3], kb[0]:kb[2]] = True
            m &= ~(sub & (roof | body))
        for eb in t.get("protect", []):
            m[eb[1]:eb[3], eb[0]:eb[2]] = False
        soft = ndi.gaussian_filter(m.astype(np.float32), 1.0)[..., None]
        soft = np.maximum(soft, m[..., None].astype(np.float32) * 0.0)
        a = a * (1.0 - soft) + fill * soft
    return np.clip(a, 0, 255).astype(np.uint8)


def foot_y(seg, x):
    (ax, ay), (bx, by) = seg
    if abs(bx - ax) < 1e-6:
        return max(ay, by)
    t = (x - ax) / (bx - ax)
    return ay + (by - ay) * t


def main():
    root = sys.argv[1]
    debug = sys.argv[sys.argv.index("--debug") + 1] if "--debug" in sys.argv else None
    sheet = sys.argv[sys.argv.index("--sheet") + 1] if "--sheet" in sys.argv else None
    cfg = load_cfg()
    art_dir = os.path.join(root, "art", "world", "crosshaven_city")
    data_dir = os.path.join(root, "data", "world", "crosshaven_city")
    src = np.asarray(Image.open(os.path.join(art_dir, cfg["source"])).convert("RGB"))
    ih, iw = src.shape[:2]
    clean = remove_towers(src, cfg)
    if sheet:
        Image.fromarray(clean).save(sheet, quality=92)
    PW, PH = iw * UP, ih * UP

    def upscale(a):
        im_ = Image.fromarray(a).resize((PW, PH), Image.LANCZOS)
        return im_.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))

    # the layers take their pixels from the full image
    g_np = np.asarray(upscale(clean))
    occl = np.zeros((ih, iw), bool)

    # ---- masks (image px)
    green = green_mask(clean)
    water = ndi.binary_opening(water_mask(clean), iterations=1)
    path = path_mask(clean)
    yy, xx = np.mgrid[0:ih, 0:iw]
    segs = [(tuple(s["a"]), tuple(s["b"]), s) for s in cfg["walls"]]

    # ---- layers
    old = json.load(open(os.path.join(data_dir, "layers.json")))
    lay_dir = os.path.join(art_dir, "layers")
    for rec in old["layers"]:
        f = os.path.join(art_dir, rec["file"])
        if rec["file"].startswith("layers/") and os.path.exists(f):
            os.remove(f)
    out_layers = []
    lid = 9000

    def add_layer(alpha_img, box, tag, sort_y, extra=None):
        nonlocal lid
        x0, y0, x1, y1 = box
        occl[y0:y1, x0:x1] |= alpha_img[y0:y1, x0:x1] > 0.5
        px0, py0, px1, py1 = x0 * UP, y0 * UP, x1 * UP, y1 * UP
        al = Image.fromarray((alpha_img[y0:y1, x0:x1] * 255).astype(np.uint8)).resize((px1 - px0, py1 - py0), Image.BILINEAR)
        al = al.filter(ImageFilter.GaussianBlur(1.2))
        rgba = np.dstack([g_np[py0:py1, px0:px1], np.asarray(al)])
        if (rgba[..., 3] > 60).sum() < 40:
            return None
        im = Image.fromarray(rgba, "RGBA")
        name = "layers/%d_v4_%s.png" % (lid, tag)
        im.save(os.path.join(art_dir, name), optimize=True)
        rec = {"id": lid, "file": name, "tag": tag, "x": px0, "y": py0, "w": im.width, "h": im.height,
               "k": 1.0, "flip": False, "sort_y": round(sort_y * UP, 1), "under": False,
               "fade": im.height >= BC.FADE_MIN_HEIGHT, "fade_min_alpha": 0.45}
        if extra:
            rec.update(extra)
        if rec["fade"]:
            bw, bh, bits = BC.alpha_bits(im)
            rec["mask"] = {"step": BC.MASK_STEP, "w": bw, "h": bh, "bits": bits}
        out_layers.append(rec)
        lid += 1
        return rec

    stone = ~green & ~water
    stone = ndi.binary_opening(stone, iterations=1)
    kept = [t for t in cfg["towers"] if t.get("keep")]
    tower_any = np.zeros((ih, iw), bool)
    for t in kept:
        x0, y0, x1, y1 = t["box"]
        tower_any[y0:y1, x0:x1] = True
    # wall strips: per wall segment, columns of strip px, from the foot up the wall height
    strip = int(cfg.get("strip_px", 6))
    for (a, b, s) in segs:
        xa, xb = sorted([a[0], b[0]])
        hgt = float(s.get("height", cfg["wall_height"]))
        below = float(s.get("below", 3))
        for x0 in range(int(xa), int(math.ceil(xb)), strip):
            x1 = min(int(math.ceil(xb)), x0 + strip)
            if x1 <= x0:
                continue
            fy0, fy1 = foot_y((a, b), x0), foot_y((a, b), x1)
            top = int(min(fy0, fy1) - hgt)
            bot = int(math.ceil(max(fy0, fy1) + below))
            m = np.zeros((ih, iw), bool)
            band = (yy <= (foot_y((a, b), xx + 0.0) + below)) & (yy >= foot_y((a, b), xx + 0.0) - hgt)
            m[top:bot, x0:x1] = band[top:bot, x0:x1]
            m &= stone & ~tower_any
            if s.get("gate"):
                m &= ~path | (yy < foot_y((a, b), xx + 0.0) - 2)
            add_layer(m.astype(np.float32), (x0, max(0, top), x1, min(ih, bot)), "ring_wall",
                      foot_y((a, b), (x0 + x1) / 2.0), {"edge": s["id"]})
    for t in kept:
        x0, y0, x1, y1 = t["box"]
        m = np.zeros((ih, iw), bool)
        m[y0:y1, x0:x1] = True
        m &= stone | (~green & ~water)
        m &= ~(path & (yy > t["base"][1] - 4))
        add_layer(m.astype(np.float32), (x0, y0, x1, y1), "tower", t["base"][1],
                  {"tower_kind": t.get("kind", "wall"), "wall_point": [t["base"][0] * UP, t["base"][1] * UP],
                   "name": t["name"]})

    # ---- cells
    lay = json.load(open(os.path.join(data_dir, "city.json")))
    plate = lay["plate"]
    sc = float(plate["scale"])
    c0 = plate["cell00_px"]
    W, H = lay["grid"]["width"], lay["grid"]["height"]
    blocked = np.zeros((ih, iw), bool)
    for (a, b, s) in segs:
        xa, xb = sorted([a[0], b[0]])
        inx = (xx >= xa - 1) & (xx <= xb + 1)
        fy = foot_y((a, b), xx + 0.0)
        blocked |= inx & (yy <= fy + float(cfg.get("block_below", 3))) & (yy >= fy - float(cfg.get("block_depth", 14)))
    for t in kept + [t for t in cfg["towers"] if t.get("block_only")]:
        cx, cy = t["base"]
        rx = (t["box"][2] - t["box"][0]) * 0.5
        blocked |= ((xx - cx) / rx) ** 2 + ((yy - (cy - rx * 0.45)) / (rx * 0.5)) ** 2 <= 1.0
    for eb in cfg.get("block_boxes", []):
        blocked[eb[1]:eb[3], eb[0]:eb[2]] = True
    gate_open = np.zeros((ih, iw), bool)
    for g in cfg["gates"]:
        p, q = np.array(g["outside"], float), np.array(g["inside"], float)
        v = q - p
        L = np.linalg.norm(v)
        u = v / L
        rel_x, rel_y = xx - p[0], yy - p[1]
        t_ = rel_x * u[0] + rel_y * u[1]
        n_ = np.abs(rel_x * -u[1] + rel_y * u[0])
        gate_open |= (t_ >= 0) & (t_ <= L) & (n_ <= float(g.get("half_width", 8)))
    bridge_ok = np.zeros((ih, iw), bool)
    for br in cfg["bridges"]:
        x0, y0, x1, y1 = br["deck"]
        bridge_ok[y0:y1, x0:x1] = True
    # the deck is the bridge's own stone (not the river around it)
    bridge_ok &= ~water_mask(clean)
    wet = ndi.binary_dilation(water, iterations=1) & ~bridge_ok
    walk_blocked = (blocked & ~gate_open) | wet

    def cell_px(x, y):
        return (c0[0] + 32.0 * (x - y) / sc, c0[1] + 16.0 * (x + y) / sc)

    rows = []
    cell_of = {}
    for y in range(H):
        row = []
        for x in range(W):
            px, py = cell_px(x, y)
            ix, iy = int(px / UP), int(py / UP)
            if not (2 <= ix < iw - 2 and 2 <= iy < ih - 2):
                row.append(".")
                continue
            if walk_blocked[iy, ix]:
                row.append("~" if wet[iy, ix] else "#")
            elif bridge_ok[iy, ix] or path[iy, ix] or gate_open[iy, ix]:
                row.append("r")
            else:
                row.append("g")
            cell_of[(x, y)] = (ix, iy)
        rows.append("".join(row))
    # keep only the walkable component the spawn is in (no islands)
    grid_w = np.array([[c in "gr" for c in r] for r in rows])

    def nearest_cell(ix, iy, ok=None):
        best = None
        for (x, y), (cx, cy) in cell_of.items():
            if not grid_w[y, x] or (ok is not None and not ok(x, y)):
                continue
            d = (cx - ix) ** 2 + (cy - iy) ** 2
            if best is None or d < best[0]:
                best = (d, (x, y))
        return best[1]

    spawn = nearest_cell(*cfg["spawn"])
    lab, n = ndi.label(grid_w, structure=[[0, 1, 0], [1, 1, 1], [0, 1, 0]])
    main_c = lab[spawn[1], spawn[0]]
    rows = ["".join(("#" if (ch in "gr" and lab[y, x] != main_c) else ch) for x, ch in enumerate(r)) for y, r in enumerate(rows)]
    grid_w = np.array([[c in "gr" for c in r] for r in rows])
    exit_c = nearest_cell(*cfg["exit"])

    def cells_on(p, q, step=1.0):
        out = []
        p, q = np.array(p, float), np.array(q, float)
        n_ = int(np.linalg.norm(q - p) / step) + 1
        for k in range(n_ + 1):
            ix, iy = p + (q - p) * k / max(1, n_)
            c = nearest_cell(ix, iy)
            if c not in out:
                out.append(c)
        return out

    gates_out, gate_cells = [], []
    for g in cfg["gates"]:
        cells = cells_on(g["outside"], g["inside"], 3.0)
        rec = {"id": g["id"], "why": "ring v4 image", "arch": [g["arch"][0] * UP, g["arch"][1] * UP],
               "wall_join_left": [g["join_left"][0] * UP, g["join_left"][1] * UP],
               "wall_join_right": [g["join_right"][0] * UP, g["join_right"][1] * UP],
               "passage": [[g["outside"][0] * UP, g["outside"][1] * UP], [g["inside"][0] * UP, g["inside"][1] * UP]],
               "cells": [list(c) for c in cells]}
        if g["id"] == "S":
            gate_cells = [list(c) for c in cells]
        gates_out.append(rec)
    bridges = []
    for br in cfg["bridges"]:
        x0, y0, x1, y1 = br["deck"]
        deck = [list(c) for c, (ix, iy) in cell_of.items() if x0 <= ix < x1 and y0 <= iy < y1 and grid_w[c[1], c[0]]
                and wet[max(0, iy - 12):iy + 12, max(0, ix - 12):ix + 12].any()]
        ends = [list(nearest_cell(*br["ends"][0])), list(nearest_cell(*br["ends"][1]))]
        bridges.append({"id": br["id"], "ends": ends, "deck_cells": sorted(deck), "crown_px": 0.0,
                        "sprite_bbox": [x0 * UP, y0 * UP, x1 * UP, y1 * UP]})
    npcs = []
    used = set()
    inside_poly = [(p[0], p[1]) for p in cfg["polygon"]]

    def in_poly(pt):
        x_, y_ = pt
        c_ = False
        for (x1_, y1_), (x2_, y2_) in zip(inside_poly, inside_poly[1:] + inside_poly[:1]):
            if (y1_ > y_) != (y2_ > y_) and x_ < x1_ + (y_ - y1_) * (x2_ - x1_) / (y2_ - y1_):
                c_ = not c_
        return c_
    for k, n_ in enumerate(lay["npcs"]):
        tgt = cfg["npc_spots"][k % len(cfg["npc_spots"])]
        c = nearest_cell(*tgt, ok=lambda x, y: (x, y) not in used and in_poly(cell_of[(x, y)]))
        used.add(c)
        n2 = dict(n_)
        n2["cell"] = {"x": int(c[0]), "y": int(c[1])}
        npcs.append(n2)
    stubs = []
    for st in lay["gate_stubs"]:
        st = json.loads(json.dumps(st))
        if st["id"] == "crossroads_to_city":
            st["to"]["x"], st["to"]["y"] = spawn
        elif st["id"] == "city_to_crossroads":
            st["from"]["x"], st["from"]["y"] = exit_c
        elif st.get("gate"):
            g = next(g for g in cfg["gates"] if g["id"] == st["gate"])
            c = nearest_cell(*g["road_end"])
            st["from"]["x"], st["from"]["y"] = c
        stubs.append(st)
    plots = []
    for p, spot in zip(lay["plots"], cfg["plot_spots"]):
        p2 = dict(p)
        p2["anchor_px"] = [spot[0] * UP, spot[1] * UP]
        fc = nearest_cell(spot[0], spot[1] + 6)
        p2["front_cells"] = [list(fc)]
        plots.append(p2)

    # the ground behind every wall and tower is filled in from around it, so the
    # local fade (hero behind a wall) shows ground, not the wall again
    import cv2
    hole = ndi.binary_dilation(occl, iterations=2).astype(np.uint8) * 255
    behind = cv2.inpaint(np.ascontiguousarray(clean[..., ::-1]), hole, 7, cv2.INPAINT_TELEA)[..., ::-1]
    ground = upscale(np.ascontiguousarray(behind))
    ground.save(os.path.join(art_dir, "ground.jpg"), quality=90)
    ground.resize((PW // 2, PH // 2), Image.LANCZOS).save(os.path.join(art_dir, "ground_lite.jpg"), quality=88)
    city = {}
    for k in ["format", "format_version", "zone_id", "region", "name", "status"]:
        city[k] = lay[k]
    city["source"] = "Mauro's ring v4 concept (" + cfg["source"] + "), towers painted out to the keep list"
    plate = dict(plate)
    plate.pop("fit", None)
    plate["size"] = [PW, PH]
    plate["source_image_px"] = [iw, ih]
    plate["image_to_plate"] = UP
    city["plate"] = plate
    city["grid"] = {"width": W, "height": H, "legend": lay["grid"]["legend"], "rows": rows, "heights": [], "height_px_per_step": 10}
    city["spawn"] = list(spawn)
    city["exit_cell"] = list(exit_c)
    city["gate_cells"] = gate_cells
    city["wall_polygon"] = [[p[0] * UP, p[1] * UP] for p in cfg["polygon"]]
    city["map_base_only"] = lay["map_base_only"]
    city["wall_ring"] = {"source": "image", "towers_kept": len(kept),
                         "towers_removed": [t["name"] for t in cfg["towers"] if not t.get("keep")],
                         "note": "Round 18: Mauro's ring v4 image is the plate; walls and kept towers are cut from it as y-sorted layers."}
    city["building_footprints"] = []
    city["gates"] = gates_out
    city["bridges"] = bridges
    city["plots"] = plots
    city["plot_rules"] = lay["plot_rules"]
    city["pets"] = []
    city["npcs"] = npcs
    city["day_hours"] = lay["day_hours"]
    city["gate_stubs"] = stubs
    city["layers"] = "layers.json"
    city["water"] = {}
    city["lights"] = {}
    city["water_gates"] = [{"id": w_["id"], "at": [w_["at"][0] * UP, w_["at"][1] * UP],
                            "flank_towers": [[t["base"][0] * UP, t["base"][1] * UP] for t in kept if t["name"] in w_["flanks"]]}
                           for w_ in cfg["water_gates"]]
    json.dump(city, open(os.path.join(data_dir, "city.json"), "w"), indent=1)
    json.dump({"format": "stasium.plate_layers", "format_version": 1, "layers": out_layers},
              open(os.path.join(data_dir, "layers.json"), "w"), separators=(",", ":"))
    st_ = np.asarray(Image.fromarray((path * 255).astype(np.uint8)).resize((PW // 4, PH // 4), Image.BILINEAR))
    Image.fromarray(st_).save(os.path.join(data_dir, "streets.png"), optimize=True)
    print("layers", len(out_layers), "towers kept", len(kept), "spawn", spawn, "exit", exit_c,
          "walkable", int(grid_w.sum()), "gates", [(g["id"], len(g["cells"])) for g in gates_out],
          "bridges", [(b["id"], len(b["deck_cells"]), b["ends"]) for b in bridges])
    if debug:
        os.makedirs(debug, exist_ok=True)
        ov = clean.copy()
        ov[walk_blocked] = (ov[walk_blocked] * 0.4 + np.array([220, 30, 30]) * 0.6).astype(np.uint8)
        ov[gate_open] = (ov[gate_open] * 0.4 + np.array([30, 220, 30]) * 0.6).astype(np.uint8)
        im = Image.fromarray(ov).resize((iw * 2, ih * 2), Image.NEAREST)
        from PIL import ImageDraw
        d = ImageDraw.Draw(im)
        for (x, y), (ix, iy) in cell_of.items():
            if rows[y][x] in "gr":
                d.point((ix * 2, iy * 2), fill=(255, 255, 0))
        for p_ in [spawn, exit_c]:
            ix, iy = cell_of[tuple(p_)]
            d.ellipse([ix * 2 - 5, iy * 2 - 5, ix * 2 + 5, iy * 2 + 5], outline=(255, 0, 255), width=2)
        im.save(os.path.join(debug, "cells.png"))


if __name__ == "__main__":
    main()
