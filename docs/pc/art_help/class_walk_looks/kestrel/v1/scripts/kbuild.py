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
def load_layers(F):
    """premultiplied float RGBA of each target layer, pre-resized to s_up (INTER_AREA); anchors scaled with it."""
    s = KCFG[F]['s_up']
    names = ['body', 'thigh', 'shin', 'foot'] + [n for n in ('front', 'back') if os.path.exists(f'{PARTS}{n}_{F}.png')]
    for nm in names:
        p = f'{PARTS}{nm}_{F}.png' if nm in ('body', 'front', 'back') else f'{PARTS}T{F}_{nm}.png'
        im = np.asarray(Image.open(p).convert('RGBA')).astype(np.float32) / 255.
        pm = np.dstack([im[..., :3] * im[..., 3:], im[..., 3:]])
        TEX[(F, nm)] = cv2.resize(pm, (round(pm.shape[1] * s), round(pm.shape[0] * s)), interpolation=cv2.INTER_AREA)

def warp(F, nm, M):
    """M maps TARGET px -> cell; the texture is pre-scaled by s_up."""
    s = KCFG[F]['s_up']; Ms = M.copy(); Ms[:, :2] = M[:, :2] / s
    return cv2.warpAffine(TEX[(F, nm)], Ms, (CW, CH), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)

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
        A = TLEG[F]['anchors']; he, to = np.array(A['heel'], float), np.array(A['toe'], float); u = unit(to - he); n = np.array([-u[1], u[0]])
        if n[1] < 0: n = -n
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
    A = dict(TLEG[F]['anchors']); A['H'] = KCFG[F]['hips'][KCFG[F]['src']]; return A    # source-leg hip = its belt-corner hip

def render(F, i):
    W = frames(F); fr = W[i]; f0 = W[0]; c = KCFG[F]; s = c['s_up']; A = anchors(F); pl = plants(F)
    Mt = trunk_M(F, fr, f0); lay = {}; meta = {}
    lay['body'] = warp(F, 'body', Mt)
    if (F, 'front') in TEX: lay['front'] = warp(F, 'front', Mt)
    if (F, 'back') in TEX: lay['back'] = warp(F, 'back', Mt)      # under-cape shadow fill, behind the legs
    # legs: uniform target scale s_up (none across the bone, <= stretch_max along it), rooted at the TARGET hip points (moved by
    # the per-frame pelvis delta); the blockout gives only the bend side (knee) and the foot-plant targets (heel/toe, ankle)
    Mt0 = trunk_M(F, f0, f0); dp = jnt(fr, 'pelvis') - jnt(f0, 'pelvis')
    Ks, As = A.get('Ks', A['K']), A.get('As', A['A'])
    Lt00 = math.dist(A['H'], A['K']) * s; Ls00 = math.dist(Ks, As) * s
    for sd in 'RL':
        hip = Mt0[:, :2] @ np.array(c['hips'][sd], float) + Mt0[:, 2] + dp
        an, kref = jnt(fr, sd + '_ankle'), jnt(fr, sd + '_knee')
        sdrop = np.array([0.0, c.get('swing_drop', {}).get(sd, [0.0] * 12)[i]])   # swing frames only: keeps the foot peak low
        an = an + sdrop
        # along-bone scale = the blockout's foreshortening of that bone relative to the pose the target leg was painted in
        # (visible_length_scale ratio), never above stretch_max; if the ankle is still out of reach both grow up to the cap
        ft = min(fr['parts'][sd + '_thigh']['visible_length_scale'] / c['vls_ref'][0], c['stretch_max'])
        fs = min(fr['parts'][sd + '_shin']['visible_length_scale'] / c['vls_ref'][1], c['stretch_max'])
        Lt0, Ls0 = Lt00 * ft, Ls00 * fs; d_ = math.dist(hip, an)
        st = float(np.clip(d_ / (0.985 * (Lt0 + Ls0)), 1.0, c['stretch_max'] / max(ft, fs)))
        Lt, Ls = Lt0 * st, Ls0 * st; ft, fs = ft * st, fs * st
        kn = ik_knee(hip, an, Lt, Ls, kref)
        key, deg = thigh_key_c(F, i, sd)
        th = warp(F, 'thigh', frame_M(A['H'], A['K'], hip, kn, Lt / math.dist(A['H'], A['K']), s))
        th[..., :3] *= c['keys'][key]
        lay[sd + '_thigh'] = th
        lay[sd + '_shin'] = warp(F, 'shin', frame_M(Ks, As, kn, an, Ls / math.dist(Ks, As), s))
        lay[sd + '_foot'] = warp(F, 'foot', foot_M(F, fr, sd, i, pl))
        gap = max(0.0, math.dist(hip, an) - (Lt + Ls))
        meta[sd] = dict(key=key, thigh_deg=deg, knee=[round(float(v), 1) for v in kn], hip=[round(float(v), 2) for v in hip],
                        stretch=round(st, 3), ax_thigh=round(ft, 3), ax_shin=round(fs, 3), reach_gap=round(gap, 2))
    idx = {n: k for k, n in enumerate(fr['draw_order'])}
    legz = {sd: min(idx[f'{sd}_thigh'], idx[f'{sd}_shin'], idx[f'{sd}_boot']) for sd in 'RL'}
    near, far = sorted('RL', key=lambda q: legz[q])
    legs_far_to_near = [f'{far}_thigh', f'{far}_shin', f'{far}_foot', f'{near}_thigh', f'{near}_shin', f'{near}_foot']
    order = (['back', 'body'] + legs_far_to_near + ['front']) if F == 'S' else (['back'] + legs_far_to_near + ['body'])   # back -> front
    order = [n for n in order if n in lay]
    acc = np.zeros((CH, CW, 4), np.float32); owner = np.full((CH, CW), -1, np.int16)
    for k, nm in enumerate(order):
        L = lay[nm]; a = L[..., 3:]; acc = L + acc * (1 - a); owner[L[..., 3] > 0.5] = k
    # bow string: at cell scale the painted string (~1 target px) breaks into dots; redraw it as a 1 px line between the
    # target's string end points (moved with the body), on top. Then drop specks < 25 px left by thin cape/arrow tips.
    for a_, b_ in c.get('string', []):
        pa, pb = (Mt[:, :2] @ np.array(p_, float) + Mt[:, 2] for p_ in (a_, b_))
        ln = np.zeros((CH, CW), np.uint8); cv2.line(ln, tuple(int(round(v)) for v in pa), tuple(int(round(v)) for v in pb), 1, 1, cv2.LINE_8)
        lm = ln > 0; acc[lm] = (0.24, 0.19, 0.16, 1.0); owner[lm] = len(order)
    from scipy import ndimage as ndi
    m = acc[..., 3] > 0.5; lab, n = ndi.label(m, np.ones((3, 3)))
    if n > 1:
        sz = ndi.sum(m, lab, range(1, n + 1)); big = 1 + int(np.argmax(sz))
        for k_ in range(1, n + 1):
            if k_ != big and sz[k_ - 1] < 25: acc[lab == k_] = 0; owner[lab == k_] = -1
    meta['order'] = order; meta['near'] = near
    return acc, lay, owner, order, meta

def to_cell(acc, F=None):
    a = acc[..., 3]; m = a > 0.5; rgb = np.where(m[..., None], acc[..., :3] / np.maximum(a[..., None], 1e-6), 0)
    out = np.zeros((CH, CW, 4), np.uint8); out[..., :3] = np.clip(rgb * 255 + .5, 0, 255).astype(np.uint8); out[..., 3] = m * 255
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
