"""Bastion v1 HD walk: painted parts rigged on Mauro's approved blockout joints (joints_512.json), Ironjaw v7 method.
usage: build.py [--only S|E] [--frames 0,6] [--out DIR]   (default out = ../frames)"""
import json, math, os, sys, argparse, numpy as np, cv2
from PIL import Image
from scipy import ndimage as ndi
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from rig_core import *
from rig_def import PARTS, P
import process_sheet as ps
B = '/workspace/handoff/class_walk_blockouts/bastion/'
J = json.load(open(B + 'joints_512.json'))['facings']
N8 = np.ones((3, 3), bool)
CFG = {
 'S': dict(helm_off=(0, 3), helm_rest=0.0, torso_off=(0, -3), torso_rest=0.0,
           belt_off=(0, -5), belt_rest=0.0, belt_swing=0.3, belt_swing_max=5.0, tabard='tabard_f',
           pauld_off={'R': (-2, -2), 'L': (0, -3)}, pauld_rest={'R': 0.0, 'L': 0.0}, pauld_follow=0.35,
           fore_bias={'R': 18.0, 'L': 0.0}, upper_cap_r=8,
           shield_off=(-4, 18), shield_rest=0.0, shield_gain=0.25,
           cape_off=(-6, 4), cape_rest_u=0.0, cape_rest_l=0.0, cape_k=(0.92, 1.08), cape_lower_at=0.80,
           boot_off={'R': (0, 0), 'L': (0, 0)}, boot_rest=0.0, thigh_cap=4, cape_last=True),
 'E': dict(helm_off=(0, 3), helm_rest=0.0, torso_off=(0, -2), torso_rest=0.0,
           belt_off=(0, -5), belt_rest=0.0, belt_swing=0.3, belt_swing_max=5.0, tabard='tabard_b',
           pauld_off={'R': (0, -3), 'L': (2, -2)}, pauld_rest={'R': 0.0, 'L': 0.0}, pauld_follow=0.35,
           fore_bias={'R': -30.0, 'L': 0.0}, upper_cap_r=8,
           shield_off=(-20, 10), shield_rest=0.0, shield_gain=0.25,
           cape_off=(-4, 2), cape_rest_u=0.0, cape_rest_l=0.0, cape_k=(0.92, 1.08), cape_lower_at=0.75,
           boot_off={'R': (0, 0), 'L': (0, 0)}, boot_rest=0.0, thigh_cap=4, cape_last=False),
}
OVR = os.path.join(HERE, 'cfg_override.json')
if os.path.exists(OVR):
    for fac, d in json.load(open(OVR)).items(): CFG[fac].update(d)
WDIR = {'S': np.array([2.0, 1.0]) / math.sqrt(5), 'E': np.array([2.0, -1.0]) / math.sqrt(5)}
EXP = {'S': (-6.66, -3.33), 'E': (-6.66, 3.33)}

def unit(v): v = np.asarray(v, float); return v / max(np.hypot(*v), 1e-9)

# ------------------------------------------------------------------ parts
TEX, PRE, DEF = {}, {}, {}
def capsule_keep(shape, A, Bp, r_extra=0.0):
    """part-local rounded crop: keep px whose projection on A->B is <= |AB|, or within the half-width circle at B."""
    yy, xx = np.indices(shape).astype(float); u = unit(np.subtract(Bp, A)); L = math.dist(A, Bp)
    t = (xx - A[0]) * u[0] + (yy - A[1]) * u[1]
    return t, u, L, yy, xx

def load_part(fac, name):
    d = dict(PARTS[fac][name]); im = np.asarray(Image.open(P + d['file'] + '.png').convert('RGBA')).copy()
    if d.get('mirror'): im = im[:, ::-1].copy()
    if d.get('cap'):        # E thigh keys painted with the lower leg: round crop just below the knee (B)
        t, u, L, yy, xx = capsule_keep(im.shape[:2], d['A'], d['B'])
        m = im[..., 3] > 0; n = np.array([-u[1], u[0]])
        tn = (xx - d['B'][0]) * n[0] + (yy - d['B'][1]) * n[1]
        band = m & (np.abs(t - L) < 4); r = (tn[band].max() - tn[band].min()) / 2 + 1 if band.any() else 40
        C = np.array(d['B']) + n * (tn[band].max() + tn[band].min()) / 2 if band.any() else np.array(d['B'])
        keep = (t <= L) | (np.hypot(xx - C[0], yy - C[1]) <= r)
        im[~keep] = 0
    if 'rows' in d:          # cape panels cut from a full painted cape: elliptic (not straight) top/bottom boundary
        r0, r1 = d['rows']; h, w = im.shape[:2]; yy, xx = np.indices((h, w)).astype(float)
        cx = w / 2; ax = w / 2 + 2
        sag = 14.0 * np.sqrt(np.clip(1 - ((xx - cx) / ax) ** 2, 0, 1))        # arc: 14 px deeper at the centre
        keep = np.ones((h, w), bool)
        if r0 > 0: keep &= yy >= r0 + sag
        if r1 < h: keep &= yy <= r1 + sag
        im[~keep] = 0
    im[im[..., 3] == 0] = 0
    return im, d

def prepare():
    TEX.clear(); PRE.clear(); DEF.clear()
    for fac in 'SE':
        for name in PARTS[fac]:
            im, d = load_part(fac, name)
            pm, pre = premul_resize(im, d['s'], d.get('sx', 1.0))
            if d.get('sx', 1.0) != 1.0:      # anchors live in un-squashed px: fold sx into the map instead
                pm, pre = premul_resize(im, d['s'])
            TEX[(fac, name)] = pm; PRE[(fac, name)] = pre; DEF[(fac, name)] = d

# ------------------------------------------------------------------ posing
def frames(fac): return [J['walk_' + fac][f'f{i:02d}'] for i in range(12)]
def idle(fac): return J['idle_' + fac]['f00']
def jnt(fr, k): return np.array(fr['joints'][k], float)

def plants(fac, tol=0.6):
    """{side: {'heel': [12 bools], 'toe': [...]}}: joint moves exactly with the ground into or out of frame i."""
    W = frames(fac); g = np.array(EXP[fac]); out = {}
    for s in 'RL':
        out[s] = {}
        for jn in ('heel', 'toe'):
            mv = [bool(np.all(np.abs(jnt(W[(i + 1) % 12], f'{s}_{jn}') - jnt(W[i], f'{s}_{jn}') - g) < tol)) for i in range(12)]
            out[s][jn] = [mv[i] or mv[i - 1] for i in range(12)]
    return out

def flat_len(fac, s):
    W = frames(fac); pl = plants(fac)[s]; fs = [i for i in range(12) if pl['heel'][i] and pl['toe'][i]]
    return float(np.linalg.norm(jnt(W[fs[0]], s + '_toe') - jnt(W[fs[0]], s + '_heel')))

def boot_toe_corr(fac, s, lp):
    """toe-anchor offset minus heel-anchor offset: lp*u - (toe - heel) on the side's first fully planted frame."""
    W = frames(fac); pl = plants(fac)[s]
    fs = [i for i in range(12) if pl['heel'][i] and pl['toe'][i]]
    v = jnt(W[fs[0]], s + '_toe') - jnt(W[fs[0]], s + '_heel')
    return unit(v) * lp - v

def frame_index(fac, fr):
    for k, f in enumerate(frames(fac)):
        if f is fr: return k
    return None

def thigh_keys(fac):
    """per leg per frame: 'fwd'/'down'/'back' by the knee's lead along the walk direction (tertiles of all 24)."""
    W = frames(fac); vals = {}
    for s in 'RL':
        vals[s] = [float(np.dot(jnt(fr, s + '_knee') - jnt(fr, s + '_hip'), WDIR[fac])) for fr in W]
    allv = np.array(vals['R'] + vals['L']); lo, hi = np.percentile(allv, [33.3, 66.7])
    return {s: ['fwd' if v > hi else 'back' if v < lo else 'down' for v in vals[s]] for s in 'RL'}, vals

def rot_about(deg):   # rotation matrix acting on dvec-convention angles (+deg = +theta)
    r = math.radians(deg); return np.array([[math.cos(r), math.sin(r)], [-math.sin(r), math.cos(r)]])

def pose(fac, fr, keys=None):
    c = CFG[fac]; Ms = {}; meta = {}; I = idle(fac)
    D = lambda n: DEF[(fac, n)]
    neck, pel, top = jnt(fr, 'neck'), jnt(fr, 'pelvis'), jnt(fr, 'head_top')
    a_t = ang(pel - neck); a_t0 = ang(jnt(I, 'pelvis') - jnt(I, 'neck'))
    R_t = rot_about(a_t - a_t0)
    has = lambda n: (fac, n) in DEF
    if has('torso'):
        d = D('torso'); o = neck + np.array(c['torso_off'])
        Ms['torso'] = similarity(d['N'], d['W'], o, o + dvec(a_t + c['torso_rest']) * 100, 1.0, d['s'])
    if has('helm'):
        d = D('helm'); o = neck + np.array(c['helm_off']); a_h = ang(top - neck)
        Ms['helm'] = similarity(d['N'], d['T'], o, o + dvec(a_h + c['helm_rest']) * 100, 1.0, d['s'])
    # belt + tassets + tabard, swinging a few degrees with the TA tabard
    sw = -(fr['parts'][c['tabard']]['rotation_deg'] - I['parts'][c['tabard']]['rotation_deg'])
    sw = (sw + 180) % 360 - 180; sw = float(np.clip(sw * c['belt_swing'], -c['belt_swing_max'], c['belt_swing_max'])); meta['belt_swing'] = round(sw, 2)
    if has('belt'):
        d = D('belt'); o = pel + R_t @ np.array(c['belt_off'], float)
        Ms['belt'] = similarity(d['C'], d['D'], o, o + dvec(a_t + c['belt_rest'] + sw) * 100, 1.0, d['s'])
    for s in 'RL':
        if not has(s + '_upper'):
            continue
        sh, el, wr = jnt(fr, s + '_shoulder'), jnt(fr, s + '_elbow'), jnt(fr, s + '_wrist')
        # upper arm
        d = D(s + '_upper'); L = math.dist(sh, el); k = float(np.clip(L / (math.dist(d['A'], d['B']) * d['s']), 0.9, 1.1))
        Ms[s + '_upper'] = similarity(d['B'], d['A'], el, sh, k, d['s']); meta[s + '_upper_k'] = round(k, 3)
        a_u = ang(el - sh); a_u0 = ang(jnt(I, s + '_elbow') - jnt(I, s + '_shoulder'))
        if has(s + '_pauld'):
          d = D(s + '_pauld'); rr = a_t - a_t0 + c['pauld_follow'] * (a_u - a_u0) + c['pauld_rest'][s]
          R = rot_about(rr) * d['s']; o = sh + np.array(c['pauld_off'][s], float)
          Ms[s + '_pauld'] = np.hstack([R, (o - R @ np.array(d['P'], float))[:, None]])
        # forearm piece (forearm + fist [+ mace] one painting)
        d = D(s + '_fore'); a_f = ang(wr - el); L = math.dist(el, wr)
        k = float(np.clip(L / (math.dist(d['E'], d['W']) * d['s']), 0.9, 1.1))
        a_fb = a_f + c['fore_bias'][s]
        Ms[s + '_fore'] = similarity(d['E'], d['W'], el, el + dvec(a_fb) * 100, k, d['s']); meta[s + '_fore_k'] = round(k, 3)
        # elbow cop over the joint
        d = D(s + '_elbowcop'); am = (a_u + a_fb) / 2; R = rot_about(am - 0.0) * d['s']
        Ms[s + '_elbowcop'] = np.hstack([R, (el - R @ np.array(d['C'], float))[:, None]])
        if s == 'L' and has('shield'):     # shield strapped flat on the outside of the left forearm, over the fist
            a_f0 = ang(jnt(I, 'L_wrist') - jnt(I, 'L_elbow'))
            d = D('shield'); Rf = rot_about(a_f - a_f0); o = wr + Rf @ np.array(c['shield_off'], float)
            rr = c['shield_rest'] + c['shield_gain'] * (a_f - a_f0)
            sx = d.get('sx', 1.0); R = rot_about(rr) @ np.diag([sx, 1.0]) * d['s']
            Ms['shield'] = np.hstack([R, (o - R @ np.array(d['C'], float))[:, None]])
    # legs
    for s in 'RL':
        hip, kn, an = jnt(fr, s + '_hip'), jnt(fr, s + '_knee'), jnt(fr, s + '_ankle')
        key = 'thigh_' + (keys[s] if keys else 'down')
        d = D(key); L = math.dist(hip, kn); k = float(np.clip(L / (math.dist(d['A'], d['B']) * d['s']), 0.9, 1.1))
        Ms[s + '_thigh'] = similarity(d['B'], d['A'], kn, hip, k, d['s']); meta[s + '_thigh'] = (key, round(k, 3))
        DEF[(fac, s + '_thigh')] = d; TEX[(fac, s + '_thigh')] = TEX[(fac, key)]; PRE[(fac, s + '_thigh')] = PRE[(fac, key)]
        d = D('greave'); L = math.dist(kn, an); k = float(np.clip(L / (math.dist(d['A'], d['B']) * d['s']), 0.9, 1.1))
        Ms[s + '_greave'] = similarity(d['B'], d['A'], an, kn, k, d['s']); meta[s + '_greave_k'] = round(k, 3)
        DEF[(fac, s + '_greave')] = d; TEX[(fac, s + '_greave')] = TEX[(fac, 'greave')]; PRE[(fac, s + '_greave')] = PRE[(fac, 'greave')]
        if (fac, 'kneecop') in DEF:
            d = D('kneecop'); am = (ang(kn - hip) + ang(an - kn)) / 2; R = rot_about(am) * d['s']
            Ms[s + '_kneecop'] = np.hstack([R, (kn - R @ np.array(d['C'], float))[:, None]])
            DEF[(fac, s + '_kneecop')] = d; TEX[(fac, s + '_kneecop')] = TEX[(fac, 'kneecop')]; PRE[(fac, s + '_kneecop')] = PRE[(fac, 'kneecop')]
        # sabaton on the heel/toe joints: fixed scale, rigid -> planted joints move it exactly with the ground
        d = D(s + '_boot'); he, to = jnt(fr, s + '_heel'), jnt(fr, s + '_toe')
        u = unit(to - he); n = np.array([-u[1], u[0]]); lp = math.dist(d['heel'], d['toe']) * d['s']
        # rigid in the blockout FOOT frame (origin on the planted joint, x along heel->toe): painted heel = heel joint +
        # o_u*u + o_n*n while the heel is planted (and in the air); once only the toe is planted the same rigid boot
        # rides the toe joint (o - flat foot length along u). The sabaton then moves exactly like the blockout foot
        # (skate 0 there), pivoting where the blockout pivots.
        fi = frame_index(fac, fr); pl = plants(fac)[s] if fi is not None else None
        hp, tp = (pl['heel'][fi], pl['toe'][fi]) if pl else (False, False)
        o = np.array(c.get('boot_o', {}).get(s, (0.0, 0.0)), float)
        if tp and not hp: Ph = to + u * (o[0] - flat_len(fac, s)) + n * o[1]
        else: Ph = he + u * o[0] + n * o[1]
        meta[s + '_boot_anchor'] = 'toe' if (tp and not hp) else 'heel'
        Ms[s + '_boot'] = similarity(d['heel'], d['toe'], Ph, Ph + u * lp, 1.0, d['s'])
    if not has('cape_u'):
        return Ms, meta
    # cape: two panels with the TA lag
    d = D('cape_u'); o = neck + R_t @ np.array(c['cape_off'], float)
    ku = float(np.clip(fr['parts']['cape_u']['visible_length_scale'] / I['parts']['cape_u']['visible_length_scale'], *c['cape_k']))
    au = -fr['parts']['cape_u']['rotation_deg'] + c['cape_rest_u']
    Ms['cape_u'] = similarity(d['T'], d['B'], o, o + dvec(au) * 100, ku, d['s'])
    hang = apply(Ms['cape_u'], np.array(d['T']) + (np.array(d['B']) - np.array(d['T'])) * c['cape_lower_at'])
    d = D('cape_l')
    kl = float(np.clip(fr['parts']['cape_l']['visible_length_scale'] / I['parts']['cape_l']['visible_length_scale'], *c['cape_k']))
    al = -fr['parts']['cape_l']['rotation_deg'] + c['cape_rest_l']
    Ms['cape_l'] = similarity(d['T'], d['B'], hang, hang + dvec(al) * 100, kl, d['s'])
    meta['cape'] = (round(au, 2), round(al, 2), round(ku, 3), round(kl, 3))
    return Ms, meta

# ------------------------------------------------------------------ draw order (nearest first)
TA_MAP = {'helm_crest': 'helm', 'helm': 'helm', 'head': 'helm', 'neck': 'helm', 'R_pauld': 'R_pauld', 'L_pauld': 'L_pauld',
          'R_uarm': 'R_upper', 'L_uarm': 'L_upper', 'R_farm': 'R_fore', 'R_hand': 'R_fore', 'mace_handle': 'R_fore', 'mace_head': 'R_fore',
          'L_farm': 'L_fore', 'L_hand': 'L_fore', 'shield': 'shield', 'torso': 'torso', 'pelvis': 'belt',
          'R_thigh': 'R_thigh', 'L_thigh': 'L_thigh', 'R_shin': 'R_greave', 'L_shin': 'L_greave', 'R_boot': 'R_boot', 'R_bootshaft': 'R_boot',
          'L_boot': 'L_boot', 'L_bootshaft': 'L_boot', 'cape_u': 'cape_u', 'cape_l': 'cape_l'}
def layer_order(fac, fr, names):
    c = CFG[fac]; idx = {}
    for i, n in enumerate(fr['draw_order']):
        m = TA_MAP.get(n) or (('belt' if n == c['tabard'] else None))
        if m and m not in idx: idx[m] = i
    z = {n: idx[n] for n in idx if n in names}
    for s in 'RL':
        z[s + '_elbowcop'] = min(z[s + '_upper'], z[s + '_fore']) - 0.2
        z[s + '_pauld'] = min(z[s + '_pauld'], z[s + '_upper'] - 0.1)
        g = min(z[s + '_thigh'], z[s + '_greave'], z[s + '_boot'])        # keep each leg together
        z[s + '_boot'], z[s + '_greave'], z[s + '_thigh'] = g, g + 0.02, g + 0.04
        if s + '_kneecop' in names: z[s + '_kneecop'] = g + 0.01
        else: z[s + '_thigh'] = g + 0.01        # E: the thigh's back band overlaps the greave top (no knee cop from behind)
    z['shield'] = z['L_fore'] - 0.3 if fac == 'S' else z['shield']
    z['cape_l'] = z['cape_u'] + 0.05
    if c['cape_last']: z['cape_u'], z['cape_l'] = 99, 99.05
    return sorted(z, key=lambda n: z[n])

# per-pixel overrides (winner, loser) on top of the order: tassets/tabard over the thigh tops (hide the hip join),
# sabatons over the tabard hem, helm over the far pauldron
OVERRIDES = [('belt', 'R_thigh'), ('belt', 'L_thigh'), ('R_boot', 'belt'), ('L_boot', 'belt')]

def render(fac, fr, keys=None, boot_override=None):
    Ms, meta = pose(fac, fr, keys)
    if boot_override: Ms.update(boot_override)
    names = list(Ms)
    order = layer_order(fac, fr, names)
    cols, layers = {}, {}
    for nm in order:
        cols[nm], layers[nm] = to_layer(warp(TEX[(fac, nm)], Ms[nm], PRE[(fac, nm)]))
    yy, xx = np.indices((CH, CW)).astype(float); c = CFG[fac]
    for s in 'RL':        # upper arm: round cap at the shoulder (pauldron covers it)
        sh, el = jnt(fr, s + '_shoulder'), jnt(fr, s + '_elbow'); L = max(math.dist(sh, el), 1e-3); v = (sh - el) / L
        t = (xx - el[0]) * v[0] + (yy - el[1]) * v[1]; r = c['upper_cap_r']; C = el + v * (L - r)
        layers[s + '_upper'] &= (t <= L - r) | (np.hypot(xx - C[0], yy - C[1]) <= r + 6)
        hip, kn = jnt(fr, s + '_hip'), jnt(fr, s + '_knee'); L = max(math.dist(hip, kn), 1e-3); v = (hip - kn) / L
        t = (xx - kn[0]) * v[0] + (yy - kn[1]) * v[1]; r = 12; C = kn + v * (L + c['thigh_cap'] - r)
        layers[s + '_thigh'] &= (t <= L + c['thigh_cap'] - r) | (np.hypot(xx - C[0], yy - C[1]) <= r + 6)
    eff = {nm: layers[nm].copy() for nm in order}
    for win, lose in OVERRIDES:
        if win in layers and lose in eff: eff[lose] &= ~layers[win]
    rgb = np.zeros((CH, CW, 3), np.float32); al = np.zeros((CH, CW), bool); owner = np.full((CH, CW), -1, np.int16)
    for nm in reversed(order):
        m = eff[nm]; rgb[m] = cols[nm][m]; al |= m; owner[m] = order.index(nm)
    return rgb, al, layers, owner, Ms, meta, order

def compose_cell(rgb, al):
    out = np.zeros((CH, CW, 4), np.uint8)
    out[..., :3] = np.where(al[..., None], np.round(rgb), 0).astype(np.uint8); out[..., 3] = al * 255
    return out

def clean_cell(cell):
    cell, nsmall = ps.drop_small(cell, 60)
    cell, nfix = ps.edge_fix(cell)
    return cell, dict(dropped_small_px=int(nsmall), edge_fix_px=int(nfix))

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--only', default='SE'); ap.add_argument('--frames', default='')
    ap.add_argument('--out', default=os.path.join(HERE, '..', 'frames')); a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True); prepare()
    fl = [int(x) for x in a.frames.split(',')] if a.frames else list(range(12))
    info = {}
    for fac in a.only:
        keys, kv = thigh_keys(fac); W = frames(fac)
        for i in fl:
            rgb, al, layers, owner, Ms, meta, order = render(fac, W[i], {s: keys[s][i] for s in 'RL'})
            cell, ci = clean_cell(compose_cell(rgb, al))
            Image.fromarray(cell, 'RGBA').save(f'{a.out}/bastion_walk_{fac}_f{i:02d}.png')
            info[f'{fac}_f{i:02d}'] = dict(meta=meta, clean=ci, order=order)
    json.dump(info, open(os.path.join(a.out, '_build_info.json'), 'w'), indent=1, default=str)
    print('ok', len(info))
