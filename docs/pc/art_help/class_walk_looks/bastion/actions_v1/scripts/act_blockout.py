"""Bastion actions v1 - render the action blockout at the house cell (512x360, pivot (256,329), walk camera) for S and E:
clay, part ID and joints per action and frame. The poses are scripts/actions.py on claude/class-walk-blockouts (the ones in
bastion_actions.mp4); only the camera framing is the walk cell instead of the 1024x720 showcase.

Mode `aimfix` (default; `approved` renders actions.py exactly as in the mp4):
  * Attack and skill: in actions.py the arms hang in the torso frame, so the torso twist (cyaw -14 at the wind-up, +10/+12
    at the smash) turns the whole swing 10-14 deg off the facing. Here the shoulders still ride on the twisted torso, but the
    arm angles are applied in the facing frame (lean kept, no yaw): the twist is the torso's, the swing plane is the facing.
    The smash comes down in front of the right shoulder (abduction 25 -> 4 at impact) so the mace head lands on the facing
    line: S down-right, E up-right. The shield arm is the same, with no yaw.
  * The attack step-in goes forward-inward instead of straight forward, so the S sabaton stays inside the cell (step_in).
  * E death falls to his left (world -X), not straight back toward the camera (straight back leaves the cell). Same screen
    path as the approved S death.
Per frame the json holds the joints (joints_512.json schema) plus hand, head_c, cape_top/mid/hem, mace_grip / mace_head,
shield_c / shield_top / shield_bot / shield_in / shield_out and shield_face (camera-facing sign of the shield face), the
torso / pelvis basis, key, draw_order, depth and parts (rotation_deg, visible_length_scale vs f00 of the same action).
usage (bpy 4.2 module): python act_blockout.py OUT_DIR [approved|aimfix] [blockout_scripts_dir]"""
import sys, os, json, math, subprocess
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '../../../../../../..'))
BO_COMMIT = 'ca1a7c30b68ebffb8279a14b05b1005568f75757'     # claude/class-walk-blockouts head with the approved bastion_actions.mp4
out = sys.argv[1]
MODE = sys.argv[2] if len(sys.argv) > 2 else 'aimfix'
bsd = sys.argv[3] if len(sys.argv) > 3 else '/tmp/bastion_blockout_act/docs/pc/art_help/class_walk_blockouts/scripts'
if not os.path.exists(bsd + '/actions.py'):
    root = '/tmp/bastion_blockout_act'; os.makedirs(root, exist_ok=True)
    subprocess.run(f'git -C "{REPO}" archive {BO_COMMIT} docs/pc/art_help/class_walk_blockouts/scripts | tar -x -C "{root}"', shell=True, check=True)
sys.path.insert(0, bsd)
import bpy, mathutils
import blockout as B
import actions as A
from blockout import rot, nrm, X, Y, Z

ACTS = [('idle', 'idle', 12), ('attack', 'attack', 12), ('skill', 'cast', 12), ('hit', 'hit', 8), ('death', 'death', 13)]
SMASH_ABD = {6: 4.0, 8: 4.0}          # aimfix: R arm abduction at the impact keys (actions.py: 15, 12)

def keys_fix(kl):
    out = []
    for fi, k in kl:
        k = json.loads(json.dumps(k)); k['feet'] = {a: tuple(b) for a, b in k['feet'].items()}; k['arms'] = {a: tuple(b) for a, b in k['arms'].items()}
        if fi in SMASH_ABD: a_, _, e_ = k['arms']['R']; k['arms']['R'] = (a_, SMASH_ABD[fi], e_)
        out.append((fi, k))
    return out

STEP_K = 0.6          # aimfix: the attack step-in, forward part kept (x0.6) and the same amount inward (see step_in)

def step_in(C, st, J):
    """attack step: actions.py steps the R foot 0.11 H straight forward (0.06 -> 0.17 H). On S that is straight toward the
    camera: the sabaton leaves the cell bottom (toe joint at y 362, the painted boot ~10 px lower). Here the same step goes
    forward-inward, 0.6 x forward and 0.6 x toward the centre line (0.85 of the step length): on S that keeps the toe on
    its idle row (forward and the body's right both point down the screen), so the boot stays inside the cell."""
    Hh = C['H']; d = st['feet']['R'][0] - 0.06 * Hh
    if d <= 1e-6: return J
    off = np.array([-STEP_K * d, -(1 - STEP_K) * d, 0.0])
    for k in ('R_heel', 'R_toe', 'R_ankle'): J[k] = J[k] + off
    J['R_knee'] = B.ik(J['R_hip'], J['R_ankle'], C['thigh'] * Hh, C['shin'] * Hh, J['_Rp'] @ Y)
    return J

def arms_facing(C, st, J):
    """re-hang both arms: shoulder on the (twisted) torso, arm angles in the facing frame (lean only, no yaw)."""
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

def side_fall(C, st):
    Hh = C['H']; t = st['tilt']; J = A.pose_act(C, dict(st, tilt=0.0))
    if not t: return J
    Rt = rot(Y, -t); piv = np.array([-C['hip_w'] * Hh * 0.9, 0.0, 0.0])
    for kk in list(J):
        if kk.startswith('_R') or kk in ('_Rc', '_Rp'): J[kk] = Rt @ J[kk]
        elif not kk.startswith('_'): J[kk] = Rt @ (J[kk] - piv) + piv
    return J

def main():
    cls = 'bastion'; C = dict(B.CLASSES[cls]); P = B.build(C); sc = bpy.context.scene; Hh = C['H']
    for d in ('clay', 'id'): os.makedirs(f'{out}/{d}', exist_ok=True)
    data = {'meta': dict(cell=[B.W, B.H_CELL], pivot=list(B.PIVOT), fps=17.144, char=cls, world_height_units=Hh,
                         source=f'claude/class-walk-blockouts {BO_COMMIT[:8]} scripts/actions.py (poses), walk camera',
                         names={'skill': 'cast'}, mode=MODE), 'facings': {}}
    for name, anim, n in ACTS:
        kl = A.keys(cls, C, anim)
        if MODE == 'aimfix' and anim == 'attack': kl = keys_fix(kl)
        for F in 'SE':
            Rf = rot(Z, -90) if F == 'S' else np.eye(3); key = f'{name}_{F}'; data['facings'][key] = {}; len0 = {}
            for i in range(n):
                st = A.sample(kl, i); J = A.pose_act(C, st)
                if MODE == 'aimfix' and anim == 'death' and F == 'E': J = side_fall(C, st)
                if MODE == 'aimfix' and anim in ('attack', 'cast'): J = arms_facing(C, st, J)
                if MODE == 'aimfix' and anim == 'attack': J = step_in(C, st, J)
                J['_act'] = st; M = A.place(P, C, J, F)
                tag = f'{cls}_{name}_{F}_f{i:02d}'
                B.render(sc, f'{out}/clay/{tag}.png', 'clay'); B.render(sc, f'{out}/id/{tag}.png', 'id')
                jp = B.joints_px(sc, J, F); pr = lambda p: B.project(sc, p)
                for k in ('R_hand', 'L_hand', 'head_c', 'cape_top', 'cape_mid', 'cape_hem'): jp[k] = pr(Rf @ J[k])[0]
                Mh = M['mace_handle']; o = Mh[:3, 3]; dz = Mh[:3, 2]
                jp['mace_grip'] = pr(o)[0]; jp['mace_head'] = pr(M['mace_head'][:3, 3])[0]; jp['mace_butt'] = pr(o - dz * 0.06 * Hh)[0]
                Ms = M['shield']; c0 = Ms[:3, 3]; sx, sz, sy = Ms[:3, 0], Ms[:3, 2], Ms[:3, 1]; w_, h_ = 0.22 * Hh, 0.40 * Hh
                jp['shield_c'] = pr(c0)[0]; jp['shield_top'] = pr(c0 + sz * 0.42 * h_)[0]; jp['shield_bot'] = pr(c0 - sz * 0.58 * h_)[0]
                jp['shield_out'] = pr(c0 + sx * w_ / 2)[0]; jp['shield_in'] = pr(c0 - sx * w_ / 2)[0]
                _, zc = pr(c0); _, zf = pr(c0 - sy * 0.05 * Hh); jp['shield_face'] = round(float(zc - zf), 4)   # > 0: face toward the camera
                basis = {}
                for bn, Rm, org in (('torso', J['_Rc'], J['chest']), ('pelvis', J['_Rp'], J['pelvis'])):
                    Rw = Rf @ Rm; ow = Rf @ org; p0, z0 = pr(ow); basis[bn] = {'o': p0}
                    for an, ax in (('x', X), ('y', Y), ('z', Z)):
                        p1, z1 = pr(ow + Rw @ ax * 0.1 * Hh); basis[bn][an] = [round(p1[0] - p0[0], 3), round(p1[1] - p0[1], 3), round(z1 - z0, 4)]
                depth = {}; parts = {}
                for k, ob in P.items():
                    c = ob.matrix_world @ (sum((mathutils.Vector(v.co) for v in ob.data.vertices), mathutils.Vector()) / len(ob.data.vertices))
                    depth[k] = pr(c)[1]
                    a = ob.matrix_world @ mathutils.Vector((0, 0, 0)); b = ob.matrix_world @ mathutils.Vector((0, 0, 1 if k.startswith('cape') else 10))
                    pa, _ = pr(a); pb, _ = pr(b); dx, dy = pb[0] - pa[0], pb[1] - pa[1]; ln = math.hypot(dx, dy)
                    if i == 0: len0[k] = ln
                    parts[k] = dict(rotation_deg=round(math.degrees(math.atan2(-dx, dy)), 2), visible_length_scale=round(ln / max(1e-6, len0.get(k, ln)), 3))
                keyd = {k: (round(v, 3) if isinstance(v, float) else v) for k, v in st.items() if k in ('drop', 'fwd', 'lean', 'cyaw', 'tilt', 'wpn')}
                keyd['arms'] = {s: [round(x, 2) for x in st['arms'][s]] for s in 'RL'}
                data['facings'][key][f'f{i:02d}'] = dict(joints=jp, basis=basis, key=keyd,
                                                         draw_order=sorted(depth, key=lambda k: depth[k]),
                                                         depth={k: round(v, 3) for k, v in depth.items()}, parts=parts)
            print(key, n, flush=True)
    json.dump(data, open(f'{out}/joints_actions_512.json', 'w'), indent=1)
    print('DONE')

if __name__ == '__main__':
    main()
