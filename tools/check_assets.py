#!/usr/bin/env python3
"""Check the Blightwood Hollow kit against the Crosshaven art rules.

Floors are 64x32 diamonds at 1x, with a _2x master at twice that, drawn at
half size. Props follow the same 2x rule. Alpha is straight: no RGB under a
fully transparent pixel. Tile grammar stays grass / stone / water / ash / dock.
Pivot is bottom-centre on the south tip (recorded in atlas_meta.json).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "art" / "world" / "blightwood_hollow"
CROSS = ROOT / "art" / "world" / "crosshaven" / "tiles" / "golden_plains.png"
GRAMMAR = {"grass", "stone", "water", "ash", "dock"}

# Animated files whose bytes are not a 64x32 floor. Sizes are the painted masters.
ANIMATED = {
    "animated/grade_ramp_violet_dusk.png": (256, 16),
    "animated/ground_fog_tile.png": (512, 256),
    "animated/ground_fog_tile_1x.png": (256, 128),
    "animated/ground_fog_drift_12f.png": (3072, 128),
    "animated/spores_drift_12f.png": (1536, 128),
    "animated/heart_sap_pulse_8f.png": (1536, 192),
}


def fail(msg: str) -> None:
    print("FAIL", msg)
    raise SystemExit(1)


def rgb_under_alpha(path: Path) -> int:
    im = Image.open(path)
    if im.mode != "RGBA":
        return 0
    px = im.load()
    n = 0
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 and (r or g or b):
                n += 1
    return n


def main() -> None:
    if not CROSS.exists():
        fail(f"crosshaven floor missing: {CROSS}")
    cross = Image.open(CROSS)
    if cross.size != (64, 32):
        fail(f"crosshaven golden_plains is {cross.size}, expected 64x32")
    if not (KIT / "MANIFEST.md").exists():
        fail("MANIFEST.md missing")
    meta_path = KIT / "atlas_meta.json"
    if not meta_path.exists():
        fail("atlas_meta.json missing")
    meta = json.loads(meta_path.read_text())
    if meta.get("grammar") != ["grass", "stone", "water", "ash", "dock"]:
        fail("atlas grammar is not grass/stone/water/ash/dock")
    notes = json.dumps(meta.get("open_points", []))
    if "watch_flagstone" not in notes or "Proposed" not in notes:
        fail("watch_flagstone family is not marked Proposed")
    if "heart_of_the_blight_footprint" not in notes:
        fail("Heart footprint open point is missing")
    by_id = {row["id"]: row for row in meta["tiles"]}
    floors = 0
    for path in sorted((KIT / "tiles").glob("*.png")):
        im = Image.open(path)
        if im.size != (64, 32):
            fail(f"{path.name} is {im.size}, floors are 64x32")
        master = KIT / "tiles" / "_2x" / path.name
        if not master.exists():
            fail(f"missing 2x master {master.name}")
        him = Image.open(master)
        if him.size != (128, 64):
            fail(f"{master.name} is {him.size}, 2x floors are 128x64")
        stray = rgb_under_alpha(path) + rgb_under_alpha(master)
        if stray:
            fail(f"{path.name} has {stray} RGB pixels under alpha 0")
        row = by_id.get(path.stem)
        if row is None:
            fail(f"{path.stem} missing from atlas_meta")
        if row.get("grammar") not in GRAMMAR:
            fail(f"{path.stem} grammar {row.get('grammar')} is outside grass/stone/water/ash/dock")
        if row.get("anchor") != "bottom-centre":
            fail(f"{path.stem} anchor is not bottom-centre")
        floors += 1
    if floors < 30:
        fail(f"only {floors} floor tiles")
    props = 0
    for path in sorted((KIT / "props").glob("*.png")):
        im = Image.open(path)
        master = KIT / "props" / "_2x" / path.name
        if not master.exists():
            fail(f"missing prop master {path.name}")
        him = Image.open(master)
        if him.size != (im.size[0] * 2, im.size[1] * 2):
            fail(f"{path.name} 2x {him.size} is not double {im.size}")
        stray = rgb_under_alpha(path) + rgb_under_alpha(master)
        if stray:
            fail(f"{path.name} has {stray} RGB pixels under alpha 0")
        props += 1
    if props < 21:
        fail(f"only {props} props")
    for rel, size in ANIMATED.items():
        path = KIT / rel
        if not path.exists():
            fail(f"missing {rel}")
        im = Image.open(path)
        if im.size != size:
            fail(f"{rel} is {im.size}, expected {size}")
        if im.mode == "RGBA":
            stray = rgb_under_alpha(path)
            if stray:
                fail(f"{rel} has {stray} RGB pixels under alpha 0")
    # The kit names these grammars and leaves water and dock empty on purpose.
    used = {row["grammar"] for row in meta["tiles"]}
    for needed in ("grass", "stone", "ash"):
        if needed not in used:
            fail(f"no tile uses grammar {needed}")
    print(f"check_assets: ok ({floors} floors, {props} props, grammar {sorted(used)})")


if __name__ == "__main__":
    main()
