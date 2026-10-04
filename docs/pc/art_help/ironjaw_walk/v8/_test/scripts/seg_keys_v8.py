"""cut the 3 S thigh keys (short-forward, medium-down, long-back) from thigh_keys_S_v8.jpg (flat grey bg) -> legs_v8/S_key{0,1,2}.png"""
import numpy as np, cv2, json
from PIL import Image
from scipy import ndimage as ndi
rgb = np.asarray(Image.open('/workspace/scratch/ij_walk/parts/thigh_keys_S_v8.jpg').convert('RGB')).astype(np.float32)
H, W = rgb.shape[:2]
std = np.sqrt(np.maximum(cv2.blur(rgb.mean(-1) ** 2, (5, 5)) - cv2.blur(rgb.mean(-1), (5, 5)) ** 2, 0)); ch = rgb.max(-1) - rgb.min(-1)
cand = (std < 2.5) & (ch < 10)
lab, n = ndi.label(cand); border = np.unique(np.r_[lab[0], lab[-1], lab[:, 0], lab[:, -1]]); border = border[border > 0]
bgm = np.isin(lab, border)
yy, xx = np.nonzero(bgm); sel = np.random.default_rng(0).choice(len(yy), min(40000, len(yy)), replace=False); yy, xx = yy[sel], xx[sel]
A = np.stack([np.ones_like(xx), xx, yy, xx * xx, yy * yy, xx * yy], 1).astype(np.float64) / np.array([1, W, H, W * W, H * H, W * H])
Y, X = np.indices((H, W)); AA = np.stack([np.ones_like(X), X, Y, X * X, Y * Y, X * Y], -1).astype(np.float64) / np.array([1, W, H, W * W, H * H, W * H])
bgf = np.stack([AA @ np.linalg.lstsq(A, rgb[yy, xx, c], rcond=None)[0] for c in range(3)], -1)
d = np.abs(rgb - bgf).max(-1)
fg = d > 14
fg = ndi.binary_opening(fg, iterations=1); fg = ndi.binary_fill_holes(fg)
for _ in range(2): fg |= ndi.binary_dilation(fg) & (d > 8)
fg = ndi.binary_erosion(fg, iterations=1); fg = ndi.binary_fill_holes(fg)
lab, n = ndi.label(fg); sz = np.bincount(lab.ravel()); sz[0] = 0
keep = [k for k in np.argsort(sz)[::-1][:3] if sz[k] > 5000]
boxes = sorted((int(np.nonzero(lab == k)[1].min()), k) for k in keep)
info = dict(bg_corner=bgf[5, 5].round(1).tolist(), bg_centre=bgf[H // 2, W // 2].round(1).tolist(), keys={})
for j, (_, k) in enumerate(boxes):
    ys, xs = np.nonzero(lab == k); x0, y0, x1, y1 = xs.min(), ys.min(), xs.max(), ys.max()
    m = lab[y0:y1 + 1, x0:x1 + 1] == k; m = ndi.binary_opening(m, iterations=2) ; m = ndi.binary_fill_holes(m)
    c = rgb[y0:y1 + 1, x0:x1 + 1].copy()
    inner = ndi.binary_erosion(m, iterations=3); _, (iy, ix) = ndi.distance_transform_edt(~inner, return_indices=True)
    ring = m & ~ndi.binary_erosion(m, iterations=2); c[ring] = c[iy[ring], ix[ring]]
    # soft 1px alpha edge (no stair-steps after the 0.2x resample)
    a = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 0.7); a = np.where(ndi.binary_erosion(m, iterations=1), 1.0, a * m)
    P = 6; rgba = np.zeros((m.shape[0] + 2 * P, m.shape[1] + 2 * P, 4), np.uint8)
    rgba[P:-P, P:-P, :3] = np.clip(c, 0, 255) * m[..., None]; rgba[P:-P, P:-P, 3] = np.round(a * 255)
    Image.fromarray(rgba, 'RGBA').save(f'legs_v8/S_key{j}.png')
    info['keys'][f'key{j}'] = dict(name=['short_forward', 'medium_down', 'long_back'][j], box=[int(x0), int(y0), int(x1), int(y1)], size=list(rgba.shape[1::-1]), px=int(m.sum()))
json.dump(info, open('legs_v8/seg_info.json', 'w'), indent=1); print(info)
sheet = Image.new('RGBA', (900, 520), (180, 60, 180, 255))
x = 0
for j in range(3):
    im = Image.open(f'legs_v8/S_key{j}.png'); sheet.alpha_composite(im, (x, 0)); x += im.width + 10
sheet.save('look/keys_cut.png')
