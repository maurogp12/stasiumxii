"""WP10a shared helpers: straight-alpha IO, premultiplied resampling, kit constants.

All images are float32 RGBA in [0,1], straight (not premultiplied) alpha, unless a name says _pm.
"""
from __future__ import annotations
import json
from pathlib import Path
import numpy as np
import cv2
from PIL import Image

ROOT = Path('/workspace/scratch/wp10a')
MANIFEST = Path('/workspace/stasium-pc-look/raw/wp10a/manifest.json')
CROSSHAVEN = Path('/workspace/stasium-repo/art/world/crosshaven')
SS = 8                     # supersampling factor relative to the 2x master

# Kit light (ZONES_BUILD_SPEC WP10 style rules, Crosshaven v7 light)
KEY = '#fff0c8'
SHADE = '#5a6fa0'
SHADOW_TINT = '#3b3a66'
CAST_SHADOW = '#1a223c'    # Crosshaven *_shadow_sway colour
OUTLINE = '#2a1c12'


def hex2rgb(h: str) -> np.ndarray:
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


def smoothstep(e0, e1, x):
    t = np.clip((np.asarray(x, np.float32) - e0) / (e1 - e0 + 1e-12), 0, 1)
    return t * t * (3 - 2 * t)


def load_rgba(p) -> np.ndarray:
    return np.asarray(Image.open(p).convert('RGBA'), np.float32) / 255.0


def load_rgb(p) -> np.ndarray:
    return np.asarray(Image.open(p).convert('RGB'), np.float32) / 255.0


RAW_MAX = 2048   # Scenario now delivers 4096x4096; keying/placing at 2048 is still >3x the 2x master and 4x faster


def load_raw(p, max_side=None) -> np.ndarray:
    """Raw paint as float RGB, area-downscaled so the long side is <= RAW_MAX (alpha-free raws: plain area filter is fine)."""
    im = Image.open(p).convert('RGB')
    m = max_side or RAW_MAX
    if max(im.size) > m:
        f = m / max(im.size)
        im = im.resize((round(im.size[0] * f), round(im.size[1] * f)), Image.BOX)
    return np.asarray(im, np.float32) / 255.0


def find_raw(raw_dir, asset_or_name, aliases=()):
    """<id>.png (or the manifest raw name) first, then the painter's short-name aliases. Subfolders (pass1/ ...) are ignored."""
    raw_dir = Path(raw_dir)
    if isinstance(asset_or_name, dict):
        names = [asset_or_name['raw']] + list(asset_or_name.get('raw_aliases') or [])
    else:
        names = [asset_or_name] + list(aliases)
    for n in names:
        if (raw_dir / n).exists():
            return raw_dir / n
    return None


def save_rgba(p, rgba: np.ndarray):
    """Straight alpha, 8-bit, RGB forced to 0 wherever the stored alpha is 0."""
    p = Path(p); p.parent.mkdir(parents=True, exist_ok=True)
    a8 = np.round(np.clip(rgba, 0, 1) * 255).astype(np.uint8)
    a8[a8[..., 3] == 0, :3] = 0
    Image.fromarray(a8, 'RGBA').save(p, optimize=True)


def save_l(p, g: np.ndarray):
    p = Path(p); p.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.round(np.clip(g, 0, 1) * 255).astype(np.uint8), 'L').save(p, optimize=True)


def premul(rgba):
    out = rgba.copy(); out[..., :3] *= rgba[..., 3:4]; return out


def unpremul(pm):
    out = pm.copy(); a = pm[..., 3:4]
    out[..., :3] = np.where(a > 1e-6, pm[..., :3] / np.maximum(a, 1e-6), 0)
    return np.clip(out, 0, 1)


def down_box(rgba, f: int):
    """Exact area average by an integer factor, done on premultiplied colour."""
    h, w = rgba.shape[:2]
    assert h % f == 0 and w % f == 0, (rgba.shape, f)
    pm = premul(rgba).reshape(h // f, f, w // f, f, 4).mean((1, 3))
    return unpremul(pm)


def resize_pm(rgba, size_wh, interp=None):
    """Resize straight-alpha RGBA through premultiplied space (no dark/bright fringes)."""
    w, h = size_wh
    if interp is None:
        interp = cv2.INTER_AREA if w < rgba.shape[1] else cv2.INTER_LANCZOS4
    pm = cv2.resize(premul(rgba), (int(w), int(h)), interpolation=interp)
    return unpremul(np.clip(pm, 0, 1))


def luminance(rgb):
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def to_lab(rgb):
    return cv2.cvtColor(np.clip(rgb, 0, 1).astype(np.float32), cv2.COLOR_RGB2Lab)


def load_manifest(path=MANIFEST):
    return json.loads(Path(path).read_text())


def manifest_assets(m, region=None):
    out = []
    for reg in m['regions']:
        if region and reg['id'] != region:
            continue
        for a in reg['assets']:
            out.append((reg, a))
    return out


def over(top, bottom):
    """Straight-alpha 'top over bottom'."""
    at, ab = top[..., 3:4], bottom[..., 3:4]
    ao = at + ab * (1 - at)
    rgb = np.where(ao > 1e-6, (top[..., :3] * at + bottom[..., :3] * ab * (1 - at)) / np.maximum(ao, 1e-6), 0)
    return np.concatenate([rgb, ao], -1)


def checker(h, w, s=8, c0=0.36, c1=0.46):
    yy, xx = np.indices((h, w))
    v = np.where(((yy // s) + (xx // s)) % 2 == 0, c0, c1).astype(np.float32)
    return np.dstack([v, v, v, np.ones_like(v)])
