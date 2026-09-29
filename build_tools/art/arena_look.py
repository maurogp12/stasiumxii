#!/usr/bin/env python3
"""Cut floor stamps for each Koliseo arena out of Mauro's look pictures.

The pictures (art/maps/arena_look/refs/<map>_look.*) are the art direction
Mauro handed on 29 Sep: lava (Slagcrown), dock over dark water (Brinewake),
electric grid (Stormspire), ice ring (Windmere), city plaza (Crosshaven).
They are painted, so their own grid does not line up with the 15x15 board.
Instead of slicing cells, this samples many small patches inside the painted
floor, scores each by how much of it is one surface (planks, glowing water,
basalt, molten lava, slate, ice, cobbles...), keeps the best spread-out
patches and bakes each one into a 64x32 iso diamond. The board draws its own
grid over the stamps, so every stamp lines up with the real cells.

Output: art/maps/arena_look/<map>/<terrain>_<n>.png (64x32 RGBA diamonds).
Mud is baked from the ground stamps with a per-arena treatment when the
picture has no mud. Presentation only: tags, walk, MP and LoS are untouched.

Run from the repo root: python3 build_tools/art/arena_look.py
Needs: pillow, numpy.
"""
import os
import random
import zlib

import numpy as np
from PIL import Image, ImageFilter

REFS = "art/maps/arena_look/refs/"
OUT = "art/maps/arena_look/"
TW, TH = 64, 32
SS = 4  # supersample


def hsv(arr):
    rgb = arr[..., :3].astype(np.float32) / 255.0
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    m = d > 1e-6
    rm = m & (mx == r)
    gm = m & (mx == g) & ~rm
    bm = m & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6
    h[gm] = ((b - r)[gm] / d[gm]) + 2
    h[bm] = ((r - g)[bm] / d[bm]) + 4
    h = h * 60.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return h, s, mx


# Surface rules: (hue, sat, val) -> bool mask. Tuned on the look pictures.
def wood(h, s, v):
    return (h >= 10) & (h <= 50) & (s >= 0.12) & (s <= 0.65) & (v >= 0.13) & (v <= 0.62)


def glow_water(h, s, v):
    return (h >= 185) & (h <= 235) & (s >= 0.45) & (v >= 0.30)


def basalt(h, s, v):
    return (v <= 0.36) & ~((h <= 45) & (s >= 0.55) & (v >= 0.30)) & (v >= 0.05)


def molten(h, s, v):
    return ((h <= 48) | (h >= 350)) & (s >= 0.55) & (v >= 0.55)


def slate(h, s, v):
    gold = (h >= 30) & (h <= 60) & (s >= 0.35) & (v >= 0.35)
    # The navy page around the board is saturated blue; slate is near-grey.
    navy = (h >= 195) & (h <= 250) & (s >= 0.35)
    return (v <= 0.34) & (v >= 0.06) & (s <= 0.45) & ~gold & ~navy


def slab(h, s, v):
    # Mauro's second Stormspire picture: blue-grey cracked stone slabs.
    gold = (h >= 30) & (h <= 65) & (s >= 0.3) & (v >= 0.35)
    violet = (h >= 250) & (h <= 320) & (s >= 0.3)
    return (h >= 195) & (h <= 245) & (v >= 0.14) & (v <= 0.62) & (s <= 0.62) & ~gold & ~violet


def rune(h, s, v):
    return (h >= 225) & (h <= 300) & (s >= 0.30) & (v >= 0.22)


def ice(h, s, v):
    return (v >= 0.66) & (s <= 0.30) & (h >= 180) & (h <= 240) | ((v >= 0.78) & (s <= 0.12))


def cobble(h, s, v):
    # Warm grey stone only: the pink and teal start strips are not the plaza.
    # Measured on the plaza: hue ~34-44, sat ~0.22-0.40, val ~0.55-0.72.
    return (h >= 22) & (h <= 48) & (s >= 0.12) & (s <= 0.44) & (v >= 0.44) & (v <= 0.86)


def lawn(h, s, v):
    return (h >= 50) & (h <= 110) & (s >= 0.25) & (v >= 0.28)


def fountain(h, s, v):
    return (h >= 170) & (h <= 210) & (s >= 0.30) & (v >= 0.45)


# map -> picture, floor quad (TL, TR, BR, BL of a rough polygon), crop size in
# picture px (w, h), and terrain -> (rule, count, min score).
MAPS = {
    "slagcrown": {
        "ref": "slagcrown_look.jpg",
        "poly": [(1000, 80), (2000, 650), (1000, 1960), (40, 650)],
        "crop": (150, 86),
        "gain": {"ground": 1.45},
        "terrains": {"ground": (basalt, 10, 0.93), "lava": (molten, 6, 0.80)},
    },
    "brinewake": {
        "ref": "brinewake_look.jpg",
        "poly": [(1500, 40), (2950, 560), (1600, 1290), (120, 580)],
        "crop": (120, 60),
        "gain": {"ground": 1.8},
        "terrains": {"ground": (wood, 10, 0.86), "water": (glow_water, 4, 0.72)},
    },
    "stormspire": {
        "ref": "stormspire_look.jpg",
        "poly": [(200, 150), (1850, 150), (1850, 950), (200, 950)],
        "crop": (70, 38),
        "gain": {"ground": 1.0},
        "terrains": {"water": (rune, 5, 0.30)},
        # Floor slabs come from the second picture (see EXTRA below).
    },
    "windmere": {
        "ref": "windmere_look.jpg",
        "poly": [(640, 250), (1120, 520), (760, 790), (260, 520)],
        "crop": (64, 34),
        "terrains": {"ground": (ice, 10, 0.85)},
    },
    "crosshaven": {
        "ref": "crosshaven_look.jpg",
        "poly": [(450, 40), (880, 290), (450, 560), (20, 290)],
        "crop": (46, 26),
        "terrains": {"ground": (cobble, 10, 0.70), "mud": (lawn, 6, 0.85)},
    },
}


def inside(poly, x, y):
    n = len(poly)
    c = False
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
            c = not c
        j = i
    return c


def diamond_mask(w, h):
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    return (np.abs(xx - cx) / (w / 2.0) + np.abs(yy - cy) / (h / 2.0)) <= 1.0


def pick_patches(img, rule, poly, cw, ch, count, min_score, seed):
    arr = np.array(img)
    hh, ss, vv = hsv(arr)
    ok = rule(hh, ss, vv)
    mask = diamond_mask(cw, ch)
    rng = random.Random(seed)
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    cands = []
    for _ in range(9000):
        x = rng.randint(max(min(xs), 0), min(max(xs), img.width - cw - 1))
        y = rng.randint(max(min(ys), 0), min(max(ys), img.height - ch - 1))
        if not inside(poly, x + cw / 2, y + ch / 2):
            continue
        score = ok[y:y + ch, x:x + cw][mask].mean()
        if score >= min_score:
            cands.append((score, x, y))
    cands.sort(reverse=True)
    chosen = []
    for score, x, y in cands:
        if all(abs(x - a) > cw * 0.9 or abs(y - b) > ch * 0.9 for _, a, b in chosen):
            chosen.append((score, x, y))
        if len(chosen) >= count:
            break
    return chosen


def bake(img, x, y, cw, ch, gain=1.0):
    """Crop, scale to the 64x32 diamond (supersampled), soft edge, keep it opaque inside.
    gain lifts pictures whose floor reads too dark at phone size."""
    patch = img.crop((x, y, x + cw, y + ch)).resize((TW * SS, TH * SS), Image.LANCZOS)
    if gain != 1.0:
        patch = Image.fromarray(np.clip(np.array(patch).astype(np.float32) * gain, 0, 255).astype(np.uint8))
    m = Image.fromarray((diamond_mask(TW * SS, TH * SS) * 255).astype(np.uint8))
    patch.putalpha(m)
    small = patch.resize((TW, TH), Image.LANCZOS)
    a = np.array(small)
    # Tips must stay opaque so neighbours close without hairline gaps.
    solid = diamond_mask(TW, TH)
    a[..., 3] = np.where(solid, 255, a[..., 3])
    return Image.fromarray(a, "RGBA")


def treat(stamp, mul=(1, 1, 1), add=(0, 0, 0), blur=0.0, desat=0.0):
    img = stamp.filter(ImageFilter.GaussianBlur(blur)) if blur else stamp
    a = np.array(img).astype(np.float32)
    rgb = a[..., :3]
    if desat:
        lum = rgb @ np.array([0.299, 0.587, 0.114])
        rgb = rgb * (1 - desat) + lum[..., None] * desat
    rgb = rgb * np.array(mul) + np.array(add)
    a[..., :3] = rgb
    a[..., 3] = np.array(stamp)[..., 3]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


# Extra sources: map -> terrain -> (picture, floor polygon, crop, rule, count, min score).
EXTRA = {
    "stormspire": {
        "ground": ("stormspire_look2.jpg", [(0, 700), (1000, 250), (1932, 700), (1932, 1932), (0, 1932)], (240, 120), slab, 10, 0.92),
    },
}

# Terrains the picture does not show: baked from ground stamps.
DERIVED = {
    "slagcrown": {
        "mud": lambda g: treat(g, mul=(0.78, 0.72, 0.70), desat=0.5),
        # Ash pool: dark glassy obsidian with a cold sheen, clearly not lava.
        "water": lambda g: treat(g, mul=(0.45, 0.55, 0.70), add=(4, 10, 22), blur=1.2),
    },
    "brinewake": {"mud": lambda g: treat(g, mul=(0.62, 0.64, 0.70), desat=0.3)},
    "stormspire": {"mud": lambda g: treat(g, mul=(0.72, 0.70, 0.86))},
    "windmere": {
        "mud": lambda g: treat(g, mul=(0.80, 0.84, 0.92), desat=0.2),
        "water": lambda g: treat(g, mul=(0.70, 0.86, 0.98), add=(0, 6, 12), blur=0.6),
    },
    "crosshaven": {
        "water": lambda g: treat(g, mul=(0.42, 0.70, 0.95), add=(8, 30, 52), blur=1.0),
    },
}


def main():
    for name, spec in MAPS.items():
        img = Image.open(REFS + spec["ref"]).convert("RGB")
        cw, ch = spec["crop"]
        out_dir = OUT + name
        os.makedirs(out_dir, exist_ok=True)
        for f in os.listdir(out_dir):
            if f.endswith(".png") and not f.startswith("prop_"):
                os.remove(os.path.join(out_dir, f))
                if os.path.exists(os.path.join(out_dir, f + ".import")):
                    os.remove(os.path.join(out_dir, f + ".import"))
        grounds = []
        for terrain, (rule, count, min_score) in spec["terrains"].items():
            picks = pick_patches(img, rule, spec["poly"], cw, ch, count, min_score, zlib.crc32((name + terrain).encode()))
            for i, (score, x, y) in enumerate(picks):
                stamp = bake(img, x, y, cw, ch, spec.get("gain", {}).get(terrain, 1.0))
                stamp.save(os.path.join(out_dir, "%s_%d.png" % (terrain, i)), optimize=True)
                if terrain == "ground":
                    grounds.append(stamp)
            print(name, terrain, len(picks), "stamps", "best %.2f" % (picks[0][0] if picks else 0))
        for terrain, (ref, poly, crop, rule, count, min_score) in EXTRA.get(name, {}).items():
            extra = Image.open(REFS + ref).convert("RGB")
            picks = pick_patches(extra, rule, poly, crop[0], crop[1], count, min_score, zlib.crc32((name + terrain + ref).encode()))
            for i, (score, x, y) in enumerate(picks):
                stamp = bake(extra, x, y, crop[0], crop[1], spec.get("gain", {}).get(terrain, 1.0))
                stamp.save(os.path.join(out_dir, "%s_%d.png" % (terrain, i)), optimize=True)
                if terrain == "ground":
                    grounds.append(stamp)
            print(name, terrain, len(picks), "stamps from", ref)
        for terrain, fn in DERIVED.get(name, {}).items():
            if terrain in spec["terrains"]:
                continue
            for i, g in enumerate(grounds[:4]):
                fn(g).save(os.path.join(out_dir, "%s_%d.png" % (terrain, i)), optimize=True)
            print(name, terrain, min(len(grounds), 4), "derived")


if __name__ == "__main__":
    random.seed(7)
    main()
