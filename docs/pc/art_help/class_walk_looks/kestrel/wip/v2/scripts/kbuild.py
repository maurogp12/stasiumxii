"""Kestrel walk v1 on Claude's v2 blockouts (hybrid, the Bastion v2 method).
 * body = the approved target minus its legs (cut_target.py), placed with one uniform scale s_up: hood top on the blockout
   head top (integer rows -> bob identical to the blockout), x on the pelvis. s_up fits the whole target (hood -> sole) into the
   v2 clay, so the target belt and the target leg length land at target scale.
 * legs = ONE target leg cut at target scale (thigh, boot shaft, boot foot), re-posed on the v2 joints: thigh from the v2
   hip, knee by 2-bone IK with the target thigh/shin ratio toward the v2 ankle (bend side = the blockout knee), foot rigid
   on the v2 heel/toe joints (planted joints move it exactly with the ground). 3 thigh keys per leg (fwd / down / back).
 * S: belt, pouches, tunic hem and bow drawn over the legs; E: the cape hangs over the legs; a dark under-tunic fill
   (back layer, inpainted from the cloak greens only) sits behind the legs so no background shows at the hem.
 * Mauro's Bastion v2 feedback is built in: (1) every leg piece is scaled by s_up across the bone and by <= 1.10 along it;
   (2) each leg is rooted at the target's own hip point (belt-corner hips + per-frame pelvis delta), the blockout joints
   give only the bend side and the foot-plant targets; (3) swing frames lower the foot / IK ankle (swing_drop, solved by
   swing_solve.py) so the visible swing peak is no higher than the blockout's.
 * Toe-off: S holds the visible ball of the boot on the ground (toe_pin 'full'); E follows the blockout toe joint
   (toe_pin 'off'), because the E blockout's toe joint sits ~7 px above its toe sole and the sole metric follows it.
usage: kbuild.py [--only SE] [--frames 0,1] [--out DIR]"""
import json, math, os, sys, argparse, numpy as np, cv2
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kcommon import *
TLEG = json.load(open(PARTS + 'target_legs.json'))
KCFG = {
 'S': dict(s_up=253 / 686, top=12, top_x=640, pelvis_tx=613, hips=dict(R=(600, 280), L=(650, 280)), src='L', belt=((541, 282), (709, 272)), drop=13.7, vls_ref=(1.05, 1.08), leg_k=1.0, stretch_max=1.10, foot_k=1.0, foot_o=[0.0, 0.0],
           keys=dict(fwd=1.05, down=1.0, back=0.92), key_deg=6.0, phase=[0.0, 0.0],
           string=[[(395, 196), (627, 505)]]),
 'E': dict(s_up=247 / 665, top=27, top_x=650, pelvis_tx=650, hips=dict(R=(675, 330), L=(625, 330)), src='R', belt=((600, 330), (700, 322)), drop=10.1, vls_ref=(0.83, 1.07), leg_k=1.0, stretch_max=1.10, foot_k=1.0, foot_o=[0.0, 0.0],
           keys=dict(fwd=1.05, down=1.0, back=0.92), key_deg=6.0, phase=[0.0, 0.0],
           string=[[(810, 158), (703, 561)], [(810, 158), (818, 228)]]),
}
OVR = os.path.join(HERE, 'kcfg.json')
if os.path.exists(OVR):
    for F, d in json.load(open(OVR)).items(): KCFG[F].update(d)

TEX = {}
RS = 1          # render scale (1 = the 512x360 cell; >1 = hi-res paint guides from the same rig, textures re-sampled at s_up*RS)
LEGB = json.load(open(PARTS + 'leg_b.json')) if os.path.exists(PARTS + 'leg_b.json') else {}
def canvas(): return (CW * RS, CH * RS)

def load_layers(F):
    """premultiplied float RGBA of each target layer, pre-resized to s_up (INTER_AREA); anchors scaled with it."""
    s = KCFG[F]['s_up']
    s = s * RS
    names = ['body', 'thigh', 'shin', 'foot', 'boot'] + [n for n in ('front', 'back', 'pelvis') if os.path.exists(f'{PARTS}{n}_{F}.png')]
    if KCFG[F].get('leg_one'): names.append('leg')
    for nm in names:
        p = f'{PARTS}{nm}_{F}.png' if nm in ('body', 'front', 'back', 'pelvis') else f'{PARTS}T{F}_{nm}.png'
        im = np.asarray(Image.open(p).convert('RGBA')).astype(np.float32) / 255.
        pm = np.dstack([im[..., :3] * im[..., 3:], im[..., 3:]])
        rz = (lambda x: cv2.resize(x, (round(pm.shape[1] * s), round(pm.shape[0] * s)), interpolation=cv2.INTER_AREA if s < 1 else cv2.INTER_CUBIC))
        TEX[(F, nm)] = np.clip(rz(pm), 0, 1)
        if nm == 'leg':
            A_ = anchors(F)
            for sg, tag in ((1.0, 'p'), (-1.0, 'n')):
                for key in ('fwd', 'back'):
                    TEX[(F, f'leg_{key}_{tag}')] = np.clip(rz(bend_thigh(F, pm, sg * KCFG[F]['key_sag'][key], A_)), 0, 1)
            continue
        if nm == 'thigh':
            for sg, tag in ((1.0, 'p'), (-1.0, 'n')):
                for key in ('fwd', 'back'):
                    b = bend_thigh(F, pm, sg * KCFG[F]['key_sag'][key])
                    TEX[(F, f'thigh_{key}_{tag}')] = cv2.resize(b, (round(pm.shape[1] * s), round(pm.shape[0] * s)), interpolation=cv2.INTER_AREA)

def bend_thigh(F, pm, sag, A=None):
    """v2 thigh keys (shape, not tone): bend the painted thigh along its hip->knee axis into an arc with sagitta `sag` target px
    toward +n (n = left normal of H->K), ends fixed (cross-sections are shifted, never scaled: across stays s_up, along stays 1).
    The fwd key bulges toward the travel side (quad / knee leading), the back key toward the trailing side (hamstring, knee
    trailing)."""
    A = A or TLEG[F]['anchors']; H, K = np.array(A['H'], float), np.array(A['K'], float); L = math.dist(H, K); u = unit(K - H); n = np.array([-u[1], u[0]])
    yy, xx = np.indices(pm.shape[:2]).astype(np.float32); t = np.clip(((xx - H[0]) * u[0] + (yy - H[1]) * u[1]) / L, 0, 1)
    d = sag * 4 * t * (1 - t)
    return cv2.remap(pm, (xx - n[0] * d).astype(np.float32), (yy - n[1] * d).astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)

def warp(F, nm, M):
    """M maps TARGET px -> cell; the texture is pre-scaled by s_up."""
    s = KCFG[F]['s_up']; Ms = M.copy(); Ms[:, :2] = M[:, :2] / s; Ms[:, 2] = M[:, 2] * RS
    return cv2.warpAffine(TEX[(F, nm)], Ms, canvas(), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)

def trunk_M(F, fr, f0):
    c = KCFG[F]; s = c['s_up']; drop = c['drop'] if c['drop'] is not None else 0.0
    ty = round(jnt(fr, 'head_top')[1] - drop - s * c['top']); tx = round(jnt(fr, 'pelvis')[0] - s * c['pelvis_tx'])
    return np.array([[s, 0, tx + c['phase'][0]], [0, s, ty + c['phase'][1]]], float)

def frame_M(A, B, P, Q, s_ax, s_w):
    """target segment A->B onto cell segment P->Q direction: along-axis scale s_ax, across scale s_w, A -> P."""
    u = unit(np.subtract(B, A)); n = np.array([-u[1], u[0]]); v = unit(np.subtract(Q, P)); m = np.array([-v[1], v[0]])
    L = np.outer(v, u) * s_ax + np.outer(m, n) * s_w
    return np.hstack([L, (np.asarray(P, float) - L @ np.asarray(A, float))[:, None]])

def ik_knee(hip, ank, L1, L2, kref):
    d = np.subtract(ank, hip); D = float(np.hypot(*d)); D = min(D, L1 + L2 - 1e-3); u = unit(d); n = np.array([-u[1], u[0]])
    a = (L1 * L1 - L2 * L2 + D * D) / (2 * D); h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    sg = 1.0 if np.dot(np.subtract(kref, hip), n) >= 0 else -1.0       # bend to the blockout knee's side
    return np.asarray(hip, float) + u * a + n * h * sg

def inv_aff(M):
    L = np.linalg.inv(M[:, :2]); return np.hstack([L, (-L @ M[:, 2])[:, None]])

def boot_skin(F, Ms, Mf):
    """the one-piece boot (target px texture) skinned on 2 bones: shaft (Ms) above the ankle, foot (Mf) below, blended over
    +-blend target px around the ankle line (smoothstep), inverted by fixed-point iteration (no seam, laces continuous)."""
    c = KCFG[F]; s = c['s_up']; A = anchors(F); bK, bA = np.array(A['bK'], float), np.array(A['bA'], float); us = unit(bA - bK)
    bl = c.get('boot_blend', 14.0)
    yy, xx = np.indices((CH * RS, CW * RS)).astype(np.float32); Q = np.stack([xx, yy], -1) / RS
    Is, If = inv_aff(Ms), inv_aff(Mf)
    ps = Q @ Is[:, :2].T + Is[:, 2]; pf = Q @ If[:, :2].T + If[:, 2]; p = ps.copy()
    for _ in range(4):
        t = ((p - bA) @ us + bl) / (2 * bl); w = np.clip(t, 0, 1); w = (w * w * (3 - 2 * w))[..., None]
        p = (1 - w) * ps + w * pf
    mp = (p * s * RS).astype(np.float32)
    return cv2.remap(TEX[(F, 'boot')], mp[..., 0], mp[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)

def leg_skin(F, tex, Mth, Msh, Mf):
    """the ONE-piece painted leg (hip -> sole) skinned on 3 bones (thigh / shin / foot) with smoothstep blends at the knee
    (+-knee_blend target px across the knee line) and the ankle (+-boot_blend): no seams, the knee rounds instead of breaking.
    Inverse warp by fixed-point iteration, each pixel seeded with the bone whose inverse is self-consistent."""
    c = KCFG[F]; s = c['s_up']; A = anchors(F); H, K, An = (np.array(A[k], float) for k in ('H', 'K', 'A'))
    ut, us = unit(K - H), unit(An - K); bk, ba = c.get('knee_blend', 16.0), c.get('boot_blend', 14.0)
    def wts(p):
        sk = np.clip(((p - K) @ ut + bk) / (2 * bk), 0, 1); sk = sk * sk * (3 - 2 * sk)
        sa = np.clip(((p - An) @ us + ba) / (2 * ba), 0, 1); sa = sa * sa * (3 - 2 * sa)
        return np.stack([1 - sk, sk * (1 - sa), sk * sa], -1)
    yy, xx = np.indices((CH * RS, CW * RS)).astype(np.float32); Q = np.stack([xx, yy], -1) / RS
    P = [Q @ inv_aff(M)[:, :2].T + inv_aff(M)[:, 2] for M in (Mth, Msh, Mf)]
    self_w = np.stack([wts(P[j])[..., j] for j in range(3)], -1); j0 = np.argmax(self_w, -1)
    p = np.choose(j0[..., None], P)
    for _ in range(5):
        w = wts(p); p = w[..., 0:1] * P[0] + w[..., 1:2] * P[1] + w[..., 2:3] * P[2]
    mp = (p * s * RS).astype(np.float32)
    return cv2.remap(TEX[(F, tex)], mp[..., 0], mp[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)

def shade_leg(L, hip, kn, an, far, c):
    """volume: a cylindrical light -> shadow gradient across each thigh / shin (warm key from the upper left: the screen-left side
    of the bone is lit), sampled as gains on the target's own legging values; the far leg is ~12 % darker for depth."""
    H_, W_ = L.shape[:2]; yy, xx = np.indices((H_, W_)).astype(np.float32); P = np.stack([xx, yy], -1) / RS
    out = np.zeros((H_, W_), np.float32) + 9e9; nn = np.zeros((H_, W_), np.float32)
    for a_, b_, hw in ((hip, kn, c.get('thigh_hw', 12.5)), (kn, an, c.get('shin_hw', 9.0))):
        a_, b_ = np.asarray(a_, float), np.asarray(b_, float); u = unit(b_ - a_); n = np.array([-u[1], u[0]])
        if n[0] > 0: n = -n                                     # n points to the screen-left (lit) side
        t = np.clip((P - a_) @ u, 0, math.dist(a_, b_)); foot = a_ + t[..., None] * u; d = np.linalg.norm(P - foot, axis=-1)
        sd = (P - a_) @ n; sel = d < out; out = np.where(sel, d, out); nn = np.where(sel, np.clip(sd / hw, -1.2, 1.2), nn)
    lam = np.clip(0.55 + 0.45 * nn - 0.25 * nn * nn, 0.0, 1.0)      # lit edge -> core shadow -> a little bounce on the far edge
    g = c.get('vol_lo', 0.80) + (c.get('vol_hi', 1.14) - c.get('vol_lo', 0.80)) * lam
    if far: g = g * (1.0 - c.get('far_dark', 0.12))
    warm = np.stack([1 + 0.04 * lam, 1 + 0.01 * lam, 1 - 0.03 * lam], -1)
    L = L.copy(); L[..., :3] = np.clip(L[..., :3] * g[..., None] * warm, 0, L[..., 3:]); return L

def thigh_key(F, fr, s):
    """fwd / down / back from the thigh's screen angle vs the hip->ankle line of the blockout (+ = knee ahead)."""
    hip, kn, an = jnt(fr, s + '_hip'), jnt(fr, s + '_knee'), jnt(fr, s + '_ankle')
    wd = np.array([2.0, 1.0]) / math.sqrt(5) if F == 'S' else np.array([2.0, -1.0]) / math.sqrt(5)
    v = unit(kn - hip); fwd = float(np.dot(v, wd)); deg = math.degrees(math.asin(max(-1, min(1, fwd))))
    return deg

_KM = {}
def thigh_key_c(F, i, s):
    """3 thigh keys by the blockout thigh's swing along the walk direction, relative to that leg's cycle mean (the iso
    projection adds a constant offset): fwd > +key_deg, back < -key_deg, else down."""
    W = frames(F)
    if (F, s) not in _KM: _KM[(F, s)] = float(np.mean([thigh_key(F, W[j], s) for j in range(12)]))
    deg = thigh_key(F, W[i], s) - _KM[(F, s)]; k = KCFG[F]['key_deg']
    return ('fwd' if deg > k else ('back' if deg < -k else 'down')), round(deg, 1)

def thigh_key2(F, hip, kn):
    """fwd / down / back by the thigh's screen angle from vertical (+ = knee toward the walk side, screen +x)"""
    v = unit(np.subtract(kn, hip)); deg = math.degrees(math.atan2(v[0], v[1])) - KCFG[F].get('key_mid', 0.0)
    k = KCFG[F]['key_deg']; return ('fwd' if deg > k else ('back' if deg < -k else 'down')), round(deg, 1)

_FL = {}
def flat_len(F, s):
    if (F, s) not in _FL:
        W = frames(F); pl = plants(F)[s]
        d = [math.dist(jnt(W[i], s + '_heel'), jnt(W[i], s + '_toe')) for i in range(12) if pl['heel'][i] and pl['toe'][i]]
        _FL[(F, s)] = float(np.median(d))
    return _FL[(F, s)]

_CP = {}
def contact_pts(F):
    """sole contact points of the target foot piece (target px): HB = lowest pixel of the rear 35 %, TB = lowest pixel of the
    front 35 % ('lowest' = along the foot normal, so it is the sole in the painted flat pose)."""
    if F not in _CP:
        A = anchors(F); he, to = np.array(A['heel'], float), np.array(A['toe'], float); u = unit(to - he); n = np.array([-u[1], u[0]])
        if n[1] < 0: n = -n
        if KCFG[F].get('boot_one'):
            a = np.asarray(Image.open(f'{PARTS}T{F}_{"leg" if KCFG[F].get("leg_one") else "boot"}.png').convert('RGBA'))[..., 3] > 127; ys, xs = np.nonzero(a); P = np.stack([xs, ys], 1).astype(float)
            bK, bA = np.array(A['bK'], float), np.array(A['bA'], float); us = unit(bA - bK); keep_ = (P - bA) @ us >= -10; P = P[keep_]
        else:
            a = np.asarray(Image.open(f'{PARTS}T{F}_foot.png').convert('RGBA'))[..., 3] > 127; ys, xs = np.nonzero(a); P = np.stack([xs, ys], 1).astype(float)
        t = (P - he) @ u; L = float(np.dot(to - he, u)); d = (P - he) @ n
        rear, front = t < t.min() + 0.35 * (L - t.min()), t > L - 0.35 * (L - t.min())
        _CP[F] = dict(HB=P[rear][np.argmax(d[rear])].tolist(), TB=P[front][np.argmax(d[front])].tolist())
    return _CP[F]

def apm(M, p): return M[:, :2] @ np.asarray(p, float) + M[:, 2]

def foot_M_base(F, fr, s, i, pl):
    """rigid foot on the blockout heel->toe frame (heel joint + foot_o), + foot_fix."""
    c = KCFG[F]; A = anchors(F); he, to = jnt(fr, s + '_heel'), jnt(fr, s + '_toe')
    u = unit(to - he); n = np.array([-u[1], u[0]]); sf = c['s_up'] * c['foot_k']; o = np.array(c['foot_o'], float)
    Ph = he + u * o[0] + n * o[1]
    fx = c.get('foot_fix', {}).get(s, [[0, 0]] * 12)[i]; Ph = Ph + np.array(fx, float)
    return frame_M(A['heel'], A['toe'], Ph, Ph + u, sf, sf)

def foot_ride(F, fr, s, i, pl):
    """the blockout pose of the foot: full plant / heel strike rigid on the heel joint (+ foot_o); toe-only rides the toe
    joint with the blockout's flat-foot heel->toe length (the material point on the toe joint stays put)."""
    c = KCFG[F]; hp, tp = pl[s]['heel'][i], pl[s]['toe'][i]
    if tp and not hp:
        he, to = jnt(fr, s + '_heel'), jnt(fr, s + '_toe'); u = unit(to - he); n = np.array([-u[1], u[0]]); o = np.array(c['foot_o'], float)
        fx = np.array(c.get('foot_fix', {}).get(s, [[0, 0]] * 12)[i], float); Ph = to + u * (o[0] - flat_len(F, s)) + n * o[1] + fx
        A = anchors(F); sf = c['s_up'] * c['foot_k']; return frame_M(A['heel'], A['toe'], Ph, Ph + u, sf, sf), to + fx
    fx = np.array(c.get('foot_fix', {}).get(s, [[0, 0]] * 12)[i], float)
    return foot_M_base(F, fr, s, i, pl), jnt(fr, s + '_heel') + fx

def foot_M(F, fr, s, i, pl):
    """full plant: rigid on the blockout heel/toe (moves with the ground). Pivot frames (toe-only = toe-off, heel-only = heel
    strike) take the blockout foot (angle, + foot_rot) and then, per pin mode, hold the VISIBLE sole contact point (TB = ball,
    HB = heel bottom of the boot piece) where the nearest full plant put it (carried with the ground):
      'full' = x and y held (no slide, no lift); 'x' = only x held (no slide along the ground; the height follows the blockout's
      toe / heel roll); 'off' = the blockout joint ride. Modes: toe_pin / heel_pin per facing."""
    c = KCFG[F]; W = frames(F); hp, tp = pl[s]['heel'][i], pl[s]['toe'][i]
    M, pv = foot_ride(F, fr, s, i, pl); cp = contact_pts(F)
    full = [pl[s]['heel'][j] and pl[s]['toe'][j] for j in range(12)]
    mode = c.get('toe_pin', 'full') if (tp and not hp) else (c.get('heel_pin', 'off') if (hp and not tp) else 'off')
    if mode is True: mode = 'full'
    if mode is False: mode = 'off'
    rd = c.get('foot_rot', {}).get(s, [0.0] * 12)[i]
    if rd:
        r = math.radians(rd); R = np.array([[math.cos(r), -math.sin(r)], [math.sin(r), math.cos(r)]])
        M = np.hstack([R @ M[:, :2], (R @ (M[:, 2] - pv) + pv)[:, None]])
    if mode != 'off' and any(full):
        if tp:   # toe-off: last full plant before i
            k = next(k for k in range(1, 13) if full[(i - k) % 12]); j = (i - k) % 12; key = 'TB'
        else:    # heel strike: first full plant after i
            k = -next(k for k in range(1, 13) if full[(i + k) % 12]); j = (i - k) % 12; key = 'HB'
        Pj = apm(foot_M_base(F, W[j], s, j, pl), cp[key]) + k * EXP[F]
        d = Pj - apm(M, cp[key])
        if mode == 'x': d[1] = 0.0
        M = M.copy(); M[:, 2] += d
    dr = c.get('swing_drop', {}).get(s, [0.0] * 12)[i]
    if dr and not (hp or tp): M = M.copy(); M[:, 2] += (0.0, dr)      # swing only: lower the foot (and the IK ankle) -> low peak
    return M

def anchors(F):
    A = dict(TLEG[F]['anchors']); A['H'] = KCFG[F]['hips'][KCFG[F]['src']]    # source-leg hip = its belt-corner hip
    if KCFG[F].get('leg_one') and F in LEGB:             # legs_sheet_b: one continuous leg (cut_legs_b.py)
        A.update({k: LEGB[F][k] for k in ('H', 'K', 'A', 'heel', 'toe')}); A.update(bK=LEGB[F]['K'], bA=LEGB[F]['A']); return A
    if KCFG[F].get('boot_one') and 'boot_anchors' in TLEG[F]:      # v2: the one-piece boot carries its own heel / toe / ankle / knee
        BA = TLEG[F]['boot_anchors']; A.update(heel=BA['heel'], toe=BA['toe'], bK=BA['K'], bA=BA['A'])
    return A

WD = {'S': np.array([2.0, 1.0]) / math.sqrt(5), 'E': np.array([2.0, -1.0]) / math.sqrt(5)}
_LG = {}
def leg_geo(F, i, sd):
    """hip (v2: target belt centre +- half the blockout hip vector), ankle (= the placed boot's ankle, i.e. the foot plant),
    knee by 2-bone IK at full target length (1 <= stretch <= 1.10 only when out of reach), bend side = blockout knee."""
    if (F, i, sd) in _LG: return _LG[(F, i, sd)]
    W = frames(F); fr = W[i]; f0 = W[0]; c = KCFG[F]; s = c['s_up']; A = anchors(F); pl = plants(F)
    Mt0 = trunk_M(F, f0, f0); dp = jnt(fr, 'pelvis') - jnt(f0, 'pelvis')
    if c.get('hip_mode') == 'v2':
        bc = Mt0[:, :2] @ ((np.array(c['belt'][0], float) + np.array(c['belt'][1], float)) / 2) + Mt0[:, 2] + dp
        hv = (jnt(fr, 'L_hip') - jnt(fr, 'R_hip')) / 2 * c.get('hip_w', 1.0); hip = bc + (hv if sd == 'L' else -hv)
    else:
        hip = Mt0[:, :2] @ np.array(c['hips'][sd], float) + Mt0[:, 2] + dp
    Mf = foot_M(F, fr, sd, i, pl); kref = jnt(fr, sd + '_knee')
    if c.get('boot_one'):
        an = apm(Mf, A['bA']); Ls0 = math.dist(A['bK'], A['bA']) * s
    else:
        an = jnt(fr, sd + '_ankle') + np.array([0.0, c.get('swing_drop', {}).get(sd, [0.0] * 12)[i]])
        Ls0 = math.dist(A.get('Ks', A['K']), A.get('As', A['A'])) * s
    Lt0 = math.dist(A['H'], A['K']) * s; d_ = math.dist(hip, an); fixup = None
    cap = c.get('reach', 0.985) * c['stretch_max'] * (Lt0 + Ls0)
    if c.get('boot_one') and d_ > cap:
        # out of reach even at the 1.10 stretch cap (the iso clay leg is foreshortened differently from the fixed target leg):
        # planted toe -> raise the heel about the visible ball (the ball stays on the ground); heel-only -> roll about the heel;
        # swing -> move the boot toward the hip. Never stretch past the cap, never detach the boot.
        hp, tp = pl[sd]['heel'][i], pl[sd]['toe'][i]
        if (hp or tp) and not (hp and tp):     # pivot frames only (a full plant stays flat)
            P0 = apm(Mf, KB_cp(F)['TB' if tp else 'HB'])
            def rot(th):
                r = math.radians(th); R = np.array([[math.cos(r), -math.sin(r)], [math.sin(r), math.cos(r)]])
                return np.hstack([R @ Mf[:, :2], (R @ (Mf[:, 2] - P0) + P0)[:, None]])
            sg = 1.0 if math.dist(hip, apm(rot(1.0), A['bA'])) < math.dist(hip, apm(rot(-1.0), A['bA'])) else -1.0
            lo, hi = 0.0, c.get('heel_raise_max', 25.0)
            for _ in range(30):
                mid = (lo + hi) / 2
                if math.dist(hip, apm(rot(sg * mid), A['bA'])) > cap: lo = mid
                else: hi = mid
            Mf = rot(sg * hi); fixup = ('heel_raise' if tp else 'heel_roll', round(sg * hi, 1))
            an2 = apm(Mf, A['bA']); d2 = math.dist(hip, an2)
            if d2 > cap:     # still out of reach at the max heel raise: lift the boot toward the hip by the rest (toe leaves the ground)
                Mf = Mf.copy(); Mf[:, 2] += unit(hip - an2) * (d2 - cap); fixup = fixup + ('pull', round(d2 - cap, 1))
        elif not (hp or tp):
            v = unit(hip - an); Mf = Mf.copy(); Mf[:, 2] += v * (d_ - cap); fixup = ('swing_pull', round(d_ - cap, 1))
        an = apm(Mf, A['bA']); d_ = math.dist(hip, an)
    # along-bone k: 1 <= k <= stretch_max (Bastion v3 rule). min_k < 1 is ONLY the 'alt' variant for Claude's call (follows the
    # iso foreshortening of the v3 clay so the stance leg can stay straight); the delivered rig keeps min_k = 1
    st = float(np.clip(d_ / (c.get('reach', 0.985) * (Lt0 + Ls0)), c.get('min_k', 1.0), c['stretch_max']))
    Lt, Ls = Lt0 * st, Ls0 * st; kn = ik_knee(hip, an, Lt, Ls, kref)
    _LG[(F, i, sd)] = dict(hip=hip, an=an, kn=kn, Lt=Lt, Ls=Ls, st=st, Mf=Mf, ratio=d_ / (Lt0 + Ls0), fixup=fixup); return _LG[(F, i, sd)]

def KB_cp(F): return contact_pts(F)

def thigh_screen_deg(F, i, sd):
    g = leg_geo(F, i, sd); v = g['kn'] - g['hip']; return math.degrees(math.atan2(v[0], v[1])) * (1 if F == 'S' else 1)

PHASE_KEY = ['fwd', 'fwd', 'down', 'down', 'back', 'back', 'back', 'back', 'down', 'fwd', 'fwd', 'fwd']
def contact_frame(F, sd):
    h = plants(F)[sd]['heel']; return next(j for j in range(12) if h[j] and not h[j - 1])

def rkey(F, i, sd):
    """v2 thigh keys by GAIT PHASE from that leg's heel strike c (the hip flexion curve of a walk): c, c+1 = fwd (contact /
    loading, thigh flexed toward travel); c+2, c+3 = down (mid-stance); c+4..c+7 = back (late stance, toe-off, pre-swing:
    thigh trailing); c+8 = down (passing); c+9..c+11 = fwd (swing). The returned degree is the rendered thigh's screen angle
    vs the cycle mean (+ = toward travel)."""
    m = float(np.mean([thigh_screen_deg(F, j, sd) for j in range(12)])); d = thigh_screen_deg(F, i, sd) - m
    if KCFG[F].get('key_mode', 'phase') == 'phase':
        return PHASE_KEY[(i - contact_frame(F, sd)) % 12], round(d, 1)
    return rkey_angle(F, i, sd)

def rkey_angle(F, i, sd):
    """thigh key from the RENDERED thigh: screen angle of hip->knee vs that leg's cycle mean, signed so + = toward the travel
    side (S down-right, E up-right: both +x on screen): fwd > key_deg, back < -key_deg, else down."""
    m = float(np.mean([thigh_screen_deg(F, j, sd) for j in range(12)])); d = thigh_screen_deg(F, i, sd) - m; k = KCFG[F]['key_deg']
    return ('fwd' if d > k else ('back' if d < -k else 'down')), round(d, 1)

def render(F, i):
    W = frames(F); fr = W[i]; f0 = W[0]; c = KCFG[F]; s = c['s_up']; A = anchors(F); pl = plants(F)
    Mt = trunk_M(F, fr, f0); lay = {}; meta = {}
    lay['body'] = warp(F, 'body', Mt)
    if (F, 'front') in TEX: lay['front'] = warp(F, 'front', Mt)
    if (F, 'back') in TEX: lay['back'] = warp(F, 'back', Mt)      # under-cape shadow fill, behind the legs
    # legs: uniform target scale s_up (none across the bone, <= stretch_max along it), rooted at the TARGET hip points (moved by
    # the per-frame pelvis delta); the blockout gives only the bend side (knee) and the foot-plant targets (heel/toe, ankle)
    for sd in 'RL':
        g = leg_geo(F, i, sd); hip, kn, an, Lt, Ls, st = g['hip'], g['kn'], g['an'], g['Lt'], g['Ls'], g['st']
        key, deg = rkey(F, i, sd)
        Mth = frame_M(A['H'], A['K'], hip, kn, Lt / math.dist(A['H'], A['K']), s)
        if key in ('fwd', 'back') and c.get('key_sag') and not c.get('leg_one'):
            # thigh key SHAPE: the bend whose bulge lands on the travel side (fwd: quad / knee leading) or the trailing side (back)
            ua = unit(np.subtract(TLEG[F]['anchors']['K'], TLEG[F]['anchors']['H'])); nt = np.array([-ua[1], ua[0]])
            nc = Mth[:, :2] @ nt; want = 1.0 if key == 'fwd' else -1.0
            tag = 'p' if np.dot(nc, WD[F]) * want >= 0 else 'n'
            th = warp(F, f'thigh_{key}_{tag}', Mth)
            th[..., :3] *= c['keys'][key]; lay[sd + '_thigh'] = th
        else:
            th = None
        if c.get('leg_one'):
            # ONE painted leg skinned on thigh / shin / foot (key shape = the bent-thigh variant of the same leg texture)
            tex = 'leg'
            if key in ('fwd', 'back') and c.get('key_sag'):
                ua = unit(np.subtract(A['K'], A['H'])); nt = np.array([-ua[1], ua[0]]); nc = Mth[:, :2] @ nt
                tex = f"leg_{key}_{'p' if np.dot(nc, WD[F]) * (1.0 if key == 'fwd' else -1.0) >= 0 else 'n'}"
            Msh = frame_M(A['K'], A['A'], kn, an, Ls / math.dist(A['K'], A['A']), s)
            lay[sd + '_leg'] = leg_skin(F, tex, Mth, Msh, g['Mf'])
        elif th is None:
            th = warp(F, 'thigh', Mth); th[..., :3] *= c['keys'][key]; lay[sd + '_thigh'] = th
        if c.get('leg_one'):
            pass
        elif c.get('boot_one'):
            Ms = frame_M(A['bK'], A['bA'], kn, an, Ls / math.dist(A['bK'], A['bA']), s)
            lay[sd + '_boot'] = boot_skin(F, Ms, g['Mf'])
        else:
            Ks, As = A.get('Ks', A['K']), A.get('As', A['A'])
            lay[sd + '_shin'] = warp(F, 'shin', frame_M(Ks, As, kn, an, Ls / math.dist(Ks, As), s))
            lay[sd + '_foot'] = warp(F, 'foot', g['Mf'])
        meta[sd] = dict(key=key, thigh_deg=deg, knee=[round(float(v), 2) for v in kn], hip=[round(float(v), 2) for v in hip],
                        ankle=[round(float(v), 2) for v in an], stretch=round(st, 3), ax_thigh=round(st, 3), ax_shin=round(st, 3),
                        reach_gap=round(max(0.0, math.dist(hip, an) - (Lt + Ls)), 2), reach_ratio=round(g['ratio'], 3),
                        knee_bend_deg=round(float(np.degrees(np.arccos(np.clip(np.dot(unit(kn - hip), unit(an - kn)), -1, 1)))), 1))
    idx = {n: k for k, n in enumerate(fr['draw_order'])}
    legz = {sd: min(idx[f'{sd}_thigh'], idx[f'{sd}_shin'], idx[f'{sd}_boot']) for sd in 'RL'}
    near, far = sorted('RL', key=lambda q: legz[q])[::-1] if False else sorted('RL', key=lambda q: legz[q])
    lp = ['leg'] if c.get('leg_one') else (['thigh', 'boot'] if c.get('boot_one') else ['thigh', 'shin', 'foot'])
    if c.get('leg_one'):
        for sd in 'RL':
            m_ = meta[sd]; lay[sd + '_leg'] = shade_leg(lay[sd + '_leg'], m_['hip'], m_['knee'], m_['ankle'], sd == far, c)
        # boots that merge (E f00 / f09): a 1-2 px rim gap cut into the far leg along the near leg's outline, so they read as two
        na = lay[near + '_leg'][..., 3]; rim = c.get('rim_px', 1.5) * RS
        if rim > 0:
            dist_out = cv2.distanceTransform((na < 0.5).astype(np.uint8), cv2.DIST_L2, 3)
            k_ = np.clip((dist_out - 0.0) / rim, 0, 1)[..., None]
            ov_ = (lay[far + '_leg'][..., 3] > 0.05) & (na > 0.05)
            lay[far + '_leg'] = lay[far + '_leg'] * np.where((dist_out[..., None] < rim) & (na[..., None] < 0.5), k_, 1.0)
        if (F, 'pelvis') in TEX: lay['pelvis'] = warp(F, 'pelvis', Mt)
    legs_far_to_near = [f'{far}_{q}' for q in lp] + [f'{near}_{q}' for q in lp]
    order = (['back', 'body'] + legs_far_to_near + ['front']) if F == 'S' else (['back'] + legs_far_to_near + ['body'])   # back -> front
    if c.get('leg_one') and F == 'E': order = ['back'] + legs_far_to_near + ['pelvis', 'body']
    order = [n for n in order if n in lay]
    acc = np.zeros((CH * RS, CW * RS, 4), np.float32); owner = np.full((CH * RS, CW * RS), -1, np.int16)
    for k, nm in enumerate(order):
        L = lay[nm]; a = L[..., 3:]; acc = L + acc * (1 - a); owner[L[..., 3] > 0.5] = k
    # bow string: at cell scale the painted string (~1 target px) breaks into dots; redraw it as a 1 px line between the
    # target's string end points (moved with the body), on top. Then drop specks < 25 px left by thin cape/arrow tips.
    for a_, b_ in c.get('string', []):
        pa, pb = ((Mt[:, :2] @ np.array(p_, float) + Mt[:, 2]) * RS for p_ in (a_, b_))
        ln = np.zeros((CH * RS, CW * RS), np.uint8); cv2.line(ln, tuple(int(round(v)) for v in pa), tuple(int(round(v)) for v in pb), 1, max(1, RS // 2), cv2.LINE_8)
        lm = ln > 0; acc[lm] = (0.24, 0.19, 0.16, 1.0); owner[lm] = len(order)
    from scipy import ndimage as ndi
    m = acc[..., 3] > 0.5; lab, n = ndi.label(m, np.ones((3, 3)))
    if n > 1:
        sz = ndi.sum(m, lab, range(1, n + 1)); big = 1 + int(np.argmax(sz))
        for k_ in range(1, n + 1):
            if k_ != big and sz[k_ - 1] < 25 * RS * RS: acc[lab == k_] = 0; owner[lab == k_] = -1
    meta['order'] = order; meta['near'] = near
    return acc, lay, owner, order, meta

def to_rgba_aa(acc, outline=True):
    """anti-aliased output for the sheets / paint guides: soft alpha (no stair-steps) + a subtle 1 px dark outline in the
    target's edge colour (multiplied into the outermost alpha ramp)"""
    a = np.clip(acc[..., 3], 0, 1); rgb = acc[..., :3] / np.maximum(a[..., None], 1e-6)
    if outline:
        e = np.clip(a - cv2.erode(a, np.ones((3, 3), np.uint8)), 0, 1)[..., None] * 0.55
        rgb = rgb * (1 - e) + np.array([0.13, 0.09, 0.07]) * e
    out = np.zeros(a.shape + (4,), np.uint8); out[..., :3] = np.clip(rgb * 255 + .5, 0, 255).astype(np.uint8); out[..., 3] = (a * 255 + .5).astype(np.uint8)
    return out

def to_cell(acc, F=None):
    a = acc[..., 3]; m = a > 0.5; rgb = np.where(m[..., None], acc[..., :3] / np.maximum(a[..., None], 1e-6), 0)
    out = np.zeros(a.shape + (4,), np.uint8); out[..., :3] = np.clip(rgb * 255 + .5, 0, 255).astype(np.uint8); out[..., 3] = m * 255
    return out

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--only', default='SE'); ap.add_argument('--frames', default='')
    ap.add_argument('--out', default=os.path.join(HERE, '..', 'frames')); a = ap.parse_args(); os.makedirs(a.out, exist_ok=True)
    fl = [int(x) for x in a.frames.split(',')] if a.frames else list(range(12)); info = {}
    for F in a.only:
        load_layers(F)
        for i in fl:
            acc, lay, owner, order, meta = render(F, i)
            Image.fromarray(to_cell(acc, F), 'RGBA').save(f'{a.out}/kestrel_walk_{F}_f{i:02d}.png'); info[f'{F}_f{i:02d}'] = meta
    json.dump(info, open(os.path.join(a.out, '_build_info.json'), 'w'), indent=1); print('ok', len(info))
