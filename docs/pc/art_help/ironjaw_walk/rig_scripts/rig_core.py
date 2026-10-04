import json, math, sys, numpy as np, cv2
from PIL import Image
from scipy import ndimage as ndi
sys.path.insert(0, '/workspace/scratch/ij_walk/rig')
from rig_def import PARTS, SCALE, P, ARM_S, ARM_AXE, SPLIT
J = json.load(open('/workspace/art_src/blockout/ironjaw_walk/renders_512/joints_512.json'))['facings']
CW, CH = 512, 360
KLO, KHI = 0.60, 1.25
ARM_REL = None   # arm sheet scale relative to global, set from S idle fit

def load_part(fac, name):
    d = PARTS[fac][name]
    im = np.asarray(Image.open(P + d['file']).convert('RGBA')).copy()
    if d['mirror']:
        im = im[:, ::-1].copy()
    return im

def premul_resize(im, s):
    """uniform pre-scale with premultiplied area/lanczos; returns float premult RGBA."""
    a = im[..., 3:4].astype(np.float32) / 255.0
    pm = np.concatenate([im[..., :3].astype(np.float32) * a, a * 255.0], -1)
    h, w = im.shape[:2]
    nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
    out = np.stack([np.asarray(Image.fromarray(pm[..., c], 'F').resize((nw, nh), Image.LANCZOS)) for c in range(4)], -1)
    return out, (nw / w, nh / h)

def ang(v):  # TA convention: 0 = down, + toward +x ; dir = (sin, cos)
    return math.degrees(math.atan2(v[0], v[1]))

def rot(deg):
    r = math.radians(deg); return np.array([[math.cos(r), math.sin(r)], [-math.sin(r), math.cos(r)]])
# rot(deg) maps dir(theta) -> dir(theta+deg) with dir=(sin,cos): check
def dvec(theta):
    r = math.radians(theta); return np.array([math.sin(r), math.cos(r)])

def similarity(src_a, src_b, dst_a, dst_b, k_axis=1.0, s=1.0):
    """Affine (2x3) mapping src_a->dst_a, src axis (a->b) onto dst axis, uniform scale s across,
    s*k_axis along the axis.  Returns M (dst = M @ [x,y,1])."""
    u = np.subtract(src_b, src_a); lu = np.hypot(*u); u = u / lu; n = np.array([-u[1], u[0]])
    v = np.subtract(dst_b, dst_a); lv = np.hypot(*v); v = v / lv; m = np.array([-v[1], v[0]])
    # local coords (along, across) -> dst
    Bsrc = np.stack([u, n], 1)          # columns
    Bdst = np.stack([v * s * k_axis, m * s], 1)
    L = Bdst @ np.linalg.inv(Bsrc)
    t = np.asarray(dst_a) - L @ np.asarray(src_a)
    return np.hstack([L, t[:, None]])

def warp(pm, M, pre):
    """pm: premult float part already pre-scaled by `pre` (sx,sy). M maps ORIGINAL part px -> cell.
    Compose with inverse pre-scale."""
    S = np.diag([1 / pre[0], 1 / pre[1]])
    # original px x_o = (x_p + 0.5)/pre - 0.5  (pixel-centre convention)
    L = M[:, :2] @ S
    t = M[:, 2] + M[:, :2] @ (0.5 / np.array(pre) - 0.5)
    M2 = np.hstack([L, t[:, None]]).astype(np.float64)
    out = cv2.warpAffine(pm, M2, (CW, CH), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    return out

def to_layer(w):
    a = w[..., 3]
    m = a >= 127.5
    rgb = np.where(m[..., None], np.clip(w[..., :3] / np.maximum(a[..., None], 1e-3) * 255.0, 0, 255), 0)
    return rgb.astype(np.float32), m
