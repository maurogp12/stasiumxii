"""2D cutout rig helpers, copied from the Ironjaw v7 rig (scratch/ij_walk/rig/rig_core.py) without its Ironjaw imports."""
import math, numpy as np, cv2
from PIL import Image
CW, CH = 512, 360

def premul_resize(im, s, sx=1.0):
    """uniform pre-scale (optional extra x factor) with premultiplied lanczos; returns float premult RGBA + (sx, sy)."""
    a = im[..., 3:4].astype(np.float32) / 255.0
    pm = np.concatenate([im[..., :3].astype(np.float32) * a, a * 255.0], -1)
    h, w = im.shape[:2]
    nw, nh = max(1, int(round(w * s * sx))), max(1, int(round(h * s)))
    out = np.stack([np.asarray(Image.fromarray(pm[..., c], 'F').resize((nw, nh), Image.LANCZOS)) for c in range(4)], -1)
    return out, (nw / w, nh / h)

def dvec(theta):
    r = math.radians(theta); return np.array([math.sin(r), math.cos(r)])

def ang(v):
    return math.degrees(math.atan2(v[0], v[1]))

def similarity(src_a, src_b, dst_a, dst_b, k_axis=1.0, s=1.0):
    """2x3 map: src_a->dst_a, src axis (a->b) onto dst axis; scale s across, s*k_axis along."""
    u = np.subtract(src_b, src_a); u = u / np.hypot(*u); n = np.array([-u[1], u[0]])
    v = np.subtract(dst_b, dst_a); v = v / np.hypot(*v); m = np.array([-v[1], v[0]])
    L = np.stack([v * s * k_axis, m * s], 1) @ np.linalg.inv(np.stack([u, n], 1))
    t = np.asarray(dst_a, float) - L @ np.asarray(src_a, float)
    return np.hstack([L, t[:, None]])

def warp(pm, M, pre):
    S = np.diag([1 / pre[0], 1 / pre[1]])
    L = M[:, :2] @ S
    t = M[:, 2] + M[:, :2] @ (0.5 / np.array(pre) - 0.5)
    return cv2.warpAffine(pm, np.hstack([L, t[:, None]]).astype(np.float64), (CW, CH), flags=cv2.INTER_LINEAR,
                          borderMode=cv2.BORDER_CONSTANT, borderValue=0)

def to_layer(w):
    a = w[..., 3]; m = a >= 127.5
    rgb = np.where(m[..., None], np.clip(w[..., :3] / np.maximum(a[..., None], 1e-3) * 255.0, 0, 255), 0)
    return rgb.astype(np.float32), m

def apply(M, p): return M[:, :2] @ np.asarray(p, float) + M[:, 2]
