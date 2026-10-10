"""Shared town-door builder: one keyed building painting -> building sprite (1x + _2x)
plus an additive door/hatch hover glow on the same canvas.

The image bottom-centre is the footprint's south tip, painted at (sx, sy) in the
source; `cell` is one cell's width in source pixels (so 1x = 64/cell, 2x = 128/cell).
"""
import os

import cv2
import numpy as np

import gkit


def build(src, out_id, glow_id, sx, sy, cell, glow_fn, key=None, pad_top=4, pad_side=4, min_island=400):
    """glow_fn(rgb_float_0_255) -> HxWx3 float additive glow in 0..1 (source resolution)."""
    rgb = gkit.load_rgb(src)
    keyf = key or gkit.key_green
    prem = gkit.clean_alpha(keyf(rgb), min_island=min_island)
    ys, xs = np.nonzero(prem[..., 3] > 0.02)
    half = max(sx - xs.min(), xs.max() + 1 - sx) + pad_side
    top = ys.min() - pad_top
    x0, x1 = int(round(sx - half)), int(round(sx + half))
    y0, y1 = int(top), int(sy)
    pad = np.zeros((y1 - y0, x1 - x0, 4), np.float32)
    sx0, sx1 = max(0, x0), min(prem.shape[1], x1)
    pad[:, sx0 - x0:sx1 - x0] = prem[y0:y1, sx0:sx1]
    glow_rgb = glow_fn(rgb)
    gpad = np.zeros((y1 - y0, x1 - x0, 3), np.float32)
    gpad[:, sx0 - x0:sx1 - x0] = glow_rgb[y0:y1, sx0:sx1]
    outdir = os.path.join(gkit.OUT, "town")
    meta = {}
    for tag, scale, sub in (("1x", 64.0 / cell, ""), ("2x", 128.0 / cell, "_2x")):
        w = int(round(pad.shape[1] * scale / 2)) * 2
        h = int(round(pad.shape[0] * scale))
        im = gkit.binarize(gkit.resize_prem(pad, w, h))
        path = os.path.join(outdir, sub, out_id + ".png")
        gkit.save_png(path, im)
        gl = cv2.resize(gpad, (w, h), interpolation=cv2.INTER_AREA)
        g8 = np.clip(gl * 255 + 0.5, 0, 255).astype(np.uint8)
        on = g8.max(-1) >= 3
        gout = np.zeros((h, w, 4), np.uint8)
        gout[..., :3] = np.where(on[..., None], g8, 0)
        gout[..., 3] = np.where(on, 255, 0)
        gpath = os.path.join(outdir, sub, glow_id + ".png")
        gkit.save_png(gpath, gout)
        meta[tag] = {"size": [w, h], "file": gkit.rel(path), "glow": gkit.rel(gpath)}
    return meta
