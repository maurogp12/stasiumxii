#!/usr/bin/env python3
"""View-only pass for rooms_0149.

Stasis Brinewake gets its own sea around the hold. Windmere floors, crystals,
and raised blocks calm down. Stormspire props are replaced; the floor plate
and lightning cells stay. Tags and Koliseo Brinewake are not touched.
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw

import paint_blocks

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ROOMS = os.path.join(ROOT, "art", "rooms")
SEA_SRC = "/opt/cursor/artifacts/assets/sea_paint.jpg"
HW, HH = 64.0, 32.0

WIND = (
    "koliseo_windmere",
    "stasis_windmere_room_a",
    "stasis_windmere_room_b",
)
STORM = (
    "koliseo_stormspire",
    "stasis_stormspire_room_a",
    "stasis_stormspire_room_b",
)
BRINE_STASIS = (
    "stasis_brinewake_room_a",
    "stasis_brinewake_room_b",
)
DROP_WIND = {"spark", "ice_shard"}
DROP_STORM = {"arc", "rock_pillar", "spark", "crystal_bolt"}


def cell_center(x, y):
    return int(((x - y) * 32 + 610) * 2), int(((x + y) * 16 + 366) * 2)


def tags_path(room_id):
    if room_id.startswith("stasis_"):
        name = room_id[len("stasis_"):]
        return os.path.join(ROOT, "art", "maps", "stasis_v1", "%s_15x15_tags.json" % name)
    name = room_id[len("koliseo_"):]
    return os.path.join(ROOT, "art", "maps", "arena_colosseum_v2", "tiled", "%s_15x15_tags.json" % name)


def load_tags(room_id):
    return json.load(open(tags_path(room_id)))["cells"]


def save_webp(path, arr):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(path, "WEBP", quality=90, method=4)


def box_mean(lum, radius):
    pad = np.pad(lum, radius, mode="edge")
    total = np.pad(pad, ((1, 0), (1, 0)), mode="constant").cumsum(0).cumsum(1)
    k = radius * 2 + 1
    window = total[k:, k:] - total[:-k, k:] - total[k:, :-k] + total[:-k, :-k]
    return window / float(k * k)


def box_rgb(arr, radius):
    out = np.empty_like(arr)
    for channel in range(3):
        out[:, :, channel] = box_mean(arr[:, :, channel], radius)
    return out


def diamond(h, w, x, y):
    cx, cy = cell_center(x, y)
    yy, xx = np.mgrid[0:h, 0:w]
    return np.abs(xx - cx) / HW + np.abs(yy - cy) / HH, xx, yy, cx, cy


def calm_windmere(room_id):
    path = os.path.join(ROOMS, room_id, "background_board_2x.webpbin")
    arr = np.array(Image.open(path).convert("RGB")).astype(np.float32)
    blur = box_rgb(arr, 6)
    h, w = arr.shape[:2]
    snow = np.array([198.0, 206.0, 216.0], np.float32)
    ice = np.array([128.0, 184.0, 220.0], np.float32)
    mud_col = np.array([122.0, 98.0, 76.0], np.float32)
    out = arr.copy()
    for cell in load_tags(room_id):
        dist, xx, yy, cx, cy = diamond(h, w, cell["x"], cell["y"])
        cover = dist <= 1.0
        if not cover.any():
            continue
        interior = dist < 0.93
        if not interior.any():
            interior = cover
        local = np.median(blur[interior], axis=0)
        varied = blur - local
        kind = cell["terrain"]
        if kind == "water":
            lift = np.clip((cy - yy) / 48.0 + 0.45, 0.0, 1.0)
            col = ice * (0.84 + 0.20 * lift)[..., None]
            sheen = (np.abs((xx - cx) * 0.32 + (yy - cy) + 6) < 5) & (dist < 0.72)
            col[sheen] = col[sheen] * 0.55 + np.array([228.0, 242.0, 250.0]) * 0.45
            rim = (dist > 0.9) & cover
            col[rim] = col[rim] * 0.7 + np.array([196.0, 222.0, 236.0]) * 0.3
            out[cover] = np.clip(col[cover], 0, 255)
        elif kind == "mud":
            col = local * 0.35 + mud_col * 0.65 + varied * 0.22
            out[cover] = np.clip(col[cover], 0, 255)
        else:
            col = local * 0.38 + snow * 0.62 + varied * 0.22
            seed = cell["x"] * 13 + cell["y"] * 7
            seam = cover & (np.abs((xx + yy // 2 + seed) % 52 - 1) < 1)
            col[seam] *= 0.94
            grout = cover & (dist > 0.97)
            col[grout] = col[grout] * 0.88 + local * 0.06
            out[cover] = np.clip(col[cover], 0, 255)
    save_webp(path, out)
    print("floor", room_id)


def paint_crystal(w, h, seed):
    scale = 3
    canvas = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas, "RGBA")
    rng = np.random.RandomState(seed)
    width = w * scale
    height = h * scale
    cx = width * 0.50
    base_y = height - 7 * scale
    count = 2 + int(rng.randint(0, 3))
    shards = []
    for index in range(count):
        center = index == count // 2
        lean = (index - (count - 1) / 2.0) * width * 0.22
        tall = height * (0.78 if center else 0.46 + 0.08 * rng.rand())
        half = width * (0.10 if center else 0.07)
        shards.append((lean, tall, half))
    shards.sort(key=lambda item: item[1])
    draw.ellipse(
        [cx - width * 0.34, base_y - scale, cx + width * 0.34, base_y + 6 * scale],
        fill=(36, 58, 82, 80),
    )
    for index in range(5):
        fx = cx + rng.uniform(-width * 0.28, width * 0.28)
        rad = rng.uniform(2.2, 4.5) * scale
        draw.ellipse([fx - rad, base_y - rad * 0.35, fx + rad, base_y + rad * 0.28], fill=(232, 240, 246, 190))
    for lean, tall, half in shards:
        tip = (cx + lean, base_y - tall)
        left = (cx + lean * 0.2 - half, base_y - 2 * scale)
        right = (cx + lean * 0.2 + half, base_y - scale)
        foot = (cx + lean * 0.15, base_y)
        draw.polygon([tip, left, foot], fill=(104, 150, 186, 255))
        draw.polygon([tip, right, foot], fill=(188, 220, 236, 255))
        cap_l = ((tip[0] * 2 + left[0]) / 3.0, (tip[1] * 2 + left[1]) / 3.0)
        cap_r = ((tip[0] * 2 + right[0]) / 3.0, (tip[1] * 2 + right[1]) / 3.0)
        draw.polygon([tip, cap_l, cap_r], fill=(236, 246, 252, 255))
        draw.line([tip, left, foot], fill=(246, 252, 255, 230), width=scale + 1)
        draw.line([tip, right], fill=(246, 252, 255, 230), width=scale + 1)
        draw.line([tip, foot], fill=(150, 196, 220, 210), width=max(1, scale - 1))
    small = canvas.resize((w, h), Image.Resampling.LANCZOS)
    arr = np.array(small).astype(np.float32)
    alpha = arr[:, :, 3]
    ys, xs = np.where(alpha > 40)
    if len(ys):
        glow_y = ys.min() + (ys.max() - ys.min()) * 0.38
        glow_x = xs.mean()
        yy, xx = np.mgrid[0:h, 0:w]
        fall = np.exp(-(((xx - glow_x) ** 2) / (w * 3.2) + ((yy - glow_y) ** 2) / (h * 1.6)))
        add = fall[..., None] * np.array([18.0, 48.0, 80.0]) * (alpha[..., None] / 255.0)
        arr[:, :, :3] = np.clip(arr[:, :, :3] + add, 0, 255)
    return np.clip(arr, 0, 255).astype(np.uint8)


def repaint_crystals(room_id):
    place_path = os.path.join(ROOMS, room_id, "place.json")
    place = json.load(open(place_path))
    count = 0
    for occ in place["occluders"]:
        if (occ.get("what") or [""])[0] != "crystal":
            continue
        cell = occ["cell"]
        path = os.path.join(ROOMS, room_id, occ["file"])
        image = Image.open(path)
        painted = paint_crystal(image.size[0], image.size[1], cell[0] * 17 + cell[1] * 3 + 5)
        save_webp(path, painted)
        count += 1
    print("crystals", room_id, count)


def drop_props(room_id, names):
    path = os.path.join(ROOMS, room_id, "place.json")
    place = json.load(open(path))
    before = len(place["occluders"])
    place["occluders"] = [occ for occ in place["occluders"] if (occ.get("what") or [""])[0] not in names]
    json.dump(place, open(path, "w"), separators=(",", ":"), ensure_ascii=False)
    print("dropped", room_id, before - len(place["occluders"]))


def paint_spire(w, h):
    scale = 3
    canvas = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas, "RGBA")
    width = w * scale
    height = h * scale
    cx = width * 0.5
    foot = height - 8 * scale
    draw.ellipse([cx - width * 0.42, foot - scale, cx + width * 0.42, foot + 7 * scale], fill=(20, 16, 28, 70))
    # Stepped stone base.
    draw.polygon(
        [(cx - width * 0.34, foot), (cx + width * 0.34, foot), (cx + width * 0.26, foot - 10 * scale), (cx - width * 0.26, foot - 10 * scale)],
        fill=(78, 70, 84, 255),
    )
    draw.polygon(
        [(cx - width * 0.26, foot - 10 * scale), (cx, foot - 10 * scale), (cx, foot), (cx - width * 0.34, foot)],
        fill=(58, 52, 66, 255),
    )
    shaft_top = foot - int(height * 0.46)
    draw.polygon(
        [(cx - width * 0.16, foot - 10 * scale), (cx + width * 0.16, foot - 10 * scale), (cx + width * 0.10, shaft_top), (cx - width * 0.10, shaft_top)],
        fill=(96, 90, 108, 255),
    )
    draw.polygon(
        [(cx - width * 0.16, foot - 10 * scale), (cx, foot - 10 * scale), (cx, shaft_top), (cx - width * 0.10, shaft_top)],
        fill=(68, 62, 78, 255),
    )
    draw.line([(cx - width * 0.10, shaft_top), (cx + width * 0.10, shaft_top)], fill=(168, 176, 188, 255), width=scale + 2)
    # Faceted conductor.
    tip = (cx, 5 * scale)
    left = (cx - width * 0.13, shaft_top + 2 * scale)
    right = (cx + width * 0.13, shaft_top + 2 * scale)
    draw.polygon([tip, left, (cx, shaft_top)], fill=(86, 150, 196, 255))
    draw.polygon([tip, right, (cx, shaft_top)], fill=(186, 226, 244, 255))
    draw.polygon([tip, ((tip[0] + left[0]) / 2, (tip[1] + left[1]) / 2), ((tip[0] + right[0]) / 2, (tip[1] + right[1]) / 2)], fill=(230, 246, 255, 255))
    draw.line([tip, left], fill=(240, 250, 255, 255), width=scale)
    draw.line([tip, right], fill=(240, 250, 255, 255), width=scale)
    # Soft glow behind the crystal, not a filled slab.
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow, "RGBA")
    gdraw.ellipse([cx - width * 0.28, tip[1], cx + width * 0.28, shaft_top + 8 * scale], fill=(70, 170, 230, 36))
    gdraw.ellipse([cx - width * 0.16, tip[1] + 4 * scale, cx + width * 0.16, shaft_top], fill=(150, 110, 220, 28))
    canvas = Image.alpha_composite(glow, canvas)
    return np.array(canvas.resize((w, h), Image.Resampling.LANCZOS))


def paint_rod(w, h, seed):
    scale = 3
    canvas = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas, "RGBA")
    width = w * scale
    height = h * scale
    cx = width * 0.5 + ((seed % 5) - 2)
    foot = height - 6 * scale
    draw.ellipse([cx - width * 0.36, foot - scale, cx + width * 0.36, foot + 5 * scale], fill=(22, 18, 28, 60))
    draw.polygon(
        [(cx - width * 0.32, foot), (cx + width * 0.32, foot), (cx + width * 0.22, foot - 8 * scale), (cx - width * 0.22, foot - 8 * scale)],
        fill=(84, 76, 90, 255),
    )
    top = foot - int(height * 0.55)
    draw.line([(cx, foot - 8 * scale), (cx, top)], fill=(150, 160, 172, 255), width=max(2, scale))
    draw.polygon([(cx, top - 10 * scale), (cx - 4 * scale, top), (cx + 4 * scale, top)], fill=(170, 220, 240, 255))
    draw.ellipse([cx - 7 * scale, top - 12 * scale, cx + 7 * scale, top], fill=(80, 190, 230, 40))
    return np.array(canvas.resize((w, h), Image.Resampling.LANCZOS))


def restyle_storm(room_id):
    path = os.path.join(ROOMS, room_id, "place.json")
    place = json.load(open(path))
    kept = []
    for occ in place["occluders"]:
        kind = (occ.get("what") or [""])[0]
        if kind in DROP_STORM:
            continue
        if kind == "tower":
            size = [44, 92]
            occ["size"] = size
            occ["offset"] = [-22, -82]
            painted = paint_spire(size[0], size[1])
            save_webp(os.path.join(ROOMS, room_id, occ["file"]), painted)
        elif kind == "conduit":
            size = [30, 52]
            occ["size"] = size
            occ["offset"] = [-15, -44]
            painted = paint_rod(size[0], size[1], occ["cell"][0] + occ["cell"][1])
            save_webp(os.path.join(ROOMS, room_id, occ["file"]), painted)
        kept.append(occ)
    place["occluders"] = kept
    json.dump(place, open(path, "w"), separators=(",", ":"), ensure_ascii=False)
    print("storm", room_id, "props", sum(1 for occ in kept if not str(occ["what"][0]).startswith("elevation")))


def deck_mask(cells, h, w):
    yy, xx = np.mgrid[0:h, 0:w]
    mask = np.zeros((h, w), dtype=bool)
    for cell in cells:
        cx, cy = cell_center(cell["x"], cell["y"])
        mask |= (np.abs(xx - cx) / HW + np.abs(yy - cy) / HH) <= 1.0
    return mask


def shift(mask):
    out = np.zeros_like(mask)
    out[1:] |= mask[:-1]
    out[:-1] |= mask[1:]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    return out


def dilate(mask, radius):
    out = mask.copy()
    for _ in range(radius):
        out = out | shift(out)
    return out


def paint_surround(room_id):
    path = os.path.join(ROOMS, room_id, "background_board_2x.webpbin")
    arr = np.array(Image.open(path).convert("RGB")).astype(np.float32)
    h, w = arr.shape[:2]
    outside = ~deck_mask(load_tags(room_id), h, w)
    sea = np.array(Image.open(SEA_SRC).convert("RGB"))
    sea = sea[int(sea.shape[0] * 0.40):]
    room_a = room_id.endswith("_a")
    if room_a:
        sea = np.fliplr(sea)
        tint = np.array([0.70, 0.95, 1.20], np.float32)
        gain = 0.74
    else:
        sea = np.flipud(sea)
        tint = np.array([0.58, 0.78, 0.88], np.float32)
        gain = 0.60
    painted = np.array(Image.fromarray(sea).resize((w, h), Image.Resampling.LANCZOS)).astype(np.float32)
    painted *= gain
    painted *= tint
    yy, xx = np.mgrid[0:h, 0:w]
    if room_a:
        sky = yy < int(h * 0.20)
        painted[sky] = painted[sky] * 0.45 + np.array([16.0, 26.0, 48.0]) * 0.55
        crest = outside & (np.abs((xx + yy) % 96 - 2) < 2) & (yy > int(h * 0.22))
    else:
        sky = (xx > int(w * 0.72)) & (yy < int(h * 0.34))
        painted[sky] = painted[sky] * 0.4 + np.array([12.0, 20.0, 34.0]) * 0.60
        crest = outside & (np.abs((xx - yy) % 120 - 2) < 2)
    painted[crest] = painted[crest] * 0.65 + np.array([150.0, 176.0, 186.0]) * 0.35
    base = arr.copy()
    base[outside] = painted[outside]
    deck = ~outside
    foam = dilate(deck & shift(outside), 2) & outside
    if room_a:
        base[foam] = base[foam] * 0.4 + np.array([150.0, 186.0, 198.0]) * 0.6
    else:
        base[foam] = base[foam] * 0.5 + np.array([130.0, 160.0, 158.0]) * 0.5
    # Distant wreckage, only in the sea.
    layer = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert("RGBA")
    draw = ImageDraw.Draw(layer, "RGBA")
    if room_a:
        draw.polygon([(40, 220), (280, 150), (340, 210), (300, 280), (70, 300)], fill=(18, 24, 36, 230))
        draw.line([(300, 180), (300, 80)], fill=(28, 32, 42, 220), width=4)
        draw.line([(250, 120), (340, 150)], fill=(40, 44, 54, 180), width=2)
        draw.ellipse([250, 168, 276, 194], fill=(190, 130, 60, 90))
    else:
        draw.line([(w - 180, h - 80), (w - 180, h - 320)], fill=(22, 26, 34, 230), width=5)
        draw.line([(w - 260, h - 240), (w - 90, h - 200)], fill=(36, 40, 48, 180), width=2)
        draw.line([(w - 180, h - 300), (w - 80, h - 160)], fill=(36, 40, 48, 140), width=2)
        draw.polygon([(w - 420, h - 140), (w - 250, h - 90), (w - 280, h - 40), (w - 460, h - 70)], fill=(16, 22, 30, 210))
    merged = np.array(layer).astype(np.float32)
    rgb = merged[:, :, :3]
    alpha = merged[:, :, 3:4] / 255.0
    # The draw sat on top of a copy of the whole plate. Keep the deck pixels.
    painted_plate = rgb * alpha + base * (1.0 - alpha)
    painted_plate[deck] = arr[deck]
    save_webp(path, painted_plate)
    print("sea", room_id)


def main():
    for room_id in WIND:
        calm_windmere(room_id)
        repaint_crystals(room_id)
        drop_props(room_id, DROP_WIND)
        paint_blocks.paint_room(room_id, True)
    for room_id in BRINE_STASIS:
        paint_surround(room_id)
    for room_id in STORM:
        restyle_storm(room_id)


if __name__ == "__main__":
    main()
