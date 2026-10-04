"""Northgate snow ground: world-space snow field and snowy cobble.

Both textures tile in world pixels (period 256 x 128 at 1x, one repeat every
four cells along each ground axis), so the scene can map them across many
cells with no per-cell seam. The 2x master is 512 x 256 and draws at 0.5.
"""

from __future__ import annotations

import numpy as np

from common import periodic_noise, save_pair, smoothstep

PERIOD_CELLS = 4
W1, H1 = 64 * PERIOD_CELLS, 32 * PERIOD_CELLS  # 1x world pixels per repeat


def _ground_uv(w: int, h: int) -> tuple[np.ndarray, np.ndarray]:
    """Ground-plane coords (in cells) for each pixel of a w x h 2x canvas."""
    sx = w / W1
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    px = (xs + 0.5) / sx
    py = (ys + 0.5) / sx
    # cell_to_local: x = (u - v) * 32, y = (u + v) * 16
    u = (px / 32.0 + py / 16.0) * 0.5
    v = (py / 16.0 - px / 32.0) * 0.5
    return u, v


def snow_field(scale: int = 2) -> np.ndarray:
    w, h = W1 * scale, H1 * scale
    rng = np.random.default_rng(41)
    big = periodic_noise(w, h, 5.0, rng)
    mid = periodic_noise(w, h, 16.0, rng)
    fine = periodic_noise(w, h, 60.0, rng)
    grain = rng.random((h, w))
    # Soft drifts: mostly bright, a cool blue-lilac low side.
    shade = 0.6 * big + 0.3 * mid + 0.1 * fine
    shade = (shade - shade.min()) / (shade.max() - shade.min())
    hi = np.array([0.975, 0.982, 1.0])
    lo = np.array([0.84, 0.865, 0.95])
    t = smoothstep(0.10, 0.70, shade)[..., None]
    rgb = lo * (1 - t) + hi * t
    lilac = np.array([0.87, 0.86, 0.97])
    band = np.exp(-((shade - 0.30) ** 2) / 0.015)[..., None] * 0.25
    rgb = rgb * (1 - band) + lilac * band
    # Painted stipple, so a wide field is not a flat colour.
    rgb = rgb - (grain[..., None] < 0.06) * np.array([0.035, 0.03, 0.012])
    # Sparkles: sparse single bright dots on the lit side.
    spark = (grain > 0.9978) & (shade > 0.5)
    rgb[spark] = np.array([1.0, 1.0, 1.0])
    a = np.ones((h, w))
    return np.dstack([np.clip(rgb, 0, 1), a])


def _voronoi(u: np.ndarray, v: np.ndarray, per_cell: int, rng) -> tuple:
    """Periodic jittered Voronoi in ground space. Returns (f1, f2, id)."""
    n = PERIOD_CELLS * per_cell
    gy, gx = np.mgrid[0:n, 0:n]
    jit = rng.random((n, n, 2)) * 0.7 + 0.15
    su = (gx + jit[..., 0]) / per_cell
    sv = (gy + jit[..., 1]) / per_cell
    seeds = np.stack([su.ravel(), sv.ravel()], 1)
    P = float(PERIOD_CELLS)
    uu = np.mod(u, P)
    vv = np.mod(v, P)
    f1 = np.full(u.shape, 9e9)
    f2 = np.full(u.shape, 9e9)
    ids = np.zeros(u.shape, dtype=np.int32)
    for k, (a, b) in enumerate(seeds):
        du = uu - a
        dv = vv - b
        du = du - P * np.round(du / P)
        dv = dv - P * np.round(dv / P)
        d = np.sqrt(du * du + dv * dv)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        ids = np.where(closer, k, ids)
        f1 = np.where(closer, d, f1)
    return f1, f2, ids, seeds.shape[0]


def snow_cobble(scale: int = 2) -> np.ndarray:
    """Grey-blue cobbles, snow packed in the joints, a light dusting on top."""
    w, h = W1 * scale, H1 * scale
    rng = np.random.default_rng(7)
    u, v = _ground_uv(w, h)
    f1, f2, ids, count = _voronoi(u, v, 3, rng)
    edge = f2 - f1  # 0 on a joint
    tone = rng.random(count)
    warm = rng.random(count)
    stone_base = np.array([0.60, 0.62, 0.68])
    warm_stone = np.array([0.66, 0.60, 0.54])
    k = warm[ids][..., None]
    base = stone_base * (1 - k * 0.7) + warm_stone * (k * 0.7)
    base = base * (0.86 + 0.24 * tone[ids])[..., None]
    # Rounded dome, lit from the upper left like the kit.
    dome = smoothstep(0.0, 0.22, edge)
    rgb = base * (0.62 + 0.38 * dome)[..., None]
    grain = periodic_noise(w, h, 90.0, np.random.default_rng(99))
    rgb = rgb * (0.95 + 0.10 * grain)[..., None]
    # Dark joints with a soft outline.
    joint = 1 - smoothstep(0.0, 0.05, edge)
    rgb = rgb * (1 - joint[..., None] * 0.6)
    snow_col = np.array([0.92, 0.94, 0.99])
    # Packed snow in the joints, in patches, not a white net.
    jn = periodic_noise(w, h, 10.0, np.random.default_rng(5))
    patch = smoothstep(0.55, 0.72, jn)
    jsnow = (1 - smoothstep(0.0, 0.07, edge)) * patch
    rgb = rgb * (1 - jsnow[..., None] * 0.95) + snow_col * (jsnow[..., None] * 0.95)
    # Thin dusting on some stone tops.
    dn = periodic_noise(w, h, 7.0, np.random.default_rng(11))
    dust = smoothstep(0.60, 0.80, dn) * smoothstep(0.05, 0.2, edge) * 0.5
    rgb = rgb * (1 - dust[..., None]) + snow_col * dust[..., None]
    a = np.ones((h, w))
    return np.dstack([np.clip(rgb, 0, 1), a])


# --- Height faces --------------------------------------------------------

def _snow_face(src: np.ndarray, top: bool) -> np.ndarray:
    """Cliff face strip repainted: cool grey stone, snow instead of grass."""
    from snow_props import _cap, _snow_colour
    from common import luma, rgb_to_hsv

    out = src.copy()
    op = src[..., 3] > 0.05
    hsv = rgb_to_hsv(src[..., :3])
    lum = luma(src[..., :3])
    green = op & (hsv[..., 0] > 55) & (hsv[..., 0] < 160) & (hsv[..., 1] > 0.2)
    stone = np.clip(lum[..., None] * np.array([0.90, 0.91, 0.98]) * 0.80, 0, 1)
    out[..., :3] = np.where(op[..., None], stone, out[..., :3])
    snow = _snow_colour(0.55 + 0.45 * np.clip((lum - lum[green].min()) / max(np.ptp(lum[green]), 1e-3), 0, 1)) if green.any() else None
    if snow is not None:
        out[..., :3] = np.where(green[..., None], snow, out[..., :3])
    if top:
        out = _cap(out, 7, 2, 17)
    return out


def snow_faces(tiles) -> list[str]:
    from common import load

    written = []
    for side in ("left", "right"):
        for variant in ("top", "a", "b", "base_ground", "base_water"):
            src = tiles / "_2x" / f"cliff_side_{side}_{variant}.png"
            if not src.exists():
                continue
            written += save_pair(tiles, f"snow_side_{side}_{variant}", _snow_face(load(src), variant == "top"))
    return written


def build(out_root) -> list[str]:
    written = []
    written += save_pair(out_root / "tiles", "snow_field", snow_field(2))
    written += save_pair(out_root / "tiles", "snow_cobble_field", snow_cobble(2))
    written += snow_faces(out_root / "tiles")
    return written
