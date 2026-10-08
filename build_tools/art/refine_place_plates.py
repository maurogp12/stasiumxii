#!/usr/bin/env python3
"""Second pass on the 0.1.147 plates. Cell-aligned. Tags are not written.

  brinewake koliseo  open dark sea around a hull; water cells are flooded holes
  brinewake stasis   the hold; water cells are hull breaches onto the sea
  windmere           ice sheets on the floor; gameplay ice is the clearer sheet
  stormspire         gold cell-lines scrubbed; water cells carry a lightning bolt
  slagcrown          gameplay lava cells are filled with molten rock

  python3 build_tools/art/refine_place_plates.py --write
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ROOMS = "art/rooms"
HW, HH = 64.0, 32.0

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
    return ((x - y) * 32.0 + 610.0) * 2.0, ((x + y) * 16.0 + 366.0) * 2.0


def diamond_samples(cells, h, w):
    ys, xs = [], []
    for x, y in cells:
        cx, cy = cell_center(x, y)
        x0 = max(int(np.floor(cx - HW - 1)), 0)
        x1 = min(int(np.ceil(cx + HW + 1)), w)
        y0 = max(int(np.floor(cy - HH - 1)), 0)
        y1 = min(int(np.ceil(cy + HH + 1)), h)
        if x1 <= x0 or y1 <= y0:
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1]
        inside = np.abs(xx - cx) / HW + np.abs(yy - cy) / HH <= 1.001
        if inside.any():
            ys.append(yy[inside])
            xs.append(xx[inside])
    if not ys:
        return np.zeros(0, np.int32), np.zeros(0, np.int32)
    return np.concatenate(ys), np.concatenate(xs)


def cell_mask(cells, h, w, pad=0.0):
    mask = np.zeros((h, w), np.bool_)
    limit = 1.001 + pad
    for x, y in cells:
        cx, cy = cell_center(x, y)
        x0 = max(int(cx - HW - 2), 0)
        x1 = min(int(cx + HW + 3), w)
        y0 = max(int(cy - HH - 2), 0)
        y1 = min(int(cy + HH + 3), h)
        yy, xx = np.mgrid[y0:y1, x0:x1]
        inside = np.abs(xx - cx) / HW + np.abs(yy - cy) / HH <= limit
        mask[y0:y1, x0:x1] |= inside
    return mask


def value_noise(ix, iy, scale, salt):
    x = ix / scale
    y = iy / scale
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    fx = (x - x0)
    fy = (y - y0)
    fx = fx * fx * (3.0 - 2.0 * fx)
    fy = fy * fy * (3.0 - 2.0 * fy)

    def h(ax, ay):
        n = (ax * 374761393 + ay * 668265263 + int(salt) * 1442695041) & 0xFFFFFFFF
        n = (n ^ (n >> 13)) * np.int64(1274126177) & 0xFFFFFFFF
        return (n & 0xFFFF).astype(np.float32) / 65535.0

    n00 = h(x0, y0)
    n10 = h(x0 + 1, y0)
    n01 = h(x0, y0 + 1)
    n11 = h(x0 + 1, y0 + 1)
    return (n00 * (1 - fx) + n10 * fx) * (1 - fy) + (n01 * (1 - fx) + n11 * fx) * fy


def paint_disc(arr, cx, cy, rx, ry, color, alpha):
    h, w = arr.shape[:2]
    x0 = max(int(cx - rx - 1), 0)
    x1 = min(int(cx + rx + 2), w)
    y0 = max(int(cy - ry - 1), 0)
    y1 = min(int(cy + ry + 2), h)
    if x1 <= x0 or y1 <= y0:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
    a = np.clip(alpha * (1.0 - d), 0, 1)
    sub = arr[y0:y1, x0:x1].astype(np.float32)
    col = np.array(color, np.float32)
    sub = sub * (1 - a)[..., None] + col * a[..., None]
    arr[y0:y1, x0:x1] = np.clip(sub, 0, 255).astype(np.uint8)


def stroke(arr, points, color, radius):
    for px, py in points:
        paint_disc(arr, px, py, radius, radius * 0.65, color, 1.0)


def jagged(x0, y0, x1, y1, salt, steps):
    pts = []
    rng = (salt * 1103515245 + 12345) & 0x7FFFFFFF
    for i in range(steps + 1):
        t = i / steps
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF
        j = ((rng % 1000) / 1000.0 - 0.5) * 10.0
        pts.append((x + j * (1 - t) * t * 4, y + j))
    return pts


def scrub_gold(arr, cells):
    """Yellow cell-lines baked into the stormspire plate."""
    h, w = arr.shape[:2]
    yy, xx = diamond_samples(cells, h, w)
    if yy.size == 0:
        return 0
    pix = arr[yy, xx].astype(np.int16)
    r, g, b = pix[:, 0], pix[:, 1], pix[:, 2]
    gold = (r > 145) & (g > 105) & (b < 120) & (r > b + 35) & (g > b + 12)
    if not gold.any():
        return 0
    # Pull the line back toward the stone next to it.
    stone = np.array([62.0, 54.0, 50.0], np.float32)
    base = arr[yy, xx].astype(np.float32)
    base[gold] = base[gold] * 0.25 + stone * 0.75
    arr[yy, xx] = np.clip(base, 0, 255).astype(np.uint8)
    return int(gold.sum())


def paint_lightning(arr, cells):
    """Charged stone plus bolts, clipped to the cell. Not a purple fill."""
    h, w = arr.shape[:2]
    indigo = np.array([48.0, 58.0, 108.0], np.float32)
    for i, (x, y) in enumerate(cells):
        cx, cy = cell_center(x, y)
        x0 = max(int(cx - HW - 1), 0)
        x1 = min(int(cx + HW + 2), w)
        y0 = max(int(cy - HH - 1), 0)
        y1 = min(int(cy + HH + 2), h)
        yy, xx = np.mgrid[y0:y1, x0:x1]
        d = np.abs(xx - cx) / HW + np.abs(yy - cy) / HH
        inside = d <= 0.94
        base = arr[y0:y1, x0:x1].astype(np.float32)
        base[inside] = base[inside] * 0.62 + indigo * 0.38
        arr[y0:y1, x0:x1] = np.clip(base, 0, 255).astype(np.uint8)
        held = arr[y0:y1, x0:x1].copy()
        paths = (
            jagged(cx - 48, cy - 2, cx + 46, cy + 4, 20 + i * 3, 9),
            jagged(cx - 4, cy - 22, cx + 8, cy + 24, 90 + i * 5, 8),
            jagged(cx - 36, cy + 14, cx + 34, cy - 16, 40 + i * 7, 8),
            jagged(cx - 22, cy + 10, cx + 26, cy - 12, 15 + i * 11, 6),
        )
        for path in paths:
            stroke(arr, path, (36, 72, 168), 9.0)
            stroke(arr, path, (150, 196, 255), 5.5)
            stroke(arr, path, (248, 252, 255), 3.2)
        painted = arr[y0:y1, x0:x1]
        painted[d > 0.96] = held[d > 0.96]


def paint_lava_fill(arr, cells):
    """Most of the diamond is molten. A dark crust stays at the rim."""
    h, w = arr.shape[:2]
    for i, (x, y) in enumerate(cells):
        cx, cy = cell_center(x, y)
        x0 = max(int(cx - HW - 1), 0)
        x1 = min(int(cx + HW + 2), w)
        y0 = max(int(cy - HH - 1), 0)
        y1 = min(int(cy + HH + 2), h)
        yy, xx = np.mgrid[y0:y1, x0:x1]
        d = np.abs(xx - cx) / HW + np.abs(yy - cy) / HH
        inside = d <= 1.001
        if not inside.any():
            continue
        n = value_noise(xx.astype(np.float32), yy.astype(np.float32), 14.0, 30 + i)
        n2 = value_noise(xx.astype(np.float32) + 20, yy.astype(np.float32), 6.0, 4 + i)
        heat = np.clip((0.92 - d) * 1.35 + (n - 0.45) * 0.55, 0, 1)
        crust = np.array([62.0, 24.0, 12.0], np.float32)
        body = np.array([196.0, 64.0, 14.0], np.float32)
        hot = np.array([255.0, 168.0, 48.0], np.float32)
        col = crust * (1 - heat)[..., None] + body * heat[..., None]
        core = (n2 > 0.62) & (d < 0.72)
        col[core] = hot
        # Rim stays rock so the cell is not an orange outline on empty stone.
        rim = d > 0.90
        base = arr[y0:y1, x0:x1].astype(np.float32)
        use = inside & ~rim
        base[use] = col[use]
        arr[y0:y1, x0:x1] = np.clip(base, 0, 255).astype(np.uint8)


def paint_sea(arr, mask_outside):
    h, w = arr.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    n = value_noise(xx.astype(np.float32), yy.astype(np.float32), 28.0, 2)
    n2 = value_noise(xx.astype(np.float32), yy.astype(np.float32), 9.0, 6)
    wave = np.sin(yy * 0.045 + np.sin(xx * 0.012) * 1.6 + n * 2.2)
    deep = np.array([6.0, 16.0, 28.0], np.float32)
    mid = np.array([14.0, 36.0, 52.0], np.float32)
    col = deep * (0.65 + 0.35 * n)[..., None] + (mid - deep) * np.clip(wave * 0.5 + 0.5, 0, 1)[..., None]
    cap = wave > 0.72
    foam = np.array([150.0, 168.0, 162.0], np.float32)
    col[cap] = col[cap] * 0.45 + foam * (0.55 * np.clip(n2[cap], 0, 1))[:, None]
    base = arr.astype(np.float32)
    base[mask_outside] = col[mask_outside]
    arr[...] = np.clip(base, 0, 255).astype(np.uint8)


def paint_hull(arr, deck, outside):
    """A timber gunwale where the deck meets the sea."""
    # Pixels of deck that touch outside, dilated a little onto both sides.
    edge = deck & shift_any(outside)
    band = dilate_bool(edge, 5) & (deck | dilate_bool(deck, 3))
    h, w = arr.shape[:2]
    yy, xx = np.where(band)
    if yy.size == 0:
        return
    wood = np.array([46.0, 30.0, 18.0], np.float32)
    rail = np.array([92.0, 70.0, 44.0], np.float32)
    base = arr[yy, xx].astype(np.float32)
    on_edge = edge[yy, xx]
    base[on_edge] = rail
    base[~on_edge] = base[~on_edge] * 0.35 + wood * 0.65
    arr[yy, xx] = np.clip(base, 0, 255).astype(np.uint8)


def shift_any(mask):
    acc = np.zeros_like(mask)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        acc |= np.roll(np.roll(mask, dy, 0), dx, 1)
    return acc


def dilate_bool(mask, radius):
    out = mask.copy()
    for r in range(1, radius + 1):
        out |= shift_any(out)
    return out


def paint_mast(arr, x, y):
    cx, cy = cell_center(x, y)
    # Broken mast rising up the image, snapped partway.
    stroke(arr, [(cx, cy + 8), (cx + 4, cy - 70)], (38, 26, 16), 5.5)
    stroke(arr, [(cx + 6, cy - 70), (cx + 18, cy - 108)], (52, 36, 22), 4.0)
    # A fallen spar and two rope lines.
    stroke(arr, [(cx - 40, cy - 20), (cx + 46, cy - 36)], (70, 52, 32), 2.2)
    stroke(arr, jagged(cx, cy - 60, cx - 70, cy + 10, 4, 5), (28, 22, 16), 1.2)
    stroke(arr, jagged(cx + 8, cy - 90, cx + 74, cy - 10, 9, 5), (28, 22, 16), 1.2)


def paint_flood_holes(arr, cells):
    """Water cells: seawater with a few broken planks, not a cyan tile."""
    h, w = arr.shape[:2]
    yy, xx = diamond_samples(cells, h, w)
    if yy.size == 0:
        return
    ix = xx.astype(np.float32)
    iy = yy.astype(np.float32)
    n = value_noise(ix, iy, 18.0, 11)
    sea = np.array([10.0, 28.0, 42.0], np.float32)
    deep = np.array([4.0, 12.0, 22.0], np.float32)
    col = deep * (1 - n)[:, None] + sea * n[:, None]
    # Plank scraps along one axis, broken so the sea shows through.
    across = np.mod(-ix + 2.0 * iy, 16.0) / 16.0
    plank = (across > 0.15) & (across < 0.42) & (value_noise(ix, iy, 8.0, 3) > 0.35)
    wood = np.array([74.0, 48.0, 30.0], np.float32)
    col[plank] = wood * (0.75 + 0.25 * n[plank])[:, None]
    arr[yy, xx] = np.clip(col, 0, 255).astype(np.uint8)


def paint_hold(arr, outside, deck):
    """Stasis: dark ribs of the hold, sea in the gaps outside the deck."""
    h, w = arr.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    rib = (np.mod(xx + yy * 0.15, 22.0) < 5.0)
    timber = np.array([36.0, 24.0, 16.0], np.float32)
    gap = np.array([8.0, 18.0, 30.0], np.float32)
    col = np.where(rib[..., None], timber, gap)
    base = arr.astype(np.float32)
    base[outside] = col[outside]
    # Wet the deck a little so the hold is not a dry harbor.
    if deck.any():
        base[deck] = base[deck] * 0.92 + np.array([8.0, 14.0, 18.0], np.float32) * 0.08
    arr[...] = np.clip(base, 0, 255).astype(np.uint8)


def paint_ice_floor(arr, ground_cells, ice_cells):
    """Glossy ice across the arena. Gameplay ice cells are the clearer sheet."""
    h, w = arr.shape[:2]

    def sheet(cells, strength, salt):
        for i, (x, y) in enumerate(cells):
            cx, cy = cell_center(x, y)
            x0 = max(int(cx - HW - 1), 0)
            x1 = min(int(cx + HW + 2), w)
            y0 = max(int(cy - HH - 1), 0)
            y1 = min(int(cy + HH + 2), h)
            yy, xx = np.mgrid[y0:y1, x0:x1]
            d = np.abs(xx - cx) / HW + np.abs(yy - cy) / HH
            inside = d <= 1.001
            n = value_noise(xx.astype(np.float32), yy.astype(np.float32), 20.0, salt + i)
            n2 = value_noise(xx.astype(np.float32), yy.astype(np.float32), 5.0, salt + 9)
            cover = np.clip((n - 0.28) * strength, 0, 0.82)
            ice = np.array([186.0, 214.0, 228.0], np.float32)
            gloss = np.array([236.0, 246.0, 252.0], np.float32)
            base = arr[y0:y1, x0:x1].astype(np.float32)
            mixed = base * (1 - cover)[..., None] + ice * cover[..., None]
            spec = (n2 > 0.72) & inside & (cover > 0.2)
            mixed[spec] = mixed[spec] * 0.4 + gloss * 0.6
            crack = (np.abs(n2 - 0.5) < 0.03) & inside
            mixed[crack] *= 0.62
            base[inside] = mixed[inside]
            arr[y0:y1, x0:x1] = np.clip(base, 0, 255).astype(np.uint8)

    sheet(ground_cells, 1.15, 40)
    sheet(ice_cells, 2.4, 80)


def _cell_window(arr, x, y):
    h, w = arr.shape[:2]
    cx, cy = cell_center(x, y)
    x0 = max(int(cx - HW - 1), 0)
    x1 = min(int(cx + HW + 2), w)
    y0 = max(int(cy - HH - 1), 0)
    y1 = min(int(cy + HH + 2), h)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    d = np.abs(xx - cx) / HW + np.abs(yy - cy) / HH
    return x0, x1, y0, y1, d


def emphasize_gameplay_ice(arr, cells):
    """Gameplay ice is a clear sheet. Decorative frost on the floor stays put."""
    for i, (x, y) in enumerate(cells):
        x0, x1, y0, y1, d = _cell_window(arr, x, y)
        inside = d <= 0.92
        if not inside.any():
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1]
        n = value_noise(xx.astype(np.float32), yy.astype(np.float32), 16.0, 80 + i)
        n2 = value_noise(xx.astype(np.float32), yy.astype(np.float32), 5.0, 91 + i)
        ice = np.array([198.0, 226.0, 246.0], np.float32)
        gloss = np.array([238.0, 248.0, 255.0], np.float32)
        base = arr[y0:y1, x0:x1].astype(np.float32)
        # Replace the interior so a dark plank cannot leave the cell looking like frost.
        scale = (0.90 + 0.08 * n)[..., None]
        base[inside] = (ice * scale)[inside]
        spec = inside & (n2 > 0.66)
        base[spec] = gloss
        crack = inside & (np.abs(n - 0.48) < 0.028)
        base[crack] *= 0.52
        arr[y0:y1, x0:x1] = np.clip(base, 0, 255).astype(np.uint8)


def quench_false_lava(arr, cells):
    """Ground and mud that read as a lava pool go back to rock. Lava cells stay."""
    rock = np.array([54.0, 34.0, 24.0], np.float32)
    for i, (x, y) in enumerate(cells):
        x0, x1, y0, y1, d = _cell_window(arr, x, y)
        inside = d <= 0.94
        if not inside.any():
            continue
        base = arr[y0:y1, x0:x1].astype(np.float32)
        r, g, b = base[:, :, 0], base[:, :, 1], base[:, :, 2]
        hot = inside & (r > 120) & (r > b + 40) & (g < 160)
        if hot.mean() < 0.04:
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1]
        n = value_noise(xx.astype(np.float32), yy.astype(np.float32), 7.0, 12 + i)
        shade = rock * (0.82 + 0.28 * n)[..., None]
        ember = hot & (n > 0.84)
        base[hot] = shade[hot]
        base[ember] = np.array([96.0, 40.0, 18.0], np.float32)
        arr[y0:y1, x0:x1] = np.clip(base, 0, 255).astype(np.uint8)


def paint_boiling(arr, cells):
    """Slagcrown water: a boiling pool, not a dark pit and not lava."""
    for i, (x, y) in enumerate(cells):
        x0, x1, y0, y1, d = _cell_window(arr, x, y)
        inside = d <= 0.90
        if not inside.any():
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1]
        n = value_noise(xx.astype(np.float32), yy.astype(np.float32), 10.0, 21 + i)
        n2 = value_noise(xx.astype(np.float32) + 8, yy.astype(np.float32), 4.5, 33 + i)
        deep = np.array([14.0, 36.0, 44.0], np.float32)
        mid = np.array([32.0, 72.0, 74.0], np.float32)
        col = deep * (1.0 - n)[..., None] + mid * n[..., None]
        bubble = n2 > 0.86
        col[bubble] = np.array([186.0, 108.0, 42.0], np.float32)
        steam = n2 > 0.94
        col[steam] = np.array([206.0, 220.0, 214.0], np.float32)
        base = arr[y0:y1, x0:x1].astype(np.float32)
        base[inside] = col[inside]
        arr[y0:y1, x0:x1] = np.clip(base, 0, 255).astype(np.uint8)


def punch(room_id, biome, tags_path, write):
    """Readability pass. Does not retag cells. Safe to run once on the refined plates."""
    path = os.path.join(ROOT, ROOMS, room_id, "background_board_2x.webpbin")
    tags = json.load(open(os.path.join(ROOT, tags_path)))
    im = Image.open(path).convert("RGB")
    arr = np.array(im)
    water = [(c["x"], c["y"]) for c in tags["cells"] if c["terrain"] == "water"]
    lava = [(c["x"], c["y"]) for c in tags["cells"] if c["terrain"] == "lava"]
    other = [(c["x"], c["y"]) for c in tags["cells"] if c["terrain"] != "lava"]
    note = "unchanged"
    if biome == "windmere":
        emphasize_gameplay_ice(arr, water)
        note = "gameplay ice sheet"
    elif biome == "slagcrown":
        quench_false_lava(arr, other)
        paint_boiling(arr, water)
        note = "lava quenched off non-lava; boiling water"
    elif biome == "stormspire":
        n = scrub_gold(arr, [(c["x"], c["y"]) for c in tags["cells"]])
        paint_lightning(arr, water)
        note = "lightning %d gold" % n
    if write and note != "unchanged":
        Image.fromarray(arr).save(path, "WEBP", quality=90, method=4)
    return {"room": room_id, "water": len(water), "lava": len(lava), "note": note}


def refine(room_id, biome, tags_path, write):
    path = os.path.join(ROOT, ROOMS, room_id, "background_board_2x.webpbin")
    tags = json.load(open(os.path.join(ROOT, tags_path)))
    im = Image.open(path).convert("RGB")
    arr = np.array(im)
    h, w = arr.shape[:2]
    all_cells = [(c["x"], c["y"]) for c in tags["cells"]]
    ground = [(c["x"], c["y"]) for c in tags["cells"] if c["terrain"] == "ground"]
    water = [(c["x"], c["y"]) for c in tags["cells"] if c["terrain"] == "water"]
    lava = [(c["x"], c["y"]) for c in tags["cells"] if c["terrain"] == "lava"]
    deck = cell_mask(all_cells, h, w)
    outside = ~deck
    note = ""
    if biome == "brinewake":
        if room_id.startswith("koliseo_"):
            paint_sea(arr, outside)
            paint_hull(arr, deck, outside)
            paint_mast(arr, 7, 7)
            note = "open sea"
        else:
            paint_hold(arr, outside, deck)
            note = "hold"
        paint_flood_holes(arr, water)
    elif biome == "windmere":
        paint_ice_floor(arr, ground, water)
        note = "ice"
    elif biome == "stormspire":
        n = scrub_gold(arr, all_cells)
        paint_lightning(arr, water)
        note = "gold scrubbed %d" % n
    elif biome == "slagcrown":
        paint_lava_fill(arr, lava)
        note = "lava fill"
    if write:
        Image.fromarray(arr).save(path, "WEBP", quality=90, method=4)
    return {"room": room_id, "water": len(water), "lava": len(lava), "note": note}


def make_crystal(w, h, seed):
    """One whole ice crystal. Hard alpha, no chips around it."""
    arr = np.zeros((h, w, 4), np.float32)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = (w - 1) / 2.0
    # Width profile: point, shoulders, faceted body, flat foot.
    t = yy / max(h - 1, 1)
    half = np.where(
        t < 0.22,
        (w * 0.06) + (w * 0.28) * (t / 0.22),
        np.where(t < 0.78, w * 0.30 - (t - 0.22) * w * 0.08, w * 0.16 * (1.0 - (t - 0.78) / 0.22)),
    )
    inside = np.abs(xx - cx) <= half
    # Facet: left cooler, right lit.
    side = np.clip((xx - cx) / max(w * 0.3, 1), -1, 1)
    ice = np.array([150.0, 196.0, 214.0]) + side[..., None] * np.array([70.0, 40.0, 20.0])
    ice = ice + (1.0 - t)[..., None] * 30.0
    # A core highlight, not a second fragment.
    core = (np.abs(xx - cx) < w * 0.06) & (t > 0.18) & (t < 0.7)
    ice[core] = np.array([236.0, 246.0, 252.0])
    arr[..., :3] = np.clip(ice, 0, 255)
    arr[..., 3] = np.where(inside, 255, 0)
    return arr.astype(np.uint8)


def retarget_crystal(path, place_path, kind):
    place = json.load(open(place_path))
    name = os.path.basename(path)
    entry = None
    for occ in place.get("occluders", []):
        if os.path.basename(occ.get("file", "")) == name:
            entry = occ
            break
    if entry is None:
        return
    old = entry.get("size", [64, 96])
    old_w, old_h = int(old[0]), int(old[1])
    if kind == "crystal":
        w, h = 96, 168
    elif kind == "ice_shard":
        w, h = 72, 128
    else:
        w, h = 56, 96
    seed = old_w * 13 + old_h
    Image.fromarray(make_crystal(w, h, seed)).save(path, "WEBP", quality=90, method=4)
    off = entry.get("offset", [0, 0])
    # Keep the foot and the horizontal centre where the old crop sat.
    entry["offset"] = [
        int(round(float(off[0]) + 0.5 * (old_w - w))),
        int(round(float(off[1]) + (old_h - h))),
    ]
    entry["size"] = [w, h]
    with open(place_path, "w") as f:
        json.dump(place, f, separators=(",", ":"))


def repaint_crystals():
    n = 0
    for room in ("koliseo_windmere", "stasis_windmere_room_a", "stasis_windmere_room_b"):
        place_path = os.path.join(ROOT, ROOMS, room, "place.json")
        place = json.load(open(place_path))
        for occ in place.get("occluders", []):
            what = occ.get("what") or []
            kind = None
            for name in ("crystal", "ice_shard", "spark"):
                if name in what:
                    kind = name
                    break
            if kind is None:
                continue
            path = os.path.join(ROOT, ROOMS, room, occ["file"])
            if os.path.exists(path):
                retarget_crystal(path, place_path, kind)
                n += 1
    return n


def _warm_line(pix):
    r = pix[:, :, 0].astype(np.int16)
    g = pix[:, :, 1].astype(np.int16)
    b = pix[:, :, 2].astype(np.int16)
    return (r > 95) & (g > 70) & (r > b + 18) & (g > b + 6) & (r + g > b * 2 + 40)


def quiet_storm_grid(arr, cells, water):
    """Pull gold cell-lines back into the stone. Water cells are repainted after."""
    water_set = set(water)
    h, w = arr.shape[:2]
    stone = np.array([58.0, 50.0, 46.0], np.float32)
    for x, y in cells:
        x0, x1, y0, y1, d = _cell_window(arr, x, y)
        inner = d <= 0.48
        if not inner.any():
            continue
        base = arr[y0:y1, x0:x1].astype(np.float32)
        if (x, y) in water_set:
            fill = stone
        else:
            fill = np.median(base[inner], axis=0)
        rim = (d > 0.78) & (d <= 1.06)
        yy, xx = np.mgrid[y0:y1, x0:x1]
        n = value_noise(xx.astype(np.float32), yy.astype(np.float32), 18.0, 17 + x + y * 3)
        tint = fill * (0.94 + 0.10 * n)[..., None]
        base[rim] = tint[rim]
        # Any warmer line left inside the diamond goes too.
        warm = _warm_line(base) & (d <= 1.06)
        base[warm] = tint[warm]
        arr[y0:y1, x0:x1] = np.clip(base, 0, 255).astype(np.uint8)


def paint_charged_grate(arr, cells):
    """Electrified floor: dark metal grate and one bolt. Not a blue or purple tile."""
    for i, (x, y) in enumerate(cells):
        x0, x1, y0, y1, d = _cell_window(arr, x, y)
        inside = d <= 0.90
        if not inside.any():
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1]
        cx, cy = cell_center(x, y)
        u = (xx - cx) / HW
        v = (yy - cy) / HH
        n = value_noise(xx.astype(np.float32), yy.astype(np.float32), 36.0, 8 + i)
        iron = np.array([44.0, 42.0, 50.0], np.float32)
        shade = iron * (0.82 + 0.28 * n)[..., None]
        # Grate bars sit in the metal. They are not the cell outline.
        bar = (np.abs(np.mod(u * 3.2 + 0.5, 1.0) - 0.5) < 0.045) | (
            np.abs(np.mod(v * 2.6 + 0.5, 1.0) - 0.5) < 0.055
        )
        grate = np.array([86.0, 92.0, 108.0], np.float32)
        shade[bar] = grate
        base = arr[y0:y1, x0:x1].astype(np.float32)
        base[inside] = shade[inside]
        arr[y0:y1, x0:x1] = np.clip(base, 0, 255).astype(np.uint8)
        held = arr[y0:y1, x0:x1].copy()
        paths = (
            jagged(cx - 36, cy + 4, cx + 34, cy - 2, 20 + i * 5, 8),
            jagged(cx - 8, cy - 14, cx + 6, cy + 16, 70 + i * 3, 6),
        )
        for path in paths:
            stroke(arr, path, (28, 36, 64), 6.5)
            stroke(arr, path, (120, 156, 210), 3.4)
            stroke(arr, path, (236, 244, 255), 1.6)
        painted = arr[y0:y1, x0:x1]
        painted[d > 0.88] = held[d > 0.88]


def paint_open_sea(arr, outside):
    """Dark blue-green water. Swells are wide, with thin crests. Not a noise stripe."""
    h, w = arr.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    swell = np.sin(yy * 0.011 + np.sin(xx * 0.0028) * 1.3)
    ripple = np.sin(yy * 0.023 + xx * 0.0011 + 1.4)
    broad = value_noise(xx, yy, 120.0, 5)
    deep = np.array([5.0, 20.0, 30.0], np.float32)
    mid = np.array([12.0, 46.0, 54.0], np.float32)
    t = np.clip(swell * 0.5 + 0.5, 0, 1)
    col = deep * (1.0 - t)[..., None] + mid * t[..., None]
    col = col * (0.90 + 0.18 * broad)[..., None]
    crest = (swell > 0.62) & (swell < 0.78)
    foam = np.array([176.0, 196.0, 184.0], np.float32)
    col[crest] = col[crest] * 0.28 + foam * 0.72
    glint = (np.abs(ripple) < 0.05) & (swell > 0.15)
    col[glint] = col[glint] * 0.62 + np.array([210.0, 224.0, 214.0], np.float32) * 0.38
    base = arr.astype(np.float32)
    base[outside] = col[outside]
    arr[...] = np.clip(base, 0, 255).astype(np.uint8)


def paint_listing_hull(arr, deck, outside):
    """Timber gunwale, and sea lapping the near (low) edge of the deck."""
    h, w = arr.shape[:2]
    edge = deck & shift_any(outside)
    if not edge.any():
        return
    ys = np.where(deck)[0]
    y_low = float(np.percentile(ys, 62))
    yy, xx = np.mgrid[0:h, 0:w]
    # Sea climbs onto the near side of the hull.
    lap = dilate_bool(outside, 16) & deck & (yy > y_low)
    sea = np.array([14.0, 52.0, 60.0], np.float32)
    foam = np.array([186.0, 204.0, 192.0], np.float32)
    base = arr.astype(np.float32)
    if lap.any():
        base[lap] = sea
        lip = lap & shift_any(deck & ~lap)
        base[lip] = foam
    band = dilate_bool(edge, 6) & ~lap
    if band.any():
        plank = (np.mod(yy, 14) < 8) & band
        wood = np.array([62.0, 40.0, 24.0], np.float32)
        dark = np.array([36.0, 24.0, 16.0], np.float32)
        base[band] = dark
        base[plank] = wood
        base[edge & ~lap] = np.array([108.0, 78.0, 46.0], np.float32)
    arr[...] = np.clip(base, 0, 255).astype(np.uint8)


def paint_broken_mast(arr, x, y):
    cx, cy = cell_center(x, y)
    # Listing a little, snapped partway up.
    stroke(arr, [(cx - 6, cy + 18), (cx + 10, cy - 78)], (48, 32, 18), 6.0)
    stroke(arr, [(cx + 12, cy - 78), (cx + 28, cy - 118)], (64, 42, 24), 4.2)
    stroke(arr, [(cx - 48, cy - 8), (cx + 54, cy - 28)], (78, 56, 32), 2.4)
    stroke(arr, jagged(cx + 4, cy - 70, cx - 78, cy + 16, 4, 6), (32, 24, 16), 1.3)
    stroke(arr, jagged(cx + 14, cy - 100, cx + 86, cy - 6, 9, 6), (32, 24, 16), 1.3)
    # A short run of railing posts along the near side.
    for k in range(-3, 4):
        px = cx + k * 22
        py = cy + 26 + abs(k) * 2
        stroke(arr, [(px, py), (px + 3, py - 16)], (88, 64, 36), 1.8)


def paint_sea_holes(arr, cells):
    """Water cells: blue-green sea, a foam rim, a few broken planks. Not stripes."""
    for i, (x, y) in enumerate(cells):
        x0, x1, y0, y1, d = _cell_window(arr, x, y)
        inside = d <= 0.98
        if not inside.any():
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        cx, cy = cell_center(x, y)
        swell = np.sin((yy - cy) * 0.09 + 0.4 * i)
        n = value_noise(xx, yy, 22.0, 11 + i)
        deep = np.array([8.0, 36.0, 46.0], np.float32)
        mid = np.array([18.0, 72.0, 78.0], np.float32)
        t = np.clip(swell * 0.35 + 0.55 + (n - 0.5) * 0.2, 0, 1)
        col = deep * (1.0 - t)[..., None] + mid * t[..., None]
        foam_band = (d > 0.62) & (d < 0.86) & (n > 0.42)
        col[foam_band] = np.array([190.0, 208.0, 196.0], np.float32)
        # Two short planks near the rim, broken so the sea shows between them.
        u = (xx - cx) / HW
        v = (yy - cy) / HH
        plank = ((np.abs(v - 0.35) < 0.08) & (np.abs(u) < 0.55) & (n > 0.25)) | (
            (np.abs(u + 0.25) < 0.07) & (v > -0.2) & (v < 0.45) & (n > 0.3)
        )
        wood = np.array([86.0, 58.0, 34.0], np.float32)
        col[plank & (d < 0.9)] = wood
        base = arr[y0:y1, x0:x1].astype(np.float32)
        base[inside] = col[inside]
        arr[y0:y1, x0:x1] = np.clip(base, 0, 255).astype(np.uint8)


def paint_flooded_hold(arr, outside, deck):
    """Below deck: planked hull, ribs, a few lanterns. Sea stays in the holes."""
    h, w = arr.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    plank = np.mod(yy, 16) < 10
    rib = np.mod(xx + (yy // 16) * 3, 84) < 7
    timber = np.array([54.0, 36.0, 22.0], np.float32)
    gap = np.array([22.0, 16.0, 12.0], np.float32)
    rib_c = np.array([78.0, 54.0, 32.0], np.float32)
    col = np.where(plank[..., None], timber, gap)
    col[rib] = rib_c
    base = arr.astype(np.float32)
    base[outside] = col[outside]
    arr[...] = np.clip(base, 0, 255).astype(np.uint8)
    # Lanterns in the margin, not on the deck.
    for lx, ly, salt in ((420, 280, 1), (1980, 360, 2), (360, 1500, 3), (2060, 1480, 4)):
        if outside[min(ly, h - 1), min(lx, w - 1)]:
            paint_disc(arr, lx, ly, 18, 14, (255, 186, 90), 0.85)
            paint_disc(arr, lx, ly, 46, 36, (180, 110, 40), 0.28)
    # The deck stays timber, a little wet, not open sea.
    if deck.any():
        wet = arr.astype(np.float32)
        wet[deck] = wet[deck] * 0.9 + np.array([18.0, 22.0, 20.0], np.float32) * 0.1
        arr[...] = np.clip(wet, 0, 255).astype(np.uint8)


def ship_room(room_id, biome, tags_path, write):
    path = os.path.join(ROOT, ROOMS, room_id, "background_board_2x.webpbin")
    tags = json.load(open(os.path.join(ROOT, tags_path)))
    arr = np.array(Image.open(path).convert("RGB"))
    h, w = arr.shape[:2]
    all_cells = [(c["x"], c["y"]) for c in tags["cells"]]
    water = [(c["x"], c["y"]) for c in tags["cells"] if c["terrain"] == "water"]
    deck = cell_mask(all_cells, h, w)
    outside = ~deck
    note = "skipped"
    if biome == "stormspire":
        quiet_storm_grid(arr, all_cells, water)
        paint_charged_grate(arr, water)
        note = "grid scrubbed, charged grate"
    elif biome == "brinewake":
        if room_id.startswith("koliseo_"):
            paint_open_sea(arr, outside)
            paint_listing_hull(arr, deck, outside)
            paint_broken_mast(arr, 7, 7)
            note = "open sea, listing hull"
        else:
            paint_flooded_hold(arr, outside, deck)
            note = "flooded hold"
        paint_sea_holes(arr, water)
    if write and note != "skipped":
        Image.fromarray(arr).save(path, "WEBP", quality=90, method=4)
    return {"room": room_id, "water": len(water), "note": note}


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--punch", action="store_true",
                        help="readability pass: ice sheet, clipped lightning, filled lava only")
    parser.add_argument("--ship", action="store_true",
                        help="stormspire grid/grate and brinewake sea only")
    args = parser.parse_args()
    if args.ship:
        for room_id, biome, tags in ROOMS_FOR:
            if biome not in ("stormspire", "brinewake"):
                continue
            info = ship_room(room_id, biome, tags, args.write)
            print(info["room"], "water", info["water"], info["note"])
        return
    if args.punch:
        for room_id, biome, tags in ROOMS_FOR:
            if biome == "brinewake":
                continue
            info = punch(room_id, biome, tags, args.write)
            print(info["room"], "water", info["water"], "lava", info["lava"], info["note"])
        return
    for room_id, biome, tags in ROOMS_FOR:
        info = refine(room_id, biome, tags, args.write)
        print(info["room"], "water", info["water"], "lava", info["lava"], info["note"])
    if args.write:
        print("crystals", repaint_crystals())


if __name__ == "__main__":
    main()
