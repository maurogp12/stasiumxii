"""Action poses (idle, attack, hit, death) and a showcase render for the class blockouts.
usage: python actions.py <class> <outdir>   -> <outdir>/show/<anim>_<F>_fNN.png (1024x720, design colours) + turntable"""
import sys, os, math, json
import numpy as np
import bpy, mathutils
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blockout as B
from blockout import rot, nrm, X, Y, Z, ik, smooth

# design colours per class (from Mauro's concepts), by part-name prefix
LOOK = {
 'mender': dict(cloth=(0.86, 0.82, 0.70), gold=(0.74, 0.60, 0.30), sash=(0.46, 0.55, 0.40), wood=(0.36, 0.25, 0.16), jade=(0.45, 0.90, 0.60), skin=(0.78, 0.64, 0.54), belt=(0.38, 0.26, 0.16)),
 'bastion': dict(steel=(0.52, 0.54, 0.58), cloth=(0.16, 0.24, 0.50), gold=(0.78, 0.62, 0.25), dark=(0.30, 0.31, 0.34), belt=(0.36, 0.25, 0.15)),
 'kestrel': dict(steel=(0.26, 0.34, 0.22), cloth=(0.24, 0.32, 0.21), gold=(0.42, 0.28, 0.17), dark=(0.33, 0.23, 0.15), belt=(0.36, 0.24, 0.14), skin=(0.78, 0.62, 0.52)),
 'gloam': dict(steel=(0.70, 0.70, 0.76), cloth=(0.30, 0.22, 0.44), gold=(0.22, 0.17, 0.27), dark=(0.13, 0.12, 0.15), belt=(0.30, 0.22, 0.17), skin=(0.08, 0.06, 0.10)),
}
def part_colour(cls, k):
    L = LOOK[cls]
    if cls == 'mender':
        if k in ('staff', 'crook'): return L['wood']
        if k == 'lantern': return L['jade']
        if k == 'sash': return L['sash']
        if k == 'head': return L['cloth']                # the face is painted under the hood later
        if k.startswith('pouch') or k == 'pelvis': return L['belt']
        if k.endswith(('boot', 'bootshaft')): return (0.34, 0.22, 0.14)
        if k.endswith('hand'): return L['skin']
        return L['cloth']
    if cls == 'bastion':
        if k.startswith(('cape', 'tabard')): return L['cloth']
        if k == 'shield': return L['cloth']
        if k in ('helm_crest',) or k.endswith('pauld'): return L['gold']
        if k == 'pelvis': return L['belt']
        if k.startswith('mace'): return (0.60, 0.61, 0.64)
        return L['steel']
    if cls == 'kestrel':
        if k.startswith(('cape', 'hood', 'mantle')): return L['cloth']
        if k == 'head': return L['skin']
        if k in ('quiver', 'pelvis'): return L['belt']
        if k == 'bow': return (0.28, 0.18, 0.11)
        if k.endswith(('thigh', 'shin')): return L['dark']
        if k.endswith(('boot', 'bootshaft')): return (0.24, 0.16, 0.10)
        return L['steel']
    if cls == 'gloam':
        if k.startswith(('cape', 'hood', 'mantle')): return L['cloth']
        if k == 'head': return L['skin']
        if k.startswith(('dagger', 'guard')): return L['steel']
        if k.endswith(('thigh', 'shin', 'boot', 'bootshaft')): return L['dark']
        if k == 'pelvis': return L['belt']
        return (0.20, 0.16, 0.26)
    return (0.6, 0.6, 0.6)

# ---------------------------------------------------------------- keyframed actions
# a key: dict(drop, fwd, lean, cyaw, tilt, feet={'R':(y,z,pitch),'L':..}, arms={'R':(A,abd,elbow),'L':..}, wpn=angle)
def lerp(a, b, s):
    if isinstance(a, dict): return {k: lerp(a[k], b[k], s) for k in a}
    if isinstance(a, tuple): return tuple(lerp(x, y, s) for x, y in zip(a, b))
    return a + (b - a) * s

def stance(C):
    Hh = C['H']; i = C
    return dict(drop=0.0, fwd=0.0, lean=0.0, cyaw=0.0, tilt=0.0, sway=0.0,
                feet={'R': (0.06 * Hh, 0.0, 0.0), 'L': (-0.05 * Hh, 0.0, 0.0)},
                arms={'R': (0.0, C['abduct'][0], C['elbow'][0]), 'L': (0.0, C['abduct'][1], C['elbow'][1])}, wpn=0.0)

def keys(cls, C, anim):
    Hh = C['H']; s0 = stance(C)
    def k(**kw):
        d = json.loads(json.dumps(s0)); d['feet'] = {a: tuple(b) for a, b in d['feet'].items()}; d['arms'] = {a: tuple(b) for a, b in d['arms'].items()}
        for a, b in kw.items():
            if a in ('feet', 'arms'): d[a].update(b)
            else: d[a] = b
        return d
    if anim == 'idle':                                  # breathing: chest rises, weapon arm settles
        return [(0, k()), (6, k(drop=0.008 * Hh, lean=2.0, arms={'R': (3.0, C['abduct'][0] + 2, C['elbow'][0] + 4)})), (12, k())]
    if anim == 'hit':                                   # recoil back, arms thrown out, recover
        return [(0, k()), (2, k(drop=0.03 * Hh, fwd=-0.03 * Hh, lean=-16, cyaw=8, arms={'R': (-25, 30, 20), 'L': (-20, 30, 25)})),
                (5, k(drop=0.02 * Hh, fwd=-0.015 * Hh, lean=-6, arms={'R': (-8, 15, 25)})), (8, k())]
    if anim == 'death':                                 # knees go, fall backward, settle
        return [(0, k()), (3, k(drop=0.08 * Hh, lean=-12, arms={'R': (-30, 35, 30), 'L': (-30, 35, 30)})),
                (8, k(drop=0.20 * Hh, tilt=62, lean=-10, arms={'R': (-60, 55, 15), 'L': (-60, 55, 15)},
                      feet={'R': (0.14 * Hh, 0.0, 30.0)})),
                (11, k(drop=0.24 * Hh, tilt=84, lean=-4, arms={'R': (-80, 70, 5), 'L': (-80, 70, 5)}, feet={'R': (0.16 * Hh, 0.0, 40.0)})),
                (12, k(drop=0.24 * Hh, tilt=86, lean=-4, arms={'R': (-82, 72, 5), 'L': (-82, 72, 5)}, feet={'R': (0.16 * Hh, 0.0, 40.0)}))]
    if cls == 'bastion' and anim == 'attack':           # overhead mace smash, shield up, step in
        return [(0, k()), (4, k(drop=0.01 * Hh, lean=-8, cyaw=-14, arms={'R': (165, 25, 70), 'L': (55, 10, 95)}, wpn=0)),
                (6, k(drop=0.04 * Hh, fwd=0.05 * Hh, lean=14, cyaw=10, arms={'R': (60, 15, 10), 'L': (50, 10, 95)}, feet={'R': (0.17 * Hh, 0.0, 0.0)})),
                (8, k(drop=0.05 * Hh, fwd=0.06 * Hh, lean=18, cyaw=12, arms={'R': (25, 12, 15), 'L': (45, 10, 95)}, feet={'R': (0.17 * Hh, 0.0, 0.0)})),
                (12, k())]
    if cls == 'bastion' and anim == 'cast':             # shield guard: shield raised square, mace cocked
        return [(0, k()), (4, k(drop=0.03 * Hh, lean=6, arms={'R': (40, 25, 80), 'L': (80, 0, 70)})), (9, k(drop=0.03 * Hh, lean=6, arms={'R': (40, 25, 80), 'L': (80, 0, 70)})), (12, k())]
    if cls == 'kestrel' and anim == 'attack':           # raise bow, draw to the cheek, loose
        aim = {'R': (88, 0, 0), 'L': (88, -30, 150)}
        return [(0, k()), (3, k(cyaw=-30, arms={'R': (70, 0, 10), 'L': (60, -10, 90)}, wpn=1.0)),
                (6, k(cyaw=-40, lean=-2, arms=aim, wpn=1.0)), (8, k(cyaw=-40, lean=-2, arms=aim, wpn=1.0)),
                (9, k(cyaw=-40, lean=-4, arms={'R': (88, 0, 0), 'L': (70, -45, 120)}, wpn=1.0)), (12, k())]
    if cls == 'kestrel' and anim == 'cast':             # Mark Shot: aim high and hold
        aim = {'R': (125, 0, 0), 'L': (125, -30, 150)}
        return [(0, k()), (4, k(cyaw=-30, lean=-8, arms=aim, wpn=1.0)), (9, k(cyaw=-30, lean=-8, arms=aim, wpn=1.0)), (12, k())]
    if cls == 'gloam' and anim == 'attack':             # cross high, lunge, double slash out and down
        return [(0, k()), (3, k(drop=0.03 * Hh, lean=4, arms={'R': (120, -25, 95), 'L': (120, -25, 95)})),
                (6, k(drop=0.06 * Hh, fwd=0.07 * Hh, lean=22, arms={'R': (45, 45, 10), 'L': (45, 45, 10)}, feet={'R': (0.20 * Hh, 0.0, 0.0)})),
                (8, k(drop=0.06 * Hh, fwd=0.07 * Hh, lean=24, arms={'R': (20, 60, 15), 'L': (20, 60, 15)}, feet={'R': (0.20 * Hh, 0.0, 0.0)})),
                (12, k())]
    if cls == 'mender' and anim == 'attack':            # lantern swing: staff swept forward, light flares at the end
        return [(0, k()), (4, k(cyaw=-18, lean=-4, arms={'R': (-30, 20, 30)})),
                (7, k(drop=0.03 * Hh, fwd=0.04 * Hh, cyaw=16, lean=10, arms={'R': (85, 10, 10)}, feet={'R': (0.15 * Hh, 0.0, 0.0)})),
                (9, k(drop=0.03 * Hh, fwd=0.04 * Hh, cyaw=16, lean=10, arms={'R': (80, 10, 12)}, feet={'R': (0.15 * Hh, 0.0, 0.0)})), (12, k())]
    if cls == 'mender' and anim == 'cast':              # heal: raise the lantern high, free hand open to the ally
        return [(0, k()), (4, k(lean=-6, arms={'R': (150, 8, 10), 'L': (70, -10, 10)})),
                (9, k(lean=-6, arms={'R': (155, 8, 8), 'L': (75, -12, 8)})), (12, k())]
    if cls == 'gloam' and anim == 'cast':               # shadow step: crouch low, daggers back, rise
        return [(0, k()), (4, k(drop=0.10 * Hh, lean=26, arms={'R': (-40, 30, 40), 'L': (-40, 30, 40)})),
                (8, k(drop=0.10 * Hh, lean=26, arms={'R': (-45, 32, 40), 'L': (-45, 32, 40)})), (12, k())]
    return [(0, k()), (12, k())]

def sample(kl, i):
    for (a, ka), (b, kb) in zip(kl, kl[1:]):
        if a <= i <= b: return lerp(ka, kb, smooth((i - a) / max(1, b - a)))
    return kl[-1][1]

def pose_act(C, st):
    Hh = C['H']; f = lambda k: C[k] * Hh; J = {}
    pel = np.array([0.0, st['fwd'], f('hip') - st['drop']])
    Rp = rot(Z, st['cyaw'] * 0.4)
    Rc = rot(Z, st['cyaw']) @ rot(X, -(C['lean'] + st['lean']))
    J['pelvis'] = pel
    J['chest'] = pel + Rc @ np.array([0, 0, f('chest') - f('hip')])
    J['neck'] = pel + Rc @ np.array([0, 0, f('neck') - f('hip')])
    J['head_c'] = pel + Rc @ np.array([0, 0.01 * Hh, f('head_c') - f('hip')])
    J['head_top'] = J['head_c'] + Rc @ np.array([0, 0, f('head')])
    for side, sg, i in (('R', 1, 0), ('L', -1, 1)):
        hip = pel + Rp @ np.array([sg * f('hip_w'), 0, -0.02 * Hh]); J[f'{side}_hip'] = hip
        fy, fz, pitch = st['feet'][side]
        Rf = rot(X, pitch); oh = np.array([0, -0.25 * f('foot'), -f('ankle')]); ot = np.array([0, 0.75 * f('foot'), -f('ankle') * 0.85])
        heel = np.array([sg * f('hip_w') * 0.9, fy - 0.25 * f('foot'), fz]); ank = heel - Rf @ oh
        J[f'{side}_ankle'], J[f'{side}_heel'], J[f'{side}_toe'] = ank, heel, ank + Rf @ ot
        J[f'{side}_knee'] = ik(hip, ank, f('thigh'), f('shin'), Rp @ Y)
        A, abd, el = st['arms'][side]
        sh = pel + Rc @ np.array([sg * f('sh_w'), 0, f('shoulder') - f('hip')]); J[f'{side}_shoulder'] = sh
        Ru = Rc @ rot(Y, sg * -abd) @ rot(X, A)
        elb = sh + Ru @ np.array([0, 0, -f('uarm')]); Rf2 = Ru @ rot(X, el)
        wr = elb + Rf2 @ np.array([0, 0, -f('farm')])
        J[f'{side}_elbow'], J[f'{side}_wrist'], J[f'{side}_hand'] = elb, wr, wr + Rf2 @ np.array([0, 0, -f('hand') * 0.5])
        J[f'_R{side}_farm'] = Rf2; J[f'_A{side}'] = A
    back = Rc @ np.array([0, -C['torso_d'] * Hh * 0.55, 0])
    J['cape_top'] = J['neck'] + back + np.array([0, 0, -0.02 * Hh])
    J['cape_mid'] = J['cape_top'] + np.array([0, -0.05 * Hh, -0.28 * Hh])
    J['cape_hem'] = J['cape_mid'] + np.array([0, -0.03 * Hh, -0.22 * Hh])
    J['_Rc'], J['_Rp'] = Rc, Rp; J['_act'] = st
    if st['tilt']:                                       # fall backward about the heels
        Rt = rot(X, st['tilt']); piv = np.array([0, -0.06 * Hh, 0])
        for kk in list(J):
            if kk.startswith('_R') or kk in ('_Rc', '_Rp'): J[kk] = Rt @ J[kk]
            elif not kk.startswith('_'): J[kk] = Rt @ (J[kk] - piv) + piv
    return J

# weapon placement during actions follows the forearm (fist closed on the handle)
_place_walk = B.place
def place(P, C, J, facing):
    M = _place_walk(P, C, J, facing)
    if '_act' not in J: return M
    Hh = C['H']; Rf = rot(Z, -90) if facing == 'S' else np.eye(3); st = J['_act']
    w = lambda k: Rf @ J[k]; Rc = Rf @ J['_Rc']
    def setm(k, m): P[k].matrix_world = mathutils.Matrix([list(r) for r in m]); M[k] = m
    if 'mace_handle' in P:
        Rh = Rf @ J['_RR_farm']; d = Rh @ nrm(np.array([0, 0.85, -0.55])); g = w('R_hand')
        setm('mace_handle', B.seg_frame(g, g + d, Rc @ X)); setm('mace_head', B.frame(Rc, g + d * 0.28 * Hh))
    if 'shield' in P:
        Rh = Rf @ J['_RL_farm']; mid = (w('L_elbow') + w('L_wrist')) / 2
        mid = w('L_elbow') * 0.3 + w('L_wrist') * 0.7
        setm('shield', B.frame(Rh @ B.SHIELD_ON_FOREARM, mid + Rh @ np.array([-0.075 * Hh, 0.0, 0.0])))
    for s in 'RL':
        if f'dagger_{s}' in P:
            Rh = Rf @ J[f'_R{s}_farm']; out = 1 if s == 'R' else -1
            d = Rh @ nrm(np.array([out * 0.35, 0.85, -0.25]))
            setm(f'dagger_{s}', B.seg_frame(w(f'{s}_hand'), w(f'{s}_hand') + d, Rc @ Z))
    if 'staff' in P:              # the staff follows the raised or swung arm; the lantern hangs from the crook
        g = w('R_hand'); fa = nrm(w('R_wrist') - w('R_elbow')); A = st['arms']['R'][0]
        up = Rf @ Z
        if A > 40: up = nrm(up * 0.35 + fa) if np.dot(fa, up) > -0.2 else nrm(up * 0.35 - fa)
        else: up = nrm(Rc @ np.array([0, 0.06, 1.0]))
        Ms = B.seg_frame(g, g + up, Rc @ X); Ms[:3, 3] = g; setm('staff', Ms)
        top = g + up * 0.55 * Hh; fw = nrm((Rc @ Y) - up * np.dot(Rc @ Y, up))
        setm('crook', B.frame(Rc, top + fw * 0.05 * Hh))
        setm('lantern', B.frame(Rc, top + fw * 0.10 * Hh - up * 0.01 * Hh))
    if 'bow' in P and st['wpn'] > 0.5:                   # drawn: limbs upright, belly facing where she aims
        aim = nrm(w('R_wrist') - w('R_elbow')); up = Rf @ Z
        setm('bow', B.bow_frame(w('R_hand'), z=up - aim * np.dot(up, aim) + aim * 0.0, y=aim))
    return M

def main():
    cls, out = sys.argv[-2], sys.argv[-1]
    C = dict(B.CLASSES[cls]); P = B.build(C); sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = 1024, 720
    sc.camera.data.ortho_scale = B.ORTHO * 1.2            # zoomed out so overhead swings and falls stay in frame
    sc.camera.data.shift_y = (590 - 360) / 1024        # pivot at (512, 590)
    for k, o in P.items():
        c = part_colour(cls, k); o.color = (*[x ** 2.2 for x in c], 1)
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'OBJECT'; sh.show_cavity = True; sh.cavity_type = 'BOTH'
    sh.show_shadows = True; sh.shadow_intensity = 0.35; sc.display.render_aa = '8'; sc.view_settings.view_transform = 'Standard'
    os.makedirs(f'{out}/show', exist_ok=True)
    def shot(name):
        sc.render.filepath = f'{out}/show/{name}.png'; bpy.ops.render.render(write_still=True)
    # walk (both facings), using the guide's walk pose
    for F in 'SE':
        for i in range(12):
            t = (i / 12) if F == 'S' else ((i - 5) / 12) % 1.0
            B.place(P, C, B.pose(C, t), F); shot(f'walk_{F}_f{i:02d}')
    # actions, S facing (and E for attack)
    lens = dict(idle=12, attack=12, cast=12, hit=8, death=12)
    for anim, n in lens.items():
        kl = keys(cls, C, anim)
        for F in (('S', 'E') if anim == 'attack' else ('S',)):
            for i in range(n + (1 if anim == 'death' else 0)):
                place(P, C, pose_act(C, sample(kl, i)), F); shot(f'{anim}_{F}_f{i:02d}')
    # turntable of the idle pose (36 steps of 10 deg)
    J = pose_act(C, stance(C))
    for i in range(36):
        place(P, C, J, 'E')
        R = mathutils.Matrix.Rotation(math.radians(10 * i), 4, 'Z')
        for o in P.values(): o.matrix_world = R @ o.matrix_world
        shot(f'turn_f{i:02d}')
    print('DONE', cls)

if __name__ == '__main__':
    main()
