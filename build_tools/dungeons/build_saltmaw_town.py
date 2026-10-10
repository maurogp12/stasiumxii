"""Eastmarch Saltmaw Grotto dungeon door: sea-cave sprite + door hover glow.

Source painting: saltmaw_src/town_saltmaw.jpg (1024x1024 on flat magenta,
asset_fgRWfg8LMTn2rKq5jgdJSVc6).
Footprint: 3x3 cells. Measured in the painting: the rock base's side tips are at
x 25 and x 1002 (y ~685), so the base diamond is ~977 px wide; one cell is 330 px
and the footprint's south tip is at (513, 962) (the front rock reaches y 964).
So 1x = 64/330 and 2x = 128/330. The cave maw opens on the front-left (SW, +y)
face; the plank pier runs out of it to the lower left and ends in cell (1,2) at
the SW edge, so the door cell is origin+(1,3), in front of the pier end.

Outputs (art/pc/dungeons/saltmaw_grotto/town/):
  saltmaw_door.png, _2x/                     building, binary alpha
  saltmaw_door_glow.png, _2x/                additive teal glow inside the maw, same canvas
"""
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import town_kit  # noqa: E402

SX, SY, CELL = 513.0, 962.0, 330.0
TEAL = np.array([0.25, 1.0, 0.78], np.float32)


def door_glow(rgb):
    """The glowing teal-green light deep inside the cave maw and on the water under the pier."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    teal = ((g > 110) & (g - r > 60) & (b > 70)).astype(np.float32) * np.clip((g - 100) / 120.0, 0, 1)
    box = np.zeros_like(teal)
    box[380:860, 380:700] = 1
    core = teal * box
    # A soft spill over the maw opening.
    poly = np.array([[400, 420], [560, 380], [680, 470], [700, 640], [600, 760], [420, 700]], np.int32)
    area = np.zeros_like(teal)
    cv2.fillPoly(area, [poly], 1.0)
    glow = cv2.GaussianBlur(core, (0, 0), 9) * 1.5 + cv2.GaussianBlur(area, (0, 0), 28) * 0.28
    glow = np.clip(glow, 0, 1)
    return glow[..., None] * TEAL


def build():
    gkit.use("saltmaw_grotto")
    return town_kit.build("town_saltmaw.jpg", "saltmaw_door", "saltmaw_door_glow", SX, SY, CELL, door_glow,
                          key=gkit.key_magenta)


if __name__ == "__main__":
    print(build())
