"""Bastion actions v1 - the painted-part rig for idle, attack, skill, hit and death (S and E; W and N are game-side mirrors).

Same pieces and rules as the LOCKED walk (bastion/v3 at 7f65035e): target-cut layers at the walk's scale s_up, the walk's
painted helm (and S belt), target-scale leg pieces rooted at the target hips, sabatons rigid on the blockout heel / toe.
Every part is bent onto the action blockout (blockout/joints_actions_512.json, act_blockout.py, aimfix mode). Per frame:
  body    one similarity (scale s_up, rotation and along-axis foreshortening from the change of the blockout pelvis->neck
          axis since idle f00), pinned at the painted hip centre, which follows the blockout pelvis. Idle f00 is placed by
          the walk's own rule (crest on the blockout head top - crest_drop, x from the pelvis, the walk's sub-px phase).
  cape    two panels with lag, skinned on the body mesh (wcape weights, feathered: no cut). Death: the cape folds down and
          lies flat on the ground beside him (squashed toward its hinge, nothing below the body's lowest contact).
  legs    walk v3 legs: target thigh / knee cop / greave / sabaton at s_up, hips = target hip points on the body, knee by
          2-bone IK at the target lengths, 1 <= k <= 1.1 along the bone only; sabaton rigid on the blockout heel -> toe
          (pinned at the heel), so a planted foot only moves when the blockout foot moves.
  arms    three rigid painted pieces per arm (upper sleeve, couter + vambrace + fist, mace), FK from the painted shoulder
          on the body: each bone keeps its painted length times the blockout's projected length change, clamped to
          +-15 %, and turns by the blockout bone's change of screen angle since idle f00 (raised and swinging arm keys are
          the target pieces turned, never a stretched hanging arm). The near pauldron is drawn again over the arm root.
  mace    rides on the fist; turns with the blockout mace (grip -> head), length within +-15 %.
  shield  strapped on the outside of the left forearm: its centre is carried by the painted forearm, its 2D shape follows the blockout
          shield's projected axes (rotation + clamped foreshortening 0.6-1.15, never mirrored, so the trident face stays).
Draw order (back to front) follows the walk, and the blockout depth decides when an arm or the mace passes behind the body.
Render at RS x the cell on a padded canvas, area-downsample, binary alpha, black under alpha 0.
usage: barig.py [--only SE] [--acts idle,attack,skill,hit,death] [--frames 0,6] [--out DIR] [--gif]"""
import os, sys, json, math, argparse, numpy as np, cv2
from PIL import Image, ImageOps
HERE = os.path.dirname(os.path.abspath(__file__))
AP = os.environ.get('BAPARTS', os.path.join(HERE, '..', 'parts'))
BLK = os.environ.get('BABLOCK', os.path.join(HERE, '..', 'blockout'))
CW, CH, PIV, FPS = 512, 360, (256, 329), 17.144
PADT, PADB, PADX = 120, 160, 80             # padding around the cell while rendering (checked, never cropped silently)
ACTS = {'idle': 12, 'attack': 12, 'skill': 12, 'hit': 8, 'death': 13}
LOOP = {'idle', 'attack', 'skill', 'hit'}
JA = json.load(open(f'{BLK}/joints_actions_512.json')); JF = JA['facings']
BJ = {F: json.load(open(f'{AP}/bjoints_{F}.json')) for F in 'SE'}
CFG = {
 'S': dict(s=0.4122, crest_drop=15.2, phase=(0.2, 0.75), boot_o=(-3.74, 9.79), tka=1.0, smax=1.1, len_clamp=(0.85, 1.15),
           cape_lag=(0.35, 0.65), cape_trail=(0.25, 0.55), cape_follow=0.45, idle_sway=(0.5, 1.2), death_fold_rot=(-6.0, -8.0), cape_lie_k=0.55,
           shield_k=(0.6, 1.15), mace_k=(0.85, 1.15)),
 'E': dict(s=0.39399, crest_drop=15.0, phase=(0.8, 0.75), boot_o=(5.02, 9.6), tka=1.1, smax=1.1, len_clamp=(0.85, 1.15),
           cape_lag=(0.35, 0.65), cape_trail=(0.25, 0.55), cape_follow=0.45, idle_sway=(0.5, 1.2), death_fold_rot=(0.0, 0.0), cape_lie_k=0.9,
           shield_k=(0.6, 1.15), mace_k=(0.85, 1.15)),
}

def fr(F, act, i): return JF[f'{act}_{F}'][f'f{i:02d}']
def jt(F, act, i, k): return np.array(fr(F, act, i)['joints'][k], float)
def ang(v): return math.atan2(v[1], v[0])
def R2(a): c, s_ = math.cos(a), math.sin(a); return np.array([[c, -s_], [s_, c]])
def unit(v): v = np.asarray(v, float); return v / max(float(np.hypot(*v)), 1e-9)
def apm(M, p): return M[:, :2] @ np.asarray(p, float) + M[:, 2]
def wrap(a): return (a + math.pi) % (2 * math.pi) - math.pi
def ss(t): t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)

def sim(a, b, A, B, s_across):
    """source segment a->b onto A->B: along scale |AB|/|ab|, across scale s_across, a -> A."""
    u = unit(np.subtract(b, a)); n = np.array([-u[1], u[0]]); v = unit(np.subtract(B, A)); m = np.array([-v[1], v[0]])
    k = math.dist(A, B) / math.dist(a, b); L = np.outer(v, u) * k + np.outer(m, n) * s_across
    return np.hstack([L, (np.asarray(A, float) - L @ np.asarray(a, float))[:, None]])

def ik_knee(hip, ank, L1, L2, kref):
    d = np.subtract(ank, hip); D = float(np.hypot(*d)); D = min(D, L1 + L2 - 1e-4); u = unit(d); n = np.array([-u[1], u[0]])
    a = (L1 * L1 - L2 * L2 + D * D) / (2 * D); h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    sg = 1.0 if np.dot(np.subtract(kref, hip), n) >= 0 else -1.0
    return np.asarray(hip, float) + u * a + n * h * sg

# ------------------------------------------------------------------ textures (premultiplied float)
TEX = {}
def ptex(name):
    """the part pre-scaled to the cell scale s_up of its facing with a premultiplied Lanczos resize (the walk's
    premul_resize), so a frame is sampled like the walk (linear, at the cell) and idle f00 keeps the walk's sharpness.
    Returns (premultiplied float RGBA 0..1, pre = (sx, sy) scaled px per target px)."""
    if name not in TEX:
        im = np.asarray(Image.open(f'{AP}/{name}.png').convert('RGBA')).astype(np.float32)
        s = CFG[name[-1]]['s'] if name[-1] in CFG else 1.0
        a = im[..., 3:4] / 255.0; pm = np.concatenate([im[..., :3] * a, a * 255.0], -1)
        h, w = im.shape[:2]; nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
        out = np.stack([np.asarray(Image.fromarray(pm[..., c], 'F').resize((nw, nh), Image.LANCZOS)) for c in range(4)], -1) / 255.0
        TEX[name] = (np.clip(out, 0, 1).astype(np.float32), (nw / w, nh / h))
    return TEX[name]

def src_px(name, P):
    """target px -> pre-scaled texture px"""
    pre = np.array(ptex(name)[1]); return (np.asarray(P, float) + 0.5) * pre - 0.5

# ------------------------------------------------------------------ mesh warp (piecewise affine)
def grid_mesh(alpha, step=4, pad=3):
    a = alpha > 0.01; ys, xs = np.nonzero(a)
    x0, x1, y0, y1 = xs.min() - step, xs.max() + step, ys.min() - step, ys.max() + step
    gx = np.arange(x0, x1 + step, step); gy = np.arange(y0, y1 + step, step)
    V = np.stack(np.meshgrid(gx, gy), -1).reshape(-1, 2).astype(np.float64); nx = len(gx)
    ad = cv2.dilate(a.astype(np.uint8), np.ones((2 * pad + 1, 2 * pad + 1), np.uint8))
    ii = [r * nx + q for r in range(len(gy) - 1) for q in range(nx - 1)
          if ad[max(gy[r], 0):gy[r] + step + 1, max(gx[q], 0):gx[q] + step + 1].any()]
    v0 = np.array(ii); tris = np.concatenate([np.stack([v0, v0 + 1, v0 + nx + 1], 1), np.stack([v0, v0 + nx + 1, v0 + nx], 1)])
    return V, tris

def warp(T, V, Vd, tris, H, W):
    D = Vd[tris]; S = V[tris]
    dA = np.concatenate([D, np.ones(D.shape[:2] + (1,))], 2); ok = np.abs(np.linalg.det(dA)) > 1e-6
    A = np.zeros((len(tris), 2, 3)); A[ok] = np.transpose(np.linalg.solve(dA[ok], S[ok]), (0, 2, 1))
    idx = np.full((H, W), -1, np.int32); Di = np.round(D * 16).astype(np.int32)
    for t in np.nonzero(ok)[0]: cv2.fillConvexPoly(idx, Di[t], int(t), lineType=cv2.LINE_8, shift=4)
    # pixels on a shared edge that neither triangle's raster covered (they show as hairline gaps at the cell scale): they
    # take a neighbour triangle's map
    gap = idx < 0; nb = cv2.dilate(idx.astype(np.float32), np.ones((3, 3), np.uint8)).astype(np.int32)
    idx[gap & (nb >= 0)] = nb[gap & (nb >= 0)]
    yy, xx = np.nonzero(idx >= 0); tt = idx[yy, xx]
    mapx = np.full((H, W), -1e4, np.float32); mapy = np.full((H, W), -1e4, np.float32)
    mapx[yy, xx] = A[tt, 0, 0] * xx + A[tt, 0, 1] * yy + A[tt, 0, 2]; mapy[yy, xx] = A[tt, 1, 0] * xx + A[tt, 1, 1] * yy + A[tt, 1, 2]
    return cv2.remap(T, mapx, mapy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0), (mapx, mapy)

def remap_with(T, maps): return cv2.remap(T, maps[0], maps[1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
def over(dst, src): return src + dst * (1 - src[..., 3:])
def lbs(V, W, Ms): return sum(W[:, j:j + 1] * (V @ M[:, :2].T + M[:, 2]) for j, M in enumerate(Ms))

_MESH = {}
def body_mesh(F):
    if F not in _MESH:
        V, tris = grid_mesh(np.asarray(Image.open(f'{AP}/body_{F}.png'))[..., 3].astype(np.float32) / 255., 4)
        wc = np.asarray(Image.open(f'{AP}/wcape_{F}.png').convert('RGB')).astype(np.float32) / 255.
        xi = np.clip(V[:, 0].astype(int), 0, 1279); yi = np.clip(V[:, 1].astype(int), 0, 719)
        wu, wl = wc[yi, xi, 0], wc[yi, xi, 1]; W = np.stack([np.clip(1 - wu - wl, 0, 1), wu, wl], 1); W /= W.sum(1, keepdims=True)
        _MESH[F] = (V, tris, W)
    return _MESH[F]

class Canvas:
    """cell px -> canvas px: (x + PADX, y + PADT) * RS"""
    def __init__(self, RS): self.RS = RS; self.H = (CH + PADT + PADB) * RS; self.W = (CW + 2 * PADX) * RS
    def M(self, M, pre=(1.0, 1.0)):     # a target->cell 2x3 map as (pre-scaled texture px)->canvas
        o = np.array([PADX, PADT], float); pre = np.asarray(pre, float)
        L = M[:, :2] @ np.diag(1 / pre); t = M[:, 2] + M[:, :2] @ (0.5 / pre - 0.5)
        return np.hstack([L * self.RS, ((t + o) * self.RS)[:, None]]).astype(np.float32)
    def pts(self, P): return (np.asarray(P, float) + np.array([PADX, PADT])) * self.RS
    def affine(self, name, M):
        T, pre = ptex(name); return cv2.warpAffine(T, self.M(M, pre), (self.W, self.H), flags=cv2.INTER_LINEAR, borderValue=0)

# ------------------------------------------------------------------ body
def placement0(F):
    """idle f00 body map = the walk's trunk rule on the idle f00 blockout joints."""
    c = CFG[F]; s = c['s']; B = BJ[F]; cx_t, cy_t = B['crest']; px_t = B['pelvis'][0]
    pel = jt(F, 'idle', 0, 'pelvis'); top = jt(F, 'idle', 0, 'head_top')
    cx = pel[0] + (cx_t - px_t) * s; cy = top[1] - c['crest_drop']
    tx = round(cx - s * cx_t) + c['phase'][0]; ty = round(cy - s * cy_t) + c['phase'][1]
    return np.array([[s, 0, tx], [0, s, ty]], float)

LIE_FLAT = 0.35
CAPE_MAX = 10.0
def torso_axis(F, act, i): return jt(F, act, i, 'neck') - jt(F, act, i, 'pelvis')

def torso_M(F, act, i):
    c = CFG[F]; s = c['s']; B = BJ[F]
    M0 = placement0(F); hc_t = np.mean([B['hips']['R'], B['hips']['L']], 0)
    u0 = torso_axis(F, 'idle', 0); ui = torso_axis(F, act, i)
    phi = wrap(ang(ui) - ang(u0)); k = float(np.clip(np.linalg.norm(ui) / np.linalg.norm(u0), 0.35, 1.15))
    e = unit(u0); Sx = np.eye(2) + (k - 1) * np.outer(e, e); A = R2(phi) @ Sx * s
    d0 = apm(M0, hc_t) - jt(F, 'idle', 0, 'pelvis')
    piv = jt(F, act, i, 'pelvis') + R2(phi) @ (Sx @ d0)
    M = np.hstack([A, (piv - A @ hc_t)[:, None]]); ky = 1.0
    if act == 'death':        # lying down: what lies on the ground is seen at the camera's 30 deg, so it flattens on screen
        ky = 1.0 - LIE_FLAT * float(ss(abs(phi) / math.radians(55.0)))
        M = squash_about(M, jt(F, act, i, 'pelvis'), np.array([0.0, 1.0]), ky)
    return M, dict(phi=math.degrees(phi), k=k, lie_ky=ky)

def rot_about(M, p, a): Rr = R2(a); return np.hstack([Rr @ M[:, :2], (Rr @ (M[:, 2] - p) + p)[:, None]])
def squash_about(M, p, d, k): S = np.eye(2) + (k - 1) * np.outer(d, d); return np.hstack([S @ M[:, :2], (S @ (M[:, 2] - p) + p)[:, None]])

def cape_angles(F, act):
    c = CFG[F]; n = ACTS[act]
    phi = np.array([torso_M(F, act, i)[1]['phi'] for i in range(n)]); pel = np.array([jt(F, act, i, 'pelvis') for i in range(n)])
    reps = 3 if act in LOOP else 1; ph = np.tile(phi, reps); pv = np.tile(pel, (reps, 1))
    vel = np.diff(pv[:, 0], prepend=pv[0, 0]) if act not in LOOP else np.diff(np.concatenate([pv[-1:, 0], pv[:, 0]]))
    out = []
    for lag, trail in ((c['cape_lag'][0], c['cape_trail'][0]), (c['cape_lag'][1], c['cape_trail'][1])):
        f = ph[0]; vf = 0.0; res = []
        for j in range(len(ph)):
            f = f + (ph[j] - f) * (1 - lag); vf = vf + (vel[j] - vf) * (1 - lag)
            res.append(math.radians((f - ph[j]) * c['cape_follow']) + math.radians(trail * vf * 4.0))
        out.append(np.array(res[-n:]))
    if act == 'idle':
        t = np.arange(n) / n * 2 * math.pi
        out[0] = out[0] + np.radians(c['idle_sway'][0]) * np.sin(t - 0.8); out[1] = out[1] + np.radians(c['idle_sway'][1]) * np.sin(t - 1.6)
    if act == 'death':
        w = np.clip(1 - (np.arange(n) - 8) / 4, 0, 1); out = [o * w for o in out]
    out = [o - o[0] for o in out]      # every action starts on the painting (idle f00), so they all chain on the same frame
    lim = math.radians(CAPE_MAX)       # a panel never swings more than this off the body (beyond it the mesh shears the tatters)
    return [np.clip(o, -lim, lim) for o in out]

# ------------------------------------------------------------------ legs (walk v3 rules)
def leg_pose(F, act, i, sd, Mt):
    c = CFG[F]; s = c['s']; B = BJ[F]; Lg = B['legs']
    th, gr, kc, sb = Lg['thigh'], Lg['greave'], Lg['kneecop'], Lg['sabaton']
    Hs = np.array(B['thigh_hip'], float); Ks = np.array(th['B'], float)
    l1 = s * math.dist(Hs, Ks); l2 = s * math.dist(gr['A'], gr['B'])
    hip = apm(Mt, B['hips'][sd])
    he, to = jt(F, act, i, sd + '_heel'), jt(F, act, i, sd + '_toe')
    u = unit(to - he); n = np.array([-u[1], u[0]]); o = c['boot_o']
    Ph = he + u * o[0] + n * o[1]
    lp = s * math.dist(sb['heel'], sb['toe'])
    Mb = sim(sb['heel'], sb['toe'], Ph, Ph + u * lp, s)
    if c['tka'] != 1.0:
        A = np.eye(2) + (c['tka'] - 1) * np.outer(u, u); Mb = np.hstack([A @ Mb[:, :2], (A @ (Mb[:, 2] - Ph) + Ph)[:, None]])
    G = jt(F, act, i, sd + '_ankle')
    d = math.dist(hip, G); k = float(np.clip(d / (l1 + l2), 1.0, c['smax']))
    kn = ik_knee(hip, G, l1 * k, l2 * k, jt(F, act, i, sd + '_knee'))
    an = kn + unit(G - kn) * (l2 * k)
    Mth = sim(Ks, Hs, kn, hip, s); Mgr = sim(gr['B'], gr['A'], an, kn, s)
    am = (ang(kn - hip) + ang(an - kn)) / 2 - ang(np.subtract(gr['B'], gr['A']))
    Rk = R2(am) * s; Mkc = np.hstack([Rk, (kn - Rk @ np.array(kc['C'], float))[:, None]])
    return dict(Mth=Mth, Mgr=Mgr, Mkc=Mkc, Mb=Mb, hip=hip, knee=kn, ankle=an, goal=G, k=k, short=max(0.0, d - (l1 + l2) * k),
                heel=apm(Mb, sb['heel']), toe=apm(Mb, sb['toe']))

def near_leg(F, act, i):
    o = fr(F, act, i)['draw_order']; return 'L' if o.index('L_boot') < o.index('R_boot') else 'R'

# ------------------------------------------------------------------ arms (FK on the painted shoulder)
KEY_BLEND = 30.0     # deg of arm-key change (|d shoulder| + |d abduction| + |d elbow|) for a full switch to the blockout direction
def key_w(F, act, i, sd):
    """how far the blockout arm key of this frame is from the idle f00 key: 0 = rest, 1 = posed."""
    a0 = fr(F, 'idle', 0)['key']['arms'][sd]; ai = fr(F, act, i)['key']['arms'][sd]
    return float(ss(sum(abs(x - y) for x, y in zip(ai, a0)) / KEY_BLEND))

def turn(a_paint, a_b0, a_bi, w):
    """screen rotation for a painted bone. At rest (w 0) it turns by the blockout bone's change since idle f00, so idle keeps
    the painting; posed (w 1: raised, swung, thrown out) it lies on the blockout bone's own screen direction, so a raised
    or swinging arm and the mace point where the blockout points (the smash lands along the facing)."""
    rel = wrap(a_bi - a_b0); absl = wrap(a_bi - a_paint)
    return wrap(rel + w * wrap(absl - rel))

def arm_pose(F, act, i, sd, Mt):
    c = CFG[F]; s = c['s']; B = BJ[F]
    rest = B['arms']['R'] if sd == 'R' else B['L_target']
    sh = apm(Mt, rest['shoulder'])
    b = lambda a, ii, k: jt(F, a, ii, f'{sd}_{k}')
    out = dict(sh=sh); prev = sh; lens = []; w = key_w(F, act, i, sd); out['w'] = w
    for seg, (ja, jb) in (('u', ('shoulder', 'elbow')), ('f', ('elbow', 'hand'))):
        v0 = s * (np.array(rest[jb], float) - np.array(rest[ja], float))
        b0 = b('idle', 0, jb) - b('idle', 0, ja); bi = b(act, i, jb) - b(act, i, ja)
        kraw = np.linalg.norm(bi) / max(np.linalg.norm(b0), 1e-6); k = float(np.clip(kraw, *c['len_clamp']))
        d = R2(turn(ang(v0), ang(b0), ang(bi), w)) @ v0 * k
        if act == 'death':    # an arm lying on the ground flattens on screen like the body (painted length kept)
            wf = float(ss(abs(torso_M(F, act, i)[1]['phi']) / 55.0)); L0 = np.linalg.norm(d)
            d = np.array([d[0], d[1] * (1 - 0.5 * wf)]); d = d / max(np.linalg.norm(d), 1e-6) * L0
        nxt = prev + d; out[jb] = nxt; lens.append(k); prev = nxt
    out['k'] = lens
    src = B['arms'][sd]
    out['Mu'] = sim(src['shoulder'], src['elbow'], out['sh'], out['elbow'], s)
    out['Mf'] = sim(src['elbow'], src['hand'], out['elbow'], out['hand'], s)
    out['Mrest_f'] = sim(rest['elbow'], rest['hand'], out['elbow'], out['hand'], s)     # target-rest frame of the forearm
    return out

MACE_R = {'S': 70.0, 'E': 62.0}      # spiked head radius incl. spikes, target px
def mace_M(F, act, i, arm):
    c = CFG[F]; s = c['s']; B = BJ[F]; g_t, h_t = np.array(B['mace']['grip']), np.array(B['mace']['head'])
    g = apm(arm['Mf'], g_t)
    b0 = jt(F, 'idle', 0, 'mace_head') - jt(F, 'idle', 0, 'mace_grip'); bi = jt(F, act, i, 'mace_head') - jt(F, act, i, 'mace_grip')
    k = float(np.clip(np.linalg.norm(bi) / max(np.linalg.norm(b0), 1e-6), *c['mace_k']))
    v0 = s * (h_t - g_t); a = turn(ang(v0), ang(b0), ang(bi), arm['w'])
    # keep the spiked head inside the cell: if it would cross the top row, the mace tips back down about the fist by the
    # smallest angle that clears it (the wind-up and the cocked guard hold it a little lower than the blockout)
    r = s * MACE_R[F]; corr = 0.0
    def head(a_): return g + R2(a_) @ v0 * k
    if head(a)[1] - r < 2:
        for dd in np.radians(np.arange(1, 91, 1)):
            cands = [a + dd, a - dd]; ok = [c_ for c_ in cands if head(c_)[1] - r >= 2]
            if ok:      # tip it further the way it already leans (no flip over the head)
                side = math.copysign(1.0, head(a)[0] - g[0]); best = max(ok, key=lambda c_: side * (head(c_)[0] - head(a)[0]))
                corr = math.degrees(best - a); a = best; break
    hd = head(a)
    M = sim(g_t, h_t, g, hd, s)
    if act == 'death':
        # the mace drops with him and lies flat on the ground: its screen vector flattens like everything lying there
        # (y x 0.5) and turns toward the ground line, then the whole piece is kept inside the cell
        wf = float(ss(abs(torso_M(F, act, i)[1]['phi']) / 55.0)); v = hd - g
        vf = np.array([v[0], v[1] * (1 - 0.5 * wf)]); vf = vf / max(np.linalg.norm(vf), 1e-6) * np.linalg.norm(v)
        hd = g + vf; M = keep_inside(sim(g_t, h_t, g, hd, s), f'mace_{F}')
        hd = apm(M, h_t); g = apm(M, g_t)
    return M, dict(grip=g, head=hd, k=k, top_corr_deg=round(corr, 1))

def shield_M(F, act, i, armL):
    """centre carried by the left forearm (outside of it); 2D shape = rotation x clamped stretch of the blockout shield's
    projected axes relative to idle f00, never mirrored."""
    c = CFG[F]; s = c['s']; B = BJ[F]
    def axes(a, ii):
        j = fr(F, a, ii)['joints']
        return np.column_stack([np.subtract(j['shield_top'], j['shield_bot']), np.subtract(j['shield_out'], j['shield_in'])])
    A0, Ai = axes('idle', 0), axes(act, i)
    L = Ai @ np.linalg.inv(A0)
    U, S_, Vt = np.linalg.svd(L); Rm = U @ Vt
    if np.linalg.det(Rm) < 0: U[:, 1] *= -1; Rm = U @ Vt
    P = Vt.T @ np.diag(np.clip(S_, *c['shield_k'])) @ Vt
    Lf = Rm @ P * s
    # the centre is carried by the painted left forearm (strapped on its outside); at idle f00 it is the painting
    cen = apm(armL['Mrest_f'], B['shield_c'])
    Ms = np.hstack([Lf, (cen - Lf @ np.array(B['shield_c'], float))[:, None]])
    if act == 'death':
        # falling, the shield comes down with him: it turns with the body and lies flat on top of his left side (strapped
        # to the forearm, which lies across him), instead of following the thrown-out blockout plate out of the cell
        Mt, ti = torso_M(F, act, i); wf = float(ss(abs(ti['phi']) / 55.0))
        Mr = Mt.copy(); Mr[:, 2] += (jt(F, act, i, 'L_wrist') - jt(F, 'idle', 0, 'L_wrist')) * 0.0
        Ms = (1 - wf) * Ms + wf * Mr
    Ms = keep_inside(Ms, f'shield_{F}')
    return Ms, dict(stretch=[float(x) for x in np.clip(S_, *c['shield_k'])], raw=[float(x) for x in S_])

_BB = {}
def keep_inside(M, name, margin=2.0):
    """translate a rigid piece the least so its painted pixels stay inside the cell."""
    if name not in _BB:
        a = np.asarray(Image.open(f'{AP}/{name}.png'))[..., 3] > 127; ys, xs = np.nonzero(a)
        k = cv2.convexHull(np.stack([xs, ys], 1).astype(np.float32))[:, 0]; _BB[name] = k
    P = np.array([apm(M, p) for p in _BB[name]]); d = np.zeros(2)
    lo, hi = P.min(0), P.max(0)
    for ax, lim in ((0, CW), (1, CH)):
        if lo[ax] < margin: d[ax] = margin - lo[ax]
        elif hi[ax] > lim - 1 - margin: d[ax] = (lim - 1 - margin) - hi[ax]
    M = M.copy(); M[:, 2] += d; return M

def behind(F, act, i, part, ref='torso', margin=0.0):
    d = fr(F, act, i)['depth']; return d.get(part, -1e9) > d.get(ref, 0) + margin

# ------------------------------------------------------------------ frame
CAPE = {}
def render(F, act, i, RS=1):
    c = CFG[F]; cv = Canvas(RS); B = BJ[F]
    Mt, tinfo = torso_M(F, act, i)
    au, al_ = CAPE.setdefault((F, act), cape_angles(F, act)); au, al_ = au[i], al_[i]
    pu = apm(Mt, B['cape_upper']); hinge_t = (B['cape_upper'][0], sum(B['cape_lower_y']) / 2)
    Mu = rot_about(Mt, pu, au); Ml = rot_about(Mu, apm(Mu, hinge_t), al_)
    fold = 0.0
    if act == 'death':
        # lying down: the cloak lies flat under and beside him. No lag is left (cape_angles), the panels turn with the body
        # by death_fold_rot (toward his feet, along the ground), and the whole body map already carries the ground-plane
        # flattening (torso_M). Nothing is squashed per vertex, so the ragged hem keeps its painted tatters.
        fold = float(ss(abs(tinfo['phi']) / 55.0)); fr_ = c['death_fold_rot']
        Mu = rot_about(Mu, pu, math.radians(fr_[0]) * fold); Ml = rot_about(Ml, pu, math.radians(fr_[0]) * fold)
        Ml = rot_about(Ml, apm(Mu, hinge_t), math.radians(fr_[1]) * fold)
        # the cloth lies flat under / over him: it is pulled in along the body toward its shoulder hinge (S lies on it,
        # so most of it disappears under his back; E falls on his side and it drapes over him)
        dn = unit(jt(F, act, i, 'pelvis') - jt(F, act, i, 'neck')); kk = 1 - (1 - c['cape_lie_k']) * fold
        Mu = squash_about(Mu, pu, dn, kk); Ml = squash_about(Ml, pu, dn, kk)
    V, tris, W = body_mesh(F)
    Vd = lbs(V, W, (Mt, Mu, Ml))
    body, maps = warp(ptex(f'body_{F}')[0], src_px(f'body_{F}', V), cv.pts(Vd), tris, cv.H, cv.W)
    back = remap_with(ptex(f'back_{F}')[0], maps)
    front = body * (1 - back[..., 3:]) if True else body
    meta = dict(torso=tinfo, cape=[math.degrees(au), math.degrees(al_)], cape_fold=fold)
    # legs
    legs = {sd: leg_pose(F, act, i, sd, Mt) for sd in 'RL'}; nr = near_leg(F, act, i); leg_imgs = []
    for sd in [x for x in 'RL' if x != nr] + [nr]:
        P = legs[sd]; L_ = np.zeros((cv.H, cv.W, 4), np.float32)
        for nm, M in (('thigh', P['Mth']), ('greave', P['Mgr']), ('kneecop', P['Mkc']), ('sabaton', P['Mb'])):
            L_ = over(L_, cv.affine(f'leg_{nm}_{F}', M))
        leg_imgs.append(L_)
        meta[sd] = {k: (v.tolist() if isinstance(v, np.ndarray) and v.ndim == 1 else v) for k, v in P.items() if not k.startswith('M')}
    # arms, mace, shield
    arms = {sd: arm_pose(F, act, i, sd, Mt) for sd in 'RL'}
    Mm, minfo = mace_M(F, act, i, arms['R']); Ms, sinfo = shield_M(F, act, i, arms['L'])
    img_u = {sd: cv.affine(f'uarm_{sd}_{F}', arms[sd]['Mu']) for sd in 'RL'}
    img_f = {sd: cv.affine(f'fore_{sd}_{F}', arms[sd]['Mf']) for sd in 'RL'}
    img_m = cv.affine(f'mace_{F}', Mm); img_s = cv.affine(f'shield_{F}', Ms); cov = cv.affine(f'cover_{F}', Mt)
    for sd in 'RL': meta['arm_' + sd] = dict(sh=arms[sd]['sh'].tolist(), el=arms[sd]['elbow'].tolist(), hand=arms[sd]['hand'].tolist(), k=arms[sd]['k'])
    meta['mace'] = dict(grip=minfo['grip'].tolist(), head=minfo['head'].tolist(), k=minfo['k']); meta['shield'] = sinfo
    # ---- composite, back to front
    rarm_back = behind(F, act, i, 'R_farm', 'torso', 0.0) and behind(F, act, i, 'R_uarm', 'torso', -5.0)
    mace_back = behind(F, act, i, 'mace_head', 'torso', 0.0)
    rarm = [img_u['R'], img_f['R']]
    img = np.zeros((cv.H, cv.W, 4), np.float32)
    mace_l = [img_m]
    if F == 'S':      # walk order: cape, legs, (L arm), body, shield, mace arm, pauldron
        order = [back]
        if rarm_back: order += (mace_l if mace_back else []) + rarm
        order += leg_imgs + [img_u['L'], img_f['L'], front, img_s]
        order += ((mace_l if not mace_back else []) if rarm_back else mace_l + rarm + [cov])
    else:             # walk order: legs, (L arm), trunk, shield, cape + pauldron + helm, mace arm, pauldron
        order = []
        if rarm_back: order += (mace_l if mace_back else []) + rarm
        order += leg_imgs + [img_f['L'], img_u['L'], back, img_s, front]
        order += ((mace_l if not mace_back else []) if rarm_back else mace_l + rarm + [cov])
    meta['rarm_back'] = bool(rarm_back); meta['mace_back'] = bool(mace_back)
    for L_ in order: img = over(img, L_)
    return img, meta, cv

def bottom_need(img, cv):
    a = img[..., 3] > 0.5; ys = np.nonzero(a.any(1))[0]
    return max(0, int(ys.max()) - (PADT + CH - 2)) if len(ys) else 0

def death_shifts(F):
    """smallest lift that keeps every death frame inside the cell (lowest row <= 358), never decreasing, eased, starting no
    earlier than the frame where the blockout first moves the feet (planted feet before that stay exactly put)."""
    n = ACTS['death']; need = [bottom_need(*[render(F, 'death', i)[k] for k in (0, 2)]) for i in range(n)]
    first = next(i for i in range(1, n) if any(np.abs(jt(F, 'death', i, f'{sd}_{k}') - jt(F, 'death', 0, f'{sd}_{k}')).max() > 0.25
                                              for sd in 'RL' for k in ('heel', 'toe')))
    sh = np.maximum.accumulate(np.array(need, float))
    for j in range(n - 2, first - 1, -1): sh[j] = max(sh[j], sh[j + 1] - 3)     # eased: at most 3 px more per frame
    sh[:first] = 0
    return [int(v) for v in sh]

def lift(img, k):
    if k <= 0: return img
    return np.concatenate([img[k:], np.zeros((k,) + img.shape[1:], np.float32)], 0)

def to_cell(img, cv):
    RS = cv.RS; sm = cv2.resize(img, (img.shape[1] // RS, img.shape[0] // RS), interpolation=cv2.INTER_AREA)
    a = sm[..., 3]; m = a > 0.5
    lost = dict(top=int(m[:PADT].sum()), bottom=int(m[PADT + CH:].sum()), left=int(m[PADT:PADT + CH, :PADX].sum()), right=int(m[PADT:PADT + CH, PADX + CW:].sum()))
    sm = sm[PADT:PADT + CH, PADX:PADX + CW]; a = sm[..., 3]; m = a > 0.5
    rgb = np.clip(sm[..., :3] / np.maximum(a[..., None], 1e-6), 0, 1)
    out = np.zeros((CH, CW, 4), np.uint8); out[m, :3] = (rgb[m] * 255 + 0.5).astype(np.uint8); out[m, 3] = 255
    # specks: drop alpha islands under 6 px (binarised antialias crumbs)
    n_, lab_, st_, _ = cv2.connectedComponentsWithStats(out[..., 3], 8)
    for k in range(1, n_):
        if st_[k, cv2.CC_STAT_AREA] < 6: out[lab_ == k] = 0
    return out, lost

def gif(paths, out, bg=(172, 172, 172), hold_last=0):
    ims = []
    for p in paths:
        a = Image.open(p).convert('RGBA'); b = Image.new('RGBA', a.size, bg + (255,)); b.alpha_composite(a)
        ims.append(b.convert('RGB').convert('P', palette=Image.ADAPTIVE, colors=255))
    dur = [10 * round(100 / FPS)] * len(ims)
    if hold_last: dur[-1] = hold_last
    ims[0].save(out, save_all=True, append_images=ims[1:], duration=dur, loop=0, disposal=2)

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--out', default=os.path.join(HERE, '..', 'frames')); ap.add_argument('--only', default='SE')
    ap.add_argument('--acts', default=','.join(ACTS)); ap.add_argument('--frames', default=None); ap.add_argument('--rs', type=int, default=1)
    ap.add_argument('--gif', action='store_true')
    a = ap.parse_args(); os.makedirs(a.out, exist_ok=True)
    infop = os.path.join(a.out, '_build_info.json'); info = json.load(open(infop)).get('frames', {}) if os.path.exists(infop) else {}
    for F in a.only:
        for act in a.acts.split(','):
            n = ACTS[act]; fl = [int(x) for x in a.frames.split(',')] if a.frames else range(n)
            shifts = death_shifts(F) if act == 'death' else [0] * n
            for i in fl:
                img, meta, cv = render(F, act, i, a.rs); img = lift(img, shifts[i] * a.rs); meta['lift_px'] = shifts[i]
                cell, lost = to_cell(img, cv); meta['lost_px_outside_cell'] = lost
                Image.fromarray(cell).save(f'{a.out}/{act}_{F}_f{i:02d}.png')
                info.setdefault(F, {}).setdefault(act, {})[f'f{i:02d}'] = meta
                print(F, act, i, 'phi %.1f k %.2f' % (meta['torso']['phi'], meta['torso']['k']),
                      'legk %.3f %.3f short %.1f %.1f' % (meta['R']['k'], meta['L']['k'], meta['R']['short'], meta['L']['short']),
                      'armk R %.2f %.2f L %.2f %.2f' % (*meta['arm_R']['k'], *meta['arm_L']['k']), 'mace %.2f' % meta['mace']['k'],
                      'lift', meta['lift_px'], 'back', meta['rarm_back'], meta['mace_back'], 'lost', {k: v for k, v in lost.items() if v}, flush=True)
            if a.gif and not a.frames:
                os.makedirs(os.path.join(a.out, '..', 'gifs'), exist_ok=True)
                gif([f'{a.out}/{act}_{F}_f{i:02d}.png' for i in range(n)], os.path.join(a.out, '..', 'gifs', f'{act}_{F}.gif'),
                    hold_last=600 if act == 'death' else 0)
    json.dump(dict(cfg=CFG, frames=info), open(infop, 'w'), indent=1, default=float)
