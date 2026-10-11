"""Southbridge Drowned Abbey dungeon door: ruined-chapel sprite + door hover glow.

Source painting: abbey_src/town_abbey.jpg (1024x1024 on flat magenta, asset_FHsUnXgZD7EkdBiC4Bdmmy3U,
an edit of asset_nKYFNm3ZmzReir4Ai6fZoyeF with the plank pier shortened).
Footprint: 3x3 cells. Measured in the painting: the foundation's side tips are at x 140 (y ~680) and
x 1009 (y ~720), so the base diamond is ~870 px wide; one cell is 290 px and the footprint's south tip
is at (575, 917). The foundation is a little deeper on its front-right than a square 3x3 (its front
corner is at (665, 905)), so that corner overhangs the SE edge by ~30 px. So 1x = 64/290 and
2x = 128/290. The door opens on the front-left (SW, +y) face; the short plank pier runs out of it
and ends in cell (1,3), so the door cell is origin+(1,3), at the pier end (as Saltmaw).

Outputs (art/pc/dungeons/drowned_abbey/town/):
  abbey_door.png, _2x/                     building, binary alpha
  abbey_door_glow.png, _2x/                additive green glow in the open door, same canvas
"""
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import town_kit  # noqa: E402

SX, SY, CELL = 575.0, 917.0, 290.0
GREEN = np.array([0.55, 1.0, 0.35], np.float32)


def door_glow(rgb):
    """The eerie green light in the half-open door and on the wet threshold."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    green = ((g > 120) & (g - r > 35) & (g - b > 60)).astype(np.float32) * np.clip((g - 110) / 110.0, 0, 1)
    box = np.zeros_like(green)
    box[500:760, 400:520] = 1
    core = green * box
    poly = np.array([[410, 560], [470, 520], [520, 560], [520, 740], [460, 760], [400, 720]], np.int32)
    area = np.zeros_like(green)
    cv2.fillPoly(area, [poly], 1.0)
    glow = cv2.GaussianBlur(core, (0, 0), 8) * 1.6 + cv2.GaussianBlur(area, (0, 0), 26) * 0.3
    return np.clip(glow, 0, 1)[..., None] * GREEN


def build():
    gkit.use("drowned_abbey")
    return town_kit.build("town_abbey.jpg", "abbey_door", "abbey_door_glow", SX, SY, CELL, door_glow, key=gkit.key_magenta)


if __name__ == "__main__":
    print(build())
