"""Ironjaw actions v1 - action blockout (clay, part ID and joints) at the house cell (512x360, pivot (256,329), walk camera)
for S and E. claude/class-walk-blockouts (ca1a7c30) has NO Ironjaw class and no Ironjaw actions, so this file adds both on
top of its blockout.py / actions.py (extracted read-only with git archive; nothing is committed there):

  class    'ironjaw': the walk-guide mannequin with his proportions (big upper body, hip at 0.45 H, broad shoulders and
           limbs, helm, pauldrons, cape) and two axes, one per fist, haft forward-down out of the fist, blade vertical.
           The idle stance is his hold (fists at belt height, elbows out, axes forward and down) on his idle foot spread.
  poses    NOT APPROVED BY MAURO - built here for his kit (data/kits.gd: Advance, Strike, Shoulder, Crush):
             attack = Strike   heavy overhead chop with the right axe, left axe drawn back; Bastion's attack timing
                               (wind-up f04, impact f06, follow-through f08, back to idle f12) and step-in.
             skill  = Shoulder shoulder charge: coil back (f03), drive the left shoulder forward with a big step and a
                               low forward lean (f06), hold the impact (f08), recover (f12). Both axes kept close.
             hit               Bastion's hit timing with a 24 deg recoil, arms thrown out and a head snap back.
             death             knees go (f03), falls (f08), lies flat on his back (S) / on his side (E) with the
                               legs straight and the arms and axes on the ground (f11-f12): a real lying-down key.
           Advance (a 2-tile hop) and Crush (a heavier Strike) have no action slot of their own in the game's drop
           (ACTION_KINDS idle/attack/skill/hit/death), so they are not separate animations here.
  aimfix   (the Kestrel / Bastion lessons, applied from the start)
             * the arms ride on the twisted torso (shoulders), but the arm angles are in the facing frame (lean only, no
               yaw): torso twist is the torso's, the swing plane is the facing -> S chops down-right, E up-right;
             * the step goes forward-inward so the boots stay inside the cell (step_in);
             * E death falls to his left (world -X), never toward the camera; S falls straight back (away from it).
Per frame the json holds the joints (joints_512.json schema) plus hand, axe grip / head / pommel per side, head_c,
cape points, the torso / pelvis basis, the key, depth per joint and a draw order.
usage (bpy 4.2 module): python act_blockout.py OUT_DIR"""
import sys, os, json, math, subprocess
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '../../../../../../..'))
BO_COMMIT = 'ca1a7c30b68ebffb8279a14b05b1005568f75757'
out = sys.argv[1]
root = os.environ.get('IJ_BO_DIR', '/tmp/ironjaw_actions_v1_blockout')
bsd = f'{root}/docs/pc/art_help/class_walk_blockouts/scripts'
if not os.path.exists(bsd + '/actions.py'):
    os.makedirs(root, exist_ok=True)
    subprocess.run(f'git -C "{REPO}" archive {BO_COMMIT} docs/pc/art_help/class_walk_blockouts/scripts | tar -x -C "{root}"', shell=True, check=True)
sys.path.insert(0, bsd)
import bpy, mathutils
import blockout as B
import actions as A
from blockout import rot, nrm, X, Y, Z

# ---------------------------------------------------------------- the Ironjaw class (fractions of H)
IRONJAW = dict(B.BASE, H=305, label='Ironjaw (berserker)', hip=0.45, chest=0.63, shoulder=0.785, neck=0.83, head_c=0.885, head=0.09,
               hip_w=0.085, sh_w=0.175, thigh=0.19, shin=0.195, ankle=0.045, foot=0.15, uarm=0.17, farm=0.15, hand=0.06,
               lean=4.0, torso_w=0.36, torso_d=0.20, pelvis_w=0.27, foot_w=1.25,
               arm_swing=(12, 12), elbow=(40, 40), abduct=(20, 20), arm_A0=(8.0, 8.0),
               limb_w=dict(thigh=0.12, shin=0.10, boot=0.105, uarm=0.11, farm=0.095, hand=0.075),
               extras=['helm', 'pauldrons', 'cape'])
AXE = dict(haft=0.30, head_at=0.25, pommel=0.07)        # haft length, head centre along it, pommel behind the fist (x H)
AXE_DIR = nrm(np.array([0.0, 0.80, -0.60]))           # in the forearm frame: forward and down out of the fist

def stance(C):
    Hh = C['H']; a0 = C['arm_A0']
    return dict(drop=0.0, fwd=0.0, lean=0.0, cyaw=0.0, tilt=0.0, sway=0.0, head=0.0, roll=0.0,
                feet={'R': (0.06 * Hh, 0.0, 0.0), 'L': (-0.05 * Hh, 0.0, 0.0)},
                arms={'R': (a0[0], C['abduct'][0], C['elbow'][0]), 'L': (a0[1], C['abduct'][1], C['elbow'][1])}, wpn=0.0)

def keys(C, anim, F='S'):
    Hh = C['H']; s0 = stance(C); a0 = s0['arms']
    def k(**kw):
        d = json.loads(json.dumps(s0)); d['feet'] = {a: tuple(b) for a, b in d['feet'].items()}; d['arms'] = {a: tuple(b) for a, b in d['arms'].items()}
        for a, b in kw.items():
            if a in ('feet', 'arms'): d[a].update(b)
            else: d[a] = b
        return d
    def arm(sd, dA=0.0, dabd=0.0, del_=0.0): return (a0[sd][0] + dA, a0[sd][1] + dabd, a0[sd][2] + del_)
    if anim == 'idle':       # heavy breathing: chest rises, shoulders settle, axes sink a little
        return [(0, k()), (6, k(drop=0.008 * Hh, lean=2.0, head=-1.5, arms={'R': arm('R', 3, 2, 5), 'L': arm('L', 3, 2, 5)})), (12, k())]
    if anim == 'attack':     # Strike: overhead chop with the right axe, left axe drawn back, step in
        return [(0, k()),
                (4, k(drop=0.01 * Hh, lean=-8, cyaw=-14, head=-4, arms={'R': (150, 18, 55), 'L': (-25, 30, 55)})),
                (6, k(drop=0.04 * Hh, fwd=0.05 * Hh, lean=14, cyaw=10, head=4, arms={'R': (70, 4, 12), 'L': (-15, 25, 45)}, feet={'R': (0.17 * Hh, 0.0, 0.0)})),
                (8, k(drop=0.05 * Hh, fwd=0.06 * Hh, lean=18, cyaw=12, head=5, arms={'R': (28, 4, 16), 'L': (-10, 25, 45)}, feet={'R': (0.17 * Hh, 0.0, 0.0)})),
                (12, k())]
    if anim == 'cast':       # Shoulder: coil, drive the left shoulder forward low with a big step, hold the hit, recover
        tuck = {'R': (-30, 22, 55), 'L': (35, 12, 105)}
        return [(0, k()),
                (3, k(drop=0.04 * Hh, fwd=-0.02 * Hh, lean=8, cyaw=14, head=-3, arms={'R': (-15, 22, 50), 'L': (20, 15, 90)})),
                (6, k(drop=0.06 * Hh, fwd=0.11 * Hh, lean=24, cyaw=-34, head=6, arms=tuck, feet={'L': (0.16 * Hh, 0.0, 0.0)})),
                (8, k(drop=0.06 * Hh, fwd=0.12 * Hh, lean=26, cyaw=-36, head=7, arms=tuck, feet={'L': (0.16 * Hh, 0.0, 0.0)})),
                (12, k())]
    if anim == 'hit':        # recoil back 24 deg, arms thrown out, head snaps back, recover
        return [(0, k()),
                (2, k(drop=0.03 * Hh, fwd=-0.035 * Hh, lean=-24, cyaw=8, head=-16, arms={'R': (-25, 45, 20), 'L': (-20, 45, 25)})),
                (3, k(drop=0.03 * Hh, fwd=-0.033 * Hh, lean=-22, cyaw=7, head=-10, arms={'R': (-22, 43, 22), 'L': (-18, 43, 27)})),
                (5, k(drop=0.02 * Hh, fwd=-0.015 * Hh, lean=-8, head=-3, arms={'R': (-8, 28, 30), 'L': (-6, 28, 32)})),
                (8, k())]
    if anim == 'death':      # knees go, falls back (S) / to his left (E), lies flat: the lying-down key is f11-f12
        out_ = lambda a, b, c: {'R': (a, b, c), 'L': (a, b, c)}
        # lying arms lie ON the ground plane: S lies on his back (ground = his side-to-side x head-to-foot plane, so the arms
        # spread sideways); E lies on his left side (ground = his front-to-back x head-to-foot plane, arms forward)
        lie = out_(5, 18, 22) if F == 'S' else {'R': (12, 14, 20), 'L': (22, 6, 15)}
        mid = out_(-25, 30, 25) if F == 'S' else {'R': (5, 30, 25), 'L': (20, 22, 15)}
        return [(0, k()),
                (3, k(drop=0.08 * Hh, lean=-12, head=-10, arms=out_(-25, 32, 30))),
                (8, k(drop=0.20 * Hh, tilt=62, lean=-10, head=-6, arms=mid, feet={'R': (0.14 * Hh, 0.0, 30.0)})),
                (11, k(drop=0.24 * Hh, tilt=88, lean=0, head=0, roll=25, arms=lie, feet={'R': (0.10 * Hh, 0.0, 0.0)})),
                (12, k(drop=0.24 * Hh, tilt=90, lean=0, head=0, roll=30, arms=lie, feet={'R': (0.10 * Hh, 0.0, 0.0)}))]
    raise KeyError(anim)

def sample(kl, i):
    for (a, ka), (b, kb) in zip(kl, kl[1:]):
        if a <= i <= b: return A.lerp(ka, kb, B.smooth((i - a) / max(1, b - a)))
    return kl[-1][1]

# ---------------------------------------------------------------- pose
def arms_facing(C, st, J):
    """arm angles in the facing frame (lean only, no yaw); shoulders on the twisted torso."""
    Hh = C['H']; f = lambda k: C[k] * Hh
    R0 = rot(X, -(C['lean'] + st['lean']))
    for side, sg in (('R', 1), ('L', -1)):
        Aa, abd, el = st['arms'][side]; sh = J[f'{side}_shoulder']
        Ru = R0 @ rot(Y, sg * -abd) @ rot(X, Aa)
        elb = sh + Ru @ np.array([0, 0, -f('uarm')]); Rf2 = Ru @ rot(X, el)
        wr = elb + Rf2 @ np.array([0, 0, -f('farm')])
        J[f'{side}_elbow'], J[f'{side}_wrist'], J[f'{side}_hand'] = elb, wr, wr + Rf2 @ np.array([0, 0, -f('hand') * 0.5])
        J[f'_R{side}_farm'] = Rf2; J[f'_A{side}'] = Aa
    return J

def step_in(C, st, J, side, rest_fy):
    """a step forward goes forward-inward (0.6 x forward, 0.6 x toward the centre line), so the boot stays in the cell."""
    Hh = C['H']; d = st['feet'][side][0] - rest_fy
    if d <= 1e-6: return J
    sg = 1 if side == 'R' else -1
    off = np.array([-sg * 0.6 * d, -(1 - 0.6) * d, 0.0])
    for k in ('heel', 'toe', 'ankle'): J[f'{side}_{k}'] = J[f'{side}_{k}'] + off
    J[f'{side}_knee'] = B.ik(J[f'{side}_hip'], J[f'{side}_ankle'], C['thigh'] * Hh, C['shin'] * Hh, J['_Rp'] @ Y)
    return J

def head_turn(C, J, st):
    """head snap / nod (pitch about the torso X axis, + = forward) and roll (death: the head lolls to the side)."""
    p, r = st.get('head', 0.0), st.get('roll', 0.0)
    if not p and not r: return J
    Rh = J['_Rc'] @ rot(Y, r) @ rot(X, -p) @ J['_Rc'].T
    for k in ('head_c', 'head_top'): J[k] = J['neck'] + Rh @ (J[k] - J['neck'])
    J['_Rh'] = Rh @ J['_Rc']
    return J

def axes(C, J):
    Hh = C['H']
    for s in 'RL':
        d = J[f'_R{s}_farm'] @ AXE_DIR; g = J[f'{s}_hand']
        J[f'{s}_axe_grip'] = g; J[f'{s}_axe_head'] = g + d * AXE['head_at'] * Hh; J[f'{s}_axe_pommel'] = g - d * AXE['pommel'] * Hh
        J[f'_axe_{s}'] = d
    return J

def fall(C, st, J, F):
    """tilt: S falls straight back about the heels (away from the camera); E falls to his left (world -X), not toward the
    camera. The whole pose (axes included) turns rigidly about the pivot."""
    t = st['tilt']
    if not t: return J
    Hh = C['H']
    if F == 'S': Rt = rot(X, t); piv = np.array([0, -0.06 * Hh, 0])
    else: Rt = rot(Y, -t); piv = np.array([-C['hip_w'] * Hh * 0.9, 0.0, 0.0])
    for kk in list(J):
        if kk.startswith('_R') or kk.startswith('_axe'): J[kk] = Rt @ J[kk]
        elif not kk.startswith('_'): J[kk] = Rt @ (J[kk] - piv) + piv
    # a falling body never sinks through the ground: the trunk, head and knees stay at least their half thickness above it
    w = B.smooth(min(1.0, t / 90.0)); lo = {'pelvis': 0.09, 'chest': 0.10, 'neck': 0.09, 'head_c': 0.07, 'R_shoulder': 0.07, 'L_shoulder': 0.07,
                                          'R_hip': 0.07, 'L_hip': 0.07, 'R_knee': 0.05, 'L_knee': 0.05}
    need = max(0.0, max(lo[k] * Hh - J[k][2] for k in lo))
    if need > 0:
        for kk in list(J):
            if not kk.startswith('_') and not kk.endswith(('heel', 'toe', 'ankle')): J[kk] = J[kk] + np.array([0, 0, need])
        for s in 'RL':      # the feet stay on the ground: knees re-solved to the raised hips
            J[f'{s}_knee'] = B.ik(J[f'{s}_hip'], J[f'{s}_ankle'], C['thigh'] * Hh, C['shin'] * Hh, J['_Rp'] @ Z)
    J['_fall_lift'] = need
    return J

def pose(C, st, F, rest):
    s2 = dict(st, tilt=0.0); J = A.pose_act(C, s2)
    J = arms_facing(C, s2, J)
    for sd in 'RL': J = step_in(C, s2, J, sd, rest['feet'][sd][0])
    J = head_turn(C, J, s2); J = axes(C, J); J['_Rh'] = J.get('_Rh', J['_Rc'])
    J = fall(C, st, J, F)
    return J

# ---------------------------------------------------------------- scene
def build(C):
    P = B.build(C); coll = bpy.context.scene.collection; Hh = C['H']
    for s in 'RL':
        col = B.IDC['weapon_R' if s == 'R' else 'weapon_L']
        P[f'axe_haft_{s}'] = B.mk_box(f'axe_haft_{s}', 0.024 * Hh, 0.024 * Hh, -AXE['pommel'] * Hh, AXE['haft'] * Hh, col, coll)
        # double-bit head: a flat crescent-ish plate (x = across the haft, z = along it), blade plane vertical
        w, h, d = 0.17 * Hh, 0.11 * Hh, 0.012 * Hh
        o2 = [(-w / 2, -h / 2), (-w * 0.18, -h * 0.22), (w * 0.18, -h * 0.22), (w / 2, -h / 2), (w * 0.42, 0), (w / 2, h / 2), (w * 0.18, h * 0.22),
              (-w * 0.18, h * 0.22), (-w / 2, h / 2), (-w * 0.42, 0)]
        v = [(x, -d / 2, z) for x, z in o2] + [(x, d / 2, z) for x, z in o2]; n = len(o2)
        Fc = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))] + [(k, (k + 1) % n, n + (k + 1) % n, n + k) for k in range(n)]
        P[f'axe_head_{s}'] = B.mk_mesh(f'axe_head_{s}', v, Fc, col, coll)
    return P

def place(P, C, J, F):
    M = B.place({k: v for k, v in P.items() if not k.startswith('axe')}, C, J, F)
    Rf = rot(Z, -90) if F == 'S' else np.eye(3); w = lambda k: Rf @ J[k]; Hh = C['H']
    M['head'] = B.frame(Rf @ J['_Rh'], w('head_c'))
    for k in ('helm', 'helm_crest'):
        if k in P: M[k] = B.frame(Rf @ J['_Rh'], w('head_c'))
    for s in 'RL':
        g = w(f'{s}_axe_grip'); d = Rf @ J[f'_axe_{s}']; up = Rf @ (J['_Rc'] @ Z)
        side = nrm(np.cross(d, up)) if np.linalg.norm(np.cross(d, up)) > 1e-3 else Rf @ X
        Mh = B.seg_frame(g, g + d, side); M[f'axe_haft_{s}'] = Mh
        Mx = B.seg_frame(w(f'{s}_axe_head'), w(f'{s}_axe_head') + d, side)
        # blade plane = haft axis x the 'up' of the hold (vertical when hanging)
        Mx2 = np.eye(4); Mx2[:3, 0] = nrm(np.cross(Mx[:3, 2], side)); Mx2[:3, 1] = side; Mx2[:3, 2] = Mx[:3, 2]; Mx2[:3, 3] = Mx[:3, 3]
        M[f'axe_head_{s}'] = Mx2
    for k, o in P.items():
        if k in M: o.matrix_world = mathutils.Matrix([list(r) for r in M[k]])
    return M

ACTS = [('idle', 'idle', 12), ('attack', 'attack', 12), ('skill', 'cast', 12), ('hit', 'hit', 8), ('death', 'death', 13)]
PTS = ['pelvis', 'chest', 'neck', 'head_c', 'head_top'] + [f'{s}_{k}' for s in 'RL' for k in
       ('shoulder', 'elbow', 'wrist', 'hand', 'axe_grip', 'axe_head', 'axe_pommel', 'hip', 'knee', 'ankle', 'toe', 'heel')] + ['cape_top', 'cape_mid', 'cape_hem']

def main():
    C = dict(IRONJAW); P = build(C); sc = bpy.context.scene
    for d in ('clay', 'id'): os.makedirs(f'{out}/{d}', exist_ok=True)
    data = {'meta': dict(cell=[B.W, B.H_CELL], pivot=list(B.PIVOT), fps=17.144, char='ironjaw', world_height_units=C['H'],
                         source=f'own Ironjaw class + poses on claude/class-walk-blockouts {BO_COMMIT[:8]} blockout.py / actions.py, walk camera',
                         approved=False, names={'skill': 'cast'}, mode='aimfix', cls={k: v for k, v in C.items() if not callable(v)}), 'facings': {}}
    rest = stance(C)
    for name, anim, n in ACTS:
        for F in 'SE':
            kl = keys(C, anim, F)
            Rf = rot(Z, -90) if F == 'S' else np.eye(3); key = f'{name}_{F}'; data['facings'][key] = {}
            for i in range(n):
                st = sample(kl, i); J = pose(C, st, F, rest); M = place(P, C, J, F)
                tag = f'ironjaw_{name}_{F}_f{i:02d}'
                B.render(sc, f'{out}/clay/{tag}.png', 'clay'); B.render(sc, f'{out}/id/{tag}.png', 'id')
                jp, dp = {}, {}
                for k in PTS:
                    p, z = B.project(sc, Rf @ J[k]); jp[k] = p; dp[k] = round(float(z), 5)
                basis = {}
                for bn, Rm, org in (('torso', J['_Rc'], J['chest']), ('pelvis', J['_Rp'], J['pelvis']), ('head', J['_Rh'], J['head_c'])):
                    Rw = Rf @ Rm; ow = Rf @ org; p0, z0 = B.project(sc, ow); basis[bn] = {'o': p0}
                    for an, ax in (('x', X), ('y', Y), ('z', Z)):
                        p1, z1 = B.project(sc, ow + Rw @ ax * 0.1 * C['H']); basis[bn][an] = [round(p1[0] - p0[0], 3), round(p1[1] - p0[1], 3), round(z1 - z0, 4)]
                depth = {}
                for k, ob in P.items():
                    c = ob.matrix_world @ (sum((mathutils.Vector(v.co) for v in ob.data.vertices), mathutils.Vector()) / len(ob.data.vertices))
                    depth[k] = round(B.project(sc, c)[1], 5)
                keyd = {k: (round(v, 3) if isinstance(v, float) else v) for k, v in st.items() if k in ('drop', 'fwd', 'lean', 'cyaw', 'tilt', 'head', 'roll')}
                keyd['arms'] = {s: [round(x, 2) for x in st['arms'][s]] for s in 'RL'}
                keyd['feet'] = {s: [round(x, 3) for x in st['feet'][s]] for s in 'RL'}
                data['facings'][key][f'f{i:02d}'] = dict(joints=jp, depth_pts=dp, basis=basis, key=keyd, depth=depth,
                                                         draw_order=sorted(depth, key=lambda k: -depth[k]))
            print(key, n, flush=True)
    json.dump(data, open(f'{out}/joints_actions_512.json', 'w'), indent=1)
    print('DONE')

if __name__ == '__main__':
    main()
