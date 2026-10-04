"""Shared helpers for the Northgate snow kit generator."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image


def smoothstep(e0: float, e1: float, x):
    t = np.clip((np.asarray(x, dtype=np.float64) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def periodic_noise(w: int, h: int, freq: float, rng) -> np.ndarray:
    """Seamless (wraps on both axes) smooth noise in 0..1, by FFT filtering."""
    white = rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    # Cycles per canvas on each axis. On a 2:1 canvas that is the iso ground squash.
    r = np.sqrt(fx ** 2 + fy ** 2)
    filt = np.exp(-(r / max(freq * 0.5, 0.5)) ** 2)
    filt[0, 0] = 0.0
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * filt))
    out = (out - out.min()) / max(out.max() - out.min(), 1e-9)
    return out


def to_image(arr: np.ndarray) -> Image.Image:
    a = np.clip(arr, 0.0, 1.0)
    return Image.fromarray((a * 255.0 + 0.5).astype(np.uint8), "RGBA")


def save_pair(folder: Path, name: str, two_x: np.ndarray, one_x: np.ndarray | None = None) -> list[str]:
    """Write <folder>/_2x/<name>.png and <folder>/<name>.png (1x by downsample)."""
    folder = Path(folder)
    (folder / "_2x").mkdir(parents=True, exist_ok=True)
    hi = to_image(two_x)
    hi.save(folder / "_2x" / f"{name}.png")
    if one_x is not None:
        lo = to_image(one_x)
    else:
        lo = downsample(hi)
    lo.save(folder / f"{name}.png")
    return [str(folder / "_2x" / f"{name}.png"), str(folder / f"{name}.png")]


def downsample(img: Image.Image) -> Image.Image:
    """Half size with premultiplied alpha so edges do not darken or glow."""
    a = np.asarray(img).astype(np.float64) / 255.0
    rgb = a[..., :3] * a[..., 3:4]
    al = a[..., 3:4]
    h, w = a.shape[0] // 2 * 2, a.shape[1] // 2 * 2
    rgb = rgb[:h, :w].reshape(h // 2, 2, w // 2, 2, 3).mean((1, 3))
    al = al[:h, :w].reshape(h // 2, 2, w // 2, 2, 1).mean((1, 3))
    out_rgb = np.where(al > 1e-4, rgb / np.maximum(al, 1e-4), 0.0)
    return to_image(np.concatenate([out_rgb, al], 2))


def load(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0


def rgb_to_hsv(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = np.max(rgb, -1)
    mn = np.min(rgb, -1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rm = m & (mx == r)
    gm = m & (mx == g) & ~rm
    bm = m & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6
    h[gm] = ((b - r)[gm] / d[gm]) + 2
    h[bm] = ((r - g)[bm] / d[bm]) + 4
    h = h * 60.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    return np.stack([h, s, mx], -1)


def luma(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722
