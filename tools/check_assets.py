#!/usr/bin/env python3
"""Crosshaven art convention check for the map-polish kit.

The NPC art box checker (`stasium-pc-look/tools/check_assets.py`) is not in
this repository. This script checks the same world-gate rules the Crosshaven
README documents, for the ids added with the snow-pine / meadow polish:

- 1x and `_2x` pair, `_2x` exactly twice the 1x size
- floor tiles 64x32 (1x) and 128x64 (2x)
- RGBA, 8-bit
- bottom gap from the south tip (ideal 0-3 px; warn above 3, fail above 24)
- no neon (a channel near 255 while another is near 0)

Exit 0 when nothing fails. Warnings print and do not fail.
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("FAIL pillow is not installed")
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1] / "art" / "world" / "crosshaven"

TILES = [
    "meadow_d", "meadow_e", "meadow_f", "meadow_g",
    "road_dirt_a", "road_dirt_b", "road_dirt_c", "road_dirt_d",
]
PROPS = [
    "pine_snow_giant", "pine_snow_tall", "pine_snow_mid_a", "pine_snow_mid_b",
    "pine_snow_small", "pine_snow_sapling",
    "pine_base_snow_large", "pine_base_snow_small",
    "polish_tuft_a", "polish_tuft_b", "polish_tuft_c",
    "snow_rocks_a", "snow_rocks_b",
]


def gap_of(im: Image.Image) -> int:
    w, h = im.size
    px = im.load()
    for y in range(h - 1, -1, -1):
        for x in range(w):
            if px[x, y][3] > 8:
                return h - 1 - y
    return h


def neon_count(im: Image.Image) -> int:
    px = im.load()
    n = 0
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 16:
                continue
            hi = max(r, g, b)
            lo = min(r, g, b)
            if hi > 245 and lo < 30:
                n += 1
    return n


def check(kind: str, id_: str, tile: bool) -> tuple[int, int]:
    fails = 0
    warns = 0
    lo = ROOT / kind / f"{id_}.png"
    hi = ROOT / kind / "_2x" / f"{id_}.png"
    if not lo.is_file() or not hi.is_file():
        print(f"FAIL {id_} missing 1x/2x pair")
        return 1, 0
    a = Image.open(lo)
    b = Image.open(hi)
    if a.mode != "RGBA" or b.mode != "RGBA":
        print(f"FAIL {id_} mode {a.mode}/{b.mode} (want RGBA)")
        fails += 1
    if b.size != (a.size[0] * 2, a.size[1] * 2):
        print(f"FAIL {id_} 2x {b.size} is not twice 1x {a.size}")
        fails += 1
    if tile and a.size != (64, 32):
        print(f"FAIL {id_} tile size {a.size} (want 64x32)")
        fails += 1
    gap = gap_of(a)
    if gap > 24:
        print(f"FAIL {id_} south-tip gap {gap}px (world gate 24)")
        fails += 1
    elif gap > 3:
        print(f"WARN {id_} south-tip gap {gap}px (ideal 0-3, within the 24px gate)")
        warns += 1
    else:
        print(f"PASS {id_} {a.size[0]}x{a.size[1]} gap={gap}")
    neon = neon_count(a)
    if neon:
        print(f"WARN {id_} {neon} neon-like pixels")
        warns += 1
    return fails, warns


def main() -> int:
    fails = 0
    warns = 0
    for id_ in TILES:
        f, w = check("tiles", id_, True)
        fails += f
        warns += w
    for id_ in PROPS:
        f, w = check("props", id_, False)
        fails += f
        warns += w
    print(f"check_assets: {fails} failed, {warns} warnings")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
