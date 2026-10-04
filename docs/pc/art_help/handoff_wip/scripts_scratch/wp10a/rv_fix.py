"""Rowanvale/Windmere per-asset raw fixes used by rv_run.py (all retouch steps are reported)."""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np, cv2
sys.path.insert(0, str(Path(__file__).parent))
from wp10a_common import to_lab, hex2rgb, smoothstep
import wp10a_props as P


def _comp_touching(mask, seed):
    n, lab = cv2.connectedComponents(mask.astype(np.uint8), connectivity=4)
    ids = np.unique(lab[seed & mask]); ids = ids[ids > 0]
    return np.isin(lab, ids)


def remove_painted_shadow(cut, rgb, lower_frac=0.5, chroma_max=11.0, L_min=38.0, bg='white', report=None, extra_region=None, thin_open=0):
    """Painted ground/cast shadow on a white bg: neutral, light pixels reachable from the transparent background
    WITHOUT crossing the bold dark outline (stones/plaster/petals inside the outline survive). Lower part only."""
    a = cut[..., 3].copy()
    lab = to_lab(rgb)
    L = lab[..., 0]; C = np.hypot(lab[..., 1], lab[..., 2])
    ys = np.nonzero((a > 0.5).any(1))[0]
    y0, y1 = ys.min(), ys.max()
    lower = np.zeros_like(a, bool); lower[int(y0 + (1 - lower_frac) * (y1 - y0)):] = True
    if extra_region is not None:
        lower |= extra_region
    barrier = cv2.dilate((L < L_min).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    cand = (a > 0) & (C < chroma_max) & (L > L_min + 4) & ~barrier & lower
    trans = a <= 0.02
    sh = _comp_touching(cand | trans, trans) & cand
    # soft fringe: semi-transparent pixels next to the removed shadow that are still neutral
    ring = cv2.dilate(sh.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    fr = ring & ~sh & (C < chroma_max + 4) & (L > L_min + 4) & lower & (a < 0.9)
    out = cut.copy()
    out[..., 3] = np.where(sh | fr, 0, a)
    if thin_open:      # drop thin left-over shadow outlines (lines thinner than thin_open px) in the lower band
        solid = (out[..., 3] > 0.3).astype(np.uint8)
        ker = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (thin_open, thin_open))
        body = cv2.dilate(cv2.morphologyEx(solid, cv2.MORPH_OPEN, ker), np.ones((5, 5), np.uint8)) > 0
        thin = lower & ~body & (out[..., 3] > 0)
        out[..., 3] = np.where(thin, 0, out[..., 3])
        if report is not None: report['thin_removed_px'] = int(thin.sum())
    if report is not None:
        report['painted_shadow_removed_px'] = int((sh | fr).sum())
    return out


def whiten(rgb, boxes):
    """Paint rectangles (fractions of w/h) white before keying: removes intruding scenery from the raw."""
    out = rgb.copy(); h, w = rgb.shape[:2]
    for fx0, fy0, fx1, fy1 in boxes:
        out[int(fy0 * h):int(fy1 * h), int(fx0 * w):int(fx1 * w)] = 1.0
    return out


def outline_colour(rgb, a):
    lab = to_lab(rgb); m = (a > 0.9) & (lab[..., 0] < 22)
    return np.median(rgb[m], 0) if m.sum() > 50 else hex2rgb('#2a1c12')


def repair_flat_top(cut, rgb, report, depth_frac=0.035, bump_frac=0.045, outline_px=None, seed=3):
    """Canopy cut flat by the image top: carve a scalloped leaf-clump top a little lower and give it the bold outline."""
    a = cut[..., 3]; h, w = a.shape
    cols = np.nonzero(a[0] > 0.5)[0]
    if cols.size == 0:
        return cut
    ys, xs = np.nonzero(a > 0.5)
    W = xs.max() - xs.min()
    xa, xb = cols.min(), cols.max()
    r = bump_frac * W; d = depth_frac * (ys.max() - ys.min())
    rng = np.random.default_rng(seed)
    n = max(3, int(round((xb - xa) / (1.7 * r))))
    cx = np.linspace(xa + 0.5 * r, xb - 0.5 * r, n) + rng.uniform(-0.15, 0.15, n) * r
    rr = r * rng.uniform(0.85, 1.15, n)
    X = np.arange(w, dtype=np.float32)
    top = np.full(w, 1e9, np.float32)
    for c, q in zip(cx, rr):
        dx = np.abs(X - c)
        yb = np.where(dx < q, d + q - np.sqrt(np.maximum(q * q - dx * dx, 0)), 1e9)   # circle tops sitting at depth d
        top = np.minimum(top, yb)
    top = np.minimum(top, d + r)                                                      # valleys never deeper than d + r
    # fade to 0 cut outside [xa, xb]
    fade = np.clip(np.minimum(X - xa + r, xb + r - X) / r, 0, 1)
    top = top * fade
    yy = np.arange(h, dtype=np.float32)[:, None]
    dist = yy - top[None, :]                     # >0 below the new boundary
    keep = np.clip(dist + 0.5, 0, 1)
    out = cut.copy()
    out[..., 3] = a * keep
    ow = outline_px or max(2.0, 0.006 * W)
    oc = outline_colour(rgb, a)
    ol = (1 - smoothstep(ow * 0.6, ow * 1.3, dist)) * (dist > -1) * (top[None, :] > 0.5) * (a > 0.5)
    out[..., :3] = out[..., :3] * (1 - ol[..., None]) + oc * ol[..., None]
    report['flat_top_repaired'] = dict(cols=int(xb - xa + 1), depth_px=round(float(d + r), 1), bumps=int(n))
    return out


def remove_base_plate(cut, rgb, report, plate_top_frac, keep_hue=(8, 50)):
    """Beehive: drop the painted paving/grass plate under the legs; keep wood-coloured legs (and their outlines)."""
    a = cut[..., 3]; h, w = a.shape
    ys = np.nonzero((a > 0.5).any(1))[0]; y0, y1 = ys.min(), ys.max()
    yp = int(y0 + plate_top_frac * (y1 - y0))
    hsv = cv2.cvtColor(np.clip(rgb, 0, 1).astype(np.float32), cv2.COLOR_RGB2HSV)
    H, S, V = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    wood = (H >= keep_hue[0]) & (H <= keep_hue[1]) & (S > 0.35) & (V > 0.18) & (V < 0.92)
    dark = V < 0.28
    below = np.zeros_like(a, bool); below[yp:] = True
    keep = ~below | wood
    k = max(3, int(0.012 * (y1 - y0))) | 1
    keep_open = cv2.morphologyEx((keep & (a > 0.3)).astype(np.uint8), cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))) > 0
    keep_open = _comp_touching(keep_open, (~below) & (a > 0.5))
    # re-attach the legs' dark outlines: dark pixels adjacent to kept legs
    near = cv2.dilate(keep_open.astype(np.uint8), np.ones((k, k), np.uint8)) > 0
    keep_final = keep_open | (near & dark & below)
    keep_final |= ~below
    soft = cv2.GaussianBlur(keep_final.astype(np.float32), (0, 0), 0.8)
    out = cut.copy(); out[..., 3] = a * np.where(below, soft, 1.0)
    report['base_plate_removed_px'] = int(((a > 0.5) & below & ~keep_final).sum())
    return out


def palette_match(rgba, palette_hex, strength=0.3, max_shift=7.0, sigma=11.0, report=None, exclude_dark=24):
    """Light colour match: shift each colour cluster's mean a fraction of the way to its nearest palette colour
    (soft assignment, capped dE), keeping the painted variation and the dark outline."""
    a = rgba[..., 3]
    rgb = np.clip(rgba[..., :3], 0, 1).astype(np.float32)
    lab = to_lab(rgb)
    pal = np.stack([to_lab(hex2rgb(c)[None, None])[0, 0] for c in palette_hex])
    m = (a > 0.5) & (lab[..., 0] > exclude_dark)
    X = lab[m]
    if X.shape[0] < 50:
        return rgba
    d2 = ((X[:, None, :] - pal[None]) ** 2).sum(-1)
    wgt = np.exp(-(d2 - d2.min(1, keepdims=True)) / (2 * sigma ** 2)); wgt /= wgt.sum(1, keepdims=True)
    delta = np.zeros_like(pal)
    drift_before = float(np.sqrt(d2.min(1)).mean())
    for k in range(len(pal)):
        wk = wgt[:, k]
        if wk.sum() < 0.01 * X.shape[0]:
            continue
        mu = (X * wk[:, None]).sum(0) / wk.sum()
        dv = (pal[k] - mu) * strength
        nrm = np.linalg.norm(dv)
        if nrm > max_shift:
            dv *= max_shift / nrm
        delta[k] = dv
    shift = wgt @ delta
    X2 = X + shift
    lab2 = lab.copy(); lab2[m] = X2
    rgb2 = cv2.cvtColor(lab2.astype(np.float32), cv2.COLOR_Lab2RGB)
    # semi-transparent edge pixels follow with the same local shift (no new fringe): blend by alpha
    wa = smoothstep(0.3, 0.6, a)[..., None]
    out = rgba.copy(); out[..., :3] = np.clip(np.where(m[..., None], rgb2, rgb) * wa + rgb * (1 - wa), 0, 1)
    if report is not None:
        d2b = ((X2[:, None, :] - pal[None]) ** 2).sum(-1)
        report['palette_drift_dE'] = [round(drift_before, 1), round(float(np.sqrt(d2b.min(1)).mean()), 1)]
    return out


def remove_base_plate_poly(cut, rgb, report, edge_pts, keep_polys, edge_pad=7, soft=1.0):
    """Keep everything above a polyline (the object's bottom outline, raw work px) plus the given polygons (legs);
    drop the painted ground plate / grass / shadow below. Polygons are traced from the raw (reported as a retouch)."""
    a = cut[..., 3]; h, w = a.shape
    xs = np.array([p[0] for p in edge_pts], np.float32); ys = np.array([p[1] for p in edge_pts], np.float32)
    yline = np.interp(np.arange(w, dtype=np.float32), xs, ys) + edge_pad
    keep = (np.arange(h, dtype=np.float32)[:, None] <= yline[None, :]).astype(np.uint8)
    above = keep.copy()
    for poly in keep_polys:
        cv2.fillPoly(keep, [np.round(np.array(poly)).astype(np.int32)], 1)
    hsv = cv2.cvtColor(np.clip(rgb, 0, 1).astype(np.float32), cv2.COLOR_RGB2HSV)
    grassy = ((hsv[..., 0] > 50) & (hsv[..., 0] < 150) & (hsv[..., 1] > 0.2)) | ((hsv[..., 1] < 0.15) & (hsv[..., 2] > 0.6))
    grassy = cv2.dilate(grassy.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    keep = np.where((above == 0) & grassy, 0, keep).astype(np.uint8)
    keep = cv2.morphologyEx(keep, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    k = cv2.GaussianBlur(keep.astype(np.float32), (0, 0), soft)
    out = cut.copy(); out[..., 3] = a * k
    report['base_plate_removed_px'] = int(((a > 0.5) & (k < 0.5)).sum())
    return out


# ------------------------------------------------------------------ 3 Oct TA fix list: recolours
def _hsv01(rgb):
    hsv = cv2.cvtColor((np.clip(rgb, 0, 1) * 255).astype(np.uint8), cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
    return hsv[..., 0] * 360 / 256, hsv[..., 1] / 255, hsv[..., 2] / 255


def fruit_mask_seeds(rgb, seeds_frac, r_frac=(0.034, 0.048), v_out=0.36):
    """Outlined fruit (pears): flood from each seed through non-outline pixels inside an ellipse bound; seeds and radii
    are fractions of the image width/height (so they hold at any working resolution)."""
    H, W = rgb.shape[:2]
    h, s, v = _hsv01(rgb)
    free = (v > v_out).astype(np.uint8)
    out = np.zeros((H, W), np.uint8)
    yy, xx = np.indices((H, W))
    for fx, fy in seeds_frac:
        cx, cy = fx * W, fy * H; rx, ry = r_frac[0] * W, r_frac[1] * H
        ell = (((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2) <= 1
        n, lab = cv2.connectedComponents(free * ell.astype(np.uint8), connectivity=4)
        l = lab[int(cy), int(cx)]
        if l == 0:
            continue
        out |= (lab == l).astype(np.uint8)
    k = max(3, int(W * 0.006)) | 1
    out = cv2.dilate(out, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
    return out.astype(np.float32)


def shift_foliage_hue(rgba, target_median=72.0, hue_band=(30.0, 70.0), protect=None, sat_scale=1.0, report=None, key='foliage_hue_shift'):
    """Rotate the hue of the canopy foliage so its median lands on target_median. Foliage = opaque, saturated pixels
    with hue inside hue_band (soft edges), so red apples, the brown trunk and the outline are untouched; `protect`
    (0..1) masks fruit out of the shift."""
    rgb, a = rgba[..., :3], rgba[..., 3]
    h, s, v = _hsv01(rgb)
    lo, hi = hue_band
    w = np.clip((h - (lo - 4)) / 8, 0, 1) * np.clip(((hi + 4) - h) / 8, 0, 1) * np.clip((s - 0.18) / 0.12, 0, 1) * (a > 0.5)
    if protect is not None:
        w = w * (1 - cv2.GaussianBlur(protect.astype(np.float32), (0, 0), 1.5))
    sel = w > 0.5
    med = float(np.median(h[sel])) if sel.any() else target_median
    d = target_median - med
    h2 = (h + d * w) % 360
    s2 = np.clip(s * (1 + (sat_scale - 1) * w), 0, 1)
    hsv = np.dstack([h2 * 256 / 360, s2 * 255, v * 255])
    hsv[..., 0] = np.clip(hsv[..., 0], 0, 255)
    rgb2 = cv2.cvtColor(np.round(hsv).astype(np.uint8), cv2.COLOR_HSV2RGB_FULL).astype(np.float32) / 255
    # keep the original value channel exactly (HSV round-trip quantisation aside) -> blend by weight
    out = rgba.copy(); out[..., :3] = rgb * (1 - w[..., None]) + rgb2 * w[..., None]
    if report is not None:
        report[key] = dict(median_before=round(med, 1), shift_deg=round(d, 1), target=target_median, px=int(sel.sum()),
                           protected_px=int((protect > 0.5).sum()) if protect is not None else 0, sat_scale=sat_scale)
    return out


def recolour_red_to_white(rgba, report=None, honey=None):
    """Beehive: red-painted boxes -> off-white boards (shading kept as value), with honey-gold kept/added on the
    already-gold parts. Red = hue <= 14 or >= 340, s > 0.35."""
    rgb, a = rgba[..., :3], rgba[..., 3]
    h, s, v = _hsv01(rgb)
    red = (((h <= 14) | (h >= 338)) & (s > 0.35) & (a > 0.3)).astype(np.float32)
    red = cv2.GaussianBlur(red, (0, 0), 0.8)
    white = np.array([0.96, 0.93, 0.86], np.float32)          # warm off-white (keyed light #fff0c8)
    lum = (0.25 + 0.75 * np.clip(v / max(np.percentile(v[red > 0.5], 95) if (red > 0.5).any() else 1, 1e-3), 0, 1))
    newc = white[None, None, :] * lum[..., None]
    shade = np.array([0.80, 0.80, 0.90], np.float32)           # cool shade tint on the dark side
    newc = newc * (shade + (1 - shade) * np.clip(lum, 0, 1)[..., None])
    out = rgba.copy(); out[..., :3] = rgb * (1 - red[..., None]) + newc * red[..., None]
    if report is not None:
        report['red_to_white_px'] = int((red > 0.5).sum())
    return out


def hedge_recolour(rgba, target_median=70.0, sat_scale=0.86, report=None):
    return shift_foliage_hue(rgba, target_median, hue_band=(40.0, 95.0), sat_scale=sat_scale, report=report, key='hedge_hue_shift')


def trim_run_ends(axis, overhang_2x=8.0, feather_2x=1.5, wobble_2x=1.5, seed=7):
    """post_render hook: cut a 1x1 run piece (fence/hedge/wall) so its ends overhang the cell edge by at most
    overhang_2x px (Euclidean, like the checker's distance outside the footprint). axis 'nwse' runs along world u,
    'nesw' along world w. Coordinates at 2x: X = 64 (u - w), Y = 32 (u + w) about the footprint centre (0, -32)."""
    def f(layers, ss, W2, H2, report):
        Hs, Ws = layers.shape[:2]
        yy, xx = np.indices((Hs, Ws), np.float32)
        X = (xx + 0.5) / ss - W2 / 2; Y = (yy + 0.5) / ss - (H2 - 32)
        u = X / 128 + Y / 64; w = Y / 64 - X / 128
        t = np.abs(u if axis == 'nwse' else w)
        lim = 0.5 + overhang_2x / 57.24          # 1 cell unit along the run = 57.24 px normal to the cell edge at 2x
        rng = np.random.default_rng(seed)
        along = (w if axis == 'nwse' else u)
        wob = np.interp(along, np.linspace(-1.5, 1.5, 64), rng.normal(0, 1, 64)) * wobble_2x / 57.24
        keep = np.clip((lim + wob - t) * 57.24 / max(feather_2x, 1e-3) + 0.5, 0, 1)
        out = layers.copy(); before = (out[..., 3] > 0.5).sum()
        out[..., 3] *= keep
        report['end_trim'] = dict(axis=axis, max_overhang_2x=overhang_2x, alpha_px_removed_ss=int(before - (out[..., 3] > 0.5).sum()))
        return out
    return f


def beehive_white_boxes(lid_v=(64.0, 62.5, 0.35), bot_v=(64.0, 95.0, 0.40)):
    """post_render hook for beehive_box: the box bodies (between the lid rim and the bottom box edge, both V-shaped
    in 2x px: y = y0 - k|x - xc|) become warm off-white boards with their painted shading kept as value; the lid,
    legs, entrance slots, seams and bees keep their honey-gold / wood colours."""
    def f(layers, ss, W2, H2, report):
        Hs, Ws = layers.shape[:2]
        yy, xx = np.indices((Hs, Ws), np.float32)
        X = (xx + 0.5) / ss; Y = (yy + 0.5) / ss
        y_lid = lid_v[1] - lid_v[2] * np.abs(X - lid_v[0]); y_bot = bot_v[1] - bot_v[2] * np.abs(X - bot_v[0])
        band = np.clip((Y - y_lid) * 2 + 0.5, 0, 1) * np.clip((y_bot - Y) * 2 + 0.5, 0, 1)
        rgb, a = layers[..., :3], layers[..., 3]
        h, s, v = _hsv01(rgb)
        paint = band * np.clip((v - 0.33) / 0.12, 0, 1) * np.clip((s - 0.2) / 0.1, 0, 1) * (a > 0.3)
        vref = np.percentile(v[paint > 0.5], 96) if (paint > 0.5).any() else 1.0
        lum = np.clip(v / vref, 0, 1)
        white = np.array([0.97, 0.94, 0.87], np.float32); shade = np.array([0.78, 0.79, 0.90], np.float32)
        newc = white * (0.18 + 0.82 * lum)[..., None] * (shade + (1 - shade) * lum[..., None])
        out = layers.copy(); out[..., :3] = rgb * (1 - paint[..., None]) + newc * paint[..., None]
        report['white_boxes_px_2x'] = int((paint > 0.5).sum() / ss / ss)
        return out
    return f
