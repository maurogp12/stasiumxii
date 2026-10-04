"""front_leaves_bottom v2 -> 2560x480 RGBA + 1280x240 sway. Work is done on a vertically FLIPPED band so the
attachment edge is row 0 (same logic as top v3). Intermediates in /workspace/scratch/v4/bot/."""
from jlib import *
import json, sys, time, os
T0 = time.time()
def log(*a): print('[%5.1fs]' % (time.time() - T0), *a, flush=True)
D = '/workspace/scratch/v4/bot/'; os.makedirs(D, exist_ok=True)
P = dict(y1=2296, smooth=5, seg_v=0.075, min_seg=120, drop_far=8, bias=0.55, rim=3, gamma=0.62, target=0.30, att_rows=6)
P.update(json.loads(sys.argv[1]) if len(sys.argv) > 1 else {})
OW, OH, SS = 2560, 480, 2
raw = np.asarray(Image.open(RAW + 'front_leaves_bottom_raw_v2.png').convert('RGB')).astype(np.float32) / 255
H, W = raw.shape[:2]
ch = round(W * OH / OW); y1 = P['y1']; y0 = y1 - ch
crop = raw[y0:y1]; del raw
Wk = resize(crop, (OW * SS, OH * SS))[::-1].copy(); del crop          # flipped: row 0 = band bottom
Hh, Ww = Wk.shape[:2]
log('band rows %d..%d of %d, scale %.4f (uniform)' % (y0, y1, H, OW / W))
h, s, v = hsv(Wk); vv = Wk.max(-1)
exact = np.abs(Wk - [1, 0, 1]).max(-1) < 0.05
key = exact | ((h > 280) & (h < 352) & (s > 0.3) & (v > 0.15))
key = cv_open(key, 1) | exact
def attached(m, rows=P['att_rows']):
    lab, n = ndi.label(m); att = np.unique(lab[:rows]); att = att[att > 0]; return np.isin(lab, att)
fg0 = attached(cv_open(~key, 2))
# ---- split overlapping leaves: marker watershed on colour gradient (outlines = strong edges).
# 'drop' seeds: foliage in the band's top rows; 'keep' seeds: THICK foliage on the bottom edge (stems are not seeds,
# so the stalk of a top-crossing leaf floods from its blade and goes with it).
from skimage.segmentation import watershed
lab3 = cv2.cvtColor(np.ascontiguousarray(Wk), cv2.COLOR_RGB2Lab)
grad = np.zeros((Hh, Ww), np.float32)
for k in range(3):
    c = cv2.GaussianBlur(lab3[..., k], (0, 0), 1.0 * SS)
    grad += np.hypot(cv2.Sobel(c, cv2.CV_32F, 1, 0), cv2.Sobel(c, cv2.CV_32F, 0, 1)) * (1 if k == 0 else 0.5)
grad += (vv < 0.05) * 200
mk = np.zeros((Hh, Ww), np.int32)
far = P['drop_far'] * SS
mk[-far:][fg0[-far:]] = 1
thick = cv_open(fg0, P.get('thick_r', 6) * SS)
mk[:far][(fg0 & thick)[:far]] = 2
ws = watershed(grad, mk, mask=fg0)
kept_seg = attached((ws == 2) | ((ws == 0) & fg0))
kept_seg[-far:] = False
kept_seg = attached(cv_open(kept_seg, 1))
log('watershed: kept %.1f%% of attached foliage, dropped %.1f%%' % (kept_seg.sum() / fg0.sum() * 100, (ws == 1).sum() / fg0.sum() * 100))
# bare stalks: thin vertical parts whose upper end is free (their leaf was dropped) are removed whole
rS = P.get('stem_r', 7)
thickk = cv_dilate(cv_open(kept_seg, rS), rS + 2)
thin = kept_seg & ~thickk
tl, tn = ndi.label(thin)
nst = 0
if tn:
    objs = ndi.find_objects(tl)
    near_thick = cv_dilate(thickk & kept_seg, 3)
    for i, sl in enumerate(objs, 1):
        comp = tl[sl] == i
        hgt = sl[0].stop - sl[0].start; area = comp.sum()
        if hgt < P.get('stem_min_h', 50) * SS: continue
        if area / hgt > P.get('stem_w', 16) * SS: continue          # leafy (fern fronds), not a bare stalk
        ys_, xs_ = np.nonzero(comp); ytop = sl[0].start + ys_.max()                # flipped: larger row = higher on screen
        topband = comp & ((np.arange(sl[0].start, sl[0].stop)[:, None]) >= ytop - 8 * SS)
        if (near_thick[sl] & topband).any(): continue                 # its upper end joins a kept leaf
        kept_seg[sl][comp] = False; nst += 1
kept_seg = attached(kept_seg)
log('bare stalks removed: %d' % nst)
# hand-directed cleanup: leaflets of the dropped palm frond that overlap the right fern (smooth blue-green, hue > 102),
# boxes in 1x output coords (x0, x1, y0, y1); anything they leave hanging is removed by attached()
for (bx0, bx1, by0, by1, hmin) in P.get('boxes', [(1755, 2045, 90, 262, 102)]):
    box = np.zeros((Hh, Ww), bool)
    box[Hh - by1 * SS:Hh - by0 * SS, bx0 * SS:bx1 * SS] = True
    blue = (h > hmin) & (s > 0.5)
    bl, bn = ndi.label(kept_seg & blue)
    big = np.unique(bl[kept_seg & blue & ~box]); big = big[big > 0]
    rm = box & kept_seg & blue & ~np.isin(bl, big)
    kept_seg &= ~cv_dilate(rm, 1)
    kept_seg = attached(cv_open(kept_seg, 2))
    log('box cleanup removed %d px' % int(rm.sum()))
np.save(D + 'ws.npy', ws.astype(np.int8))
fg = kept_seg.copy()
# pinholes
hole = ndi.binary_fill_holes(fg) & ~fg
hl, hn = ndi.label(hole)
if hn:
    hs = np.bincount(hl.ravel(), minlength=hn + 1); kf = ndi.mean(key.astype(np.float32), hl, np.arange(hn + 1))
    small = (hs < 40 * SS * SS) & (np.nan_to_num(kf) < 0.5); small[0] = False; fg |= small[hl]
np.savez_compressed(D + 'stage1.npz', fg=fg, kept=kept_seg)
# stair-step / jaggy repair -> crisp 1-2 px AA edge
mm = cv2.GaussianBlur(fg.astype(np.float32), (0, 0), P['smooth'] * SS / 2.5)
fg2 = attached(mm > P['bias'])
fg2[-P['drop_far'] // 2:] = False                                     # nothing touches the band top
fg2 = attached(fg2)
rim = P['rim']
core = fg & cv_erode(fg2, rim) & ~cv_dilate(key, rim)
Wd = Wk.copy(); nk = cv_dilate(key, 8) & ~core
Wd[nk] = despill_magenta(Wk[nk][None])[0]
col = np.where(core[..., None], Wd, despill_magenta(push_pull(Wd, core)))
# tone: lift the very dark painted interiors (luminance gamma), then scale to the target mean
L0 = np.maximum(lum(col), 1e-4)
L1 = L0 ** P['gamma']
col = np.clip(col * (L1 / L0)[..., None], 0, 1)
m0 = lum(col)[fg2].mean(); g = P['target'] / m0
col = np.clip(col * g, 0, 1)
colo = resize(col, (OW, OH)); a = resize(fg2.astype(np.float32), (OW, OH))
a[a < 1.5 / 255] = 0; a[a > 254.5 / 255] = 1
edge = (a > 0) & cv_dilate(a < 0.5, 2)
med = np.dstack([ndi.median_filter(colo[..., k], size=7) for k in range(3)])
spk = edge & (lum(colo) < 0.6 * lum(med)); colo[spk] = med[spk]
colo, a = colo[::-1], a[::-1]                                          # unflip
rgba = (np.dstack([np.clip(colo, 0, 1), np.clip(a, 0, 1)]) * 255 + .5).astype(np.uint8)
save_rgba(rgba, D + 'front_leaves_bottom_v2@2x.png')
al = rgba[..., 3]; vis = al >= 128
info = dict(band=[y0, y1], mean_lum=float(lum(rgba[..., :3].astype(np.float32) / 255)[vis].mean()), gain_after_gamma=float(g),
            opaque=float((al == 255).mean()), semi=float(((al > 0) & (al < 255)).mean()), faint=int(((al > 0) & (al < 64)).sum()),
            top_row_max=int(al[0].max()), top4_max=int(al[:4].max()), bottom_row_opaque=float((al[-1] == 255).mean()),
            left_col_opaque=float((al[:, 0] > 0).mean()), right_col_opaque=float((al[:, -1] > 0).mean()))
e = (al > 0) & (al < 255); r_, g_, b_ = [rgba[..., k][e].astype(int) for k in range(3)]
info['pink_edge_px'] = int(((r_ > g_ + 40) & (b_ > g_ + 40)).sum())
lab3, n3 = ndi.label(al > 0); bott = np.unique(lab3[-2:]); info['islands_not_on_bottom'] = int(n3 - len(bott[bott > 0]))
log(json.dumps(info)); json.dump(info, open(D + 'info.json', 'w'), indent=1)
# sway (half size): 0 at the bottom edge -> 1 at the leaf tips, per column
ah = resize(a, (OW // 2, OH // 2))[::-1]
hh_, ww_ = ah.shape
y2 = np.arange(hh_, dtype=np.float32)[:, None]
present = ah > 0.05
tip = np.where(present.any(0), hh_ - np.argmax(present[::-1], 0), 1).astype(np.float32)
tip = ndi.maximum_filter1d(tip, size=max(3, ww_ // 40)); tip = cv2.GaussianBlur(tip[None, :], (0, 0), ww_ / 60).ravel()
tip = np.maximum(tip, hh_ * 0.15)
sway = smoothstep(0.0, 1.0, np.clip(y2 / tip[None, :], 0, 1)) ** 0.85
near = cv2.GaussianBlur((ah > 0.02).astype(np.float32), (0, 0), 3) > 0.02
sway = cv2.GaussianBlur(np.where(near, sway, 0).astype(np.float32), (0, 0), 1.5)[::-1]
save_l(sway, D + 'front_leaves_bottom_v2_sway.png')
sq = (np.clip(sway, 0, 1) * 255 + .5).astype(np.uint8); log('sway bottom row max %d, max %d' % (sq[-1].max(), sq.max()))
checker_preview(rgba, D + 'view_bot2.png', maxw=1400)
log('done')
