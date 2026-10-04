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
    near_axe_fix={'S': False, 'E': False},   # v2: Luca's raise is baked into the TA joints -> 0 deg
    axe_k_floor=0.9,
    upper_cap_r=19,
    pauldron_zone=16,
    far_axe_sides={'E': dict(part='L_axe', colour=(220, 60, 210), dilate=4)},
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
SIDES_DIR = '/workspace/art_src/blockout/ironjaw_walk/renders_512/sides/'

def unit(v): v = np.asarray(v, float); return v / np.hypot(*v)

def split_piece(fac, name, im):
    """v2: mask the painted forearm+fist+axe piece into its cuff / fist / axe sub-piece."""
    d = PARTS[fac][name]; src = PARTS[fac][d.get('src', name)]
    E, G, H = (np.array(src[k], float) for k in 'EGH')
    uEG, uGH = unit(G - E), unit(H - G)
    yy, xx = np.indices(im.shape[:2]).astype(float)
    tEG = (xx - G[0]) * uEG[0] + (yy - G[1]) * uEG[1]; tGH = (xx - G[0]) * uGH[0] + (yy - G[1]) * uGH[1]
    if d['kind'] == 'fore2':
        C = G + SPLIT['cuff_t'] * uEG
        keep = (tEG < SPLIT['cuff_t']) | (np.hypot(xx - C[0], yy - C[1]) < SPLIT['cap_r'])
    elif d['kind'] == 'fist':
        keep = (tEG >= SPLIT['fist_t0']) & (tGH <= SPLIT['fist_t1'])
    else:
        keep = tGH > SPLIT['axe_t0']
    im = im.copy(); kill = ~keep & (im[..., 3] > 0); im[~keep] = 0
    extra = dict(sub_of=d.get('src', name), removed_px=int(kill.sum()), kept_px=int((im[..., 3] > 0).sum()))
    if d['kind'] == 'fore2':
        d['W'] = (G + SPLIT['wrist_t'] * uEG).tolist()
    return im, extra

def prepare(colour_maps=None):
    global ARM
    ARM = {fac: ARM_S for fac in 'SE'}
    INFO['arm_scale'] = {'cuff_fist': ARM_S, 'axe': ARM_AXE, 'upper_arm': 'global scale', 'note': 'axe scale set from the idle painted axe head size'}
    for fac in 'SE':
        for name, d in PARTS[fac].items():
            im = load_part(fac, name); extra = {}
            if d['kind'] in ('fore2', 'fist', 'axe'):
                im, extra = split_piece(fac, name, im)
            if d['kind'] == 'torso' and 'neck' not in d:
                tf = torso_fit(fac, im, SCALE[fac]); d.update(neck=tf['neck'], pelvis=tf['pelvis']); extra = tf
            s = ARM_AXE if d['kind'] == 'axe' else ARM[fac] if d['kind'] in ('fore2', 'fist') else SCALE[fac] * d.get('srel', 1.0)
            d['s'] = s
            if colour_maps is not None:
                im = apply_maps(im, colour_maps[fac], cloth_part=(d['kind'] == 'cape'))
            pm, pre = premul_resize(im, s)
            TEX[(fac, name)] = pm; PRE[(fac, name)] = pre
            INFO['parts'][f'{fac}/{name}'] = dict({k: v for k, v in d.items()}, scale=round(s, 4), **extra)

# ------------------------------------------------------------- posing
def pose_matrices(fac, fr, idle, fix_deg=0.0):
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
    k = float(np.clip(Pf['cape']['visible_length_scale'] / Pi['cape']['visible_length_scale'], *CFG['cape_k'])) * d.get('k0', 1.0)
    Ms['cape'] = similarity(d['A'], d['B'], top, top + dvec(th) * 100, k, d['s'])
    for side in 'RL':
        for seg, (p, q) in (('thigh', ('hip', 'knee')), ('shin', ('knee', 'ankle'))):
            nm = f'{side}_{seg}'; d = PARTS[fac][nm]
            Pj, Dj = np.array(Jf[f'{side}_{p}']), np.array(Jf[f'{side}_{q}'])
            L = np.hypot(*(Dj - Pj)); la = math.dist(d['A'], d['B']) * s
            k = float(np.clip(L / la, KLO, KHI))
            v = dvec(Pf[nm]['rotation_deg']) if L < 4 else (Dj - Pj) / L
            Ms[nm] = similarity(d['B'], d['A'], Dj, Dj - v * 100, k, s); meta[nm] = round(k, 3)
        # boot
        nm = f'{side}_boot'; d = PARTS[fac][nm]
        dr = round(Pf[nm]['rotation_deg'] - Pi[nm]['rotation_deg'], 2) + CFG['tilt'][fac]
        a = np.array(Jf[f'{side}_ankle'])
        R = rot(dr) * d['s']
        Ms[nm] = np.hstack([R, (a - R @ np.array(d['A']))[:, None]])
        # upper arm: elbow cop on the elbow joint, axis to the shoulder, unit length scale (cropped at the shoulder in render)
        nm = f'{side}_upperarm'; d = PARTS[fac][nm]
        Pj, Dj = np.array(Jf[f'{side}_shoulder']), np.array(Jf[f'{side}_elbow'])
        Ms[nm] = similarity(d['B'], d['A'], Dj, Pj, 1.0, d['s']); meta[nm] = round(float(np.hypot(*(Pj - Dj))), 1)
        # forearm cuff: painted elbow end -> elbow joint, painted wrist -> wrist joint
        nm = f'{side}_forearm'; d = PARTS[fac][nm]; sa = ARM[fac]
        Ej, Wj = np.array(Jf[f'{side}_elbow']), np.array(Jf[f'{side}_wrist'])
        L = np.hypot(*(Wj - Ej)); la = math.dist(d['E'], d['W']) * sa
        k = float(np.clip(L / la, KLO, KHI))
        Ms[nm] = similarity(d['E'], d['W'], Ej, Wj, k, sa); meta[nm] = round(k, 3)
        # fist: grip on the grip joint, handle axis on grip->head
        Gj, Hj = np.array(Jf[f'{side}_axe_grip']), np.array(Jf[f'{side}_axe_head_centre'])
        Ms[f'{side}_fist'] = similarity(d['G'], d['H'], Gj, Hj, 1.0, sa)
        # axe: head centre on the head joint, full width; along-axis squash only down to axe_k_floor
        sx = PARTS[fac][f'{side}_axe']['s']
        D = np.hypot(*(Hj - Gj)); ka = float(np.clip(D / (math.dist(d['G'], d['H']) * sx), CFG['axe_k_floor'], 1.0))
        Ms[f'{side}_axe'] = similarity(d['H'], d['G'], Hj, Gj, ka, sx); meta[f'{side}_axe'] = round(ka, 3)
    return Ms, meta

def apply(M, p): return M[:, :2] @ np.asarray(p, float) + M[:, 2]

def axe_heads(fac, Ms):
    return {sd: apply(Ms[f'{sd}_axe'], PARTS[fac][f'{sd}_forearm']['H']) for sd in 'RL'}

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
        key[f'{side}_axe'] = idx[f'{side}_axe']
        key[f'{side}_fist'] = min(idx[f'{side}_forearm'], idx[f'{side}_axe']) - 0.01
    key['torso'] = idx['torso']
    key['cape'] = 99 if fac == 'S' else idx['cape']
    return sorted(key, key=lambda n: key[n])     # nearest first

# ------------------------------------------------------------- render
# pairwise per-pixel overrides (winner, loser), applied on top of the TA draw order:
#  - skirt/torso over the thighs+shins, boots over the skirt (v1 leg/torso/skirt/boot fixes)
#  - forearm cuff over its own upper arm (v1 cuff fix)
#  - torso pauldron over the top of the upper arm (shoulder zone only, see render)
OVERRIDES = [('R_boot', 'torso'), ('L_boot', 'torso'),
             ('torso', 'R_thigh'), ('torso', 'L_thigh'), ('torso', 'R_shin'), ('torso', 'L_shin')]
# (v1's forearm-over-upper-arm cuff override is dropped: it only existed to hide the trimmed opening of the old
#  spiked upper arms; the new upper arms have closed ends, so forearm vs upper arm follows the TA draw order.)

def frame_tag(fac, fr):
    if fr is J['idle_' + fac]: return 'idle_' + fac
    for i, W in enumerate(frames(fac)):
        if fr is W: return f'walk_{fac}_f{i:02d}'
    return None

def sides_mask(tag, colour, tol=60):
    a = np.asarray(Image.open(SIDES_DIR + tag + '.png').convert('RGB')).astype(int)
    return np.abs(a - np.array(colour)).sum(-1) < tol

def render(fac, fr, idle, fix_deg=0.0, planted_override=None, tag=None):
    Ms, meta = pose_matrices(fac, fr, idle, fix_deg)
    if planted_override:
        Ms.update(planted_override)
    tag = tag or frame_tag(fac, fr)
    order = layer_order(fac, fr['draw_order'])
    rgb = np.zeros((CH, CW, 3), np.float32); al = np.zeros((CH, CW), bool); owner = np.full((CH, CW), -1, np.int16)
    layers, cols = {}, {}
    for nm in order:
        w = warp(TEX[(fac, nm)], Ms[nm], PRE[(fac, nm)])
        cols[nm], layers[nm] = to_layer(w)
    yy, xx = np.indices((CH, CW)).astype(float)
    shoulder_zone = {}
    for side in 'RL':        # crop the upper arm at the shoulder joint (round cap); torso wins in the shoulder zone
        nm = f'{side}_upperarm'
        Pj, Dj = np.array(fr['joints'][f'{side}_shoulder']), np.array(fr['joints'][f'{side}_elbow'])
        L = max(np.hypot(*(Pj - Dj)), 1e-3); v = (Pj - Dj) / L
        t = (xx - Dj[0]) * v[0] + (yy - Dj[1]) * v[1]; r = CFG['upper_cap_r']; C = Dj + v * (L - r)
        layers[nm] &= (t <= L - r) | (np.hypot(xx - C[0], yy - C[1]) <= r)
        shoulder_zone[nm] = t > L - CFG['pauldron_zone']
    far = CFG['far_axe_sides'].get(fac)
    if far:                  # far axe: visible only where the TA render shows it (sides pass, dilated)
        nm = far['part']
        if tag is not None and os.path.exists(SIDES_DIR + tag + '.png'):
            vis = ndi.binary_dilation(sides_mask(tag, far['colour']), iterations=far['dilate'])
            meta['far_axe_sides_px'] = int(vis.sum())
        else:
            vis = np.zeros((CH, CW), bool); meta['far_axe_sides_px'] = None
        layers[nm + '_unclipped'] = layers[nm].copy(); layers['far_axe_sides_vis'] = vis
        layers[nm] = layers[nm] & vis
    eff = {nm: layers[nm].copy() for nm in order}
    for win, lose in OVERRIDES:
        eff[lose] &= ~layers[win]
    for nm, z in shoulder_zone.items():
        eff[nm] &= ~(layers['torso'] & z)
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
