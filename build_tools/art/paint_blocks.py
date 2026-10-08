#!/usr/bin/env python3
"""Repaint elevation blocks with each room's own floor.

The top face keeps the current footprint. A short side and a soft contact
shadow sit in the canvas below it. Tags, offsets, and every other sprite stay
put. Run: python3 build_tools/art/paint_blocks.py --write
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ROOMS = os.path.join(ROOT, "art", "rooms")
BIOMES = ("brinewake", "windmere", "stormspire", "slagcrown")


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
    return int(((x - y) * 32 + 610) * 2), int(((x + y) * 16 + 366) * 2)


def save_webp(path, arr):
    Image.fromarray(arr).save(path, "WEBP", quality=90, method=4)


def bad_material(rgb, biome):
    r = rgb[:, :, 0]
    g = rgb[:, :, 1]
    b = rgb[:, :, 2]
    if biome == "stormspire":
        return ((b > r + 18) & (b > 90)) | ((b > 170) & (g > 130))
    if biome == "slagcrown":
        return (r > 155) & (r > g + 55) & (r > b + 70)
    if biome == "brinewake":
        return (b > r + 18) & (g > r + 6) & (b > 75) & (g > 55)
    return np.zeros(r.shape, dtype=bool)


def blue_cast(rgb):
    med = np.median(rgb.reshape(-1, 3), axis=0)
    return med[2] > med[0] + 8 and med[2] > 55


def box_mean(lum, radius):
    pad = np.pad(lum, radius, mode="edge")
    total = np.pad(pad, ((1, 0), (1, 0)), mode="constant").cumsum(0).cumsum(1)
    k = radius * 2 + 1
    window = total[k:, k:] - total[:-k, k:] - total[k:, :-k] + total[:-k, :-k]
    return window / float(k * k)


def fill_from_good(color, good, region):
    out = color.copy()
    known = good.copy()
    h, w = known.shape
    for _ in range(48):
        need = region & ~known
        if not need.any():
            break
        acc = np.zeros_like(out)
        weight = np.zeros((h, w), np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            sy = slice(max(0, -dy), h - max(0, dy))
            dy_ = slice(max(0, dy), h - max(0, -dy))
            sx = slice(max(0, -dx), w - max(0, dx))
            dx_ = slice(max(0, dx), w - max(0, -dx))
            src = known[sy, sx]
            acc[dy_, dx_][src] += out[sy, sx][src]
            weight[dy_, dx_][src] += 1.0
        take = need & (weight > 0)
        if not take.any():
            break
        out[take] = acc[take] / weight[take, None]
        known |= take
    still = region & ~known
    if still.any() and known.any():
        out[still] = out[known].mean(axis=0)
    return out


def donor_patch(bg, biome):
    """A stone/wood/ice patch with no hazard paint, used when a cell is a grate."""
    height, width = bg.shape[:2]
    best = None
    best_score = -1.0
    for y in range(2, 13):
        for x in range(2, 13):
            cx, cy = cell_center(x, y)
            if cy - 36 < 0 or cx - 72 < 0 or cy + 36 >= height or cx + 72 >= width:
                continue
            crop = bg[cy - 36:cy + 36, cx - 72:cx + 72]
            if bad_material(crop, biome).mean() > 0.02:
                continue
            if biome == "stormspire" and blue_cast(crop):
                continue
            score = float(crop.std())
            if score > best_score:
                best_score = score
                best = crop.copy()
    if best is None:
        best = bg[400:544, 800:1088].copy()
    return best


def sample_top(bg, top, origin, biome, cell, donor):
    h, w = top.shape
    ox, oy = origin
    ys, xs = np.mgrid[0:h, 0:w]
    px = ox + xs
    py = oy + ys
    height, width = bg.shape[:2]
    inside = top & (px >= 0) & (py >= 0) & (px < width) & (py < height)
    sampled = np.zeros((h, w, 3), np.float32)
    sampled[inside] = bg[py[inside], px[inside]]
    good = inside & ~bad_material(sampled, biome)
    cast = biome == "stormspire" and inside.any() and blue_cast(sampled[inside])
    if cast or good.mean() < 0.004 or (top.sum() > 0 and good.sum() < top.sum() * 0.55):
        # Hazard paint covers this cell. Borrow the room's floor grain.
        dh, dw = donor.shape[:2]
        shift = (cell[0] * 17 + cell[1] * 9) % max(dw // 3, 1)
        sx = (xs + shift) % dw
        sy = (ys * 2) % dh
        sampled = donor[sy, sx].astype(np.float32)
        return sampled
    if (~good & top).any():
        sampled = fill_from_good(sampled, good, top)
    return sampled


def stylize(rgb, top, biome, cell, elev):
    h, w = rgb.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    ys, xs = np.where(top)
    y0, y1 = int(ys.min()), int(ys.max())
    yn = (yy - y0) / float(max(y1 - y0, 1))
    out = rgb * (1.06 - 0.10 * yn)[..., None]
    rng = np.random.RandomState(cell[0] * 131 + cell[1] * 17 + elev * 3 + 11)
    if biome == "windmere":
        noise = rng.rand(h, w).astype(np.float32)
        noise = box_mean(noise, 4)
        snow = np.array([234.0, 240.0, 246.0], np.float32)
        amount = np.zeros((h, w), np.float32)
        amount += np.clip(0.38 * (0.48 - yn), 0, 0.38)
        amount = np.maximum(amount, np.where(noise > 0.70, 0.22, 0.0))
        amount = np.clip(amount, 0, 0.46)
        out = out * (1.0 - amount[..., None]) + snow * amount[..., None]
    elif biome == "stormspire":
        out = out * 1.18 + 7.0
        lum = out.mean(axis=2)
        carved = lum < box_mean(lum, 2) - 7.0
        out[carved] *= 0.70
    elif biome == "slagcrown":
        lum = out.mean(axis=2)
        crack = top & (lum < box_mean(lum, 2) - 11.0)
        if top.any() and crack.sum() < top.sum() * 0.035:
            grain = box_mean(rng.rand(h, w).astype(np.float32), 2)
            crack = crack | (top & (np.abs(grain - 0.52) < 0.035) & (lum < np.median(lum[top]) + 6))
        ember = np.array([132.0, 42.0, 14.0], np.float32)
        out[crack] = out[crack] * 0.74 + ember * 0.26
        near = top & ~crack & (box_mean(crack.astype(np.float32), 1) > 0.2)
        out[near] = out[near] * 0.92 + ember * 0.08
    elif biome == "brinewake":
        out *= np.array([1.05, 0.97, 0.86], np.float32)
        # Board seams across the slab, in the deck's wood rather than a new color.
        seam = top & (np.abs((yy + xx // 2 + cell[1]) % 15 - 1) < 1)
        out[seam] *= 0.72
    out = np.clip(out, 0, 255)
    if biome == "stormspire":
        # Lightning left on a raised cell is not floor stone.
        excess = out[:, :, 2] - np.maximum(out[:, :, 0], out[:, :, 1]) - 4.0
        out[:, :, 2] -= np.clip(excess, 0, 255) * 0.9
        hot = out.mean(axis=2) > 145.0
        stone = np.array([72.0, 62.0, 56.0], np.float32)
        out[hot] = out[hot] * 0.35 + stone * 0.65
    return np.clip(out, 0, 255)


def paint_block(bg, donor, path, cell, offset, biome, elev):
    im = np.array(Image.open(path).convert("RGBA"))
    h, w = im.shape[:2]
    top = im[:, :, 3] > 200
    if not top.any():
        return None
    ox, oy = int(offset[0]), int(offset[1])
    cx, cy = cell_center(cell[0], cell[1])
    sampled = sample_top(bg, top, (cx + ox, cy + oy), biome, cell, donor)
    color = stylize(sampled, top, biome, cell, elev)

    out = np.zeros((h, w, 4), np.uint8)
    out[top, :3] = np.clip(color[top], 0, 255).astype(np.uint8)
    out[top, 3] = 255

    if biome == "windmere":
        # A snow cap on a pale stone lip. The dark skirt was reading as a box.
        side_h = 14 if elev >= 2 else 9
        shadow_h = 5
        shadow_peak = 34.0
    else:
        side_h = 16 if elev >= 2 else 12
        shadow_h = 8
        shadow_peak = 88.0
    side_rgb = np.zeros((h, w, 3), np.float32)
    side = np.zeros((h, w), dtype=bool)
    shadow_a = np.zeros((h, w), np.float32)
    for x in range(w):
        rows = np.where(top[:, x])[0]
        if len(rows) == 0:
            continue
        yb = int(rows.max())
        lip = color[yb, x].astype(np.float32)
        for k in range(1, side_h + 1):
            y = yb + k
            if y >= h or top[y, x]:
                break
            if biome == "windmere":
                shade = 0.96 - 0.14 * (k / float(side_h))
            else:
                shade = 0.70 - 0.34 * (k / float(side_h))
            if biome == "brinewake" and (x + cell[0]) % 16 == 0:
                shade *= 0.62
            elif biome == "stormspire" and k % 6 == 0:
                shade *= 0.78
            elif biome == "slagcrown" and (x * 2 + k) % 19 == 0:
                shade *= 0.70
            pix = lip * shade
            if k <= 2 and biome == "windmere":
                pix = pix * 0.55 + np.array([228.0, 236.0, 244.0]) * 0.45
            elif k == 1:
                pix = np.minimum(lip * 0.92, 230.0)
            side_rgb[y, x] = pix
            side[y, x] = True
        for k in range(1, shadow_h + 1):
            y = yb + side_h + k
            if y >= h or top[y, x] or side[y, x]:
                continue
            fade = (1.0 - k / float(shadow_h + 1)) ** 1.35
            shadow_a[y, x] = max(shadow_a[y, x], shadow_peak * fade)
            spill = shadow_peak * 0.45 * fade
            if x > 0:
                shadow_a[y, x - 1] = max(shadow_a[y, x - 1], spill)
            if x + 1 < w:
                shadow_a[y, x + 1] = max(shadow_a[y, x + 1], spill)
    out[side, :3] = np.clip(side_rgb[side], 0, 255).astype(np.uint8)
    out[side, 3] = 255
    shade_px = ~top & ~side & (shadow_a > 2)
    if biome == "windmere":
        out[shade_px, :3] = (18, 24, 32)
    else:
        out[shade_px, :3] = (8, 6, 6)
    out[shade_px, 3] = np.clip(shadow_a[shade_px], 0, 120).astype(np.uint8)

    rgb = out[:, :, :3].astype(np.int16)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    gold = (out[:, :, 3] > 20) & (r > 145) & (g > 100) & (r > b + 30) & (g > b + 8)
    if gold.any():
        stone = np.median(out[top, :3].astype(np.float32), axis=0)
        base = out[:, :, :3].astype(np.float32)
        base[gold] = base[gold] * 0.30 + stone * 0.70
        out[:, :, :3] = np.clip(base, 0, 255).astype(np.uint8)
    return out


def load_bg(room):
    path = os.path.join(ROOMS, room, "background_board_2x.webpbin")
    return np.array(Image.open(path).convert("RGB"))


def paint_room(room, write):
    biome = biome_of(room)
    bg = load_bg(room)
    donor = donor_patch(bg, biome)
    place = json.load(open(os.path.join(ROOMS, room, "place.json")))
    changed = 0
    for occ in place.get("occluders", []):
        what = occ.get("what") or []
        if not what or not str(what[0]).startswith("elevation"):
            continue
        elev = 2 if "2" in str(what[0]) else 1
        path = os.path.join(ROOMS, room, occ["file"])
        painted = paint_block(bg, donor, path, occ["cell"], occ.get("offset", [0, 0]), biome, elev)
        if painted is None:
            continue
        if write:
            save_webp(path, painted)
        changed += 1
    return changed


def preview():
    os.makedirs("/tmp/blockprev", exist_ok=True)
    for room in ("koliseo_windmere", "koliseo_stormspire", "koliseo_slagcrown", "koliseo_brinewake"):
        biome = biome_of(room)
        bg = load_bg(room)
        donor = donor_patch(bg, biome)
        place = json.load(open(os.path.join(ROOMS, room, "place.json")))
        plate = np.array(Image.open(os.path.join(ROOMS, room, "background_board_2x.webpbin")).convert("RGBA"))
        items = []
        for occ in place.get("occluders", []):
            what = occ.get("what") or []
            if not what or not str(what[0]).startswith("elevation"):
                continue
            elev = 2 if "2" in str(what[0]) else 1
            path = os.path.join(ROOMS, room, occ["file"])
            sprite = paint_block(bg, donor, path, occ["cell"], occ.get("offset", [0, 0]), biome, elev)
            cell = occ["cell"]
            z = (cell[0] + cell[1]) * 10 + elev * 8
            items.append((z, cell, occ.get("offset", [0, 0]), sprite))
        for _z, cell, offset, sprite in sorted(items, key=lambda item: item[0]):
            cx, cy = cell_center(cell[0], cell[1])
            x0 = cx + int(offset[0])
            y0 = cy + int(offset[1])
            sh, sw = sprite.shape[:2]
            x1, y1 = min(plate.shape[1], x0 + sw), min(plate.shape[0], y0 + sh)
            if x0 >= x1 or y0 >= y1:
                continue
            cut = sprite[: y1 - y0, : x1 - x0]
            alpha = cut[:, :, 3:4].astype(np.float32) / 255.0
            dst = plate[y0:y1, x0:x1]
            dst[:, :, :3] = (cut[:, :, :3] * alpha + dst[:, :, :3] * (1.0 - alpha)).astype(np.uint8)
            dst[:, :, 3] = 255
        # Center of the arena, where the flat slabs read worst.
        crop = plate[620:1500, 700:1800]
        Image.fromarray(crop).resize((crop.shape[1] // 2, crop.shape[0] // 2), Image.BILINEAR).save(
            "/tmp/blockprev/%s_preview.png" % room
        )
        print("preview", room, crop.shape)


def main():
    write = "--write" in sys.argv
    if "--preview" in sys.argv:
        preview()
        return
    total = 0
    for room in room_ids():
        n = paint_room(room, write)
        total += n
        print("%s %d" % (room, n))
    print("blocks", total, "write" if write else "dry")


if __name__ == "__main__":
    main()
