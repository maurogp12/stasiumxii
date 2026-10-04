"""Gloam actions v1 - the painted-part rig for idle, attack, skill, hit and death (S and E; W and N are game-side mirrors).

Same pieces and rules as the LOCKED walk (gloam/v1_claude at 8119c9e, read through gwalk.py): the target-cut body at the
walk's scale s and height (S 0.362, E 0.354, dy 6), the walk's continuous painted legs on its 3-bone skin, and the walk's
leg rules. Every piece is bent onto the action blockout (blockout/joints_actions_512.json, act_blockout.py, aimfix mode).
Per frame:
  body    one map of the body painting (body_F, front_F): scale s, rotated by the change of the blockout pelvis->neck axis
          since idle f00, pinned at the painted hip centre, which follows the blockout pelvis. Idle f00 sits exactly where
          the walk puts f00 (x on the hip centre, hood top on the clay's head-top row + dy). The along-axis foreshortening
          is kept within 0.92-1.08 (a lean, not a squash) and is 1 in death (rigid).
  head    the hood with the shadowed face and the two violet eyes is its own skin bone (wcape B weight, feathered), so the
          hit can snap the head back about the neck; otherwise it rides on the body and faces the facing (S down-right,
          E up-right), which is the strike direction.
  cloak   two panels with lag (wcape R / G), skinned on the body mesh: the upper turns about the shoulders, the lower about
          the hip line; each is an exponential follower of the torso angle plus a trail of the pelvis velocity, clamped to
          +-10 deg (beyond that the mesh shears the tatters). Death: the panels turn down onto the ground with the body
          and lie flat beside him - rotations only, the cloak is never squashed.
  legs    the walk's painted legs (leg_F / legfar_F, grig.mesh, 3-bone skin); feet on the blockout heel / toe, pinned at
          the heel, so a planted foot only moves when the blockout foot moves; knee by 2-bone IK at the painted lengths
          (stance_kmin <= k <= stretch_max, the walk's limits).
  arms    two rigid painted pieces per arm (upper sleeve; bracer + fist + curved dagger as one piece), FK from the painted
          shoulder on the body. Each bone keeps its painted length times the blockout's projected length change, clamped
          to +-15 %. At rest it turns by the blockout bone's change since idle f00 (idle keeps the painting); once the arm
          key leaves the stance it lies on the blockout bone's own screen direction, so the raised cross and the slash
          point where the blockout points (along the facing). A bone turned more than RAISE_FLIP deg from its painting is
          drawn reflected across its own axis (the raised key), so its lit edge stays toward the light instead of being lit
          from below. The near hood cloak (cover_F) is drawn again over each arm root.
  death   the lying-down key: the body is turned rigidly (no squash) from the blockout fall onto the ground, finishing at
          LIE_DEG, and the daggers drop flat beside the hands. The whole figure is lifted only as far as it needs to stay
          in the cell, and only from the frame where the blockout moves the feet.
Render at RS x the cell on a padded canvas (every pixel that would fall outside the cell is counted), area-downsample,
binary alpha, black under alpha 0.
usage: garig.py [--only SE] [--acts idle,attack,skill,hit,death] [--frames 0,6] [--out DIR] [--rs 3] [--gif]"""
import os, sys, json, math, argparse, numpy as np, cv2
from PIL import Image, ImageOps
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import gwalk
G = gwalk.grig
AP = os.environ.get('GAPARTS', os.path.join(HERE, '..', 'parts'))
BLK = os.environ.get('GABLOCK', os.path.join(HERE, '..', 'blockout'))
CW, CH, PIV, FPS = 512, 360, (256, 329), 17.144
PADT, PADB, PADX = 120, 160, 80
ACTS = {'idle': 12, 'attack': 12, 'skill': 12, 'hit': 8, 'death': 13}
LOOP = {'idle', 'attack', 'skill', 'hit'}
JA = json.load(open(f'{BLK}/joints_actions_512.json')); JF = JA['facings']
GJ = {F: json.load(open(f'{AP}/gjoints_{F}.json')) for F in 'SE'}
LR = G.RIG                                         # the walk's leg rig (target px)
CFG = {F: dict(s=G.CFG[F]['s'], dy=G.CFG[F]['dy'], len_clamp=(0.85, 1.15), axis_k=(0.92, 1.08),
               cape_lag=(0.35, 0.65), cape_trail=(0.25, 0.55), cape_follow=0.45, idle_sway=(0.6, 1.4),
               death_fold_rot=(0.0, -20.0) if F == 'S' else (0.0, -25.0),
               hit_tilt=23.0, head_snap=(-13.0 if F == 'S' else -12.0)) for F in 'SE'}
for F_ in 'SE': CFG[F_].update({k: G.CFG[F_][k] for k in ('foot_o', 'foot_k', 'stretch_max', 'stance_kmin', 'far_dark', 'reach')})
CAPE_MAX = 10.0
KEY_BLEND = 30.0
RAISE_FLIP = 100.0
LIE_DEG = {'S': 55.0, 'E': -64.0}                  # final body angle of the lying key: along the blockout body line on the iso ground (aimfix ends at +55 / -62)

def fr(F, act, i): return JF[f'{act}_{F}'][f'f{i:02d}']
def jt(F, act, i, k): return np.array(fr(F, act, i)['joints'][k], float)
def ang(v): return math.atan2(v[1], v[0])
def R2(a): c, s_ = math.cos(a), math.sin(a); return np.array([[c, -s_], [s_, c]])
def unit(v): v = np.asarray(v, float); return v / max(float(np.hypot(*v)), 1e-9)
def apm(M, p): return M[:, :2] @ np.asarray(p, float) + M[:, 2]
def wrap(a): return (a + math.pi) % (2 * math.pi) - math.pi
def ss(t): t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)
def rot_about(M, p, a): Rr = R2(a); return np.hstack([Rr @ M[:, :2], (Rr @ (M[:, 2] - p) + p)[:, None]])

def sim(a, b, A, B, s_across, flip=False):
    """source segment a->b onto A->B: along scale |AB|/|ab|, across scale s_across (negative = reflected across the bone)."""
    u = unit(np.subtract(b, a)); n = np.array([-u[1], u[0]]); v = unit(np.subtract(B, A)); m = np.array([-v[1], v[0]])
    k = math.dist(A, B) / math.dist(a, b); L = np.outer(v, u) * k + np.outer(m, n) * s_across * (-1 if flip else 1)
    return np.hstack([L, (np.asarray(A, float) - L @ np.asarray(a, float))[:, None]])

# ------------------------------------------------------------------ textures / mesh warp
TEX = {}
def ptex(path):
    if path not in TEX:
        im = np.asarray(Image.open(path).convert('RGBA')).astype(np.float32) / 255.
        TEX[path] = np.dstack([im[..., :3] * im[..., 3:], im[..., 3:]])
    return TEX[path]
def atex(name): return ptex(f'{AP}/{name}.png')

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
        A = np.maximum(atex(f'body_{F}')[..., 3], atex(f'front_{F}')[..., 3]); V, tris = grid_mesh(A, 4)
        wc = np.asarray(Image.open(f'{AP}/wcape_{F}.png').convert('RGB')).astype(np.float32) / 255.
        xi = np.clip(V[:, 0].astype(int), 0, 1279); yi = np.clip(V[:, 1].astype(int), 0, 719)
        wu, wl, wh = wc[yi, xi, 0], wc[yi, xi, 1], wc[yi, xi, 2]
        W = np.stack([np.clip(1 - wu - wl - wh, 0, 1), wu, wl, wh], 1); W /= W.sum(1, keepdims=True)
        on = cv2.dilate((A > 0.5).astype(np.uint8), np.ones((3, 3), np.uint8))[yi, xi] > 0      # vertices on paint
        _MESH[F] = (V, tris, W, on)
    return _MESH[F]

class Canvas:
    """cell px -> canvas px: (x + PADX, y + PADT) * RS"""
    def __init__(self, RS): self.RS = RS; self.H = (CH + PADT + PADB) * RS; self.W = (CW + 2 * PADX) * RS
    def pts(self, P): return (np.asarray(P, float) + np.array([PADX, PADT])) * self.RS
    def M(self, M):
        o = np.array([PADX, PADT], float); return np.hstack([M[:, :2] * self.RS, ((M[:, 2] + o) * self.RS)[:, None]]).astype(np.float32)
    def affine(self, name, M):
        return cv2.warpAffine(atex(name), self.M(M), (self.W, self.H), flags=cv2.INTER_LINEAR, borderValue=0)

# ------------------------------------------------------------------ body
_CT = {}
def clay_top(F, act, i):
    if (F, act, i) not in _CT:
        a = np.asarray(Image.open(f'{BLK}/clay/gloam_{act}_{F}_f{i:02d}.png').convert('RGBA'))[..., 3] > 127
        _CT[(F, act, i)] = int(np.nonzero(a[:, 200:312].any(1))[0].min())
    return _CT[(F, act, i)]

def hc_t(F): return (np.array(LR[F]['hips']['near'], float) + np.array(LR[F]['hips']['far'], float)) / 2

def placement0(F):
    """idle f00 = the walk rule (grig.body_T): x of the painted hip centre on the blockout hip centre, hood top on the
    clay's head-top row + dy."""
    c = CFG[F]; s = c['s']; hb = (jt(F, 'idle', 0, 'L_hip') + jt(F, 'idle', 0, 'R_hip')) / 2
    return np.array([[s, 0, hb[0] - s * hc_t(F)[0]], [0, s, clay_top(F, 'idle', 0) - s * LR[F]['top'] + c['dy']]], float)

def torso_axis(F, act, i): return jt(F, act, i, 'neck') - jt(F, act, i, 'pelvis')

def raw_phi(F, act, i):
    u0 = torso_axis(F, 'idle', 0); ui = torso_axis(F, act, i); return wrap(ang(ui) - ang(u0)), np.linalg.norm(ui) / np.linalg.norm(u0)

def body_phi(F, act, i):
    """the painted body angle: the blockout's, with the hit recoil brought to hit_tilt at its peak and the death fall
    carried on to the lying key LIE_DEG."""
    phi, k = raw_phi(F, act, i)
    if act == 'hit':
        pk = max(abs(raw_phi(F, act, j)[0]) for j in range(ACTS['hit']))
        phi *= max(1.0, math.radians(CFG[F]['hit_tilt']) / pk)
    if act == 'death':
        p_end = raw_phi(F, act, ACTS['death'] - 1)[0]; t = ss((i - 5) / 6.0)
        phi = phi + t * (math.radians(LIE_DEG[F]) - p_end) * (abs(phi) / max(abs(p_end), 1e-6))
        k = 1.0
    return phi, k

def torso_M(F, act, i):
    c = CFG[F]; s = c['s']; M0 = placement0(F); h = hc_t(F)
    phi, kraw = body_phi(F, act, i); k = float(np.clip(kraw, *c['axis_k'])) if act != 'death' else 1.0
    e = unit(torso_axis(F, 'idle', 0)); Sx = np.eye(2) + (k - 1) * np.outer(e, e); A = R2(phi) @ Sx * s
    d0 = apm(M0, h) - jt(F, 'idle', 0, 'pelvis')
    piv = jt(F, act, i, 'pelvis') + R2(phi) @ (Sx @ d0)
    return np.hstack([A, (piv - A @ h)[:, None]]), dict(phi=math.degrees(phi), k=k, phi_blockout=math.degrees(raw_phi(F, act, i)[0]))

def head_angle(F, act, i):
    """hit: the head snaps back (CFG head_snap at f01-f02, out by f05), on top of the body recoil."""
    if act != 'hit': return 0.0
    w = {1: 0.8, 2: 1.0, 3: 0.55, 4: 0.2}.get(i, 0.0); return math.radians(CFG[F]['head_snap']) * w

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
    out = [o - o[0] for o in out]
    lim = math.radians(CAPE_MAX); return [np.clip(o, -lim, lim) for o in out]

FLOOR = 356.0
def cape_floor(F, act, i):
    """the lowest row the cloak may reach: the cell bottom (with a 3 px margin); lying down, the ground under the body
    (the lowest blockout heel / toe + 4 px), so the cloak lies on the ground instead of hanging below it."""
    if act == 'death' and lie_w(F, act, i) > 0.05:
        g = max(jt(F, act, i, f'{sd}_{k}')[1] for sd in 'RL' for k in ('heel', 'toe')) + 4.0
        return min(FLOOR, g * lie_w(F, act, i) + FLOOR * (1 - lie_w(F, act, i)))
    return FLOOR

KEEP_MAX = 25.0
def cape_keep_in(F, act, i, Mt, Mu, Ml, Mh, pu, hinge_t):
    """if the long cloak would leave the cell (or, lying, hang below the ground), the lower panel swings about its hinge
    by the smallest angle (at most KEEP_MAX) that keeps the painted hem above the floor: the cloak lags the recoil / lies
    along the ground. A rotation only (no squash); the upper panel is untouched, so the bend spreads over the whole
    feathered hip band. Returns the panel maps and the extra angle (deg)."""
    V, tris, W, on = body_mesh(F); fl = cape_floor(F, act, i); hc = apm(Mu, hinge_t)
    def low(ml): return float(lbs(V[on], W[on], (Mt, Mu, ml, Mh))[:, 1].max())
    if low(Ml) <= fl: return Mu, Ml, 0.0
    best = (low(Ml), Ml, 0.0)
    for d in np.arange(1.0, KEEP_MAX + 0.5, 1.0):
        for sg in (1.0, -1.0):
            ml = rot_about(Ml, hc, math.radians(d * sg)); lo = low(ml)
            if lo <= fl: return Mu, ml, d * sg
            if lo < best[0]: best = (lo, ml, d * sg)
    return Mu, best[1], best[2]

# ------------------------------------------------------------------ legs (the walk's painted legs, walk rules)
def leg_pose(F, act, i, sd, Mt):
    c = CFG[F]; s = c['s']; R = LR[F]
    H, K, A = (np.array(R[k], float) for k in ('H', 'K', 'A'))
    hv = (jt(F, act, i, 'L_hip') - jt(F, act, i, 'R_hip')) / 2
    hip = apm(Mt, hc_t(F)) + (hv if sd == 'L' else -hv)
    he_d, to_d = jt(F, act, i, sd + '_heel'), jt(F, act, i, sd + '_toe'); he_s, to_s = np.array(R['heel'], float), np.array(R['toe'], float)
    kf = float(np.clip(math.dist(he_d, to_d) / (s * math.dist(he_s, to_s)), *c['foot_k']))
    u = unit(to_s - he_s); n = np.array([-u[1], u[0]]); v = unit(to_d - he_d); m = np.array([-v[1], v[0]])
    L = np.outer(v, u) * s * kf + np.outer(m, n) * s
    Mf = np.hstack([L, (he_d - L @ he_s)[:, None]]); Mf[:, 2] += np.array(c['foot_o'], float)
    an = apm(Mf, A); Lt0, Ls0 = s * math.dist(H, K), s * math.dist(K, A); D = math.dist(hip, an)
    k = max(D / (c['reach'] * (Lt0 + Ls0)), c['stance_kmin']); kc = min(k, c['stretch_max']); pull = 0.0
    if k > kc:
        an2 = hip + unit(an - hip) * (Lt0 + Ls0) * kc * c['reach']; Mf = Mf.copy(); Mf[:, 2] += an2 - an; pull = math.dist(an2, an); an = an2
    kn = G.ik_knee(hip, an, Lt0 * kc, Ls0 * kc, jt(F, act, i, sd + '_knee'))
    return dict(Mt=G.bone_M(H, K, hip, kn, s), Ms=G.bone_M(K, A, kn, an, s), Mf=Mf, hip=hip, knee=kn, ankle=an,
                heel=apm(Mf, R['heel']), toe=apm(Mf, R['toe']), k=kc, pull=pull)

def near_leg(F, act, i):
    o = fr(F, act, i)['draw_order']; return 'L' if o.index('L_boot') < o.index('R_boot') else 'R'

# ------------------------------------------------------------------ arms (FK on the painted shoulder)
def key_w(F, act, i, sd):
    a0 = fr(F, 'idle', 0)['key']['arms'][sd]; ai = fr(F, act, i)['key']['arms'][sd]
    return float(ss(sum(abs(x - y) for x, y in zip(ai, a0)) / KEY_BLEND))

def turn(a_paint, a_b0, a_bi, w):
    rel = wrap(a_bi - a_b0); absl = wrap(a_bi - a_paint); return wrap(rel + w * wrap(absl - rel))

def lie_w(F, act, i): return float(ss(abs(torso_M(F, act, i)[1]['phi']) / 60.0)) if act == 'death' else 0.0

_HULL = {}
def hull(name):
    if name not in _HULL:
        al = np.asarray(Image.open(f'{AP}/{name}.png'))[..., 3] > 127; ys, xs = np.nonzero(al)
        _HULL[name] = cv2.convexHull(np.stack([xs, ys], 1).astype(np.float32))[:, 0].astype(float)
    return _HULL[name]

ARM_BOX = (3.0, 3.0, CW - 4.0, 356.0)
def arm_pose(F, act, i, sd, Mt, Mhead=None):
    """FK on the painted shoulder (see the module notes). If the dagger or fist would leave the cell, the whole arm turns
    about the shoulder by the smallest angle that keeps it inside (keep_deg)."""
    c = CFG[F]; s = c['s']; Jp = GJ[F]['arms'][sd]
    sh = apm(Mt, Jp['shoulder']); b = lambda a, ii, k: jt(F, a, ii, f'{sd}_{k}')
    w = key_w(F, act, i, sd); lw = lie_w(F, act, i); bones = []
    for ja, jb in (('shoulder', 'elbow'), ('elbow', 'hand')):
        v0 = s * (np.array(Jp[jb], float) - np.array(Jp[ja], float))
        b0 = b('idle', 0, jb) - b('idle', 0, ja); bi = b(act, i, jb) - b(act, i, ja)
        kraw = np.linalg.norm(bi) / max(np.linalg.norm(b0), 1e-6); k = float(np.clip(kraw, *c['len_clamp']))
        a = turn(ang(v0), ang(b0), ang(bi), w)
        if lw > 0:     # lying: the arm flattens onto the ground (turned toward the ground line, painted length kept)
            d = R2(a) @ v0; d2 = np.array([d[0], d[1] * (1 - 0.6 * lw)]); a = ang(d2) - ang(v0)
        bones.append((jb, v0, a, k))
    def chain(delta):
        out = dict(sh=sh); prev = sh; rots = []
        for jb, v0, a, k in bones:
            nxt = prev + R2(a + delta) @ v0 * k; out[jb] = nxt; prev = nxt; rots.append(math.degrees(wrap(a + delta)))
        fl = [abs(r) > RAISE_FLIP for r in rots]
        out['Mu'] = sim(Jp['shoulder'], Jp['elbow'], out['sh'], out['elbow'], s, fl[0])
        out['Mf'] = sim(Jp['elbow'], Jp['hand'], out['elbow'], out['hand'], s, fl[1])
        out.update(rot=rots, flip=fl, k=[bn[3] for bn in bones], w=w)
        P = np.vstack([apm(out['Mf'], p) for p in hull(f'fore_{sd}_{F}')])
        x0, y0, x1, y1 = ARM_BOX
        out['_out'] = float(max(0, x0 - P[:, 0].min(), P[:, 0].max() - x1, y0 - P[:, 1].min(), P[:, 1].max() - y1))
        return out
    out = chain(0.0); kd = 0.0
    if out['_out'] > 0:
        for d in np.arange(1.0, 121.0, 1.0):
            cand = [chain(math.radians(d * sg)) for sg in (1.0, -1.0)]; ok = [o for o in cand if o['_out'] == 0]
            if ok: out = ok[0]; kd = d if ok[0] is cand[0] else -d; break
    out['keep_deg'] = kd
    out['tip'] = apm(out['Mf'], Jp['tip']); out['grip'] = apm(out['Mf'], Jp['grip'])
    return out

def behind(F, act, i, part, ref='torso', margin=0.0):
    d = fr(F, act, i)['depth']; return d.get(part, -1e9) > d.get(ref, 0) + margin

# ------------------------------------------------------------------ frame
CAPE = {}
def render(F, act, i, RS=3):
    c = CFG[F]; cv = Canvas(RS); GJF = GJ[F]
    Mt, tinfo = torso_M(F, act, i)
    au, al_ = CAPE.setdefault((F, act), cape_angles(F, act)); au, al_ = au[i], al_[i]
    pu = apm(Mt, GJF['cape_upper']); hinge_t = (GJF['cape_upper'][0], sum(GJF['cape_lower_y']) / 2)
    Mu = rot_about(Mt, pu, au); Ml = rot_about(Mu, apm(Mu, hinge_t), al_)
    fold = 0.0
    if act == 'death':
        # lying down: the cloak lies flat on the ground beside him. The panels turn on down to the ground with the body
        # (death_fold_rot, toward his feet), as rotations only: nothing is squashed, the tatters keep their painted shape
        fold = lie_w(F, act, i); fr_ = c['death_fold_rot']
        Mu = rot_about(Mu, pu, math.radians(fr_[0]) * fold); Ml = rot_about(Ml, pu, math.radians(fr_[0]) * fold)
        Ml = rot_about(Ml, apm(Mu, hinge_t), math.radians(fr_[1]) * fold)
    neck = apm(Mt, GJF['neck']); ha = head_angle(F, act, i); Mh = rot_about(Mt, neck, ha)
    if ha: Mh = Mh.copy(); Mh[:, 2] += R2(math.radians(tinfo['phi'])) @ np.array([-1.5, 0.5]) * (abs(ha) / math.radians(12))
    V, tris, W, on = body_mesh(F)
    Mu, Ml, keep = cape_keep_in(F, act, i, Mt, Mu, Ml, Mh, pu, hinge_t)
    Vd = lbs(V, W, (Mt, Mu, Ml, Mh))
    body, maps = warp(atex(f'body_{F}'), V, cv.pts(Vd), tris, cv.H, cv.W)
    front = remap_with(atex(f'front_{F}'), maps); cover = remap_with(atex(f'cover_{F}'), maps)
    meta = dict(torso=tinfo, cape=[math.degrees(au), math.degrees(al_)], cape_fold=fold, head_snap_deg=math.degrees(ha), cape_keep_in_deg=keep)
    # legs
    legs = {sd: leg_pose(F, act, i, sd, Mt) for sd in 'RL'}; nr = near_leg(F, act, i); leg_imgs = []
    legs_a = np.zeros((cv.H, cv.W), np.float32)
    for sd in [x for x in 'RL' if x != nr] + [nr]:
        P = legs[sd]; name = G.tname(F, sd)
        Vl, tl, Wl = G.mesh(F, name)
        Ld, _ = warp(G.tex(name), Vl, cv.pts(lbs(Vl, Wl, (P['Mt'], P['Ms'], P['Mf']))), tl, cv.H, cv.W)
        if sd != nr: Ld[..., :3] *= c['far_dark']
        legs_a = np.maximum(legs_a, Ld[..., 3]); leg_imgs.append(Ld)
        meta[sd] = {k: (v.tolist() if isinstance(v, np.ndarray) and v.ndim == 1 else v) for k, v in P.items() if not k.startswith('M')}
    # arms
    arms = {sd: arm_pose(F, act, i, sd, Mt) for sd in 'RL'}; arm_img = {}
    for sd in 'RL':
        P = arms[sd]
        arm_img[sd] = over(cv.affine(f'uarm_{sd}_{F}', P['Mu']), cv.affine(f'fore_{sd}_{F}', P['Mf']))
        meta['arm_' + sd] = dict(sh=P['sh'].tolist(), el=P['elbow'].tolist(), hand=P['hand'].tolist(), tip=P['tip'].tolist(),
                                 k=P['k'], rot=P['rot'], flip=P['flip'], w=P['w'], keep_deg=P['keep_deg'])
    back = {sd: behind(F, act, i, f'{sd}_farm', 'torso', 0.0) and behind(F, act, i, f'{sd}_uarm', 'torso', -5.0) for sd in 'RL'}
    if F == 'E': back['L'] = back['L'] or arms['L']['w'] < 0.5         # the hidden left arm stays under the cloak at rest
    meta['arm_back'] = back
    # ---- composite, back to front (walk orders: S back, legs, front; E legs, back, front)
    img = np.zeros((cv.H, cv.W, 4), np.float32)
    order = [arm_img[sd] for sd in 'LR' if back[sd]]
    order += ([body] + leg_imgs + [front]) if F == 'S' else (leg_imgs + [body, front])
    fronts = [sd for sd in ('R', 'L') if not back[sd]]
    if F == 'S': fronts = sorted(fronts, key=lambda sd: -fr(F, act, i)['depth'].get(f'{sd}_farm', 0))
    else: fronts = sorted(fronts, key=lambda sd: -fr(F, act, i)['depth'].get(f'{sd}_farm', 0))
    order += [arm_img[sd] for sd in fronts]
    if fronts: order += [cover]
    for L_ in order: img = over(img, L_)
    if act != 'death' and G.CFG[F].get('crotch_fill'):
        kn_y = min(meta['R']['knee'][1], meta['L']['knee'][1])
        sub = img[PADT * RS:(PADT + CH) * RS, PADX * RS:(PADX + CW) * RS]; la = np.ascontiguousarray(legs_a[PADT * RS:(PADT + CH) * RS, PADX * RS:(PADX + CW) * RS])
        sub2 = np.ascontiguousarray(sub); meta['crotch_fill_px'] = G.close_crotch(F, sub2, la, kn_y, RS); sub[:] = sub2
    return img, meta, cv

def bottom_need(img, cv):
    a = img[..., 3] > 0.5; ys = np.nonzero(a.any(1))[0]
    return max(0, int(math.ceil(ys.max() / cv.RS)) - (PADT + CH - 2)) if len(ys) else 0

def death_shifts(F):
    """smallest lift that keeps every death frame inside the cell (lowest row <= 358), never decreasing, eased (at most
    3 px per frame), starting no earlier than the frame where the blockout first moves the feet."""
    n = ACTS['death']; need = []
    for i in range(n):
        img, _, cv = render(F, 'death', i, 1); need.append(bottom_need(img, cv))
    first = next(i for i in range(1, n) if any(np.abs(jt(F, 'death', i, f'{sd}_{k}') - jt(F, 'death', 0, f'{sd}_{k}')).max() > 0.25
                                              for sd in 'RL' for k in ('heel', 'toe')))
    sh = np.maximum.accumulate(np.array(need, float))
    for j in range(n - 2, first - 1, -1): sh[j] = max(sh[j], sh[j + 1] - 3)
    sh[:first] = 0
    return [int(v) for v in sh]

def lift(img, k):
    if k <= 0: return img
    return np.concatenate([img[k:], np.zeros((k,) + img.shape[1:], np.float32)], 0)

def to_cell(img, cv, F):
    RS = cv.RS; sm = cv2.resize(img, (img.shape[1] // RS, img.shape[0] // RS), interpolation=cv2.INTER_AREA)
    a = sm[..., 3]; m = a > 0.5
    lost = dict(top=int(m[:PADT].sum()), bottom=int(m[PADT + CH:].sum()), left=int(m[PADT:PADT + CH, :PADX].sum()), right=int(m[PADT:PADT + CH, PADX + CW:].sum()))
    sm = np.ascontiguousarray(sm[PADT:PADT + CH, PADX:PADX + CW])
    out = G.to_cell(sm, 1, F)                      # the walk's binarise + see-through speck fill
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
    ap.add_argument('--acts', default=','.join(ACTS)); ap.add_argument('--frames', default=None); ap.add_argument('--rs', type=int, default=3)
    ap.add_argument('--gif', action='store_true')
    a = ap.parse_args(); os.makedirs(a.out, exist_ok=True)
    infop = os.path.join(a.out, '_build_info.json'); info = json.load(open(infop)).get('frames', {}) if os.path.exists(infop) else {}
    for F in a.only:
        for act in a.acts.split(','):
            n = ACTS[act]; fl = [int(x) for x in a.frames.split(',')] if a.frames else range(n)
            shifts = death_shifts(F) if act == 'death' else [0] * n
            for i in fl:
                img, meta, cv = render(F, act, i, a.rs); img = lift(img, shifts[i] * a.rs); meta['lift_px'] = shifts[i]
                cell, lost = to_cell(img, cv, F); meta['lost_px_outside_cell'] = lost
                if shifts[i]:
                    for sd in 'RL':
                        for k in ('heel', 'toe', 'hip', 'knee', 'ankle'): meta[sd][k] = [meta[sd][k][0], meta[sd][k][1] - shifts[i]]
                Image.fromarray(cell).save(f'{a.out}/{act}_{F}_f{i:02d}.png')
                info.setdefault(F, {}).setdefault(act, {})[f'f{i:02d}'] = meta
                print(F, act, i, 'phi %.1f k %.2f' % (meta['torso']['phi'], meta['torso']['k']),
                      'legk %.3f %.3f pull %.1f %.1f' % (meta['R']['k'], meta['L']['k'], meta['R']['pull'], meta['L']['pull']),
                      'armk R %.2f %.2f L %.2f %.2f' % (*meta['arm_R']['k'], *meta['arm_L']['k']), 'flip', meta['arm_R']['flip'], meta['arm_L']['flip'],
                      'back', meta['arm_back'], 'lift', meta['lift_px'], 'lost', {k: v for k, v in lost.items() if v}, flush=True)
            if a.gif and not a.frames:
                os.makedirs(os.path.join(a.out, '..', 'gifs'), exist_ok=True)
                gif([f'{a.out}/{act}_{F}_f{i:02d}.png' for i in range(n)], os.path.join(a.out, '..', 'gifs', f'{act}_{F}.gif'),
                    hold_last=600 if act == 'death' else 0)
    json.dump(dict(cfg=CFG, frames=info), open(infop, 'w'), indent=1, default=float)
