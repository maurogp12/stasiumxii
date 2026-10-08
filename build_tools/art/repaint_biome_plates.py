#!/usr/bin/env python3
"""Repaint Brinewake, Windmere, Stormspire and Slagcrown floor plates.

Each painted feature stays on the cell it already occupies. Tags, elevation
and spawns are not written. Decoration cells that were a cyan, purple or
neon-orange box are returned to the surrounding floor. Gameplay water and
lava cells are repainted as part of the place:

  brinewake  broken deck planks, dark sea in the gaps
  windmere   snow stone with a pale ice sheet, not a teal square
  stormspire stone with a thin etched crack, not a purple box
  slagcrown  basalt with lava only in a channel

Run from the repo root:
  python3 build_tools/art/repaint_biome_plates.py --write
  python3 build_tools/art/repaint_biome_plates.py --preview /tmp/plate_preview
"""
import argparse
import json
import os
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ROOMS = "art/rooms"
HW, HH = 64.0, 32.0  # half-size of a 2x diamond (world diamond is 64x32)

BIOMES = ("brinewake", "windmere", "stormspire", "slagcrown")
ROOMS_FOR = []
for biome in BIOMES:
    ROOMS_FOR.append((f"koliseo_{biome}", biome, f"art/maps/arena_colosseum_v2/tiled/{biome}_15x15_tags.json"))
    for letter in ("a", "b"):
        ROOMS_FOR.append((
            f"stasis_{biome}_room_{letter}",
            biome,
            f"art/maps/stasis_v1/{biome}_room_{letter}_15x15_tags.json",
        ))


def cell_center(x, y):
    ix = ((x - y) * 32.0 + 610.0) * 2.0
    iy = ((x + y) * 16.0 + 366.0) * 2.0
    return ix, iy


def hash01(x, y, salt=0):
    n = (int(x) * 374761393 + int(y) * 668265263 + int(salt) * 1442695041) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return (n & 0xFFFFFF) / float(0xFFFFFF)


def value_noise(ix, iy, scale, salt):
    # Lattice value noise. ix, iy are arrays.
    x = ix / scale
    y = iy / scale
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    fx = x - x0
    fy = y - y0
    fx = fx * fx * (3.0 - 2.0 * fx)
    fy = fy * fy * (3.0 - 2.0 * fy)

    def h(ax, ay):
        n = (ax.astype(np.int64) * 374761393 + ay.astype(np.int64) * 668265263 + int(salt) * 1442695041) & 0xFFFFFFFF
        n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
        return (n & 0xFFFF).astype(np.float32) / 65535.0

    n00 = h(x0, y0)
    n10 = h(x0 + 1, y0)
    n01 = h(x0, y0 + 1)
    n11 = h(x0 + 1, y0 + 1)
    nx0 = n00 * (1 - fx) + n10 * fx
    nx1 = n01 * (1 - fx) + n11 * fx
    return nx0 * (1 - fy) + nx1 * fy


def is_color_box(mean):
    r, g, b = float(mean[0]), float(mean[1]), float(mean[2])
    if g > 70 and b > 85 and r < 90 and b > r + 22:
        return True
    if b > 85 and b > r + 18 and b > g + 12 and r < 130:
        return True
    if r > 170 and g < 110 and b < 50:
        return True
    return False


def diamond_samples(cells, h, w):
    """Pixels that belong to these cells, plus per-pixel cell index."""
    ys = []
    xs = []
    owners = []
    for i, (x, y) in enumerate(cells):
        cx, cy = cell_center(x, y)
        x0 = max(int(np.floor(cx - HW - 1)), 0)
        x1 = min(int(np.ceil(cx + HW + 1)), w)
        y0 = max(int(np.floor(cy - HH - 1)), 0)
        y1 = min(int(np.ceil(cy + HH + 1)), h)
        if x1 <= x0 or y1 <= y0:
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1]
        dx = xx - cx
        dy = yy - cy
        inside = np.abs(dx) / HW + np.abs(dy) / HH <= 1.001
        if not inside.any():
            continue
        ys.append(yy[inside])
        xs.append(xx[inside])
        owners.append(np.full(int(inside.sum()), i, np.int32))
    if not ys:
        return np.zeros(0, np.int32), np.zeros(0, np.int32), np.zeros(0, np.int32)
    return np.concatenate(ys), np.concatenate(xs), np.concatenate(owners)


def donor_lookup(donors):
    if not donors:
        return {}
    return {i: donors[i % len(donors)] for i in range(len(donors) + 8)}


def sample_donor(arr, dx, dy, donor):
    cx, cy = cell_center(donor[0], donor[1])
    sx = np.clip(np.rint(cx + dx).astype(np.int32), 0, arr.shape[1] - 1)
    sy = np.clip(np.rint(cy + dy).astype(np.int32), 0, arr.shape[0] - 1)
    return arr[sy, sx].astype(np.float32)


def paint_room(room_id, biome, tags_path, write, preview_dir):
    img_path = os.path.join(ROOT, ROOMS, room_id, "background_board_2x.webpbin")
    tags = json.load(open(os.path.join(ROOT, tags_path)))
    im = Image.open(img_path).convert("RGB")
    arr = np.array(im)
    h, w = arr.shape[:2]
    by = {(c["x"], c["y"]): c for c in tags["cells"]}
    donors = [(c["x"], c["y"]) for c in tags["cells"]
              if c["terrain"] == "ground" and not c.get("paint_only") and int(c.get("elevation", 0)) == 0]
    if not donors:
        donors = [(c["x"], c["y"]) for c in tags["cells"] if c["terrain"] == "ground"]
    ground_mean = None
    if donors:
        cols = []
        for x, y in donors[::max(1, len(donors) // 24)]:
            cx, cy = cell_center(x, y)
            ix, iy = int(round(cx)), int(round(cy))
            if 0 <= ix < w and 0 <= iy < h:
                cols.append(arr[iy, ix])
        if cols:
            ground_mean = np.mean(cols, axis=0)

    gameplay = []
    decoration = []
    for c in tags["cells"]:
        terrain = c["terrain"]
        props = list(c.get("paint_only", []))
        kind = "decoration"
        if terrain in ("water", "mud", "lava", "void"):
            kind = "gameplay"
        elif c.get("walkable") is False:
            kind = "gameplay"
        entry = {"x": c["x"], "y": c["y"], "terrain": terrain, "elevation": c.get("elevation", 0),
                 "paint_only": props, "mark": kind}
        if kind == "gameplay":
            gameplay.append(entry)
        else:
            decoration.append(entry)

    # Decoration cells whose plate is a colored box go back to the floor.
    box_cells = []
    for c in tags["cells"]:
        if c["terrain"] != "ground":
            continue
        if not c.get("paint_only") and int(c.get("elevation", 0)) == 0:
            # A bare ground cell that is still a cyan/purple/orange square.
            pass
        cx, cy = cell_center(c["x"], c["y"])
        ix, iy = int(round(cx)), int(round(cy))
        if not (0 <= ix < w and 0 <= iy < h):
            continue
        mean = arr[max(0, iy - 4):iy + 5, max(0, ix - 8):ix + 9].mean(axis=(0, 1))
        if is_color_box(mean):
            box_cells.append((c["x"], c["y"]))

    changed = np.zeros((h, w), np.bool_)

    def stamp_floor(cells, darken=1.0):
        if not cells:
            return
        yy, xx, owners = diamond_samples(cells, h, w)
        if yy.size == 0:
            return
        # Local offset from each pixel's own cell, then a donor diamond.
        dx = np.empty(yy.shape, np.float32)
        dy = np.empty(yy.shape, np.float32)
        src = np.empty((yy.shape[0], 3), np.float32)
        # Group by owner for the donor choice.
        for i, cell in enumerate(cells):
            sel = owners == i
            if not sel.any():
                continue
            cx, cy = cell_center(cell[0], cell[1])
            dx[sel] = xx[sel] - cx
            dy[sel] = yy[sel] - cy
            donor = donors[(cell[0] * 3 + cell[1] * 5) % len(donors)]
            src[sel] = sample_donor(arr, dx[sel], dy[sel], donor)
        src *= darken
        noise = value_noise(xx.astype(np.float32), yy.astype(np.float32), 11.0, 3)
        src *= (0.92 + 0.10 * noise)[:, None]
        arr[yy, xx] = np.clip(src, 0, 255).astype(np.uint8)
        changed[yy, xx] = True

    water = [(c["x"], c["y"]) for c in tags["cells"] if c["terrain"] == "water"]
    lava = [(c["x"], c["y"]) for c in tags["cells"] if c["terrain"] == "lava"]

    if biome == "brinewake":
        paint_broken_deck(arr, changed, water)
    elif biome == "windmere":
        stamp_floor(water, 1.0)
        paint_ice(arr, changed, water)
    elif biome == "stormspire":
        stamp_floor(water, 0.96)
        paint_etch(arr, changed, water)
    elif biome == "slagcrown":
        stamp_floor(lava, 0.62)
        paint_lava_channels(arr, changed, lava, by)
        stamp_floor(water, 0.55)
        paint_wet_pits(arr, changed, water)

    # Colored boxes on decoration (and any leftover ground squares).
    stamp_floor(box_cells, 1.0)

    report = {
        "room": room_id,
        "biome": biome,
        "gameplay": gameplay,
        "decoration_boxes_repainted": [{"x": x, "y": y} for x, y in box_cells],
        "gameplay_count": len(gameplay),
        "decoration_count": len(decoration),
    }
    if preview_dir and room_id.startswith("koliseo_"):
        os.makedirs(preview_dir, exist_ok=True)
        Image.fromarray(arr).resize((960, 771), Image.BILINEAR).save(
            os.path.join(preview_dir, f"{room_id}.png"))
        # Means of the repainted gameplay cells, so a bright square cannot hide.
        for terrain in ("water", "lava", "ground"):
            pts = [(c["x"], c["y"]) for c in tags["cells"] if c["terrain"] == terrain]
            if not pts:
                continue
            cols = []
            for x, y in pts:
                cx, cy = cell_center(x, y)
                ix, iy = int(round(cx)), int(round(cy))
                if 0 <= ix < w and 0 <= iy < h:
                    cols.append(arr[iy - 3:iy + 4, ix - 6:ix + 7].mean(axis=(0, 1)))
            if cols:
                print("   ", terrain, np.mean(cols, axis=0).round(1))
    if write:
        Image.fromarray(arr).save(img_path, "WEBP", quality=90, method=4)
        # Godot reads the bytes; the name stays webpbin.
    return report


def paint_broken_deck(arr, changed, cells):
    if not cells:
        return
    h, w = arr.shape[:2]
    yy, xx, _owners = diamond_samples(cells, h, w)
    if yy.size == 0:
        return
    ix = xx.astype(np.float32)
    iy = yy.astype(np.float32)
    # Planks run along the deck. Across-plank is the short iso axis.
    across = (-ix + 2.0 * iy) / np.sqrt(5.0)
    along = (2.0 * ix + iy) / np.sqrt(5.0)
    band = 18.0
    t = np.mod(across, band) / band
    bevel = 1.0 - np.abs(t - 0.5) * 1.15
    bevel = np.clip(bevel, 0.55, 1.0)
    grain = 0.90 + 0.12 * np.sin(along * 0.11 + across * 0.02)
    wood = np.array([78.0, 52.0, 34.0], np.float32)
    # Per-plank stain so neighboring boards are not one color.
    plank_i = np.floor(across / band).astype(np.int32)
    stain = 0.78 + 0.28 * ((plank_i * 17) & 255).astype(np.float32) / 255.0
    plank = wood * (bevel * grain * stain)[:, None]
    # Broken gaps: a stable hash per plank segment.
    seg = np.floor(along / 42.0).astype(np.int64)
    plank64 = plank_i.astype(np.int64)
    n = (plank64 * 374761393 + seg * 668265263) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    gap = ((n & 0xFF).astype(np.float32) / 255.0) > 0.58
    # Jagged the gap edge with noise so it is not a rectangle.
    edge = value_noise(ix, iy, 7.0, 9)
    gap = gap & (edge > 0.28)
    sea = np.array([8.0, 16.0, 24.0], np.float32)
    ripple = 0.85 + 0.25 * value_noise(ix, iy, 9.0, 4)
    sea_px = sea * ripple[:, None]
    out = np.where(gap[:, None], sea_px, plank)
    arr[yy, xx] = np.clip(out, 0, 255).astype(np.uint8)
    changed[yy, xx] = True


def paint_ice(arr, changed, cells):
    if not cells:
        return
    yy, xx, _owners = diamond_samples(cells, h_of(arr), w_of(arr))
    if yy.size == 0:
        return
    ix = xx.astype(np.float32)
    iy = yy.astype(np.float32)
    n = value_noise(ix, iy, 22.0, 11)
    n2 = value_noise(ix, iy, 6.0, 6)
    # Pale sheet, not a saturated teal fill. Most of the diamond stays snow.
    sheet = np.clip((n - 0.38) * 1.8, 0.0, 0.55)
    ice = np.array([198.0, 214.0, 224.0], np.float32)
    base = arr[yy, xx].astype(np.float32)
    mixed = base * (1.0 - sheet)[:, None] + ice * sheet[:, None]
    crack = np.abs(n2 - 0.5) < 0.035
    mixed[crack] *= 0.72
    arr[yy, xx] = np.clip(mixed, 0, 255).astype(np.uint8)
    changed[yy, xx] = True


def paint_etch(arr, changed, cells):
    if not cells:
        return
    yy, xx, owners = diamond_samples(cells, h_of(arr), w_of(arr))
    if yy.size == 0:
        return
    ix = xx.astype(np.float32)
    iy = yy.astype(np.float32)
    # A crack shared by neighbors: distance to the line between cell centers
    # is computed per cell as a short etched stroke, low contrast.
    base = arr[yy, xx].astype(np.float32)
    # Continuous crack field: darken where noise crosses a narrow band.
    n = value_noise(ix, iy, 18.0, 21)
    etch = np.abs(n - 0.5) < 0.018
    # A second, shorter cross scratch.
    n2 = value_noise(ix + 40.0, iy - 15.0, 14.0, 8)
    etch = etch | (np.abs(n2 - 0.62) < 0.012)
    base[etch] = base[etch] * 0.55 + np.array([48.0, 44.0, 52.0], np.float32) * 0.45
    arr[yy, xx] = np.clip(base, 0, 255).astype(np.uint8)
    changed[yy, xx] = True


def paint_lava_channels(arr, changed, cells, by):
    if not cells:
        return
    h, w = arr.shape[:2]
    yy, xx, _owners = diamond_samples(cells, h, w)
    if yy.size == 0:
        return
    mask = np.zeros((h, w), np.bool_)
    mask[yy, xx] = True
    # Stroke a channel along a spanning tree of the lava cells.
    pts = {c: cell_center(c[0], c[1]) for c in cells}
    remaining = set(cells)
    start = min(cells)
    tree = []
    grown = {start}
    remaining.remove(start)
    while remaining:
        best = None
        best_d = 1e18
        for a in grown:
            ax, ay = pts[a]
            for b in remaining:
                bx, by_ = pts[b]
                d = (ax - bx) ** 2 + (ay - by_) ** 2
                if d < best_d:
                    best_d = d
                    best = (a, b)
        tree.append(best)
        grown.add(best[1])
        remaining.remove(best[1])
    # Also point a channel toward a steam vent when one sits next to lava.
    for x, y in cells:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = by.get((x + dx, y + dy))
            if n and "steam_vent" in n.get("paint_only", []):
                tree.append(((x, y), (x + dx, y + dy)))
    chan = np.zeros((h, w), np.float32)
    core = np.zeros((h, w), np.float32)
    for a, b in tree:
        ax, ay = pts[a] if a in pts else cell_center(a[0], a[1])
        bx, by_ = pts[b] if b in pts else cell_center(b[0], b[1])
        steps = int(max(abs(ax - bx), abs(ay - by_), 1)) + 1
        for t in range(steps + 1):
            u = t / steps
            px = int(round(ax + (bx - ax) * u))
            py = int(round(ay + (by_ - ay) * u))
            y0, y1 = max(0, py - 9), min(h, py + 10)
            x0, x1 = max(0, px - 14), min(w, px + 15)
            yy2, xx2 = np.mgrid[y0:y1, x0:x1]
            d = np.hypot((xx2 - px) * 0.55, yy2 - py)
            sub = chan[y0:y1, x0:x1]
            sub_c = core[y0:y1, x0:x1]
            sub[...] = np.maximum(sub, np.clip(1.0 - d / 8.0, 0, 1))
            sub_c[...] = np.maximum(sub_c, np.clip(1.0 - d / 2.6, 0, 1))
    body = np.array([92.0, 28.0, 8.0], np.float32)
    hot = np.array([210.0, 96.0, 24.0], np.float32)
    base = arr.astype(np.float32)
    lava_px = mask & (chan > 0.05)
    mix = chan[lava_px][:, None]
    base[lava_px] = base[lava_px] * (1.0 - mix) + body * mix
    hot_px = mask & (core > 0.4)
    base[hot_px] = hot
    arr[...] = np.clip(base, 0, 255).astype(np.uint8)
    changed[yy, xx] = True


def paint_wet_pits(arr, changed, cells):
    """Slagcrown's few water cells: a dark pit, not a cyan tile."""
    if not cells:
        return
    yy, xx, owners = diamond_samples(cells, h_of(arr), w_of(arr))
    if yy.size == 0:
        return
    ix = xx.astype(np.float32)
    iy = yy.astype(np.float32)
    # Distance from each pixel to its cell center, normalized.
    dist = np.ones(yy.shape, np.float32)
    # owners index into `cells` only if diamond_samples enumerated `cells` in order.
    # Recompute per cell.
    for i, cell in enumerate(cells):
        sel = owners == i
        if not sel.any():
            continue
        cx, cy = cell_center(cell[0], cell[1])
        dist[sel] = np.abs(ix[sel] - cx) / HW + np.abs(iy[sel] - cy) / HH
    base = arr[yy, xx].astype(np.float32)
    pit = np.clip(1.0 - dist, 0, 1) ** 1.4
    dark = np.array([28.0, 22.0, 20.0], np.float32)
    ember = np.array([120.0, 48.0, 16.0], np.float32)
    base = base * (1.0 - 0.75 * pit)[:, None] + dark * (0.75 * pit)[:, None]
    eye = pit > 0.72
    base[eye] = ember
    arr[yy, xx] = np.clip(base, 0, 255).astype(np.uint8)
    changed[yy, xx] = True


def h_of(arr):
    return arr.shape[0]


def w_of(arr):
    return arr.shape[1]


def clear_storm_occluders():
    """Drop near-black texels that touch the transparent cut, on Stormspire only."""
    cleared = 0
    files = 0
    for dirpath, _dirs, names in os.walk(os.path.join(ROOT, ROOMS)):
        if "stormspire" not in dirpath or not dirpath.endswith("occluders_2x"):
            continue
        for name in names:
            if not name.endswith(".webpbin"):
                continue
            path = os.path.join(dirpath, name)
            im = Image.open(path).convert("RGBA")
            arr = np.array(im)
            rgb = arr[..., :3]
            alpha = arr[..., 3]
            dark = (rgb.max(axis=-1) < 20) & (alpha > 180)
            trans = alpha < 20
            seen = np.zeros(alpha.shape, np.bool_)
            q = deque()
            ys, xs = np.where(trans)
            for y, x in zip(ys.tolist(), xs.tolist()):
                seen[y, x] = True
                q.append((y, x))
            h, w = alpha.shape
            n = 0
            while q:
                y, x = q.popleft()
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if ny < 0 or nx < 0 or ny >= h or nx >= w or seen[ny, nx]:
                        continue
                    seen[ny, nx] = True
                    if dark[ny, nx]:
                        alpha[ny, nx] = 0
                        n += 1
                        q.append((ny, nx))
                    elif trans[ny, nx]:
                        q.append((ny, nx))
            if n:
                arr[..., 3] = alpha
                Image.fromarray(arr).save(path, "WEBP", quality=90, method=4)
                cleared += n
            files += 1
    return files, cleared


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--preview", default="")
    parser.add_argument("--occluders", action="store_true")
    parser.add_argument("--report", default="")
    args = parser.parse_args()
    reports = []
    for room_id, biome, tags in ROOMS_FOR:
        reports.append(paint_room(room_id, biome, tags, args.write, args.preview))
        print(room_id, "gameplay", reports[-1]["gameplay_count"],
              "boxes", len(reports[-1]["decoration_boxes_repainted"]))
    if args.occluders and args.write:
        files, cleared = clear_storm_occluders()
        print("occluders", files, "cleared", cleared)
    if args.report:
        os.makedirs(os.path.dirname(args.report), exist_ok=True)
        with open(args.report, "w") as f:
            json.dump(reports, f, indent=2)
        print("report", args.report)


if __name__ == "__main__":
    main()
