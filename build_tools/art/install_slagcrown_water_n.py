#!/usr/bin/env python3
"""Paint Slagcrown water cells with the lava-lake crust (option N).

Mauro rejected the pale pools and the lava-fall pits. Every water cell on the
Koliseo and both stasis rooms gets lavalake_N v1-v4, chosen by (x + 2y) % 4
so an orthogonal neighbour never repeats. Solid lava cells stay byte-identical
in their interiors. The tall steam columns are a runtime effect and are not
touched here. No waterfall or pit prop is installed; these are flat diamonds.
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PACK = "/tmp/lava_n/slots/N"
ROOMS = (
    "koliseo_slagcrown",
    "stasis_slagcrown_room_a",
    "stasis_slagcrown_room_b",
)


def cell_center(x, y):
    return int(((x - y) * 32 + 610) * 2), int(((x + y) * 16 + 366) * 2)


def tags_path(room_id):
    if room_id.startswith("stasis_"):
        name = room_id[len("stasis_"):]
        return os.path.join(ROOT, "art", "maps", "stasis_v1", "%s_15x15_tags.json" % name)
    name = room_id[len("koliseo_"):]
    return os.path.join(ROOT, "art", "maps", "arena_colosseum_v2", "tiled", "%s_15x15_tags.json" % name)


def variant(x, y):
    return (int(x) + 2 * int(y)) % 4


def diamond_dist(height, width):
    yy, xx = np.mgrid[0:height, 0:width]
    return np.abs(xx + 0.5 - width / 2.0) / (width / 2.0) + np.abs(yy + 0.5 - height / 2.0) / (height / 2.0)


def load_slots():
    slots = []
    for index in range(1, 5):
        img = np.array(Image.open(os.path.join(PACK, "lavalake_N_v%d.png" % index)).convert("RGBA")).astype(np.float32)
        if img.shape[0] != 64 or img.shape[1] != 128:
            raise SystemExit("slot %d is %s, expected 64x128" % (index, img.shape))
        dist = diamond_dist(64, 128)
        if int(((dist > 1.01) & (img[:, :, 3] > 8)).sum()) != 0:
            raise SystemExit("slot %d alpha leaves the diamond" % index)
        slots.append(img)
    return slots


def interior(arr, x, y, limit=0.72):
    cx, cy = cell_center(x, y)
    crop = arr[cy - 32:cy + 32, cx - 64:cx + 64]
    dist = diamond_dist(64, 128)
    return crop[dist < limit]


def stamp_room(room_id, slots):
    path = os.path.join(ROOT, "art", "rooms", room_id, "background_board_2x.webpbin")
    place_path = os.path.join(ROOT, "art", "rooms", room_id, "place.json")
    place_before = open(place_path, "rb").read()
    original = np.array(Image.open(path).convert("RGBA"))
    plate = original.astype(np.float32)
    cells = json.load(open(tags_path(room_id)))["cells"]
    water = [(int(c["x"]), int(c["y"])) for c in cells if c["terrain"] == "water"]
    lava = [(int(c["x"]), int(c["y"])) for c in cells if c["terrain"] == "lava"]
    if not water:
        raise SystemExit("%s has no water" % room_id)
    for x, y in water:
        tile = slots[variant(x, y)]
        cx, cy = cell_center(x, y)
        x0, y0 = cx - 64, cy - 32
        x1, y1 = x0 + 128, y0 + 64
        if x0 < 0 or y0 < 0 or x1 > plate.shape[1] or y1 > plate.shape[0]:
            raise SystemExit("%s water %s falls off the plate" % (room_id, (x, y)))
        patch = plate[y0:y1, x0:x1]
        alpha = tile[:, :, 3:4] / 255.0
        patch[:, :, :3] = tile[:, :, :3] * alpha + patch[:, :, :3] * (1.0 - alpha)
    out = np.clip(np.round(plate), 0, 255).astype(np.uint8)
    # Lava interiors stay the painted Lava B still. The crust's own alpha
    # stops at the water diamond, so a neighbour's interior is untouched.
    for x, y in lava:
        before = interior(original, x, y)
        after = interior(out, x, y)
        if not np.array_equal(before, after):
            raise SystemExit("%s lava interior changed %s" % (room_id, (x, y)))
    changed = np.any(out[:, :, :3] != original[:, :, :3], axis=2)
    # Every changed pixel sits under some water slot's alpha.
    cover = np.zeros(out.shape[:2], np.uint8)
    for x, y in water:
        tile = slots[variant(x, y)]
        cx, cy = cell_center(x, y)
        cover[cy - 32:cy + 32, cx - 64:cx + 64] |= (tile[:, :, 3] > 0).astype(np.uint8)
    leaked = int((changed & (cover == 0)).sum())
    if leaked:
        raise SystemExit("%s changed %d pixels outside the water diamonds" % (room_id, leaked))
    if not np.array_equal(out[:, :, 3], original[:, :, 3]):
        raise SystemExit("%s plate alpha changed" % room_id)
    # The crust is orange-black, not the pale teal pool.
    sample = interior(out, water[0][0], water[0][1], 0.45)
    med = np.median(sample[:, :3], axis=0)
    if med[0] < med[2]:
        raise SystemExit("%s water still reads cool %s" % (room_id, med))
    Image.fromarray(out, "RGBA").save(path, "WEBP", lossless=True, quality=100, method=4)
    if open(place_path, "rb").read() != place_before:
        raise SystemExit("%s place.json changed" % room_id)
    print(room_id, "water", len(water), "lava", len(lava), "changed", int(changed.sum()), "median", med.round(1))


def main():
    slots = load_slots()
    for room_id in ROOMS:
        stamp_room(room_id, slots)


if __name__ == "__main__":
    main()
