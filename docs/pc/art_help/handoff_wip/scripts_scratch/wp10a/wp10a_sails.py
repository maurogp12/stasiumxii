"""WP10a windmill sails: one separately painted, face-on sail cross -> 12-frame rotation strip (+ flat frame).

Paint the sails alone, face-on (not in perspective), evenly lit (they rotate, so baked light would rotate with them),
hub in the middle, on the region's flat background. 4 symmetric sails -> 90 deg per loop, 7.5 deg per frame.
Each frame is rotated at 8x supersampling of the 2x frame, squashed in y by 0.9 (the Crosshaven windmill_sails_flat
perspective), given a screen-fixed top-left light ramp, then box-downsampled to 2x and, separately, 1x.

Usage: wp10a_sails.py RAW --out DIR [--id old_windmill_sails] [--frames 12] [--frame 160] [--hub X,Y] [--bg white|black]
                      [--ccw/--cw] [--matte key|hybrid]
"""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path
import numpy as np, cv2
sys.path.insert(0, str(Path(__file__).parent))
from wp10a_common import SS, load_rgb, load_raw, save_rgba, premul, unpremul, down_box, resize_pm, hex2rgb, KEY, SHADE
from wp10a_props import key_background, clean_components


def build(raw, out, sid='old_windmill_sails', frames=12, frame_1x=160, hub=None, bg='white', ccw=True, matte='key',
          squash=0.9, light=0.10, sym=4, radius_1x=None, pre=None):
    rep = {}
    rgb0 = load_raw(raw)
    if pre: rgb0 = pre(rgb0)
    cut, rep = key_background(rgb0, bg, matte, rep)
    cut = clean_components(cut, rep)
    a = cut[..., 3]
    ys, xs = np.nonzero(a > 0.5)
    if hub is None:
        w = a[a > 0.5]
        hub = (float((xs * w).sum() / w.sum()), float((ys * w).sum() / w.sum()))
        rep['hub_method'] = 'alpha centroid (pass --hub X,Y if the cross is not symmetric)'
    hx, hy = hub
    R = float(np.sqrt((xs - hx) ** 2 + (ys - hy) ** 2).max()) + 2
    F2 = frame_1x * 2; Fs = F2 * SS
    s = (Fs / 2 - 2 * SS) / R
    # square crop around the hub, scaled to the SS frame
    r = int(np.ceil(R)) + 4
    padc = np.pad(cut, ((r, r), (r, r), (0, 0)))
    crop = padc[int(hy) - r + r:int(hy) + r + r, int(hx) - r + r:int(hx) + r + r]
    if radius_1x:                       # sail tip radius in 1x px (frame keeps its size; sails shrink inside it)
        n = int(round(2 * r * (radius_1x * 2 * SS) / R)); n += n % 2
        n = min(n, Fs)
        small = resize_pm(crop, (n, n)); big = np.zeros((Fs, Fs, 4), np.float32)
        o = (Fs - n) // 2; big[o:o + n, o:o + n] = small
    else:
        big = resize_pm(crop, (Fs, Fs))
    yy, xx = np.indices((Fs, Fs), np.float32)
    nx, ny = (xx - Fs / 2) / (Fs / 2), (yy - Fs / 2) / (Fs / 2)
    ramp = 1 + light * np.clip(-(nx + ny) / 1.41, -1, 1)
    warm = hex2rgb(KEY); cool = hex2rgb(SHADE)
    tint = np.where((-(nx + ny))[..., None] > 0, 1 + 0.04 * (warm - 1), 1 + 0.04 * (cool - 0.6))
    step = (360 / sym) / frames
    st2, st1 = [], []
    for i in range(frames):
        ang = step * i * (1 if ccw else -1)
        M = cv2.getRotationMatrix2D((Fs / 2, Fs / 2), ang, 1.0)
        M[1] *= squash; M[1, 2] += Fs / 2 * (1 - squash)
        pm = cv2.warpAffine(premul(big), M, (Fs, Fs), flags=cv2.INTER_LINEAR, borderValue=0)
        fr = unpremul(np.clip(pm, 0, 1))
        fr[..., :3] = np.clip(fr[..., :3] * ramp[..., None] * tint, 0, 1)
        st2.append(down_box(fr, SS)); st1.append(down_box(fr, SS * 2))
    out = Path(out)
    save_rgba(out / 'animated/_2x' / f'{sid}.png', np.concatenate(st2, 1)); save_rgba(out / 'animated' / f'{sid}.png', np.concatenate(st1, 1))
    flat = big.copy()
    save_rgba(out / 'animated/_2x' / f'{sid}_flat.png', down_box(flat, SS)); save_rgba(out / 'animated' / f'{sid}_flat.png', down_box(flat, SS * 2))
    rep.update(frames=frames, frame_size=[frame_1x, frame_1x], frame_size_2x=[F2, F2], deg_per_frame=step, direction='ccw' if ccw else 'cw',
               hub_raw=[round(hx, 1), round(hy, 1)], sail_radius_raw=round(R, 1), sail_radius_1x=round(radius_1x if radius_1x else (Fs / 2 - 2 * SS) / SS / 2, 1), squash_y=squash,
               fps_for_4_44s_turn=round(frames / (4.44 / sym), 2))
    return rep


def bake_static(kit, body_id, sails_id, hub_from_anchor_1x, static_id):
    """Static fallback like Crosshaven windmill_2x2: body + sails frame 0 on the body's canvas/anchor (both scales)."""
    from wp10a_common import load_rgba, over
    kit = Path(kit); out = {}
    for tag, scl in (('_2x', 2), ('', 1)):
        sub = (lambda d: kit / d / '_2x') if tag else (lambda d: kit / d)
        body = load_rgba(sub('props') / f'{body_id}.png'); strip = load_rgba(sub('animated') / f'{sails_id}.png')
        fh = strip.shape[0]; f0 = strip[:, :fh]
        H, W = body.shape[:2]
        cx = W / 2 + hub_from_anchor_1x[0] * scl; cy = H + hub_from_anchor_1x[1] * scl
        x0, y0 = int(round(cx - fh / 2)), int(round(cy - fh / 2))
        layer = np.zeros_like(body)
        sx0, sy0 = max(0, -x0), max(0, -y0); dx0, dy0 = max(0, x0), max(0, y0)
        w = min(fh - sx0, W - dx0); h = min(fh - sy0, H - dy0)
        layer[dy0:dy0 + h, dx0:dx0 + w] = f0[sy0:sy0 + h, sx0:sx0 + w]
        clipped = bool(sx0 or sy0 or w < fh - sx0 or h < fh - sy0)
        save_rgba(sub('props') / f'{static_id}.png', over(layer, body))
        out['clipped' + tag] = clipped
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('raw'); ap.add_argument('--out', required=True); ap.add_argument('--id', default='old_windmill_sails')
    ap.add_argument('--frames', type=int, default=12); ap.add_argument('--frame', type=int, default=160)
    ap.add_argument('--hub'); ap.add_argument('--bg', default='white'); ap.add_argument('--cw', action='store_true')
    ap.add_argument('--matte', default='key')
    a = ap.parse_args()
    hub = tuple(float(v) for v in a.hub.split(',')) if a.hub else None
    print(json.dumps(build(a.raw, a.out, a.id, a.frames, a.frame, hub, a.bg, not a.cw, a.matte), indent=1, default=float))


if __name__ == '__main__':
    main()
