#!/usr/bin/env python3
"""Install Slagcrown lava set B.

Frames only (f1 is darker than the stills, so the stills stay out).
Each frame is Lanczos-scaled to 256x128 for the phone cell (~175 px).
The plate gets f1 of that cell's variant, so the soft edge sits on the same art.
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PACK = "/tmp/scen_lava_b/slots_b/frames"
OUT = os.path.join(ROOT, "art", "lava", "slagcrown_b")
ROOMS = (
    "koliseo_slagcrown",
    "stasis_slagcrown_room_a",
    "stasis_slagcrown_room_b",
)


def cell_center(x, y):
    return int(((x - y) * 32 + 610) * 2), int(((x + y) * 16 + 366) * 2)


def tags_path(room_id):
    if room_id.startswith("stasis_"):
        return os.path.join(ROOT, "art", "maps", "stasis_v1", "%s_15x15_tags.json" % room_id[len("stasis_"):])
    return os.path.join(ROOT, "art", "maps", "arena_colosseum_v2", "tiled", "%s_15x15_tags.json" % room_id[len("koliseo_"):])


def variant(x, y):
    """0..3. Orthogonal and diagonal neighbours never share it."""
    return (int(x) + 2 * int(y)) % 4


def save_frames():
    os.makedirs(OUT, exist_ok=True)
    for index in range(1, 5):
        for frame in range(1, 4):
            src = Image.open(os.path.join(PACK, "lava_cell_v%d_f%d.png" % (index, frame))).convert("RGBA")
            art = src.resize((256, 128), Image.Resampling.LANCZOS)
            path = os.path.join(OUT, "v%d_f%d.webpbin" % (index, frame))
            art.save(path, "WEBP", lossless=True, quality=100, method=4)
            alpha = np.array(art.getchannel("A"))
            print(path, art.size, "soft", int(((alpha > 8) & (alpha < 247)).sum()))


def stamp_room(room_id):
    path = os.path.join(ROOT, "art", "rooms", room_id, "background_board_2x.webpbin")
    plate = Image.open(path).convert("RGBA")
    frames = [Image.open(os.path.join(PACK, "lava_cell_v%d_f1.png" % (index + 1))).convert("RGBA") for index in range(4)]
    cells = json.load(open(tags_path(room_id)))["cells"]
    count = 0
    for cell in cells:
        if cell["terrain"] != "lava":
            continue
        x, y = int(cell["x"]), int(cell["y"])
        cx, cy = cell_center(x, y)
        plate.alpha_composite(frames[variant(x, y)], (cx - 64, cy - 32))
        count += 1
    rgb = Image.fromarray(np.array(plate.convert("RGB")))
    rgb.save(path, "WEBP", quality=90, method=4)
    print("plate", room_id, count)


def main():
    save_frames()
    for room_id in ROOMS:
        stamp_room(room_id)


if __name__ == "__main__":
    main()
