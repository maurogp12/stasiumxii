"""Auto anchors for limb-like parts (principal axis; A/B = mid cross-section 5% in from each end) and sabatons
(heel = rear-most sole px, toe = front-most sole px, sole = lowest 12% of rows). Prints JSON; rig_def.py copies the values."""
import json, os, sys, numpy as np
from PIL import Image
P = os.environ.get('BASTION_PARTS', '/workspace/scratch/bastion/parts/')
def mask(n): return np.asarray(Image.open(P + n + '.png'))[..., 3] > 0
def limb(n):
    m = mask(n); ys, xs = np.nonzero(m); c = np.array([xs.mean(), ys.mean()])
    X = np.stack([xs - c[0], ys - c[1]], 1); w, v = np.linalg.eigh(X.T @ X / len(X)); u = v[:, 1]
    if u[1] < 0: u = -u
    t = X @ u; n_ = X @ np.array([-u[1], u[0]]); lo, hi = np.percentile(t, [0.5, 99.5]); L = hi - lo
    out = {}
    for k, tt in (('A', lo + 0.05 * L), ('B', hi - 0.05 * L)):
        sel = np.abs(t - tt) < 3; mid = (n_[sel].min() + n_[sel].max()) / 2
        p = c + u * tt + np.array([-u[1], u[0]]) * mid; out[k] = [round(float(p[0]), 1), round(float(p[1]), 1)]
    out['len'] = round(float(L), 1); out['width'] = round(float(np.percentile(n_, 99) - np.percentile(n_, 1)), 1)
    return out
def boot(n):
    m = mask(n); ys, xs = np.nonzero(m); y1 = ys.max(); y0 = ys.min(); H = y1 - y0
    sole = ys > y1 - 0.12 * H
    heel = [int(xs[sole].min()), int(ys[sole][np.argmin(xs[sole])])]; toe = [int(xs[sole].max()), int(ys[sole][np.argmax(xs[sole])])]
    top = ys < y0 + 0.06 * H; ank = [round(float(xs[top].mean()), 1), int(y0)]
    return dict(heel=heel, toe=toe, top=ank, sole_y=int(y1), size=list(m.shape[::-1]))
R = {}
for n in ['S_thigh_fwd', 'S_thigh_down', 'S_thigh_back', 'S_greave', 'S_upper_a', 'S_upper_b', 'E_thigh_down', 'E_greave', 'E_upper_a', 'E_upper_b', 'S_cape_u', 'S_cape_l']:
    R[n] = limb(n)
for n in ['S_sabaton_a', 'S_sabaton_b', 'E_sabaton']:
    R[n] = boot(n)
print(json.dumps(R, indent=0))
