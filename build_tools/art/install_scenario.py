#!/usr/bin/env python3
"""Drop Scenario PNGs into the room slots listed in scenario_slots.json.

    python3 build_tools/art/install_scenario.py art/scenario/incoming
    python3 build_tools/art/install_scenario.py windmere_crystal.png stormspire_spire.png

A file matches a slot when its name (without extension) is the slot id.
One crystal / spire / conduit / volcano PNG is resized onto every instance
of that slot. Sea frames replace surround.webpbin. An optional lava-cell
PNG is stamped onto the Koliseo Slagcrown plate. Frost tufts are stored
until the cells are named on the command: --frost room x y
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SLOTS = json.load(open(os.path.join(HERE, "scenario_slots.json")))["slots"]
HW, HH = 64.0, 32.0


def cell_center(x, y):
    return int(((x - y) * 32 + 610) * 2), int(((x + y) * 16 + 366) * 2)


def save_webp(path, image):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, "WEBP", quality=90, method=4)
    print("wrote", path, image.size)


def fit(image, size, transparent):
    mode = "RGBA" if transparent else "RGB"
    return image.convert(mode).resize((int(size[0]), int(size[1])), Image.Resampling.LANCZOS)


def stamp_lava(image):
    plate_path = os.path.join(ROOT, "art/rooms/koliseo_slagcrown/background_board_2x.webpbin")
    tags = json.load(open(os.path.join(ROOT, "art/maps/arena_colosseum_v2/tiled/slagcrown_15x15_tags.json")))
    tile = np.array(fit(image, [128, 64], True)).astype(np.float32)
    plate = np.array(Image.open(plate_path).convert("RGBA")).astype(np.float32)
    h, w = plate.shape[:2]
    for cell in tags["cells"]:
        if cell["terrain"] != "lava":
            continue
        cx, cy = cell_center(cell["x"], cell["y"])
        x0, y0 = cx - 64, cy - 32
        x1, y1 = x0 + 128, y0 + 64
        if x0 < 0 or y0 < 0 or x1 > w or y1 > h:
            continue
        patch = plate[y0:y1, x0:x1]
        alpha = tile[:, :, 3:4] / 255.0
        patch[:, :, :3] = patch[:, :, :3] * (1.0 - alpha) + tile[:, :, :3] * alpha
        patch[:, :, 3] = np.maximum(patch[:, :, 3], tile[:, :, 3])
        plate[y0:y1, x0:x1] = patch
    save_webp(plate_path, Image.fromarray(np.clip(plate, 0, 255).astype(np.uint8)))


def install_one(path, slot):
    image = Image.open(path)
    if slot["id"] == "slagcrown_lava_cell":
        stamp_lava(image)
        return
    if slot["id"] == "windmere_frost_tuft":
        ready = os.path.join(ROOT, "art/scenario/windmere_frost_tuft.webpbin")
        save_webp(ready, fit(image, slot["size"], True))
        print("frost tuft stored. Pass cells with --frost <room> <x> <y> to place it.")
        return
    if "instances" in slot:
        for inst in slot["instances"]:
            save_webp(os.path.join(ROOT, inst["dest"]), fit(image, inst["size"], slot.get("transparent", True)))
        return
    save_webp(os.path.join(ROOT, slot["dest"]), fit(image, slot["size"], slot.get("transparent", True)))


def place_frost(room, x, y):
    src = os.path.join(ROOT, "art/scenario/windmere_frost_tuft.webpbin")
    if not os.path.isfile(src):
        raise SystemExit("no frost tuft stored yet")
    dest_rel = "occluders_2x/frost_%d_%d.webpbin" % (x, y)
    dest = os.path.join(ROOT, "art/rooms", room, dest_rel)
    image = Image.open(src)
    save_webp(dest, image)
    place_path = os.path.join(ROOT, "art/rooms", room, "place.json")
    place = json.load(open(place_path))
    place["occluders"] = [occ for occ in place["occluders"] if occ.get("file") != dest_rel]
    place["occluders"].append({
        "file": dest_rel,
        "cell": [x, y],
        "offset": [-24, -18],
        "what": ["frost_tuft"],
        "size": [48, 28],
    })
    json.dump(place, open(place_path, "w"), separators=(",", ":"), ensure_ascii=False)
    print("placed frost", room, x, y)


def main(argv):
    by_id = {slot["id"]: slot for slot in SLOTS}
    args = list(argv)
    while args and args[0] == "--frost":
        if len(args) < 4:
            raise SystemExit("usage: --frost <room> <x> <y>")
        place_frost(args[1], int(args[2]), int(args[3]))
        args = args[4:]
    files = []
    for arg in args:
        if os.path.isdir(arg):
            for name in sorted(os.listdir(arg)):
                if name.lower().endswith(".png"):
                    files.append(os.path.join(arg, name))
        else:
            files.append(arg)
    if not files and not argv:
        raise SystemExit("pass PNG files or a directory")
    for path in files:
        stem = os.path.splitext(os.path.basename(path))[0]
        slot = by_id.get(stem)
        if slot is None:
            print("skip", path, "(name is not a slot id)")
            continue
        install_one(path, slot)


if __name__ == "__main__":
    main(sys.argv[1:])
