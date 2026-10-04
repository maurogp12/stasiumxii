"""Walk-guide blockouts (clay + part-ID passes + joints) for the PC classes, matching the Technical Artist's
Ironjaw guide: orthographic camera, azimuth 45 deg, 30 deg below horizontal, ortho_scale 494.62 over a 512x360 cell,
pivot (256, 329) under the pelvis, 12 frames at 17.144 fps. S = front 3/4 walking down-right, E = back 3/4 walking
up-right; W and N are mirrors. Contacts: S f00 (R foot forward) / f06; E f05 / f11 like Ironjaw.
usage: python blockout.py <class> <outdir>     (run with the bpy 4.2 module)"""
import sys, os, json, math
import numpy as np
import bpy, mathutils
from bpy_extras.object_utils import world_to_camera_view

W, H_CELL, PIVOT = 512, 360, (256, 329)
ORTHO = 494.6236559139785
PX = W / ORTHO                                   # screen px per world unit
FRAMES = 12

# ---------------------------------------------------------------- class definitions (fractions of height H)
# v2 proportions (4 Oct): measured from Mauro's approved painted targets, where the hip sits at 0.57-0.61 of the height.
# v1 had the hip at 0.50, so painted legs came out short and stubby under the target's upper body.
BASE = dict(hip=0.585, chest=0.745, shoulder=0.825, neck=0.86, head_c=0.918, head=0.082,
            hip_w=0.070, sh_w=0.115, thigh=0.265, shin=0.275, ankle=0.045, foot=0.14,
            uarm=0.170, farm=0.150, hand=0.060, stride=0.30, drop=0.030, lift=0.07, lean=4.0,
            arm_swing=(18, 18), elbow=(20, 20), abduct=(8, 8), yaw=6.0, sway=0.012,
            limb_w=dict(thigh=0.085, shin=0.065, boot=0.075, uarm=0.060, farm=0.052, hand=0.05),
            torso_w=0.24, torso_d=0.14, pelvis_w=0.20)
CLASSES = {
 # hooded ranger: longbow low in the right hand, quiver on the back, ragged knee-length cloak, tall boots
 'kestrel': dict(BASE, H=250, label='Kestrel (ranger)', hip=0.605, thigh=0.275, shin=0.285, stride=0.32, sh_w=0.105, torso_w=0.21, torso_d=0.12, pelvis_w=0.18,
                 arm_swing=(8, 20), elbow=(28, 18), abduct=(10, 7),
                 limb_w=dict(thigh=0.078, shin=0.060, boot=0.072, uarm=0.050, farm=0.046, hand=0.045),
                 extras=['hood', 'cloak', 'quiver', 'bow']),
 # hooded rogue: twin curved daggers held low and out, long ragged cloak, slight crouch and forward lean
 'gloam': dict(BASE, H=250, label='Gloam (rogue)', hip=0.56, thigh=0.255, shin=0.265, chest=0.72, shoulder=0.80, neck=0.835, head_c=0.895,
               lean=11.0, stride=0.27, drop=0.025, sh_w=0.11, torso_w=0.215, torso_d=0.13, pelvis_w=0.19,
               arm_swing=(9, 9), elbow=(62, 62), abduct=(16, 16),
               limb_w=dict(thigh=0.080, shin=0.062, boot=0.074, uarm=0.054, farm=0.050, hand=0.048),
               extras=['hood_tall', 'cloak_long', 'dagger_R', 'dagger_L']),
 # gold-trimmed knight: kite shield on the left forearm, flanged morning-star mace in the right hand,
 # pauldrons, blue tabard front/back, long ragged blue cape. Heavier, shorter stride, more bob.
 # calm cleric healer (design B): hood and short mantle, long ivory robe to the boots, sage sash,
 # tall crook staff in the right hand with a caged jade lantern hanging from the crook, vial pouches at the hips
 'mender': dict(BASE, H=245, label='Mender (healer)', sh_w=0.105, torso_w=0.22, torso_d=0.13, pelvis_w=0.21,
                stride=0.28, drop=0.022, lift=0.05, lean=2.0, arm_swing=(6, 14), elbow=(35, 18), abduct=(12, 8),
                limb_w=dict(thigh=0.080, shin=0.062, boot=0.072, uarm=0.058, farm=0.052, hand=0.046),
                hip=0.585, extras=['hood', 'robe', 'staff', 'pouches']),
 'bastion': dict(BASE, H=273, label='Bastion (knight)', sh_w=0.145, torso_w=0.30, torso_d=0.17, pelvis_w=0.24,
                 stride=0.28, hip_w=0.085, hip=0.575, drop=0.035, lift=0.055, yaw=4.0, arm_swing=(12, 4), elbow=(30, 85), abduct=(9, 14),
                 limb_w=dict(thigh=0.105, shin=0.085, boot=0.095, uarm=0.085, farm=0.075, hand=0.065),
                 extras=['helm', 'pauldrons', 'tabard', 'cape', 'mace', 'shield']),
}

# part-ID colours (same families as the Ironjaw guide: right side oranges, left side blues)
IDC = dict(torso=(0.62, 0.62, 0.62), pelvis=(0.50, 0.50, 0.52), head=(0.80, 0.80, 0.80), neck=(0.70, 0.70, 0.70),
           R_uarm=(1.0, 0.75, 0.45), R_farm=(0.97, 0.55, 0.20), R_hand=(0.85, 0.40, 0.10),
           L_uarm=(0.55, 0.75, 1.0), L_farm=(0.35, 0.55, 0.90), L_hand=(0.15, 0.35, 0.75),
           R_thigh=(0.95, 0.60, 0.25), R_shin=(0.85, 0.45, 0.15), R_boot=(0.65, 0.30, 0.10),
           L_thigh=(0.40, 0.60, 0.95), L_shin=(0.25, 0.45, 0.85), L_boot=(0.10, 0.25, 0.65),
           cape=(0.50, 0.25, 0.25), cape2=(0.40, 0.18, 0.18), hood=(0.72, 0.72, 0.76), quiver=(0.55, 0.35, 0.20),
           weapon_R=(0.85, 0.20, 0.80), weapon_L=(0.15, 0.80, 0.40), shield=(0.15, 0.80, 0.40),
           tabard=(0.30, 0.30, 0.65), R_pauld=(1.0, 0.85, 0.60), L_pauld=(0.70, 0.85, 1.0), helm=(0.85, 0.85, 0.85))

# ---------------------------------------------------------------- math helpers
def rot(axis, deg):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a); x, y, z = axis
    return np.array([[c + x * x * (1 - c), x * y * (1 - c) - z * s, x * z * (1 - c) + y * s],
                     [y * x * (1 - c) + z * s, c + y * y * (1 - c), y * z * (1 - c) - x * s],
                     [z * x * (1 - c) - y * s, z * y * (1 - c) + x * s, c + z * z * (1 - c)]])
X, Y, Z = np.array([1., 0, 0]), np.array([0., 1, 0]), np.array([0., 0, 1])
def nrm(v): return v / (np.linalg.norm(v) + 1e-9)
def seg_frame(a, b, side):
    """4x4: origin a, local Z along a->b, local X ~ side."""
    z = nrm(b - a); x = nrm(side - z * np.dot(side, z)); y = np.cross(z, x)
    M = np.eye(4); M[:3, 0], M[:3, 1], M[:3, 2], M[:3, 3] = x, y, z, a; return M
def frame(R, o):
    M = np.eye(4); M[:3, :3] = R; M[:3, 3] = o; return M
def smooth(t): return t * t * (3 - 2 * t)

def ik(hip, ank, l1, l2, fwd):
    d = ank - hip; L = np.linalg.norm(d); L = min(L, (l1 + l2) * 0.999); u = nrm(d)
    a = (l1 * l1 - l2 * l2 + L * L) / (2 * L); h = math.sqrt(max(0.0, l1 * l1 - a * a))
    bend = nrm(fwd - u * np.dot(fwd, u))
    return hip + u * a + bend * h

# ---------------------------------------------------------------- pose
def pose(C, t, idle=False):
    """Joint positions in body space (X right, Y forward, Z up), ground at Z=0, pelvis over origin.
    t in [0,1): R foot lands forward at t=0, L at t=0.5."""
    Hh = C['H']; f = lambda k: C[k] * Hh
    S = 0.0 if idle else C['stride'] * Hh
    J = {}
    ph = 2 * math.pi * t
    drop = 0.0 if idle else C['drop'] * Hh * (0.5 + 0.5 * math.cos(2 * ph))      # low at contacts
    sway = 0.0 if idle else C['sway'] * Hh * math.sin(ph)
    yaw = 0.0 if idle else C['yaw'] * math.cos(ph)                                # R hip forward at t=0
    pel = np.array([sway, 0, f('hip') - drop])
    Rp = rot(Z, yaw)
    lean = rot(X, -C['lean'])                                                     # forward lean (top goes +Y)
    Rc = rot(Z, -yaw * 0.7) @ lean
    J['pelvis'] = pel
    chest = pel + Rc @ np.array([0, 0, f('chest') - f('hip')])
    J['chest'] = chest
    J['neck'] = pel + Rc @ np.array([0, 0, f('neck') - f('hip')])
    J['head_c'] = pel + Rc @ np.array([0, 0.01 * Hh, f('head_c') - f('hip')])
    J['head_top'] = J['head_c'] + Rc @ np.array([0, 0, f('head') * 1.0])
    for side, sg, p0 in (('R', 1, 0.0), ('L', -1, 0.5)):
        hip = pel + Rp @ np.array([sg * f('hip_w'), 0, -0.02 * Hh])
        J[f'{side}_hip'] = hip
        u = (t + p0) % 1.0
        if idle:
            fy, fz, pitch = (0.02 * Hh * (1 if side == 'R' else -1)), 0.0, 0.0
        elif u < 0.6:                                   # stance: foot slides back under the body
            s = u / 0.6; fy = S / 2 - S * s; fz = 0.0
            pitch = 14 * (1 - s / 0.15) if s < 0.15 else (0 if s < 0.7 else -32 * (s - 0.7) / 0.3)
        else:                                           # swing
            s = (u - 0.6) / 0.4; fy = -S / 2 + S * smooth(s); fz = C['lift'] * Hh * math.sin(math.pi * s)
            pitch = -32 * (1 - s) + 12 * s
        fx = sg * f('hip_w') * 0.9
        # foot frame: heel-to-toe along +Y, pitched; ankle above the heel third
        Rf = rot(X, pitch)
        oh = np.array([0, -0.25 * f('foot'), -f('ankle')]); ot = np.array([0, 0.75 * f('foot'), -f('ankle')])   # v3: toe joint on the sole
        ank = np.array([fx, fy, fz + f('ankle')])
        if fz == 0 and not idle and pitch > 0:           # heel strike: the heel is the planted point (no skate)
            heel = np.array([fx, fy - 0.25 * f('foot'), 0.0]); ank = heel - Rf @ oh
        elif fz == 0 and not idle and pitch < 0:         # heel off: roll over the planted toe
            toe = np.array([fx, fy + 0.75 * f('foot'), 0.0]); ank = toe - Rf @ ot
        heel = ank + Rf @ oh; toe = ank + Rf @ ot
        J[f'{side}_ankle'], J[f'{side}_heel'], J[f'{side}_toe'] = ank, heel, toe
        J[f'{side}_knee'] = ik(hip, ank, f('thigh'), f('shin'), Rp @ Y)
        # arms (swing opposite to the same-side leg)
        i = 0 if side == 'R' else 1
        A = 0.0 if idle else C['arm_swing'][i] * (-math.cos(ph) if side == 'R' else math.cos(ph))
        sh = pel + Rc @ np.array([sg * f('sh_w'), 0, f('shoulder') - f('hip')])
        J[f'{side}_shoulder'] = sh
        Ru = Rc @ rot(Y, sg * -C['abduct'][i]) @ rot(X, A)                          # +A swings the arm forward
        el = sh + Ru @ np.array([0, 0, -f('uarm')])
        Rf2 = Ru @ rot(X, C['elbow'][i] + max(0, A) * 0.6)
        wr = el + Rf2 @ np.array([0, 0, -f('farm')])
        J[f'{side}_elbow'], J[f'{side}_wrist'] = el, wr
        J[f'{side}_hand'] = wr + Rf2 @ np.array([0, 0, -f('hand') * 0.5])
        J[f'_R{side}_farm'] = Rf2; J[f'_A{side}'] = A
    # cloth: two-link panel from the upper back, lagging the pelvis
    lag = 0.0 if idle else math.sin(ph - 1.0)
    back = Rc @ np.array([0, -C['torso_d'] * Hh * 0.55, 0])
    J['cape_top'] = J['neck'] + back + np.array([0, 0, -0.02 * Hh])
    J['cape_mid'] = J['cape_top'] + np.array([0.012 * Hh * lag, -0.05 * Hh - (0 if idle else 0.015 * Hh), -0.28 * Hh])
    J['cape_hem'] = J['cape_mid'] + np.array([0.025 * Hh * lag, -0.03 * Hh - (0 if idle else 0.03 * Hh), -0.22 * Hh])
    J['_Rc'], J['_Rp'] = Rc, Rp
    if not idle:
        _straighten(C, J, 0.976 - 0.012 * math.cos(4 * math.pi * t))
    return J

STANCE_EXT = 0.985     # v3: planted leg nearly straight (hip-ankle / leg length), as in the painted targets

def _straighten(C, J, ext=STANCE_EXT):
    """v3: raise the body so the most-bent planted leg is `ext` straight (0.964 at contact, 0.988 mid-stance), then re-solve the knees.
    v2 kept the pelvis drop and left planted knees bent about 30 deg, which read as a crouch once painted."""
    Hh = C['H']; L = (C['thigh'] + C['shin']) * Hh; need = []
    for s in 'RL':
        a, h = J[f'{s}_ankle'], J[f'{s}_hip']
        if J[f'{s}_heel'][2] <= 0.5 or J[f'{s}_toe'][2] <= 0.5:        # planted
            dxy = np.hypot(*(h[:2] - a[:2])); z_ok = np.sqrt(max(0.0, (ext * L) ** 2 - dxy ** 2))
            need.append(a[2] + z_ok - h[2])
    if not need: return
    dz = min(need)
    feet = {f'{s}_{k}' for s in 'RL' for k in ('ankle', 'heel', 'toe')}
    for k in list(J):
        if k.startswith('_') or k in feet or k.endswith('knee'): continue
        J[k] = J[k] + np.array([0, 0, dz])
    for s in 'RL':
        J[f'{s}_knee'] = ik(J[f'{s}_hip'], J[f'{s}_ankle'], C['thigh'] * Hh, C['shin'] * Hh, J['_Rp'] @ Y)

# ---------------------------------------------------------------- scene
def mk_box(name, sx, sy, z0, z1, col, coll):
    me = bpy.data.meshes.new(name)
    x, y = sx / 2, sy / 2
    v = [(-x, -y, z0), (x, -y, z0), (x, y, z0), (-x, y, z0), (-x, -y, z1), (x, -y, z1), (x, y, z1), (-x, y, z1)]
    fc = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    me.from_pydata(v, [], fc); me.update()
    o = bpy.data.objects.new(name, me); coll.objects.link(o); o.color = (*[c ** 2.2 for c in col], 1); return o

def mk_mesh(name, verts, faces, col, coll):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    o = bpy.data.objects.new(name, me); coll.objects.link(o); o.color = (*[c ** 2.2 for c in col], 1); return o

def spiky_ball(r, n_sp=10):
    """icosahedron + spikes: verts/faces (morning-star head)."""
    t = (1 + 5 ** .5) / 2
    V = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    V = [tuple(np.array(v) / np.linalg.norm(v) * r) for v in V]
    F = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
         (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    out_v, out_f = list(V), list(F)
    for k in range(12):                                   # a cone spike out of every vertex
        d = np.array(V[k]) / r; base = len(out_v); a = nrm(np.cross(d, [0.3, 0.7, 0.2])); b = np.cross(d, a)
        for j in range(4):
            ang = j * math.pi / 2; out_v.append(tuple(d * r * 0.8 + (a * math.cos(ang) + b * math.sin(ang)) * r * 0.28))
        out_v.append(tuple(d * r * 1.75))
        for j in range(4): out_f.append((base + j, base + (j + 1) % 4, base + 4))
    return out_v, out_f

def build(C):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene; coll = sc.collection; Hh = C['H']; f = lambda k: C[k] * Hh; lw = C['limb_w']
    P = {}
    P['pelvis'] = mk_box('pelvis', f('pelvis_w'), C['torso_d'] * Hh * 0.9, -0.07 * Hh, 0.05 * Hh, IDC['pelvis'], coll)
    P['torso'] = mk_box('torso', f('torso_w'), C['torso_d'] * Hh, 0.03 * Hh, (C['shoulder'] - C['hip'] + 0.02) * Hh, IDC['torso'], coll)
    P['neck'] = mk_box('neck', 0.06 * Hh, 0.06 * Hh, 0, (C['head_c'] - C['neck']) * Hh, IDC['neck'], coll)
    hw = 0.085 * Hh
    P['head'] = mk_box('head', hw * 1.25, hw * 1.35, -f('head') * 0.75, f('head'), IDC['head'], coll)
    for s in 'RL':
        P[f'{s}_uarm'] = mk_box(f'{s}_uarm', lw['uarm'] * Hh, lw['uarm'] * Hh, 0, f('uarm'), IDC[f'{s}_uarm'], coll)
        P[f'{s}_farm'] = mk_box(f'{s}_farm', lw['farm'] * Hh, lw['farm'] * Hh, 0, f('farm'), IDC[f'{s}_farm'], coll)
        P[f'{s}_hand'] = mk_box(f'{s}_hand', lw['hand'] * Hh, lw['hand'] * Hh * 1.2, -f('hand') * 0.2, f('hand'), IDC[f'{s}_hand'], coll)
        P[f'{s}_thigh'] = mk_box(f'{s}_thigh', lw['thigh'] * Hh, lw['thigh'] * Hh, -0.02 * Hh, f('thigh'), IDC[f'{s}_thigh'], coll)
        P[f'{s}_shin'] = mk_box(f'{s}_shin', lw['shin'] * Hh, lw['shin'] * Hh * 1.05, 0, f('shin'), IDC[f'{s}_shin'], coll)
        P[f'{s}_boot'] = mk_box(f'{s}_boot', lw['boot'] * Hh, lw['boot'] * Hh, 0, f('foot'), IDC[f'{s}_boot'], coll)
        P[f'{s}_bootshaft'] = mk_box(f'{s}_bootshaft', lw['boot'] * Hh * 0.95, lw['boot'] * Hh, 0, 0.13 * Hh, IDC[f'{s}_boot'], coll)
    ex = C['extras']
    if 'hood' in ex or 'hood_tall' in ex:
        tall = 'hood_tall' in ex
        k = 1.0
        v = [(-1, -1.1, -0.9), (1, -1.1, -0.9), (1, 0.9, -0.9), (-1, 0.9, -0.9), (-1.05, -1.25, 0.9), (1.05, -1.25, 0.9),
             (0.9, 0.95, 0.85), (-0.9, 0.95, 0.85), (0, -1.6 if tall else -1.3, 1.75 if tall else 1.25)]
        v = [(a * hw * 0.78, b * hw * 0.85, c * hw * 0.85) for a, b, c in v]
        F = [(0, 1, 5, 4), (1, 2, 6, 5), (3, 0, 4, 7), (4, 5, 8), (5, 6, 8), (6, 7, 8), (7, 4, 8), (0, 3, 2, 1)]
        P['hood'] = mk_mesh('hood', v, F, IDC['hood'], coll)
        P['mantle'] = mk_box('mantle', f('torso_w') * 1.15, C['torso_d'] * Hh * 1.25, -0.10 * Hh, 0.0, IDC['hood'], coll)
    if 'helm' in ex:
        P['helm'] = mk_box('helm', hw * 1.45, hw * 1.55, -f('head') * 0.85, f('head') * 1.15, IDC['helm'], coll)
        P['helm_crest'] = mk_box('helm_crest', hw * 0.25, hw * 1.4, f('head') * 1.1, f('head') * 1.35, IDC['helm'], coll)
    if 'pauldrons' in ex:
        for s in 'RL':
            P[f'{s}_pauld'] = mk_box(f'{s}_pauld', 0.13 * Hh, 0.14 * Hh, -0.07 * Hh, 0.035 * Hh, IDC[f'{s}_pauld'], coll)
    cw = {'cloak': 0.27, 'cloak_long': 0.27, 'cape': 0.27}
    for key, w in cw.items():
        if key in ex:
            P['cape_u'] = mk_box('cape_u', w * Hh, 0.02 * Hh, 0, 1, IDC['cape'], coll)      # length scaled per frame
            P['cape_l'] = mk_box('cape_l', w * Hh * 1.12, 0.02 * Hh, 0, 1, IDC['cape2'], coll)
            C['_cape_len'] = 1.25 if key == 'cloak_long' else (1.15 if key == 'cape' else 0.95)
    if 'robe' in ex:                                     # robe skirt: front and back panels down to the boot tops
        P['tabard_f'] = mk_box('tabard_f', 0.24 * Hh, 0.02 * Hh, -0.40 * Hh, 0.02 * Hh, IDC['tabard'], coll)
        P['tabard_b'] = mk_box('tabard_b', 0.26 * Hh, 0.02 * Hh, -0.42 * Hh, 0.02 * Hh, IDC['tabard'], coll)
        for sd in 'RL':
            P[f'robe_{sd}'] = mk_box(f'robe_{sd}', 0.02 * Hh, 0.14 * Hh, -0.38 * Hh, 0.02 * Hh, IDC['tabard'], coll)
        P['sash'] = mk_box('sash', 0.07 * Hh, 0.015 * Hh, -0.24 * Hh, 0.0, IDC['cape'], coll)
    if 'staff' in ex:                                    # crook staff: shaft, crook hook, lantern
        P['staff'] = mk_box('staff', 0.022 * Hh, 0.022 * Hh, -0.40 * Hh, 0.55 * Hh, IDC['weapon_R'], coll)
        P['crook'] = mk_box('crook', 0.02 * Hh, 0.11 * Hh, -0.02 * Hh, 0.02 * Hh, IDC['weapon_R'], coll)
        P['lantern'] = mk_box('lantern', 0.06 * Hh, 0.06 * Hh, -0.10 * Hh, 0.0, IDC['weapon_L'], coll)
    if 'pouches' in ex:
        for sd in 'RL':
            P[f'pouch_{sd}'] = mk_box(f'pouch_{sd}', 0.06 * Hh, 0.06 * Hh, -0.07 * Hh, 0.0, IDC['quiver'], coll)
    if 'tabard' in ex:
        P['tabard_f'] = mk_box('tabard_f', 0.13 * Hh, 0.015 * Hh, -0.27 * Hh, 0, IDC['tabard'], coll)
        P['tabard_b'] = mk_box('tabard_b', 0.15 * Hh, 0.015 * Hh, -0.25 * Hh, 0, IDC['tabard'], coll)
    if 'quiver' in ex:
        P['quiver'] = mk_box('quiver', 0.06 * Hh, 0.06 * Hh, -0.15 * Hh, 0.12 * Hh, IDC['quiver'], coll)
    if 'bow' in ex:                                       # recurve longbow as a bent strip of 6 segments + string
        n = 6; L = 0.62 * Hh; verts, faces = [], []
        pts = [(0, 0.06 * Hh * math.sin(math.pi * k / n) - 0.05 * Hh * (1 if k in (0, n) else 0), -L / 2 + L * k / n) for k in range(n + 1)]
        th = 0.018 * Hh
        for k, (x, y, z) in enumerate(pts):
            wk = th * (1.6 if k == n // 2 else 1.0)
            verts += [(x - wk / 2, y - wk / 2, z), (x + wk / 2, y - wk / 2, z), (x + wk / 2, y + wk / 2, z), (x - wk / 2, y + wk / 2, z)]
        for k in range(n):
            a, b = 4 * k, 4 * (k + 1)
            for j in range(4): faces.append((a + j, a + (j + 1) % 4, b + (j + 1) % 4, b + j))
        s0 = len(verts); verts += [(0, -0.05 * Hh, -L / 2), (0.003 * Hh, -0.05 * Hh, -L / 2), (0.003 * Hh, -0.05 * Hh, L / 2), (0, -0.05 * Hh, L / 2)]
        faces.append((s0, s0 + 1, s0 + 2, s0 + 3))
        P['bow'] = mk_mesh('bow', verts, faces, IDC['weapon_R'], coll)
    for s in 'RL':
        if f'dagger_{s}' in ex:                          # curved blade: tapered quad strip, cross-guard
            L = 0.25 * Hh; th = 0.015 * Hh
            v = [(-th, 0, 0), (th, 0, 0), (th, 0.035 * Hh, 0.05 * Hh), (-th, 0.035 * Hh, 0.05 * Hh),
                 (-th / 2, 0.02 * Hh, L * 0.6), (th / 2, 0.02 * Hh, L * 0.6), (0, -0.03 * Hh, L), (0, -0.03 * Hh, L)]
            v += [(-th, -0.012 * Hh, 0), (th, -0.012 * Hh, 0)]
            F = [(0, 1, 2, 3), (3, 2, 5, 4), (4, 5, 6), (0, 3, 4, 8), (1, 9, 5, 2), (8, 4, 6), (9, 6, 5)]
            P[f'dagger_{s}'] = mk_mesh(f'dagger_{s}', v, F, IDC['weapon_R' if s == 'R' else 'weapon_L'], coll)
            P[f'guard_{s}'] = mk_box(f'guard_{s}', 0.05 * Hh, 0.02 * Hh, -0.01 * Hh, 0.01 * Hh, IDC['weapon_R' if s == 'R' else 'weapon_L'], coll)
    if 'mace' in ex:
        P['mace_handle'] = mk_box('mace_handle', 0.028 * Hh, 0.028 * Hh, -0.06 * Hh, 0.26 * Hh, IDC['weapon_R'], coll)
        bv, bf = spiky_ball(0.05 * Hh)
        P['mace_head'] = mk_mesh('mace_head', bv, bf, IDC['weapon_R'], coll)
    if 'shield' in ex:                                   # kite shield: pentagon plate, curved slightly
        w, h = 0.22 * Hh, 0.40 * Hh; d = 0.02 * Hh
        o2 = [(-w / 2, 0.42 * h), (w / 2, 0.42 * h), (w * 0.47, -0.05 * h), (0, -0.58 * h), (-w * 0.47, -0.05 * h)]
        v = [(x, -d / 2 - 0.006 * Hh * (1 - (2 * x / w) ** 2), z) for x, z in o2] + [(x, d / 2, z) for x, z in o2]
        F = [(0, 1, 2, 3, 4), (9, 8, 7, 6, 5)] + [(k, (k + 1) % 5, 5 + (k + 1) % 5, 5 + k) for k in range(5)]
        P['shield'] = mk_mesh('shield', v, F, IDC['shield'], coll)
    # camera
    cam = bpy.data.cameras.new('cam'); co = bpy.data.objects.new('cam', cam); coll.objects.link(co); sc.camera = co
    cam.type = 'ORTHO'; cam.ortho_scale = ORTHO
    el, az = math.radians(30), math.radians(-45)
    d = np.array([math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)])
    co.location = mathutils.Vector(tuple(d * 2000))
    co.rotation_euler = (-mathutils.Vector(tuple(d))).to_track_quat('-Z', 'Y').to_euler()
    cam.clip_end = 5000
    cam.shift_y = (PIVOT[1] - H_CELL / 2) / W; cam.shift_x = (W / 2 - PIVOT[0]) / W
    sc.render.resolution_x, sc.render.resolution_y = W, H_CELL
    sc.render.film_transparent = True
    sc.render.engine = 'BLENDER_WORKBENCH'
    return P

def place(P, C, J, facing):
    """Pose all parts for joints J (body space) and facing ('S' -> forward +X, 'E' -> forward +Y)."""
    Hh = C['H']
    Rf = rot(Z, -90) if facing == 'S' else np.eye(3)
    w = lambda k: Rf @ J[k]
    Rc, Rp = Rf @ J['_Rc'], Rf @ J['_Rp']
    M = {}
    M['pelvis'] = frame(Rp, w('pelvis'))
    M['torso'] = frame(Rc, w('pelvis'))
    M['neck'] = seg_frame(w('neck'), w('head_c'), Rc @ X)
    M['head'] = frame(Rc, w('head_c'))
    right = Rc @ X
    for s in 'RL':
        M[f'{s}_uarm'] = seg_frame(w(f'{s}_shoulder'), w(f'{s}_elbow'), right)
        M[f'{s}_farm'] = seg_frame(w(f'{s}_elbow'), w(f'{s}_wrist'), right)
        M[f'{s}_hand'] = seg_frame(w(f'{s}_wrist'), w(f'{s}_wrist') + (w(f'{s}_wrist') - w(f'{s}_elbow')), right)
        M[f'{s}_thigh'] = seg_frame(w(f'{s}_hip'), w(f'{s}_knee'), Rp @ X)
        M[f'{s}_shin'] = seg_frame(w(f'{s}_knee'), w(f'{s}_ankle'), Rp @ X)
        heel, toe = w(f'{s}_heel'), w(f'{s}_toe')
        M[f'{s}_boot'] = seg_frame(heel + (Rf @ Z) * C['H'] * 0.03, toe + (Rf @ Z) * C['H'] * 0.03, Rf @ X)
        M[f'{s}_bootshaft'] = seg_frame(w(f'{s}_ankle') - (Rf @ Z) * Hh * 0.02, w(f'{s}_knee'), Rp @ X)
    if 'hood' in P:
        M['hood'] = frame(Rc, w('head_c')); M['mantle'] = frame(Rc, w('neck'))
    if 'helm' in P:
        M['helm'] = frame(Rc, w('head_c')); M['helm_crest'] = frame(Rc, w('head_c'))
    for s in 'RL':
        if f'{s}_pauld' in P: M[f'{s}_pauld'] = frame(Rc @ rot(Y, (12 if s == 'R' else -12)), w(f'{s}_shoulder') + Rc @ Z * Hh * 0.01)
    if 'cape_u' in P:
        k = C['_cape_len']; top, mid, hem = w('cape_top'), w('cape_mid'), w('cape_hem')
        mid = top + (mid - top) * k; hem = mid + (hem - w('cape_mid')) * k
        Mu = seg_frame(top, mid, right); Mu[:3, 2] *= np.linalg.norm(mid - top); M['cape_u'] = Mu
        Ml = seg_frame(mid, hem, right); Ml[:3, 2] *= np.linalg.norm(hem - mid); M['cape_l'] = Ml
    if 'tabard_f' in P:
        fw = Rp @ Y
        th = [np.dot(nrm(w(f'{s}_knee') - w(f'{s}_hip')), fw) for s in 'RL']
        k = 0.45 if 'robe' in C['extras'] else 0.9           # a long robe swings less than a tabard
        M['tabard_f'] = frame(Rp @ rot(X, math.degrees(max(th)) * k + 4), w('pelvis') + fw * C['torso_d'] * Hh * 0.52)
        M['tabard_b'] = frame(Rp @ rot(X, math.degrees(min(th)) * k - 6), w('pelvis') - fw * C['torso_d'] * Hh * 0.52)
    for sd in 'RL':
        if f'robe_{sd}' in P:     # side panels follow the hip, splitting slightly with the stride
            sg = 1 if sd == 'R' else -1
            M[f'robe_{sd}'] = frame(Rp, w('pelvis') + Rp @ np.array([sg * C['pelvis_w'] * Hh * 0.55, 0, 0]))
        if f'pouch_{sd}' in P:
            sg = 1 if sd == 'R' else -1
            M[f'pouch_{sd}'] = frame(Rp, w('pelvis') + Rp @ np.array([sg * C['pelvis_w'] * Hh * 0.62, 0.02 * Hh, 0.0]))
    if 'sash' in P:
        M['sash'] = frame(Rp, w('pelvis') + (Rp @ Y) * C['torso_d'] * Hh * 0.56)
    if 'staff' in P:              # held upright in the right fist, swinging a little with the arm
        g = w('R_hand'); up = nrm(Rc @ rot(X, J.get('_AR', 0.0) * 0.5) @ np.array([0, 0.06, 1.0]))
        Ms = seg_frame(g, g + up, Rc @ X); Ms[:3, 3] = g; M['staff'] = Ms
        top = g + up * 0.55 * Hh
        fw = nrm((Rc @ Y) - up * np.dot(Rc @ Y, up))
        M['crook'] = frame(Rc, top + fw * 0.05 * Hh)
        M['lantern'] = frame(Rc, top + fw * 0.10 * Hh)
    if 'quiver' in P:      # on the back, over the left shoulder, tilted
        M['quiver'] = frame(Rc @ rot(Y, 28), w('chest') + Rc @ np.array([-0.05 * Hh, -C['torso_d'] * Hh * 0.75, 0.05 * Hh]))
    if 'bow' in P:         # held low in the right hand, upper limb back and up, lower limb forward and down
        up, fw = Rc @ Z, Rc @ Y
        M['bow'] = bow_frame(w('R_hand'), z=nrm(up - fw * 0.30), y=fw)
    for s in 'RL':
        if f'dagger_{s}' in P:   # blade out of the fist, forward and out, edge down
            Rh = Rf @ J[f'_R{s}_farm']
            out = 1 if s == 'R' else -1
            M[f'dagger_{s}'] = seg_frame(w(f'{s}_hand'), w(f'{s}_hand') + Rc @ nrm(np.array([out * 0.75, 0.45, -0.35])), Rc @ Z)
            M[f'guard_{s}'] = frame(Rh, w(f'{s}_hand'))
    if 'mace_handle' in P:      # handle forward and down out of the right fist, head low in front
        # body space: handle forward and down from the fist at hip height, swinging with the arm
        d = Rf @ J['_Rc'] @ rot(X, J['_AR'] * 0.8) @ nrm(np.array([-0.10, 0.85, -0.42]))
        g = w('R_hand'); Mh = seg_frame(g, g + d, Rc @ X); M['mace_handle'] = Mh
        M["mace_head"] = frame(Rc, g + d * 0.28 * Hh)
    if 'shield' in P:           # strapped flat on the OUTSIDE of the left forearm: face out, long axis up
        Rh = Rf @ J['_RL_farm']
        mid = w('L_elbow') * 0.3 + w('L_wrist') * 0.7          # over the fist, which grips the strap behind it
        M['shield'] = frame(Rh @ SHIELD_ON_FOREARM, mid + Rh @ np.array([-0.075 * Hh, 0.0, 0.0]))
    for k, o in P.items():
        o.matrix_world = mathutils.Matrix([list(r) for r in M[k]])
    return M

# shield axes in forearm space: width along the forearm, height up (forearm local +Y once the elbow is bent),
# face (shield local -Y) pointing outward (forearm local -X for the left arm), turned 20 deg toward the front
SHIELD_ON_FOREARM = np.array([[0.0, -1.0, 0.0], [0.0, 0.0, 1.0], [-1.0, 0.0, 0.0]]).T @ np.eye(3)
SHIELD_ON_FOREARM = np.column_stack([[0, 0, -1], [-1, 0, 0], [0, 1, 0]]).astype(float) @ rot(Z, 40)

def bow_frame(grip, z, y):
    """bow mesh frame: limbs along z, belly (+y) toward the target / forward, string (-y) toward the archer."""
    z = nrm(z); y = nrm(y - z * np.dot(y, z)); x = np.cross(y, z)
    M = np.eye(4); M[:3, 0], M[:3, 1], M[:3, 2], M[:3, 3] = x, y, z, grip; return M

def project(sc, p):
    v = world_to_camera_view(sc, sc.camera, mathutils.Vector(tuple(p)))
    return [round(v.x * W, 3), round((1 - v.y) * H_CELL, 3)], v.z

def joints_px(sc, J, facing):
    Rf = rot(Z, -90) if facing == 'S' else np.eye(3)
    keys = ['pelvis', 'chest', 'neck', 'head_top'] + [f'{s}_{k}' for s in 'RL' for k in ('shoulder', 'elbow', 'wrist', 'hip', 'knee', 'ankle', 'toe', 'heel')]
    out = {k: project(sc, Rf @ J[k])[0] for k in keys}
    return out

def render(sc, path, mode):
    sh = sc.display.shading
    if mode == 'clay':
        sh.light = 'STUDIO'; sh.color_type = 'SINGLE'; sh.single_color = (0.78, 0.78, 0.78)
        sh.show_cavity = True; sh.cavity_type = 'WORLD'; sh.show_object_outline = False
        sc.display.render_aa = '8'
    else:
        sh.light = 'FLAT'; sh.color_type = 'OBJECT'; sh.show_cavity = False; sc.display.render_aa = 'OFF'
    sc.view_settings.view_transform = 'Standard'
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)

def main():
    cls, out = sys.argv[-2], sys.argv[-1]
    C = dict(CLASSES[cls]); os.makedirs(out + '/clay', exist_ok=True); os.makedirs(out + '/id', exist_ok=True)
    P = build(C); sc = bpy.context.scene
    data = {'meta': dict(cell=[W, H_CELL], pivot=list(PIVOT), fps=17.144, frames=FRAMES,
                         camera=dict(type='orthographic', azimuth_deg=45.0, elevation_deg_below_horizontal=30.0, ortho_scale=ORTHO),
                         char=cls, label=C['label'], world_height_units=C['H'],
                         notes='Blockout walk guide (clay + part ID + joints) in the Ironjaw TA format. Joints are camera projections '
                               'in the 512x360 cell, pivot (256,329) is the ground under the pelvis. S walks down-right, E walks up-right; '
                               'W = mirror of S, N = mirror of E. draw_order is nearest-camera first (part-centre depth). '
                               'rotation_deg: 0 = straight down, positive = clockwise on screen. visible_length_scale = projected length / idle.'),
            'facings': {}}
    idle_len = {}
    seq = [('idle', True, [0])] + [('walk', False, list(range(FRAMES)))]
    for facing in ('S', 'E'):
        for anim, idle, frames in seq:
            key = f'{anim}_{facing}'; data['facings'][key] = {}
            for i in frames:
                # E contacts at f05/f11 like Ironjaw's E; S contacts at f00/f06
                t = (i / FRAMES) if facing == 'S' else ((i - 5) / FRAMES) % 1.0
                J = pose(C, t, idle)
                Mw = place(P, C, J, facing)
                tag = f'{cls}_{anim}_{facing}_f{i:02d}'
                render(sc, f'{out}/clay/{tag}.png', 'clay'); render(sc, f'{out}/id/{tag}.png', 'id')
                jp = joints_px(sc, J, facing)
                depth = {}; parts = {}
                for k, o in P.items():
                    c = o.matrix_world @ (sum((mathutils.Vector(v.co) for v in o.data.vertices), mathutils.Vector()) / len(o.data.vertices))
                    depth[k] = project(sc, c)[1]
                    a = o.matrix_world @ mathutils.Vector((0, 0, 0)); b = o.matrix_world @ mathutils.Vector((0, 0, 1 if k.startswith('cape') else 10))
                    pa, _ = project(sc, a); pb, _ = project(sc, b); dx, dy = pb[0] - pa[0], pb[1] - pa[1]
                    ln = math.hypot(dx, dy)
                    if idle: idle_len[(facing, k)] = ln
                    parts[k] = dict(rotation_deg=round(math.degrees(math.atan2(-dx, dy)), 2),
                                    visible_length_scale=round(ln / max(1e-6, idle_len.get((facing, k), ln)), 3))
                data['facings'][key][f'f{i:02d}'] = dict(joints=jp, draw_order=sorted(depth, key=lambda k: depth[k]), parts=parts)
    json.dump(data, open(f'{out}/joints_512.json', 'w'), indent=1)
    print('DONE', cls)

if __name__ == '__main__':
    main()
