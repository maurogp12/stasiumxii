import numpy as np, cv2
from PIL import Image
from scipy import ndimage as ndi
SHIP = '/workspace/stasium-pc-look/ship/crosshaven_jungle/'
RAW = '/workspace/stasium-pc-look/raw/crosshaven_jungle/'
def hsv(rgb):
    x = cv2.cvtColor(np.ascontiguousarray(rgb.astype(np.float32)), cv2.COLOR_RGB2HSV)
    return x[..., 0], x[..., 1], x[..., 2]          # h in degrees 0..360, s,v 0..1
def lum(rgb): return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722
def resize(a, size, interp=None):
    if interp is None:
        interp = cv2.INTER_AREA if size[0] < a.shape[1] else cv2.INTER_LANCZOS4
    return cv2.resize(np.ascontiguousarray(a.astype(np.float32)), size, interpolation=interp)
def disk(r):
    y, x = np.ogrid[-r:r + 1, -r:r + 1]; return (x * x + y * y) <= r * r
def cv_close(m, r):
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
    return cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, k).astype(bool)
def cv_dilate(m, r):
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
    return cv2.dilate(m.astype(np.uint8), k).astype(bool)
def cv_erode(m, r):
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
    return cv2.erode(m.astype(np.uint8), k).astype(bool)
def cv_open(m, r):
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
    return cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, k).astype(bool)
def push_pull(img, valid):
    """fill invalid pixels with colour diffused from valid ones (pyramid push-pull)."""
    w = valid.astype(np.float32); c = img.astype(np.float32) * w[..., None]
    cs, ws = [c], [w]
    while min(cs[-1].shape[:2]) > 4:
        h, wd = cs[-1].shape[:2]; sz = (max(1, wd // 2), max(1, h // 2))
        cs.append(cv2.resize(cs[-1], sz, interpolation=cv2.INTER_AREA)); ws.append(cv2.resize(ws[-1], sz, interpolation=cv2.INTER_AREA))
    est = cs[-1] / np.maximum(ws[-1], 1e-6)[..., None]
    for c_l, w_l in zip(cs[-2::-1], ws[-2::-1]):
        up = cv2.resize(est, (c_l.shape[1], c_l.shape[0]), interpolation=cv2.INTER_LINEAR)
        e = c_l / np.maximum(w_l, 1e-6)[..., None]
        a = np.clip(w_l * 4, 0, 1)[..., None]
        est = e * a + up * (1 - a)
    return est
def despill_magenta(rgb):
    out = rgb.copy(); ex = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
    ex = np.clip(ex, 0, None); out[..., 0] -= ex; out[..., 2] -= ex
    return np.clip(out, 0, 1)
def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)
def noise2d(shape, scale, seed=0, octaves=3):
    rng = np.random.default_rng(seed); H, W = shape; out = np.zeros(shape, np.float32); amp = 1.0; tot = 0
    for o in range(octaves):
        sc = max(scale / (2 ** o), 1)
        g = rng.standard_normal((int(H / sc) + 3, int(W / sc) + 3)).astype(np.float32)
        up = cv2.resize(g, (int(g.shape[1] * sc), int(g.shape[0] * sc)), interpolation=cv2.INTER_CUBIC)[:H, :W]
        out += amp * up; tot += amp; amp *= 0.5
    out /= tot; return np.clip(out / (out.std() * 2.5 + 1e-6), -1, 1)
def save_rgba(a, p): Image.fromarray(np.ascontiguousarray(a), 'RGBA').save(p, optimize=True)
def save_l(a01, p): Image.fromarray((np.clip(a01, 0, 1) * 255 + .5).astype(np.uint8), 'L').save(p, optimize=True)
def checker_preview(rgba, path, maxw=1400, bg=(58, 58, 68)):
    im = Image.fromarray(rgba, 'RGBA'); b = Image.new('RGBA', im.size, bg + (255,)); b.alpha_composite(im)
    b = b.convert('RGB'); b.thumbnail((maxw, maxw * 4)); b.save(path)
