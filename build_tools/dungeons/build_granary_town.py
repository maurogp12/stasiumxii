"""Stoneford granary dungeon door: building sprite + hatch hover glow.

Source painting: granary_src/town_granary.jpg (1024x1024 on flat green).
Footprint: 3x3 cells (the front row holds the open hatch and the stair pit).
In the painting the footprint's south tip is at (452, 980) and one cell is
268 px wide, so 1x = 64/268 and 2x = 128/268.

Outputs (art/pc/dungeons/old_granary_cellar/town/):
  granary_door.png, _2x/granary_door.png              building, binary alpha
  granary_door_hatch_glow.png, _2x/...                 additive hover glow, same canvas
Image bottom-centre = south tip of footprint cell origin+(2,2), as the
Crosshaven kit buildings. The cutting code is shared (town_kit.py).
"""
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import town_kit  # noqa: E402

SX, SY, CELL = 452.0, 980.0, 268.0


def hatch_glow(rgb):
    # Glow source: the warm stair pit and lit hatch lantern.
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    warm = ((r > 170) & (g > 90) & (b < 120) & (r - b > 90)).astype(np.float32)
    box = np.zeros_like(warm)
    box[600:960, 380:640] = 1
    pit = warm * box
    # Light the hatch frame rim a little too.
    poly = np.array([[300, 575], [500, 640], [600, 690], [600, 880], [470, 960], [210, 840]], np.int32)
    area = np.zeros_like(warm)
    cv2.fillPoly(area, [poly], 1.0)
    glow = cv2.GaussianBlur(pit, (0, 0), 10) * 2.2 + cv2.GaussianBlur(area, (0, 0), 22) * 0.35
    glow = np.clip(glow, 0, 1)
    col = np.array([1.0, 0.62, 0.22], np.float32)
    return glow[..., None] * col


def build():
    gkit.use("old_granary_cellar")
    return town_kit.build("town_granary.jpg", "granary_door", "granary_door_hatch_glow", SX, SY, CELL, hatch_glow)


if __name__ == "__main__":
    print(build())
