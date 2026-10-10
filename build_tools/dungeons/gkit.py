"""Shared helpers for the dungeon art kit builders (Old Granary Cellar first).

Everything here works on float32 numpy images.

* Chroma key: the paintings are made on flat pure green (about RGB 5,250,4).
  Alpha is estimated from the green excess, colour is un-mixed from the green
  (so no green fringe survives), the image is area-downsampled in
  premultiplied space, then alpha is cut to binary 0/255 and RGB is zeroed
  under alpha 0.
* Iso projection: a top-down square texture is mapped onto the 64x32 board
  diamond (top tip = texture corner (0,0), +x runs to the right tip).
"""
from __future__ import annotations

import json
import os

import cv2
import numpy as np
from PIL import Image

GREEN = np.array([5.0, 250.0, 4.0], np.float32)
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
# Dungeon id -> its folder of chosen source paintings (next to this file).
DUNGEONS = {"old_granary_cellar": "granary_src", "frostspire_archive": "frostspire_src"}
# GKIT_OUT_ROOT redirects every builder's output (used by check_granary_repro.py).
OUT_ROOT = os.environ.get("GKIT_OUT_ROOT") or os.path.join(REPO, "art", "pc", "dungeons")
DUNGEON = "old_granary_cellar"
SRC = os.path.join(HERE, "granary_src")
OUT = os.path.join(OUT_ROOT, DUNGEON)


def use(dungeon: str) -> None:
    """Point SRC/OUT (and so load_rgb, rel and every builder) at one dungeon."""
    global DUNGEON, SRC, OUT
    DUNGEON = dungeon
    SRC = os.path.join(HERE, DUNGEONS[dungeon])
    OUT = os.path.join(OUT_ROOT, dungeon)


def load_rgb(name: str) -> np.ndarray:
    path = name if os.path.isabs(name) else os.path.join(SRC, name)
    return np.asarray(Image.open(path).convert("RGB"), np.float32)


def key_green(rgb: np.ndarray, lo: float = 18.0, hi: float = 200.0) -> np.ndarray:
    """RGB (0..255) on flat green -> premultiplied RGBA float (0..1).

    alpha = 1 at green excess <= lo, 0 at >= hi (excess = g - max(r, b)).
    The foreground colour is un-mixed from the known green and its green is
    clamped to max(r, b) + 12 on any partly-keyed pixel (despill).
    """
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    ex = g - np.maximum(r, b)
    a = 1.0 - np.clip((ex - lo) / (hi - lo), 0.0, 1.0)
    a = a.astype(np.float32)
    safe = np.maximum(a, 1e-3)[..., None]
    fg = (rgb - (1.0 - a[..., None]) * GREEN) / safe
    fg = np.clip(fg, 0, 255)
    part = a < 0.999
    cap = np.maximum(fg[..., 0], fg[..., 2]) + 12.0
    fg[..., 1] = np.where(part, np.minimum(fg[..., 1], cap), fg[..., 1])
    # Spill on solid pixels right next to the background.
    near = cv2.dilate((a < 0.5).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    cap2 = np.maximum(fg[..., 0], fg[..., 2]) + 25.0
    fg[..., 1] = np.where(near, np.minimum(fg[..., 1], cap2), fg[..., 1])
    out = np.zeros(rgb.shape[:2] + (4,), np.float32)
    out[..., :3] = fg / 255.0 * a[..., None]
    out[..., 3] = a
    return out


MAGENTA = np.array([249.0, 3.0, 250.0], np.float32)


def key_magenta(rgb: np.ndarray, lo: float = 18.0, hi: float = 200.0) -> np.ndarray:
    """Like key_green, for paintings on flat magenta (used where the piece itself is green)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    ex = np.minimum(r, b) - g
    a = 1.0 - np.clip((ex - lo) / (hi - lo), 0.0, 1.0)
    a = a.astype(np.float32)
    safe = np.maximum(a, 1e-3)[..., None]
    fg = np.clip((rgb - (1.0 - a[..., None]) * MAGENTA) / safe, 0, 255)
    near = cv2.dilate((a < 0.5).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    near |= a < 0.999
    spill = np.maximum(np.minimum(fg[..., 0], fg[..., 2]) - fg[..., 1] - 10.0, 0.0)
    fg[..., 0] = np.where(near, fg[..., 0] - spill, fg[..., 0])
    fg[..., 2] = np.where(near, fg[..., 2] - spill, fg[..., 2])
    out = np.zeros(rgb.shape[:2] + (4,), np.float32)
    out[..., :3] = fg / 255.0 * a[..., None]
    out[..., 3] = a
    return out


def key_auto(rgb: np.ndarray) -> np.ndarray:
    c = rgb[:8, :8].reshape(-1, 3).mean(0)
    return key_magenta(rgb) if c[0] > 150 and c[2] > 150 and c[1] < 80 else key_green(rgb)


def clean_alpha(prem: np.ndarray, min_island: int = 400, fill_holes: int = 60) -> np.ndarray:
    """Drop small floating islands and fill pin holes (source resolution)."""
    a = (prem[..., 3] > 0.5).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(a, 8)
    keep = np.zeros(n, bool)
    for i in range(1, n):
        keep[i] = stats[i, cv2.CC_STAT_AREA] >= min_island
    mask = keep[lab]
    out = prem.copy()
    out[~mask] = 0
    if fill_holes:
        inv = (~mask).astype(np.uint8)
        n2, lab2, st2, _ = cv2.connectedComponentsWithStats(inv, 4)
        for i in range(1, n2):
            if st2[i, cv2.CC_STAT_AREA] < fill_holes:
                hole = lab2 == i
                blur = cv2.blur(out, (7, 7))
                wa = np.maximum(blur[..., 3:4], 1e-3)
                out[hole] = np.concatenate([blur[..., :3][hole] / wa[hole], np.ones((hole.sum(), 1), np.float32)], 1)
    return out


def crop_bbox(prem: np.ndarray, pad: int = 0):
    ys, xs = np.nonzero(prem[..., 3] > 0.02)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    y0, x0 = max(0, y0 - pad), max(0, x0 - pad)
    y1, x1 = min(prem.shape[0], y1 + pad), min(prem.shape[1], x1 + pad)
    return prem[y0:y1, x0:x1], (x0, y0, x1, y1)


def resize_prem(prem: np.ndarray, w: int, h: int) -> np.ndarray:
    interp = cv2.INTER_AREA if w < prem.shape[1] else cv2.INTER_CUBIC
    out = cv2.resize(prem, (int(w), int(h)), interpolation=interp)
    return np.clip(out, 0, 1)


def binarize(prem: np.ndarray, thr: float = 0.5) -> np.ndarray:
    """Premultiplied float -> straight uint8 RGBA with alpha 0/255, RGB 0 under 0."""
    a = prem[..., 3]
    on = a >= thr
    rgb = prem[..., :3] / np.maximum(a, 1e-4)[..., None]
    rgb = np.clip(rgb * 255.0 + 0.5, 0, 255).astype(np.uint8)
    out = np.zeros(prem.shape[:2] + (4,), np.uint8)
    out[..., :3] = np.where(on[..., None], rgb, 0)
    out[..., 3] = np.where(on, 255, 0)
    return out


def save_png(path: str, rgba: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(rgba).save(path, optimize=True)


def grade(prem: np.ndarray, mul=(1.0, 1.0, 1.0), sat: float = 1.0, gamma: float = 1.0) -> np.ndarray:
    """Colour grade a premultiplied image in straight space."""
    a = prem[..., 3:4]
    rgb = prem[..., :3] / np.maximum(a, 1e-4)
    lum = (rgb * np.array([0.299, 0.587, 0.114], np.float32)).sum(-1, keepdims=True)
    rgb = lum + (rgb - lum) * sat
    rgb = np.clip(rgb, 0, 1) ** gamma
    rgb = rgb * np.array(mul, np.float32)
    return np.concatenate([np.clip(rgb, 0, 1) * a, a], -1)


# ---------------------------------------------------------------- iso tiles

def diamond_mask(w: int, h: int, bleed: float = 0.5) -> np.ndarray:
    """Binary diamond of the w x h box; pixel centres within the diamond grown by `bleed` px."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    d = np.abs(xs - w / 2) / (w / 2) + np.abs(ys - h / 2) / (h / 2)
    return d <= 1.0 + bleed / (h / 2)


def project_square(tex: np.ndarray, w: int, h: int, ss: int = 6, bleed: float = 0.5) -> np.ndarray:
    """Map a square top-down texture (float, any channels) onto a w x h diamond.

    Texture corner (0,0) -> top tip, (1,0) -> right tip, (1,1) -> bottom tip,
    (0,1) -> left tip. Supersampled ss x then area-reduced. Returns float RGBA
    premultiplied with a binary diamond alpha (grown by `bleed` px so
    neighbours never leave a hairline gap).
    """
    W, H = w * ss, h * ss
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32) + 0.5
    px = (xs - W / 2) / (W / 2)
    py = ys / (H / 2)
    s = (px + py) / 2.0
    t = (py - px) / 2.0
    th, tw = tex.shape[:2]
    mx = np.clip(s, 0, 1) * (tw - 1)
    my = np.clip(t, 0, 1) * (th - 1)
    img = tex if tex.shape[2] == 4 else np.concatenate([tex, np.ones(tex.shape[:2] + (1,), np.float32)], -1)
    big = cv2.remap(img, mx.astype(np.float32), my.astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    small = cv2.resize(big, (w, h), interpolation=cv2.INTER_AREA)
    m = diamond_mask(w, h, bleed)
    out = np.zeros((h, w, 4), np.float32)
    out[..., :3] = small[..., :3]
    out[..., 3] = 1.0
    out[~m] = 0
    return out


def rel(path: str) -> str:
    return os.path.relpath(path, OUT).replace(os.sep, "/")


def write_json(path: str, data) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")
