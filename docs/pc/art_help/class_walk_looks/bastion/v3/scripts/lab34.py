import numpy as np
M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
WP = np.array([0.95047, 1, 1.08883])
def rgb2lab(rgb):
    c = rgb.astype(np.float64) / 255.0; c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    xyz = c @ M.T / WP
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)
def lab2rgb(lab):
    fy = (lab[..., 0] + 16) / 116; fx = fy + lab[..., 1] / 500; fz = fy - lab[..., 2] / 200
    f = np.stack([fx, fy, fz], -1)
    xyz = np.where(f > 0.206893, f ** 3, (f - 16 / 116) / 7.787) * WP
    c = xyz @ np.linalg.inv(M).T
    c = np.where(c > 0.0031308, 1.055 * np.clip(c, 0, None) ** (1 / 2.4) - 0.055, 12.92 * c)
    return np.clip(np.round(c * 255), 0, 255).astype(np.uint8)

from scipy import ndimage as ndi

def cloth_weight(lab, mask, c_lo=10.0, c_hi=16.0, hue=(0.0, 40.0)):
    """Soft cloth (crimson cape/tabard) weight: red-hued, chroma ramp c_lo..c_hi, then
    spatially regularised (large connected regions only, slightly dilated)."""
    ch = np.hypot(lab[..., 1], lab[..., 2]); hu = np.degrees(np.arctan2(lab[..., 2], lab[..., 1]))
    red = (hu >= hue[0]) & (hu <= hue[1]) & mask
    w = np.clip((ch - c_lo) / (c_hi - c_lo), 0, 1) * red
    core = ndi.binary_opening(w > 0.5, iterations=1)
    lab_, n = ndi.label(core)
    sz = np.bincount(lab_.ravel()); sz[0] = 0
    big = np.isin(lab_, np.nonzero(sz >= 400)[0])
    big = ndi.binary_closing(big, iterations=2)
    big = ndi.binary_dilation(big, iterations=1) & mask
    ws = ndi.uniform_filter(big.astype(np.float64), 3)
    return np.clip(np.maximum(ws, w * big), 0, 1) * mask

def cdf_map(src_vals, ref_vals, n=1024):
    q = np.linspace(0, 1, n)
    return np.quantile(src_vals, q), np.quantile(ref_vals, q)

def match_armor(rgb, mask, ref_lab_pixels, src_pool=None):
    """LAB per-channel CDF match of armour (non-cloth) pixels to ref armour pixels.
    Cloth keeps its colour (blend by 1-cloth_weight)."""
    lab = rgb2lab(rgb)
    cw = cloth_weight(lab, mask)
    arm = mask & (cw < 0.05)
    pool = src_pool if src_pool is not None else lab[arm]
    out = lab.copy()
    for c in range(3):
        sq, rq = cdf_map(pool[:, c], ref_lab_pixels[:, c])
        out[..., c] = np.interp(lab[..., c], sq, rq)
    new = lab2rgb(out)
    a = (1 - cw)[..., None] * mask[..., None]
    res = np.round(rgb * (1 - a) + new * a).astype(np.uint8)
    return res, cw

def cloth_weight2(lab, mask, belt_frac=0.47, seed_c=10.0, low_c=4.0, grow=6):
    """Cloth = crimson regions that hang below the belt (cape, tabard), grown up to `grow` px
    through lower-chroma red px (cape shadows/edges). Red patches confined above the belt
    (lacquered pauldron/chest trim) are NOT cloth -> treated as armour. Per figure mask."""
    ch = np.hypot(lab[..., 1], lab[..., 2]); hu = np.degrees(np.arctan2(lab[..., 2], lab[..., 1]))
    out = np.zeros(mask.shape, np.float64)
    lab_m, nm = ndi.label(mask)
    ys, xs = np.nonzero(mask); top, bot = ys.min(), ys.max(); belt = top + belt_frac * (bot - top)
    core = ndi.binary_opening(mask & (ch > seed_c) & (hu >= 0) & (hu <= 40), iterations=1)
    cl, n = ndi.label(core)
    seeds = np.zeros_like(mask)
    objs = ndi.find_objects(cl)
    for k, sl in enumerate(objs, 1):
        c = cl[sl] == k
        if c.sum() >= 60 and sl[0].stop - 1 > belt:
            seeds[sl] |= c
    low = mask & (ch > low_c) & (hu >= -10) & (hu <= 45)
    g = seeds.copy()
    for _ in range(grow):
        g = (ndi.binary_dilation(g) & low) | g
    g = ndi.binary_closing(g, iterations=1) & mask
    return np.clip(ndi.uniform_filter(g.astype(np.float64), 3), 0, 1) * mask

def match_armor2(rgb, masks, ref_rgb, ref_mask):
    """Pool armour px (cloth_weight2 < 0.05) of all `masks` -> per-channel LAB CDF match to
    the ref figure's armour px; result blended by (1 - cloth weight)."""
    rl = rgb2lab(ref_rgb); rcw = cloth_weight2(rl, ref_mask)
    ref = rl[ref_mask & (rcw < 0.05)]
    lab = rgb2lab(rgb)
    cws = [cloth_weight2(lab, m) for m in masks]
    pool = np.concatenate([lab[m & (w < 0.05)] for m, w in zip(masks, cws)])
    out = lab.copy(); maps = []
    for c in range(3):
        sq, rq = cdf_map(pool[:, c], ref[:, c]); maps.append((sq, rq))
        out[..., c] = np.interp(lab[..., c], sq, rq)
    new = lab2rgb(out).astype(np.float64)
    res = rgb.astype(np.float64).copy()
    for m, w in zip(masks, cws):
        a = ((1 - w) * m)[..., None]
        res = res * (1 - a) + new * a
    stats = dict(ref_armour_px=int(len(ref)), src_armour_px=int(len(pool)),
                 ref_pct=[np.percentile(ref[:, c], [10, 50, 90]).round(2).tolist() for c in range(3)],
                 src_pct=[np.percentile(pool[:, c], [10, 50, 90]).round(2).tolist() for c in range(3)],
                 ref_cloth_frac=round(float((rcw[ref_mask] > 0.5).mean()), 3),
                 src_cloth_frac=[round(float((w[m] > 0.5).mean()), 3) for m, w in zip(masks, cws)])
    return np.round(res).astype(np.uint8), cws, stats
