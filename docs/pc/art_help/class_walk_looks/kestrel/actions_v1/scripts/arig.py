"""Kestrel actions v1 - the painted-part rig for idle, attack, skill, hit and death (S and E; W and N are game-side mirrors).

Same method as the LOCKED walk (v3_claude): every part is cut from the approved target and bent onto the blockout joints
(blockout/joints_actions_512.json, rendered by act_blockout.py) with smooth mesh skinning, so there is no cut at a shoulder,
elbow or knee. Per frame i and facing F:
  torso   the upper body (body_F: torso, hood and face, quiver, cloak; arms and bow cut away and the holes filled) is placed by
          one similarity: scale s (the walk's), rotated by the change of the blockout's pelvis -> neck axis since idle f00 and
          foreshortened along that axis by its length change (hit recoil, death fall), pinned at the painted pelvis, which
          follows the blockout pelvis. At idle f00 it sits exactly as the walk does (x on the hip centre, hood top on the
          clay's head-top row).
  cloak   two panels with lag, skinned on the same mesh (weights in wcape_F, feathered: no cut): the upper panel turns about
          the shoulder, the lower about the hip line; each lags the torso angle (an exponential follower) and trails the
          pelvis velocity, the lower one more.
  legs    the walk's continuous painted legs (leg_F / legfar_F, 3-bone skin, krig.mesh); the feet lie on the blockout heel
          and toe joints, pinned at the heel, so a planted foot only moves when the blockout foot moves.
  arms    one continuous painted arm per side (shoulder -> elbow -> fist, 2-bone skin, elbow blend +-16 target px), hung on
          the torso's painted shoulder and solved by 2D IK onto the blockout hand (offset into the painted body), bending to
          the blockout elbow's side; bone lengths follow the blockout's projected foreshortening.
  bow     held: rigid with the bow forearm (the painted bow and string, limbs down: the walk / idle rule). Raised: the
          painted limbs are warped along the blockout bow's projected chord and belly (belly toward the aim, string toward
          her); the string is drawn tip -> nock -> tip (straight when braced or loosed). Fist drawn over the grip.
  arrow   its own piece: shaft, fletching and head from nock to tip along the blockout aim while drawn.
  covers  the pauldron / cloak over each shoulder is redrawn over the arm root.
Render at RS x the cell (3), area-downsample to 512x360, binary alpha, black under alpha 0.
Death: the fall leaves the cell bottom (E lands toward the camera, below the pivot row). The whole figure is lifted by the
smallest eased shift that keeps it inside the cell (see README).
usage: arig.py [--only SE] [--acts idle,attack,skill,hit,death] [--frames 0,6] [--out DIR] [--gif]"""
import os, sys, json, math, argparse, numpy as np, cv2
from PIL import Image, ImageOps
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, '../../v3_claude/scripts')))
import krig
from krig import unit, apm, bone_M, ik_knee
AP = os.environ.get('KAPARTS', os.path.join(HERE, '..', 'parts'))
BLK = os.environ.get('KABLOCK', os.path.join(HERE, '..', 'blockout'))
CW, CH, PIV, FPS = 512, 360, (256, 329), 17.144
PADB = 200                                   # extra rows under the cell while rendering (death shift), cropped after
ACTS = {'idle': 12, 'attack': 12, 'skill': 12, 'hit': 8, 'death': 13}
LOOP = {'idle', 'attack', 'skill', 'hit'}    # these start and end on the idle pose
JA = json.load(open(f'{BLK}/joints_actions_512.json'))
META = JA['meta']; JF = JA['facings']; HH = META['world_height_units']; PXW = 512 / 494.6236559139785
ARIG = {F: json.load(open(f'{AP}/arig_{F}.json')) for F in 'SE'}
LRIG = krig.RIG
CFG = {
 'S': dict(s=253 / 686, elbow_blend=16.0, len_clip=(0.40, 1.25), cape_lag=(0.35, 0.65), cape_trail=(0.25, 0.55),
           cape_follow=0.45, idle_sway=(0.6, 1.4), string=(112, 98, 76), death_fold_rot=(-20.0, -25.0), fore_max=1.22, up_max=2.2, arrow_len=1.0, bow_k=0.92),
 'E': dict(s=247 / 665, elbow_blend=16.0, len_clip=(0.40, 1.25), cape_lag=(0.35, 0.65), cape_trail=(0.25, 0.55),
           cape_follow=0.45, idle_sway=(0.6, 1.4), string=(70, 62, 52), death_fold_rot=(0.0, 0.0), fore_max=1.22, up_max=2.2, arrow_len=1.0, bow_k=0.92),
}
for F_ in 'SE': CFG[F_].update({k: krig.CFG[F_][k] for k in ('foot_o', 'foot_k', 'stretch_max', 'stance_kmin', 'far_dark', 'reach')})

def fr(F, act, i): return JF[f'{act}_{F}'][f'f{i:02d}']
def jt(F, act, i, k): return np.array(fr(F, act, i)['joints'][k], float)
def ang(v): return math.atan2(v[1], v[0])
def R2(a): c, s_ = math.cos(a), math.sin(a); return np.array([[c, -s_], [s_, c]])

# ------------------------------------------------------------------ textures (premultiplied float)
TEX = {}
def tex(path):
    if path not in TEX:
        im = np.asarray(Image.open(path).convert('RGBA')).astype(np.float32) / 255.
        TEX[path] = np.dstack([im[..., :3] * im[..., 3:], im[..., 3:]])
    return TEX[path]
def ptex(name): return tex(f'{AP}/{name}.png')

# ------------------------------------------------------------------ mesh warp (piecewise affine, vectorised)
def grid_mesh(alpha, step=4, pad=3):
    a = alpha > 0.01; ys, xs = np.nonzero(a)
    x0, x1, y0, y1 = xs.min() - step, xs.max() + step, ys.min() - step, ys.max() + step
    gx = np.arange(x0, x1 + step, step); gy = np.arange(y0, y1 + step, step)
    V = np.stack(np.meshgrid(gx, gy), -1).reshape(-1, 2).astype(np.float64); nx = len(gx)
    ad = cv2.dilate(a.astype(np.uint8), np.ones((2 * pad + 1, 2 * pad + 1), np.uint8))
    ii = []
    for r in range(len(gy) - 1):
        ya = gy[r]
        for q in range(nx - 1):
            xa = gx[q]
            if ad[max(ya, 0):ya + step + 1, max(xa, 0):xa + step + 1].any(): ii.append(r * nx + q)
    v0 = np.array(ii); tris = np.concatenate([np.stack([v0, v0 + 1, v0 + nx + 1], 1), np.stack([v0, v0 + nx + 1, v0 + nx], 1)])
    return V, tris

def warp(T, V, Vd, tris, H, W):
    """T premult texture (target px); V source vertices, Vd destination vertices (canvas px); triangles drawn in order."""
    D = Vd[tris]; S = V[tris]
    # per triangle affine dst -> src
    dA = np.concatenate([D, np.ones(D.shape[:2] + (1,))], 2)               # (t,3,3)
    ok = np.abs(np.linalg.det(dA)) > 1e-6
    A = np.zeros((len(tris), 2, 3))
    A[ok] = np.transpose(np.linalg.solve(dA[ok], S[ok]), (0, 2, 1))
    idx = np.full((H, W), -1, np.int32)
    Di = np.round(D * 16).astype(np.int32)
    for t in np.nonzero(ok)[0]: cv2.fillConvexPoly(idx, Di[t], int(t), lineType=cv2.LINE_8, shift=4)
    yy, xx = np.nonzero(idx >= 0); tt = idx[yy, xx]
    mapx = np.full((H, W), -1e4, np.float32); mapy = np.full((H, W), -1e4, np.float32)
    mapx[yy, xx] = A[tt, 0, 0] * xx + A[tt, 0, 1] * yy + A[tt, 0, 2]
    mapy[yy, xx] = A[tt, 1, 0] * xx + A[tt, 1, 1] * yy + A[tt, 1, 2]
    return cv2.remap(T, mapx, mapy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0), (mapx, mapy)

def remap_with(T, maps): return cv2.remap(T, maps[0], maps[1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
def over(dst, src): return src + dst * (1 - src[..., 3:])
def lbs(V, W, Ms): return sum(W[:, j:j + 1] * (V @ M[:, :2].T + M[:, 2]) for j, M in enumerate(Ms))
def ss(t): t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)

_MESH = {}
def body_mesh(F):
    if F not in _MESH:
        A = np.maximum(ptex(f'body_{F}')[..., 3], ptex(f'front_{F}')[..., 3]); V, tris = grid_mesh(A, 4)
        wc = np.asarray(Image.open(f'{AP}/wcape_{F}.png').convert('RGB')).astype(np.float32) / 255.
        xi = np.clip(V[:, 0].astype(int), 0, 1279); yi = np.clip(V[:, 1].astype(int), 0, 719)
        wu, wl = wc[yi, xi, 0], wc[yi, xi, 1]; W = np.stack([np.clip(1 - wu - wl, 0, 1), wu, wl], 1); W /= W.sum(1, keepdims=True)
        _MESH[F] = (V, tris, W)
    return _MESH[F]

def arm_mesh(F, sd):
    key = ('arm', F, sd)
    if key not in _MESH:
        A = ptex(f'arm_{sd}_{F}')[..., 3]; V, tris = grid_mesh(A, 3)
        J = ARIG[F]['arms'][sd]; Sh, El, Hd = (np.array(J[k], float) for k in ('shoulder', 'elbow', 'hand'))
        mk = unit(unit(El - Sh) + unit(Hd - El)); b = CFG[F]['elbow_blend']
        w = ss(((V - El) @ mk + b) / (2 * b)); W = np.stack([1 - w, w], 1)
        order = np.argsort(W[tris].mean(1)[:, 1], kind='stable')
        _MESH[key] = (V, tris[order], W)
    return _MESH[key]

def strip_mesh(line, w, step=3.0):
    """quad strip along the bow centre line: source vertices, their arc fraction t and signed across offset."""
    P = np.array(line, float); seg = np.linalg.norm(np.diff(P, axis=0), axis=1); cum = np.concatenate([[0], np.cumsum(seg)])
    L = cum[-1]; ts = np.arange(0, L + 1e-6, step); ts[-1] = L
    pts = np.stack([np.interp(ts, cum, P[:, 0]), np.interp(ts, cum, P[:, 1])], 1)
    tg = np.gradient(pts, axis=0); tg /= np.linalg.norm(tg, axis=1, keepdims=True); nn = np.stack([-tg[:, 1], tg[:, 0]], 1)
    offs = np.linspace(-w, w, 5); V, T, O = [], [], []
    for k in range(len(ts)):
        for o in offs: V.append(pts[k] + nn[k] * o); T.append(ts[k] / L); O.append(o)
    n = len(offs); tris = []
    for k in range(len(ts) - 1):
        for j in range(n - 1):
            a = k * n + j; tris += [(a, a + 1, a + n + 1), (a, a + n + 1, a + n)]
    return np.array(V), np.array(T), np.array(O), np.array(tris), pts, ts / L

# ------------------------------------------------------------------ the torso transform
def torso_axis(F, act, i):
    return jt(F, act, i, 'neck') - jt(F, act, i, 'pelvis')

def torso_M(F, act, i):
    """target px -> cell px for the rigid torso: scale s, rotation and along-axis foreshortening from the blockout."""
    c = CFG[F]; s = c['s']; R = ARIG[F]; LR = LRIG[F]
    hc_t = (np.array(LR['hips']['near'], float) + np.array(LR['hips']['far'], float)) / 2       # painted hip centre (walk rule)
    u0 = torso_axis(F, 'idle', 0); ui = torso_axis(F, act, i)
    phi = (ang(ui) - ang(u0) + math.pi) % (2 * math.pi) - math.pi; k = float(np.clip(np.linalg.norm(ui) / np.linalg.norm(u0), 0.35, 1.15))
    e = unit(u0); Sx = np.eye(2) + (k - 1) * np.outer(e, e)
    A = R2(phi) @ Sx * s
    # idle f00 placement = the walk rule: x of the painted hip centre on the blockout hip centre, hood top on the clay top row
    hb0 = (jt(F, 'idle', 0, 'L_hip') + jt(F, 'idle', 0, 'R_hip')) / 2
    top0 = clay_top(F, 'idle', 0)
    t0 = np.array([hb0[0] - s * hc_t[0], top0 - s * LR['top']])
    d0 = s * hc_t + t0 - jt(F, 'idle', 0, 'pelvis')          # painted hip centre vs the blockout pelvis at idle
    piv = jt(F, act, i, 'pelvis') + R2(phi) @ (Sx @ d0)
    t = piv - A @ hc_t
    return np.hstack([A, t[:, None]]), dict(phi=math.degrees(phi), k=k)

_CT = {}
def clay_top(F, act, i):
    if (F, act, i) not in _CT:
        a = np.asarray(Image.open(f'{BLK}/clay/kestrel_{act}_{F}_f{i:02d}.png').convert('RGBA'))[..., 3] > 127
        _CT[(F, act, i)] = int(np.nonzero(a[:, 150:362].any(1))[0].min())
    return _CT[(F, act, i)]

def squash_about(M, p, d, k):
    """compose: after M, scale by k along unit direction d about cell point p."""
    S = np.eye(2) + (k - 1) * np.outer(d, d); A = S @ M[:, :2]; t = S @ (M[:, 2] - p) + p
    return np.hstack([A, t[:, None]])

def rot_about(M, p, a):
    """compose: after M, rotate by a (rad) about cell point p."""
    Rr = R2(a); A = Rr @ M[:, :2]; t = Rr @ (M[:, 2] - p) + p
    return np.hstack([A, t[:, None]])

# ------------------------------------------------------------------ cloak lag
def cape_angles(F, act):
    """per frame (upper, lower) panel angle in rad: an exponential follower of the torso angle (lag) plus a trail against the
    pelvis velocity; idle adds a slow sway. Loops are run three times so the cycle is seamless."""
    c = CFG[F]; n = ACTS[act]
    phi = np.array([torso_M(F, act, i)[1]['phi'] for i in range(n)]); pel = np.array([jt(F, act, i, 'pelvis') for i in range(n)])
    reps = 3 if act in LOOP else 1
    ph = np.tile(phi, reps); pv = np.tile(pel, (reps, 1))
    vel = np.diff(pv[:, 0], prepend=pv[0, 0]) if act not in LOOP else np.diff(np.concatenate([pv[-1:, 0], pv[:, 0]]))
    out = []
    for lag, trail in ((c['cape_lag'][0], c['cape_trail'][0]), (c['cape_lag'][1], c['cape_trail'][1])):
        f = ph[0]; vf = 0.0; res = []
        for j in range(len(ph)):
            f = f + (ph[j] - f) * (1 - lag)                # follower of the torso angle (deg)
            vf = vf + (vel[j] - vf) * (1 - lag)
            res.append(math.radians((f - ph[j]) * c['cape_follow']) + math.radians(trail * vf * 4.0))
        out.append(np.array(res[-n:]))
    if act == 'idle':
        t = np.arange(n) / n * 2 * math.pi
        out[0] = out[0] + np.radians(c['idle_sway'][0]) * np.sin(t - 0.8); out[1] = out[1] + np.radians(c['idle_sway'][1]) * np.sin(t - 1.6)
    if act == 'death':                                  # the cloak settles with the body: no lag left once she lies still
        w = np.clip(1 - (np.arange(n) - 8) / 4, 0, 1); out = [o * w for o in out]
    return out

# ------------------------------------------------------------------ legs (walk parts, walk rules)
def leg_pose(F, act, i, sd, Mt):
    c = CFG[F]; s = c['s']; R = LRIG[F]
    H, K, A = (np.array(R[k], float) for k in ('H', 'K', 'A'))
    hc_t = (np.array(R['hips']['near'], float) + np.array(R['hips']['far'], float)) / 2
    hv = (jt(F, act, i, 'L_hip') - jt(F, act, i, 'R_hip')) / 2
    hip = apm(Mt, hc_t) + (hv if sd == 'L' else -hv)
    he_d, to_d = jt(F, act, i, sd + '_heel'), jt(F, act, i, sd + '_toe'); he_s, to_s = np.array(R['heel'], float), np.array(R['toe'], float)
    kf = float(np.clip(math.dist(he_d, to_d) / (s * math.dist(he_s, to_s)), *c['foot_k']))
    u = unit(to_s - he_s); n = np.array([-u[1], u[0]]); v = unit(to_d - he_d); m = np.array([-v[1], v[0]])
    L = np.outer(v, u) * s * kf + np.outer(m, n) * s
    Mf = np.hstack([L, (he_d - L @ he_s)[:, None]]); Mf[:, 2] += np.array(c['foot_o'], float)
    an = apm(Mf, A); Lt0, Ls0 = s * math.dist(H, K), s * math.dist(K, A); D = math.dist(hip, an)
    k = max(D / (c['reach'] * (Lt0 + Ls0)), c['stance_kmin']); kc = min(k, c['stretch_max']); pull = 0.0
    if k > kc:
        an2 = hip + unit(an - hip) * (Lt0 + Ls0) * kc * c['reach']; Mf = Mf.copy(); Mf[:, 2] += an2 - an; pull = math.dist(an2, an); an = an2
    kn = ik_knee(hip, an, Lt0 * kc, Ls0 * kc, jt(F, act, i, sd + '_knee'))
    return dict(Mt=bone_M(H, K, hip, kn, s), Ms=bone_M(K, A, kn, an, s), Mf=Mf, hip=hip, knee=kn, ankle=an,
                heel=apm(Mf, R['heel']), toe=apm(Mf, R['toe']), k=kc, pull=pull)

def near_leg(F, act, i):
    o = fr(F, act, i)['draw_order']; return 'L' if o.index('L_boot') < o.index('R_boot') else 'R'

# ------------------------------------------------------------------ arms
def arm_pose(F, act, i, sd, Mt, phi, hand_target=None):
    """the painted shoulder rides on the torso; elbow and hand are the blockout's, moved into the painted body: at rest by
    the painted-vs-blockout offset of that joint at idle f00 (turned with the torso), when raised by the shoulder offset
    (so the arm keeps the blockout's shape off the painted shoulder). The upper arm may stretch up to up_max (it is mostly
    the grown sleeve), the forearm to fore_max; beyond that the elbow / hand come in along the bone."""
    c = CFG[F]; s = c['s']; J = ARIG[F]['arms'][sd]
    Sh, El, Hd = (np.array(J[k], float) for k in ('shoulder', 'elbow', 'hand'))
    sh = apm(Mt, Sh)
    b = lambda a, ii, k: jt(F, a, ii, f'{sd}_{k}')
    M0, _ = torso_M(F, 'idle', 0); rot = R2(math.radians(phi))
    d_el = apm(M0, El) - b('idle', 0, 'elbow'); d_hd = apm(M0, Hd) - b('idle', 0, 'hand')
    d_sh = sh - b(act, i, 'shoulder')
    r = float(fr(F, act, i)['key'].get('raise_', 0.0))
    el = b(act, i, 'elbow') + (1 - r) * (rot @ d_el) + r * d_sh
    hd = b(act, i, 'hand') + (1 - r) * (rot @ d_hd) + r * d_sh
    if hand_target is not None: el = el + (np.asarray(hand_target, float) - hd); hd = np.asarray(hand_target, float)
    l1p, l2p = s * math.dist(Sh, El), s * math.dist(El, Hd); short = 0.0
    if math.dist(sh, el) > l1p * c['up_max']: el = sh + unit(el - sh) * l1p * c['up_max']
    if math.dist(el, hd) > l2p * c['fore_max']:
        h2 = el + unit(hd - el) * l2p * c['fore_max']; short = math.dist(h2, hd); hd = h2
    Mu = bone_M(Sh, El, sh, el, s); Mf = bone_M(El, Hd, el, hd, s)
    return dict(Mu=Mu, Mf=Mf, sh=sh, el=el, hand=hd, short=short, f=(math.dist(sh, el) / l1p, math.dist(el, hd) / l2p))

def fore_rigid(F, sd, P):
    """similarity of the forearm bone (scale s, no stretch): the held bow rides on it."""
    J = ARIG[F]['arms'][sd]; El, Hd = np.array(J['elbow'], float), np.array(J['hand'], float); s = CFG[F]['s']
    a = ang(P['hand'] - P['el']) - ang(Hd - El); A = R2(a) * s
    return np.hstack([A, (P['hand'] - A @ Hd)[:, None]])

# ------------------------------------------------------------------ bow and arrow
def bow_aimed(F, act, i, hand, RS, canvas):
    """warp the painted limbs along the blockout bow: chord top -> bottom, belly bulge toward the aim."""
    c = CFG[F]; R = ARIG[F]; j = fr(F, act, i)['joints']
    g = np.array(j['bow_grip']); top = np.array(j['bow_top']); bot = np.array(j['bow_bot']); bel = np.array(j['bow_belly'])
    kb = c['bow_k']; sh = hand - g
    P = lambda p: g + (np.asarray(p) - g) * kb + sh
    top_c, bot_c, bel_c = P(top), P(bot), P(bel)
    V, T, O, tris, pts, tt = strip_mesh(R['bow_line'], R['bow_w'] / 2 + 2)
    # source chord frame
    s0, s1 = pts[0], pts[-1]; ch = s1 - s0; L0 = np.linalg.norm(ch); e = ch / L0; nrm_ = np.array([-e[1], e[0]])
    gs = np.array(R['grip'], float); tg = float(np.clip((gs - s0) @ e / L0, 0.2, 0.8))
    off_src = (pts - s0) @ nrm_                                                # bulge of the painted limbs off their chord
    belly_src = float(np.interp(tg, tt, off_src))
    # destination chord; the grip sits at the same fraction; bulge scaled by the projected belly
    ch2 = bot_c - top_c; L1 = np.linalg.norm(ch2); e2 = ch2 / max(L1, 1e-6); n2 = np.array([-e2[1], e2[0]])
    belly_dst = (bel_c - (top_c + ch2 * tg)) @ n2 if L1 > 1 else 0.0
    gproj = top_c + ch2 * tg
    bulge_k = belly_dst / belly_src if abs(belly_src) > 1e-3 else 0.0
    # where the grip lands after the bulge must be the hand: shift the whole bow so it does
    Vd = []
    s = c['s']
    for v, t_, o in zip(V, T, O):
        base = top_c + ch2 * t_ + n2 * (np.interp(t_, tt, off_src) * bulge_k)
        Vd.append(base + n2 * o * s * np.sign(bulge_k if bulge_k else 1))
    Vd = np.array(Vd)
    grip_after = gproj + n2 * belly_src * bulge_k
    Vd += hand - grip_after
    tips = (top_c + hand - grip_after, bot_c + hand - grip_after)
    img, _ = warp(ptex(f'bow_aim_{F}'), V, Vd * RS, tris, *canvas)
    return img, tips, hand - g

def draw_line(img, pts, rgb, w, RS):
    """antialiased poly-line painted into a premultiplied canvas (string)."""
    lay = np.zeros(img.shape[:2], np.uint8)
    P = (np.array(pts) * RS * 16).astype(np.int32)
    cv2.polylines(lay, [P.reshape(-1, 1, 2)], False, 255, max(1, int(round(w * RS))), cv2.LINE_AA, shift=4)
    a = lay.astype(np.float32)[..., None] / 255.
    col = np.dstack([np.full(img.shape[:2], v / 255., np.float32) for v in rgb])
    src = np.dstack([col * a, a]); return over(img, src)

ARROW = None
def arrow_tex():
    """the arrow, painted once at 4x cell detail along +x (nock at x=0): ash shaft with a lit edge, three grey-brown fletches
    sampled from the quiver's feathers, a dark iron head."""
    global ARROW
    if ARROW is None:
        L, Wd = 300, 24; im = np.zeros((Wd, L, 4), np.float32); cy = Wd / 2
        yy, xx = np.mgrid[0:Wd, 0:L].astype(np.float32)
        shaft = (np.abs(yy - cy) <= 2.2) & (xx >= 4) & (xx <= L - 34)
        im[shaft, :3] = [0.42, 0.31, 0.19]; im[shaft & (yy < cy - 0.5), :3] = [0.58, 0.45, 0.30]; im[shaft, 3] = 1
        for k, (o, col) in enumerate(((-1, (0.55, 0.50, 0.42)), (1, (0.47, 0.42, 0.35)))):
            fl = (xx >= 8) & (xx <= 64) & (o * (yy - cy) > 1.5) & (o * (yy - cy) < 2 + 7 * (1 - np.abs((xx - 40) / 30)).clip(0, 1) ** 0.6 * (xx < 64))
            im[fl, :3] = col; im[fl, 3] = 1
            stripe = fl & (((xx.astype(int) // 6) % 2) == 0); im[stripe, :3] *= 0.85
        head = (xx >= L - 36) & (np.abs(yy - cy) <= (L - xx) * 0.24) & (xx <= L - 1)
        im[head, :3] = [0.22, 0.22, 0.24]; im[head & (yy < cy), :3] = [0.38, 0.38, 0.40]; im[head, 3] = 1
        nock = (xx < 6) & (np.abs(yy - cy) <= 3); im[nock, :3] = [0.30, 0.22, 0.14]; im[nock, 3] = 1
        im = cv2.GaussianBlur(im, (0, 0), 0.5)
        ARROW = np.dstack([im[..., :3] * im[..., 3:], im[..., 3:]])
    return ARROW

def arrow_piece(nock, tip, RS, canvas):
    T = arrow_tex(); L = np.linalg.norm(np.subtract(tip, nock))
    if L < 3: return None
    u = unit(np.subtract(tip, nock)); n = np.array([-u[1], u[0]]); k = L / T.shape[1]
    wk = min(1.0, max(0.55, k * 2.2)) * 0.32           # cell width of the 24 px texture: ~2.5 px wide shaft region
    M = np.zeros((2, 3)); M[:, 0] = u * k * RS; M[:, 1] = n * wk * RS; M[:, 2] = (np.asarray(nock) - n * wk * T.shape[0] / 2) * RS
    return cv2.warpAffine(T, M, (canvas[1], canvas[0]), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)

# ------------------------------------------------------------------ frame
def render(F, act, i, RS=3, shift=0.0):
    c = CFG[F]; Hc, Wc = (CH + PADB) * RS, CW * RS; canvas = (Hc, Wc)
    Mt, tinfo = torso_M(F, act, i)
    capes = CAPE.setdefault((F, act), cape_angles(F, act))
    au, al_ = capes[0][i], capes[1][i]
    R = ARIG[F]
    pu = apm(Mt, R['cape_upper']); hy = sum(R['cape_lower_y']) / 2
    hinge_t = (R['cape_upper'][0] - 40 if F == 'S' else R['cape_upper'][0] - 20, hy)
    Mu = rot_about(Mt, pu, au); Ml = rot_about(Mu, apm(Mu, hinge_t), al_)
    if act == 'death':
        # lying down, the cloak falls onto the ground around her instead of hanging off the body: both panels fold in
        # toward their hinge along the cloth's own hanging direction (the painted 'down', turned with the torso)
        wf = float(np.clip(abs(tinfo['phi']) / 55.0, 0, 1)); wf = wf * wf * (3 - 2 * wf)
        dn = np.array([0.0, 1.0])          # on the ground the cloth can only recede up the screen, never hang below
        fr_ = CFG[F]['death_fold_rot']           # and swing along the body toward her feet
        Mu = rot_about(Mu, pu, math.radians(fr_[0]) * wf); Ml = rot_about(Ml, pu, math.radians(fr_[0]) * wf)
        Ml = rot_about(Ml, apm(Mu, hinge_t), math.radians(fr_[1]) * wf)
        hc = apm(Mu, hinge_t)
        Mu = squash_about(Mu, pu, dn, 1 - 0.5 * wf); Ml = squash_about(Ml, hc, dn, 1 - 0.5 * wf)
        Ml = squash_about(Ml, apm(Mu, hinge_t), dn, 1 - 0.5 * wf)
        meta_fold = wf
    else: meta_fold = 0.0
    V, tris, W = body_mesh(F)
    Vd = lbs(V, W, (Mt, Mu, Ml))
    if act == 'death' and meta_fold > 0:
        # cloth lying on the ground cannot hang below the body's lowest contact: everything under that floor row is
        # compressed toward it (a per-vertex squash of the same mesh, so the hem stays ragged and there is no cut)
        floor = max(max(jt(F, act, i, f'{sd}_{k}')[1] for sd in 'RL' for k in ('heel', 'toe')), jt(F, act, i, 'pelvis')[1] + 30) + 4
        lo = Vd[:, 1] > floor
        Vd[lo, 1] = floor + (Vd[lo, 1] - floor) * (1 - 0.7 * meta_fold)
    Vd = Vd * RS
    body, maps = warp(ptex(f'body_{F}'), V, Vd, tris, *canvas)
    front = remap_with(ptex(f'front_{F}'), maps)
    img = np.zeros((Hc, Wc, 4), np.float32); meta = dict(torso=tinfo, cape=[math.degrees(au), math.degrees(al_)], cape_fold=meta_fold)
    # legs
    legs = {sd: leg_pose(F, act, i, sd, Mt) for sd in 'RL'}
    nr = near_leg(F, act, i); legs_a = np.zeros(canvas, np.float32); leg_imgs = []
    for sd in [x for x in 'RL' if x != nr] + [nr]:
        P = legs[sd]; name = f'leg_{F}' if sd == 'L' else f'legfar_{F}'
        Vl, tl, Wl = krig.mesh(F, name)
        Ld, _ = warp(krig.tex(name), Vl, lbs(Vl, Wl, (P['Mt'], P['Ms'], P['Mf'])) * RS, tl, *canvas)
        if sd != nr: Ld[..., :3] *= c['far_dark']
        legs_a = np.maximum(legs_a, Ld[..., 3]); leg_imgs.append(Ld)
        meta[sd] = {k: (v.tolist() if isinstance(v, np.ndarray) and v.ndim == 1 else v) for k, v in P.items() if k not in ('Mt', 'Ms', 'Mf')}
    # arms
    phi = tinfo['phi']; arms = {}
    key = fr(F, act, i)['key']; r = key.get('raise_', 0.0); drawn = fr(F, act, i)['drawn']
    arms['R'] = arm_pose(F, act, i, 'R', Mt, phi)
    bow_img = None; arrow_img = None; string_pts = None
    if r > 0.02:
        bow_img, tips, gshift = bow_aimed(F, act, i, arms['R']['hand'], RS, canvas)
        j = fr(F, act, i)['joints']; g = np.array(j['bow_grip'])
        nock = np.array(j['nock']) * 1.0
        nock_c = arms['R']['hand'] + (nock - g) * c['bow_k']
        if drawn:
            tip_c = arms['R']['hand'] + (np.array(j['arrow_tip']) - g) * c['bow_k']
            arrow_img = arrow_piece(nock_c, tip_c, RS, canvas)
            string_pts = [tips[0], nock_c, tips[1]]
            arms['L'] = arm_pose(F, act, i, 'L', Mt, phi, hand_target=nock_c)
        else:
            string_pts = [tips[0], tips[1]]
        meta['nock'] = nock_c.tolist(); meta['bow_tips'] = [t.tolist() for t in tips]
    if 'L' not in arms: arms['L'] = arm_pose(F, act, i, 'L', Mt, phi)
    arm_imgs = {}
    for sd in 'RL':
        P = arms[sd]; Va, ta, Wa = arm_mesh(F, sd)
        arm_imgs[sd], _ = warp(ptex(f'arm_{sd}_{F}'), Va, lbs(Va, Wa, (P['Mu'], P['Mf'])) * RS, ta, *canvas)
        meta['arm_' + sd] = dict(sh=P['sh'].tolist(), el=P['el'].tolist(), hand=P['hand'].tolist(), short=P['short'], f=P['f'])
    if bow_img is None:
        Mb = fore_rigid(F, 'R', arms['R'])
        if act == 'death' and meta_fold > 0:
            # falling, the bow comes down with her and lies flat on the ground like the blockout bow, not sticking out
            bl = R['bow_line']; bv = np.subtract(bl[-1], bl[0]); cur = ang(Mb[:, :2] @ bv)
            jj = fr(F, act, i)['joints']; want = ang(np.subtract(jj['bow_bot'], jj['bow_top']))     # the blockout bow, lying
            d_ = (want - cur + math.pi) % (2 * math.pi) - math.pi
            g_ = apm(Mb, R['grip']); Mb = rot_about(Mb, g_, d_ * meta_fold)
            # and it slips out of her hand: the grip slides a third of the way in toward the body as it lands
            Mb = Mb.copy(); Mb[:, 2] += (jt(F, act, i, 'pelvis') - g_) * 0.35 * meta_fold
        bow_img = cv2.warpAffine(ptex(f'bow_hang_{F}'), (Mb * RS).astype(np.float32), (Wc, Hc), flags=cv2.INTER_LINEAR, borderValue=0)
    if string_pts is not None: bow_img = draw_line(bow_img, string_pts, c['string'], 0.7, RS)
    cov = {sd: cv2.warpAffine(ptex(f'cover_{F}_{sd}'), (Mt * RS).astype(np.float32), (Wc, Hc), flags=cv2.INTER_LINEAR, borderValue=0) for sd in 'RL'}
    # ---- composite (back to front)
    if F == 'S':
        # drawn: the draw arm's elbow is back behind the head, so the arm goes behind the body (the hand is at the far cheek)
        order = ([arm_imgs['L']] if r > 0.5 else []) + [body] + leg_imgs + [front] + ([] if r > 0.5 else [arm_imgs['L']]) + [cov['L']]
        order += ([arm_imgs['R'], bow_img] + ([arrow_img] if arrow_img is not None else [])) if r > 0.02 else [bow_img, arm_imgs['R']]
        order += [cov['R']]
    else:
        order = [arm_imgs['L']] + leg_imgs + [body, front, bow_img] + ([arrow_img] if arrow_img is not None else []) + [arm_imgs['R'], cov['R']]
    for L_ in order: img = over(img, L_)
    if F == 'S' and krig.CFG['S'].get('crotch_fill'):
        kn_y = min(meta['R']['knee'][1], meta['L']['knee'][1])
        img_c = img[:CH * RS]; la = legs_a[:CH * RS]
        meta['crotch_fill_px'] = krig.close_crotch('S', img_c, la, kn_y, RS); img[:CH * RS] = img_c
    meta['shift'] = shift; meta['raise'] = r; meta['drawn'] = drawn
    if shift:      # lift the whole figure (death only): rows come up from the padding under the cell
        k = int(round(shift * RS)); img = np.concatenate([img[k:], np.zeros((k,) + img.shape[1:], np.float32)], 0)
    return img, meta

CAPE = {}

def to_cell(img, RS): return krig.to_cell(np.ascontiguousarray(img[:CH * RS]), RS)

def bottom_of(img, RS):
    a = cv2.resize(img[..., 3], (CW, (CH + PADB)), interpolation=cv2.INTER_AREA) > 0.5
    ys = np.nonzero(a.any(1))[0]; return int(ys.max()) if len(ys) else 0

def death_shifts(F, RS=2):
    """smallest lift that keeps every death frame inside the cell (bottom row <= 359), eased and never decreasing."""
    n = ACTS['death']; need = []
    for i in range(n):
        img, _ = render(F, 'death', i, RS); need.append(max(0, bottom_of(img, RS) - 359))
    sh = np.maximum.accumulate(np.array(need, float))
    return [float(math.ceil(v)) for v in sh]

def gif(paths, out, bg=(172, 172, 172), mirror=False, hold_last=0):
    ims = []
    for p in paths:
        a = Image.open(p).convert('RGBA'); a = ImageOps.mirror(a) if mirror else a; b = Image.new('RGBA', a.size, bg + (255,)); b.alpha_composite(a)
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
            shifts = death_shifts(F) if act == 'death' else [0.0] * n
            for i in fl:
                img, meta = render(F, act, i, a.rs, shifts[i])
                Image.fromarray(to_cell(img, a.rs)).save(f'{a.out}/{act}_{F}_f{i:02d}.png')
                info.setdefault(F, {}).setdefault(act, {})[f'f{i:02d}'] = meta
                print(F, act, i, 'phi %.1f k %.2f' % (meta['torso']['phi'], meta['torso']['k']), 'legk %.3f %.3f pull %.1f %.1f' % (meta['R']['k'], meta['L']['k'], meta['R']['pull'], meta['L']['pull']),
                      'armshort %.1f %.1f' % (meta['arm_R']['short'], meta['arm_L']['short']), 'shift', meta['shift'], flush=True)
            if a.gif and not a.frames:
                gif([f'{a.out}/{act}_{F}_f{i:02d}.png' for i in range(n)], os.path.join(a.out, '..', 'gifs', f'{act}_{F}.gif'),
                    hold_last=600 if act == 'death' else 0)
    json.dump(dict(cfg=CFG, frames=info), open(infop, 'w'), indent=1, default=float)
