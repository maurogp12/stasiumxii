"""WP10a ground tiles: project one seamless top-down swatch into seamless 2:1 diamond variants.

One cell = one full period of the swatch (the swatch is rotated 45 deg and squashed 2:1 onto the diamond, as the
Crosshaven floors were). Every variant has the same edge band (variants only differ inside, through an edge-pinned blend
with a shifted copy of the swatch), so any variant can sit next to any other: the Crosshaven hash picker keeps working.
Rendered at 8x supersampling of the 2x master (1024x512), then box-downsampled to 2x (128x64) and, separately, 1x (64x32).
RGB outside the diamond continues the texture, so the 0.5 px alpha bleed shows the right neighbour colour.

Light: the swatch's LEFT edge becomes the diamond's NW edge (screen top-left). If the painter lit the swatch from another
side, pass --rot so the lit side ends up on the left.

Usage:
  wp10a_tiles.py SWATCH FAMILY --variants a,b,c --out DIR [--directional u|v] [--rot K] [--fix-seams]
                 [--edges BASE_SWATCH] [--seed N] [--preview PNG]
"""
from __future__ import annotations
import argparse, hashlib, json, sys
from pathlib import Path
import numpy as np
import cv2
from scipy.ndimage import map_coordinates
sys.path.insert(0, str(Path(__file__).parent))
from wp10a_common import (CROSSHAVEN, SS, load_rgb, save_rgba, down_box, smoothstep, over, luminance)

W2, H2 = 128, 64                  # 2x master
WS, HS = W2 * SS, H2 * SS         # 1024 x 512 supersampled
SIDES = ('nw', 'ne', 'se', 'sw')
CORNERS = {'n': ('nw', 'ne'), 'e': ('ne', 'se'), 's': ('se', 'sw'), 'w': ('nw', 'sw')}
EDGE_W0, EDGE_W1, EDGE_AMP = 0.10, 0.34, 0.07   # transition band (cell units) and boundary wiggle; AMP*max|n| < W0
EDGE_BREAKUP = 0.9                                # base-texture-driven raggedness of the transition


# ---------------------------------------------------------------- swatch prep
def seam_score(img):
    """Wrap seam / mean neighbour step. ~1 = seamless; > 1.8 = visible seam."""
    dc = np.abs(np.diff(img, axis=1)).mean(); dr = np.abs(np.diff(img, axis=0)).mean()
    sc = np.abs(img[:, 0] - img[:, -1]).mean() / max(dc, 1e-6)
    sr = np.abs(img[0] - img[-1]).mean() / max(dr, 1e-6)
    return float(sc), float(sr)


def fix_seams(img, frac=0.22):
    """Offset blend: near the borders use the half-rolled copy (continuous across the wrap), inside keep the original."""
    s = img.shape[0]
    r = np.roll(img, (s // 2, s // 2), (0, 1))
    t = (np.arange(s) + 0.5) / s
    d = np.minimum(t, 1 - t)
    w1 = 1 - smoothstep(0, frac, d)
    w = np.maximum(w1[:, None], w1[None, :])[..., None]
    return img * (1 - w) + r * w


def prep_swatch(path, rot=0, fix=False, period=1024):
    img = load_rgb(path)
    h, w = img.shape[:2]
    if h != w:
        s = min(h, w); y0, x0 = (h - s) // 2, (w - s) // 2
        img = img[y0:y0 + s, x0:x0 + s]
        print(f'  note: {Path(path).name} is {w}x{h}; centre-cropped to {s}x{s} (crop breaks seamlessness: use --fix-seams)')
    img = np.rot90(img, rot).copy()
    sc = seam_score(img)
    if fix:
        img = fix_seams(img); sc2 = seam_score(img)
        print(f'  seam score cols/rows {sc[0]:.2f}/{sc[1]:.2f} -> {sc2[0]:.2f}/{sc2[1]:.2f} after --fix-seams')
    elif max(sc) > 1.8:
        print(f'  WARNING: seam score cols/rows {sc[0]:.2f}/{sc[1]:.2f} (> 1.8): swatch is not seamless; rerun with --fix-seams')
    # wrap-aware resample to the working period
    s = img.shape[0]
    if s != period:
        pad = max(4, s // 16)
        big = np.pad(img, ((pad, pad), (pad, pad), (0, 0)), mode='wrap')
        f = period / s
        big = cv2.resize(big, None, fx=f, fy=f, interpolation=cv2.INTER_AREA if f < 1 else cv2.INTER_CUBIC)
        p = int(round(pad * f))
        img = big[p:p + period, p:p + period]
        img = cv2.resize(img, (period, period), interpolation=cv2.INTER_AREA)
    return np.clip(img, 0, 1).astype(np.float32), sc


# ---------------------------------------------------------------- geometry
def world_grid(ws=WS, hs=HS):
    """World coords (cell units, NW origin) of every supersampled pixel centre; cell (0,0) occupies [0,1)^2."""
    yy, xx = np.indices((hs, ws), np.float32)
    sx = ((xx + 0.5) / ws * W2 - W2 / 2) / 2       # 1x px from the north tip
    sy = ((yy + 0.5) / hs * H2) / 2
    xw = sx / 64 + sy / 32
    yw = sy / 32 - sx / 64
    return xw, yw


def sample(tex, xw, yw, du=0.0, dv=0.0):
    p = tex.shape[0]
    u = (xw + du) * p - 0.5
    v = (yw + dv) * p - 0.5
    return np.stack([map_coordinates(tex[..., c], [v, u], order=1, mode='grid-wrap') for c in range(3)], -1)


_ALPHA = {}
def floor_alpha(w, h):
    """Crosshaven floor alpha (64x32 / 128x64 diamond with 0.5 px bleed), bit-identical when the kit is on the box."""
    if (w, h) in _ALPHA:
        return _ALPHA[(w, h)]
    f = CROSSHAVEN / ('tiles/golden_plains_a.png' if w == 64 else 'tiles/_2x/golden_plains_a.png')
    if f.exists():
        from PIL import Image
        a = np.asarray(Image.open(f).convert('RGBA'), np.float32)[..., 3] / 255.0
    else:   # analytic fallback: diamond grown by 0.5 px, 16x coverage
        k = 16
        yy, xx = np.indices((h * k, w * k), np.float32)
        x = (xx + 0.5) / k; y = (yy + 0.5) / k
        d = (np.abs(x - w / 2) / (w / 2) + np.abs(y - h / 2) / (h / 2) - 1) * (h / 2) / np.sqrt(1.25)  # px from edge
        a = (d <= 0.5).astype(np.float32).reshape(h, k, w, k).mean((1, 3))
    _ALPHA[(w, h)] = a
    return a


def finish(rgb_ss, alpha_mul_ss=None):
    """SS rgb -> (2x rgba, 1x rgba) with the floor alpha; optional extra alpha (corner decals)."""
    a_ss = np.ones(rgb_ss.shape[:2], np.float32) if alpha_mul_ss is None else alpha_mul_ss
    rgba = np.dstack([rgb_ss, a_ss])
    t2 = down_box(rgba, SS); t1 = down_box(rgba, SS * 2)
    t2[..., 3] *= floor_alpha(W2, H2); t1[..., 3] *= floor_alpha(W2 // 2, H2 // 2)
    return t2, t1


# ---------------------------------------------------------------- variants
def blob_noise(shape, seed, sigma):
    rng = np.random.default_rng(seed)
    n = rng.random((shape[0] // 8, shape[1] // 8)).astype(np.float32)
    n = cv2.GaussianBlur(n, (0, 0), sigma / 8)
    n = cv2.resize(n, (shape[1], shape[0]), interpolation=cv2.INTER_CUBIC)
    return (n - n.min()) / max(np.ptp(n), 1e-6)


def edge_window(xw, yw, m0=0.07, m1=0.22):
    d = np.minimum.reduce([xw, 1 - xw, yw, 1 - yw])
    return smoothstep(m0, m1, d)


def variant_rgb(tex, k, xw, yw, seed, directional=None):
    base = sample(tex, xw, yw)
    if k == 0:
        return base
    if directional == 'tint':   # hard-edged pattern (flagstone joints): no shifted-copy blend (it ghosts the joints), value wobble only
        win = edge_window(xw, yw)
        tint = 1 + 0.06 * (blob_noise(xw.shape, seed + 7 * k, 90) * 2 - 1) * win
        return np.clip(base * tint[..., None], 0, 1)
    phi = 0.6180339887
    du, dv = (k * phi) % 1, (k * phi * phi + 0.37) % 1
    if directional == 'u':      # furrows run along u: never shift across them
        dv = 0.0
    elif directional == 'v':
        du = 0.0
    alt = sample(tex, xw, yw, du, dv)
    win = edge_window(xw, yw)
    m = smoothstep(0.38, 0.62, blob_noise(xw.shape, seed + 101 * k, 70)) * win
    rgb = base * (1 - m[..., None]) + alt * m[..., None]
    tint = 1 + 0.035 * (blob_noise(xw.shape, seed + 7 * k, 120) * 2 - 1) * win      # soft value wobble, pinned at edges
    return np.clip(rgb * tint[..., None], 0, 1)


# ---------------------------------------------------------------- autotile edges / corners
def side_noise(name, t):
    h = int(hashlib.md5(name.encode()).hexdigest()[:8], 16)
    rng = np.random.default_rng(h)
    n = np.zeros_like(t)
    for f in range(1, 5):
        n += rng.uniform(0.4, 1.0) / f * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
    return n / 1.6                                            # |n| <= ~1


def side_term(side, xw, yw, fam):
    d, t = {'nw': (xw, yw), 'ne': (yw, xw), 'se': (1 - xw, yw), 'sw': (1 - yw, xw)}[side]
    return smoothstep(EDGE_W0, EDGE_W1, d + EDGE_AMP * side_noise(fam + side, t))


def edge_mask(sides, xw, yw, fam):
    f = np.ones_like(xw)
    for s in sides:
        f *= side_term(s, xw, yw, fam)
    return f


def corner_alpha(c, xw, yw, fam):
    a, b = CORNERS[c]
    fam_mask = 1 - (1 - side_term(a, xw, yw, fam)) * (1 - side_term(b, xw, yw, fam))
    return 1 - fam_mask


def breakup_field(btex):
    """World-consistent high-pass of the base swatch luminance in [-1,1]: lets base tufts poke into the family edge."""
    lum = btex @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    pad = btex.shape[0] // 8
    big = np.pad(lum, pad, mode='wrap')
    hp = (big - cv2.GaussianBlur(big, (0, 0), btex.shape[0] / 40))[pad:-pad, pad:-pad]
    hp = np.clip(hp / (2.5 * hp.std() + 1e-6), -1, 1)
    return np.repeat(hp[..., None], 3, -1).astype(np.float32)


def apply_breakup(f, hp, k=EDGE_BREAKUP):
    """Ragged painted transition; the 4f(1-f) window keeps f exactly 0 / 1 where it was, so neighbours still match."""
    return np.clip(f - k * hp * 4 * f * (1 - f), 0, 1)


def edge_sets():
    out = []
    for m in range(1, 16):
        out.append([s for i, s in enumerate(SIDES) if m >> i & 1])
    return out


# ---------------------------------------------------------------- main build
def build(swatch, family, variants, out, directional=None, rot=0, fix=False, edges=None, seed=7, base_rot=0, base_fix=False):
    out = Path(out)
    tex, sc = prep_swatch(swatch, rot, fix)
    xw, yw = world_grid()
    files = []
    for k, v in enumerate(variants):
        rgb = variant_rgb(tex, k, xw, yw, seed, directional)
        t2, t1 = finish(rgb)
        save_rgba(out / 'tiles' / '_2x' / f'{family}_{v}.png', t2); save_rgba(out / 'tiles' / f'{family}_{v}.png', t1)
        files.append(f'{family}_{v}')
    if edges:
        btex, _ = prep_swatch(edges, base_rot, base_fix)
        fam_rgb = sample(tex, xw, yw); base_rgb = sample(btex, xw, yw)
        hp = sample(breakup_field(btex), xw, yw)[..., 0]
        for sides in edge_sets():
            f = apply_breakup(edge_mask(sides, xw, yw, family), hp)[..., None]
            t2, t1 = finish(base_rgb * (1 - f) + fam_rgb * f)
            name = f"{family}_edge_{'_'.join(sides)}"
            save_rgba(out / 'tiles' / '_2x' / f'{name}.png', t2); save_rgba(out / 'tiles' / f'{name}.png', t1)
            files.append(name)
        for c in CORNERS:
            t2, t1 = finish(base_rgb, 1 - apply_breakup(1 - corner_alpha(c, xw, yw, family), hp))
            name = f'{family}_corner_{c}'
            save_rgba(out / 'tiles' / '_2x' / f'{name}.png', t2); save_rgba(out / 'tiles' / f'{name}.png', t1)
            files.append(name)
    return files, sc


# ---------------------------------------------------------------- seam test / preview
def hpick(x, y, k):
    return (((x * 73856093) ^ (y * 19349663) ^ (x * y * 83492791)) & 0x7fffffff) % k


def render_board(tile_for_cell, n, scale2x=True, bg=(0.05, 0.05, 0.07)):
    """Draw an n x n board with the Crosshaven anchor rule; tile_for_cell(x,y) -> list of rgba (drawn in order)."""
    tw, th = (W2, H2) if scale2x else (W2 // 2, H2 // 2)
    Wb, Hb = n * tw + 4, n * th + th + 4
    ox, oy = Wb // 2, 2
    img = np.zeros((Hb, Wb, 4), np.float32); img[..., :3] = bg; img[..., 3] = 1
    for s in range(2 * n - 1):
        for x in range(n):
            y = s - x
            if not 0 <= y < n:
                continue
            cx = ox + (x - y) * tw // 2; ty = oy + (x + y) * th // 2
            for t in tile_for_cell(x, y):
                reg = img[ty:ty + th, cx - tw // 2: cx + tw // 2]
                img[ty:ty + th, cx - tw // 2: cx + tw // 2] = over(t, reg)
    return img


def seam_metric(tiles_2x, tex_ref, n=6):
    """Max / mean |board - continuous projection| over the interior; ~1/255 means seamless (only 8-bit rounding + bleed)."""
    # continuous reference: the whole board area projected directly from the swatch (variant 0 everywhere)
    board = render_board(lambda x, y: [tiles_2x[0]], n)
    Hb, Wb = board.shape[:2]
    ox = Wb // 2; oy = 2
    yy, xx = np.indices((Hb, Wb), np.float32)
    sx = (xx + 0.5 - ox) / 2; sy = (yy + 0.5 - oy) / 2
    xw = sx / 64 + sy / 32; yw = sy / 32 - sx / 64
    inside = (xw > 0.02) & (yw > 0.02) & (xw < n - 0.02) & (yw < n - 0.02)
    # sample at 1 px (no supersampling) so compare after a light blur on both
    ref = sample(tex_ref, xw, yw)
    a = cv2.GaussianBlur(board[..., :3], (0, 0), 1.0); b = cv2.GaussianBlur(ref, (0, 0), 1.0)
    d = np.abs(a - b).max(-1)[inside]
    # hairline test: board on black vs on white must agree where the floor covers (any gap shows)
    board_w = render_board(lambda x, y: [tiles_2x[0]], n, bg=(1, 1, 1))
    gap = np.abs(board_w[..., :3] - board[..., :3]).max(-1)[inside]
    return dict(max_abs_vs_continuous=float(d.max()), mean_abs_vs_continuous=float(d.mean()),
                hairline_max=float(gap.max()), hairline_px=int((gap > 2 / 255).sum()))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('swatch'); ap.add_argument('family')
    ap.add_argument('--variants', default='a,b'); ap.add_argument('--out', required=True)
    ap.add_argument('--directional', choices=('u', 'v')); ap.add_argument('--rot', type=int, default=0)
    ap.add_argument('--fix-seams', action='store_true'); ap.add_argument('--edges')
    ap.add_argument('--base-rot', type=int, default=0); ap.add_argument('--base-fix-seams', action='store_true')
    ap.add_argument('--seed', type=int, default=7)
    a = ap.parse_args()
    files, sc = build(a.swatch, a.family, a.variants.split(','), a.out, a.directional, a.rot, a.fix_seams, a.edges, a.seed,
                      a.base_rot, a.base_fix_seams)
    print(f'{a.family}: {len(files)} tiles -> {a.out}/tiles (+_2x); swatch seam score {sc[0]:.2f}/{sc[1]:.2f}')


if __name__ == '__main__':
    main()
