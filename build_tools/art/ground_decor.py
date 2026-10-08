#!/usr/bin/env python3
"""Ground the room decorations and repaint Stormspire lightning and Brinewake sea.

View only. Tags, elevation labels, spawns, and lava plates are left alone.
Run: python3 build_tools/art/ground_decor.py --write
"""
import glob
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ROOMS = os.path.join(ROOT, "art", "rooms")
SEA_SRC = "/opt/cursor/artifacts/assets/sea_paint.jpg"
HOLE_SRC = "/opt/cursor/artifacts/assets/deck_hole.jpg"

BIOMES = ("brinewake", "windmere", "stormspire", "slagcrown")
HW, HH = 64.0, 32.0

STONE = {
    "stormspire": np.array([50.0, 44.0, 40.0]),
    "slagcrown": np.array([46.0, 30.0, 24.0]),
    "windmere": np.array([164.0, 174.0, 182.0]),
    "brinewake": np.array([52.0, 36.0, 26.0]),
}

# Height scale. Windmere ice is 45% of the current crystal. The volcano is a vent.
SCALE = {
    "crystal": 0.45,
    "ice_shard": 0.45,
    "volcano": 0.34,
    "tower": 0.46,
    "conduit": 0.56,
    "arc": 0.56,
    "crystal_bolt": 0.52,
    "rock_pillar": 0.55,
    "basalt_pillar": 0.55,
    "wreck": 0.70,
    "chest": 0.68,
    "crate": 0.68,
    "coral_rock": 0.62,
    "driftwood": 0.66,
}
SINK = {
    "wreck": 14, "chest": 10, "crate": 10, "coral_rock": 8, "driftwood": 12,
    "conduit": 6, "arc": 6, "tower": 8, "rock_pillar": 8, "basalt_pillar": 8,
    "crystal_bolt": 6,
}


def biome_of(room_id):
    for name in BIOMES:
        if name in room_id:
            return name
    return ""


def room_ids():
    out = []
    for path in sorted(glob.glob(os.path.join(ROOMS, "*", "place.json"))):
        room = os.path.basename(os.path.dirname(path))
        if biome_of(room):
            out.append(room)
    return out


def cell_center(x, y):
    return ((x - y) * 32 + 610) * 2, ((x + y) * 16 + 366) * 2


def tags_path(room_id):
    if room_id.startswith("stasis_"):
        return os.path.join(ROOT, "art", "maps", "stasis_v1", "%s_15x15_tags.json" % room_id[len("stasis_"):])
    return os.path.join(ROOT, "art", "maps", "arena_colosseum_v2", "tiled", "%s_15x15_tags.json" % room_id[len("koliseo_"):])


def load_tags(room_id):
    return json.load(open(tags_path(room_id)))


def stand_cells(room_id):
    """Cells a fighter starts on, plus the ring around them."""
    tags = load_tags(room_id)
    seeds = []
    for item in tags.get("spawns") or []:
        if isinstance(item, list) and len(item) >= 2:
            seeds.append((int(item[0]), int(item[1])))
    if room_id.startswith("koliseo_"):
        seeds.extend([(1, 13), (13, 1)])
    out = set()
    for x, y in seeds:
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                out.add((x + dx, y + dy))
    return out


def is_center(x, y):
    return max(abs(x - 7), abs(y - 7)) <= 2


def ice_kind(what):
    for name in ("crystal", "ice_shard", "spark"):
        if name in what:
            return name
    return None


def kind_of(what):
    if not what:
        return ""
    for name in SCALE:
        if name in what:
            return name
    if what and str(what[0]).startswith("elevation"):
        return "elevation"
    return str(what[0])


def save_webp(path, arr):
    Image.fromarray(arr).save(path, "WEBP", quality=90, method=4)


def flatten_block(path, biome):
    im = np.array(Image.open(path).convert("RGBA"))
    h, w = im.shape[:2]
    alpha = im[:, :, 3]
    if not (alpha > 20).any():
        return
    ys, xs = np.where(alpha > 20)
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    cy = y0 + (y1 - y0) * 0.36
    cx = (x0 + x1) * 0.5
    hw = max((x1 - x0) * 0.5, 1.0)
    hh = max((y1 - y0) * 0.36, 1.0)
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.abs(xx - cx) / hw + np.abs(yy - cy) / hh
    stone = STONE[biome]
    lum = im[:, :, :3].astype(np.float32).mean(axis=2)
    med = float(np.median(lum[alpha > 20])) or 1.0
    shade = stone * (0.86 + 0.18 * np.clip(lum / med, 0.75, 1.2))[..., None]
    crack = (np.abs((xx * 2 - yy) % 31 - 3) < 1) | (np.abs((xx + yy * 2) % 47 - 2) < 1)
    shade[crack & (d <= 1.0)] *= 0.7
    # A small embedded rock, not a second block.
    rock = (d < 0.42) & (((xx + yy) // 9) % 5 == 0)
    shade[rock] *= 0.78
    out = np.zeros_like(im)
    top = d <= 1.0
    shadow = (d > 1.0) & (d < 1.22) & (yy > cy)
    out[:, :, :3] = np.clip(shade, 0, 255).astype(np.uint8)
    out[:, :, 3] = 0
    out[top, 3] = np.where(alpha[top] > 20, 255, 0).astype(np.uint8)
    out[shadow, :3] = (stone * 0.45).astype(np.uint8)
    out[shadow, 3] = 90
    save_webp(path, out)


def mute_gold(arr, biome):
    rgb = arr[:, :, :3].astype(np.int16)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    gold = (r > 145) & (g > 105) & (r > b + 28) & (g > b + 8) & (arr[:, :, 3] > 20)
    if not gold.any():
        return arr
    stone = STONE[biome]
    out = arr.copy()
    base = out[:, :, :3].astype(np.float32)
    base[gold] = base[gold] * 0.25 + stone * 0.75
    out[:, :, :3] = np.clip(base, 0, 255).astype(np.uint8)
    return out


def opaque_foot(arr):
    alpha = arr[:, :, 3]
    ys, xs = np.where(alpha > 30)
    if len(ys) == 0:
        return arr.shape[1] / 2.0, arr.shape[0] - 1.0
    yb = int(ys.max())
    band = ys >= yb - 2
    return float(xs[band].mean()), float(yb)


def add_shadow(arr):
    h, w = arr.shape[:2]
    alpha = arr[:, :, 3]
    ys, xs = np.where(alpha > 40)
    if len(ys) == 0:
        return arr
    yb = int(ys.max())
    band = ys >= yb - 3
    x0, x1 = int(xs[band].min()), int(xs[band].max())
    pad = 8
    out = np.zeros((h + pad, w, 4), np.uint8)
    out[:h] = arr
    cx = (x0 + x1) * 0.5
    rx = max((x1 - x0) * 0.55, 4.0)
    for i in range(pad):
        y = h + i
        half = rx * (1.0 - i / pad)
        a = int(78 * (1.0 - i / pad))
        x_lo = max(0, int(cx - half))
        x_hi = min(w, int(cx + half))
        out[y, x_lo:x_hi, :3] = (18, 16, 14)
        out[y, x_lo:x_hi, 3] = a
    return out


def scale_prop(path, scale, sink, biome, mute):
    arr = np.array(Image.open(path).convert("RGBA"))
    if mute:
        arr = mute_gold(arr, biome)
    fx, fy = opaque_foot(arr)
    h, w = arr.shape[:2]
    nw = max(8, int(round(w * scale)))
    nh = max(8, int(round(h * scale)))
    small = np.array(Image.fromarray(arr).resize((nw, nh), Image.Resampling.LANCZOS))
    small = add_shadow(small)
    save_webp(path, small)
    # Resize is from the top-left, so the foot moves by (1 - scale).
    delta = [fx - fx * scale, fy - fy * scale + sink]
    return [small.shape[1], small.shape[0]], delta


def relocate_ice(room_id, occluders):
    """Drop center ice and ice on a fighter's cells. Keep the edge clusters."""
    if "windmere" not in room_id:
        return occluders
    stand = stand_cells(room_id)
    kept = []
    moved = []
    for occ in occluders:
        what = occ.get("what") or []
        if ice_kind(what) is None:
            kept.append(occ)
            continue
        cell = occ.get("cell") or [0, 0]
        x, y = int(cell[0]), int(cell[1])
        if is_center(x, y) or (x, y) in stand:
            moved.append(occ)
        else:
            kept.append(occ)
    used = set()
    for occ in kept:
        cell = occ.get("cell") or [0, 0]
        used.add((int(cell[0]), int(cell[1])))
    edges = [(0, 0), (14, 14), (0, 7), (14, 7), (1, 0), (13, 14), (0, 14), (14, 0)]
    for occ in moved:
        dest = None
        for cell in edges:
            if cell in used or cell in stand or is_center(*cell):
                continue
            dest = cell
            break
        if dest is None:
            continue
        occ["cell"] = [dest[0], dest[1]]
        used.add(dest)
        kept.append(occ)
    return kept


def ground_room(room_id, write):
    biome = biome_of(room_id)
    place_path = os.path.join(ROOMS, room_id, "place.json")
    place = json.load(open(place_path))
    occluders = relocate_ice(room_id, list(place.get("occluders", [])))
    notes = []
    for occ in occluders:
        what = occ.get("what") or []
        kind = kind_of(what)
        path = os.path.join(ROOMS, room_id, occ["file"])
        if not os.path.exists(path):
            continue
        if kind == "elevation":
            if write:
                flatten_block(path, biome)
            notes.append("block")
            continue
        if "windmere" in room_id and ice_kind(what):
            scale = 0.45
            mute = False
        else:
            scale = SCALE.get(kind, 0.62)
            mute = True
        sink = SINK.get(kind, 4)
        if not write:
            continue
        size, delta = scale_prop(path, scale, sink, biome, mute)
        off = occ.get("offset") or [0, 0]
        occ["offset"] = [int(round(float(off[0]) + delta[0])), int(round(float(off[1]) + delta[1]))]
        occ["size"] = size
        notes.append(kind)
    place["occluders"] = occluders
    if write:
        with open(place_path, "w") as handle:
            json.dump(place, handle, separators=(",", ":"))
    return notes


def cell_window(arr, x, y):
    h, w = arr.shape[:2]
    cx, cy = cell_center(x, y)
    x0, x1 = max(0, int(cx - HW - 2)), min(w, int(cx + HW + 3))
    y0, y1 = max(0, int(cy - HH - 2)), min(h, int(cy + HH + 3))
    yy, xx = np.mgrid[y0:y1, x0:x1]
    d = np.abs(xx - cx) / HW + np.abs(yy - cy) / HH
    return x0, x1, y0, y1, d, cx, cy


def paint_lightning(arr, cells):
    """Dark grate, a cyan/violet glow inside the diamond, a bright crackle. No rim."""
    for i, (x, y) in enumerate(cells):
        x0, x1, y0, y1, d, cx, cy = cell_window(arr, x, y)
        inside = d <= 0.90
        if not inside.any():
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1]
        u = (xx - cx) / HW
        v = (yy - cy) / HH
        iron = np.array([32.0, 30.0, 36.0])
        # Soft inner glow only. A full fill turned a cluster into a purple slab.
        glow = np.clip(0.55 - d * 0.45, 0.0, 0.34)
        col = iron + np.array([18.0, 70.0, 120.0]) * glow[..., None]
        col = col + np.array([40.0, 10.0, 70.0]) * (glow * 0.35)[..., None]
        bar = (np.abs(np.mod(u * 3.1 + 0.5, 1.0) - 0.5) < 0.055) | (
            np.abs(np.mod(v * 2.5 + 0.5, 1.0) - 0.5) < 0.065
        )
        col[bar] = np.array([118.0, 138.0, 158.0])
        base = arr[y0:y1, x0:x1].astype(np.float32)
        base[inside] = col[inside]
        arr[y0:y1, x0:x1] = np.clip(base, 0, 255).astype(np.uint8)
        held = arr[y0:y1, x0:x1].copy()
        _bolt(arr, cx - 28, cy + 6, cx + 26, cy - 4, 11 + i * 3)
        _bolt(arr, cx - 6, cy - 12, cx + 8, cy + 14, 40 + i)
        painted = arr[y0:y1, x0:x1]
        painted[d > 0.88] = held[d > 0.88]


def _bolt(arr, x0, y0, x1, y1, seed):
    rng = np.random.default_rng(seed)
    pts = [(x0, y0)]
    for step in range(1, 7):
        t = step / 6.0
        px = x0 + (x1 - x0) * t + float(rng.integers(-6, 7))
        py = y0 + (y1 - y0) * t + float(rng.integers(-4, 5))
        pts.append((px, py))
    pts.append((x1, y1))
    _stroke(arr, pts, (36, 18, 64), 2.4)
    _stroke(arr, pts, (70, 210, 255), 1.8)
    _stroke(arr, pts, (196, 120, 255), 1.15)
    _stroke(arr, pts, (245, 252, 255), 0.7)


def _stroke(arr, pts, color, radius):
    h, w = arr.shape[:2]
    col = np.array(color, np.float32)
    r2 = radius * radius
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        length = max(abs(x1 - x0), abs(y1 - y0), 1.0)
        for t in np.linspace(0, 1, int(length) + 1):
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            x_lo, x_hi = int(x - radius - 1), int(x + radius + 2)
            y_lo, y_hi = int(y - radius - 1), int(y + radius + 2)
            if x_hi < 0 or y_hi < 0 or x_lo >= w or y_lo >= h:
                continue
            x_lo, y_lo = max(0, x_lo), max(0, y_lo)
            x_hi, y_hi = min(w, x_hi), min(h, y_hi)
            yy, xx = np.mgrid[y_lo:y_hi, x_lo:x_hi]
            mask = (xx - x) ** 2 + (yy - y) ** 2 <= r2
            patch = arr[y_lo:y_hi, x_lo:x_hi].astype(np.float32)
            patch[mask] = col
            arr[y_lo:y_hi, x_lo:x_hi] = patch.astype(np.uint8)


def deck_mask(cells, h, w):
    yy, xx = np.mgrid[0:h, 0:w]
    mask = np.zeros((h, w), bool)
    for x, y in cells:
        cx, cy = cell_center(x, y)
        mask |= (np.abs(xx - cx) / HW + np.abs(yy - cy) / HH) <= 1.0
    return mask


def paint_sea(arr, outside):
    sea = np.array(Image.open(SEA_SRC).convert("RGB"))
    sea = sea[int(sea.shape[0] * 0.40):]
    painted = np.array(Image.fromarray(sea).resize((arr.shape[1], arr.shape[0]), Image.Resampling.LANCZOS)).astype(np.float32)
    painted *= 0.78
    base = arr.astype(np.float32)
    base[outside] = painted[outside]
    arr[...] = np.clip(base, 0, 255).astype(np.uint8)


def hull_foam(arr, deck, outside):
    edge = deck & _shift(outside)
    if not edge.any():
        return
    foam = _dilate(edge, 3) & outside
    base = arr.astype(np.float32)
    base[foam] = base[foam] * 0.35 + np.array([176.0, 190.0, 180.0]) * 0.65
    arr[...] = np.clip(base, 0, 255).astype(np.uint8)


def _shift(mask):
    out = np.zeros_like(mask)
    out[1:] |= mask[:-1]
    out[:-1] |= mask[1:]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    return out


def _dilate(mask, radius):
    out = mask.copy()
    for _ in range(radius):
        out = out | _shift(out)
    return out


def paint_holes(arr, cells):
    hole = np.array(Image.open(HOLE_SRC).convert("RGB"))
    cy, cx = hole.shape[0] // 2, hole.shape[1] // 2
    water = hole[cy - 160:cy + 160, cx - 160:cx + 160]
    for i, (x, y) in enumerate(cells):
        x0, x1, y0, y1, d, ccx, ccy = cell_window(arr, x, y)
        inside = d <= 0.96
        if not inside.any():
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1]
        u = np.clip((xx - ccx) / (HW * 2) + 0.5, 0, 0.999)
        v = np.clip((yy - ccy) / (HH * 2) + 0.5, 0, 0.999)
        # Jitter the sample so neighboring holes are not a stamp.
        u = np.clip(u * 0.72 + 0.08 + (i % 5) * 0.03, 0, 0.999)
        v = np.clip(v * 0.72 + 0.1 + (i % 3) * 0.04, 0, 0.999)
        sy = (v * (water.shape[0] - 1)).astype(np.int32)
        sx = (u * (water.shape[1] - 1)).astype(np.int32)
        col = water[sy, sx].astype(np.float32)
        # Broken foam, not a white diamond.
        foam = (d > 0.78) & (d < 0.94) & (((xx + yy + i * 17) % 11) > 7)
        col[foam] = col[foam] * 0.4 + np.array([168.0, 182.0, 172.0]) * 0.6
        plank = ((np.abs((yy - ccy) - 8) < 3) & (np.abs(xx - ccx) < 28) & (((xx + i) % 9) > 2)) | (
            (np.abs((xx - ccx) + 10) < 3) & ((yy - ccy) > -6) & ((yy - ccy) < 14)
        )
        col[plank & (d < 0.9)] = np.array([78.0, 52.0, 32.0])
        base = arr[y0:y1, x0:x1].astype(np.float32)
        base[inside] = col[inside]
        arr[y0:y1, x0:x1] = np.clip(base, 0, 255).astype(np.uint8)


def repaint_plates(write):
    for room_id in room_ids():
        biome = biome_of(room_id)
        if biome not in ("stormspire", "brinewake"):
            continue
        path = os.path.join(ROOMS, room_id, "background_board_2x.webpbin")
        tags = load_tags(room_id)
        arr = np.array(Image.open(path).convert("RGB"))
        cells = [(c["x"], c["y"]) for c in tags["cells"]]
        water = [(c["x"], c["y"]) for c in tags["cells"] if c["terrain"] == "water"]
        if biome == "stormspire":
            paint_lightning(arr, water)
            note = "lightning %d" % len(water)
        else:
            if room_id.startswith("koliseo_"):
                outside = ~deck_mask(cells, arr.shape[0], arr.shape[1])
                paint_sea(arr, outside)
                hull_foam(arr, ~outside, outside)
            paint_holes(arr, water)
            note = "sea holes %d" % len(water)
        if write:
            save_webp(path, arr)
        print(room_id, note)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    for room_id in room_ids():
        notes = ground_room(room_id, args.write)
        print(room_id, "props", len(notes))
    repaint_plates(args.write)


if __name__ == "__main__":
    main()
