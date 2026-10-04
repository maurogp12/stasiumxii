"""Bastion v2 HD walk, Ironjaw v7 method:
 * upper body look (helm + torso + pauldrons, cape, shield) = layers cut from Mauro's approved target (cut_target_layers.py),
   placed on the blockout joints: trunk on head_top/pelvis (integer moves -> bob identical to the blockout), near pauldron
   on the R shoulder, shield strapped on the L forearm (wrist + forearm angle), cape with the TA two-panel lag;
 * articulated parts = painted part sheets on the blockout joints (build.py): belt+tassets+tabard (swing), upper arms,
   elbow cops, forearm+fist+mace (one painting), L fist, thigh keys by phase, knee cops, greaves, sabatons on heel/toe.
usage: build_hybrid.py [--only S|E] [--frames ..] [--out DIR]"""
import json, math, os, sys, argparse, numpy as np, cv2
from PIL import Image
from scipy import ndimage as ndi
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import build as BM
from build import *
from rig_def import P
TL = json.load(open(P + 'target_layers.json'))['info']
HPARTS = {
 'S': {
  'belt':    dict(file='S_belt', kind='belt', C=[150, 52], D=[150, 395], s=0.228),
#  'R_upper': dict(file='S_upper_a', kind='limb', A=[87.6, 17.7], B=[73.0, 205.8], s=0.19),  # near arm = target layer (lbs)
  'L_upper': dict(file='S_upper_b', kind='limb', A=[46.0, 17.2], B=[56.0, 185.5], s=0.173),
#  'R_elbowcop': dict(file='S_elbowcop', kind='cop', C=[77, 80], s=0.13),  # near arm = target layer (lbs)
  'L_elbowcop': dict(file='S_elbowcop', kind='cop', C=[77, 80], s=0.118),
#  'R_fore':  dict(file='S_mace', kind='fore', E=[62, 52], W=[150, 112], H=[75, 360], s=0.25),  # near arm = target layer (lbs)
  'L_fore':  dict(file='S_fist', kind='fore', E=[158, 42], W=[100, 135], H=[62, 182], s=0.228),
  # v2 legs: cut from the approved target at target scale (s = s_up); fwd/back thigh keys = painted keys graded and
  # width-matched to the target thigh (the target hides the thighs under the tabard except the near one, see cut_target_legs.py)
  'thigh_fwd':  dict(file='S_thigh_fwd', kind='limb', A=[100, 40], B=[78, 278], s=0.244),
  'thigh_down': dict(file='TSL_thigh', kind='limb', A=[38.0, -30.0], B=[41.0, 136.0], s=0.4137, nograde=True),
  'thigh_back': dict(file='S_thigh_back', kind='limb', A=[55, 40], B=[86, 330], s=0.253),
  'kneecop': dict(file='TSL_kneecop', kind='cop', C=[39.0, 53.0], s=0.4137, nograde=True),
  'greave':  dict(file='TSL_greave', kind='limb', A=[42.0, -12.0], B=[35.0, 134.0], s=0.4137, nograde=True),
  'R_boot':  dict(file='TSL_sabaton', kind='boot', heel=[-1.7000000000000455, 75.10000000000002], toe=[66.0, 105.0], s=0.4137, nograde=True),
  'L_boot':  dict(file='TSL_sabaton', kind='boot', heel=[-1.7000000000000455, 75.10000000000002], toe=[66.0, 105.0], s=0.4137, nograde=True),
 },
 'E': {   # E: arms/shield/tassets/cape from the target; painted legs (thigh keys capsule-cropped below the knee, greave, sabaton)
  'thigh_fwd':  dict(file='E_thigh_fwd', kind='limb', A=[52, 22], B=[50, 160], s=0.424, cap=True),
  'thigh_down': dict(file='TEL_thigh', kind='limb', A=[48.0, 5.0], B=[66.0, 132.0], s=0.3965, nograde=True),
  'thigh_back': dict(file='E_thigh_back', kind='limb', A=[45, 25], B=[95, 150], s=0.448, cap=True),
  'kneecop': dict(file='TEL_kneecop', kind='cop', C=[28.0, 65.0], s=0.3965, nograde=True),
  'greave':  dict(file='TEL_greave', kind='limb', A=[43.0, 10.0], B=[55.0, 160.0], s=0.3965, nograde=True),
  'R_boot':  dict(file='TEL_sabaton', kind='boot', heel=[30.0, 91.0], toe=[90.0, 64.0], s=0.3965, nograde=True),
  'L_boot':  dict(file='TEL_sabaton', kind='boot', heel=[30.0, 91.0], toe=[90.0, 64.0], s=0.3965, nograde=True),
 }}
# target layers: s_up = cell px per target px; crest = target crest tip; pelvis = target pelvis point (target px)
TCFG = {
 'E': dict(s_up=0.454, crest=(615, 6), crest_drop=15.0, pelvis_x=668, dx=0.0, dy=0.0,
           cape_pivot=(590, 125), cape_lag_u=1.0, cape_lag_l=1.0, cape_split=0.45, shield_gain=1.0, cape_scale=0.88,
           tasset_pivot=(690, 292), tasset_gain=1.0,
           helm=dict(file='E_helm', mirror=True, crest=(174.5, 5), tcrest=(613.8, 6), k=0.225, neck=(616, 100)),
           layers=('trunk', 'R_pauld', 'shield', 'cape', 'arm', 'tasset'),
           arm_pivot=(705, 165), arm_elbow=(765, 265), arm_head=(1000, 495), arm_r0=6, arm_r1=30, arm_eb=8, arm_gain=1.0),
 'S': dict(s_up=0.454, crest=(692, 15), crest_drop=18.2, pelvis_x=700, dx=0.0, dy=0.0,
           helm=dict(file='S_helm', mirror=False, crest=(172.5, 5), tcrest=(700.5, 12), k=0.235, neck=(700, 125)),
           cape_pivot=(565, 150), cape_lag_u=1.0, cape_lag_l=1.0, cape_split=0.45, shield_gain=1.0,
           layers=('trunk', 'R_pauld', 'shield', 'cape', 'arm'),
           arm_pivot=(570, 180), arm_elbow=(518, 292), arm_head=(443, 537), arm_r0=6, arm_r1=30, arm_eb=8, arm_gain=1.0),
}
OVR = os.path.join(HERE, 'cfg_hybrid.json')
if os.path.exists(OVR):
    for fac, d in json.load(open(OVR)).items():
        TCFG[fac].update(d.get('T', {})); BM.CFG[fac].update(d.get('C', {}))
        for k, v in d.get('P', {}).items(): HPARTS[fac][k].update(v)

if os.environ.get('HELM_OVR'):   # tuning only: '{"k":..,"tcrest":[..]}' merged into every facing's helm
    for fac in TCFG:
        if TCFG[fac].get('helm'): TCFG[fac]['helm'] = {**TCFG[fac]['helm'], **json.loads(os.environ['HELM_OVR'])}

TT, TPRE = {}, {}
import lab34 as LB
from PIL import ImageDraw
GRADE_STRENGTH = 0.8
def target_ref(fac, what):
    """Lab pixels of the approved target used as the colour reference: 'legs' (target legs) or 'helm' (target helm)."""
    T = '/workspace/handoff/class_walk_blockouts/targets/'
    rgb = np.asarray(Image.open(T + f'bastion_rp_{fac}_f00.jpg').convert('RGB')); al = np.asarray(Image.open(T + f'bastion_rp_{fac}_f00_alpha.png').convert('L')) > 127
    PJ = json.load(open(P + 'target_layers.json'))['polygons'][fac]; x0 = PJ.get('crop_x0', 0)
    def pm(poly):
        im = Image.new('L', (al.shape[1], al.shape[0]), 0); ImageDraw.Draw(im).polygon([(x + x0, y) for x, y in poly], fill=1); return np.asarray(im) > 0
    if what == 'helm': m = pm(PJ['helm']) & al
    elif fac == 'E': m = (pm(PJ['Rleg']) | pm(PJ['Lleg'])) & al
    else:
        yy, xx = np.indices(al.shape); m = al & (yy > 480) & (xx > 560) & (xx < 840)
    lab = LB.rgb2lab(rgb); cloth = (lab[..., 2] < -8) & (-lab[..., 2] > np.abs(lab[..., 1]) * 1.2)
    return lab[m & ~cloth]

def grade(im, ref, k=GRADE_STRENGTH):
    """per-class (steel / gold trim) Lab mean+std match of a painted part to the target reference (dark matte steel)."""
    a = im[..., 3] > 0; lab = LB.rgb2lab(im[..., :3]); out = lab.copy()
    gold = lambda L: (L[..., 0] > 35) & (L[..., 2] > 12)
    rg = gold(ref); sg = gold(lab) & a
    for cm, rm in ((a & ~sg, ~rg), (sg, rg)):
        if cm.sum() < 30 or rm.sum() < 30: continue
        for c in range(3):
            mu, sd = lab[..., c][cm].mean(), lab[..., c][cm].std() + 1e-3; rmu, rsd = ref[rm, c].mean(), ref[rm, c].std()
            out[..., c][cm] = (1 - k) * lab[..., c][cm] + k * ((lab[..., c][cm] - mu) / sd * rsd + rmu)
    o = im.copy(); o[..., :3] = np.where(a[..., None], np.clip(LB.lab2rgb(out), 0, 255), 0).astype(np.uint8); return o
LEG_PARTS = ('thigh_fwd', 'thigh_down', 'thigh_back', 'kneecop', 'greave', 'R_boot', 'L_boot')   # graded unless nograde (target-cut)

def prepare_h(facs):
    BM.PARTS.clear(); BM.PARTS.update({f: HPARTS[f] for f in facs})
    import rig_def; rig_def.PARTS = BM.PARTS
    BM.prepare_subset = None
    TEX.clear(); PRE.clear(); DEF.clear()
    for fac in facs:
        for name in HPARTS[fac]:
            im, d = load_part(fac, name)
            if name in LEG_PARTS and not d.get('nograde'): im = grade(im, target_ref(fac, 'legs'))
            if d.get('nograde'): d['s'] = TCFG[fac]['s_up'] * d.get('tk', 1.0)     # target-cut part: target scale (x tk)
            pm, pre = premul_resize(im, d['s']); TEX[(fac, name)] = pm; PRE[(fac, name)] = pre; DEF[(fac, name)] = d
        h = TCFG[fac].get('helm')
        if h:   # painted helm (head faces the direction of travel): painted px -> target px scale k, then s_up
            im = np.asarray(Image.open(P + h['file'] + '.png').convert('RGBA'))
            if h['mirror']: im = np.ascontiguousarray(im[:, ::-1])
            im = grade(im, target_ref(fac, 'helm'))
            TT[(fac, 'phelm')], TPRE[(fac, 'phelm')] = premul_resize(im, TCFG[fac]['s_up'] * h['k'])
        for ly in TCFG[fac]['layers']:
            im = np.asarray(Image.open(P + f'T{fac}_{ly}.png').convert('RGBA'))
            TT[(fac, ly)], TPRE[(fac, ly)] = premul_resize(im, TCFG[fac]['s_up'])

def trunk_M(fac, fr):
    """target px -> cell: uniform s_up, integer translation; crest on the blockout head top (bob), x on the pelvis."""
    t = TCFG[fac]; s = t['s_up']; j = fr['joints']
    cx = j['pelvis'][0] + (t['crest'][0] - t['pelvis_x']) * s + t['dx']; cy = j['head_top'][1] - t['crest_drop'] + t['dy']
    tx, ty = round(cx - s * t['crest'][0]), round(cy - s * t['crest'][1])
    ph = t.get('phase', (0.0, 0.0)); tx, ty = tx + ph[0], ty + ph[1]     # constant sub-px phase (phase_solve.py)
    return np.array([[s, 0, tx], [0, s, ty]], float)

def layer_M(fac, ly, Mt):
    """target-px map -> map for the cropped layer png."""
    o = TL[fac][ly]['origin']; M = Mt.copy(); M[:, 2] = Mt[:, 2] + Mt[:, :2] @ np.array(o, float); return M

def rot_pt(M, c, deg):
    """compose: rotate the output of M by deg (screen, + = counter-clockwise in dvec convention) about cell point c."""
    R = rot_about(deg); A = R @ M[:, :2]; t = R @ (M[:, 2] - c) + c; return np.hstack([A, t[:, None]])

def cape_swing(pm, pivot, du, dl, split, L):
    """two-panel lag as a smooth per-radius rotation about the hang point: angle du near the top -> dl at the hem."""
    yy, xx = np.indices(pm.shape[:2]).astype(np.float32)
    dxp, dyp = xx - pivot[0], yy - pivot[1]; r = np.hypot(dxp, dyp)
    w = np.clip((r / L - split) / (1 - split), 0, 1); w = w * w * (3 - 2 * w)
    th = np.radians(du + (dl - du) * w)
    # inverse map: source = pivot + R(-th) (p - pivot), dvec convention -> screen rotation by -th
    c, s_ = np.cos(th), np.sin(th)
    sx = pivot[0] + c * dxp + s_ * dyp; sy = pivot[1] - s_ * dxp + c * dyp
    return cv2.remap(pm, sx.astype(np.float32), sy.astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)

def lbs(pm, pivot, deg, r0, r1, stretch=1.0, axis=(0.0, 1.0)):
    """rig_fx.lbs_swing (Ironjaw v7): weight 0 inside r0 (under the pauldron) -> 1 beyond r1, + = clockwise on screen."""
    h, w = pm.shape[:2]; yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = xx - pivot[0], yy - pivot[1]; r = np.hypot(dx, dy)
    t = np.clip((r - r0) / max(1e-3, r1 - r0), 0, 1); t = t * t * (3 - 2 * t)
    a = -np.radians(deg) * t; c, s_ = np.cos(a), np.sin(a)
    e = np.asarray(axis, np.float32); e = e / np.linalg.norm(e); k = 1.0 / (1.0 + (stretch - 1.0) * t)
    rx, ry = c * dx - s_ * dy, s_ * dx + c * dy; al = rx * e[0] + ry * e[1]
    rx, ry = rx + (k - 1) * al * e[0], ry + (k - 1) * al * e[1]
    return cv2.remap(pm, (pivot[0] + rx).astype(np.float32), (pivot[1] + ry).astype(np.float32), cv2.INTER_LINEAR,
                     borderMode=cv2.BORDER_CONSTANT, borderValue=0)

MACE_HEAD = {}
def mace_head(fac):
    """blockout mace head centre per frame (magenta in the id pass): the IK goal for the near arm."""
    if fac not in MACE_HEAD:
        out = []
        for i in range(12):
            a = np.asarray(Image.open(f'{B}id/bastion_walk_{fac}_f{i:02d}.png').convert('RGB')).astype(int)
            m = (a[..., 0] > 200) & (a[..., 2] > 200) & (a[..., 1] < 80); ys, xs = np.nonzero(m); out.append(np.array([xs.mean(), ys.mean()]))
        MACE_HEAD[fac] = out
    return MACE_HEAD[fac]

def sang(v): return math.degrees(math.atan2(v[1], v[0]))      # screen angle, + = clockwise (y down)

def arm_ik(P, E0, H0, T):
    """two-bone IK (shoulder P, elbow E0, mace head H0 at rest) -> (shoulder deg, elbow deg), both + = clockwise."""
    L1, L2 = np.linalg.norm(E0 - P), np.linalg.norm(H0 - E0); v = T - P; d = float(np.clip(np.linalg.norm(v), abs(L1 - L2) + 1, L1 + L2 - 1e-3))
    al = math.degrees(math.acos(np.clip((L1 * L1 + d * d - L2 * L2) / (2 * L1 * d), -1, 1)))
    cr = lambda a, b: a[0] * b[1] - a[1] * b[0]
    sg = float(np.sign(cr(H0 - P, E0 - P))) or 1.0
    best = None
    for sgn in (1.0, -1.0):          # keep the elbow on the rest side of the shoulder->head line
        th = math.radians(sang(v) + sgn * al); E = P + L1 * np.array([math.cos(th), math.sin(th)])
        if best is None or float(np.sign(cr(T - P, E - P))) == sg: best = E if best is None or float(np.sign(cr(T - P, E - P))) == sg else best
    E = best; a1 = sang(E - P) - sang(E0 - P); a2 = sang(T - E) - sang(H0 - E0) - a1
    w = lambda x: (x + 180) % 360 - 180
    return w(a1), w(a2)

def arm_maps(shape, P, E0, H0, a1, a2, r0, r1, eb):
    """backward maps: dst -> (shoulder lbs, radial weights) -> (elbow lbs, weight by position along the forearm axis)."""
    h, w = shape; yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    def rot_map(X, Y, piv, deg, t):
        a = -np.radians(deg) * t; c, s_ = np.cos(a), np.sin(a); dx, dy = X - piv[0], Y - piv[1]
        return piv[0] + c * dx - s_ * dy, piv[1] + s_ * dx + c * dy
    r = np.hypot(xx - P[0], yy - P[1]); t = np.clip((r - r0) / max(1e-3, r1 - r0), 0, 1); t = t * t * (3 - 2 * t)
    X1, Y1 = rot_map(xx, yy, P, a1, t)                       # undo the shoulder
    u = (H0 - E0) / np.linalg.norm(H0 - E0); sp = (X1 - E0[0]) * u[0] + (Y1 - E0[1]) * u[1]
    t2 = np.clip((sp + eb) / (2 * eb), 0, 1); t2 = t2 * t2 * (3 - 2 * t2)
    X2, Y2 = rot_map(X1, Y1, E0, a2, t2)                     # undo the elbow (rest pose coords)
    return X2.astype(np.float32), Y2.astype(np.float32)

TLEGS = json.load(open(P + 'target_legs.json'))
def ik2(H, G, l1, l2, side):
    """planar two-bone IK: knee for hip H, goal G, bone lengths l1, l2; side = sign of cross(G-H, K-H) to keep."""
    v = G - H; d = float(np.linalg.norm(v)); u = v / max(d, 1e-9); n = np.array([-u[1], u[0]])
    d = min(d, l1 + l2 - 1e-6)
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d); h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    K = [H + u * a + n * h, H + u * a - n * h]
    cr = lambda p: v[0] * (p - H)[1] - v[1] * (p - H)[0]
    return K[0] if np.sign(cr(K[0])) == side else K[1]

def legs_v3(fac, i, fr, f0, Ms, meta):
    """v3 legs. Every leg piece is a target-cut piece at the trunk scale s_up (no per-bone scale): across = s_up, along =
    s_up x k with 1 <= k <= smax (stretch only when the plant target is out of reach). Each hip is rooted at the target's own
    hip point (target px under the belt corners) mapped like the f00 trunk and moved by the per-frame blockout pelvis delta.
    The blockout gives only the knee bend side (rotation) and the foot-plant targets (ankle, heel/toe -> sabaton, unchanged
    v2 boot code). Optional swing fix: per-frame ankle/boot drop (px down) and toe-down boot rotation about the heel joint."""
    t = TCFG[fac]; lv = t['leg_v3']; Mt0 = trunk_M(fac, f0); s = t['s_up']; smax = lv.get('smax', 1.1)
    dp = jnt(fr, 'pelvis') - jnt(f0, 'pelvis')
    tl = TLEGS
    th, gr, kc = tl[f'{fac}_thigh'], tl[f'{fac}_greave'], tl[f'{fac}_kneecop']
    o_th = np.array(th['origin'], float); Hs = np.array(lv['thigh_hip'], float) - o_th; Bs = np.array(th['B'], float)
    dth, dgr, dkc = DEF[(fac, 'thigh_down')], DEF[(fac, 'greave')], DEF[(fac, 'kneecop')]
    l1 = math.dist(Hs, Bs) * dth['s']; l2 = math.dist(dgr['A'], dgr['B']) * dgr['s']
    sw = t.get('swing', {}); out = {}
    for sd in 'RL':
        hip = Mt0[:, :2] @ np.array(lv['hip'][sd], float) + Mt0[:, 2] + dp - np.array(t.get('phase', (0.0, 0.0)), float) * lv.get('phase_free', 0)
        hb, kb, ab = jnt(fr, sd + '_hip'), jnt(fr, sd + '_knee'), jnt(fr, sd + '_ankle')
        drop = sw.get(sd, {}).get('drop', [0.0] * 12)[i]; G = ab + np.array([0.0, drop])
        vb = ab - hb; side = float(np.sign(vb[0] * (kb - hb)[1] - vb[1] * (kb - hb)[0])) or 1.0
        d = math.dist(hip, G); k = float(np.clip(d / (l1 + l2), 1.0, smax))
        kn = ik2(hip, G, l1 * k, l2 * k, side)
        an = kn + (G - kn) / max(np.linalg.norm(G - kn), 1e-9) * (l2 * k)      # greave end (== G unless out of reach)
        Ms[sd + '_thigh'] = similarity(Bs, Hs, kn, hip, k, dth['s'])
        DEF[(fac, sd + '_thigh')] = dth; TEX[(fac, sd + '_thigh')] = TEX[(fac, 'thigh_down')]; PRE[(fac, sd + '_thigh')] = PRE[(fac, 'thigh_down')]
        Ms[sd + '_greave'] = similarity(dgr['B'], dgr['A'], an, kn, k, dgr['s'])
        am = (ang(kn - hip) + ang(an - kn)) / 2; R = rot_about(am) * dkc['s']
        Ms[sd + '_kneecop'] = np.hstack([R, (kn - R @ np.array(dkc['C'], float))[:, None]])
        if drop: Ms[sd + '_boot'] = Ms[sd + '_boot'] + np.array([[0, 0, 0.0], [0, 0, drop]])
        ka = DEF[(fac, sd + '_boot')].get('tka', 1.0)
        if ka != 1.0:     # along-foot stretch only (<= smax), about the painted heel anchor: rigid in the foot frame
            db = DEF[(fac, sd + '_boot')]; M = Ms[sd + '_boot']; ph = M[:, :2] @ np.array(db['heel'], float) + M[:, 2]
            pt = M[:, :2] @ np.array(db['toe'], float) + M[:, 2]; u = (pt - ph) / np.linalg.norm(pt - ph)
            A = np.eye(2) + (ka - 1) * np.outer(u, u); Ms[sd + '_boot'] = np.hstack([A @ M[:, :2], (A @ (M[:, 2] - ph) + ph)[:, None]])
        rd = sw.get(sd, {}).get('toe_rot', [0.0] * 12)[i]
        if rd: Ms[sd + '_boot'] = rot_pt(Ms[sd + '_boot'], jnt(fr, sd + '_heel') + np.array([0.0, drop]), rd)
        out[sd] = dict(hip=hip, knee=kn, ankle=an, goal=G, stretch=k, reach_short=round(max(0.0, d - (l1 + l2) * k), 2))
        meta[sd + '_thigh'] = ('target_thigh', round(k, 3)); meta[sd + '_greave_k'] = round(k, 3)
    belt = Mt0[:, :2] @ np.mean(np.array(lv['belt'], float), 0) + Mt0[:, 2] + dp - np.array(t.get('phase', (0.0, 0.0)), float) * lv.get('phase_free', 0)
    meta['legs_v3'] = {sd: {kk: (np.round(v, 2).tolist() if isinstance(v, np.ndarray) else v) for kk, v in out[sd].items()} for sd in 'RL'}
    meta['legs_v3']['belt_centre'] = np.round(belt, 2).tolist()
    meta['legs_v3']['hip_mid_off'] = round(float(np.linalg.norm((out['R']['hip'] + out['L']['hip']) / 2 - belt)), 2)
    return out

def render_h(fac, i, keys):
    W = frames(fac); fr = W[i]; f0 = W[0]; t = TCFG[fac]; c = BM.CFG[fac]
    Ms, meta = pose(fac, fr, {s: keys[s][i] for s in 'RL'})
    Mt, Mt0 = trunk_M(fac, fr), trunk_M(fac, f0)
    legj = legs_v3(fac, i, fr, f0, Ms, meta) if t.get('leg_v3') else None   # v3: target-rooted legs (overrides the leg maps)
    if t.get('belt_k', 1.0) != 1.0 and 'belt' in Ms:   # v3: shorter painted tabard (scale along its hang axis about the belt anchor C)
        db = DEF[(fac, 'belt')]; M = Ms['belt']; c0 = M[:, :2] @ np.array(db['C'], float) + M[:, 2]; d0 = M[:, :2] @ np.array(db['D'], float) + M[:, 2]
        u = (d0 - c0) / np.linalg.norm(d0 - c0); A = np.eye(2) + (t['belt_k'] - 1) * np.outer(u, u)
        Ms['belt'] = np.hstack([A @ M[:, :2], (A @ (M[:, 2] - c0) + c0)[:, None]])
    # support-boot sole calibration (sole_cal.py): sub-3 px per-frame nudge so the painted sole sits on the blockout sole
    bf = t.get('boot_fix', {})
    for sd in 'RL':
        fx_ = bf.get(sd, [[0, 0]] * 12)[i]; Ms[sd + '_boot'][:, 2] += np.array(fx_, float)
        rd = t.get('boot_rot', {}).get(sd, [0.0] * 12)[i]
        if rd:   # v2: small rotation about the planted pivot joint (toe while toe-only planted): the pin stays put,
            pl_ = BM.plants(fac)[sd]; k_ = 'toe' if (pl_['toe'][i] and not pl_['heel'][i]) else 'heel'   # the sole line lands on the clay's
            pv = jnt(fr, sd + '_' + k_) + np.array(fx_, float); Ms[sd + '_boot'] = rot_pt(Ms[sd + '_boot'], pv, rd)
    L = {}
    L['trunk'] = layer_M(fac, 'trunk', Mt)
    d_sh = np.round(jnt(fr, 'R_shoulder') - jnt(f0, 'R_shoulder'))
    M = layer_M(fac, 'R_pauld', Mt0); M[:, 2] += d_sh; L['R_pauld'] = M
    a_f = ang(jnt(fr, 'L_wrist') - jnt(fr, 'L_elbow')); a_f0 = ang(jnt(f0, 'L_wrist') - jnt(f0, 'L_elbow'))
    M = layer_M(fac, 'shield', Mt0); M[:, 2] += jnt(fr, 'L_wrist') - jnt(f0, 'L_wrist')
    L['shield'] = rot_pt(M, jnt(fr, 'L_wrist'), t['shield_gain'] * (a_f - a_f0))
    L['cape'] = layer_M(fac, 'cape', Mt)
    cpiv = Mt[:, :2] @ np.array(t['cape_pivot'], float) + Mt[:, 2]
    if t.get('cape_scale', 1.0) != 1.0:      # uniform about the collar (no squash): keeps the hem clear of the blockout soles
        k = t['cape_scale']; M = L['cape']; L['cape'] = np.hstack([k * M[:, :2], (k * (M[:, 2] - cpiv) + cpiv)[:, None]])
    if 'tasset' in t['layers']:               # tassets hang from the belt and swing a few degrees with the TA tabard
        M = layer_M(fac, 'tasset', Mt); tp = Mt[:, :2] @ np.array(t['tasset_pivot'], float) + Mt[:, 2]
        L['tasset'] = rot_pt(M, tp, t['tasset_gain'] * meta['belt_swing'])
        if t.get('tasset_k', 1.0) != 1.0:     # v2: shorter tassets (vertical scale about the belt pivot) so the knee cops show
            k = t['tasset_k']; Sy = np.array([[1, 0, 0], [0, k, (1 - k) * tp[1]]], float)
            Mq = L['tasset']; L['tasset'] = np.hstack([Sy[:, :2] @ Mq[:, :2], (Sy[:, :2] @ Mq[:, 2] + Sy[:, 2])[:, None]])
    if 'arm' in t['layers']:
        M = layer_M(fac, 'arm', Mt0); M[:, 2] += d_sh; L['arm'] = M
    if t.get('helm'):   # painted helm: crest tip on the target crest tip (same top row -> bob/height unchanged),
        h = t['helm']; kk = t['s_up'] * h['k']           # tilt follows the blockout head (head_top - neck) about the neck
        ct = Mt[:, :2] @ np.array(h['tcrest'], float) + Mt[:, 2]
        ct = ct - np.array([0.0, t.get('phase', (0.0, 0.0))[1]])   # the helm (head top row: bob/height) keeps the integer phase
        M = np.array([[kk, 0, ct[0] - kk * h['crest'][0]], [0, kk, ct[1] - kk * h['crest'][1]]], float)
        nk = Mt[:, :2] @ np.array(h['neck'], float) + Mt[:, 2]
        dt = ang(jnt(fr, 'head_top') - jnt(fr, 'neck')) - ang(jnt(f0, 'head_top') - jnt(f0, 'neck'))
        L['phelm'] = rot_pt(M, nk, dt); meta['helm_tilt'] = round(float(dt), 2)
    cols, layers = {}, {}
    for ly, M in L.items():
        w = warp(TT[(fac, ly)], M, TPRE[(fac, ly)])
        if ly == 'cape':
            piv = Mt[:, :2] @ np.array(t['cape_pivot'], float) + Mt[:, 2]
            if t.get('cape_low_k', 1.0) != 1.0:  # (scalar or per-frame list)   # lower panel only (below the pelvis row): shorter by cape_low_k x TA cape_l length
                k0 = t['cape_low_k'][i] if isinstance(t['cape_low_k'], list) else t['cape_low_k']
                kl = k0 * fr['parts']['cape_l']['visible_length_scale'] / f0['parts']['cape_l']['visible_length_scale']
                yk = jnt(fr, 'pelvis')[1] + t.get('cape_low_dy', 0.0)
                yy_, xx_ = np.indices(w.shape[:2]).astype(np.float32)
                sy = np.where(yy_ > yk, yk + (yy_ - yk) / kl, yy_).astype(np.float32)
                w = cv2.remap(w, xx_, sy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0); meta['cape_low_k'] = round(float(kl), 3)
            du = -(fr['parts']['cape_u']['rotation_deg'] - f0['parts']['cape_u']['rotation_deg']) * t['cape_lag_u']
            dl = -(fr['parts']['cape_l']['rotation_deg'] - f0['parts']['cape_l']['rotation_deg']) * t['cape_lag_l']
            w = cape_swing(w, piv, du, dl, t['cape_split'], 170.0); meta['cape_deg'] = (round(du, 2), round(dl, 2))
        if ly == 'arm':
            Ma = Mt0.copy(); Ma[:, 2] += d_sh; piv = Ma[:, :2] @ np.array(t['arm_pivot'], float) + Ma[:, 2]
            E0 = Ma[:, :2] @ np.array(t['arm_elbow'], float) + Ma[:, 2]; H0 = Ma[:, :2] @ np.array(t['arm_head'], float) + Ma[:, 2]
            mh = mace_head(fac); T = H0 - d_sh + t['arm_gain'] * (mh[i] - mh[0]) + (1 - t['arm_gain']) * d_sh
            if t.get('arm_abs', 0.0):   # v2: hold the mace at the blockout's mace head (raised, elbow bent), full swing (gain 1)
                b = t['arm_abs']; T = (1 - b) * T + b * (mh[i] + np.array(t.get('arm_off', [0.0, 0.0]), float))
            T = T + np.array(t.get('arm_lift', [0.0, 0.0]), float)   # constant raise of the hold (elbow bends to reach it)
            a1, a2 = arm_ik(piv, E0, H0, T)
            X, Y = arm_maps(w.shape[:2], piv, E0, H0, a1, a2, t['arm_r0'], t['arm_r1'], t['arm_eb'])
            w = cv2.remap(w, X, Y, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0); meta['arm'] = (round(a1, 2), round(a2, 2)); R_ = lambda d, v: np.array([[math.cos(math.radians(d)), -math.sin(math.radians(d))], [math.sin(math.radians(d)), math.cos(math.radians(d))]]) @ v
            Ea = piv + R_(a1, E0 - piv); Ha = Ea + R_(a1 + a2, H0 - E0)      # where the mace head actually lands (IK may saturate)
            meta['mace_head_xy'] = [float(Ha[0]), float(Ha[1])]; meta['mace_goal_xy'] = [float(T[0]), float(T[1])]
        cols[ly], layers[ly] = to_layer(w)
    for nm, M in Ms.items():
        cols[nm], layers[nm] = to_layer(warp(TEX[(fac, nm)], M, PRE[(fac, nm)]))
    yy, xx = np.indices((CH, CW)).astype(float)
    for s in 'RL':
        hip, kn = (legj[s]['hip'], legj[s]['knee']) if legj else (jnt(fr, s + '_hip'), jnt(fr, s + '_knee'))
        Lh = max(math.dist(hip, kn), 1e-3); v = (hip - kn) / Lh
        tt = (xx - kn[0]) * v[0] + (yy - kn[1]) * v[1]; r = 12; C = kn + v * (Lh + c['thigh_cap'] - r)
        layers[s + '_thigh'] &= (tt <= Lh + c['thigh_cap'] - r) | (np.hypot(xx - C[0], yy - C[1]) <= r + 6)
    # order, nearest first
    idx = {n: k for k, n in enumerate(fr['draw_order'])}
    legz = {s: min(idx[f'{s}_thigh'], idx[f'{s}_shin'], idx[f'{s}_boot']) for s in 'RL'}
    near, far = sorted('RL', key=lambda s: legz[s])
    if fac == 'S':
        order = ['phelm', 'R_pauld', 'arm', 'R_elbowcop', 'R_upper', 'R_fore', 'shield', 'trunk', 'L_fore', 'L_elbowcop', 'L_upper', 'belt']
        for s in (near, far): order += [f'{s}_boot', f'{s}_kneecop', f'{s}_greave', f'{s}_thigh']
        order += ['cape']
    else:   # E (back 3/4): cape hangs in front of the legs; tassets over the thigh tops; shield face over the far arm
        order = ['phelm', 'R_pauld', 'arm', 'cape', 'shield', 'tasset', 'trunk']
        for s in (near, far): order += [f'{s}_boot', f'{s}_kneecop', f'{s}_greave', f'{s}_thigh']
    order = [n for n in order if n in layers]
    eff = {nm: layers[nm].copy() for nm in order}
    for win, lose in [w_l for w_l in [('belt', 'R_thigh'), ('belt', 'L_thigh'), ('R_boot', 'belt'), ('L_boot', 'belt'), ('R_kneecop', 'belt'), ('L_kneecop', 'belt')] if w_l[0] in eff and w_l[1] in eff]:
        if fac == 'S' and win.endswith('kneecop'): continue
        eff[lose] &= ~layers[win]
    rgb = np.zeros((CH, CW, 3), np.float32); al = np.zeros((CH, CW), bool); owner = np.full((CH, CW), -1, np.int16)
    for nm in reversed(order):
        m = eff[nm]; rgb[m] = cols[nm][m]; al |= m; owner[m] = order.index(nm)
    meta['order'] = order
    return rgb, al, layers, owner, {**Ms, **L}, meta, order

def gold_lift(cell, dl):
    # global gold-trim grade: downscaling the target layers darkens the thin gold trims (outline bleed); lift L* of
    # gold pixels by dl so the trim reads at the target's value. Same class rule as the metric's palette ('bone').
    if not dl: return cell
    from skimage.color import rgb2lab, lab2rgb
    m = cell[..., 3] > 0; lab = rgb2lab(cell[..., :3])
    g = m & (lab[..., 0] > 35) & (lab[..., 2] > 12) & ~((lab[..., 2] < -8) & (-lab[..., 2] > np.abs(lab[..., 1]) * 1.2))
    lab[..., 0][g] = np.clip(lab[..., 0][g] + dl, 0, 100)
    out = cell.copy(); out[..., :3] = np.clip(lab2rgb(lab) * 255 + .5, 0, 255).astype(np.uint8); out[..., :3][~g] = cell[..., :3][~g]
    return out

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--only', default='S'); ap.add_argument('--frames', default='')
    ap.add_argument('--out', default=os.path.join(HERE, '..', 'frames')); a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True); prepare_h(a.only)
    fl = [int(x) for x in a.frames.split(',')] if a.frames else list(range(12))
    info = {}
    for fac in a.only:
        keys, kv = thigh_keys(fac)
        for i in fl:
            rgb, al, layers, owner, Ms, meta, order = render_h(fac, i, keys)
            cell, ci = clean_cell(compose_cell(rgb, al))
            cell = gold_lift(cell, TCFG[fac].get('gold_lift', 0.0))
            Image.fromarray(cell, 'RGBA').save(f'{a.out}/bastion_walk_{fac}_f{i:02d}.png')
            info[f'{fac}_f{i:02d}'] = dict(meta=meta, clean=ci)
    json.dump(info, open(os.path.join(a.out, '_build_info.json'), 'w'), indent=1, default=str)
    print('ok', len(info))
