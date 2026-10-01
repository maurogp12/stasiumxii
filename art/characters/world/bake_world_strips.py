#!/usr/bin/env python3
"""Bake PC walk/run strips from the mobile 0.1.61 character sheets.

Reads PNGs already extracted under /tmp/mobile_chars (git archive of
origin/mobile). Writes retouched copies under art/characters/world/.
Does not touch the mobile branch.
"""

from __future__ import annotations

import os
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
SRC = Path("/tmp/mobile_chars/art/export_2x/characters")
CLASSES = ["ironjaw", "kestrel", "gloam", "mender", "bastion"]
DIRS = ["n", "e", "s", "w"]
CELL_W = 144
CELL_H = 160
AUTHORED = 6
# Soles sit on this row. In-betweens blend only the body above it.
FOOT_Y = 128
FEATHER = 12
# Walk in-between lifts the body a little. Run lifts more so the stride reads airborne.
WALK_LOFT = 3
RUN_LOFT = 7
WALK_SWAY = 2
RUN_SWAY = 3

SOURCE_COMMIT = "d9ec4044c98581805cce2a6732f89d0de95fbb83"


def load_cells(path: Path) -> list[np.ndarray]:
    im = Image.open(path).convert("RGBA")
    arr = np.array(im)
    if arr.shape[1] != CELL_W * AUTHORED or arr.shape[0] != CELL_H:
        raise SystemExit(f"unexpected size {arr.shape} for {path}")
    return [arr[:, i * CELL_W : (i + 1) * CELL_W].copy() for i in range(AUTHORED)]


def _premul(rgba: np.ndarray) -> np.ndarray:
    out = rgba.astype(np.float32)
    out[:, :, :3] *= out[:, :, 3:4] / 255.0
    return out


def _shift(img: np.ndarray, dx: int, dy: int) -> np.ndarray:
    """Positive dx moves pixels right. Positive dy moves pixels down. Empty stays clear."""
    out = np.zeros_like(img)
    h, w = img.shape[:2]
    x0 = max(0, dx)
    x1 = w + min(0, dx)
    y0 = max(0, dy)
    y1 = h + min(0, dy)
    if x1 <= x0 or y1 <= y0:
        return out
    out[y0:y1, x0:x1] = img[y0 - dy : y1 - dy, x0 - dx : x1 - dx]
    return out


def _align(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Slide B's body onto A so a mix does not draw two torsos."""
    aa = a[:FOOT_Y, :, 3] > 48
    best = (0, 0, -1)
    for dy in range(-2, 3):
        for dx in range(-4, 5):
            shifted = _shift(b, dx, dy)
            bb = shifted[:FOOT_Y, :, 3] > 48
            score = int(np.logical_and(aa, bb).sum())
            if score > best[2]:
                best = (dx, dy, score)
    return _shift(b, best[0], best[1])


def _feather_feet(body_frame: np.ndarray, feet_src: np.ndarray) -> np.ndarray:
    out = body_frame.copy()
    cut = FOOT_Y
    out[cut:] = feet_src[cut:]
    if FEATHER <= 0:
        return out
    band = out[cut - FEATHER : cut].astype(np.float32)
    src = feet_src[cut - FEATHER : cut].astype(np.float32)
    w = np.linspace(0.0, 1.0, FEATHER, dtype=np.float32)[:, None, None]
    mixed = band * (1.0 - w) + src * w
    out[cut - FEATHER : cut] = np.clip(mixed, 0, 255).astype(np.uint8)
    return out


def blend_body(a: np.ndarray, b: np.ndarray, t: float) -> np.ndarray:
    """Upper-body mix after the next pose is lined up. Feet stay on frame A."""
    b = _align(a, b)
    ap = _premul(a)
    bp = _premul(b)
    mix = ap * (1.0 - t) + bp * t
    alpha = mix[:, :, 3:4]
    rgb = np.zeros_like(mix[:, :, :3])
    np.divide(mix[:, :, :3], np.maximum(alpha / 255.0, 1e-4), out=rgb)
    out = np.zeros_like(a)
    out[:, :, :3] = np.clip(rgb, 0, 255)
    out[:, :, 3] = np.clip(alpha[:, :, 0], 0, 255)
    return _feather_feet(out.astype(np.uint8), a)


def _move_body(frame: np.ndarray, dx: int, dy: int) -> np.ndarray:
    """Shift the body. Feet stay put, with a feather so the waist does not tear."""
    if dx == 0 and dy == 0:
        return frame
    moved = _shift(frame, dx, dy)
    return _feather_feet(moved, frame)


def cycle(cells: list[np.ndarray], gait: str) -> list[np.ndarray]:
    frames: list[np.ndarray] = []
    n = len(cells)
    loft_px = RUN_LOFT if gait == "run" else WALK_LOFT
    sway = RUN_SWAY if gait == "run" else WALK_SWAY
    for i in range(n):
        authored = cells[i]
        nxt = cells[(i + 1) % n]
        # 0.35 keeps the leading silhouette. A half mix doubled the axes.
        mid = blend_body(authored, nxt, 0.35)
        side = sway if i % 2 == 0 else -sway
        mid = _move_body(mid, side, -loft_px)
        frames.append(authored)
        frames.append(mid)
    return frames


def save_strip(frames: list[np.ndarray], path: Path) -> None:
    sheet = np.concatenate(frames, axis=1)
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(path)


def save_idle(frame: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(frame, "RGBA").save(path)


def write_tres(class_name: str, dest: Path) -> None:
    """SpriteFrames for walk_*, run_*, idle_*. Atlas regions, not a copy of mobile .tres."""
    ext = []
    subs = []
    anims = []
    ext_ids = {}
    step = 1

    def ext_id(filename: str) -> str:
        nonlocal step
        if filename in ext_ids:
            return ext_ids[filename]
        step += 1
        eid = f"{step}_{filename.replace('.', '_')}"
        ext_ids[filename] = eid
        ext.append(
            f'[ext_resource type="Texture2D" path="res://art/characters/world/{class_name}/{filename}" id="{eid}"]'
        )
        return eid

    def atlas(eid: str, x: int) -> str:
        nonlocal step
        step += 1
        sid = f"Atlas_{step}"
        subs.append(
            "\n".join(
                [
                    f'[sub_resource type="AtlasTexture" id="{sid}"]',
                    f'atlas = ExtResource("{eid}")',
                    f"region = Rect2({x}, 0, {CELL_W}, {CELL_H})",
                ]
            )
        )
        return sid

    def add_anim(name: str, filename: str, count: int, speed: float, loop: bool) -> None:
        eid = ext_id(filename)
        frame_lines = []
        for i in range(count):
            sid = atlas(eid, i * CELL_W)
            frame_lines.append(
                '{"duration": 1.0, "texture": SubResource("%s")}' % sid
            )
        anims.append(
            '{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.1f}'
            % (", ".join(frame_lines), "true" if loop else "false", name, speed)
        )

    for facing in DIRS:
        add_anim(f"walk_{facing}", f"{class_name}_walk_{facing}.png", 12, 12.0, True)
        add_anim(f"run_{facing}", f"{class_name}_run_{facing}.png", 12, 14.0, True)
        add_anim(f"idle_{facing}", f"{class_name}_idle_{facing}.png", 1, 1.0, True)

    text = ['[gd_resource type="SpriteFrames" format=3]', ""]
    text.extend(ext)
    text.append("")
    text.extend(subs)
    text.append("")
    text.append("[resource]")
    text.append("animations = [%s]" % ", ".join(anims))
    text.append("")
    dest.write_text("\n".join(text))


def main() -> None:
    for class_name in CLASSES:
        dest = OUT / class_name
        for facing in DIRS:
            src = SRC / class_name / "anims" / f"{class_name}_walk_{facing}.png"
            cells = load_cells(src)
            save_strip(cycle(cells, "walk"), dest / f"{class_name}_walk_{facing}.png")
            save_strip(cycle(cells, "run"), dest / f"{class_name}_run_{facing}.png")
            idle_src = SRC / class_name / "idle" / f"{class_name}_idle_plant_{facing}_v1.png"
            if idle_src.exists():
                idle = np.array(Image.open(idle_src).convert("RGBA"))
            else:
                idle = cells[0]
            save_idle(idle, dest / f"{class_name}_idle_{facing}.png")
        write_tres(class_name, dest / f"{class_name}_frames.tres")
        print("baked", class_name)
    readme = OUT / "README.md"
    readme.write_text(
        f"""# PC world characters

Copies for the Crosshaven walker on `main`. The mobile branch is unchanged.

Source commit: `{SOURCE_COMMIT}` (mobile 0.1.61, "Mobile 0.1.61: Berserker Ironjaw kept, Stills test fix").

Copied read-only from `art/export_2x/characters/<class>/`:

- `anims/<class>_walk_{{n,e,s,w}}.png` — 864×160, six 144×160 cells, for ironjaw, kestrel, gloam, mender, bastion
- `idle/<class>_idle_plant_{{n,e,s,w}}_v1.png` — ironjaw and bastion only

Kestrel, Gloam, and Mender have no idle plant on mobile. Their idle frame is walk cell 0 (the foot-down plant).

## What changed on the PC copies

Mobile playback is six frames. These strips are twelve frames: each authored cell is kept, in the same order, and an in-between is inserted before the next cell (including the loop from cell 5 back to cell 0).

The in-between is a 35% mix of the next pose after that pose is shifted onto the current torso, so the axes and cape do not double. Pixels from y={FOOT_Y} down stay on the leading authored frame, with a {FEATHER}px feather. The body of that in-between is then lifted ({WALK_LOFT}px walk, {RUN_LOFT}px run) and swayed sideways by {WALK_SWAY}px / {RUN_SWAY}px on alternating steps. There is no separate mobile run sheet. The run strip is this same order with the taller loft and a wider sway. The feet stay planted.

The world walker does not play these strips on a clock. It picks the frame from distance traveled, one walk cycle per tile, and a longer stride while running. Each step holds the planted frame at the start and end, and shows the lifted in-between through the middle of the step. Facing stays the mobile four-direction lock (east, south, north, west). Pivot matches the mobile pawn: centered sprite, offset `(0, -72)` before scale.

Combat pawns still use `art/characters/<class>/` static facings. These files are only for the open-world walker.

`bake_world_strips.py` rebuilds the strips from an extract of that mobile commit.
"""
    )


if __name__ == "__main__":
    main()
