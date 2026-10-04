"""Ironjaw actions v1 - the painted-part rig for idle, attack (Strike), skill (Shoulder), hit and death, S and E
(W and N are game-side mirrors). Same method as the LOCKED Kestrel and Bastion actions (barig.py), on the parts of his
current painted walk (ironjaw_walk v7, cut by ijcut.py), bent onto the action blockout (act_blockout.py, aimfix).

Per frame:
  body    one similarity: the walk's scale s (S 0.3884, E 0.4190, the walk f00 fit) plus rotation and along-axis
          foreshortening from the change of the blockout pelvis->neck axis since idle f00, pinned at the painted pelvis,
          which follows the blockout pelvis. Idle f00 = the walk f00 placement moved onto the idle pelvis (x) with the
          helm top on row 64, the approved idle set's height.
  head    the walk's painted helm, rigid on the body, turned about the painted neck by the blockout head's change
          relative to the torso (hit head snap, idle nod, death roll). It always faces the action direction: S down-right,
          E up-right (it is the walk's helm).
  cape    its own mesh, three-bone skin (torso, upper panel, lower panel; wcape weights, feathered past the ragged hem so
          the tatters never shear), panels lag the torso angle and trail the pelvis. S behind him, E over his back.
  arms    per arm: pauldron rigid on the body (redrawn over the arm root), upper arm (rerebrace) and ONE rigid piece
          vambrace + fist + axe (the fist stays closed on the haft as painted). FK from the painted shoulder: at rest each
          bone turns by the blockout bone's change since idle f00 (idle keeps the painting); once the arm key leaves the
          stance (30 deg of key change) the bone lies on the blockout bone's own screen direction, so raised and striking
          arms are the painted pieces turned (never a stretched hanging arm). Upper arm length follows the blockout's
          projected length change clamped to +-15 %; the forearm + axe piece is never stretched (k 1.00).
  legs    the walk's painted thigh / shin / boot pieces (graded to the walk legs): boot rigid on the blockout heel->toe
          (turns by its change since idle f00, idle = his idle foot placement), ankle = the boot's painted ankle point,
          knee by 2-bone IK at the idle leg lengths (k 1.00, up to 1.10 only when out of reach).
  death   the lying-down key: everything that lies on the ground flattens on screen (y x 0.65 at full lie), the cape lies
          under / over him, the arms lie spread on the ground with the axes still in the fists.
Draw order follows the walk (S: cape, far arm, far leg, near leg, body, head, near arm; E: legs, body, cape, arms) and
the blockout depth decides when an arm passes in front of / behind the body.
Clean-up per frame: binary alpha, black under alpha 0, no speckle islands, pin holes inside the figure closed and the
dark halo pixels on the silhouette edge re-coloured from the paint just inside (the walk frames have both).
usage: ijrig.py [--only SE] [--acts ...] [--frames 0,6] [--out DIR] [--gif]"""
import os, sys, json, math, argparse
import numpy as np, cv2
from PIL import Image
from scipy import ndimage as ndi
HERE = os.path.dirname(os.path.abspath(__file__))
AP = os.environ.get('IJPARTS', os.path.join(HERE, '..', 'parts'))
BLK = os.environ.get('IJBLOCK', os.path.join(HERE, '..', 'blockout'))
CW, CH, PIV, FPS = 512, 360, (256, 329), 17.144
PADT, PADB, PADX = 140, 160, 120
ACTS = {'idle': 12, 'attack': 12, 'skill': 12, 'hit': 8, 'death': 13}
LOOP = {'idle', 'attack', 'skill', 'hit'}
JF = json.load(open(f'{BLK}/joints_actions_512.json'))['facings']
WF = json.load(open(f'{BLK}/walk_fit.json'))
TAJ = json.load(open(f'{BLK}/ta_idle_joints.json'))
PJ = {F: json.load(open(f'{AP}/ijoints_{F}.json')) for F in 'SE'}
IDLE_TOP = 64                     # approved idle set: helm top row (hd_set_idle, all facings)
CFG = {
 'S': dict(s=WF['S']['s'], near='R', far='L', thigh_share=0.44, straight=0.97, len_clamp=(0.85, 1.15), leg_smax=1.10,
           cape_lag=(0.35, 0.65), cape_trail=(0.25, 0.55), cape_follow=0.5, cape_hang=(0.6, 0.5), idle_sway=(0.5, 1.2), cape_lie_k=0.6, cape_front=False),
 'E': dict(s=WF['E']['s'], near='L', far='R', thigh_share=0.40, straight=0.97, len_clamp=(0.85, 1.15), leg_smax=1.10,
           cape_lag=(0.35, 0.65), cape_trail=(0.25, 0.55), cape_follow=0.5, cape_hang=(0.35, 0.3), idle_sway=(0.5, 1.2), cape_lie_k=0.9, cape_front=True),
}

def fr(F, act, i): return JF[f'{act}_{F}'][f'f{i:02d}']
def jt(F, act, i, k): return np.array(fr(F, act, i)['joints'][k], float)
def ang(v): return math.atan2(v[1], v[0])
def R2(a): c, s_ = math.cos(a), math.sin(a); return np.array([[c, -s_], [s_, c]])
def unit(v): v = np.asarray(v, float); return v / max(float(np.hypot(*v)), 1e-9)
def apm(M, p): return M[:, :2] @ np.asarray(p, float) + M[:, 2]
def wrap(a): return (a + math.pi) % (2 * math.pi) - math.pi
def ss(t): t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)
def H3(M): return np.vstack([M, [0, 0, 1]])
def rot_about(M, p, a): Rr = R2(a); return np.hstack([Rr @ M[:, :2], (Rr @ (M[:, 2] - p) + p)[:, None]])
def squash_about(M, p, d, k): S = np.eye(2) + (k - 1) * np.outer(d, d); return np.hstack([S @ M[:, :2], (S @ (M[:, 2] - p) + p)[:, None]])

def sim(a, b, A, B, s_across):
    """source segment a->b onto A->B: along scale |AB|/|ab|, across scale s_across, a -> A."""
    u = unit(np.subtract(b, a)); n = np.array([-u[1], u[0]]); v = unit(np.subtract(B, A)); m = np.array([-v[1], v[0]])
    k = math.dist(A, B) / math.dist(a, b); L = np.outer(v, u) * k + np.outer(m, n) * s_across
    return np.hstack([L, (np.asarray(A, float) - L @ np.asarray(a, float))[:, None]])

def rigid(a, b, A, B, s):
    """source segment a->b turned onto the direction A->B, scale s (no stretch), a -> A."""
    th = ang(np.subtract(B, A)) - ang(np.subtract(b, a)); L = R2(th) * s
    return np.hstack([L, (np.asarray(A, float) - L @ np.asarray(a, float))[:, None]])

def ik_knee(hip, ank, L1, L2, sg):
    d = np.subtract(ank, hip); D = float(np.hypot(*d)); D = min(D, L1 + L2 - 1e-4); u = unit(d); n = np.array([-u[1], u[0]])
    a = (L1 * L1 - L2 * L2 + D * D) / (2 * D); h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    return np.asarray(hip, float) + u * a + n * h * sg

# ------------------------------------------------------------------ textures (premultiplied float, pre-scaled to the cell)
TEX = {}
def unit_of(name):
    """target px per part px (1 for the target-cut parts; the leg pieces carry their own scale)."""
    return 1.0             # every part, the leg pieces too, is stored in target px (ijcut.py resamples the legs)

def ptex(name):
    """the part pre-scaled to the cell with a premultiplied Lanczos resize (as the walk), so a frame is sampled at the
    cell like the walk and idle f00 keeps the walk's sharpness. Returns (premult float RGBA 0..1, pre = scaled px per part px)."""
    if name not in TEX:
        im = np.asarray(Image.open(f'{AP}/{name}.png').convert('RGBA')).astype(np.float32)
        s = CFG[name[-1]]['s'] * unit_of(name)
        a = im[..., 3:4] / 255.0; pm = np.concatenate([im[..., :3] * a, a * 255.0], -1)
        h, w = im.shape[:2]; nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
        out = np.stack([np.asarray(Image.fromarray(pm[..., c], 'F').resize((nw, nh), Image.LANCZOS)) for c in range(4)], -1) / 255.0
        TEX[name] = (np.clip(out, 0, 1).astype(np.float32), (nw / w, nh / h))
    return TEX[name]

def grid_mesh(alpha, step=4, pad=3):
    a = alpha > 0.01; ys, xs = np.nonzero(a)
    x0, x1, y0, y1 = xs.min() - step, xs.max() + step, ys.min() - step, ys.max() + step
    gx = np.arange(x0, x1 + step, step); gy = np.arange(y0, y1 + step, step)
    V = np.stack(np.meshgrid(gx, gy), -1).reshape(-1, 2).astype(np.float64); nx = len(gx)
    ad = cv2.dilate(a.astype(np.uint8), np.ones((2 * pad + 1, 2 * pad + 1), np.uint8))
    ii = [r * nx + q for r in range(len(gy) - 1) for q in range(nx - 1) if ad[max(gy[r], 0):gy[r] + step + 1, max(gx[q], 0):gx[q] + step + 1].any()]
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
    return cv2.remap(T, mapx, mapy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)

def over(dst, src): return src + dst * (1 - src[..., 3:])
def lbs(V, W, Ms): return sum(W[:, j:j + 1] * (V @ M[:, :2].T + M[:, 2]) for j, M in enumerate(Ms))

class Canvas:
    def __init__(self, RS): self.RS = RS; self.H = (CH + PADT + PADB) * RS; self.W = (CW + 2 * PADX) * RS
    def M(self, M, pre=(1.0, 1.0)):
        o = np.array([PADX, PADT], float); pre = np.asarray(pre, float)
        L = M[:, :2] @ np.diag(1 / pre); t = M[:, 2] + M[:, :2] @ (0.5 / pre - 0.5)
        return np.hstack([L * self.RS, ((t + o) * self.RS)[:, None]]).astype(np.float32)
    def pts(self, P): return (np.asarray(P, float) + np.array([PADX, PADT])) * self.RS
    def affine(self, name, M):
        """M: target px -> cell (for a leg piece: its own px are converted with unit_of)."""
        T, pre = ptex(name); u = unit_of(name)
        Mp = M @ H3(np.diag([u, u, 1.0])[:2]) if u != 1.0 else M
        return cv2.warpAffine(T, self.M(Mp, pre), (self.W, self.H), flags=cv2.INTER_LINEAR, borderValue=0)

# ------------------------------------------------------------------ body
_TOP = {}
def head_top_t(F):
    if F not in _TOP:
        a = np.asarray(Image.open(f'{AP}/head_{F}.png'))[..., 3] > 127; _TOP[F] = float(np.nonzero(a.any(1))[0].min())
    return _TOP[F]

def placement0(F):
    """idle f00: the walk f00 placement (cell = s * target + t), moved onto the idle pelvis in x, helm top on row 64."""
    s = CFG[F]['s']; t = np.array(WF[F]['t'], float)
    dx = jt(F, 'idle', 0, 'pelvis')[0] - WF[F]['walk_f00_pelvis'][0]
    tx = t[0] + dx; ty = IDLE_TOP - s * head_top_t(F)
    return np.array([[s, 0, tx], [0, s, ty]], float)

LIE_FLAT = 0.35
CAPE_MAX = 22.0
def torso_axis(F, act, i): return jt(F, act, i, 'neck') - jt(F, act, i, 'pelvis')
def lie_w(phi): return float(ss(abs(phi) / math.radians(55.0)))

def torso_M(F, act, i):
    s = CFG[F]['s']; pel_t = PJ[F]['pelvis']
    M0 = placement0(F); u0 = torso_axis(F, 'idle', 0); ui = torso_axis(F, act, i)
    phi = wrap(ang(ui) - ang(u0)); k = float(np.clip(np.linalg.norm(ui) / np.linalg.norm(u0), 0.35, 1.15))
    e = unit(u0); Sx = np.eye(2) + (k - 1) * np.outer(e, e); A = R2(phi) @ Sx * s
    d0 = apm(M0, pel_t) - jt(F, 'idle', 0, 'pelvis')
    piv = jt(F, act, i, 'pelvis') + R2(phi) @ (Sx @ d0)
    M = np.hstack([A, (piv - A @ np.asarray(pel_t, float))[:, None]]); ky = 1.0
    if act == 'death':
        ky = 1.0 - LIE_FLAT * lie_w(phi)
        M = squash_about(M, jt(F, act, i, 'pelvis'), np.array([0.0, 1.0]), ky)
    return M, dict(phi=math.degrees(phi), k=k, lie_ky=ky)

def head_M(F, act, i, Mt):
    """the helm turns about the painted neck by the blockout head's change relative to the torso."""
    def rel(a, ii): return wrap(ang(jt(F, a, ii, 'head_top') - jt(F, a, ii, 'neck')) - ang(torso_axis(F, a, ii)))
    dphi = wrap(rel(act, i) - rel('idle', 0))
    nk = apm(Mt, PJ[F]['neck'])
    return rot_about(Mt, nk, dphi), math.degrees(dphi)

def cape_angles(F, act):
    c = CFG[F]; n = ACTS[act]
    phi = np.array([torso_M(F, act, i)[1]['phi'] for i in range(n)]); pel = np.array([jt(F, act, i, 'pelvis') for i in range(n)])
    reps = 3 if act in LOOP else 1; ph = np.tile(phi, reps); pv = np.tile(pel, (reps, 1))
    vel = np.diff(pv[:, 0], prepend=pv[0, 0]) if act not in LOOP else np.diff(np.concatenate([pv[-1:, 0], pv[:, 0]]))
    out = []
    # each panel eases toward hanging (it gives back c['cape_hang'] of the torso turn: a leaning torso does not swing its
    # cape out with it) with a lag, and trails the pelvis velocity
    for lag, trail, hang in ((c['cape_lag'][0], c['cape_trail'][0], c['cape_hang'][0]), (c['cape_lag'][1], c['cape_trail'][1], c['cape_hang'][1])):
        f = ph[0]; vf = 0.0; res = []
        for j in range(len(ph)):
            f = f + (ph[j] - f) * (1 - lag); vf = vf + (vel[j] - vf) * (1 - lag)
            res.append(math.radians((f - ph[j]) * c['cape_follow'] - hang * f) + math.radians(trail * vf * 4.0))
        out.append(np.array(res[-n:]))
    if act == 'idle':
        t = np.arange(n) / n * 2 * math.pi
        out[0] = out[0] + np.radians(c['idle_sway'][0]) * np.sin(t - 0.8); out[1] = out[1] + np.radians(c['idle_sway'][1]) * np.sin(t - 1.6)
    if act == 'death':
        w = np.clip(1 - (np.arange(n) - 5) / 4, 0, 1); out = [o * w for o in out]
    out = [o - o[0] for o in out]
    lim = math.radians(CAPE_MAX)
    return [np.clip(o, -lim, lim) for o in out]

# ------------------------------------------------------------------ legs
def foot_calib(F):
    """his idle foot placement (TA idle joints, the joints the approved idle set stands on) minus the blockout idle feet:
    a constant screen offset per foot, so idle f00 stands like the approved idle and a foot moves only when the
    blockout foot moves."""
    out = {}
    for sd in 'RL':
        out[sd] = {k: np.array(TAJ[F][f'{sd}_{k}'], float) - jt(F, 'idle', 0, f'{sd}_{k}') for k in ('heel', 'toe', 'ankle')}
    return out
CAL = {F: foot_calib(F) for F in 'SE'}

def piece(F, sd, seg): return PJ[F]['legs'][f'{sd}_{seg}']
def pt(F, sd, seg, k):
    """a leg piece point in target px."""
    return np.asarray(piece(F, sd, seg)[k], float)

def foot_pose(F, act, i, sd):
    c = CFG[F]; s = c['s']; cal = CAL[F][sd]
    he = jt(F, act, i, f'{sd}_heel') + cal['heel']; to = jt(F, act, i, f'{sd}_toe') + cal['toe']
    he0 = jt(F, 'idle', 0, f'{sd}_heel') + cal['heel']; to0 = jt(F, 'idle', 0, f'{sd}_toe') + cal['toe']
    th = wrap(ang(to - he) - ang(to0 - he0))
    # idle: the boot sole centre on the foot's ground point (heel/toe mid x, lowest of the two rows)
    g0 = np.array([(he0[0] + to0[0]) / 2, max(he0[1], to0[1])]); o = g0 - (he0 + to0) / 2
    g = (he + to) / 2 + R2(th) @ o
    sole = pt(F, sd, 'boot', 'sole')
    Mb = np.hstack([R2(th) * s, (g - R2(th) * s @ sole)[:, None]])
    if act == 'death':        # a boot lying on the ground flattens with him
        phi = torso_M(F, act, i)[1]['phi']; Mb = squash_about(Mb, g, np.array([0.0, 1.0]), 1 - LIE_FLAT * lie_w(math.radians(phi)) * 0.6)
    return Mb, dict(heel=he.tolist(), toe=to.tolist(), ground=g.tolist(), turn=math.degrees(th))

_LEGL = {}
def leg_lengths(F, sd):
    """the idle leg: painted hip -> boot ankle point, nearly straight (walk rule 0.97), split thigh / shin as the walk."""
    if (F, sd) not in _LEGL:
        c = CFG[F]; Mt0, _ = torso_M(F, 'idle', 0); hip = apm(Mt0, hip_t(F, sd)); Mb, _ = foot_pose(F, 'idle', 0, sd)
        an = apm(Mb, pt(F, sd, 'boot', 'J')); tot = math.dist(hip, an) / c['straight']
        _LEGL[(F, sd)] = (c['thigh_share'] * tot, (1 - c['thigh_share']) * tot)
    return _LEGL[(F, sd)]

_HIPT = {}
def hip_t(F, sd):
    """the hip point in target px: his idle hip (TA idle joints) mapped back through the idle f00 body placement."""
    if (F, sd) not in _HIPT:
        M0 = placement0(F); _HIPT[(F, sd)] = np.linalg.solve(M0[:, :2], np.array(TAJ[F][f'{sd}_hip'], float) - M0[:, 2])
    return _HIPT[(F, sd)]

def leg_pose(F, act, i, sd, Mt):
    c = CFG[F]; s = c['s']
    hip = apm(Mt, hip_t(F, sd)); Mb, finfo = foot_pose(F, act, i, sd)
    an = apm(Mb, pt(F, sd, 'boot', 'J')); L1, L2 = leg_lengths(F, sd)
    d = math.dist(hip, an); k = float(np.clip(d / ((L1 + L2) * 0.999), 1.0, c['leg_smax']))
    # knee to the side the blockout knee is on
    hb, kb, ab = (jt(F, act, i, f'{sd}_{x}') for x in ('hip', 'knee', 'ankle'))
    u = unit(ab - hb); n = np.array([-u[1], u[0]]); sg = 1.0 if np.dot(kb - hb, n) >= 0 else -1.0
    kn = ik_knee(hip, an, L1 * k, L2 * k, sg)
    th0, th1 = pt(F, sd, 'thigh', 'P0'), pt(F, sd, 'thigh', 'P1'); sh0, sh1 = pt(F, sd, 'shin', 'P0'), pt(F, sd, 'shin', 'P1')
    Mth = sim(th0, th1, hip, kn, s); Msh = sim(sh0, sh1, kn, an, s)
    return dict(Mth=Mth, Msh=Msh, Mb=Mb, hip=hip.tolist(), knee=kn.tolist(), ankle=an.tolist(), k=k,
                short=max(0.0, d - (L1 + L2) * k), heel=finfo['heel'], toe=finfo['toe'])

# ------------------------------------------------------------------ arms
KEY_BLEND = 90.0
def key_w(F, act, i, sd):
    a0 = fr(F, 'idle', 0)['key']['arms'][sd]; ai = fr(F, act, i)['key']['arms'][sd]
    return float(ss(sum(abs(x - y) for x, y in zip(ai, a0)) / KEY_BLEND))

def turn(a_paint, a_b0, a_bi, w):
    rel = wrap(a_bi - a_b0); absl = wrap(a_bi - a_paint)
    return wrap(rel + w * wrap(absl - rel))

def arm_pose(F, act, i, sd, Mt):
    c = CFG[F]; s = c['s']; Jt = PJ[F]['arms'][sd]
    sh = apm(Mt, Jt['shoulder']); w = key_w(F, act, i, sd); b = lambda a, ii, k: jt(F, a, ii, f'{sd}_{k}')
    out = dict(sh=sh, w=w); prev = sh; ks = []
    tilt_w = lie_w(math.radians(torso_M(F, act, i)[1]['phi'])) if act == 'death' else 0.0
    for seg, (ja, jb), (pa, pb) in (('u', ('shoulder', 'elbow'), ('shoulder', 'elbow')), ('f', ('elbow', 'hand'), ('elbow', 'grip'))):
        v0 = s * (np.array(Jt[pb], float) - np.array(Jt[pa], float))
        b0 = b('idle', 0, jb) - b('idle', 0, ja); bi = b(act, i, jb) - b(act, i, ja)
        kraw = np.linalg.norm(bi) / max(np.linalg.norm(b0), 1e-6)
        k = float(np.clip(kraw, *c['len_clamp'])) if seg == 'u' else 1.0       # the forearm + axe piece is rigid
        d = R2(turn(ang(v0), ang(b0), ang(bi), w)) @ v0 * k
        if tilt_w:            # lying on the ground: flattens on screen like the body (painted length kept)
            L0 = np.linalg.norm(d); d = np.array([d[0], d[1] * (1 - 0.5 * tilt_w)]); d = d / max(np.linalg.norm(d), 1e-6) * L0
        nxt = prev + d; out[jb if seg == 'u' else 'grip'] = nxt; ks.append(k); prev = nxt
    out['k'] = ks
    out['Mu'] = sim(Jt['shoulder'], Jt['elbow'], out['sh'], out['elbow'], s)
    out['Mf'] = rigid(Jt['elbow'], Jt['grip'], out['elbow'], out['grip'], s)
    # keep the axe inside the cell: if the forearm + axe piece would cross an edge, it turns about the elbow by the smallest
    # angle that clears it (the wind-up holds the axe a little lower / the fallen axe a little closer than the blockout)
    hull = piece_hull(f'fore_{sd}_{F}'); corr = 0.0
    def bad(M_): P = np.array([apm(M_, p) for p in hull]); return (P[:, 0].min() < 2) or (P[:, 0].max() > CW - 3) or (P[:, 1].min() < 2) or (P[:, 1].max() > CH - 3)
    if bad(out['Mf']):
        for dd in np.radians(np.arange(1, 121, 1)):
            ok = [a_ for a_ in (dd, -dd) if not bad(rot_about(out['Mf'], out['elbow'], a_))]
            if ok: corr = ok[0]; break
        if corr:
            out['Mf'] = rot_about(out['Mf'], out['elbow'], corr); out['grip'] = apm(out['Mf'], Jt['grip'])
    out['edge_turn_deg'] = round(math.degrees(corr), 1)
    return out

_HULL = {}
def piece_hull(name):
    if name not in _HULL:
        a = np.asarray(Image.open(f'{AP}/{name}.png'))[..., 3] > 127; ys, xs = np.nonzero(a)
        _HULL[name] = cv2.convexHull(np.stack([xs, ys], 1).astype(np.float32))[:, 0]
    return _HULL[name]

def depth(F, act, i, part): return fr(F, act, i)['depth'].get(part, 0.0)
def arm_front(F, act, i, sd):
    """is this arm (forearm + fist + axe) in front of the body? The walk's order at rest (S: near arm in front, far arm
    behind; E: both arms over the body and cape); it flips only when the blockout moves the forearm and fist more than
    0.08 H past the torso in depth relative to idle f00 (+ = away from the camera)."""
    m = 0.08 * 305
    def dd(a, ii): return (depth(F, a, ii, f'{sd}_farm') + depth(F, a, ii, f'{sd}_hand')) / 2 - depth(F, a, ii, 'torso')
    rel = dd(act, i) - dd('idle', 0)
    rest_front = (CFG[F]['near'] == sd) if F == 'S' else True
    if rest_front: return not rel > m
    return rel < -m

# ------------------------------------------------------------------ frame
CAPE = {}
_MESH = {}
def cape_mesh(F):
    if F not in _MESH:
        V, tris = grid_mesh(np.asarray(Image.open(f'{AP}/cape_{F}.png'))[..., 3].astype(np.float32) / 255., 6)
        wc = np.asarray(Image.open(f'{AP}/wcape_{F}.png').convert('RGB')).astype(np.float32) / 255.
        xi = np.clip(V[:, 0].astype(int), 0, 1279); yi = np.clip(V[:, 1].astype(int), 0, 719)
        wu, wl = wc[yi, xi, 0], wc[yi, xi, 1]; W = np.stack([np.clip(1 - wu - wl, 0, 1), wu, wl], 1); W /= W.sum(1, keepdims=True)
        _MESH[F] = (V, tris, W)
    return _MESH[F]

def src_px(name, P):
    pre = np.array(ptex(name)[1]); return (np.asarray(P, float) + 0.5) * pre - 0.5

def render(F, act, i, RS=1):
    c = CFG[F]; cv = Canvas(RS); PJF = PJ[F]
    Mt, tinfo = torso_M(F, act, i); Mh, hdeg = head_M(F, act, i, Mt)
    au, al_ = CAPE.setdefault((F, act), cape_angles(F, act)); au, al_ = au[i], al_[i]
    pu = apm(Mt, PJF['cape_upper']); hinge_t = (PJF['cape_upper'][0], sum(PJF['cape_lower_y']) / 2)
    Mu = rot_about(Mt, pu, au); Ml = rot_about(Mu, apm(Mu, hinge_t), al_)
    if act == 'death':        # the cape lies flat under (S) / over (E) him: pulled in along the body toward its hinge
        fold = lie_w(math.radians(tinfo['phi'])); dn = unit(jt(F, act, i, 'pelvis') - jt(F, act, i, 'neck')); kk = 1 - (1 - c['cape_lie_k']) * fold
        Mu = squash_about(Mu, pu, dn, kk); Ml = squash_about(Ml, pu, dn, kk)
    V, tris, W = cape_mesh(F); Vd = lbs(V, W, (Mt, Mu, Ml))
    cape = warp(ptex(f'cape_{F}')[0], src_px(f'cape_{F}', V), cv.pts(Vd), tris, cv.H, cv.W)
    body = cv.affine(f'body_{F}', Mt); head = cv.affine(f'head_{F}', Mh)
    meta = dict(torso=tinfo, head_deg=hdeg, cape=[math.degrees(au), math.degrees(al_)])
    # legs
    legs = {sd: leg_pose(F, act, i, sd, Mt) for sd in 'RL'}; leg_img = {}
    for sd in 'RL':
        P = legs[sd]; L_ = np.zeros((cv.H, cv.W, 4), np.float32)
        for nm, M in (('boot', P['Mb']), ('shin', P['Msh']), ('thigh', P['Mth'])):
            L_ = over(L_, cv.affine(f'leg_{sd}_{nm}_{F}', M))
        leg_img[sd] = L_; meta[sd] = {k: v for k, v in P.items() if not k.startswith('M')}
    dl = {sd: depth(F, act, i, f'{sd}_shin') + depth(F, act, i, f'{sd}_boot') for sd in 'RL'}
    lorder = sorted('RL', key=lambda sd: -dl[sd])          # far leg first
    # arms
    arms = {sd: arm_pose(F, act, i, sd, Mt) for sd in 'RL'}
    aimg = {sd: [cv.affine(f'uarm_{sd}_{F}', arms[sd]['Mu']), cv.affine(f'fore_{sd}_{F}', arms[sd]['Mf'])] for sd in 'RL'}
    paul = {sd: cv.affine(f'pauld_{sd}_{F}', Mt) for sd in 'RL'}
    for sd in 'RL': meta['arm_' + sd] = dict(sh=arms[sd]['sh'].tolist(), el=arms[sd]['elbow'].tolist(), grip=arms[sd]['grip'].tolist(), k=arms[sd]['k'], w=arms[sd]['w'], edge_turn_deg=arms[sd]['edge_turn_deg'])
    front = {sd: arm_front(F, act, i, sd) for sd in 'RL'}; meta['arm_front'] = front
    img = np.zeros((cv.H, cv.W, 4), np.float32)
    order = []
    if not c['cape_front']: order.append(cape)
    for sd in 'RL':                                  # arms behind the body (S far arm at rest)
        if not front[sd]: order += aimg[sd] + [paul[sd]]
    order += [leg_img[sd] for sd in lorder]
    order += [body]
    if c['cape_front']: order.append(cape)
    # a front arm raised above its shoulder (the wind-up over the helm) passes behind the head; the pauldron stays on top
    raised = {sd: front[sd] and arms[sd]['grip'][1] < arms[sd]['sh'][1] - 10 for sd in 'RL'}; meta['arm_raised'] = raised
    for sd in 'RL':
        if raised[sd]: order += aimg[sd]
    order.append(head)
    for sd in sorted('RL', key=lambda x: -(depth(F, act, i, f'{x}_farm'))):
        if front[sd]: order += ([] if raised[sd] else aimg[sd]) + [paul[sd]]
    for L_ in order: img = over(img, L_)
    return img, meta, cv

def bottom_need(img):
    a = img[..., 3] > 0.5; ys = np.nonzero(a.any(1))[0]
    return max(0, int(ys.max()) - (PADT + CH - 2)) if len(ys) else 0

def side_need(img):
    a = img[..., 3] > 0.5; xs = np.nonzero(a.any(0))[0]
    if not len(xs): return 0
    lo = (PADX + 2) - int(xs.min()); hi = int(xs.max()) - (PADX + CW - 3)
    return lo if lo > 0 else (-hi if hi > 0 else 0)

def death_shifts(F):
    """smallest lift (up) and side shift that keep every death frame inside the cell, never decreasing, eased (<= 3 px per
    frame), and only from the frame where the blockout first moves the feet (planted feet before that stay put)."""
    n = ACTS['death']; imgs = [render(F, 'death', i)[0] for i in range(n)]
    need_y = [bottom_need(m) for m in imgs]; need_x = [side_need(m) for m in imgs]
    first = next(i for i in range(1, n) if any(np.abs(jt(F, 'death', i, f'{sd}_{k}') - jt(F, 'death', 0, f'{sd}_{k}')).max() > 0.25
                                              for sd in 'RL' for k in ('heel', 'toe')))
    out = []
    for need in (need_y, need_x):
        sg = 1 if max(need, key=abs, default=0) >= 0 else -1
        sh = np.maximum.accumulate(np.array([sg * v for v in need], float).clip(0))
        for j in range(n - 2, first - 1, -1): sh[j] = max(sh[j], sh[j + 1] - 3)
        sh[:first] = 0; out.append([int(sg * v) for v in sh])
    return out

def shift(img, dy, dx):
    if dy: img = np.concatenate([img[dy:], np.zeros((dy,) + img.shape[1:], np.float32)], 0)
    if dx: img = np.roll(img, dx, axis=1)
    return img

def clean_cell(out):
    """binary alpha clean-up: speckle islands dropped, pin holes (< 24 px) inside the figure closed with the paint around
    them, and dark halo pixels on the silhouette edge (much darker than the paint just inside) re-coloured from it."""
    a = out[..., 3] > 0
    n_, lab_, st_, _ = cv2.connectedComponentsWithStats(a.astype(np.uint8), 8)
    for k in range(1, n_):
        if st_[k, cv2.CC_STAT_AREA] < 8: a[lab_ == k] = False
    holes = ndi.binary_fill_holes(a) & ~a; hl, hn = ndi.label(holes)
    if hn:
        sz = np.bincount(hl.ravel()); small = np.isin(hl, np.nonzero(sz < 24)[0]) & holes
        a |= small
    rgb = out[..., :3].astype(np.float32)
    # pixels to (re)colour: the closed pin holes
    need = a & (out[..., 3] == 0)
    lum = rgb.mean(-1)
    edge = a & ~ndi.binary_erosion(a)
    inner = a & ~edge & ~need
    k = np.ones((5, 5), np.float32)
    s_in = cv2.filter2D(np.where(inner, lum, 0).astype(np.float32), -1, k, borderType=cv2.BORDER_CONSTANT)
    n_in = cv2.filter2D(inner.astype(np.float32), -1, k, borderType=cv2.BORDER_CONSTANT)
    mean_in = s_in / np.maximum(n_in, 1)
    halo = edge & (n_in >= 3) & (lum < 0.55 * mean_in) & (mean_in > 30)
    fix = need | halo
    if fix.any():
        src = inner.copy()
        _, (iy, ix) = ndi.distance_transform_edt(~src, return_indices=True)
        blur = np.stack([cv2.filter2D(np.where(src, rgb[..., c], 0).astype(np.float32), -1, np.ones((3, 3), np.float32)) for c in range(3)], -1)
        cnt = cv2.filter2D(src.astype(np.float32), -1, np.ones((3, 3), np.float32))[..., None]
        col = np.where(cnt > 0, blur / np.maximum(cnt, 1), rgb[iy, ix])
        rgb[fix] = col[fix]
    res = np.zeros_like(out); res[a, :3] = np.clip(rgb[a] + 0.5, 0, 255).astype(np.uint8); res[a, 3] = 255
    return res, dict(halo_px=int(halo.sum()), holes_closed=int(need.sum()))

def to_cell(img, cv):
    RS = cv.RS; sm = cv2.resize(img, (img.shape[1] // RS, img.shape[0] // RS), interpolation=cv2.INTER_AREA) if RS > 1 else img
    m = sm[..., 3] > 0.5
    lost = dict(top=int(m[:PADT].sum()), bottom=int(m[PADT + CH:].sum()), left=int(m[PADT:PADT + CH, :PADX].sum()), right=int(m[PADT:PADT + CH, PADX + CW:].sum()))
    sm = sm[PADT:PADT + CH, PADX:PADX + CW]; a = sm[..., 3]; m = a > 0.5
    rgb = np.clip(sm[..., :3] / np.maximum(a[..., None], 1e-6), 0, 1)
    out = np.zeros((CH, CW, 4), np.uint8); out[m, :3] = (rgb[m] * 255 + 0.5).astype(np.uint8); out[m, 3] = 255
    out, cl = clean_cell(out)
    return out, lost, cl

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
    ap.add_argument('--acts', default=','.join(ACTS)); ap.add_argument('--frames', default=None); ap.add_argument('--gif', action='store_true')
    a = ap.parse_args(); os.makedirs(a.out, exist_ok=True)
    infop = os.path.join(a.out, '_build_info.json'); info = json.load(open(infop)).get('frames', {}) if os.path.exists(infop) else {}
    for F in a.only:
        for act in a.acts.split(','):
            n = ACTS[act]; fl = [int(x) for x in a.frames.split(',')] if a.frames else range(n)
            sy, sx = death_shifts(F) if act == 'death' else ([0] * n, [0] * n)
            for i in fl:
                img, meta, cv = render(F, act, i); img = shift(img, sy[i], sx[i]); meta['lift_px'] = sy[i]; meta['side_px'] = sx[i]
                cell, lost, cl = to_cell(img, cv); meta['lost_px_outside_cell'] = lost; meta['cleanup'] = cl
                Image.fromarray(cell).save(f'{a.out}/{act}_{F}_f{i:02d}.png')
                info.setdefault(F, {}).setdefault(act, {})[f'f{i:02d}'] = meta
                print(F, act, i, 'phi %.1f head %.1f' % (meta['torso']['phi'], meta['head_deg']), 'legk %.3f %.3f' % (meta['R']['k'], meta['L']['k']),
                      'armk R %.2f L %.2f' % (meta['arm_R']['k'][0], meta['arm_L']['k'][0]), 'front', meta['arm_front'], 'shift', sy[i], sx[i],
                      'lost', {k: v for k, v in lost.items() if v}, cl, flush=True)
            if a.gif and not a.frames:
                os.makedirs(os.path.join(a.out, '..', 'gifs'), exist_ok=True)
                gif([f'{a.out}/{act}_{F}_f{i:02d}.png' for i in range(n)], os.path.join(a.out, '..', 'gifs', f'{act}_{F}.gif'), hold_last=600 if act == 'death' else 0)
    json.dump(dict(cfg=CFG, frames=info), open(infop, 'w'), indent=1, default=float)
