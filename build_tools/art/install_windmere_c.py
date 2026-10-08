#!/usr/bin/env python3
"""Install Windmere option C (Mauro, 2026-10-08).

Ice hazard cells (terrain water) are replaced with ice_C v1-v4.
Snow ground is retextured with snow_C and multiplied by the cell's own
luminance, so seams stay. Mud, crystals, and frost tufts are not touched.
Raised blocks keep their side faces byte for byte; only the top diamond
is recolored, with the same luminance multiply.

Variant is (x + 2y) % 4, matching the lava cells, so neighbours differ.
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PACK = "/tmp/scen_windmere"
OUT = os.path.join(ROOT, "art", "windmere", "alive")
ROOMS = (
    "koliseo_windmere",
    "stasis_windmere_room_a",
    "stasis_windmere_room_b",
)
# Top face of every elevation block: point-up diamond in the sprite.
BLOCK_CX = 65.0
BLOCK_CY = 32.0
BLOCK_HW = 64.0
BLOCK_HH = 32.0


def cell_center(x, y):
    return ((x - y) * 32 + 610) * 2, ((x + y) * 16 + 366) * 2


def tags_path(room_id):
    if room_id.startswith("stasis_"):
        name = room_id[len("stasis_"):]
        return os.path.join(ROOT, "art", "maps", "stasis_v1", "%s_15x15_tags.json" % name)
    name = room_id[len("koliseo_"):]
    return os.path.join(ROOT, "art", "maps", "arena_colosseum_v2", "tiled", "%s_15x15_tags.json" % name)


def variant(x, y):
    return (int(x) + 2 * int(y)) % 4


def diamond_mask():
    yy, xx = np.mgrid[0:64, 0:128]
    return np.abs(xx + 0.5 - 64.0) / 64.0 + np.abs(yy + 0.5 - 32.0) / 32.0 <= 1.0


def save_webp(path, image):
    image.save(path, "WEBP", lossless=True, quality=100, method=4)


def load_slots():
    ice, snow = [], []
    for index in range(1, 5):
        ice.append(np.array(Image.open(os.path.join(PACK, "slots", "C", "ice_C_v%d.png" % index)).convert("RGBA")))
        snow.append(np.array(Image.open(os.path.join(PACK, "slots", "C", "snow_C_v%d.png" % index)).convert("RGBA")))
    return ice, snow


def load_hires():
    ice, snow = [], []
    for index in range(1, 5):
        ice.append(np.array(Image.open(
            os.path.join(PACK, "slots", "C", "hires", "ice_C_v%d_512x256.png" % index)).convert("RGBA"), np.float32))
        snow.append(np.array(Image.open(
            os.path.join(PACK, "slots", "C", "hires", "snow_C_v%d_512x256.png" % index)).convert("RGBA"), np.float32))
    return ice, snow


def paste_cell(plate, slot, cx, cy, shade):
    x0, y0 = int(cx) - 64, int(cy) - 32
    crop = plate[y0:y0 + 64, x0:x0 + 128]
    src = slot.astype(np.float32)
    alpha = (src[:, :, 3] / 255.0) * MASK
    if shade:
        lum = crop[:, :, :3].astype(np.float32).mean(axis=2)
        med = float(np.median(lum[MASK]))
        if med < 1.0:
            med = 1.0
        ratio = np.clip(lum / med, 0.35, 1.75)
        rgb = np.clip(src[:, :, :3] * ratio[:, :, None], 0, 255)
    else:
        rgb = src[:, :, :3]
        med = 0.0
    base = crop[:, :, :3].astype(np.float32)
    mixed = rgb * alpha[:, :, None] + base * (1.0 - alpha[:, :, None])
    crop[:, :, :3] = np.clip(mixed, 0, 255).astype(np.uint8)
    return med


def sample_hires(tex, u, v):
    """Bilinear sample. u,v are 0..1 across the diamond."""
    x = np.clip(u, 0, 1) * (tex.shape[1] - 1)
    y = np.clip(v, 0, 1) * (tex.shape[0] - 1)
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    x1 = np.clip(x0 + 1, 0, tex.shape[1] - 1)
    y1 = np.clip(y0 + 1, 0, tex.shape[0] - 1)
    fx = (x - x0)[:, :, None]
    fy = (y - y0)[:, :, None]
    c00 = tex[y0, x0]
    c10 = tex[y0, x1]
    c01 = tex[y1, x0]
    c11 = tex[y1, x1]
    return c00 * (1 - fx) * (1 - fy) + c10 * fx * (1 - fy) + c01 * (1 - fx) * fy + c11 * fx * fy


def recolor_block(path, snow_tex):
    im = np.array(Image.open(path).convert("RGBA"))
    h, w = im.shape[:2]
    if w != 131 or h not in (87, 107):
        raise SystemExit("unexpected block %s %s" % (path, im.shape))
    yy, xx = np.mgrid[0:h, 0:w]
    top = (np.abs(xx + 0.5 - BLOCK_CX) / BLOCK_HW + np.abs(yy + 0.5 - BLOCK_CY) / BLOCK_HH <= 1.0)
    top &= im[:, :, 3] > 0
    before = im.copy()
    lum = im[:, :, :3].astype(np.float32).mean(axis=2)
    med = float(np.median(lum[top]))
    if med < 1.0:
        med = 1.0
    ratio = np.clip(lum / med, 0.35, 1.75)
    u = (xx + 0.5 - (BLOCK_CX - BLOCK_HW)) / (BLOCK_HW * 2.0)
    v = (yy + 0.5 - (BLOCK_CY - BLOCK_HH)) / (BLOCK_HH * 2.0)
    sampled = sample_hires(snow_tex, u, v)
    shaded = np.clip(sampled[:, :, :3] * ratio[:, :, None], 0, 255)
    im[top, :3] = shaded[top].astype(np.uint8)
    # Sides, shadow, and empty texels stay the authored pixels.
    if not np.array_equal(im[~top], before[~top]):
        raise SystemExit("block sides changed %s" % path)
    save_webp(path, Image.fromarray(im))
    return int(top.sum())


def stamp_room(room_id, ice, snow, hires_snow):
    path = os.path.join(ROOT, "art", "rooms", room_id, "background_board_2x.webpbin")
    original = np.array(Image.open(path).convert("RGBA"))
    plate = original.copy()
    cells = json.load(open(tags_path(room_id)))["cells"]
    shade = {}
    counts = {"ground": 0, "water": 0, "mud": 0, "raised": 0}
    for cell in cells:
        terrain = cell["terrain"]
        if terrain == "mud":
            counts["mud"] += 1
            continue
        if terrain not in ("ground", "water"):
            continue
        x, y = int(cell["x"]), int(cell["y"])
        cx, cy = cell_center(x, y)
        slot = snow[variant(x, y)] if terrain == "ground" else ice[variant(x, y)]
        med = paste_cell(plate, slot, cx, cy, terrain == "ground")
        counts[terrain] += 1
        if terrain == "ground" and int(cell.get("elevation", 0)) == 0:
            shade["%d,%d" % (x, y)] = med
        if int(cell.get("elevation", 0)) > 0:
            counts["raised"] += 1
    # One modulate per flat snow cell, relative to this room's own median.
    vals = np.array(list(shade.values()), np.float32)
    ref = float(np.median(vals)) if len(vals) else 1.0
    for key, med in list(shade.items()):
        shade[key] = round(float(med) / ref, 4)
    # Mud diamonds and the plate outside every ground/ice cell stay exact.
    mud_cells = [(int(c["x"]), int(c["y"])) for c in cells if c["terrain"] == "mud"]
    for x, y in mud_cells:
        cx, cy = cell_center(x, y)
        x0, y0 = int(cx) - 64, int(cy) - 32
        # Interior of the mud diamond (inset) must be untouched. The shared
        # edge belongs to the neighbouring snow paste.
        if not np.array_equal(plate[y0 + 16:y0 + 48, x0 + 32:x0 + 96], original[y0 + 16:y0 + 48, x0 + 32:x0 + 96]):
            raise SystemExit("mud cell changed %s %s,%s" % (room_id, x, y))
    save_webp(path, Image.fromarray(plate))
    place = json.load(open(os.path.join(ROOT, "art", "rooms", room_id, "place.json")))
    blocks = 0
    tops = 0
    for occ in place.get("occluders", []):
        what = occ.get("what") or []
        if not what or not str(what[0]).startswith("elevation"):
            continue
        cell = occ["cell"]
        tex = hires_snow[variant(cell[0], cell[1])]
        tops += recolor_block(os.path.join(ROOT, "art", "rooms", room_id, occ["file"]), tex)
        blocks += 1
    print(room_id, counts, "blocks", blocks, "top px", tops, "plate", os.path.getsize(path))
    return shade


def export_runtime():
    os.makedirs(OUT, exist_ok=True)
    alive = os.path.join(PACK, "alive")
    copies = [
        ("bg_koliseo_crowd_layer_2400x1080_L1_back_stands.png", "crowd_l1.webpbin"),
        ("bg_koliseo_crowd_layer_2400x1080_L2_front_wall.png", "crowd_l2.webpbin"),
        ("prop_banner.png", "prop_banner.webpbin"),
        ("prop_brazier.png", "prop_brazier.webpbin"),
        ("prop_pine.png", "prop_pine.webpbin"),
        ("prop_statue.png", "prop_statue.webpbin"),
        ("prop_icicles_f1.png", "icicle_f1.webpbin"),
        ("prop_icicles_f2.png", "icicle_f2.webpbin"),
        ("prop_icicles_f3.png", "icicle_f3.webpbin"),
        ("fx_glint_f1.png", "glint_f1.webpbin"),
        ("fx_glint_f2.png", "glint_f2.webpbin"),
        ("fx_glint_f3.png", "glint_f3.webpbin"),
        ("fx_mist_tile_512.png", "mist.webpbin"),
    ]
    for src, dest in copies:
        image = Image.open(os.path.join(alive, src)).convert("RGBA")
        save_webp(os.path.join(OUT, dest), image)
        print("asset", dest, image.size, os.path.getsize(os.path.join(OUT, dest)))
    flake_dir = os.path.join(alive, "flakes")
    names = sorted(os.listdir(flake_dir))
    for index, name in enumerate(names, start=1):
        image = Image.open(os.path.join(flake_dir, name)).convert("RGBA")
        dest = os.path.join(OUT, "flake_%02d.webpbin" % index)
        save_webp(dest, image)
    print("flakes", len(names))
    for kind in ("ice", "snow"):
        for index in range(1, 5):
            src = os.path.join(PACK, "slots", "C", "hires", "%s_C_v%d_512x256.png" % (kind, index))
            image = Image.open(src).convert("RGBA")
            dest = os.path.join(OUT, "%s_v%d.webpbin" % (kind, index))
            save_webp(dest, image)
            print("floor", dest, os.path.getsize(dest))


MASK = diamond_mask()


def main():
    ice, snow = load_slots()
    _hires_ice, hires_snow = load_hires()
    export_runtime()
    shades = {}
    for room_id in ROOMS:
        shades[room_id] = stamp_room(room_id, ice, snow, hires_snow)
    with open(os.path.join(OUT, "shade.json"), "w", encoding="utf-8") as handle:
        json.dump(shades, handle, separators=(",", ":"))
    print("shade", os.path.getsize(os.path.join(OUT, "shade.json")))


if __name__ == "__main__":
    main()
