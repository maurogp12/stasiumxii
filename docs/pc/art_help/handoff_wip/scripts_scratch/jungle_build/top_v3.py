"""front_leaves_top v3 -> 2560x480 RGBA + 1280x240 sway. Checkpoints in /workspace/scratch/v3/."""
from jlib import *
import json, sys, time, os
T0 = time.time()
def log(*a): print('[%5.1fs]' % (time.time() - T0), *a, flush=True)
D = '/workspace/scratch/v3/'
P = dict(smooth=6, black=0.06, seg_v=0.2, shadow_r=40, env_win=200, env_blur=40, env_tol=40, env_floor=0.45,
         drop_far=6, min_seg=150, margin=24, close_r=5, inner_d=6, rim=3, bias=0.55)
P.update(json.loads(sys.argv[1]) if len(sys.argv) > 1 else {})
OW, OH, SS = 2560, 480, 2
# ---- stage 1: crop the 16:3 band from the top of the 21:9 frame (uniform scale, no stretch)
raw = np.asarray(Image.open(RAW + 'front_leaves_top_raw_v3.png').convert('RGB')).astype(np.float32) / 255
H, W = raw.shape[:2]
ch = round(W * OH / OW)                      # 6048 * 3/16 = 1134 rows
crop = raw[:ch]
del raw
Wk = resize(crop, (OW * SS, OH * SS)); del crop
Hh, Ww = Wk.shape[:2]
log('band rows 0..%d of %d, scale %.4f (uniform)' % (ch, H, OW / W))
h, s, v = hsv(Wk); vv = Wk.max(-1)
exact = np.abs(Wk - [1, 0, 1]).max(-1) < 0.04
key = exact | ((h > 280) & (h < 352) & (s > 0.28) & (v > 0.06))
key = cv_open(key, 1) | exact
dark = vv < P['black']
backing = cv_dilate(cv_open(dark, 7), 2) & dark
outline = dark & ~backing
key |= backing
rows = np.arange(Hh)[:, None]
def attached(m):
    lab, n = ndi.label(m); att = np.unique(lab[:6]); att = att[att > 0]; return np.isin(lab, att)
# board keep-out (default camera): screen = out px * 0.75; board diamond centre (960,450), half extents 461 x 230.4
yy, xx = np.indices((Hh, Ww)).astype(np.float32)
sx, sy = xx / SS * 0.75, yy / SS * 0.75
m = P['margin']
keepout = (np.abs(sx - 960) / (461 + 2 * m) + np.abs(sy - 450) / (230.4 + m)) <= 1
del yy, xx, sx, sy
fg0 = attached(cv_open(~key, 2))
# ---- stage 2: leaf segments; drop whole leaves that cross the band bottom or the board keep-out
seg = cv_open(fg0 & ~outline & ~(vv < P['seg_v']), 1)
lab, n = ndi.label(seg)
sizes = np.bincount(lab.ravel(), minlength=n + 1)
bad = np.zeros(n + 1, bool)
bad[sizes < P['min_seg'] * SS * SS] = True
bad[np.unique(lab[-P['drop_far']:])] = True
bad[np.unique(lab[keepout])] = True
bad[0] = True
kept = seg & ~bad[lab]
log('segments %d, dropped %d' % (n, int(bad[1:].sum())))
dkey = ndi.distance_transform_edt(~key)
inner = outline & cv_close(kept, P['close_r']) & (dkey > P['inner_d'])
fg = kept | inner
np.savez_compressed(D + 'stage2.npz', kept=kept, inner=inner, keepout=keepout)
# ---- stage 3: dark painted leaves (navy) as whole segments above the leaf envelope; pure-black gaps as shadow
depth = np.where(fg.any(0), Hh - np.argmax(fg[::-1], 0), 0).astype(np.float32)
env = ndi.maximum_filter1d(depth, P['env_win'])
env = cv2.GaussianBlur(env[None, :], (0, 0), P['env_blur']).ravel()
env = np.maximum(env, P['env_floor'] * Hh)
navy = cv_open(~key & (vv >= P['black']) & (vv < P['seg_v']) & ~fg, 2)
nl, nn = ndi.label(navy)
viol = navy & ((rows > (env + P['env_tol'])[None, :]) | keepout | (rows >= Hh - P['drop_far']))
nbad = np.zeros(nn + 1, bool); nbad[np.unique(nl[viol])] = True
nsz = np.bincount(nl.ravel(), minlength=nn + 1); nbad[nsz < 400 * SS * SS] = True; nbad[0] = True
navy_k = navy & ~nbad[nl]
fg |= navy_k
sr = P['shadow_r']
pf = np.pad(fg, sr, mode='edge'); pf[:sr] = True           # beyond the top edge counts as canopy
encl = cv_close(pf, sr)[sr:-sr, sr:-sr]
shadow = (backing | outline | dark | (vv < P['seg_v'])) & ~key | (backing & encl)
shadow = shadow & encl & ~fg & ~exact & ~cv_dilate(keepout, 4)
shadow[-P['drop_far']:] = False
# wider canopy notches at the top edge (left by dropped leaves): dark canopy fill, never in the keep-out / deep rows
magkey = key & ~backing
R2 = P.get('notch_r', 110)
pf2 = np.pad(fg | shadow, R2, mode='edge'); pf2[:R2] = True
encl2 = cv_close(pf2, R2)[R2:-R2, R2:-R2] & (rows < (P.get('notch_depth', 0.5) * Hh))
notch = encl2 & ~fg & ~shadow & ~magkey & ~exact & ~cv_dilate(keepout, 4)
notch[-P['drop_far']:] = False
shadow |= notch
fg = attached(fg | shadow); shadow &= fg
hole = ndi.binary_fill_holes(fg) & ~fg
hl, hn = ndi.label(hole)
if hn:
    hs = np.bincount(hl.ravel(), minlength=hn + 1)
    nb = np.zeros(hn + 1, bool); nb[np.unique(hl[cv_dilate(shadow, 2) & hole])] = True
    kf = ndi.mean(key.astype(np.float32), hl, np.arange(hn + 1))
    sel = nb & (hs < 6000 * SS * SS) & (np.nan_to_num(kf) < 0.3); sel[0] = False
    small = (hs < 60 * SS * SS) & (np.nan_to_num(kf) < 0.5); small[0] = False   # pinholes
    bub = sel[hl]; shadow |= bub; fg |= bub | small[hl]
log('navy kept %d/%d, shadow px %d' % (int((~nbad[1:]).sum()), nn, int(shadow.sum())))
np.savez_compressed(D + 'stage3.npz', fg=fg, shadow=shadow)
# ---- stage 4: stair-step repair (silhouette smoothing at step scale, slight inward bias) -> crisp AA alpha
leafpart = fg & ~shadow
mm = cv2.GaussianBlur(leafpart.astype(np.float32), (0, 0), P['smooth'] * SS)
fg2 = mm > P['bias']
# synthetic canopy-notch boundary: leafy jagged edge (only on the wide notch fill, not on gaps between leaves)
jn = noise2d((Hh, Ww), P.get('jag_scale', 14) * SS, seed=31, octaves=2) * P.get('jag_amp', 0.3)
nj = cv2.GaussianBlur(notch.astype(np.float32), (0, 0), 3 * SS) + jn
nj = (nj > 0.5) & cv_dilate(notch, 3 * SS) & ~cv_dilate(keepout, 2) & ~magkey
nj = cv2.GaussianBlur(nj.astype(np.float32), (0, 0), 1.2) > 0.5
sh2 = (shadow & ~notch) | nj
fg2 = fg2 | sh2
fg2[:2] |= fg[:2]
shadow = shadow | (sh2 & ~fg)
fg2 = attached(fg2)
# islands / tiny bits after smoothing
lab2, n2 = ndi.label(fg2)
log('fg2 components %d' % n2)
rim = P['rim']
core = fg & cv_erode(fg2, rim) & ~cv_dilate(key, rim) & ~cv_dilate(outline & ~inner, rim)
core |= shadow & cv_erode(fg2, rim)
Wd = Wk.copy()
nearkey = cv_dilate(key, 8) & ~core
Wd[nearkey] = despill_magenta(Wk[nearkey][None])[0]
tmask = shadow & (dark | (vv >= P['seg_v']))   # pure black and painted-over dropped-leaf pixels get the canopy tint
tint = np.array([0.03, 0.08, 0.10], np.float32)
nzs = noise2d((Hh, Ww), 60 * SS, seed=11)[..., None] * 0.025
Wd = np.where(tmask[..., None], np.clip(tint + nzs, 0, 1), Wd)
col = np.where(core[..., None], Wd, despill_magenta(push_pull(Wd, core)))
colo = resize(col, (OW, OH)); a = resize(fg2.astype(np.float32), (OW, OH))
a[a < 1.5 / 255] = 0
edge = (a > 0) & cv_dilate(a < 0.5, 2)
med = np.dstack([ndi.median_filter(colo[..., k], size=7) for k in range(3)])
spk = edge & (lum(colo) < 0.6 * lum(med)); colo[spk] = med[spk]
rgba = (np.dstack([np.clip(colo, 0, 1), np.clip(a, 0, 1)]) * 255 + .5).astype(np.uint8)
save_rgba(rgba, D + 'front_leaves_top_v3@2x.png')
log('saved master: opaque(>=128) %.3f semi %.4f faint(1-63) %d' % ((rgba[..., 3] >= 128).mean(), ((rgba[..., 3] > 0) & (rgba[..., 3] < 255)).mean(), int(((rgba[..., 3] > 0) & (rgba[..., 3] < 64)).sum())))
# ---- stage 5: sway (half of the master = 1280x240): 0 at the top edge -> 255 at the leaf tips (per column)
ah = resize(fg2.astype(np.float32), (OW // 2, OH // 2))
hh_, ww_ = ah.shape
y2 = np.arange(hh_, dtype=np.float32)[:, None]
present = ah > 0.05
tip = np.where(present.any(0), hh_ - np.argmax(present[::-1], 0), 1).astype(np.float32)
tip = ndi.maximum_filter1d(tip, size=max(3, ww_ // 40))
tip = cv2.GaussianBlur(tip[None, :], (0, 0), ww_ / 60).ravel()
tip = np.maximum(tip, hh_ * 0.15)
sway = smoothstep(0.0, 1.0, np.clip(y2 / tip[None, :], 0, 1)) ** 0.85
near = cv2.GaussianBlur((ah > 0.02).astype(np.float32), (0, 0), 3) > 0.02
sway = cv2.GaussianBlur(np.where(near, sway, 0).astype(np.float32), (0, 0), 1.5)
save_l(sway, D + 'front_leaves_top_v3_sway.png')
checker_preview(rgba, D + 'view_top_v3.png', maxw=1400)
log('done')
