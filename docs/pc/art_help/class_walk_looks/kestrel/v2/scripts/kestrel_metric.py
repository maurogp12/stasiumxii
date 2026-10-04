#!/usr/bin/env python3
"""Kestrel walk match metric = the Bastion v2 metric (Claude's Ironjaw match_metric.py) with only these changes:
  * prefix kestrel; the S target alpha file is an RGBA cutout, so its alpha channel is used as the mask
  * palette classes cloak (green) / leather (brown) / dark (rest); sole finding ignores green cloak instead of blue cloth
Bastion changes kept:
  * frames are DIR/<prefix>_walk_{F}_fNN.png (--prefix, default bastion)
  * --v2 is the motion reference: the approved blockout clay pass (clay/bastion_walk_{F}_fNN.png); --idle the clay idle f00
  * the target alpha is the approved binary mask (--target_alpha) instead of the grey flood cut
  * palette classes steel / cape(blue cloth) / bone(gold trim); sole finding ignores blue cloth instead of crimson
Everything else (fit, read-scale SSIM, weights, motion rule, PASS bar) is unchanged.

Original: Ironjaw walk match metric: LOOK vs the repaint target and MOTION vs the locked v2 walk.

usage: match_metric.py --facing S --cand DIR --v2 DIR --target rp_S_f00_t1.jpg --idle ironjaw_idle_S_f00.png
                       --joints joints_512.json [--out report.json] [--png check.png] [--selftest]
Frames are DIR/ironjaw_walk_{F}_fNN.png, 512x360 RGBA, pivot (256,329), 12 frames.
Needs numpy, pillow, opencv-python, scikit-image.

LOOK (f00, target scaled into the cell by fitting the upper body):
  ssim_upper   read-scale SSIM (gauss 1.2 px, half size) on the grey-composited figure above the pelvis line (masked mean)
  ssim_lower   same below the pelvis line (legs; the painter narrowed the stride, so ~0.8 is the ceiling)
  iou          full silhouette IoU
  palette      1 - mean CIEDE2000/15 over the steel / cape / bone medians
  height_vs_idle  tallest walk frame (passing) height / approved idle height (pivot row 329). The idle set is the size
               reference in game; the repaint's legs are longer than the idle's, so leg length is NOT scored vs the repaint
  look_score   100*(.35 ssim_upper + .15 ssim_lower + .20 iou + .20 palette + .10 legprop)
  look_hold_upper  per-frame upper SSIM vs the target moved with the pelvis (arm swing costs ~.1; a drop
               well below the neighbours flags a tear, a seam or a cape break in that frame)
MOTION (every frame vs v2, which Luca locked):
  bob_err      max |head-top bob(cand) - bob(v2)| px, after removing each series' mean
  sole_err     per frame: support-foot sole point (cand) - (v2), px
  motion_score 100 * share of frames with sole_err <= 2 px and bob_err <= 1 px
PASS: look_score >= 85 and ssim_upper >= .85 and palette >= .85; motion_score >= 95.
Skate is not re-measured here: v2 has skate 0 (qa_walk.py), so a sole that matches v2 within 2 px every frame cannot skate.
Crimson pixels are ignored when finding soles, but a dark cape hem hanging below the boots still counts (on purpose:
the hem must clear the ground).
"""
import argparse, json, math, os, sys
import numpy as np, cv2
from PIL import Image
from skimage.metrics import structural_similarity
from skimage.color import rgb2lab, deltaE_ciede2000
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

BG = 126

PREFIX = 'kestrel'
def load(d, F, i):
    a = np.asarray(Image.open(f'{d}/{PREFIX}_walk_{F}_f{i:02d}.png').convert('RGBA'))
    return a[..., :3], a[..., 3] > 127

def comp(rgb, m):
    o = np.full(rgb.shape, BG, np.uint8); o[m] = rgb[m]; return o

def place(trgb, ta, s, tx, ty):
    M = np.float32([[s, 0, tx], [0, s, ty]])
    r = cv2.warpAffine(trgb, M, (512, 360), flags=cv2.INTER_AREA, borderValue=(BG,) * 3)
    a = cv2.warpAffine(ta.astype(np.float32), M, (512, 360), flags=cv2.INTER_LINEAR) > .5
    return r, a

def fit(trgb, ta, cm, py):
    """scale/translate the target so its upper body (rows < py) best overlaps the candidate's."""
    ys, xs = np.nonzero(cm); cy0, cy1 = ys.min(), ys.max()
    tys, txs = np.nonzero(ta)
    best = None
    s0 = (cy1 - cy0) / (tys.max() - tys.min())
    up = np.zeros((360, 512), bool); up[:py] = True
    for s in s0 * np.linspace(.8, 1.2, 41):
        for dy in range(-8, 9, 2):
            ty = cy0 - tys.min() * s + dy
            tx = (xs.mean() - txs.mean() * s)
            for dx in range(-12, 13, 3):
                _, a = place(trgb[::4, ::4], ta[::4, ::4], s * 4, tx + dx, ty)
                i = (a & cm & up).sum(); u = ((a | cm) & up).sum()
                if best is None or i / u > best[0]: best = (i / u, s, tx + dx, ty)
    # refine 1 px
    _, s, tx, ty = best
    for dx in (-2, -1, 0, 1, 2):
        for dy in (-2, -1, 0, 1, 2):
            _, a = place(trgb, ta, s, tx + dx, ty + dy)
            v = (a & cm & up).sum() / ((a | cm) & up).sum()
            if v > best[0]: best = (v, s, tx + dx, ty + dy)
    return best

def mssim(a, b, m):
    if m.sum() < 50: return float('nan')
    # read-scale SSIM: blur + half size ~ what survives the in-game 0.3-0.5 draw scale
    g = lambda x: cv2.resize(cv2.GaussianBlur(cv2.cvtColor(x, cv2.COLOR_RGB2GRAY), (0, 0), 1.2), (256, 180), interpolation=cv2.INTER_AREA)
    mm = cv2.resize(m.astype(np.uint8), (256, 180), interpolation=cv2.INTER_NEAREST) > 0
    _, S = structural_similarity(g(a), g(b), full=True, data_range=255, win_size=7)
    return float(S[mm].mean())

def classes(rgb, m):
    lab = rgb2lab(rgb)
    L, A, B = lab[..., 0], lab[..., 1], lab[..., 2]
    cloak = m & (A < -4) & (B > 4)                          # green cloak / hood
    leather = m & ~cloak & (A > 4) & (B > 8)               # brown leather (boots, trousers, bracers, quiver, bow)
    dark = m & ~cloak & ~leather
    return lab, {'cloak': cloak, 'leather': leather, 'dark': dark}

def palette(cr, cm, tr, tm):
    cl, cc = classes(cr, cm); tl, tc = classes(tr, tm); out = {}
    for k in cc:
        if tc[k].sum() < 30 or cc[k].sum() < 30: out[k] = None; continue
        a = np.median(cl[cc[k]], 0); b = np.median(tl[tc[k]], 0)
        out[k] = dict(dE=round(float(deltaE_ciede2000(a[None], b[None])[0]), 2),
                      share_cand=round(float(cc[k].sum() / cm.sum()), 3), share_tgt=round(float(tc[k].sum() / tm.sum()), 3))
    d = [v['dE'] for v in out.values() if v]
    return out, max(0., 1 - float(np.mean(d)) / 15)

def cloth(rgb):
    lab = rgb2lab(rgb); return (lab[..., 1] < -4) & (lab[..., 2] > 4)     # green cloak

def sole(m, x0, x1, y0=0):
    """support-boot sole point; cape/loincloth pixels (crimson) are removed by the caller, rows above y0 ignored."""
    x0, x1 = max(0, int(x0)), min(512, int(x1))
    sub = m[:, x0:x1].copy(); sub[:max(0, int(y0))] = False; ys, xs = np.nonzero(sub)
    if len(ys) == 0: return None
    y1 = ys.max(); sel = ys >= y1 - 2
    return (float(xs[sel].mean() + x0), int(y1))

def head_top(m):
    cols = m[:, 200:312]; ys = np.nonzero(cols.any(1))[0]
    return int(ys.min())

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--facing', required=True); ap.add_argument('--cand', required=True); ap.add_argument('--v2', required=True)
    ap.add_argument('--target', required=True); ap.add_argument('--joints', required=True); ap.add_argument('--out'); ap.add_argument('--idle', required=True, help='hd_set_idle/ironjaw_idle_{F}_f00.png')
    ap.add_argument('--png', help='write a side-by-side f00 check image')
    ap.add_argument('--target_alpha', required=True); ap.add_argument('--prefix', default='kestrel')
    ap.add_argument('--selftest', action='store_true', help='score the fitted target against itself (expect look ~100)')
    a = ap.parse_args(); F = a.facing
    global PREFIX; PREFIX = a.prefix
    J = json.load(open(a.joints))['facings'][f'walk_{F}']
    py = int(round(J['f00']['joints']['pelvis'][1]))
    cr, cm = load(a.cand, F, 0)
    trgb = np.asarray(Image.open(a.target).convert('RGB')); _ta = Image.open(a.target_alpha); ta = (np.asarray(_ta)[..., 3] if _ta.mode == 'RGBA' else np.asarray(_ta.convert('L'))) > 127
    iou_up, s, tx, ty = fit(trgb, ta, cm, py)
    tr, tm = place(trgb, ta, s, tx, ty)
    if a.selftest: cr, cm = tr, tm
    C, T = comp(cr, cm), comp(tr, tm)
    U = cm | tm; up = np.zeros_like(U); up[:py] = True
    r = dict(facing=F, fit=dict(scale=round(s, 4), tx=round(tx, 1), ty=round(ty, 1), iou_upper=round(float(iou_up), 3)))
    r['ssim_upper'] = round(mssim(C, T, U & up), 3)
    r['ssim_lower'] = round(mssim(C, T, U & ~up), 3)
    r['ssim_full'] = round(mssim(C, T, U), 3)
    r['iou'] = round(float((cm & tm).sum() / U.sum()), 3)
    r['palette_detail'], pal = palette(cr, cm, tr, tm); r['palette'] = round(pal, 3)
    cs = np.nonzero(cm)[0].max(); ts = np.nonzero(tm)[0].max()
    r['leg_ratio_vs_repaint'] = round(float((cs - py) / max(1, ts - py)), 3)   # info only: the repaint's legs are longer than the idle set's
    # height vs the approved idle set (the in-game size reference): tallest walk frame (passing) vs idle, pivot row 329
    ia = np.asarray(Image.open(a.idle).convert('RGBA'))[..., 3] > 127
    itop = int(np.nonzero(ia)[0].min())
    tops = [head_top(load(a.cand, F, i)[1]) for i in range(12)]
    r['height_vs_idle'] = round((329 - min(tops)) / (329 - itop), 3)
    legprop = max(0., 1 - abs(r['height_vs_idle'] - 1) / .10)
    hold = []                                 # does the look hold over the cycle? target follows the pelvis
    p0 = np.array(J['f00']['joints']['pelvis'])
    for i in range(12):
        d = np.array(J[f'f{i:02d}']['joints']['pelvis']) - p0
        ri, mi = load(a.cand, F, i); ti, tmi = place(trgb, ta, s, tx + d[0], ty + d[1])
        upi = np.zeros_like(U); upi[:int(py + d[1])] = True
        hold.append(round(mssim(comp(ri, mi), comp(ti, tmi), (mi | tmi) & upi), 3))
    r['look_hold_upper'] = hold
    r['look_score'] = round(100 * (.35 * r['ssim_upper'] + .15 * r['ssim_lower'] + .20 * r['iou'] + .20 * pal + .10 * legprop), 1)
    # motion
    bc, bv, errs, soles_c = [], [], [], []
    for i in range(12):
        jj = J[f'f{i:02d}']['joints']
        sup = 'R' if jj['R_ankle'][1] >= jj['L_ankle'][1] else 'L'
        xs = [jj[f'{sup}_toe'][0], jj[f'{sup}_heel'][0], jj[f'{sup}_ankle'][0]]
        rc, mc = load(a.cand, F, i); rv, mv = load(a.v2, F, i)
        y0 = jj[f'{sup}_ankle'][1] - 4
        pc = sole(mc & ~cloth(rc), min(xs) - 12, max(xs) + 12, y0); pv = sole(mv & ~cloth(rv), min(xs) - 12, max(xs) + 12, y0)
        bc.append(head_top(mc)); bv.append(head_top(mv)); soles_c.append((sup, pc))
        errs.append(round(math.dist(pc, pv), 2) if pc and pv else None)
    bob = np.array(bc) - np.mean(bc) - (np.array(bv) - np.mean(bv))
    r['bob_err_per_frame'] = [round(float(v), 1) for v in bob]
    r['bob_err'] = round(float(np.abs(bob).max()), 2)
    r['bob_amp'] = dict(cand=int(max(bc) - min(bc)), v2=int(max(bv) - min(bv)))
    r['sole_err'] = errs
    ok = [(e is not None and e <= 2 and abs(b) <= 1) for e, b in zip(errs, bob)]
    r['motion_score'] = round(100 * sum(ok) / 12, 1)
    r['PASS'] = dict(look=bool(r['look_score'] >= 85 and r['ssim_upper'] >= .85 and pal >= .85),
                     motion=bool(r['motion_score'] >= 95))
    print(json.dumps({k: v for k, v in r.items() if k not in ('bob_err_per_frame',)}, indent=1))
    if a.out: json.dump(r, open(a.out, 'w'), indent=1)
    if a.png:
        diff = np.abs(C.astype(int) - T.astype(int)).sum(2).clip(0, 255).astype(np.uint8)
        Image.fromarray(np.hstack([C, T, cv2.applyColorMap(diff, cv2.COLORMAP_INFERNO)[..., ::-1]])).save(a.png)

if __name__ == '__main__':
    main()
