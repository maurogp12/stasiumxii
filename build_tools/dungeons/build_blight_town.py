"""Westwatch Heart of the Blight dungeon door: hollow blighted stump sprite + violet cave hover glow.

Source painting: blight_src/town_blight.jpg (1024x1024 on flat green, asset_xT2NTzzD6pfLumMd12YcYsd5).
Violet keys cleanly on green (it is the opposite hue), so this kit uses the green key throughout.
Footprint: 4x4 cells. Measured in the painting: the blighted earth patch's side tips are at x 9 (y 516)
and x 1014 (y 530), so the base is ~1005 px wide and one cell is 251 px. The painted earth is rounder and
deeper than a 2:1 diamond (its front with the trodden path runs down to y ~955), so the footprint's south
tip is put at (511, 860), near the path's end: the sprite is cut flat at the south tip (the kit rule), and
there the cut only crosses the narrow path. The earth's front corners overhang the footprint's south edges.
The cave mouth faces the front; the path runs out of it to the south and the door cell is origin+(3,4),
on the path just outside the SW edge of the corner cell (3,3).

Outputs (art/pc/dungeons/heart_of_the_blight/town/):
  blight_door.png, _2x/                    building, binary alpha
  blight_door_glow.png, _2x/               additive violet glow in the cave mouth, same canvas
"""
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import town_kit  # noqa: E402

SX, SY, CELL = 511.0, 860.0, 251.0
VIOLET = np.array([0.78, 0.35, 1.0], np.float32)


def cave_glow(rgb):
    """The violet light deep in the cave mouth and its spill on the roots, plus the lantern."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    vio = ((b > 120) & (r > 90) & (b - g > 70) & (r - g > 40)).astype(np.float32) * np.clip((b - 100) / 120.0, 0, 1)
    box = np.zeros_like(vio)
    box[380:640, 400:640] = 1
    box[270:360, 125:180] = 1  # the violet lantern on the post
    core = vio * box
    area = np.zeros_like(vio)
    cv2.ellipse(area, (515, 520), (95, 110), 0, 0, 360, 1.0, -1)
    glow = cv2.GaussianBlur(core, (0, 0), 7) * 1.7 + cv2.GaussianBlur(area, (0, 0), 30) * 0.35
    return np.clip(glow, 0, 1)[..., None] * VIOLET


def build():
    gkit.use("heart_of_the_blight")
    return town_kit.build("town_blight.jpg", "blight_door", "blight_door_glow", SX, SY, CELL, cave_glow, key=gkit.key_green)


if __name__ == "__main__":
    print(build())
