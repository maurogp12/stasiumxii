"""Mender actions v1 - the painted-part rig for idle, attack, skill, hit and death (S and E; W and N are game-side mirrors).

Same family as the LOCKED Kestrel and Bastion actions (kestrel/ and bastion/actions_v1/scripts) and the LOCKED Mender walk
(mender/v1_claude at 08ea869b, read-only). Every part is cut from the approved target (mcut_act.py) and bent onto the action
blockout (blockout/joints_actions_512.json, act_blockout.py, aimfix mode). Nothing is repainted frame by frame. Per frame:
  body    the walk's back / front layers minus the arms, staff and lantern (holes filled with real robe paint), skinned on
          4 affine bones (wbody weights, feathered, so there is no cut):
            base   one similarity at the walk's scale s, rotation and along-axis foreshortening from the change of the
                   blockout pelvis->neck axis since idle f00, pinned at the painted hip centre (which follows the blockout
                   pelvis). Idle f00 is the walk's placement rule (hood top on the clay's head-top row + dy).
            upper  + the torso twist: the blockout shoulder line's change (cyaw) as a foreshortening / shear of the upper
                   body about the neck (clamped). The twist is the torso's own; the arms are separate pieces.
            head   + a head rotation about the neck (the hit's head snap).
            skirt  the robe below the belt turns about the hip line with a lag (and a slow idle sway).
          Hit: the blockout recoil (lean -16, seen as ~10 deg on screen) is scaled so the painted torso recoils 22 deg.
  legs    the walk's continuous painted legs (leg_F / legfar_F, 3-bone mesh skin, knee blend 24, ankle blend 14), hips on the
          painted hip line, the boot rigid on the blockout heel / toe (pinned at the heel, so a planted foot moves only when
          the blockout foot moves), knee by 2-bone IK at the painted lengths, 0.82 <= k <= 1.10 along the bone.
  arms    two rigid painted pieces per arm (robe sleeve; forearm + fist / hand), FK from the painted shoulder on the upper
          body bone. Each bone keeps its painted length times the blockout's projected length change clamped to +-15 % and
          turns by the blockout bone's change of screen angle since idle f00, blended to the blockout bone's own direction
          when the key is posed (Bastion's `turn`). A raised arm is the painted sleeve and fist turned, never a stretched
          hanging arm. E: the right sleeve's hanging bell is its own piece, hinged on the forearm, hanging toward gravity.
  staff   rigid, in the fist: its grip rides on the painted forearm, it turns like the blockout staff (grip -> top,
          act_blockout staff_fix). If the crook would leave the cell top it tips toward the facing about the fist by the
          smallest angle that keeps it inside (reported per frame).
  lantern rigid, hung from the crook tip: a damped pendulum driven by the hook's motion (loops simulated 3 times, f00 = the
          painting). No light effect is painted (effects are separate).
  death   f00-f03 rigged (the knees go, arms thrown out). From f04 the f03 figure (with staff and lantern) falls as one
          painted key: its painting plane turns onto the iso ground with the blockout tilt (0 -> 86 deg), pinned at the
          blockout pelvis. Lying, the figure keeps its painted length (x 0.91, the ground foreshortening of the walk camera) and
          width; it is never squashed toward a hinge. S lies on his back (front painting), E prone (back painting); both fall
          up-left, the approved S path.
Render on a padded canvas at the cell scale with premultiplied Lanczos-prescaled textures, binary alpha, black under alpha 0.
usage: marig.py [--only SE] [--acts idle,attack,skill,hit,death] [--frames 0,6] [--out DIR] [--gif]"""
import os, sys, json, math, argparse, subprocess, numpy as np, cv2
from PIL import Image, ImageOps
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '../../../../../../..'))
AP = os.environ.get('MAPARTS', os.path.join(HERE, '..', 'parts'))
BLK = os.environ.get('MABLOCK', os.path.join(HERE, '..', 'blockout'))
WALK_COMMIT = '08ea869b'
WALK_DIR = os.environ.get('MWALK', '/tmp/mender_walk_lock')
CW, CH, PIV, FPS = 512, 360, (256, 329), 17.144
PADT, PADB, PADX = 120, 160, 80
ACTS = {'idle': 12, 'attack': 12, 'skill': 12, 'hit': 8, 'death': 13}
LOOP = {'idle', 'attack', 'skill', 'hit'}

def walk_dir():
    d = os.path.join(WALK_DIR, 'docs/pc/art_help/class_walk_looks/mender/v1_claude')
    if not os.path.exists(d + '/parts/leg_S.png'):
        os.makedirs(WALK_DIR, exist_ok=True)
        subprocess.run(f'git -C "{REPO}" archive {WALK_COMMIT} docs/pc/art_help/class_walk_looks/mender/v1_claude | tar -x -C "{WALK_DIR}"',
                       shell=True, check=True)
    return d
WD = walk_dir()
JA = json.load(open(f'{BLK}/joints_actions_512.json')); JF = JA['facings']
MJ = {F: json.load(open(f'{AP}/mjoints_{F}.json')) for F in 'SE'}
# the walk's settings (mender/v1_claude/scripts/mrig.py CFG + mcfg.json)
CFG = {
 'S': dict(s=0.372, dy=-0.3, foot_o=(-3.3, 3.0), stance_kmin=0.82, stretch_max=1.10, reach=0.998, knee_blend=24.0, ankle_blend=14.0,
           far_dark=0.90, foot_k=(0.88, 1.12), len_clamp=(0.85, 1.15), skirt_lag=0.55, skirt_follow=0.5, skirt_trail=0.35, skirt_max=8.0,
           idle_sway=0.6, hit_recoil=22.0, head_snap=10.0, twist_k=(0.85, 1.10), twist_max=10.0, drape_g=0.65, facing_sign=1.0),
 'E': dict(s=0.368, dy=-1.0, foot_o=(2.6, 4.0), stance_kmin=0.82, stretch_max=1.10, reach=0.998, knee_blend=24.0, ankle_blend=14.0,
           far_dark=0.90, foot_k=(0.88, 1.12), len_clamp=(0.85, 1.15), skirt_lag=0.55, skirt_follow=0.5, skirt_trail=0.35, skirt_max=8.0,
           idle_sway=0.6, hit_recoil=22.0, head_snap=10.0, twist_k=(0.85, 1.10), twist_max=10.0, drape_g=0.65, facing_sign=1.0),
}
if os.environ.get('MACFG'):                 # overrides (used by the E scale / dy sweep, see README)
    for F_, d_ in json.loads(os.environ['MACFG']).items(): CFG[F_].update(d_)
SRC = {'S': 'L', 'E': 'R'}      # the walk's painted source leg goes on this blockout side; the other gets legfar_F
LIE = dict(x=(0.894, -0.447), down=(0.814, 0.407), up=(-0.816, -0.408))   # ground-plane axes of the walk camera (az 45, el 30)

def fr(F, act, i): return JF[f'{act}_{F}'][f'f{i:02d}']
def jt(F, act, i, k): return np.array(fr(F, act, i)['joints'][k], float)
def ang(v): return math.atan2(v[1], v[0])
def R2(a): c, s_ = math.cos(a), math.sin(a); return np.array([[c, -s_], [s_, c]])
def unit(v): v = np.asarray(v, float); return v / max(float(np.hypot(*v)), 1e-9)
def apm(M, p): return M[:, :2] @ np.asarray(p, float) + M[:, 2]
def wrap(a): return (a + math.pi) % (2 * math.pi) - math.pi
def ss(t): t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)
def comp(A, B): return np.hstack([A[:, :2] @ B[:, :2], (A[:, :2] @ B[:, 2] + A[:, 2])[:, None]])
def about(L, p): p = np.asarray(p, float); return np.hstack([L, (p - L @ p)[:, None]])

def sim(a, b, A, B, s_across):
    u = unit(np.subtract(b, a)); n = np.array([-u[1], u[0]]); v = unit(np.subtract(B, A)); m = np.array([-v[1], v[0]])
    k = math.dist(A, B) / math.dist(a, b); L = np.outer(v, u) * k + np.outer(m, n) * s_across
    return np.hstack([L, (np.asarray(A, float) - L @ np.asarray(a, float))[:, None]])

def ik_knee(hip, ank, L1, L2, kref):
    d = np.subtract(ank, hip); D = float(np.hypot(*d)); D = min(D, L1 + L2 - 1e-4); u = unit(d); n = np.array([-u[1], u[0]])
    a = (L1 * L1 - L2 * L2 + D * D) / (2 * D); h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    sg = 1.0 if np.dot(np.subtract(kref, hip), n) >= 0 else -1.0
    return np.asarray(hip, float) + u * a + n * h * sg

# ------------------------------------------------------------------ textures (premultiplied float, prescaled to the cell)
TEX = {}
def tpath(name):
    return f'{WD}/parts/{name}.png' if name.startswith('leg') else f'{AP}/{name}.png'
def ptex(name):
    if name not in TEX:
        im = np.asarray(Image.open(tpath(name)).convert('RGBA')).astype(np.float32)
        s = CFG[name[-1]]['s']
        a = im[..., 3:4] / 255.0; pm = np.concatenate([im[..., :3] * a, a * 255.0], -1)
        h, w = im.shape[:2]; nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
        out = np.stack([np.asarray(Image.fromarray(pm[..., c], 'F').resize((nw, nh), Image.LANCZOS)) for c in range(4)], -1) / 255.0
        TEX[name] = (np.clip(out, 0, 1).astype(np.float32), (nw / w, nh / h))
    return TEX[name]
def src_px(name, P): pre = np.array(ptex(name)[1]); return (np.asarray(P, float) + 0.5) * pre - 0.5

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

def warp(T, V, Vd, tris, H, W, order=None):
    D = Vd[tris]; S = V[tris]
    dA = np.concatenate([D, np.ones(D.shape[:2] + (1,))], 2); ok = np.abs(np.linalg.det(dA)) > 1e-6
    A = np.zeros((len(tris), 2, 3)); A[ok] = np.transpose(np.linalg.solve(dA[ok], S[ok]), (0, 2, 1))
    idx = np.full((H, W), -1, np.int32); Di = np.round(D * 16).astype(np.int32)
    for t in (order if order is not None else range(len(tris))):
        if ok[t]: cv2.fillConvexPoly(idx, Di[t], int(t), lineType=cv2.LINE_8, shift=4)
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
        a = np.maximum(np.asarray(Image.open(f'{AP}/back_{F}.png'))[..., 3], np.asarray(Image.open(f'{AP}/front_{F}.png'))[..., 3]).astype(np.float32) / 255.
        V, tris = grid_mesh(a, 4)
        wb = np.asarray(Image.open(f'{AP}/wbody_{F}.png').convert('RGB')).astype(np.float32) / 255.
        xi = np.clip(V[:, 0].astype(int), 0, 1279); yi = np.clip(V[:, 1].astype(int), 0, 719)
        wh, wu, wk = wb[yi, xi, 0], wb[yi, xi, 1], wb[yi, xi, 2]
        Wh = wh; Wu = wu * (1 - wh); Wk = wk * (1 - wh) * (1 - wu)
        W = np.stack([np.clip(1 - Wh - Wu - Wk, 0, 1), Wu, Wh, Wk], 1); W /= W.sum(1, keepdims=True)
        _MESH[F] = (V, tris, W)
    return _MESH[F]

_LMESH = {}
def leg_mesh(F, name, step=4):
    key = (F, name)
    if key not in _LMESH:
        a = np.asarray(Image.open(tpath(name)))[..., 3].astype(np.float32) / 255.
        V, tris = grid_mesh(a, step, 1)
        R = MJ[F]['walk_rig']; H, K, A = (np.array(R[k], float) for k in ('H', 'K', 'A'))
        ut, us = unit(K - H), unit(A - K); mk = unit(ut + us); c = CFG[F]; bk, ba = c['knee_blend'], c['ankle_blend']
        wk = ss(((V - K) @ mk + bk) / (2 * bk)); wa = ss(((V - A) @ us + ba) / (2 * ba))
        Wt = np.stack([1 - wk, wk * (1 - wa), wk * wa], -1)
        tw = Wt[tris].mean(1); order = np.argsort(tw @ np.array([0.0, 1.0, 2.0]), kind='stable')
        _LMESH[key] = (V, tris, Wt, order)
    return _LMESH[key]

class Canvas:
    def __init__(self, RS=1): self.RS = RS; self.H = (CH + PADT + PADB) * RS; self.W = (CW + 2 * PADX) * RS
    def M(self, M, pre=(1.0, 1.0)):
        o = np.array([PADX, PADT], float); pre = np.asarray(pre, float)
        L = M[:, :2] @ np.diag(1 / pre); t = M[:, 2] + M[:, :2] @ (0.5 / pre - 0.5)
        return np.hstack([L * self.RS, ((t + o) * self.RS)[:, None]]).astype(np.float32)
    def pts(self, P): return (np.asarray(P, float) + np.array([PADX, PADT])) * self.RS
    def affine(self, name, M):
        T, pre = ptex(name); return cv2.warpAffine(T, self.M(M, pre), (self.W, self.H), flags=cv2.INTER_LINEAR, borderValue=0)
    def cellimg_affine(self, img, M2):
        """warp a canvas image by a cell-space 2x3 map (canvas coordinates)."""
        o = np.array([PADX, PADT], float) * self.RS
        L = M2[:, :2]; t = M2[:, 2] * self.RS + o - L @ o
        return cv2.warpAffine(img, np.hstack([L, t[:, None]]).astype(np.float32), (self.W, self.H), flags=cv2.INTER_LINEAR, borderValue=0)

# ------------------------------------------------------------------ body
_CT = {}
def clay_top(F):
    if F not in _CT:
        a = np.asarray(Image.open(f'{BLK}/clay/mender_idle_{F}_f00.png').convert('RGBA'))[..., 3] > 127
        x = int(round(jt(F, 'idle', 0, 'head_top')[0])); _CT[F] = int(np.nonzero(a[:, x - 15:x + 15].any(1))[0].min())
    return _CT[F]

def hc_t(F): R = MJ[F]['walk_rig']; return (np.array(R['hips']['near'], float) + np.array(R['hips']['far'], float)) / 2

def placement0(F):
    """idle f00 body map = the walk's rule: x on the blockout hip centre, hood top on the clay's head-top row + dy."""
    c = CFG[F]; s = c['s']; R = MJ[F]['walk_rig']
    hci = (jt(F, 'idle', 0, 'L_hip') + jt(F, 'idle', 0, 'R_hip')) / 2
    tx = hci[0] - s * hc_t(F)[0] + c.get('dx', 0.0); ty = clay_top(F) - s * R['top'] + c['dy']
    return np.array([[s, 0, tx], [0, s, ty]], float)

def torso_axis(F, act, i): return jt(F, act, i, 'neck') - jt(F, act, i, 'pelvis')

_HITG = {}
def hit_gain(F):
    """the painted recoil: the blockout hit's peak screen tilt scaled to hit_recoil deg."""
    if F not in _HITG:
        u0 = torso_axis(F, 'idle', 0); pk = max(abs(wrap(ang(torso_axis(F, 'hit', i)) - ang(u0))) for i in range(ACTS['hit']))
        _HITG[F] = math.radians(CFG[F]['hit_recoil']) / max(pk, 1e-6)
    return _HITG[F]

def torso_M(F, act, i):
    c = CFG[F]; s = c['s']; M0 = placement0(F); h = hc_t(F)
    u0 = torso_axis(F, 'idle', 0); ui = torso_axis(F, act, i)
    phi = wrap(ang(ui) - ang(u0)); k = float(np.clip(np.linalg.norm(ui) / np.linalg.norm(u0), 0.35, 1.15))
    if act == 'hit': phi *= hit_gain(F)
    e = unit(u0); Sx = np.eye(2) + (k - 1) * np.outer(e, e); A = R2(phi) @ Sx * s
    d0 = apm(M0, h) - jt(F, 'idle', 0, 'pelvis')
    piv = jt(F, act, i, 'pelvis') + R2(phi) @ (Sx @ d0)
    M = np.hstack([A, (piv - A @ h)[:, None]])
    return M, dict(phi=math.degrees(phi), k=k)

def twist_M(F, act, i, Mt, phi):
    """upper-body twist (cell space, about the neck): the blockout shoulder line's change since idle f00 with the torso tilt
    taken out, as a map that keeps the torso axis and takes the idle shoulder vector to the current one (clamped)."""
    c = CFG[F]
    v0 = jt(F, 'idle', 0, 'L_shoulder') - jt(F, 'idle', 0, 'R_shoulder'); vi = R2(-phi) @ (jt(F, act, i, 'L_shoulder') - jt(F, act, i, 'R_shoulder'))
    a0 = unit(torso_axis(F, 'idle', 0))
    k = float(np.clip(np.linalg.norm(vi) / np.linalg.norm(v0), *c['twist_k']))
    da = 0.0                     # the twist is a foreshortening of the shoulder line only (lean / recoil keep their tilt)
    vc = R2(da) @ v0 * k
    T = np.column_stack([vc, a0]) @ np.linalg.inv(np.column_stack([v0, a0]))
    Tc = R2(phi) @ T @ R2(-phi)
    neck = apm(Mt, MJ[F]['neck'])
    return about(Tc, neck), dict(k=k, deg=math.degrees(da))

HEAD_SNAP = [0.0, 0.55, 1.0, 0.65, 0.3, 0.12, 0.04, 0.0]
def head_deg(F, act, i, phi_deg):
    if act != 'hit': return 0.0
    return CFG[F]['head_snap'] * HEAD_SNAP[i] * math.copysign(1.0, phi_peak(F))

_PP = {}
def phi_peak(F):
    if F not in _PP:
        ph = [torso_M(F, 'hit', i)[1]['phi'] for i in range(ACTS['hit'])]; _PP[F] = max(ph, key=abs)
    return _PP[F]

_SK = {}
def skirt_angles(F, act):
    if (F, act) in _SK: return _SK[(F, act)]
    c = CFG[F]; n = ACTS[act]
    phi = np.array([torso_M(F, act, i)[1]['phi'] for i in range(n)]); pel = np.array([jt(F, act, i, 'pelvis') for i in range(n)])
    reps = 3 if act in LOOP else 1; ph = np.tile(phi, reps); pv = np.tile(pel, (reps, 1))
    vel = np.diff(pv[:, 0], prepend=pv[0, 0])
    f = ph[0]; vf = 0.0; res = []
    for j in range(len(ph)):
        f = f + (ph[j] - f) * (1 - c['skirt_lag']); vf = vf + (vel[j] - vf) * (1 - c['skirt_lag'])
        res.append(math.radians((f - ph[j]) * c['skirt_follow']) - math.radians(c['skirt_trail'] * vf * 4.0))
    out = np.array(res[-n:])
    if act == 'idle': out = out + np.radians(c['idle_sway']) * np.sin(np.arange(n) / n * 2 * math.pi - 1.0)
    out = out - out[0]
    lim = math.radians(c['skirt_max']); _SK[(F, act)] = np.clip(out, -lim, lim); return _SK[(F, act)]

def body_bones(F, act, i):
    Mt, ti = torso_M(F, act, i)
    phi = math.radians(ti['phi'])
    Tw, twi = twist_M(F, act, i, Mt, phi); Mu = comp(Tw, Mt)
    hd = head_deg(F, act, i, ti['phi']); Mh = comp(about(R2(math.radians(hd)), apm(Mu, MJ[F]['neck'])), Mu)
    sk = skirt_angles(F, act)[i] if act != 'death' else 0.0
    hip_c = apm(Mt, [hc_t(F)[0], MJ[F]['belt_y'][0]])
    Mk = comp(about(R2(sk), hip_c), Mt)
    return dict(Mt=Mt, Mu=Mu, Mh=Mh, Mk=Mk), dict(torso=ti, twist=twi, head_deg=hd, skirt_deg=math.degrees(sk))

# ------------------------------------------------------------------ legs (walk rules)
def leg_pose(F, act, i, sd, Mt, hip=None):
    c = CFG[F]; s = c['s']; R = MJ[F]['walk_rig']
    H, K, A = (np.array(R[k], float) for k in ('H', 'K', 'A')); he_s, to_s = np.array(R['heel'], float), np.array(R['toe'], float)
    if hip is None:
        hc = apm(Mt, hc_t(F)); hv = (jt(F, act, i, 'L_hip') - jt(F, act, i, 'R_hip')) / 2
        hip = hc + hv if sd == 'L' else hc - hv
    he_d, to_d = jt(F, act, i, sd + '_heel'), jt(F, act, i, sd + '_toe')
    kf = float(np.clip(math.dist(he_d, to_d) / (s * math.dist(he_s, to_s)), *c['foot_k']))
    u = unit(to_s - he_s); n = np.array([-u[1], u[0]]); v = unit(to_d - he_d); m = np.array([-v[1], v[0]])
    L = np.outer(v, u) * s * kf + np.outer(m, n) * s
    Mf = np.hstack([L, (he_d - L @ he_s)[:, None]]); Mf[:, 2] += np.array(c['foot_o'], float)
    an = apm(Mf, A); Lt0, Ls0 = s * math.dist(H, K), s * math.dist(K, A); D = math.dist(hip, an)
    kraw = D / (c['reach'] * (Lt0 + Ls0)); k = float(np.clip(kraw, c['stance_kmin'], c['stretch_max']))
    kn = ik_knee(hip, an, Lt0 * k, Ls0 * k, jt(F, act, i, sd + '_knee'))
    an2 = kn + unit(an - kn) * Ls0 * k          # if the leg is short of the boot, the gap stays under the robe (reported)
    Mth = sim(H, K, hip, kn, s); Msh = sim(K, A, kn, an2, s)
    return dict(Mth=Mth, Msh=Msh, Mf=Mf, hip=hip, knee=kn, ankle=an, k=k, k_raw=kraw, short=max(0.0, D - (Lt0 + Ls0) * k),
                heel=apm(Mf, he_s), toe=apm(Mf, to_s))

def near_leg(F, act, i):
    o = fr(F, act, i)['draw_order']; return 'L' if o.index('L_boot') < o.index('R_boot') else 'R'

def render_leg(F, sd, P, cv):
    name = f'leg_{F}' if sd == SRC[F] else f'legfar_{F}'
    V, tris, Wt, order = leg_mesh(F, name)
    Vd = lbs(V, Wt, (P['Mth'], P['Msh'], P['Mf']))
    img, _ = warp(ptex(name)[0], src_px(name, V), cv.pts(Vd), tris, cv.H, cv.W, order)
    return img

# ------------------------------------------------------------------ arms, staff, lantern
KEY_BLEND = 30.0
def key_w(F, act, i, sd):
    a0 = fr(F, 'idle', 0)['key']['arms'][sd]; ai = fr(F, act, i)['key']['arms'][sd]
    return float(ss(sum(abs(x - y) for x, y in zip(ai, a0)) / KEY_BLEND))

def turn(a_paint, a_b0, a_bi, w):
    rel = wrap(a_bi - a_b0); absl = wrap(a_bi - a_paint)
    return wrap(rel + w * wrap(absl - rel))

CAST_HOLD = 6
def cast_p(F, i):
    """skill progress 0 (rest) .. 1 (the hold) from the blockout staff-arm key."""
    A = fr(F, 'skill', i)['key']['arms']['R'][0]; Ah = fr(F, 'skill', CAST_HOLD)['key']['arms']['R'][0]
    return float(ss(A / Ah))

def arm_pose(F, act, i, sd, Mu, _raw=False):
    if act == 'skill' and sd == 'R' and not _raw:
        # the heal lifts the staff arm straight from the painting to the hold pose (each bone turns by p x its hold turn,
        # length by p of its hold factor), out at his side: the blockout path goes forward through the camera line, which
        # puts the fist and the lantern across the face for three frames
        h = arm_pose(F, act, CAST_HOLD, sd, Mu, _raw=True); p = cast_p(F, i); s = CFG[F]['s']; J = MJ[F]['arms'][sd]
        out = dict(sh=apm(Mu, J['shoulder'])); prev = out['sh']; out['w'] = p; out['k'] = []; out['rot'] = []
        for n_, (ja, jb) in enumerate((('shoulder', 'elbow'), ('elbow', 'hand'))):
            v0 = s * (np.array(J[jb], float) - np.array(J[ja], float)); a = p * h['rot'][n_]
            kh = CAST_K[F] if CAST_K[F] is not None else h['k'][n_]; k = 1 + p * (kh - 1)
            prev = prev + R2(a) @ v0 * k; out[jb] = prev; out['k'].append(k); out['rot'].append(a)
        out['Mu'] = sim(J['shoulder'], J['elbow'], out['sh'], out['elbow'], s); out['Mf'] = sim(J['elbow'], J['hand'], out['elbow'], out['hand'], s)
        return out
    c = CFG[F]; s = c['s']; J = MJ[F]['arms'][sd]
    sh = apm(Mu, J['shoulder']); b = lambda a, ii, k: jt(F, a, ii, f'{sd}_{k}')
    out = dict(sh=sh); prev = sh; lens = []; rots = []; w = key_w(F, act, i, sd); out['w'] = w
    for ja, jb in (('shoulder', 'elbow'), ('elbow', 'hand')):
        v0 = s * (np.array(J[jb], float) - np.array(J[ja], float))
        b0 = b('idle', 0, jb) - b('idle', 0, ja); bi = b(act, i, jb) - b(act, i, ja)
        k = float(np.clip(np.linalg.norm(bi) / max(np.linalg.norm(b0), 1e-6), *c['len_clamp']))
        a = turn(ang(v0), ang(b0), ang(bi), w)
        if act == 'skill' and sd == 'R': a += w * math.radians(CAST_OUT[F][0 if ja == 'shoulder' else 1])
        d = R2(a) @ v0 * k
        nxt = prev + d; out[jb] = nxt; lens.append(k); rots.append(a); prev = nxt
    out['k'] = lens; out['rot'] = rots
    out['Mu'] = sim(J['shoulder'], J['elbow'], out['sh'], out['elbow'], s)
    out['Mf'] = sim(J['elbow'], J['hand'], out['elbow'], out['hand'], s)
    return out

# skill (heal): the staff arm opens outward on screen (upper, fore, deg; S: his right is screen-left) so the raised fist and
# the lantern clear the hood; the staff top tips toward the facing (+ = clockwise = screen right for S and E)
CAST_OUT = {'S': (-55.0, -32.0), 'E': (8.0, 4.0)}
CAST_K = {'S': 1.0, 'E': None}     # S: the arm opens across the screen, so the painted lengths are kept (no foreshortening)
CAST_TILT = {'S': 14.0, 'E': 8.0}
DRAPE_HINGE = {'E': (768, 246)}
def drape_M(F, arm):
    """E right sleeve bell: hinged on the painted forearm, it turns only (1 - drape_g) of the forearm's turn (it hangs)."""
    s = CFG[F]['s']; hg = DRAPE_HINGE[F]; p = apm(arm['Mf'], hg); a = arm['rot'][1] * (1 - CFG[F]['drape_g'])
    L = R2(a) * s; return np.hstack([L, (p - L @ np.array(hg, float))[:, None]])

_HULL = {}
def hull(name):
    if name not in _HULL:
        a = np.asarray(Image.open(f'{AP}/{name}.png'))[..., 3] > 127; ys, xs = np.nonzero(a)
        _HULL[name] = cv2.convexHull(np.stack([xs, ys], 1).astype(np.float32))[:, 0]
    return _HULL[name]

def staff_M(F, act, i, arm):
    c = CFG[F]; s = c['s']; St = MJ[F]['staff']; g_t, t_t = np.array(St['grip'], float), np.array(St['top'], float)
    g = apm(arm['Mf'], g_t); v0 = s * (t_t - g_t)
    b0 = jt(F, 'idle', 0, 'staff_top') - jt(F, 'idle', 0, 'staff_grip'); bi = jt(F, act, i, 'staff_top') - jt(F, act, i, 'staff_grip')
    a = turn(ang(v0), ang(b0), ang(bi), arm['w'])          # screen rotation of the painted staff about the fist
    if act == 'death':      # the knees go: the staff tilts with the body (the arms are thrown out, the fist loosens)
        a = HIT_STAFF[F] * math.radians(torso_M(F, act, i)[1]['phi'])
    if act == 'hit':        # knocked back, the staff stays in the fist and tilts with the recoil (it does not fly across him)
        a = HIT_STAFF[F] * math.radians(torso_M(F, act, i)[1]['phi'])
    if act == 'skill':      # the heal: the staff is lifted near-upright, its top tipped toward the facing (it never sweeps)
        a = arm['w'] * math.radians(CAST_TILT[F])
    def M_of(a_): L = R2(a_) * s; return np.hstack([L, (g - L @ g_t)[:, None]])
    M = M_of(a); corr = 0.0
    def ok(M_):
        P = np.array([apm(M_, p) for p in hull(f'staff_{F}')])
        return P[:, 1].min() >= 2 and P[:, 1].max() <= FLOOR and P[:, 0].min() >= 2 and P[:, 0].max() <= CW - 3
    slide = 0.0
    if not ok(M):
        # the butt would go through the floor: a near-upright staff slides up through the fist (the butt stays on the
        # ground, the hand slides on the shaft), at most SLIDE_MAX px
        P = np.array([apm(M, p) for p in hull(f'staff_{F}')]); u = unit(apm(M, t_t) - g)
        over_ = P[:, 1].max() - FLOOR
        if over_ > 0 and -u[1] > 0.6:
            d = min(over_ / -u[1], SLIDE_MAX); M2 = M.copy(); M2[:, 2] += u * d
            if ok(M2) or d >= SLIDE_MAX: M = M2; slide = d
    if not ok(M):
        # otherwise (or still out): the staff is rigid in the fist and tips the least way that keeps it in the cell; if the
        # crook would leave the cell top it tips toward the facing (screen right for S and E: + first)
        base = M
        for dd in np.radians(np.arange(1, 121, 1)):
            hit = next((x for x in (a + dd, a - dd) if ok(_slid(M_of(x), base, M_of(a)))), None)
            if hit is not None: corr = math.degrees(hit - a); a = hit; M = _slid(M_of(a), base, M_of(a)); break
    return M, dict(grip=g.tolist(), top=apm(M, t_t).tolist(), deg=math.degrees(a), top_corr_deg=round(corr, 1), slide_px=round(slide, 1))

def _slid(M, Mslid, Mbase):
    """carry a slide already applied (Mslid vs Mbase translation) over to a re-rotated staff map M."""
    M = M.copy(); M[:, 2] += Mslid[:, 2] - Mbase[:, 2]; return M

SLIDE_MAX = 40.0
# hit: the staff's tilt per degree of torso recoil. S: with the body. E: the fist is pulled back toward the camera ~40 px,
# so the planted staff leans away (top outward) and the lantern stays clear of his shoulder
HIT_STAFF = {'S': 0.8, 'E': -0.6}
FLOOR = 356          # lowest cell row a held staff may reach (the ground under the planted boots is row ~350-358)
PEND = dict(g=4.9, damp=0.45, sub=4, max=40.0)
_LA = {}
def lantern_angles(F, act):
    if (F, act) in _LA: return _LA[(F, act)]
    n = ACTS[act]; s = CFG[F]['s']; Lt = MJ[F]['lantern']; Lp = s * math.dist(Lt['hook'], Lt['c'])
    hooks = []
    for i in range(n):
        if act == 'death' and i > 3: hooks.append(hooks[-1]); continue
        bb, _ = body_bones(F, act, i); arm = arm_pose(F, act, i, 'R', bb['Mu']); Ms, _ = staff_M(F, act, i, arm)
        hooks.append(apm(Ms, Lt['hook']))
    hooks = np.array(hooks); hp = np.concatenate([np.repeat(hooks[:1], 6, 0), hooks]) if act in LOOP else hooks   # from rest
    th, om = 0.0, 0.0; res = []; prev = hp[0]; pv = np.zeros(2)
    for j in range(len(hp)):
        vel = hp[j] - prev; acc = vel - pv; pv = vel; prev = hp[j]
        om += -(acc[0] / Lp) * math.cos(th)            # the hook's horizontal acceleration this frame kicks the swing
        for _ in range(PEND['sub']):                   # then gravity and damping over the frame
            dt = 1.0 / PEND['sub']; al = -(PEND['g'] / Lp) * math.sin(th) - PEND['damp'] * om
            om += al * dt; th += om * dt
        th = float(np.clip(th, -math.radians(PEND['max']), math.radians(PEND['max'])))
        res.append(th)
    out = np.array(res[-n:])
    if act in LOOP:      # every looped action starts and ends on idle f00 (the painting): the swing settles over the last 3 frames
        out = out - out[0] * (1 - np.arange(n) / n); out = out * (1 - ss((np.arange(n) - (n - 4)) / 3.0))
        lim = math.radians(PEND['max']); out = np.clip(out, -lim, lim)
    _LA[(F, act)] = out; return out

def lantern_M(F, act, i, Ms):
    s = CFG[F]['s']; hk = MJ[F]['lantern']['hook']; p = apm(Ms, hk); th = lantern_angles(F, act)[i]
    L = R2(th) * s; return np.hstack([L, (p - L @ np.array(hk, float))[:, None]]), math.degrees(th)

def rel_depth(F, act, i, part):
    d0 = fr(F, 'idle', 0)['depth']; di = fr(F, act, i)['depth']
    return (di[part] - di['torso']) - (d0[part] - d0['torso'])

# ------------------------------------------------------------------ frame
def render_upright(F, act, i, cv, layers=False, skip_leg=None):
    bb, binfo = body_bones(F, act, i)
    V, tris, W = body_mesh(F); Vd = lbs(V, W, (bb['Mt'], bb['Mu'], bb['Mh'], bb['Mk']))
    back, maps = warp(ptex(f'back_{F}')[0], src_px(f'back_{F}', V), cv.pts(Vd), tris, cv.H, cv.W)
    front = remap_with(ptex(f'front_{F}')[0], maps)
    meta = dict(binfo)
    legs = {sd: leg_pose(F, act, i, sd, bb['Mt']) for sd in 'RL'}; nr = near_leg(F, act, i); leg_imgs = []
    for sd in [x for x in 'RL' if x != nr] + [nr]:
        if sd == skip_leg: meta[sd] = {k: (v.tolist() if isinstance(v, np.ndarray) else v) for k, v in legs[sd].items() if not k.startswith('M')}; continue
        L_ = render_leg(F, sd, legs[sd], cv)
        if sd != nr: L_[..., :3] *= CFG[F]['far_dark']
        leg_imgs.append(L_)
        meta[sd] = {k: (v.tolist() if isinstance(v, np.ndarray) else v) for k, v in legs[sd].items() if not k.startswith('M')}
    arms = {sd: arm_pose(F, act, i, sd, bb['Mu']) for sd in 'RL'}
    Ms, sinfo = staff_M(F, act, i, arms['R']); Ml, lth = lantern_M(F, act, i, Ms)
    img = {}
    for sd in 'RL':
        img[f'u{sd}'] = cv.affine(f'uarm_{sd}_{F}', arms[sd]['Mu']); img[f'f{sd}'] = cv.affine(f'fore_{sd}_{F}', arms[sd]['Mf'])
        meta['arm_' + sd] = dict(sh=arms[sd]['sh'].tolist(), el=arms[sd]['elbow'].tolist(), hand=arms[sd]['hand'].tolist(), k=arms[sd]['k'], w=arms[sd]['w'])
    if F == 'E': img['dR'] = cv.affine(f'drape_R_{F}', drape_M(F, arms['R']))
    img['staff'] = cv.affine(f'staff_{F}', Ms); img['lant'] = cv.affine(f'lantern_{F}', Ml)
    meta['staff'] = sinfo; meta['lantern_deg'] = lth
    # ---- composite, back to front
    rarm = ['uR'] + (['dR'] if F == 'E' else []) + ['fR']
    if F == 'S':
        behind = []; frontL = ['uL', 'fL', 'lant', 'staff'] + rarm
    else:
        bR = rel_depth(F, act, i, 'R_farm') > 15; bS = rel_depth(F, act, i, 'staff') > 15
        bL = rel_depth(F, act, i, 'L_farm') > 15 or fr(F, act, i)['key']['arms']['L'][0] > 30
        # the forearm (+ bell) and the fist go behind the body when the blockout says so; the sleeve stays on the shoulder
        behind = (['uL', 'fL'] if bL else []) + (['lant', 'staff'] if bS else []) + (['dR', 'fR'] if bR else [])
        frontL = ([] if bL else ['uL', 'fL']) + ([] if bS else ['lant', 'staff']) + ['uR'] + ([] if bR else ['dR', 'fR'])
        meta['behind'] = dict(R=bool(bR), staff=bool(bS), L=bool(bL))
    def stack(skip=()):
        o = np.zeros((cv.H, cv.W, 4), np.float32)
        for k in behind:
            if k not in skip: o = over(o, img[k])
        o = over(o, back)
        for L_ in leg_imgs: o = over(o, L_)
        o = over(o, front)
        for k in frontL:
            if k not in skip: o = over(o, img[k])
        return o
    if layers:
        prop = over(img['lant'], img['staff'])
        return dict(body=stack(skip=('lant', 'staff')), prop=prop), meta
    return stack(), meta

def lie_A(theta):
    """painting plane -> screen as the figure turns from standing (theta 0) onto the iso ground (theta 90, head up-left)."""
    t = math.radians(theta); ph = math.radians(26.57) * min(theta, 90.0) / 90.0
    X = np.array([math.cos(ph), -math.sin(ph)])
    Up = math.cos(t) * np.array([0.0, -1.0]) + math.sin(t) * np.array(LIE['up'])
    return np.column_stack([X, -Up])

FALL_FROM = 3
SLIP = 10.0          # px the dropped staff and lantern slip away from his side by the time he lies flat
_SRC = {}; _SHIFT = {}
# E falls to his side about his planted left boot (act_blockout side_fall): that boot stays on its blockout heel / toe
# through the fall, the fall pivots there, and that leg is re-skinned every frame from the falling hip to the planted boot
PIN_LEG = {'E': 'L'}
def fall_src(F, cv):
    if F not in _SRC: _SRC[F] = render_upright(F, 'death', FALL_FROM, cv, layers=True, skip_leg=PIN_LEG.get(F))
    return _SRC[F]

def fall_M(F, i, shift):
    """the fall map (cell space): the f03 figure's painting plane turned onto the ground by the blockout tilt, pivoting at
    its feet (the painted heel / toe midpoint of f03), which follow the blockout heels, plus the in-cell shift (eased in)."""
    m0 = fall_src(F, Canvas())[1]; sds = PIN_LEG[F] if F in PIN_LEG else 'RL'
    p0 = np.mean([m0[sd]['heel'] for sd in sds], 0)
    b0 = np.mean([jt(F, 'death', FALL_FROM, f'{sd}_heel') for sd in sds], 0); bi = np.mean([jt(F, 'death', i, f'{sd}_heel') for sd in sds], 0)
    th = float(fr(F, 'death', i)['key'].get('tilt', 0.0)); A = lie_A(th); e = float(ss(th / 86.0))
    p1 = p0 + (bi - b0) + np.asarray(shift, float) * e
    return np.hstack([A, (p1 - A @ p0)[:, None]]), th, e

def fall_img(F, i, cv, shift):
    src = fall_src(F, cv)[0]; M2, th, e = fall_M(F, i, shift)
    body = cv.cellimg_affine(src['body'], M2)
    # the dropped staff and lantern slip away from his side (painting -x for S: his right, toward the camera when he lies;
    # painting +x for E: his right, away from the camera) and lie flat with him
    sx = (-1.0 if F == 'S' else 1.0) * SLIP * e; Ms_ = M2.copy(); Ms_[:, 2] += M2[:, :2] @ np.array([sx, 0.0])
    prop = cv.cellimg_affine(src['prop'], Ms_)
    if F in PIN_LEG:      # the planted leg: hip carried by the fall, boot on the blockout heel / toe of this frame
        sd = PIN_LEG[F]; m0 = fall_src(F, cv)[1]; P = leg_pose(F, 'death', i, sd, None, hip=apm(M2, m0[sd]['hip']))
        leg = render_leg(F, sd, P, cv); leg[..., :3] *= CFG[F]['far_dark'] if near_leg(F, 'death', FALL_FROM) != sd else 1.0
        _PL[(F, i)] = P
        return over(over(prop, leg), body), e
    return (over(body, prop) if F == 'S' else over(prop, body)), e
_PL = {}

def fall_shift(F):
    """the least translation (eased in with the fall) that keeps every lying frame inside the cell (2 px margin), so the
    lying figure is never lifted off the ground: he lands a little up-left / right of the blockout's spot instead."""
    if F in _SHIFT: return _SHIFT[F]
    cv = Canvas(); need = np.zeros(2)
    for i in range(FALL_FROM + 1, ACTS['death']):
        img, e = fall_img(F, i, cv, (0.0, 0.0))
        if e < 1e-3: continue
        a = img[..., 3] > 0.5; ys, xs = np.nonzero(a); xs = xs - PADX; ys = ys - PADT
        lo = np.array([xs.min(), ys.min()]); hi = np.array([xs.max(), ys.max()]); lim = np.array([CW - 3, CH - 3])
        d = np.where(lo < 2, 2 - lo, np.where(hi > lim, lim - hi, 0)) / e
        need = np.where(np.abs(d) > np.abs(need), d, need)
    _SHIFT[F] = np.ceil(np.abs(need)) * np.sign(need); return _SHIFT[F]

def render(F, act, i, RS=1):
    cv = Canvas(RS)
    if act != 'death' or i <= FALL_FROM:
        img, meta = render_upright(F, act, i, cv); meta['lie_deg'] = 0.0; return img, meta, cv
    src, meta0 = fall_src(F, cv); meta = json.loads(json.dumps(meta0))
    sh = fall_shift(F); img, e = fall_img(F, i, cv, sh); M2, th, e = fall_M(F, i, sh)
    for sd in 'RL':
        if (F, i) in _PL and sd == PIN_LEG.get(F):
            P = _PL[(F, i)]; meta[sd] = {k: (v.tolist() if isinstance(v, np.ndarray) else v) for k, v in P.items() if not k.startswith('M')}
        else:
            for k in ('heel', 'toe'): meta[sd][k] = apm(M2, meta0[sd][k]).tolist()
    meta['lie_deg'] = th; meta['lie_M'] = M2.tolist(); meta['lie_shift'] = [float(x) for x in sh]
    return img, meta, cv

def to_cell(img, cv):
    RS = cv.RS; sm = cv2.resize(img, (img.shape[1] // RS, img.shape[0] // RS), interpolation=cv2.INTER_AREA) if RS != 1 else img
    a = sm[..., 3]; m = a > 0.5
    lost = dict(top=int(m[:PADT].sum()), bottom=int(m[PADT + CH:].sum()), left=int(m[PADT:PADT + CH, :PADX].sum()), right=int(m[PADT:PADT + CH, PADX + CW:].sum()))
    sm = sm[PADT:PADT + CH, PADX:PADX + CW]; a = sm[..., 3]; m = a > 0.5
    rgb = np.clip(sm[..., :3] / np.maximum(a[..., None], 1e-6), 0, 1)
    out = np.zeros((CH, CW, 4), np.uint8); out[m, :3] = (rgb[m] * 255 + 0.5).astype(np.uint8); out[m, 3] = 255
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

def jsonable(o):
    if isinstance(o, dict): return {k: jsonable(v) for k, v in o.items()}
    if isinstance(o, (list, tuple)): return [jsonable(v) for v in o]
    if isinstance(o, np.ndarray): return jsonable(o.tolist())
    if isinstance(o, (np.floating,)): return float(o)
    if isinstance(o, (np.integer,)): return int(o)
    if isinstance(o, (np.bool_,)): return bool(o)
    return o

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--out', default=os.path.join(HERE, '..', 'frames')); ap.add_argument('--only', default='SE')
    ap.add_argument('--acts', default=','.join(ACTS)); ap.add_argument('--frames', default=None); ap.add_argument('--rs', type=int, default=1)
    ap.add_argument('--gif', action='store_true')
    a = ap.parse_args(); os.makedirs(a.out, exist_ok=True)
    infop = os.path.join(a.out, '_build_info.json'); info = json.load(open(infop)).get('frames', {}) if os.path.exists(infop) else {}
    for F in a.only:
        for act in a.acts.split(','):
            n = ACTS[act]; fl = [int(x) for x in a.frames.split(',')] if a.frames else range(n)
            for i in fl:
                img, meta, cv = render(F, act, i, a.rs)
                cell, lost = to_cell(img, cv); meta['lost_px_outside_cell'] = lost
                Image.fromarray(cell).save(f'{a.out}/{act}_{F}_f{i:02d}.png')
                info.setdefault(F, {}).setdefault(act, {})[f'f{i:02d}'] = jsonable(meta)
                print(F, act, i, 'phi %.1f' % meta['torso']['phi'], 'tw %.2f/%.1f' % (meta['twist']['k'], meta['twist']['deg']), 'head %.1f' % meta['head_deg'],
                      'skirt %.1f' % meta['skirt_deg'], 'legk %.3f %.3f short %.1f %.1f' % (meta['R']['k'], meta['L']['k'], meta['R']['short'], meta['L']['short']),
                      'armk R %.2f %.2f L %.2f %.2f' % (*meta['arm_R']['k'], *meta['arm_L']['k']), 'staff %.0f corr %.0f' % (meta['staff']['deg'], meta['staff']['top_corr_deg']),
                      'lant %.0f' % meta['lantern_deg'], 'lie %.0f' % meta['lie_deg'], 'lost', {k: v for k, v in lost.items() if v}, flush=True)
            if a.gif and not a.frames:
                os.makedirs(os.path.join(a.out, '..', 'gifs'), exist_ok=True)
                gif([f'{a.out}/{act}_{F}_f{i:02d}.png' for i in range(n)], os.path.join(a.out, '..', 'gifs', f'{act}_{F}.gif'),
                    hold_last=600 if act == 'death' else 0)
    json.dump(dict(cfg=CFG, frames=info), open(infop, 'w'), indent=1, default=float)
