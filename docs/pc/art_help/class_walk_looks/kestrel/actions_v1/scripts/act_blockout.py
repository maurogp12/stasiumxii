"""Kestrel actions v1 - render the action blockout at the house cell (512x360, pivot (256,329), walk camera) for S and E:
clay, part ID and joints per action and frame. The poses are scripts/actions.py on claude/class-walk-blockouts (the ones in
kestrel_actions.mp4), unchanged; only the camera framing is the walk cell instead of the 1024x720 showcase.

Per frame the json holds the blockout joints (same schema as joints_512.json) plus what the painted rig needs:
  joints   + hand, head_c, cape_top / cape_mid / cape_hem, bow_grip / bow_top / bow_bot / string_top / string_bot,
           arrow_nock / arrow_tip (drawn frames only)
  basis    screen vectors (px per 0.1 H) and camera depth of the torso (Rc), pelvis (Rp) and head axes x (right), y (fwd), z (up)
  key      the sampled action key (drop, fwd, lean, cyaw, tilt, wpn)
  draw_order, depth (nearest first), parts (rotation_deg, visible_length_scale vs the f00 of the same action)
Mode `aimfix` (default; `approved` renders actions.py exactly as in the mp4): the attack and the skill are re-solved so the
shot follows Mauro's rule (S aims down-right, E aims up-right, the head faces the aim). actions.py turns the torso by
cyaw -40 and points the bow arm with it, so its arrow flies 40 deg right of the facing (S: straight down the screen, E: flat
right). Here the torso stays square to the facing (the painted torso cannot yaw anyway), the arrow line runs from the
draw-side cheek along the facing (skill: 35 deg up, Mark Shot aims high), the bow hand sits on that line 0.27 H out and the
draw hand on the nock; both arms are 2-bone IK onto those points with the arm lengths of the blockout. Timing (raise, full
draw, hold, loose, recover), lean, drop and the feet are the blockout's. The bow turns from hanging (limbs down, the walk
rule) to aimed (limbs across the aim, belly toward it, string toward her) while the arm raises.
Also in `aimfix`: the E death falls to her left instead of straight back (see side_fall; S death is unchanged).
usage (bpy 4.2 module): python act_blockout.py OUT_DIR [approved|aimfix] [blockout_scripts_dir]"""
import sys, os, json, math, subprocess
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '../../../../../../..'))
BO_COMMIT = 'ca1a7c30b68ebffb8279a14b05b1005568f75757'     # claude/class-walk-blockouts head with the approved kestrel_actions.mp4
out = sys.argv[1]
MODE = sys.argv[2] if len(sys.argv) > 2 else 'aimfix'
bsd = sys.argv[3] if len(sys.argv) > 3 else '/tmp/kestrel_blockout_act/docs/pc/art_help/class_walk_blockouts/scripts'
if not os.path.exists(bsd + '/actions.py'):
    root = '/tmp/kestrel_blockout_act'; os.makedirs(root, exist_ok=True)
    subprocess.run(f'git -C "{REPO}" archive {BO_COMMIT} docs/pc/art_help/class_walk_blockouts/scripts | tar -x -C "{root}"', shell=True, check=True)
sys.path.insert(0, bsd)
import bpy, mathutils
import blockout as B
import actions as A
from blockout import rot, nrm, X, Y, Z

ACTS = [('idle', 'idle', 12), ('attack', 'attack', 12), ('skill', 'cast', 12), ('hit', 'hit', 8), ('death', 'death', 13)]

# archery keys for the aim fix: (frame, raise r, draw d); d < 0 = loosed (string back at brace, the hand flies back)
ARCH = {'attack': dict(pitch=0.0, keys=[(0, 0, 0), (3, 1.0, 0.3), (6, 1.0, 1.0), (8, 1.0, 1.0), (9, 1.0, -1.0), (12, 0, -1.0)]),
        'cast': dict(pitch=35.0, keys=[(0, 0, 0), (4, 1.0, 1.0), (9, 1.0, 1.0), (10, 1.0, -1.0), (12, 0, -1.0)])}
DRAW = 0.27            # bow hand -> anchor at full draw, x H
BRACE = 0.06           # string -> grip at rest, x H

def arch_sample(kl, i):
    for (a, ra, da), (b, rb, db) in zip(kl, kl[1:]):
        if a <= i <= b:
            t = B.smooth((i - a) / max(1, b - a))
            if db < 0 <= da or (da < 0 and db < 0): return ra + (rb - ra) * t, (db if i > a else da)
            return ra + (rb - ra) * t, da + (db - da) * t
    return kl[-1][1], kl[-1][2]

def ik_pt(a, b, l1, l2, hint):
    d = b - a; L = np.linalg.norm(d)
    if L > (l1 + l2) * 0.999: b = a + d / L * (l1 + l2) * 0.999; d = b - a; L = np.linalg.norm(d)
    return B.ik(a, b, l1, l2, hint), b

def aim_fix(C, anim, i, st, J0):
    """re-solve both arms (see the module doc); returns J and the archery state."""
    Hh = C['H']; f = lambda k: C[k] * Hh; cfg = ARCH[anim]
    r, d = arch_sample(cfg['keys'], i)
    st = dict(st); st['cyaw'] = 0.0; st['arms'] = dict(st['arms'])
    rest = A.stance(C); st['arms'] = rest['arms']
    J = A.pose_act(C, st); Rc = J['_Rc']
    p = math.radians(cfg['pitch'])
    aim = nrm(np.array([0.0, math.cos(p), math.sin(p)]))
    anchor = J['head_c'] + Rc @ np.array([-0.030 * Hh, 0.035 * Hh, -0.050 * Hh])     # draw-side (left) cheek / jaw
    grip = anchor + aim * DRAW * Hh
    if d >= 0: nock = grip - aim * (BRACE + (DRAW - BRACE) * d) * Hh
    else: nock = grip - aim * BRACE * Hh
    hand_L = nock if d >= 0 else anchor - aim * 0.04 * Hh + Rc @ np.array([-0.05 * Hh, -0.02 * Hh, 0.02 * Hh])   # loosed: flies back and out
    tR = J['R_hand'] * (1 - r) + grip * r; tL = J['L_hand'] * (1 - r) + hand_L * r
    for side, tgt, hint in (('R', tR, Rc @ np.array([0.6, -0.2, -1.0])), ('L', tL, Rc @ np.array([-1.0, -0.6, 0.15]))):
        sh = J[f'{side}_shoulder']; l2 = f('farm') + 0.5 * f('hand')
        # bend toward the rest elbow while the arm is down (so f00 is exactly the idle pose), the archery bend when raised
        h0 = nrm(J[f'{side}_elbow'] - (sh + J[f'{side}_hand']) / 2); hint = nrm(h0 * (1 - r) + nrm(hint) * r)
        el, hd = ik_pt(sh, tgt, f('uarm'), l2, hint)
        J[f'{side}_elbow'] = el; J[f'{side}_hand'] = hd; J[f'{side}_wrist'] = el + nrm(hd - el) * f('farm')
        z = nrm(J[f'{side}_wrist'] - el); x = nrm(np.cross(Rc @ Y, z)); y = np.cross(z, x)
        J[f'_R{side}_farm'] = np.column_stack([x, y, -z])
    if r > 0:     # the grip is where the bow hand is (the line may be cut short when the arm cannot reach)
        grip = J['R_hand']
        if d >= 0: nock = grip - aim * (BRACE + (DRAW - BRACE) * d) * Hh
        else: nock = grip - aim * BRACE * Hh
    return J, dict(r=float(r), d=float(d), aim=aim, grip=grip, nock=nock, anchor=anchor, loosed=bool(d < 0))

def side_fall(C, st):
    """E death: the same keys, but the fall goes to her left (world -X) instead of straight back (world -Y). Straight back
    lands toward the camera, below the pivot row: in the walk camera the head ends at y 376 and the bow at y 510, outside
    the 360 px cell. To her left lands up-left on screen, the same screen path as the approved S death (S falls back = -X)."""
    Hh = C['H']; t = st['tilt']; J = A.pose_act(C, dict(st, tilt=0.0))
    if not t: return J
    Rt = rot(Y, -t); piv = np.array([-C['hip_w'] * Hh * 0.9, 0.0, 0.0])
    for kk in list(J):
        if kk.startswith('_R') or kk in ('_Rc', '_Rp'): J[kk] = Rt @ J[kk]
        elif not kk.startswith('_'): J[kk] = Rt @ (J[kk] - piv) + piv
    return J

def bow_M(C, J, F, arch):
    """hanging (walk rule) -> aimed, slerped by the raise r. Body space -> world via the facing."""
    Rf = rot(Z, -90) if F == 'S' else np.eye(3); Rc = Rf @ J['_Rc']
    up, fw = Rc @ Z, Rc @ Y
    Mh = B.bow_frame(Rf @ J['R_hand'], z=nrm(up - fw * 0.30), y=fw)
    if not arch or arch['r'] <= 0: return Mh
    aim = Rf @ arch['aim']; upw = Rf @ Z
    Ma = B.bow_frame(Rf @ J['R_hand'], z=nrm(upw - aim * np.dot(upw, aim)), y=aim)
    qa = mathutils.Matrix([list(r_) for r_ in Mh[:3, :3]]).to_quaternion(); qb = mathutils.Matrix([list(r_) for r_ in Ma[:3, :3]]).to_quaternion()
    q = qa.slerp(qb, B.smooth(min(1.0, arch['r']))); M = np.eye(4); M[:3, :3] = np.array(q.to_matrix()); M[:3, 3] = Rf @ J['R_hand']
    return M

def main():
    cls = 'kestrel'; C = dict(B.CLASSES[cls]); P = B.build(C); sc = bpy.context.scene; Hh = C['H']
    if MODE == 'aimfix':      # the nocked arrow (blockout only had it implied)
        P['arrow'] = B.mk_box('arrow', 0.008 * Hh, 0.008 * Hh, 0, 1, B.IDC['weapon_L'], sc.collection); P['arrow'].hide_render = True
    for d in ('clay', 'id'): os.makedirs(f'{out}/{d}', exist_ok=True)
    data = {'meta': dict(cell=[B.W, B.H_CELL], pivot=list(B.PIVOT), fps=17.144, char=cls, world_height_units=Hh,
                         source=f'claude/class-walk-blockouts {BO_COMMIT[:8]} scripts/actions.py (poses), walk camera',
                         names={'skill': 'cast'}, mode=MODE), 'facings': {}}
    for name, anim, n in ACTS:
        kl = A.keys(cls, C, anim)
        for F in 'SE':
            Rf = rot(Z, -90) if F == 'S' else np.eye(3); key = f'{name}_{F}'; data['facings'][key] = {}; len0 = {}
            for i in range(n):
                st = A.sample(kl, i); J = A.pose_act(C, st); arch = None
                if MODE == 'aimfix' and anim == 'death' and F == 'E': J = side_fall(C, st)
                if MODE == 'aimfix' and anim in ARCH: J, arch = aim_fix(C, anim, i, st, J); st = dict(st, cyaw=0.0, wpn=1.0 if arch['r'] > 0 else 0.0)
                st_place = dict(st, wpn=0.0)
                J['_act'] = st_place; M = A.place({k: v for k, v in P.items() if k != 'arrow'}, C, J, F)
                Mb_ = bow_M(C, J, F, arch); P['bow'].matrix_world = mathutils.Matrix([list(r_) for r_ in Mb_]); M['bow'] = Mb_
                if 'arrow' in P:
                    if arch and arch['r'] > 0.5 and not arch['loosed']:
                        nk = Rf @ arch['nock']; am = Rf @ arch['aim']
                        Ma_ = B.seg_frame(nk, nk + am, Rf @ Z); Ma_[:3, 2] *= 0.36 * Hh; P['arrow'].matrix_world = mathutils.Matrix([list(r_) for r_ in Ma_])
                        P['arrow'].hide_render = False
                    else: P['arrow'].hide_render = True
                tag = f'kestrel_{name}_{F}_f{i:02d}'
                B.render(sc, f'{out}/clay/{tag}.png', 'clay'); B.render(sc, f'{out}/id/{tag}.png', 'id')
                jp = B.joints_px(sc, J, F)
                pr = lambda p: B.project(sc, p)
                for k in ('R_hand', 'L_hand', 'head_c', 'cape_top', 'cape_mid', 'cape_hem'): jp[k] = pr(Rf @ J[k])[0]
                Mb = M['bow']; o = Mb[:3, 3]; bz, by = Mb[:3, 2], Mb[:3, 1]; L = 0.62 * Hh
                jp['bow_grip'] = pr(o)[0]; jp['bow_top'] = pr(o + bz * L / 2)[0]; jp['bow_bot'] = pr(o - bz * L / 2)[0]
                jp['bow_belly'] = pr(o + by * 0.06 * Hh)[0]
                jp['string_top'] = pr(o + bz * L / 2 - by * 0.05 * Hh)[0]; jp['string_bot'] = pr(o - bz * L / 2 - by * 0.05 * Hh)[0]
                drawn = bool(arch and arch['r'] > 0.5 and not arch['loosed']) if MODE == 'aimfix' else st['wpn'] > 0.5
                if arch:
                    aim = Rf @ arch['aim']; nock = Rf @ arch['nock']
                    jp['nock'] = pr(nock)[0]; jp['aim'] = pr(o + aim * 0.3 * Hh)[0]; jp['anchor'] = pr(Rf @ arch['anchor'])[0]
                    if drawn: jp['arrow_nock'] = pr(nock)[0]; jp['arrow_tip'] = pr(nock + aim * 0.36 * Hh)[0]
                elif drawn:
                    aim = nrm(Rf @ (J['R_wrist'] - J['R_elbow'])); nock = Rf @ J['L_hand']
                    jp['arrow_nock'] = pr(nock)[0]; jp['arrow_tip'] = pr(nock + aim * 0.36 * Hh)[0]
                    jp['aim'] = pr(o + aim * 0.3 * Hh)[0]
                basis = {}
                for bn, Rm, org in (('torso', J['_Rc'], J['chest']), ('pelvis', J['_Rp'], J['pelvis']), ('head', J['_Rc'], J['head_c'])):
                    Rw = Rf @ Rm; ow = Rf @ org; p0, z0 = pr(ow); basis[bn] = {'o': p0}
                    for an, ax in (('x', X), ('y', Y), ('z', Z)):
                        p1, z1 = pr(ow + Rw @ ax * 0.1 * Hh); basis[bn][an] = [round(p1[0] - p0[0], 3), round(p1[1] - p0[1], 3), round(z1 - z0, 4)]
                depth = {}; parts = {}
                for k, ob in P.items():
                    if ob.hide_render: continue
                    c = ob.matrix_world @ (sum((mathutils.Vector(v.co) for v in ob.data.vertices), mathutils.Vector()) / len(ob.data.vertices))
                    depth[k] = pr(c)[1]
                    a = ob.matrix_world @ mathutils.Vector((0, 0, 0)); b = ob.matrix_world @ mathutils.Vector((0, 0, 1 if k.startswith('cape') else 10))
                    pa, _ = pr(a); pb, _ = pr(b); dx, dy = pb[0] - pa[0], pb[1] - pa[1]; ln = math.hypot(dx, dy)
                    if i == 0: len0[k] = ln
                    parts[k] = dict(rotation_deg=round(math.degrees(math.atan2(-dx, dy)), 2), visible_length_scale=round(ln / max(1e-6, len0.get(k, ln)), 3))
                keyd = {k: (round(v, 3) if isinstance(v, float) else v) for k, v in st.items() if k in ('drop', 'fwd', 'lean', 'cyaw', 'tilt', 'wpn')}
                if arch: keyd.update(raise_=round(arch['r'], 3), draw=round(arch['d'], 3), loosed=arch['loosed'])
                data['facings'][key][f'f{i:02d}'] = dict(joints=jp, basis=basis, key=keyd, drawn=bool(drawn),
                                                         draw_order=sorted(depth, key=lambda k: depth[k]),
                                                         depth={k: round(v, 3) for k, v in depth.items()}, parts=parts)
            print(key, n, flush=True)
    json.dump(data, open(f'{out}/joints_actions_512.json', 'w'), indent=1)
    print('DONE')

if __name__ == '__main__':
    main()
