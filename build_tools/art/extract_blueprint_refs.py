#!/usr/bin/env python3
"""Cut the Ironjaw look target out of the GDD Blueprint image.

Blueprint §6 "Ironjaw SIDE walk" (Mauro, 27 Sep) is the approved look: red
plate, grill helm, dual double-bit axes, drawn on white paper. It is not in
the repo as a strip, so this cuts it out: a border flood key on the paper and
the grey floor shadow, then five frames scaled to the 144x160 cell with feet
on row 150. The pass pose is repeated so the loop keeps six cells.

(Kestrel and Gloam walk E in the blueprint are the shipped keyed strips on a
black page, so they are not cut from here; rebuild_character_strips.py backs
their gaps with the same dark instead.)

Input: the blueprint's word/media folder (unzip the .docx).
Output: build_tools/art/refs/ironjaw_walk_e.png (864x160 RGBA).

Usage: python3 build_tools/art/extract_blueprint_refs.py <word/media dir>
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

CELL_W, CELL_H, FOOT_Y, BODY_H = 144, 160, 150, 132
OUT = "build_tools/art/refs"
SHEETS = {
    # class: (file, crop box, frames drawn)
    "ironjaw": ("992855c9ab718c36dd089843129766de6e427aff.jpg", (0, 76, 900, 336), 5),
}


def paper_mask(rgb):
    """White paper, the checker 'transparency' and the grey floor shadow."""
    mx = rgb.max(2)
    mn = rgb.min(2)
    cand = (mn >= 168) & ((mx - mn) <= 26)
    lab, cnt = ndi.label(cand)
    drop = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    if cnt:
        # Paper trapped between the legs is not armor.
        sizes = ndi.sum(np.ones_like(lab), lab, range(1, cnt + 1))
        drop |= {i + 1 for i, s in enumerate(sizes) if s >= 25}
    return np.isin(lab, list(drop))


def split_frames(solid, n):
    cols = solid.sum(0) > 0
    runs, start = [], None
    for x, on in enumerate(cols):
        if on and start is None:
            start = x
        if not on and start is not None:
            runs.append((start, x))
            start = None
    if start is not None:
        runs.append((start, len(cols)))
    runs = [r for r in runs if r[1] - r[0] > 20]
    if len(runs) == n:
        return runs
    w = solid.shape[1] / n
    return [(int(i * w), int((i + 1) * w)) for i in range(n)]


def to_cell(rgba, scale):
    a = np.array(rgba)
    ys, xs = np.where(a[:, :, 3] > 40)
    body = rgba.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    w, h = int(round(body.width * scale)), int(round(body.height * scale))
    body = body.resize((w, h), Image.LANCZOS)
    cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    cell.paste(body, (CELL_W // 2 - w // 2, FOOT_Y + 1 - h), body)
    return cell


def extract(media, cls):
    name, box, n = SHEETS[cls]
    img = Image.open(os.path.join(media, name)).convert("RGB").crop(box)
    rgb = np.array(img).astype(np.int32)
    solid = ndi.binary_opening(~paper_mask(rgb), iterations=1)
    lab, cnt = ndi.label(solid)
    if cnt:
        sizes = ndi.sum(np.ones_like(lab), lab, range(1, cnt + 1))
        solid = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= 120])
    alpha = Image.fromarray((solid * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
    rgba = np.dstack([rgb.astype(np.uint8), np.array(alpha)])
    frames = [Image.fromarray(rgba[:, x0:x1], "RGBA") for x0, x1 in split_frames(solid, n)]
    heights = [np.ptp(np.where(np.array(f)[:, :, 3] > 40)[0]) + 1 for f in frames]
    scale = BODY_H / float(np.median(heights))
    cells = [to_cell(f, scale) for f in frames]
    while len(cells) < 6:
        # Five drawn poses: add an in-between of the middle pair so the loop
        # keeps six cells and every cell is still a new pose.
        k = len(cells) // 2
        cells.insert(k + 1, Image.blend(cells[k], cells[k + 1], 0.5))
    strip = Image.new("RGBA", (CELL_W * 6, CELL_H), (0, 0, 0, 0))
    for i, c in enumerate(cells[:6]):
        strip.paste(c, (i * CELL_W, 0))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "%s_walk_e.png" % cls)
    strip.save(path, optimize=True)
    print(cls, "frames", len(frames), "scale %.2f" % scale, "->", path)


if __name__ == "__main__":
    for cls in SHEETS:
        extract(sys.argv[1], cls)
