#!/usr/bin/env python3
"""Install Stormspire tower option B on the Koliseo room only.

Mauro rejected the slate plinths. The tower ring is the bronze dais: grey
stone with aged-bronze trim, and the two pits are bronze-lipped wells with a
violet glow in the opening. Lightning cells and the tower sprite stay as they
are. Cell layout, elevation, offsets, and walk data are untouched.

Floors use (x + 2y) % 4 so orthogonal neighbours differ. Blocks use (x + y) % 2.
The two pits share that parity, so they take (x + y + x // 4) % 2.
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PACK = "/tmp/tower_b/slots/B"
ROOM = "koliseo_stormspire"
# Top face of every elevation block: point-up diamond, same as the Windmere pass.
BLOCK_CX = 65
BLOCK_CY = 32
# Soft bottom of the authored silhouette. Elev 2 is exactly 19px deeper, which
# is the extra offset (-73 vs -53) so both plinths still meet the floor.
SOFT_BOTTOM = {1: 80, 2: 99}
# Median of the ground cells that share an edge with this ring, measured on
# the plate from before the slate pass. The bronze slots are a little lighter;
# halfway toward the flags keeps the inlay and hides the seam.
BORDER_MED = np.array([64.5, 61.0, 67.5], np.float32)
BLEND = 0.55


def cell_center(x, y):
    return ((x - y) * 32 + 610) * 2, ((x + y) * 16 + 366) * 2


def floor_variant(x, y):
    return (int(x) + 2 * int(y)) % 4


def block_variant(x, y):
    return (int(x) + int(y)) % 2


def pit_variant(x, y):
    return (int(x) + int(y) + int(x) // 4) % 2


def save_webp(path, image):
    image.save(path, "WEBP", lossless=True, quality=100, method=4)


def downsample(path, size):
    """Premultiplied Lanczos. Straight-alpha resize fringes the violet seams."""
    arr = np.array(Image.open(path).convert("RGBA")).astype(np.float32)
    prem = arr.copy()
    prem[:, :, :3] *= arr[:, :, 3:4] / 255.0
    small = np.array(
        Image.fromarray(np.clip(prem, 0, 255).astype(np.uint8), "RGBA").resize(
            size, Image.Resampling.LANCZOS
        )
    ).astype(np.float32)
    alpha = small[:, :, 3:4]
    rgb = np.zeros_like(small[:, :, :3])
    ok = alpha[:, :, 0] > 0.5
    rgb[ok] = small[:, :, :3][ok] / (alpha[:, :, 0][ok][:, None] / 255.0)
    out = np.zeros_like(small)
    out[:, :, :3] = np.clip(rgb, 0, 255)
    out[:, :, 3] = small[:, :, 3]
    return out


def tint(img, ratio):
    out = img.copy()
    out[:, :, :3] *= np.asarray(ratio, np.float32).reshape(1, 1, 3)
    np.clip(out[:, :, :3], 0, 255, out=out[:, :, :3])
    return out


def diamond_feather(height, width, px=1.75):
    """1 inside the point-up diamond, falling to 0 over `px` pixels outside it."""
    yy, xx = np.mgrid[0:height, 0:width]
    dist = np.abs(xx + 0.5 - width / 2.0) / (width / 2.0) + np.abs(yy + 0.5 - height / 2.0) / (height / 2.0)
    grad = float(np.hypot(2.0 / width, 2.0 / height))
    outside = (dist - 1.0) / grad
    return np.clip(1.0 - outside / px, 0.0, 1.0).astype(np.float32)


def clamp_diamond(img):
    """Drop Lanczos (or slot) alpha that would land in a neighbour's interior."""
    feather = diamond_feather(img.shape[0], img.shape[1])
    out = img.copy()
    out[:, :, 3] = np.minimum(out[:, :, 3], feather * 255.0)
    return out


def load_rgba(path):
    return np.array(Image.open(path).convert("RGBA")).astype(np.float32)


def floor_ratio(floors):
    meds = []
    for img in floors:
        solid = img[:, :, 3] > 200
        meds.append(np.median(img[:, :, :3][solid], axis=0))
    art = np.mean(meds, axis=0).astype(np.float32)
    target = art + BLEND * (BORDER_MED - art)
    return target / np.maximum(art, 1.0), target


def paint_violet_well(img):
    """Round violet well inside the bronze lip. The grate bars stay on top."""
    height, width = img.shape[:2]
    yy, xx = np.mgrid[0:height, 0:width]
    nx = (xx + 0.5 - width / 2.0) / (width / 2.0)
    ny = (yy + 0.5 - height / 2.0) / (height / 2.0)
    radius = np.sqrt(nx * nx + ny * ny)
    opening = np.clip((0.56 - radius) / 0.20, 0.0, 1.0)
    glow = np.clip(1.0 - radius / 0.52, 0.0, 1.0) ** 1.35
    core = np.array([228.0, 140.0, 255.0], np.float32)
    edge = np.array([96.0, 28.0, 168.0], np.float32)
    well = edge + (core - edge) * glow[:, :, None]
    lum = img[:, :, :3].mean(axis=2) / 255.0
    bars = np.clip((lum - 0.18) / 0.40, 0.0, 1.0)
    # Mostly the glowing well; bronze bars remain visible over it.
    mix = opening * (0.90 - 0.38 * bars) * (img[:, :, 3] / 255.0)
    out = img.copy()
    out[:, :, :3] = img[:, :, :3] * (1.0 - mix[:, :, None]) + well * mix[:, :, None]
    return out


def load_floors():
    # The 128×64 slots are the plate's pixel size. Hires downscales smear alpha
    # into the square corners, and those corners are the next cell's interior.
    raw = []
    for index in range(1, 5):
        raw.append(load_rgba(os.path.join(PACK, "floor_B_v%d.png" % index)))
    ratio, target = floor_ratio(raw)
    print("floor ratio", np.round(ratio, 3), "target", np.round(target, 1))
    floors = [clamp_diamond(tint(img, ratio)) for img in raw]
    pits = []
    for index in range(1, 3):
        lip = tint(load_rgba(os.path.join(PACK, "pit_B_v%d.png" % index)), ratio)
        pits.append(clamp_diamond(paint_violet_well(lip)))
    return floors, pits


def load_blocks():
    """Scale the footprint to 128px. Side median is pulled halfway to the floor."""
    raw = []
    for index, name in enumerate(("block_B_v1_512w.png", "block_B_v2_512w.png"), start=1):
        src = Image.open(os.path.join(PACK, "hires", name))
        width = 128
        height = int(round(src.size[1] * (width / float(src.size[0]))))
        raw.append(downsample(os.path.join(PACK, "hires", name), (width, height)))
    sides = []
    for img in raw:
        h, w = img.shape[:2]
        yy, xx = np.mgrid[0:h, 0:w]
        top = np.abs(xx + 0.5 - 64.0) / 64.0 + np.abs(yy + 0.5 - 32.0) / 32.0 <= 1.0
        side = (img[:, :, 3] > 200) & ~top
        sides.append(np.median(img[:, :, :3][side], axis=0))
    side_med = np.mean(sides, axis=0).astype(np.float32)
    # Leave the bronze. A colour multiply toward the grey flags turns the
    # trim purple. The skirt only has to meet the existing elevation.
    print("block side", np.round(side_med, 1), "untinted")
    return raw


def paste_diamond(plate, sprite, x, y):
    cx, cy = cell_center(x, y)
    x0, y0 = int(cx) - 64, int(cy) - 32
    crop = plate[y0:y0 + 64, x0:x0 + 128].astype(np.float32)
    alpha = sprite[:, :, 3:4] / 255.0
    mixed = sprite[:, :, :3] * alpha + crop[:, :, :3] * (1.0 - alpha)
    plate[y0:y0 + 64, x0:x0 + 128, :3] = np.clip(mixed, 0, 255).astype(np.uint8)
    return x0, y0, sprite[:, :, 3] > 0


def fit_block(src, elevation):
    """Keep the 2:1 top. Stretch only the skirt so elev 2 still meets the floor."""
    canvas_h = 87 if elevation == 1 else 107
    canvas = np.zeros((canvas_h, 131, 4), np.float32)
    soft = np.where(src[:, :, 3] > 8)[0]
    if len(soft) == 0:
        raise SystemExit("empty block sprite")
    src_bot = int(soft[-1])
    target = SOFT_BOTTOM[elevation]
    split = 64
    if src_bot <= split or target <= split:
        raise SystemExit("block silhouette has no skirt %s %s" % (src_bot, target))
    dest_rows = target + 1
    src_y = np.arange(dest_rows, dtype=np.float32)
    below = src_y > split
    src_y[below] = split + (src_y[below] - split) * ((src_bot - split) / float(target - split))
    y0 = np.clip(np.floor(src_y).astype(np.int32), 0, src.shape[0] - 1)
    y1 = np.clip(y0 + 1, 0, src.shape[0] - 1)
    fy = (src_y - y0)[:, None, None]
    # Premultiplied sample so the stretched tip does not fringe.
    prem = src.copy()
    prem[:, :, :3] *= src[:, :, 3:4] / 255.0
    sampled = prem[y0] * (1.0 - fy) + prem[y1] * fy
    alpha = sampled[:, :, 3:4]
    rgb = np.zeros_like(sampled[:, :, :3])
    ok = alpha[:, :, 0] > 0.5
    rgb[ok] = sampled[:, :, :3][ok] / (alpha[:, :, 0][ok][:, None] / 255.0)
    fitted = np.zeros_like(sampled)
    fitted[:, :, :3] = np.clip(rgb, 0, 255)
    fitted[:, :, 3] = np.clip(sampled[:, :, 3], 0, 255)
    fitted[:, :, 3][fitted[:, :, 3] < 4] = 0
    # Image x=64 lands on canvas x=65, the authored diamond centre.
    canvas[:dest_rows, 1:129] = fitted
    return canvas


def ring_cells(cells):
    blocks = [(int(c["x"]), int(c["y"])) for c in cells if int(c.get("elevation", 0)) > 0]
    bset = set(blocks)
    floors, pits = [], []
    for cell in cells:
        x, y = int(cell["x"]), int(cell["y"])
        if (x, y) in bset:
            floors.append((x, y))
            continue
        if int(cell.get("elevation", 0)) != 0:
            continue
        near = min(max(abs(x - bx), abs(y - by)) for bx, by in bset)
        if near != 1:
            continue
        if cell["terrain"] == "mud":
            pits.append((x, y))
        elif cell["terrain"] == "ground":
            floors.append((x, y))
    return floors, pits, bset


def main():
    room = os.path.join(ROOT, "art", "rooms", ROOM)
    plate_path = os.path.join(room, "background_board_2x.webpbin")
    tags = json.load(open(os.path.join(
        ROOT, "art", "maps", "arena_colosseum_v2", "tiled", "stormspire_15x15_tags.json"
    )))
    cells = tags["cells"]
    floors, pits, bset = ring_cells(cells)
    water = [(int(c["x"]), int(c["y"])) for c in cells if c["terrain"] == "water"]
    if water_near_blocks(cells, bset) != 8:
        raise SystemExit("expected 8 lightning cells beside the tower")
    if len(bset) != 27 or set(pits) != {(5, 6), (9, 8)}:
        raise SystemExit("unexpected ring floors %s pits %s blocks %s" % (len(floors), pits, len(bset)))
    if len(floors) != 95:
        raise SystemExit("expected 95 floor diamonds, got %s" % len(floors))

    place_path = os.path.join(room, "place.json")
    place_bytes = open(place_path, "rb").read()
    tower_path = os.path.join(room, "occluders_2x", "centre_tower.webpbin")
    tower_bytes = open(tower_path, "rb").read()

    floor_tex, pit_tex = load_floors()
    block_tex = load_blocks()
    original = np.array(Image.open(plate_path).convert("RGBA"))
    plate = original.copy()
    mask = np.zeros(plate.shape[:2], dtype=bool)
    for x, y in floors:
        x0, y0, alpha = paste_diamond(plate, floor_tex[floor_variant(x, y)], x, y)
        mask[y0:y0 + 64, x0:x0 + 128] |= alpha
    for x, y in pits:
        x0, y0, alpha = paste_diamond(plate, pit_tex[pit_variant(x, y)], x, y)
        mask[y0:y0 + 64, x0:x0 + 128] |= alpha
    if not np.array_equal(plate[~mask], original[~mask]):
        raise SystemExit("pixels outside the tower ring changed")
    for x, y in water:
        if not interior_same(plate, original, x, y):
            raise SystemExit("lightning cell changed %s,%s" % (x, y))
    save_webp(plate_path, Image.fromarray(plate))

    place = json.loads(place_bytes.decode("utf-8"))
    written = 0
    for occ in place.get("occluders", []):
        what = occ.get("what") or []
        if not what or not str(what[0]).startswith("elevation"):
            continue
        elev = int(str(what[0]).split()[-1])
        cell = occ["cell"]
        path = os.path.join(room, occ["file"])
        before = Image.open(path)
        if before.size != (131, 87 if elev == 1 else 107):
            raise SystemExit("unexpected canvas %s %s" % (path, before.size))
        fitted = fit_block(block_tex[block_variant(cell[0], cell[1])], elev)
        if fitted.shape != (before.size[1], before.size[0], 4):
            raise SystemExit("fitted shape %s" % (fitted.shape,))
        soft = np.where(fitted[:, :, 3] > 8)[0]
        if int(soft[-1]) != SOFT_BOTTOM[elev]:
            raise SystemExit("bottom %s != %s for %s" % (soft[-1], SOFT_BOTTOM[elev], path))
        save_webp(path, Image.fromarray(np.clip(fitted, 0, 255).astype(np.uint8)))
        written += 1
    if written != 27:
        raise SystemExit("wrote %s blocks" % written)
    if open(place_path, "rb").read() != place_bytes:
        raise SystemExit("place.json changed")
    if open(tower_path, "rb").read() != tower_bytes:
        raise SystemExit("tower sprite changed")
    print(
        "floors", len(floors), "pits", pits,
        "pit variants", [pit_variant(x, y) for x, y in pits],
        "blocks", written, "plate", os.path.getsize(plate_path),
    )
    write_preview(plate, place, room)


def water_near_blocks(cells, bset):
    count = 0
    for cell in cells:
        if cell["terrain"] != "water":
            continue
        x, y = int(cell["x"]), int(cell["y"])
        near = min(max(abs(x - bx), abs(y - by)) for bx, by in bset)
        if near == 1:
            count += 1
    return count


def interior_same(plate, original, x, y):
    cx, cy = cell_center(x, y)
    x0, y0 = int(cx) - 64, int(cy) - 32
    # Centre of the diamond, clear of the 1-2px soft edge shared with a neighbour.
    return np.array_equal(
        plate[y0 + 16:y0 + 48, x0 + 32:x0 + 96],
        original[y0 + 16:y0 + 48, x0 + 32:x0 + 96],
    )


def write_preview(plate, place, room):
    out_dir = "/tmp/spire_out"
    os.makedirs(out_dir, exist_ok=True)
    # Tower area, cells roughly 2..12. Plate crop plus the occluders in sort order.
    crop = plate[520:1500, 560:1900].copy()
    origin = (560, 520)
    draws = []
    for occ in place.get("occluders", []):
        cell = occ["cell"]
        cx, cy = cell_center(cell[0], cell[1])
        off = occ["offset"]
        kind = str((occ.get("what") or [""])[0])
        # Tower draws after the blocks it stands on, matching the runtime sort.
        elev_flag = 2 if kind == "tower" else (1 if kind.startswith("elevation") else 0)
        draws.append((cell[0] + cell[1], elev_flag, int(cx) + int(off[0]), int(cy) + int(off[1]), occ))
    draws.sort()
    base = Image.fromarray(crop).convert("RGBA")
    for _, _, px, py, occ in draws:
        sprite = Image.open(os.path.join(room, occ["file"])).convert("RGBA")
        base.alpha_composite(sprite, (px - origin[0], py - origin[1]))
    rgb = Image.new("RGB", base.size, (20, 16, 18))
    rgb.paste(base, mask=base.split()[-1])
    rgb.save(os.path.join(out_dir, "tower_area.jpg"), "JPEG", quality=90)
    print("preview", rgb.size)


if __name__ == "__main__":
    main()
