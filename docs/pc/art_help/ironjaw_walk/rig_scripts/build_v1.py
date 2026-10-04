import json, math, sys, os, numpy as np, cv2
from PIL import Image
from scipy import ndimage as ndi
sys.path.insert(0, '/workspace/scratch/ij_walk/rig'); sys.path.insert(0, '/workspace/scratch/ij_walk/rig/lib')
from rig_core import *
import lab34 as LB
OUT = '/workspace/scratch/ij_walk/rig/'
CFG = dict(
    tilt={'S': -14.0, 'E': 14.0},           # boot rest tilt (deg, TA convention) applied to painted heel->toe
    cape_rest={'S': -16.0, 'E': 0.0},       # cape rest angle (deg) added to TA cape rotation
    cape_off={'S': (0, 6), 'E': (0, -30)},  # cape hang point relative to neck joint
    cape_k=(0.92, 1.08),
    near_axe_fix={'S': True, 'E': False},
    fore_k_floor=0.8,
    hide_far_axe={'E': 0.45},
)
if os.path.exists(OUT + 'cfg_override.json'):
    CFG.update(json.load(open(OUT + 'cfg_override.json')))

def frames(fac):
    W = J['walk_' + fac]; return [W[f'f{i:02d}'] for i in range(12)]

# ------------------------------------------------------------- derived anchors
def upper_cut(fac, name, im):
    d = PARTS[fac][name]; A = np.array(d['A'], float)
    rgb = im[..., :3].astype(float); m = im[..., 3] > 0
    L = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    H = m.shape[0]; dark = m & (L < 22); dark[:int(0.7 * H)] = False
    dark = ndi.binary_opening(dark, iterations=2); lab, n = ndi.label(dark); sz = np.bincount(lab.ravel()); sz[0] = 0
    op = lab == np.argmax(sz); ys, xs = np.nonzero(op)
    c = np.array([xs.mean(), ys.mean()]); u = (c - A) / np.hypot(*(c - A))
    t = (xs - A[0]) * u[0] + (ys - A[1]) * u[1]
    tcut = t.min() - 3
    yy, xx = np.indices(m.shape); tt = (xx - A[0]) * u[0] + (yy - A[1]) * u[1]
    im = im.copy(); kill = (tt > tcut) & m; im[kill] = 0
    B = A + u * (tcut - 26)
    return im, B.tolist(), dict(cut_t=float(tcut), removed_px=int(kill.sum()), axis=u.tolist())

def torso_fit(fac, im, s):
    ref = np.asarray(Image.open(f'/workspace/art/ironjaw_full/v4_hd/_norim/idle/ironjaw_idle_{fac}_f00.png'))
    ra = ref[..., 3] > 0
    w, h = int(round(im.shape[1] * s)), int(round(im.shape[0] * s))
    ka = cv2.resize((im[..., 3] > 0).astype(np.float32), (w, h), interpolation=cv2.INTER_AREA) > 0.5
    kp = np.pad(ka, ((60, 0), (0, 0))); b0, b1 = 60, 140; best = None
    for ty in range(40, 85):
        for tx in range(256 - w // 2 - 25, 256 - w // 2 + 26):
            A = np.zeros((b1 - b0, CW), bool); A[:, tx:tx + w] = kp[b0 - ty + 60:b1 - ty + 60]
            B = ra[b0:b1]; iou = (A & B).sum() / max((A | B).sum(), 1)
            if best is None or iou > best[0]: best = (iou, tx, ty)
    iou, tx, ty = best
    sx, sy = w / im.shape[1], h / im.shape[0]
    idle = J['idle_' + fac]['joints']
    inv = lambda p: [(p[0] - tx) / sx, (p[1] - ty) / sy]
    return dict(iou=round(float(iou), 4), tx=tx, ty=ty, neck=inv(idle['neck']), pelvis=inv(idle['pelvis']))

TEX, PRE, INFO = {}, {}, {'parts': {}}
def prepare(colour_maps=None):
    global ARM
    ARM = {}
    # arm scale from S idle grip->head fit
    rel = []
    for side in 'RL':
        d = PARTS['S'][f'{side}_forearm']; ji = J['idle_S']['joints']
        rel.append(math.dist(ji[f'{side}_axe_grip'], ji[f'{side}_axe_head_centre']) / math.dist(d['G'], d['H']))
    s_arm_S = float(np.mean(rel)); arm_rel = s_arm_S / SCALE['S']
    INFO['arm_scale'] = {'S': round(s_arm_S, 4), 'E': round(arm_rel * SCALE['E'], 4), 'arm_rel_to_global': round(arm_rel, 4)}
    for fac in 'SE':
        ARM[fac] = arm_rel * SCALE[fac]
        for name, d in PARTS[fac].items():
            im = load_part(fac, name); extra = {}
            if d['kind'] == 'upper':
                im, B, extra = upper_cut(fac, name, im); d['B'] = B
            if d['kind'] == 'torso' and 'neck' not in d:
                tf = torso_fit(fac, im, SCALE[fac]); d.update(neck=tf['neck'], pelvis=tf['pelvis']); extra = tf
            s = ARM[fac] if d['kind'] in ('upper', 'fore') else SCALE[fac]
            if colour_maps is not None:
                im = apply_maps(im, colour_maps[fac], cloth_part=(d['kind'] == 'cape'))
            pm, pre = premul_resize(im, s)
            TEX[(fac, name)] = pm; PRE[(fac, name)] = pre
            INFO['parts'][f'{fac}/{name}'] = dict({k: v for k, v in d.items()}, scale=round(s, 4), **extra)
        # E forearm along-axis squash (foreshortened handle/forearm) from idle E
        for side in 'RL':
            d = PARTS[fac][f'{side}_forearm']; ji = J['idle_' + fac]['joints']
            k = math.dist(ji[f'{side}_axe_grip'], ji[f'{side}_axe_head_centre']) / (math.dist(d['G'], d['H']) * ARM[fac])
            d['k_fit'] = round(k, 4); d['k'] = 1.0 if fac == 'S' else round(max(k, CFG['fore_k_floor']), 4)
            INFO['parts'][f'{fac}/{side}_forearm']['k_axis'] = d['k']

# ------------------------------------------------------------- posing
def pose_matrices(fac, fr, idle, fix_deg):
    Jf, Pf, Ji, Pi = fr['joints'], fr['parts'], idle['joints'], idle['parts']
    s = SCALE[fac]; Ms = {}; meta = {}
    d = PARTS[fac]['torso']
    dr = Pf['torso']['rotation_deg'] - Pi['torso']['rotation_deg']
    R = rot(dr) * s
    km = (np.array(d['neck']) + np.array(d['pelvis'])) / 2; jm = (np.array(Jf['neck']) + np.array(Jf['pelvis'])) / 2
    Ms['torso'] = np.hstack([R, (jm - R @ km)[:, None]])
    # cape
    d = PARTS[fac]['cape']
    th = Pf['cape']['rotation_deg'] + CFG['cape_rest'][fac]
    top = np.array(Jf['neck']) + np.array(CFG['cape_off'][fac])
    k = float(np.clip(Pf['cape']['visible_length_scale'] / Pi['cape']['visible_length_scale'], *CFG['cape_k']))
    Ms['cape'] = similarity(d['A'], d['B'], top, top + dvec(th) * 100, k, s)
    for side in 'RL':
        for seg, (p, q) in (('thigh', ('hip', 'knee')), ('shin', ('knee', 'ankle'))):
            nm = f'{side}_{seg}'; d = PARTS[fac][nm]
            Pj, Dj = np.array(Jf[f'{side}_{p}']), np.array(Jf[f'{side}_{q}'])
            L = np.hypot(*(Dj - Pj)); la = math.dist(d['A'], d['B']) * s
            k = float(np.clip(L / la, KLO, KHI))
            if L < 4:   # degenerate projection: use TA part rotation
                v = dvec(Pf[nm]['rotation_deg'])
            else:
                v = (Dj - Pj) / L
            Ms[nm] = similarity(d['B'], d['A'], Dj, Dj - v * 100, k, s); meta[nm] = round(k, 3)
        # boot
        nm = f'{side}_boot'; d = PARTS[fac][nm]
        dr = round(Pf[nm]['rotation_deg'] - Pi[nm]['rotation_deg'], 2) + CFG['tilt'][fac]
        a = np.array(Jf[f'{side}_ankle'])
        R = rot(dr) * s
        Ms[nm] = np.hstack([R, (a - R @ np.array(d['A']))[:, None]])
        # upper arm
        nm = f'{side}_upperarm'; d = PARTS[fac][nm]; sa = ARM[fac]
        Pj, Dj = np.array(Jf[f'{side}_shoulder']), np.array(Jf[f'{side}_elbow'])
        L = np.hypot(*(Dj - Pj)); la = math.dist(d['A'], d['B']) * sa
        k = float(np.clip(L / la, KLO, KHI))
        Ms[nm] = similarity(d['A'], d['B'], Pj, Pj + (Dj - Pj) / L * 100, k, sa); meta[nm] = round(k, 3)
        # forearm + fist + axe (one rigid piece)
        nm = f'{side}_forearm'; d = PARTS[fac][nm]
        G, H = np.array(Jf[f'{side}_axe_grip']), np.array(Jf[f'{side}_axe_head_centre'])
        M = similarity(d['G'], d['H'], G, H, d['k'], sa)
        if side == 'R' and fix_deg:
            e = np.array(Jf['R_elbow']); Rr = rot(fix_deg)
            M = np.hstack([Rr @ M[:, :2], (Rr @ (M[:, 2] - e) + e)[:, None]])
        Ms[nm] = M
    return Ms, meta

def apply(M, p): return M[:, :2] @ np.asarray(p, float) + M[:, 2]

def near_axe_fix(fac):
    """constant rotation (deg, about R elbow) on the idle pose so R axe head y == L axe head y."""
    idle = J['idle_' + fac]; Ms, _ = pose_matrices(fac, idle, idle, 0.0)
    hR = apply(Ms['R_forearm'], PARTS[fac]['R_forearm']['H']); hL = apply(Ms['L_forearm'], PARTS[fac]['L_forearm']['H'])
    e = np.array(idle['joints']['R_elbow'])
    best = min(np.arange(-60, 60.01, 0.05), key=lambda dd: abs((rot(dd) @ (hR - e) + e)[1] - hL[1]))
    gR = apply(Ms['R_forearm'], PARTS[fac]['R_forearm']['G'])
    return round(float(best), 2), dict(idle_R_head=hR.round(1).tolist(), idle_L_head=hL.round(1).tolist(),
                                    idle_R_grip=gR.round(1).tolist(),
                                    R_head_after=(rot(best) @ (hR - e) + e).round(1).tolist(),
                                    R_grip_after=(rot(best) @ (gR - e) + e).round(1).tolist())

# ------------------------------------------------------------- order
LEG = ('thigh', 'shin', 'boot')
def layer_order(fac, order):
    idx = {n: i for i, n in enumerate(order)}
    key = {}
    for side in 'RL':
        g = min(idx[f'{side}_{p}'] for p in LEG)
        for j, p in enumerate(LEG): key[f'{side}_{p}'] = g + 0.1 * j + (0.01 if side == 'L' else 0)
        key[f'{side}_upperarm'] = idx[f'{side}_upperarm']
        key[f'{side}_forearm'] = idx[f'{side}_forearm']
    key['torso'] = min([idx['torso']] + [key[f'{s}_thigh'] for s in 'RL']) - 0.05
    key['cape'] = 99 if fac == 'S' else idx['cape']
    return sorted(key, key=lambda n: key[n])     # nearest first

# ------------------------------------------------------------- render
# pairwise per-pixel overrides (winner, loser): forearm cuff hides its upper arm's trimmed end; a boot is never
# hidden by the skirt (trailing/lifted foot stays readable). Everything else follows the TA draw order.
OVERRIDES = [('R_forearm', 'R_upperarm'), ('L_forearm', 'L_upperarm'), ('R_boot', 'torso'), ('L_boot', 'torso')]
def render(fac, fr, idle, fix_deg, planted_override=None):
    Ms, meta = pose_matrices(fac, fr, idle, fix_deg)
    if planted_override:
        Ms.update(planted_override)
    order = layer_order(fac, fr['draw_order'])
    rgb = np.zeros((CH, CW, 3), np.float32); al = np.zeros((CH, CW), bool); owner = np.full((CH, CW), -1, np.int16)
    layers, cols = {}, {}
    for nm in order:
        w = warp(TEX[(fac, nm)], Ms[nm], PRE[(fac, nm)])
        cols[nm], layers[nm] = to_layer(w)
    if fac in CFG['hide_far_axe']:          # far (L) axe head lives behind the body: never the visible winner
        d = PARTS[fac]['L_forearm']; M = Ms['L_forearm']
        G = M[:, :2] @ np.array(d['G'], float) + M[:, 2]; H = M[:, :2] @ np.array(d['H'], float) + M[:, 2]
        u = H - G; yy, xx = np.indices((CH, CW)); t = ((xx - G[0]) * u[0] + (yy - G[1]) * u[1]) / (u ** 2).sum()
        others = np.zeros((CH, CW), bool)
        for nm in order:
            if nm != 'L_forearm': others |= layers[nm]
        layers['L_forearm'] = layers['L_forearm'] & ~((t > CFG['hide_far_axe'][fac]) & ~others)
    eff = {nm: layers[nm].copy() for nm in order}
    for win, lose in OVERRIDES:
        eff[lose] &= ~layers[win]
    for nm in reversed(order):            # far -> near
        m = eff[nm]
        rgb[m] = cols[nm][m]; al |= m; owner[m] = list(PARTS[fac]).index(nm)
    return rgb, al, layers, owner, Ms, meta, order

def compose_cell(rgb, al):
    out = np.zeros((CH, CW, 4), np.uint8)
    out[..., :3] = np.where(al[..., None], np.round(rgb), 0).astype(np.uint8); out[..., 3] = al * 255
    return out

# ------------------------------------------------------------- colour maps
def cdf(src, ref, n=1024):
    q = np.linspace(0, 1, n); return np.quantile(src, q), np.quantile(ref, q)
def build_maps(cell, ref):
    out = {}
    for tag, img in (('src', cell), ('ref', ref)):
        m = img[..., 3] > 0; lab = LB.rgb2lab(img[..., :3]); cw = LB.cloth_weight(lab, m)
        out[tag] = (lab[m & (cw < 0.05)], lab[m & (cw > 0.6)])
    maps = {'armour': [cdf(out['src'][0][:, c], out['ref'][0][:, c]) for c in range(3)],
            'cloth': [cdf(out['src'][1][:, c], out['ref'][1][:, c]) for c in range(3)]}
    st = {t: {k: [np.percentile(out[t][i][:, c], [10, 50, 90]).round(1).tolist() for c in range(3)] for i, k in enumerate(('armour', 'cloth'))} for t in out}
    return maps, st
def apply_maps(im, maps, cloth_part=False):
    m = im[..., 3] > 0; lab = LB.rgb2lab(im[..., :3])
    cw = np.ones(m.shape) * m if cloth_part else LB.cloth_weight(lab, m)
    if cloth_part:   # keep near-neutral (dark shadow / metal) cape px on the armour map
        ch = np.hypot(lab[..., 1], lab[..., 2]); cw = np.clip((ch - 4) / 6, 0, 1) * m
    A = lab.copy(); C = lab.copy()
    for c in range(3):
        A[..., c] = np.interp(lab[..., c], *maps['armour'][c]); C[..., c] = np.interp(lab[..., c], *maps['cloth'][c])
    res = LB.lab2rgb(A).astype(np.float64) * (1 - cw[..., None]) + LB.lab2rgb(C).astype(np.float64) * cw[..., None]
    out = im.copy(); out[..., :3] = np.where(m[..., None], np.round(res), 0).astype(np.uint8)
    return out
