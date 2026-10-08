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
    # Lossy WebP posterizes soft alpha. Props stay lossless; opaque seas stay lossy.
    partial = image.mode == "RGBA" and image.getextrema()[3][0] < 255
    if partial:
        image.save(path, "WEBP", lossless=True, quality=100, method=4)
    else:
        image.convert("RGB").save(path, "WEBP", quality=90, method=4)
    print("wrote", path, image.size, "lossless" if partial else "lossy")


# Per-room volcano files. One PNG each, already at that room's canvas size.
VOLCANO_ROOM = {
    "slagcrown_volcano_koliseo": "koliseo_slagcrown",
    "slagcrown_volcano_stasis_a": "stasis_slagcrown_room_a",
    "slagcrown_volcano_stasis_b": "stasis_slagcrown_room_b",
}
# Ground cells with no prop and no elevation. Visual only.
FROST_CELLS = {
    "koliseo_windmere": [(5, 1), (2, 9), (13, 5)],
    "stasis_windmere_room_a": [(2, 6), (8, 8), (4, 12)],
    "stasis_windmere_room_b": [(3, 1), (8, 2), (10, 6)],
}


def fit(image, size, transparent):
    """Lanczos only. Soft anti-aliased alpha stays; nothing is thresholded."""
    mode = "RGBA" if transparent else "RGB"
    image = image.convert(mode)
    size = (int(size[0]), int(size[1]))
    if image.size == size:
        return image
    return image.resize(size, Image.Resampling.LANCZOS)


def contain_bottom(image, size):
    """Fit the opaque art inside size, centred, base on the bottom edge."""
    image = image.convert("RGBA")
    alpha = np.array(image.getchannel("A"))
    ys, xs = np.where(alpha > 8)
    if len(xs) == 0:
        return fit(image, size, True)
    crop = image.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    tw, th = int(size[0]), int(size[1])
    scale = min(tw / crop.size[0], th / crop.size[1])
    resized = crop.resize((max(1, int(round(crop.size[0] * scale))), max(1, int(round(crop.size[1] * scale)))), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.paste(resized, ((tw - resized.size[0]) // 2, th - resized.size[1]), resized)
    return canvas


def bottom_offset(image, drop):
    """Top-left offset, in plate pixels, that puts the opaque base on the cell."""
    alpha = np.array(image.getchannel("A"))
    ys, xs = np.where(alpha > 8)
    if len(xs) == 0:
        return [-(image.size[0] // 2), drop - image.size[1]]
    base_x = int(round((int(xs.min()) + int(xs.max())) / 2.0))
    base_y = int(ys.max())
    return [int(-base_x), int(drop - base_y)]


def write_occluder(room, kind, image, drop):
    place_path = os.path.join(ROOT, "art", "rooms", room, "place.json")
    place = json.load(open(place_path))
    written = 0
    for occ in place["occluders"]:
        if (occ.get("what") or [""])[0] != kind:
            continue
        path = os.path.join(ROOT, "art", "rooms", room, occ["file"])
        save_webp(path, image)
        occ["size"] = [image.size[0], image.size[1]]
        occ["offset"] = bottom_offset(image, drop)
        written += 1
    json.dump(place, open(place_path, "w"), separators=(",", ":"), ensure_ascii=False)
    print("placed", kind, room, written, image.size)


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


def install_volcano_room(path, room):
    slot = next(item for item in SLOTS if item["id"] == "slagcrown_volcano")
    inst = next(item for item in slot["instances"] if item["room"] == room)
    image = Image.open(path)
    # Koliseo grows to about 1.5 cells (192 plate px) from the full-res cone
    # when that file is beside the slot. Stasis rooms keep their slot canvas.
    full = os.path.join(os.path.dirname(os.path.dirname(path)), "slagcrown", "centre_volcano.png")
    if room == "koliseo_slagcrown" and os.path.isfile(full):
        src = Image.open(full)
        width = 192
        height = max(1, int(round(src.size[1] * (width / float(src.size[0])))))
        image = src.convert("RGBA").resize((width, height), Image.Resampling.LANCZOS)
        placed = image
        write_occluder(room, "volcano", placed, 8)
        return
    placed = fit(image, inst["size"], True)
    dest = os.path.join(ROOT, inst["dest"])
    save_webp(dest, placed)
    write_occluder(room, "volcano", placed, 8)


def install_one(path, slot):
    image = Image.open(path)
    if slot["id"] == "slagcrown_lava_cell":
        print("skip lava cell (busier than the plate lava)")
        return
    if slot["id"] == "windmere_frost_tuft":
        ready = os.path.join(ROOT, "art/scenario/windmere_frost_tuft.webpbin")
        save_webp(ready, fit(image, slot["size"], True))
        for room, cells in FROST_CELLS.items():
            for x, y in cells:
                place_frost(room, x, y)
        return
    if "instances" in slot:
        for inst in slot["instances"]:
            save_webp(os.path.join(ROOT, inst["dest"]), fit(image, inst["size"], slot.get("transparent", True)))
        return
    save_webp(os.path.join(ROOT, slot["dest"]), fit(image, slot["size"], slot.get("transparent", True)))


def install_crystal_variants(paths):
    slot = next(item for item in SLOTS if item["id"] == "windmere_crystal")
    instances = slot["instances"]
    arts = [contain_bottom(Image.open(path), slot["size"]) for path in paths]
    by_room = {}
    for index, inst in enumerate(instances):
        art = arts[index % len(arts)]
        by_room.setdefault(inst["room"], []).append((inst, art))
    for room, items in by_room.items():
        place_path = os.path.join(ROOT, "art", "rooms", room, "place.json")
        place = json.load(open(place_path))
        for inst, art in items:
            dest = os.path.join(ROOT, inst["dest"])
            save_webp(dest, art)
            offset = bottom_offset(art, 12)
            rel = "occluders_2x/" + os.path.basename(inst["dest"])
            for occ in place["occluders"]:
                if occ.get("file") == rel and occ.get("cell") == inst["cell"]:
                    occ["size"] = [art.size[0], art.size[1]]
                    occ["offset"] = offset
        json.dump(place, open(place_path, "w"), separators=(",", ":"), ensure_ascii=False)
        print("crystals", room, len(items))


def install_spire(full_slim):
    """Slim spire at about 2x the old slot, base on the centre of (7,7)."""
    art = contain_bottom(Image.open(full_slim), (104, 220))
    for room in ("koliseo_stormspire", "stasis_stormspire_room_a", "stasis_stormspire_room_b"):
        write_occluder(room, "tower", art, 0)


def install_pack(root):
    """A Scenario drop: slots/*.png plus the full-res sources next to it."""
    slots_dir = root if os.path.isdir(os.path.join(root, "slots")) is False and os.path.basename(root) == "slots" else os.path.join(root, "slots")
    if not os.path.isdir(slots_dir):
        slots_dir = root
    pack = os.path.dirname(slots_dir) if os.path.basename(slots_dir) == "slots" else slots_dir
    by_id = {slot["id"]: slot for slot in SLOTS}
    for name in sorted(os.listdir(slots_dir)):
        if not name.lower().endswith(".png"):
            continue
        stem = os.path.splitext(name)[0]
        path = os.path.join(slots_dir, name)
        if stem == "slagcrown_lava_cell":
            print("skip", name, "(lava tile is busier than the plate)")
            continue
        if stem in ("windmere_crystal", "stormspire_spire", "slagcrown_volcano_koliseo"):
            continue
        if stem in VOLCANO_ROOM:
            install_volcano_room(path, VOLCANO_ROOM[stem])
            continue
        slot = by_id.get(stem)
        if slot is None:
            print("skip", name)
            continue
        install_one(path, slot)
    variants = [os.path.join(pack, "windmere", "prop_ice_crystal_%s.png" % letter) for letter in ("a", "b", "c")]
    if all(os.path.isfile(path) for path in variants):
        install_crystal_variants(variants)
    else:
        crystal = os.path.join(slots_dir, "windmere_crystal.png")
        if os.path.isfile(crystal):
            install_one(crystal, by_id["windmere_crystal"])
    slim = os.path.join(pack, "stormspire", "centre_lightning_spire_slim.png")
    if os.path.isfile(slim):
        install_spire(slim)
    else:
        spire = os.path.join(slots_dir, "stormspire_spire.png")
        if os.path.isfile(spire):
            install_one(spire, by_id["stormspire_spire"])
    volcano = os.path.join(slots_dir, "slagcrown_volcano_koliseo.png")
    full = os.path.join(pack, "slagcrown", "centre_volcano.png")
    if os.path.isfile(full):
        install_volcano_room(volcano if os.path.isfile(volcano) else full, "koliseo_slagcrown")
    elif os.path.isfile(volcano):
        install_volcano_room(volcano, "koliseo_slagcrown")


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
        if os.path.isdir(arg) and (
            os.path.isdir(os.path.join(arg, "slots"))
            or os.path.isfile(os.path.join(arg, "slagcrown_volcano_koliseo.png"))
            or os.path.isfile(os.path.join(arg, "brinewake_room_a_sea.png"))
        ):
            install_pack(arg)
            continue
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
