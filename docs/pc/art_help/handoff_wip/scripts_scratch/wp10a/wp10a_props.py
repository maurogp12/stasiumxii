"""WP10a prop processing: raw Scenario paint on a flat background -> kit-ready 2x master + 1x + masks/strips.

Steps per asset (all parameters come from raw/wp10a/manifest.json):
  1. key the flat background (white for Rowanvale, black for Windmere). The background field is measured (Scenario drifts:
     off-white, vignettes, frames), alpha comes from a colour-line projection in the edge band, colours are decontaminated,
     stray marks/text far from the object are dropped. --matte hybrid uses rembg (birefnet-general-lite, cached in
     ~/.rembg) to rescue enclosed bg-coloured details (white petals on white, dark outlines on black).
  2. trim, find the ground contact (bottom of the main silhouette), scale to the manifest art height (or fence width),
     place so the contact sits on the footprint (base_fill: 0 = footprint centre, 1 = south tip), bottom-centre anchor on
     the south tip of the footprint's south-most cell.
  3. render at 8x of the 2x master, add a small soft contact shadow (#3b3a66, clipped to the footprint), optional thin
     outline; box-downsample to 2x and, separately, to 1x. Straight alpha, RGB 0 under alpha 0.
  4. sway: sway mask (padded canvas, Crosshaven profile), 16-frame *_sway strip and *_shadow_sway cast-shadow strip.
  5. emit: greyscale emission mask (1x size = half the 2x master, as the props checker expects) + 2x.
  6. report json + a flat staging folder (<id>@2x.png, <id>.png, <id>_emit.png, props.json) for check_assets --package props.

Usage: wp10a_props.py --region rowanvale [--ids a,b] [--raw DIR] [--out DIR] [--matte key|hybrid|rembg] [--outline]
"""
from __future__ import annotations
import argparse, json, sys, colorsys
from pathlib import Path
import numpy as np
import cv2
sys.path.insert(0, str(Path(__file__).parent))
from wp10a_common import (SS, hex2rgb, smoothstep, load_rgb, save_rgba, save_l, premul, unpremul, down_box, resize_pm,
                          to_lab, over, load_manifest, SHADOW_TINT, CAST_SHADOW, OUTLINE, load_raw, find_raw)
from PIL import Image


# ============================================================ 1. keying
def border_band(shape, frac=0.015):
    h, w = shape[:2]; b = max(4, int(min(h, w) * frac))
    m = np.zeros((h, w), bool); m[:b] = m[-b:] = True; m[:, :b] = m[:, -b:] = True
    return m


def touching_border(mask):
    n, lab = cv2.connectedComponents(mask.astype(np.uint8), connectivity=8)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    return np.isin(lab, edge[edge > 0]) & mask


def norm_conv(img, w, sigma):
    num = cv2.GaussianBlur(img * w[..., None], (0, 0), sigma)
    den = cv2.GaussianBlur(w.astype(np.float32), (0, 0), sigma)
    return num / np.maximum(den[..., None], 1e-6), den


def key_background(rgb, bg_hint='white', matte='key', report=None, shadow_cut=False):
    report = {} if report is None else report
    h, w = rgb.shape[:2]
    lab = to_lab(rgb)
    band = border_band(rgb.shape)
    ref = np.median(rgb[band], 0)
    hint = {'white': np.ones(3, np.float32), 'black': np.zeros(3, np.float32)}.get(bg_hint, hex2rgb(bg_hint) if str(bg_hint).startswith('#') else ref)
    report['bg_border_median'] = '#%02x%02x%02x' % tuple(np.round(ref * 255).astype(int))
    report['_bg_ref'] = ref.tolist()
    d_hint = float(np.linalg.norm(to_lab(ref[None, None])[0, 0] - to_lab(hint[None, None])[0, 0]))
    if d_hint > 10:
        report.setdefault('warnings', []).append(f'border median {report["bg_border_median"]} is dE {d_hint:.0f} from the expected {bg_hint} background')
    # background field: border-connected pixels near the border colour, smoothly filled (handles vignettes / off-white)
    dref = np.linalg.norm(lab - to_lab(ref[None, None])[0, 0], axis=-1)
    loose = touching_border(dref < 14)
    sig = max(h, w) * 0.03
    B, den = norm_conv(rgb, loose.astype(np.float32), sig)
    B = np.where(den[..., None] > 0.02, B, ref)
    D = np.linalg.norm(lab - to_lab(B), axis=-1)
    noise = float(np.percentile(D[loose & band], 90)) if (loose & band).sum() > 100 else 1.0
    t_bg = max(2.5, 2.0 * noise); t_fg = max(10.0, 3.5 * t_bg)
    report['bg_noise_dE90'] = round(noise, 2); report['t_bg'] = round(t_bg, 2); report['t_fg'] = round(t_fg, 2)
    vign = np.linalg.norm(to_lab(B)[loose] - to_lab(ref[None, None])[0, 0], axis=-1)
    report['bg_field_range_dE'] = round(float(np.percentile(vign, 99)), 1) if vign.size else 0.0
    bg_hard = touching_border(D < t_bg)
    # enclosed holes (gaps between branches): only very close to the background and not tiny
    holes = (D < min(t_bg, 2.0)) & ~bg_hard
    n, labh, st, _ = cv2.connectedComponentsWithStats(holes.astype(np.uint8), 8)
    big = np.zeros(n, bool); big[1:] = st[1:, cv2.CC_STAT_AREA] > 0.0004 * h * w
    bg_hard |= big[labh]
    band_px0 = max(3.0, 0.004 * max(h, w))
    if shadow_cut:
        # painted ground shadow on a light background: smooth, neutral, darker than the background field, in the
        # lower part of the picture, and connected to the background. Treated as background (the script adds its own
        # small contact shadow).
        Lb = to_lab(B)[..., 0]; L = lab[..., 0]
        chroma = np.hypot(lab[..., 1] - to_lab(B)[..., 1], lab[..., 2] - to_lab(B)[..., 2])
        loc_sd = np.sqrt(np.maximum(cv2.GaussianBlur(L * L, (0, 0), 3) - cv2.GaussianBlur(L, (0, 0), 3) ** 2, 0))
        obj = ~bg_hard
        ys_ = np.nonzero(obj.any(1))[0]
        lower = (np.arange(h)[:, None] > ys_.min() + 0.55 * (ys_.max() - ys_.min())) if ys_.size else np.zeros((h, 1), bool)
        sh = (chroma < 7) & (L < Lb - 2) & (L > Lb - 55) & (loc_sd < 2.2) & lower
        sh = touching_border(bg_hard | sh) & ~bg_hard
        k = int(2 * band_px0) | 1                       # take the shadow's faint fringe too
        fringe = cv2.dilate(sh.astype(np.uint8), np.ones((k, k), np.uint8)) > 0
        sh |= fringe & (chroma < 7) & (loc_sd < 3.0) & (L > Lb - 55) & lower & ~bg_hard
        report['shadow_cut_px'] = int(sh.sum())
        bg_hard |= sh
    # soft alpha only in a thin band next to the background; anything deeper inside is solid (cream plaster on white,
    # dark trunks on black stay opaque instead of turning see-through)
    band_px = max(3.0, 0.004 * max(h, w))
    dist_bg = cv2.distanceTransform((~bg_hard).astype(np.uint8), cv2.DIST_L2, 5)
    fg_hard = ((D > t_fg) | (dist_bg > band_px)) & ~bg_hard
    report['edge_band_px'] = round(band_px, 1)
    # foreground colour from DEEP pixels (beyond 2 bands), so a soft painted fringe (anti-aliased outline glow mixed
    # with the background) is not taken as the object colour
    deep = (dist_bg > 2 * band_px) & ~bg_hard
    F1, d1 = norm_conv(rgb, deep.astype(np.float32), 2 * band_px)
    F2, d2 = norm_conv(rgb, fg_hard.astype(np.float32), band_px * 6)
    F = np.where(d1[..., None] > 0.03, F1, F2)
    FB = F - B; IB = rgb - B
    den2 = (FB ** 2).sum(-1)
    a_proj = np.clip((IB * FB).sum(-1) / np.maximum(den2, 1e-6), 0, 1)
    resid = np.linalg.norm(IB - a_proj[..., None] * FB, axis=-1) / np.sqrt(np.maximum(den2, 1e-6))
    a_ratio = np.clip((D - t_bg) / (t_fg - t_bg), 0, 1)
    fb_de = np.linalg.norm(to_lab(np.clip(F, 0, 1)) - to_lab(B), axis=-1)
    a_old = np.where(fg_hard, 1.0, np.where(fb_de > 12, a_proj, a_ratio))
    # de-halo: within 2 bands of the background, pixels that sit on the background->object colour line are mixes,
    # whatever their dE (a 50% dark-outline/white mix is dE ~40 but still half transparent)
    online = (dist_bg <= 2 * band_px) & (fb_de > 12) & (resid < 0.12) & ~bg_hard
    a = np.where(online, np.minimum(a_old, a_proj), a_old)
    report['dehalo_px'] = int((online & (a_proj < 0.9)).sum())
    a = np.where(bg_hard, 0.0, np.where(a >= 0.999, 1.0, smoothstep(0.06, 0.98, a))).astype(np.float32)
    if matte in ('hybrid', 'rembg'):
        ra = rembg_alpha(rgb)
        if matte == 'rembg':
            a = ra
        else:
            core = cv2.erode((ra > 0.9).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
            rescue = core & (a < 0.5) & ~touching_border(D < t_bg)
            report['rembg_rescued_px'] = int(rescue.sum())
            a = np.where(rescue, 1.0, a)
    # decontaminate: un-mix the background from edge pixels
    C = B + IB / np.maximum(a[..., None], 1e-3)
    wgt = smoothstep(0.05, 0.6, a)[..., None]
    C = np.clip(C * wgt + np.clip(F, 0, 1) * (1 - wgt), 0, 1)
    C = np.where(a[..., None] >= 0.999, rgb, C)
    return np.dstack([C, a]).astype(np.float32), report


_REMBG = None
def rembg_alpha(rgb):
    global _REMBG
    from rembg import remove, new_session
    from PIL import Image
    if _REMBG is None:
        _REMBG = new_session('birefnet-general-lite')
    out = remove(Image.fromarray((rgb * 255).astype(np.uint8)), session=_REMBG, only_mask=True)
    return np.asarray(out, np.float32) / 255.0


def clean_components(rgba, report):
    bg_ref = report.pop('_bg_ref', None)
    a = rgba[..., 3]
    solid = (a > 0.5).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(solid, 8)
    if n <= 1:
        report.setdefault('warnings', []).append('nothing found after keying'); return rgba
    main = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
    x, y, w, h = st[main, :4]
    mx, my = 0.12 * w, 0.12 * h
    keep = np.zeros(n, bool); keep[main] = True
    dropped = 0
    for i in range(1, n):
        if i == main: continue
        xi, yi, wi, hi, ar = st[i]
        inside = xi >= x - mx and yi >= y - my and xi + wi <= x + w + mx and yi + hi <= y + h + my
        bgish = False
        if bg_ref is not None:      # detached piece that is basically background colour (painted-shadow fringe, vignette)
            pix = rgba[..., :3][lab == i]
            bgish = float(np.linalg.norm(to_lab(np.median(pix, 0)[None, None])[0, 0] - to_lab(np.asarray(bg_ref, np.float32)[None, None])[0, 0])) < 18
        if inside and ar >= 0.002 * st[main, 4] and not bgish:
            keep[i] = True
        else:
            dropped += ar
    keepmask = keep[lab]
    # soft edge pixels follow the nearest kept solid region
    near = cv2.dilate(keepmask.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
    out = rgba.copy(); out[..., 3] = np.where(near, a, 0)
    if dropped:
        report['dropped_stray_px'] = int(dropped)
    return out


def shadow_cut(rgba, strength=1.0):
    """Remove a painted ground/cast shadow: low-chroma, semi-dark, semi-transparent pixels in the bottom quarter."""
    a = rgba[..., 3]; lab = to_lab(rgba[..., :3])
    ys = np.nonzero((a > 0.5).any(1))[0]
    if ys.size == 0: return rgba
    y0, y1 = ys.min(), ys.max()
    rows = np.arange(a.shape[0])[:, None]
    bottom = smoothstep(y1 - 0.3 * (y1 - y0), y1 - 0.18 * (y1 - y0), rows)
    chroma = np.hypot(lab[..., 1], lab[..., 2])
    sh = (1 - smoothstep(6, 14, chroma)) * (1 - smoothstep(0.75, 0.95, a)) * bottom * strength
    out = rgba.copy(); out[..., 3] = a * (1 - sh)
    return out


# ============================================================ 2-3. placement + render
def measure(rgba, mode='base'):
    """Ground contact. 'base': bottom of the main silhouette (trees, posts, buildings). 'axis': midpoint of a run's two
    ends (fences, walls), so the run's centre lands on the footprint centre and chained cells meet."""
    a = rgba[..., 3]; solid = a > 0.5
    ys, xs = np.nonzero(solid)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    hb = max(3, int(0.04 * (y1 - y0)))
    band = solid[y1 - hb:y1]
    bx = np.nonzero(band.any(0))[0]
    cx = float((np.nonzero(band)[1] + 0.5).mean()); cy = float(y1)
    if mode == 'axis':
        k = max(2, int(0.08 * (x1 - x0)))
        yl = np.nonzero(solid[:, x0:x0 + k].any(1))[0].max() + 1
        yr = np.nonzero(solid[:, x1 - k:x1].any(1))[0].max() + 1
        cx, cy = (x0 + x1) / 2.0, (yl + yr) / 2.0
    return dict(x0=int(x0), x1=int(x1), y0=int(y0), y1=int(y1), contact=(cx, cy), base_w=float(bx.max() - bx.min() + 1))


def footprint_mask(shape, anchor, fp, scale):
    """Footprint diamond (px at the given scale per 1x px) around the south tip anchor."""
    h, w = shape
    fx, fy = fp
    yy, xx = np.indices((h, w), np.float32)
    X = (xx + 0.5 - anchor[0]) / scale; Y = (yy + 0.5 - anchor[1]) / scale       # 1x px from the tip
    xw = X / 64 + Y / 32 + fx; yw = Y / 32 - X / 64 + fy                          # world (cells) from the NW corner
    return ((xw >= 0) & (xw <= fx) & (yw >= 0) & (yw <= fy)).astype(np.float32)


def render(asset, cut, opts, report):
    W2, H2 = asset['size_2x']
    ss = opts.get('ss', SS)
    Ws, Hs = W2 * ss, H2 * ss
    pr = asset.get('process', {})
    fill = pr.get('base_fill', 0.2)
    A = np.array([Ws / 2, Hs], np.float32)
    fc = np.array(asset['footprint_centre_from_anchor_1x'], np.float32) * 2 * ss
    G = A + fc * (1 - fill) + np.array(opts.get('nudge_2x', (0, 0)), np.float32) * ss
    m = measure(cut, pr.get('contact', 'base'))
    cx, cy = m['contact']; art_h = m['y1'] - m['y0']; art_w = m['x1'] - m['x0']
    if opts.get('target_w_2x') or (asset.get('process_target_w_2x') and not opts.get('art_h_2x')):
        s = (opts.get('target_w_2x') or asset['process_target_w_2x']) * ss / art_w
    else:
        s = (pr.get('art_h_2x') or H2 * 0.92) * ss / art_h
    margin = 2 * ss
    if opts.get('fit_half_w_2x'):          # keep the art within +-fit_half_w_2x of the anchor (checker span rule)
        margin = max(margin, (W2 / 2 - opts['fit_half_w_2x']) * ss)
    lim = [ (G[0] - margin) / max(cx - m['x0'], 1), (Ws - margin - G[0]) / max(m['x1'] - cx, 1), (G[1] - 2 * ss) / max(cy - m['y0'], 1)]
    s_fit = min(lim)
    if s_fit < s:
        report.setdefault('warnings', []).append(f'art does not fit the canvas at the target size: scaled to {100 * s_fit / s:.0f}% of the manifest art height/width')
        s = s_fit
    # resize the trimmed cut (premultiplied), then place with a sub-pixel affine
    pad = 4
    y0, y1 = max(0, m['y0'] - pad), min(cut.shape[0], m['y1'] + pad)
    x0, x1 = max(0, m['x0'] - pad), min(cut.shape[1], m['x1'] + pad)
    crop = cut[y0:y1, x0:x1]
    nw, nh = max(1, int(round(crop.shape[1] * s))), max(1, int(round(crop.shape[0] * s)))
    sc = resize_pm(crop, (nw, nh))
    sx, sy = nw / crop.shape[1], nh / crop.shape[0]
    tx = G[0] - (cx - x0) * sx; ty = G[1] - (cy - y0) * sy
    M = np.float32([[1, 0, tx], [0, 1, ty]])
    pm = cv2.warpAffine(premul(sc), M, (Ws, Hs), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    art = unpremul(np.clip(pm, 0, 1))
    layers = art
    if opts.get('outline'):
        r = max(1, int(round(1.1 * ss)))
        dil = cv2.dilate((art[..., 3] > 0.35).astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))).astype(np.float32)
        ol = np.dstack([np.broadcast_to(hex2rgb(OUTLINE), art.shape[:2] + (3,)), cv2.GaussianBlur(dil, (0, 0), ss * 0.5) * 0.85])
        layers = over(art, ol)
    if opts.get('contact_shadow', pr.get('contact_shadow', True)):
        bw = m['base_w'] * s
        rx = max(bw * 0.62, 10 * ss); ry = rx * 0.5
        ctr = (float(G[0]), float(G[1] - ry * 0.55))
        ell = np.zeros((Hs, Ws), np.float32)
        cv2.ellipse(ell, (int(ctr[0]), int(ctr[1])), (int(rx), int(ry)), 0, 0, 360, 1.0, -1, cv2.LINE_AA)
        ell = cv2.GaussianBlur(ell, (0, 0), max(rx / 3.5, ss))
        ell *= footprint_mask((Hs, Ws), A, asset['footprint_size'], 2 * ss)
        sh = np.dstack([np.broadcast_to(hex2rgb(SHADOW_TINT), (Hs, Ws, 3)), ell * 0.38])
        layers = over(layers, sh)
    if opts.get('post_render'):            # per-asset canvas-space edit at the supersampled scale (end trims, recolours by region)
        layers = opts['post_render'](layers, ss, W2, H2, report)
    t2 = down_box(layers, ss); t1 = down_box(layers, ss * 2)
    glow2 = None
    if opts.get('glow_raw') is not None:      # painted glow pass, placed with exactly the same transform
        g = opts['glow_raw'][y0:y1, x0:x1]
        g = cv2.resize(g, (nw, nh), interpolation=cv2.INTER_AREA if s < 1 else cv2.INTER_CUBIC)
        g = cv2.warpAffine(g, M, (Ws, Hs), flags=cv2.INTER_LINEAR, borderValue=0)
        glow2 = g.reshape(H2, ss, W2, ss).mean((1, 3))
    a2 = t2[..., 3]
    ys, xs = np.nonzero(a2 > 0.5)
    report.update(scale_raw_to_2x=round(s / ss, 4), contact_2x=[round(float(G[0] / ss), 2), round(float(G[1] / ss), 2)],
                  anchor_px_2x=[W2 / 2, H2], anchor_px=[W2 / 4, H2 / 2],
                  art_x_from_anchor_2x=[int(xs.min() - W2 / 2), int(xs.max() + 1 - W2 / 2)] if xs.size else None,
                  art_height_2x=int(H2 - ys.min()) if ys.size else 0, coverage=round(float((a2 > 0.5).mean()), 4),
                  raw_to_2x=dict(sx=float(sx / ss), sy=float(sy / ss), x0=int(x0), y0=int(y0), tx=float(tx / ss), ty=float(ty / ss),
                                 note='x2 = (x_work - x0) * sx + tx (work = raw after the load_raw downscale)'))
    if xs.size and (xs.min() == 0 or xs.max() == W2 - 1 or ys.min() == 0):
        report.setdefault('warnings', []).append('art touches the canvas edge')
    return t2, t1, dict(G=(G / ss).tolist(), top=float(ys.min()) if ys.size else 0.0, glow2=glow2)


# ============================================================ 4. sway
def sway_mask(rgba, ground_y, pin_frac, pad):
    """Crosshaven profile: 0 below the pin (trunk/base), rising to ~245 at the top, on the padded canvas."""
    a = np.pad(rgba[..., 3], ((0, 0), (pad, pad)))
    ys = np.nonzero((a > 0.3).any(1))[0]
    top = ys.min()
    pin = ground_y - pin_frac * (ground_y - top)
    rows = np.arange(a.shape[0], dtype=np.float32)[:, None]
    wv = np.clip((pin - rows) / max(pin - top, 1), 0, 1) ** 1.3
    k = max(3, int(round(a.shape[1] / 40)) * 2 + 1)
    sil = cv2.dilate((a > 0.02).astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))).astype(np.float32)
    mk = cv2.GaussianBlur(sil * wv, (0, 0), max(0.6, a.shape[1] / 200)) * (245 / 255)
    return np.clip(mk, 0, 1).astype(np.float32)


def warp_frame(rgba_p, mask, phase, amp):
    """One sway frame, the Crosshaven shader displacement baked: dx = sin(ph - 1.1 w) amp w^1.15, dy = 0.18 |dx| w."""
    h, w = mask.shape
    yy, xx = np.indices((h, w), np.float32)
    dx = np.sin(phase - 1.1 * mask) * amp * mask ** 1.15
    mx = (xx - dx).astype(np.float32); my = (yy - 0.18 * np.abs(dx) * mask).astype(np.float32)
    pm = cv2.remap(premul(rgba_p).astype(np.float32), mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    return unpremul(np.clip(pm, 0, 1))


def cast_shadow(frame, ground_y, scale, h_art=None, out_wh=None, shear=0.62, squash=0.30, soft_1x=2.2, strength=0.42):
    """Ground-layer cast shadow of a sway frame (light from the top-left): canvas grows right and down."""
    h, w = frame.shape[:2]
    a = frame[..., 3]
    if h_art is None:
        ys = np.nonzero((a > 0.05).any(1))[0]; h_art = ground_y - ys.min()
    H_art = h_art
    if out_wh is None:
        W_out = w + int(np.ceil(shear * H_art + 3 * soft_1x * scale)); H_out = h + int(np.ceil(squash * H_art + 3 * soft_1x * scale))
    else:
        W_out, H_out = out_wh
    yy, xx = np.indices((H_out, W_out), np.float32)
    hgt = (yy - ground_y) / squash
    sx = xx - shear * hgt; sy = ground_y - hgt
    valid = (hgt >= 0)
    sil = cv2.remap(a.astype(np.float32), sx.astype(np.float32), sy.astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0) * valid
    sil = cv2.GaussianBlur(sil, (0, 0), soft_1x * scale)
    out = np.zeros((H_out, W_out, 4), np.float32); out[..., :3] = hex2rgb(CAST_SHADOW); out[..., 3] = np.clip(sil, 0, 1) * strength
    return out


def build_sway(aid, t2, t1, ground_y_2x, sw, out):
    files = {}
    # shadow frame size fixed from the 1x art (rounded up to a multiple of 4 for BC7), 2x = exactly double
    pad1 = sw['pad_1x']; gy1 = ground_y_2x / 2
    h1 = gy1 - np.nonzero((t1[..., 3] > 0.05).any(1))[0].min() + 2
    sw_w1 = int(np.ceil((t1.shape[1] + 2 * pad1 + 0.62 * h1 + 6.6) / 4) * 4)
    sw_h1 = int(np.ceil((t1.shape[0] + 0.30 * h1 + 6.6) / 4) * 4)
    for tag, img, scl in (('_2x', t2, 2), ('', t1, 1)):
        pad = sw['pad_1x'] * scl
        mask = sway_mask(img, ground_y_2x * scl / 2, sw['pin_frac'], pad)
        imgp = np.pad(img, ((0, 0), (pad, pad), (0, 0)))
        frames = [warp_frame(imgp, mask, 2 * np.pi * i / sw['frames'], sw['amp_1x'] * scl) for i in range(sw['frames'])]
        gy = ground_y_2x * scl / 2
        shadows = [cast_shadow(f, gy, scl, h1 * scl, (sw_w1 * scl, sw_h1 * scl)) for f in frames]
        sub = (lambda p: Path(out) / p / '_2x') if tag else (lambda p: Path(out) / p)
        save_l(sub('animated/sway_masks') / f'{aid}_swaymask.png', mask)
        save_rgba(sub('animated') / f'{aid}_sway.png', np.concatenate(frames, 1))
        save_rgba(sub('animated/shadows') / f'{aid}_shadow_sway.png', np.concatenate(shadows, 1))
        files['frame' + tag] = list(frames[0].shape[1::-1]); files['shadow_frame' + tag] = list(shadows[0].shape[1::-1])
    return files


# ============================================================ 5. emit
def hsv(rgb):
    mx = rgb.max(-1); mn = rgb.min(-1); d = mx - mn
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hh = np.where(mx == r, ((g - b) / np.maximum(d, 1e-6)) % 6, np.where(mx == g, (b - r) / np.maximum(d, 1e-6) + 2, (r - g) / np.maximum(d, 1e-6) + 4)) * 60
    return np.where(d > 1e-6, hh, 0), s, mx


def emit_mask(rgba, rule):
    rgb, a = rgba[..., :3], rgba[..., 3]
    h, s, v = hsv(rgb)
    if rule == 'ice':
        hue = smoothstep(160, 178, h) * (1 - smoothstep(212, 228, h))
        e = np.maximum(hue * smoothstep(0.12, 0.35, s) * smoothstep(0.62, 0.9, v),
                       smoothstep(0.86, 0.97, v) * smoothstep(0.02, 0.07, rgb[..., 2] - rgb[..., 0]))
    elif rule == 'warm':
        hue = smoothstep(12, 24, h) * (1 - smoothstep(55, 68, h))
        e = hue * smoothstep(0.3, 0.55, s) * smoothstep(0.65, 0.9, v)
    else:
        raise ValueError(rule)
    e = cv2.GaussianBlur(e.astype(np.float32) * smoothstep(0.3, 0.9, a), (0, 0), 0.8)
    hi = np.percentile(e[e > 0.1], 97) if (e > 0.1).sum() > 20 else 1.0
    return np.clip(e / max(hi, 1e-3), 0, 1) * smoothstep(0.02, 0.4, a)


# ============================================================ driver
def process(asset, raw_path, out, stage, opts):
    rep = dict(id=asset['id'], raw=str(raw_path))
    rep['raw_size'] = list(Image.open(raw_path).size)
    rgb = load_raw(raw_path, opts.get('raw_max'))
    rep['work_size'] = list(rgb.shape[1::-1])
    if opts.get('pre'):                      # per-asset raw clean-up (crop away intruding scenery etc.)
        rgb = opts['pre'](rgb)
    bg = 'white' if 'white' in asset['raw_bg'] else 'black'
    cut, rep = key_background(rgb, opts.get('bg', bg), opts.get('matte', 'key'), rep, opts.get('shadow_cut', False))
    cut = clean_components(cut, rep)
    if opts.get('post'):                     # per-asset alpha clean-up after keying (base plates, painted shadows)
        cut = opts['post'](cut, rgb)
    gp = Path(raw_path).with_name(Path(raw_path).stem + '_glow.png')
    opts = dict(opts, glow_raw=(load_raw(gp, opts.get('raw_max')) @ np.array([0.2126, 0.7152, 0.0722], np.float32)) if (asset.get('emit') and gp.exists()) else None)
    t2, t1, geo = render(asset, cut, opts, rep)
    aid = asset['id']
    save_rgba(Path(out) / 'props/_2x' / f'{aid}.png', t2); save_rgba(Path(out) / 'props' / f'{aid}.png', t1)
    save_rgba(Path(stage) / f'{aid}@2x.png', t2); save_rgba(Path(stage) / f'{aid}.png', t1)
    rep['files'] = dict(file=f'props/{aid}.png', file_2x=f'props/_2x/{aid}.png')
    if asset.get('sway'):
        rep['sway'] = build_sway(aid, t2, t1, geo['G'][1], asset['sway'], out)
    if asset.get('emit'):
        if geo['glow2'] is not None:
            e2 = np.clip(geo['glow2'] / max(np.percentile(geo['glow2'][geo['glow2'] > 0.05], 97) if (geo['glow2'] > 0.05).sum() > 20 else 1, 1e-3), 0, 1) * smoothstep(0.02, 0.4, t2[..., 3])
            rep['emit_source'] = 'painted glow pass ' + gp.name
        else:
            e2 = emit_mask(t2, asset['emit']['rule'])
            rep['emit_source'] = f"colour rule '{asset['emit']['rule']}'"
        roi = asset['emit'].get('roi_2x')
        if roi:
            r_ = np.zeros_like(e2)
            for bx0, by0, bx1, by1 in roi: r_[by0:by1, bx0:bx1] = 1
            e2 = e2 * cv2.GaussianBlur(r_, (0, 0), 2.0)
        elif geo['glow2'] is None:
            rep.setdefault('warnings', []).append('emit from colour rule without roi_2x boxes: check for false glow on snow/white stone')
        e1 = cv2.resize(e2, (t1.shape[1], t1.shape[0]), interpolation=cv2.INTER_AREA)
        save_l(Path(out) / 'props/emit/_2x' / f'{aid}_emit.png', e2); save_l(Path(out) / 'props/emit' / f'{aid}_emit.png', e1)
        save_l(Path(stage) / f'{aid}_emit.png', e1)
        rep['emit_coverage'] = round(float((e2 > 0.2).mean()), 4)
        if rep['emit_coverage'] < 0.002:
            rep.setdefault('warnings', []).append('emit mask nearly empty: check the glow colours against the rule')
    return rep


def props_json_entry(asset, rep):
    return dict(id=asset['id'], file_2x=f"{asset['id']}@2x.png", file_1x=f"{asset['id']}.png",
                footprint_cells=asset['footprint_size'], anchor_px_2x=rep['anchor_px_2x'], anchor_px_1x=rep['anchor_px'],
                size_2x=asset['size_2x'], size_1x=asset['size'], emissive='yes' if asset.get('emit') else 'no',
                art_x_from_anchor_2x=rep.get('art_x_from_anchor_2x'), height_px_2x=rep.get('art_height_2x'))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', required=True); ap.add_argument('--ids')
    ap.add_argument('--raw'); ap.add_argument('--out'); ap.add_argument('--stage')
    ap.add_argument('--reports')
    ap.add_argument('--matte', default='key', choices=('key', 'hybrid', 'rembg'))
    ap.add_argument('--outline', action='store_true'); ap.add_argument('--shadow-cut', action='store_true')
    ap.add_argument('--manifest', default='/workspace/stasium-pc-look/raw/wp10a/manifest.json')
    a = ap.parse_args()
    m = load_manifest(a.manifest)
    reg = next(r for r in m['regions'] if r['id'] == a.region)
    raw = Path(a.raw or reg['raw_dir'])
    out = Path(a.out or f'/workspace/stasium-pc-look/ship/wp10a_{a.region}/art/world/{a.region}')
    stage = Path(a.stage or f'/workspace/stasium-pc-look/ship/wp10a_{a.region}_props_check')
    ids = set(a.ids.split(',')) if a.ids else None
    reps, pj = [], []
    for asset in reg['assets']:
        if asset['kind'] == 'tile' or (ids and asset['id'] not in ids):
            continue
        rp = find_raw(raw, asset)
        if rp is None:
            print(f"  missing raw: {raw / asset['raw']} (aliases {asset.get('raw_aliases')})"); continue
        r = process(asset, rp, out, stage, dict(matte=a.matte, outline=a.outline, shadow_cut=a.shadow_cut))
        reps.append(r); pj.append(props_json_entry(asset, r))
        print(f"  {asset['id']:30s} {asset['size_2x']} art_x {r.get('art_x_from_anchor_2x')} h {r.get('art_height_2x')} warn {r.get('warnings', [])}")
    stage.mkdir(parents=True, exist_ok=True)
    (stage / 'props.json').write_text(json.dumps(dict(package=f'wp10a_{a.region}', version=1, props=pj), indent=1, default=float))
    rdir = Path(a.reports or f'/workspace/stasium-pc-look/ship/wp10a_{a.region}/_reports'); rdir.mkdir(parents=True, exist_ok=True)
    (rdir / 'props_report.json').write_text(json.dumps(reps, indent=1, default=float))


if __name__ == '__main__':
    main()
