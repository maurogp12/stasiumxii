"""Stoneford granary dungeon door: building sprite + hatch hover glow.

Source painting: granary_src/town_granary.jpg (1024x1024 on flat green).
Footprint: 3x3 cells (the front row holds the open hatch and the stair pit).
In the painting the footprint's south tip is at (452, 980) and one cell is
268 px wide, so 1x = 64/268 and 2x = 128/268.

Outputs (art/pc/dungeons/old_granary_cellar/town/):
  granary_door.png, _2x/granary_door.png              building, binary alpha
  granary_door_hatch_glow.png, _2x/...                 additive hover glow, same canvas
Image bottom-centre = south tip of footprint cell origin+(2,2), as the
Crosshaven kit buildings.
"""
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402

SX, SY, CELL = 452.0, 980.0, 268.0
OUTDIR = os.path.join(gkit.OUT, "town")


def build():
    rgb = gkit.load_rgb("town_granary.jpg")
    prem = gkit.clean_alpha(gkit.key_green(rgb))
    ys, xs = np.nonzero(prem[..., 3] > 0.02)
    half = max(SX - xs.min(), xs.max() + 1 - SX) + 4
    top = ys.min() - 4
    x0, x1 = int(round(SX - half)), int(round(SX + half))
    y0, y1 = int(top), int(SY)
    pad = np.zeros((y1 - y0, x1 - x0, 4), np.float32)
    sx0, sx1 = max(0, x0), min(prem.shape[1], x1)
    pad[:, sx0 - x0:sx1 - x0] = prem[y0:y1, sx0:sx1]
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
    glow_rgb = glow[..., None] * col
    gpad = np.zeros((y1 - y0, x1 - x0, 3), np.float32)
    gpad[:, sx0 - x0:sx1 - x0] = glow_rgb[y0:y1, sx0:sx1]
    meta = {}
    for tag, scale, sub in (("1x", 64.0 / CELL, ""), ("2x", 128.0 / CELL, "_2x")):
        w = int(round(pad.shape[1] * scale / 2)) * 2
        h = int(round(pad.shape[0] * scale))
        im = gkit.binarize(gkit.resize_prem(pad, w, h))
        path = os.path.join(OUTDIR, sub, "granary_door.png")
        gkit.save_png(path, im)
        gl = cv2.resize(gpad, (w, h), interpolation=cv2.INTER_AREA)
        g8 = np.clip(gl * 255 + 0.5, 0, 255).astype(np.uint8)
        on = g8.max(-1) >= 3
        gout = np.zeros((h, w, 4), np.uint8)
        gout[..., :3] = np.where(on[..., None], g8, 0)
        gout[..., 3] = np.where(on, 255, 0)
        gpath = os.path.join(OUTDIR, sub, "granary_door_hatch_glow.png")
        gkit.save_png(gpath, gout)
        meta[tag] = {"size": [w, h], "file": gkit.rel(path), "glow": gkit.rel(gpath)}
    return meta


if __name__ == "__main__":
    print(build())
