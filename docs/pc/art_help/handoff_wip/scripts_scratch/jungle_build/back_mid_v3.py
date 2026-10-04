"""back_mid v3 -> 4096x2560 RGBA @2x (+ sway 2048x1280). Intermediates in /workspace/scratch/v3/bm/."""
from jlib import *
import json, sys, time, os
T0 = time.time()
def log(*a): print('[%5.1fs]' % (time.time() - T0), *a, flush=True)
D = '/workspace/scratch/v3/bm/'; os.makedirs(D, exist_ok=True)
P = dict(ch=2000, dy=0, dx=0, smooth=11, wave=0.18, thr=0.45)
P.update(json.loads(sys.argv[1]) if len(sys.argv) > 1 else {})
OW, OH = 4096, 2560
raw = np.asarray(Image.open(RAW + 'back_mid_raw_v3.png').convert('RGB')).astype(np.float32) / 255
RH, RW = raw.shape[:2]
mag = np.abs(raw - [1, 0, 1]).max(-1) < 0.06
lab, n = ndi.label(mag); sz = np.bincount(lab.ravel()); sz[0] = 0; oval = lab == sz.argmax()
ys, xs = np.nonzero(oval); ocx, ocy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
ch = P['ch']; cw = ch * OW / OH
x0 = int(round(ocx - cw / 2 + P['dx'])); y0 = int(round(ocy - ch / 2 + P['dy']))
x0 = max(0, min(RW - int(cw), x0)); y0 = max(0, min(RH - ch, y0))
crop = raw[y0:y0 + ch, x0:x0 + int(round(cw))]
log('oval bbox x %d..%d y %d..%d; crop x %d..%d y %d..%d (%dx%d) scale x%.3f (uniform)' % (xs.min(), xs.max(), ys.min(), ys.max(), x0, x0 + crop.shape[1], y0, y0 + ch, crop.shape[1], ch, OW / crop.shape[1]))
W = np.clip(resize(crop, (OW, OH), cv2.INTER_LANCZOS4), 0, 1); del raw
h, s, v = hsv(W)
magk = (np.abs(W - [1, 0, 1]).max(-1) < 0.12) | ((h > 285) & (h < 335) & (s > 0.55) & (v > 0.55))
lab, n = ndi.label(magk); sz = np.bincount(lab.ravel()); sz[0] = 0
hole = ndi.binary_fill_holes(lab == sz.argmax())               # islands inside the oval go too
# stair-step repair of the oval edge + light leafy waviness, then 1 px AA via signed distance
f = cv2.GaussianBlur(hole.astype(np.float32), (0, 0), P['smooth'])
f += noise2d((OH, OW), 26, seed=7, octaves=3) * P['wave'] * cv_dilate(hole, 40) * ~cv_erode(hole, 40)
hm = (f > P['thr']) | cv_erode(hole, 60)       # stair corners may be re-covered (coloured from the rim)
hm = ndi.binary_fill_holes(hm)
lab, n = ndi.label(hm); sz = np.bincount(lab.ravel()); sz[0] = 0; hm = lab == sz.argmax()
gy, gx = np.gradient(f); g = np.maximum(np.hypot(gx, gy), 1e-4)
alpha = np.clip(0.5 + (P['thr'] - f) / g, 0, 1).astype(np.float32)     # ~1 px AA along the smoothed contour
alpha[cv_erode(hm, 2)] = 0; alpha[~cv_dilate(hm, 2)] = 1
alpha[alpha < 1.5 / 255] = 0
np.savez_compressed(D + 'masks.npz', hole=hole, hm=hm)
# colour: trust pixels away from any magenta; diffuse into the rim, despill whatever is left
pinkish = magk | ((h > 280) & (h < 345) & (s > 0.35))
core = ~cv_dilate(pinkish | hm, 4)
col = np.where(core[..., None], W, despill_magenta(push_pull(W, core)))
rgba = (np.dstack([col, alpha]) * 255 + .5).astype(np.uint8)
save_rgba(rgba, D + 'back_mid_v3@2x.png')
a8 = rgba[..., 3]; cb = a8[OH // 4:3 * OH // 4, OW // 4:3 * OW // 4]
edges = dict(top=(a8[0] == 255).mean(), bottom=(a8[-1] == 255).mean(), left=(a8[:, 0] == 255).mean(), right=(a8[:, -1] == 255).mean())
ys2, xs2 = np.nonzero(a8 == 0)
log('centre box alpha<32: %.1f%%; transparent %.1f%% of canvas; semi px %d; edges opaque %s; hole bbox x %d..%d y %d..%d' % (
    (cb < 32).mean() * 100, (a8 == 0).mean() * 100, int(((a8 > 0) & (a8 < 255)).sum()), {k: round(float(x), 3) for k, x in edges.items()}, xs2.min(), xs2.max(), ys2.min(), ys2.max()))
# sway (half size): leaf masses sway; trunks, roots, rocks and the ground terrace under the hole are pinned
Wh = resize(col, (OW // 2, OH // 2)); ah = resize(alpha, (OW // 2, OH // 2))
hh, ss, vv = hsv(Wh)
sky = ((vv > 0.8) & (ss < 0.45)) | ((hh > 15) & (hh < 58) & (vv > 0.7))
lw = lum(Wh); mu = cv2.GaussianBlur(lw, (0, 0), 3); lstd = np.sqrt(np.maximum(cv2.GaussianBlur(lw * lw, (0, 0), 3) - mu * mu, 0))
lstd = cv2.GaussianBlur(lstd, (0, 0), 4)
leafc = ~sky & (vv > 0.08) & ((((hh > 55) & (hh < 175) & (ss > 0.3))) | (lstd > P.get('tex', 0.05)))
leafc = cv_close(cv_open(leafc, 2), 3)
wood = ~sky & ~leafc            # bark (blue-grey/brown), roots, rock, deep shade
leaf = leafc
pinned = cv_open(wood & (lstd < P.get('tex_pin', 0.035)), 8)   # smooth, coherent bark/rock pins; textured canopy sways
dist = ndi.distance_transform_edt(~pinned)
sw = smoothstep(2, 40, dist) * np.clip(cv2.GaussianBlur((~pinned & ~sky).astype(np.float32), (0, 0), 6) * 1.3, 0, 1)
H2, W2 = sw.shape
hy0 = ys2.max() / 2; hx0, hx1 = xs2.min() / 2, xs2.max() / 2
yy, xx = np.indices((H2, W2)).astype(np.float32)
inx = smoothstep(hx0 - 60, hx0 + 80, xx) * (1 - smoothstep(hx1 - 80, hx1 + 60, xx))
ground = inx * smoothstep(ocy_out := (hy0 - 80), hy0 + 40, yy)        # terrace / roots / cliffs below the hole
sw = sw * (1 - ground) * (ah > 0)
sw = cv2.GaussianBlur(sw.astype(np.float32), (0, 0), 1.5)
sw = sw / max(np.percentile(sw[sw > 0.05], 99.5), 1e-3) if (sw > 0.05).any() else sw
save_l(sw, D + 'back_mid_v3_sway.png')
checker_preview(rgba, D + 'view_bm3.png', maxw=1400)
Image.fromarray((np.clip(sw, 0, 1) * 255).astype(np.uint8)).resize((1024, 640)).save(D + 'view_bm3_sway.png')
log('done')
