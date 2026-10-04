"""Kestrel v3 (Claude) - the walk rig: ONE continuous painted leg per side, mesh-skinned on 3 bones onto blockout v3.1 joints.

Per frame i and facing F (S, E):
  body   back_F (target minus legs, under-tunic fill) and front_F (belt / pouches / hem / bow, or the whole cape for E) are placed
         with one uniform scale s (the target's hood->sole fitted to the clay), x on the blockout hip centre, y moving with the
         clay's own head-top row (integer rows -> the bob is the blockout's bob exactly).
  hips   the painted hip centre of the target, +- half the blockout hip vector (hip_w) -> the legs hang from the target's belt hips.
  foot   the source boot is a rigid similarity (scale s) laid on the blockout heel / toe joints; the planted point (toe at
         toe-off, heel at heel strike, the middle when flat) is pinned, so planted feet move exactly with the ground (no skate).
  knee   2-bone IK at full target length (k = 1); a leg out of reach stretches along the bone (k <= stretch_max), never across;
         bend side = the blockout knee's side.
  skin   the painted leg is a triangle mesh (4 target px grid) deformed by linear-blend skinning of three affine bones (thigh,
         shin, foot) with smoothstep weights across the knee bisector (+-knee_blend) and the ankle line (+-ankle_blend): the
         knee bends smoothly, there is no cut anywhere between hip and sole. Across the bone the scale is always s.
  shade  the painting's own shading is kept; the far-side leg (blockout R) is far_dark darker.
Render at RS x the cell (default 3), then area-downsample to 512x360, binary alpha, black under alpha 0.
usage: krig.py [--out DIR] [--only SE] [--gif]"""
import os, sys, json, math, subprocess, argparse, numpy as np, cv2
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '../../../../../../..'))
PARTS = os.environ.get('K3PARTS', os.path.join(HERE, '..', 'parts'))
BLOCK_COMMIT = 'ec4beff918ad691be293d7f22de3689b1516e67e'      # Kestrel blockout v3.1 on claude/class-walk-blockouts
BLOCK = os.environ.get('KBLOCK', '/tmp/kestrel_blockout_v31')
CW, CH, PIV = 512, 360, (256, 329)
FPS = 17.144
EXP = {'S': np.array([-8.13, -4.07]), 'E': np.array([-8.13, 4.07])}   # ground motion per frame in the blockout

CFG = {
 'S': dict(s=253 / 686, hip_w=1.0, knee_blend=24.0, ankle_blend=14.0, stretch_max=1.10, far_dark=0.90, dy=0.0,
           foot_o=[-2.6, 4.8], reach=0.998, stance_kmin=0.90, swing_kmin=0.85, bend_rest=20.0, dy_kmax=1.03, foot_k=(0.88, 1.12)),
 'E': dict(s=247 / 665, hip_w=1.0, knee_blend=24.0, ankle_blend=14.0, stretch_max=1.10, far_dark=0.90, dy=0.0,
           foot_o=[2.4, 5.0], reach=0.998, stance_kmin=0.90, swing_kmin=0.85, bend_rest=20.0, dy_kmax=1.03, foot_k=(0.88, 1.12)),
}
OVR = os.path.join(HERE, 'kcfg.json')
if os.path.exists(OVR):
    for F_, d_ in json.load(open(OVR)).items(): CFG[F_].update(d_)

def blockout_dir():
    d = os.path.join(BLOCK, 'docs/pc/art_help/class_walk_blockouts/kestrel/')
    if not os.path.exists(d + 'joints_512.json'):
        os.makedirs(BLOCK, exist_ok=True)
        subprocess.run(f'git -C "{REPO}" archive {BLOCK_COMMIT} docs/pc/art_help/class_walk_blockouts/kestrel | tar -x -C "{BLOCK}"',
                       shell=True, check=True)
    return d

BD = blockout_dir()
J = json.load(open(BD + 'joints_512.json'))['facings']
def frames(F): return [J['walk_' + F][f'f{i:02d}'] for i in range(12)]
def jnt(fr, k): return np.array(fr['joints'][k], float)
def unit(v): v = np.asarray(v, float); return v / max(float(np.hypot(*v)), 1e-9)

def plants(F, tol=0.6):
    """heel / toe planted in frame i = that joint moves with the ground into or out of frame i."""
    W = frames(F); out = {}
    for sd in 'RL':
        out[sd] = {}
        for k in ('heel', 'toe'):
            mv = [np.abs(jnt(W[(i + 1) % 12], f'{sd}_{k}') - jnt(W[i], f'{sd}_{k}') - EXP[F]).max() <= tol for i in range(12)]
            out[sd][k] = [bool(mv[i] or mv[i - 1]) for i in range(12)]
    return out

_CT = {}
def clay_top(F, i):
    if (F, i) not in _CT:
        a = np.asarray(Image.open(f'{BD}clay/kestrel_walk_{F}_f{i:02d}.png').convert('RGBA'))[..., 3] > 127
        _CT[(F, i)] = int(np.nonzero(a[:, 200:312].any(1))[0].min())
    return _CT[(F, i)]

def near_side(fr):
    """the blockout draw_order is front -> back (ID maps: the part listed first occludes)."""
    o = fr['draw_order']; return 'L' if o.index('L_boot') < o.index('R_boot') else 'R'

def far_dark(F, i, sd):
    """far leg ~10 % darker, eased over the neighbouring frames so the swap of near / far never pops."""
    W = frames(F); f = [float(near_side(W[(i + d) % 12]) != sd) for d in (-1, 0, 1)]
    return 1 - (1 - CFG[F]['far_dark']) * (0.25 * f[0] + 0.5 * f[1] + 0.25 * f[2])

# ------------------------------------------------------------------ textures
TEX = {}
def tex(name):
    if name not in TEX:
        im = np.asarray(Image.open(f'{PARTS}/{name}.png').convert('RGBA')).astype(np.float32) / 255.
        TEX[name] = np.dstack([im[..., :3] * im[..., 3:], im[..., 3:]])
    return TEX[name]

RIG = {F: json.load(open(f'{PARTS}/rig_{F}.json')) for F in 'SE' if os.path.exists(f'{PARTS}/rig_{F}.json')}

# ------------------------------------------------------------------ geometry
def body_T(F, i, dy):
    """target px -> cell: x' = s*x + tx, y' = s*y + ty (ty integer-row locked to the clay head top)."""
    c = CFG[F]; s = c['s']; W = frames(F); R = RIG[F]
    hc_t = (np.array(R['hips']['near'], float) + np.array(R['hips']['far'], float)) / 2
    hci = (jnt(W[i], 'L_hip') + jnt(W[i], 'R_hip')) / 2
    tx = hci[0] - s * hc_t[0]
    ty = clay_top(F, i) - s * R['top'] + dy          # hood top on the clay's head-top row (+ dy): the painted proportions hold
    return s, tx, ty

def tpt(T, p): s, tx, ty = T; return np.array([s * p[0] + tx, s * p[1] + ty])

def hips(F, i, dy):
    W = frames(F); fr = W[i]; T = body_T(F, i, dy); R = RIG[F]
    hc = tpt(T, (np.array(R['hips']['near'], float) + np.array(R['hips']['far'], float)) / 2)
    hv = (jnt(fr, 'L_hip') - jnt(fr, 'R_hip')) / 2 * CFG[F]['hip_w']
    return {'L': hc + hv, 'R': hc - hv}

def sim_M(p_src, q_src, p_dst, q_dst, s, pin):
    """similarity (scale s, rotation = dst dir - src dir) that maps the blend `pin` of p_src..q_src onto the same blend of p_dst..q_dst."""
    a = math.atan2(*(np.subtract(q_dst, p_dst)[::-1])) - math.atan2(*(np.subtract(q_src, p_src)[::-1]))
    R = s * np.array([[math.cos(a), -math.sin(a)], [math.sin(a), math.cos(a)]])
    ps = (1 - pin) * np.asarray(p_src, float) + pin * np.asarray(q_src, float)
    pd = (1 - pin) * np.asarray(p_dst, float) + pin * np.asarray(q_dst, float)
    return np.hstack([R, (pd - R @ ps)[:, None]])

def apm(M, p): return M[:, :2] @ np.asarray(p, float) + M[:, 2]

def foot_M(F, i, sd, pl):
    """the boot foot on the blockout heel / toe joints: rotation onto the heel->toe direction, across scale s, along scale
    s * kf with kf = blockout foot length / painted foot length clipped to foot_k (the iso foot foreshortens a little).
    Pinned point: the heel while the heel is planted (strike + flat), the toe at toe-off, the middle in swing -> the planted
    contact point moves exactly with the ground."""
    fr = frames(F)[i]; R = RIG[F]; c = CFG[F]; s = c['s']
    hp, tp = pl[sd]['heel'][i], pl[sd]['toe'][i]
    pin = 0.0 if hp else 1.0 if tp else 0.5
    he_d, to_d = jnt(fr, sd + '_heel'), jnt(fr, sd + '_toe'); he_s, to_s = np.array(R['heel'], float), np.array(R['toe'], float)
    kf = float(np.clip(math.dist(he_d, to_d) / (s * math.dist(he_s, to_s)), *c['foot_k']))
    u = unit(to_s - he_s); n = np.array([-u[1], u[0]]); v = unit(to_d - he_d); m = np.array([-v[1], v[0]])
    L = np.outer(v, u) * s * kf + np.outer(m, n) * s
    ps = (1 - pin) * he_s + pin * to_s; pd = (1 - pin) * he_d + pin * to_d
    M = np.hstack([L, (pd - L @ ps)[:, None]])
    M[:, 2] += np.array(c['foot_o'], float)
    # per-leg constant lateral offset of the foot track (S: the far boot must not hide straight behind the near leg).
    # Constant over the whole cycle -> a planted foot still moves exactly with the ground (no skate).
    M[:, 2] += np.array(c.get('foot_lat', {}).get(sd, (0.0, 0.0)), float)
    return M, pin

def ik_knee(hip, ank, L1, L2, kref):
    d = np.subtract(ank, hip); D = float(np.hypot(*d)); D = min(D, L1 + L2 - 1e-4); u = unit(d); n = np.array([-u[1], u[0]])
    a = (L1 * L1 - L2 * L2 + D * D) / (2 * D); h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    sg = 1.0 if np.dot(np.subtract(kref, hip), n) >= 0 else -1.0
    return np.asarray(hip, float) + u * a + n * h * sg

def bone_M(A, B, P, Q, s_w):
    """source segment A->B onto P->Q: along scale |PQ|/|AB|, across scale s_w, A -> P."""
    u = unit(np.subtract(B, A)); n = np.array([-u[1], u[0]]); v = unit(np.subtract(Q, P)); m = np.array([-v[1], v[0]])
    k = math.dist(P, Q) / math.dist(A, B)
    L = np.outer(v, u) * k + np.outer(m, n) * s_w
    return np.hstack([L, (np.asarray(P, float) - L @ np.asarray(A, float))[:, None]])

def leg_pose(F, i, sd, dy, pl=None):
    """cell-space joints of one leg + its three bone matrices (target px -> cell)."""
    pl = pl or plants(F); c = CFG[F]; s = c['s']; R = RIG[F]; fr = frames(F)[i]
    H, K, A = (np.array(R[k], float) for k in ('H', 'K', 'A'))
    hip = hips(F, i, dy)[sd]
    Mf, pin = foot_M(F, i, sd, pl); an = apm(Mf, A)
    Lt0, Ls0 = s * math.dist(H, K), s * math.dist(K, A); D = math.dist(hip, an)
    planted = bool(pl[sd]['heel'][i] or pl[sd]['toe'][i])
    # knee bend to aim for: the blockout's own knee bend minus its rest bend (the clay knee joint sits ~20 deg off the
    # hip-ankle line even on a straight leg); planted legs aim for straight.
    h_, k_, a_ = (jnt(fr, sd + '_' + n) for n in ('hip', 'knee', 'ankle')); v1, v2 = k_ - h_, a_ - k_
    bb = abs(math.degrees(math.atan2(v1[0] * v2[1] - v1[1] * v2[0], v1 @ v2)))
    beta = 0.0 if planted else float(np.clip(bb - c['bend_rest'], 0, 75))
    Db = math.sqrt(Lt0 ** 2 + Ls0 ** 2 + 2 * Lt0 * Ls0 * math.cos(math.radians(beta)))
    k = D / (c['reach'] * Db)
    # stance legs: k follows the iso foreshortening of the blockout leg (E-ALT ruling, 0.90 <= k <= 1.10);
    # swing / toe-off legs: depth bend, 0.85 <= k (the knee bends toward the viewer instead of swinging out sideways)
    k = max(k, c['stance_kmin'] if planted else c['swing_kmin'])
    kc = min(k, c['stretch_max'])
    if k > kc:      # beyond the stretch cap: the foot comes up toward the hip (reported as 'pull')
        an2 = hip + unit(an - hip) * (Lt0 + Ls0) * kc * c['reach']; Mf = Mf.copy(); Mf[:, 2] += an2 - an; pull = math.dist(an2, an); an = an2
    else: pull = 0.0
    kn = ik_knee(hip, an, Lt0 * kc, Ls0 * kc, jnt(fr, sd + '_knee'))
    Mt = bone_M(H, K, hip, kn, s); Ms = bone_M(K, A, kn, an, s)
    toe = apm(Mf, R['toe']); heel = apm(Mf, R['heel'])
    return dict(hip=hip, knee=kn, ankle=an, toe=toe, heel=heel, Mt=Mt, Ms=Ms, Mf=Mf, k=kc, pull=pull, pin=pin,
                planted=bool(pl[sd]['heel'][i] or pl[sd]['toe'][i]), heel_pl=pl[sd]['heel'][i], toe_pl=pl[sd]['toe'][i])

# ------------------------------------------------------------------ mesh skin
_MESH = {}
def mesh(F, name, step=4):
    key = (F, name)
    if key in _MESH: return _MESH[key]
    T = tex(name); a = T[..., 3] > 0.01; ys, xs = np.nonzero(a)
    x0, x1, y0, y1 = xs.min() - step, xs.max() + step, ys.min() - step, ys.max() + step
    gx = np.arange(x0, x1 + step, step); gy = np.arange(y0, y1 + step, step)
    V = np.stack(np.meshgrid(gx, gy), -1).reshape(-1, 2).astype(np.float64); nx = len(gx)
    ad = cv2.dilate(a.astype(np.uint8), np.ones((3, 3), np.uint8))
    tris = []
    for r in range(len(gy) - 1):
        for q in range(nx - 1):
            xa, ya = gx[q], gy[r]
            if ad[max(ya, 0):ya + step + 1, max(xa, 0):xa + step + 1].any():
                v0 = r * nx + q; tris += [(v0, v0 + 1, v0 + nx + 1), (v0, v0 + nx + 1, v0 + nx)]
    tris = np.array(tris)
    R = RIG[F]; H, K, A = (np.array(R[k], float) for k in ('H', 'K', 'A'))
    ut, us = unit(K - H), unit(A - K); mk = unit(ut + us)
    c = CFG[F]; bk, ba = c['knee_blend'], c['ankle_blend']
    def ss(t): t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)
    wk = ss(((V - K) @ mk + bk) / (2 * bk)); wa = ss(((V - A) @ us + ba) / (2 * ba))
    Wt = np.stack([1 - wk, wk * (1 - wa), wk * wa], -1)
    # draw order of triangles: thigh first, then shin, foot last (the boot shaft overlaps the thigh at an inner-knee fold)
    tw = Wt[tris].mean(1); order = np.argsort(tw @ np.array([0.0, 1.0, 2.0]), kind='stable')
    _MESH[key] = (V, tris[order], Wt); return _MESH[key]

def skin(F, name, P, RS):
    """forward-skin the mesh, rasterise each triangle's source coordinates, remap the texture (premultiplied)."""
    V, tris, Wt = mesh(F, name)
    Vd = sum(Wt[:, j:j + 1] * (V @ M[:, :2].T + M[:, 2]) for j, M in enumerate((P['Mt'], P['Ms'], P['Mf']))) * RS
    Hh, Ww = CH * RS, CW * RS
    mapx = np.full((Hh, Ww), -1e4, np.float32); mapy = np.full((Hh, Ww), -1e4, np.float32)
    D = Vd[tris]; S_ = V[tris]
    for t in range(len(tris)):
        d = D[t]; x0 = int(math.floor(d[:, 0].min())); x1 = int(math.ceil(d[:, 0].max())); y0 = int(math.floor(d[:, 1].min())); y1 = int(math.ceil(d[:, 1].max()))
        x0 = max(x0, 0); y0 = max(y0, 0); x1 = min(x1, Ww - 1); y1 = min(y1, Hh - 1)
        if x1 < x0 or y1 < y0: continue
        Mx = np.array([[d[1, 0] - d[0, 0], d[2, 0] - d[0, 0]], [d[1, 1] - d[0, 1], d[2, 1] - d[0, 1]]])
        det = np.linalg.det(Mx)
        if abs(det) < 1e-9: continue
        Mi = np.linalg.inv(Mx)
        yy, xx = np.mgrid[y0:y1 + 1, x0:x1 + 1]
        px = xx + 0.5 - 0.5 - d[0, 0]; py = yy - d[0, 1]
        b1 = Mi[0, 0] * px + Mi[0, 1] * py; b2 = Mi[1, 0] * px + Mi[1, 1] * py
        ins = (b1 >= -1e-3) & (b2 >= -1e-3) & (b1 + b2 <= 1 + 1e-3)
        if not ins.any(): continue
        s0 = S_[t]
        sx = s0[0, 0] + b1 * (s0[1, 0] - s0[0, 0]) + b2 * (s0[2, 0] - s0[0, 0])
        sy = s0[0, 1] + b1 * (s0[1, 1] - s0[0, 1]) + b2 * (s0[2, 1] - s0[0, 1])
        sub = (slice(y0, y1 + 1), slice(x0, x1 + 1))
        mapx[sub][ins] = sx[ins]; mapy[sub][ins] = sy[ins]
    out = cv2.remap(tex(name), mapx, mapy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    return out

def place(F, name, T, RS):
    s, tx, ty = T
    M = np.float32([[s * RS, 0, tx * RS], [0, s * RS, ty * RS]])
    return cv2.warpAffine(tex(name), M, (CW * RS, CH * RS), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)

def over(dst, src): return src + dst * (1 - src[..., 3:])

def solve_dy(F):
    """body height: the support leg reaches its planted foot at k = 1 (straight) in the frame where it is longest."""
    pl = plants(F); c = CFG[F]; s = c['s']; R = RIG[F]
    Lt = s * (math.dist(R['H'], R['K']) + math.dist(R['K'], R['A']))
    def worst(dy):
        m = 0
        for i in range(12):
            fr = frames(F)[i]; sup = 'R' if jnt(fr, 'R_ankle')[1] >= jnt(fr, 'L_ankle')[1] else 'L'
            an = apm(foot_M(F, i, sup, pl)[0], R['A']); m = max(m, math.dist(hips(F, i, dy)[sup], an) / Lt)
        return m
    lo, hi = -40.0, 40.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if worst(mid) > c['dy_kmax'] * c['reach']: lo = mid
        else: hi = mid
    return round(hi, 2)

def get_dy(F):
    if CFG[F].get('dy') is None: CFG[F]['dy'] = solve_dy(F)
    return CFG[F]['dy']

def render(F, i, RS=3, legs_only=False):
    """premultiplied float RGBA at RS x the cell, plus the frame's leg meta."""
    dy = get_dy(F); T = body_T(F, i, dy); fr = frames(F)[i]; pl = plants(F)
    img = np.zeros((CH * RS, CW * RS, 4), np.float32)
    if not legs_only: img = over(img, place(F, f'back_{F}', T, RS))
    nr = near_side(fr); meta = dict(near=nr)
    for sd in ([x for x in 'RL' if x != nr] + [nr]):
        P = leg_pose(F, i, sd, dy, pl)
        L = skin(F, f'leg_{F}' if sd == 'L' else f'legfar_{F}', P, RS)
        L[..., :3] *= far_dark(F, i, sd)
        img = over(img, L)
        meta[sd] = {k: (v.tolist() if isinstance(v, np.ndarray) and v.ndim == 1 else v) for k, v in P.items() if k not in ('Mt', 'Ms', 'Mf')}
    if not legs_only: img = over(img, place(F, f'front_{F}', T, RS))
    meta['body_T'] = list(T); meta['dy'] = dy
    return img, meta

def to_cell(img, RS):
    sm = cv2.resize(img, (CW, CH), interpolation=cv2.INTER_AREA) if RS != 1 else img
    a = sm[..., 3]; m = a > 0.5
    rgb = np.clip(sm[..., :3] / np.maximum(a[..., None], 1e-6), 0, 1)
    out = np.zeros((CH, CW, 4), np.uint8); out[m, :3] = (rgb[m] * 255 + 0.5).astype(np.uint8); out[m, 3] = 255
    return out

def gif(paths, out, scale=1, bg=(172, 172, 172)):
    ims = []
    for p in paths:
        a = Image.open(p).convert('RGBA'); b = Image.new('RGBA', a.size, bg + (255,)); b.alpha_composite(a)
        if scale != 1: b = b.resize((a.width * scale, a.height * scale), Image.NEAREST)
        ims.append(b.convert('RGB').convert('P', palette=Image.ADAPTIVE, colors=255))
    ims[0].save(out, save_all=True, append_images=ims[1:], duration=10 * round(100 / FPS), loop=0, disposal=2)

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--out', default=os.path.join(HERE, '..', 'frames')); ap.add_argument('--only', default='SE')
    ap.add_argument('--frames', default=None); ap.add_argument('--rs', type=int, default=3); ap.add_argument('--gif', action='store_true')
    a = ap.parse_args(); os.makedirs(a.out, exist_ok=True); info = {}
    fl = [int(x) for x in a.frames.split(',')] if a.frames else range(12)
    for F in a.only:
        info[F] = {}
        for i in fl:
            img, meta = render(F, i, a.rs)
            Image.fromarray(to_cell(img, a.rs)).save(f'{a.out}/kestrel_walk_{F}_f{i:02d}.png'); info[F][f'f{i:02d}'] = meta
            print(F, i, 'near', meta['near'], 'k', round(meta['R']['k'], 3), round(meta['L']['k'], 3), 'pull', round(meta['R']['pull'], 1), round(meta['L']['pull'], 1), flush=True)
        if a.gif and not a.frames:
            gif([f'{a.out}/kestrel_walk_{F}_f{i:02d}.png' for i in range(12)], os.path.join(a.out, '..', f'walk_{F}.gif'))
    json.dump(dict(cfg=CFG, frames=info), open(f'{a.out}/_build_info.json', 'w'), indent=1, default=float)
