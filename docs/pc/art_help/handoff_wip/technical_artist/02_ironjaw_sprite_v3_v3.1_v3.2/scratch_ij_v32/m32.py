"""Ironjaw v3.2 measurement helpers: head/torso offset by RGB template match, feet metrics as check_chars."""
import numpy as np, sys
from PIL import Image
sys.path.insert(0, "/workspace/stasium-pc-look/tools")
import check_chars as C
PIV = {"walk": (82, 140), "idle": (82, 140), "attack": (82, 140), "hit": (82, 140), "death": (104, 140)}
N = {"walk": 12, "idle": 4, "attack": 6, "hit": 4, "death": 6}
def load(root, st, fc, i=0):
    a = np.array(Image.open(f"{root}/{st}/ironjaw_{st}_{fc}_f{i:02d}.png").convert("RGBA"))
    if st == "death":   # bring into the 165x157 frame of reference (pivot 82,140): crop x 22..186, y 0..156
        a = a[:157, 22:187]
    return a
def bbox(a):
    ys, xs = np.where(a[..., 3] > 127); return xs.min(), ys.min(), xs.max(), ys.max()
def template(ref, rows):
    """opaque pixels of ref in rows [y0,y1) as (ys,xs,rgb)"""
    m = ref[..., 3] > 127; sel = np.zeros_like(m); sel[rows[0]:rows[1]] = True; sel &= m
    ys, xs = np.where(sel); return ys, xs, ref[ys, xs, :3].astype(float)
def match(tpl, a, r=16, cols=None):
    ys, xs, rgb = tpl
    if cols is not None:
        k = (xs >= cols[0]) & (xs < cols[1]); ys, xs, rgb = ys[k], xs[k], rgb[k]
    h, w = a.shape[:2]; A = a.astype(float); best = None
    for dy in range(-r, r+1):
        for dx in range(-r, r+1):
            y2, x2 = ys+dy, xs+dx; ok = (y2 >= 0) & (y2 < h) & (x2 >= 0) & (x2 < w)
            if ok.mean() < 0.95: continue
            pb = A[y2[ok], x2[ok]]
            e = (np.abs(rgb[ok]-pb[:, :3]).mean(1)*(pb[:, 3] > 127) + 160*(pb[:, 3] <= 127)).mean()
            if best is None or e < best[2]: best = (dx, dy, e)
    return best
def head_rows(ref, n=34):
    b = bbox(ref); return (b[1], b[1]+n)
def feet(a):
    m = C.mask(a); s = C.sole_row(m); return s, C.feet_x(m)
