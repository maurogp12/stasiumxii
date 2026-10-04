"""back_mid v4 -> 4096x2560 RGBA @2x + 2048x1280 sway. Intermediates in /workspace/scratch/v4/bm/."""
from jlib import *
import json, sys, time
T0 = time.time()
def log(*a): print('[%5.1fs]' % (time.time() - T0), *a, flush=True)
D = '/workspace/scratch/v4/bm/'
P = dict(top_pad=100, sig_deg=2.2, vine_v=0.62)
P.update(json.loads(sys.argv[1]) if len(sys.argv) > 1 else {})
OW, OH = 4096, 2560
raw = np.asarray(Image.open(RAW + 'back_mid_raw_v4.png').convert('RGB')).astype(np.float32) / 255
RH, RW = raw.shape[:2]
need_h = int(round(RW * OH / OW))                      # 3360 rows for a full-width 16:10 frame
T = P['top_pad']; B = need_h - RH - T
pad = np.pad(raw, ((T, B), (0, 0), (0, 0)), mode='reflect'); del raw
# soften the mirror seams a little (blend a blurred copy over +-24 rows around each seam)
for yseam in (T, T + RH):
    lo, hi = max(0, yseam - 24), min(need_h, yseam + 24)
    blur = cv2.GaussianBlur(pad[max(0, lo - 30):hi + 30], (0, 0), 6)[lo - max(0, lo - 30):lo - max(0, lo - 30) + hi - lo]
    w = (1 - np.abs(np.arange(lo, hi) - yseam) / 24.0)[:, None, None] * 0.7
    pad[lo:hi] = pad[lo:hi] * (1 - w) + blur * w
s = OW / RW
W = np.clip(resize(pad, (OW, OH), cv2.INTER_AREA), 0, 1); del pad
log('full raw width, pad top %d / bottom %d raw rows (reflect), uniform scale x%.4f' % (T, B, s))
h, sat, v = hsv(W)
magk = (np.abs(W - [1, 0, 1]).max(-1) < 0.12) | ((h > 285) & (h < 335) & (sat > 0.55) & (v > 0.55))
lab, n = ndi.label(magk); sz = np.bincount(lab.ravel()); sz[0] = 0
mag = lab == sz.argmax()
hole0 = ndi.binary_fill_holes(cv_close(mag, 25))        # stepped oval incl. dangling vines
# ---- smooth the stepped contour: elliptical-normalised polar radius, smoothed in angle
ys, xs = np.nonzero(hole0); cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
ax, ay = (xs.max() - xs.min()) / 2, (ys.max() - ys.min()) / 2
cnts, _ = cv2.findContours(hole0.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
c = max(cnts, key=len)[:, 0, :].astype(np.float64)
u, w_ = (c[:, 0] - cx) / ax, (c[:, 1] - cy) / ay
th = np.arctan2(w_, u); r = np.hypot(u, w_)
NB = 2048; bins = ((th + np.pi) / (2 * np.pi) * NB).astype(int) % NB
rb = np.zeros(NB); cnt = np.zeros(NB)
np.add.at(rb, bins, r); np.add.at(cnt, bins, 1)
# for each angle bin take the mean radius (stair treads and risers average to the step midpoint)
idx = np.arange(NB); ok = cnt > 0
rb = np.interp(idx, idx[ok], rb[ok] / cnt[ok], period=NB)
sig = P['sig_deg'] / 360 * NB
rs = ndi.gaussian_filter1d(rb, sig, mode='wrap')
yy, xx = np.indices((OH, OW)).astype(np.float32)
U, V = (xx - cx) / ax, (yy - cy) / ay
TH = np.arctan2(V, U); RR = np.hypot(U, V)
rr = np.interp((TH + np.pi) / (2 * np.pi) * NB, np.arange(NB + 1), np.append(rs, rs[0]))
f = RR - rr                                              # <0 inside the smoothed oval
gy, gx = np.gradient(f); g = np.maximum(np.hypot(gx, gy), 1e-6)
sd = f / g                                               # ~signed distance in px
hole_a = np.clip(0.5 - sd, 0, 1)                         # 1 inside, 1 px AA
dev = np.abs(sd[cv_dilate(hole0, 1) & ~cv_erode(hole0, 1)])
log('oval centre (%.0f,%.0f) semi-axes %.0f x %.0f; stepped edge vs smooth curve: mean %.1f px, p95 %.1f, max %.1f' % (cx, cy, ax, ay, dev.mean(), np.percentile(dev, 95), dev.max()))
# ---- dangling vines inside the oval stay opaque (attached to the canopy above)
vine = hole0 & ~mag & ((v < P['vine_v']) | ((h > 60) & (h < 180) & (sat > 0.35)))
vine = cv_open(vine, 1)
lab, n = ndi.label(vine | ~cv_erode(hole0, 3)); att = np.unique(lab[~cv_erode(hole0, 3)]); vine &= np.isin(lab, att[att > 0])
# AA weight for vine pixels from how magenta they are
magness = np.clip((np.minimum(W[..., 0], W[..., 2]) - W[..., 1]), 0, 1)
vine_a = np.where(cv_dilate(vine, 1), np.clip(1 - magness * 1.15, 0, 1), 0) * hole_a
alpha = 1 - hole_a + vine_a
alpha = np.clip(alpha, 0, 1).astype(np.float32)
alpha[alpha < 1.5 / 255] = 0; alpha[alpha > 254.5 / 255] = 1
# ---- colour: trust pixels away from magenta; diffuse into the rim / stair corners, despill
pinkish = magk | ((h > 280) & (h < 345) & (sat > 0.35))
core = ~cv_dilate(pinkish, 4)
col = np.where(core[..., None], W, despill_magenta(push_pull(W, core)))
col = np.where(cv_dilate(vine, 2)[..., None], despill_magenta(W), col)
rgba = (np.dstack([np.clip(col, 0, 1), alpha]) * 255 + .5).astype(np.uint8)
save_rgba(rgba, D + 'back_mid_v4@2x.png')
a8 = rgba[..., 3]; cb = a8[OH // 4:3 * OH // 4, OW // 4:3 * OW // 4]
solidL = np.argmax(a8 < 255, 1); solidL[~(a8 < 255).any(1)] = OW
solidR = np.argmax(a8[:, ::-1] < 255, 1); solidR[~(a8 < 255).any(1)] = OW
y2, x2 = np.nonzero(a8 < 128)
info = dict(scale=s, top_pad=T, bottom_pad=B, centre_lt32=float((cb < 32).mean() * 100), transparent=float((a8 == 0).mean() * 100),
            semi=int(((a8 > 0) & (a8 < 255)).sum()), edges=[bool((a8[0] == 255).all()), bool((a8[-1] == 255).all()), bool((a8[:, 0] == 255).all()), bool((a8[:, -1] == 255).all())],
            side_solid_min=[int(solidL.min()), int(solidR.min())], hole_bbox=[int(x2.min()), int(x2.max()), int(y2.min()), int(y2.max())],
            oval=dict(cx=cx, cy=cy, ax=ax, ay=ay), vine_px=int(vine.sum()), step_dev=[float(dev.mean()), float(np.percentile(dev, 95)), float(dev.max())])
log(json.dumps(info))
json.dump(info, open(D + 'info.json', 'w'), indent=1)
np.savez_compressed(D + 'masks.npz', hole0=hole0, vine=vine, rs=rs)
# ---- sway (half size): canopy leaf masses sway; trunks/bark, sky glimpses and ALL ground are still (0)
Wh = resize(col, (OW // 2, OH // 2)); ah = resize(alpha, (OW // 2, OH // 2))
hh, ss, vv = hsv(Wh)
lw = lum(Wh); mu = cv2.GaussianBlur(lw, (0, 0), 3); lstd = cv2.GaussianBlur(np.sqrt(np.maximum(cv2.GaussianBlur(lw * lw, (0, 0), 3) - mu * mu, 0)), (0, 0), 4)
leaf = (vv > 0.08) & (((hh > 55) & (hh < 175) & (ss > 0.3)) | (lstd > 0.05))
leaf = cv_close(cv_open(leaf, 2), 3)
pinned = cv_open(~leaf & (lstd < 0.035), 8)
dist = ndi.distance_transform_edt(~pinned)
sw = smoothstep(2, 40, dist) * np.clip(cv2.GaussianBlur(leaf.astype(np.float32), (0, 0), 6) * 1.3, 0, 1)
H2, W2 = sw.shape
# ground line: hole's lower boundary inside its span, the oval's centre row outside it; everything below is still
hb = np.where((a8 < 128).any(0), OH - 1 - np.argmax((a8 < 128)[::-1], 0), -1)[::2] / 2.0
gl = np.where(hb > 0, hb, cy / 2)
gl = ndi.minimum_filter1d(gl, 61); gl = cv2.GaussianBlur(gl[None].astype(np.float32), (0, 0), 20).ravel()
yy2 = np.arange(H2, dtype=np.float32)[:, None]
ground = smoothstep(gl[None, :] - 30, gl[None, :] + 10, yy2)
sw = sw * (1 - ground) * (ah > 0.5)
sw = cv2.GaussianBlur(sw.astype(np.float32), (0, 0), 1.5) * (1 - ground) * (ah > 0)
sw = sw / max(np.percentile(sw[sw > 0.05], 99.5), 1e-3) if (sw > 0.05).any() else sw
save_l(sw, D + 'back_mid_v4_sway.png')
swq = (np.clip(sw, 0, 1) * 255 + .5).astype(np.uint8)
log('sway: ground rows (below line) max %d, nonzero %.1f%%' % (int(swq[(ground > 0.999)].max()), (swq > 0).mean() * 100))
checker_preview(rgba, D + 'view_bm4.png', maxw=1400)
Image.fromarray(swq).resize((1024, 640)).save(D + 'view_bm4_sway.png')
log('done')
