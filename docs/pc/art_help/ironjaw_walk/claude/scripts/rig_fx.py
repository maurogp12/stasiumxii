"""Rig helpers for the Ironjaw HD walk (scenario-art handoff).
All warps are backward-mapped with cv2.remap so nothing tears or leaves holes."""
import numpy as np, cv2

def remap(rgba, mx, my):
    return cv2.remap(rgba, mx.astype(np.float32), my.astype(np.float32), cv2.INTER_LINEAR,
                     borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))

def lbs_swing(rgba, pivot, deg, r0, r1, stretch=1.0, axis=(0.0, 1.0)):
    """Arm swing without a shoulder seam: the transform weight ramps 0 (r<r0, pauldron) -> 1 (r>r1, forearm/fist/axe),
    so the arm stays welded to the shoulder and bends through the upper arm instead of pivoting as a rigid cutout.
    deg = in-plane rotation (reads right in the front 3/4). stretch = foreshortening along `axis` (shoulder->fist):
    in the back 3/4 a fore/aft swing must read as the arm getting shorter/longer, NOT as an in-plane rotation,
    which flings the axe sideways (Luca's v1 complaint)."""
    h, w = rgba.shape[:2]; yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = xx - pivot[0], yy - pivot[1]; r = np.hypot(dx, dy)
    t = np.clip((r - r0) / max(1e-3, r1 - r0), 0, 1); t = t * t * (3 - 2 * t)
    a = -np.radians(deg) * t                      # inverse rotation for backward mapping
    c, s = np.cos(a), np.sin(a)
    e = np.asarray(axis, np.float32); e = e / np.linalg.norm(e)
    k = 1.0 / (1.0 + (stretch - 1.0) * t)         # inverse axial scale
    rx, ry = c * dx - s * dy, s * dx + c * dy
    along = rx * e[0] + ry * e[1]
    rx, ry = rx + (k - 1) * along * e[0], ry + (k - 1) * along * e[1]
    return remap(rgba, pivot[0] + rx, pivot[1] + ry)

def cape_sway(rgba, top, hem, dx_hem, lift=0.0, ripple=0.0, phase=0.0, k=0.035):
    """Cloth lag: horizontal offset grows from 0 at the collar (top) to dx_hem at the hem with a soft power curve,
    plus an optional travelling ripple on the ragged hem. lift raises the hem (follows the bob one frame late)."""
    h, w = rgba.shape[:2]; yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.clip((yy - top) / max(1, hem - top), 0, 1)
    off = dx_hem * t ** 1.6 + ripple * t ** 2 * np.sin(phase - k * yy)
    return remap(rgba, xx - off, yy + lift * t ** 2)

def axis_stretch(p_from, p_fix, p_to):
    """2x3 affine that keeps p_fix (ankle) and moves p_from (hip) to p_to by stretching ONLY along the hip-ankle axis
    (with the matching rotation). Lengthens a leg without making it chunkier; foot plants are untouched."""
    p_from, p_fix, p_to = map(lambda p: np.asarray(p, float), (p_from, p_fix, p_to))
    u, v = p_from - p_fix, p_to - p_fix
    k = np.linalg.norm(v) / np.linalg.norm(u)
    a = np.arctan2(v[1], v[0]) - np.arctan2(u[1], u[0])
    e = u / np.linalg.norm(u); n = np.array([-e[1], e[0]])
    B = np.stack([e, n], 1)                                  # columns: axis, normal
    S = B @ np.diag([k, 1.0]) @ B.T
    R = np.array([[np.cos(a), -np.sin(a)], [np.sin(a), np.cos(a)]])
    A = R @ S
    return np.hstack([A, (p_fix - A @ p_fix)[:, None]])

def lab_match(src_rgb, src_mask, ref_rgb, ref_mask, strength=1.0):
    """Reinhard mean/std transfer in Lab from ref to src (inside masks). Used to bring old paint into the HD palette."""
    s = cv2.cvtColor(src_rgb, cv2.COLOR_RGB2LAB).astype(np.float32); r = cv2.cvtColor(ref_rgb, cv2.COLOR_RGB2LAB).astype(np.float32)
    ms, ss = s[src_mask].mean(0), s[src_mask].std(0) + 1e-3; mr, sr = r[ref_mask].mean(0), r[ref_mask].std(0)
    o = (s - ms) / ss * sr + mr; o = s + (o - s) * strength
    out = cv2.cvtColor(np.clip(o, 0, 255).astype(np.uint8), cv2.COLOR_LAB2RGB)
    res = src_rgb.copy(); res[src_mask] = out[src_mask]; return res

def capsule(shape, a, b, r):
    m = np.zeros(shape, np.uint8)
    cv2.line(m, tuple(int(round(v)) for v in a), tuple(int(round(v)) for v in b), 1, int(round(2 * r)))
    for p in (a, b): cv2.circle(m, tuple(int(round(v)) for v in p), int(round(r)), 1, -1)
    return m > 0

def over(dst, src):
    a = src[..., 3:4].astype(np.float32) / 255
    o = dst.astype(np.float32); o[..., :3] = src[..., :3] * a + o[..., :3] * (1 - a); o[..., 3:] = np.maximum(o[..., 3:], src[..., 3:])
    return o.astype(np.uint8)
