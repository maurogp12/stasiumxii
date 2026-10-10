"""Northgate Frostspire Archive dungeon door: building sprite + door hover glow.

Source painting: frostspire_src/town_frostspire.jpg (1024x1024 on flat magenta,
asset_5cQZwTSVeG9hKyej6R82WQni).
Footprint: 3x3 cells. Measured in the painting (see _mock/town_door_footprint.png):
the footprint's south tip is at (515, 996) and one cell is 200 px wide, so
1x = 64/200 and 2x = 128/200. The doorway is on the front-left (SW, +y) face;
its frosted steps fill cell (2,2) next to the south tip, so the door cell is origin+(2,3).

Outputs (art/pc/dungeons/frostspire_archive/town/):
  frostspire_door.png, _2x/                     building, binary alpha
  frostspire_door_glow.png, _2x/                additive ice-blue door glow, same canvas
"""
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import town_kit  # noqa: E402

SX, SY, CELL = 515.0, 996.0, 200.0


def door_glow(rgb):
    """The glowing ice-blue light inside the open doors and on the steps."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    cold = ((b > 170) & (b - r > 70) & (g > 90)).astype(np.float32) * np.clip((b - 150) / 100.0, 0, 1)
    box = np.zeros_like(cold)
    box[640:960, 390:560] = 1
    core = cold * box
    # A soft spill over the door frame and the steps.
    poly = np.array([[395, 700], [470, 650], [560, 690], [560, 900], [470, 960], [380, 905]], np.int32)
    area = np.zeros_like(cold)
    cv2.fillPoly(area, [poly], 1.0)
    glow = cv2.GaussianBlur(core, (0, 0), 8) * 1.6 + cv2.GaussianBlur(area, (0, 0), 24) * 0.3
    glow = np.clip(glow, 0, 1)
    col = np.array([0.42, 0.72, 1.0], np.float32)
    return glow[..., None] * col


def build():
    gkit.use("frostspire_archive")
    return town_kit.build("town_frostspire.jpg", "frostspire_door", "frostspire_door_glow", SX, SY, CELL, door_glow,
                          key=gkit.key_magenta)


if __name__ == "__main__":
    print(build())
