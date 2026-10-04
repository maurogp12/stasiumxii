import numpy as np, cv2, json
from PIL import Image
from scipy import ndimage as ndi
OUT = {}
for F in 'SE':
    rgb = np.asarray(Image.open(f'/workspace/scratch/ij_walk/parts/legs_{F}_v6.jpg').convert('RGB')).astype(np.float32)
    H, W = rgb.shape[:2]
    # background: smooth estimate from border-connected flat grey
    sm = cv2.GaussianBlur(rgb, (0, 0), 2)
    std = np.sqrt(np.maximum(cv2.blur((rgb.mean(-1)) ** 2, (5, 5)) - cv2.blur(rgb.mean(-1), (5, 5)) ** 2, 0))
    ch = rgb.max(-1) - rgb.min(-1)
    # bg colour field: median filter of the image with figures removed iteratively
    cand = (std < 2.5) & (ch < 10)
    lab, n = ndi.label(cand); border = np.unique(np.r_[lab[0], lab[-1], lab[:, 0], lab[:, -1]]); border = border[border > 0]
    bgm = np.isin(lab, border)
    # fit a smooth bg (quadratic) to bg pixels
    yy, xx = np.nonzero(bgm); sel = np.random.default_rng(0).choice(len(yy), min(40000, len(yy)), replace=False); yy, xx = yy[sel], xx[sel]
    A = np.stack([np.ones_like(xx), xx, yy, xx * xx, yy * yy, xx * yy], 1).astype(np.float64) / np.array([1, W, H, W * W, H * H, W * H])
    Y, X = np.indices((H, W)); AA = np.stack([np.ones_like(X), X, Y, X * X, Y * Y, X * Y], -1).astype(np.float64) / np.array([1, W, H, W * W, H * H, W * H])
    bgf = np.stack([AA @ np.linalg.lstsq(A, rgb[yy, xx, c], rcond=None)[0] for c in range(3)], -1)
    d = np.abs(rgb - bgf).max(-1)
    fg = d > 14
    fg = ndi.binary_opening(fg, iterations=1); fg = ndi.binary_fill_holes(fg)
    # grow into soft edge pixels that differ moderately and are adjacent
    for _ in range(2): fg |= ndi.binary_dilation(fg) & (d > 8)
    fg = ndi.binary_erosion(fg, iterations=1)   # shave the antialiased bg-blended ring
    fg = ndi.binary_fill_holes(fg)
    lab, n = ndi.label(fg); sz = np.bincount(lab.ravel()); sz[0] = 0
    keep = [k for k in np.argsort(sz)[::-1][:6] if sz[k] > 2000]
    if len(keep) < 6:     # two pieces touch (E boot spurs): split the widest blob at its thinnest column in the middle third
        k = max(keep, key=lambda k: np.ptp(np.nonzero(lab == k)[1])); ys, xs = np.nonzero(lab == k)
        cnt = np.bincount(xs - xs.min()); a_, b_ = len(cnt) // 3, 2 * len(cnt) // 3; cut = xs.min() + a_ + int(np.argmin(cnt[a_:b_]))
        print('split blob at x', cut, 'col px', cnt[cut - xs.min()])
        n2 = lab.max() + 1; lab[(lab == k) & (np.indices(lab.shape)[1] >= cut)] = n2
        sz = np.bincount(lab.ravel()); sz[0] = 0; keep = [k for k in np.argsort(sz)[::-1][:6] if sz[k] > 2000]
    boxes = []
    for k in keep:
        ys, xs = np.nonzero(lab == k); boxes.append((int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()), k))
    boxes.sort()
    names = ['R_thigh', 'L_thigh', 'R_shin', 'L_shin', 'R_boot', 'L_boot']
    info = {}
    for nm, (x0, y0, x1, y1, k) in zip(names, boxes):
        m = lab[y0:y1 + 1, x0:x1 + 1] == k
        c = rgb[y0:y1 + 1, x0:x1 + 1].copy()
        # edge recolour: outer 2px ring from >=3px inside (kills grey bg blend)
        inner = ndi.binary_erosion(m, iterations=3)
        _, (iy, ix) = ndi.distance_transform_edt(~inner, return_indices=True)
        ring = m & ~ndi.binary_erosion(m, iterations=2)
        c[ring] = c[iy[ring], ix[ring]]
        P = 6; rgba = np.zeros((m.shape[0] + 2 * P, m.shape[1] + 2 * P, 4), np.uint8)
        rgba[P:-P, P:-P, :3] = np.clip(c, 0, 255) * m[..., None]; rgba[P:-P, P:-P, 3] = m * 255
        Image.fromarray(rgba, 'RGBA').save(f'legs_v6/{F}_{nm}.png')
        info[nm] = dict(box=[x0, y0, x1, y1], size=[int(rgba.shape[1]), int(rgba.shape[0])], px=int(m.sum()))
    OUT[F] = dict(bg_corner=bgf[5, 5].round(1).tolist(), bg_centre=bgf[H // 2, W // 2].round(1).tolist(), pieces=info)
    print(F, OUT[F])
json.dump(OUT, open('legs_v6/seg_info.json', 'w'), indent=1)
