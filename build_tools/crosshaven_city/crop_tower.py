"""Ring tower from the approved v5 horizontal gatehouse (round 8).

Crops the gatehouse's left flanking tower as its own sprite, so ring and
corner towers match the gatehouse towers (same face-on angle and scale).
Above the curtain's merlon line the tower's own alpha is kept; below it the
curtain behind the tower is cut away by mirroring the tower's clean left
silhouette (soft edge included) about the tower axis. No new art is painted.

  python3 crop_tower.py <gatehouse_horizontal_CONCEPTO.png> <out.png>
"""
import json
import sys

import numpy as np
from PIL import Image

AXIS_X = 254.5      # tower axis in the gatehouse art (crenellation centre)
CURTAIN_TOP_Y = 404  # first row where the curtain meets the tower's right side


def crop(src, dst):
    im = np.array(Image.open(src).convert("RGBA"))
    H, W = im.shape[:2]
    a = im[..., 3].astype(np.float32)
    out = im.copy()
    xs = np.arange(W, dtype=np.float32)
    mirror = np.clip(np.round(2 * AXIS_X - xs).astype(int), 0, W - 1)
    right = xs > AXIS_X
    for y in range(CURTAIN_TOP_Y, H):
        na = a[y].copy()
        na[right] = np.minimum(a[y, right], a[y, mirror[right]])
        out[y, :, 3] = na.astype(np.uint8)
    # nothing of the curtain beyond the tower's widest mirrored extent
    left_min = int(np.nonzero((a > 8).any(0))[0].min())
    x1 = int(np.ceil(2 * AXIS_X - left_min)) + 2
    out[:, x1:, 3] = 0
    ys, xs_ = np.nonzero(out[..., 3] > 8)
    box = (int(xs_.min()), int(ys.min()), int(xs_.max()) + 1, int(ys.max()) + 1)
    tile = Image.fromarray(out, "RGBA").crop(box)
    tile.save(dst)
    # base anchor: tower axis, 13 px above the bottom (the gatehouse curtain
    # foot sits 13 px above the tower's lowest pixel)
    base = [round(AXIS_X - box[0], 1), tile.height - 13]
    print(json.dumps({"size": list(tile.size), "box": box, "base": base}))


if __name__ == "__main__":
    crop(sys.argv[1], sys.argv[2])
