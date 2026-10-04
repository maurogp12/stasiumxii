#!/usr/bin/env python3
"""Ironjaw walk v3.5 prototype: HD repaint upper body + seamless arm swing + cape sway on v2's locked leg motion,
v2 legs lengthened along the hip-ankle axis (feet pinned) and graded to the HD leg palette.
Run from the repo root: python3 docs/pc/art_help/ironjaw_walk/claude/scripts/proto.py S E
Stand-in for the v4 painted legs: swap leg_layer() for the new thigh/greave/boot parts and keep everything else."""
import json, sys, numpy as np, cv2
from PIL import Image
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cut import cut_target
import rig_fx as fx

R = 'docs/pc/art_help/ironjaw_walk/'
J = json.load(open(R + 'ta_joints/joints_512.json'))['facings']
FIT = json.load(open(R + 'claude/scripts/idlefit.json'))            # target->cell scale fitted to the approved idle set
# target-space annotations (abs px in the 1280x720 repaints)
ANN = {
 'S': dict(pelvis=(588, 330), raise_px=13,
           arms=[dict(name='near', pivot=(500, 160), r0=70, r1=200, sign=1,
                      poly=[(430, 80), (548, 80), (548, 215), (524, 255), (530, 330), (540, 400), (475, 412), (470, 515), (325, 515), (325, 318), (430, 318), (436, 200)]),
                 dict(name='far', pivot=(725, 160), r0=70, r1=200, sign=-1,
                      poly=[(690, 55), (805, 55), (835, 200), (935, 318), (935, 500), (800, 500), (790, 410), (688, 405), (700, 330), (712, 220), (684, 120)])],
           cape_y=430, legs=[(540, 445), (712, 445), (728, 560), (745, 712), (505, 712), (525, 560)], loin_y=440,
           cape=dict(top=150, hem=640, amp=7.0, ripple=3.0, hem_lift=45), cape_front=False),
 'E': dict(pelvis=(605, 400), raise_px=0,
           arms=[dict(name='left', pivot=(515, 150), r0=60, r1=190, sign=1, axis=(-0.3, 1),
                      poly=[(462, 85), (572, 85), (552, 235), (528, 330), (520, 420), (470, 585), (330, 585), (330, 335), (428, 325), (436, 200)]),
                 dict(name='right', pivot=(705, 150), r0=60, r1=190, sign=-1, axis=(0.3, 1),
                      poly=[(648, 85), (772, 85), (806, 200), (812, 325), (905, 345), (905, 585), (765, 585), (728, 420), (700, 330), (702, 235)])],
           cape_y=440, legs=[(522, 430), (745, 430), (755, 712), (515, 712)], loin_y=0,
           cape=dict(top=110, hem=625, amp=8.0, ripple=3.0, hem_lift=45), cape_front=True),
}

def poly_mask(shape, pts):
    m = np.zeros(shape, np.uint8); cv2.fillPoly(m, [np.int32(pts)], 1); return m > 0

def is_red(rgb):
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(int)
    return (lab[..., 1] - 128 > 10) & (lab[..., 1] - 128 > (lab[..., 2] - 128) * 1.2)

def layers(F):
    A = ANN[F]; rgb, al, _ = cut_target(R + f'repaint_targets/rp_{F}_f00_t1.jpg')
    rgba = np.dstack([rgb, al.astype(np.uint8) * 255])
    # cloth = crimson plus the dark folds between crimson strands (closing), so the cape is cut whole, not as strands
    red = cv2.morphologyEx(is_red(rgb).astype(np.uint8), cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8)) > 0
    red &= al
    H = rgb.shape[:2]; yy = np.mgrid[0:H[0], 0:H[1]][0]
    L = {}
    legs = poly_mask(H, A['legs'])
    low = al & (yy > A['cape_y']) & ~legs                      # dark strand tips below the waist belong to the cape too
    cape = ((red & ~(yy < A['loin_y'])) if not A['cape_front'] else (red & (yy > 120))) | low
    taken = np.zeros(H, bool)
    for arm in A['arms']:
        m = poly_mask(H, arm['poly']) & al & ~red & ~taken; taken |= m
        L[arm['name']] = np.where(m[..., None], rgba, 0).astype(np.uint8)
    L['cape'] = np.where((cape & ~taken)[..., None], rgba, 0).astype(np.uint8)
    body = al & ~taken & ~cape & ~(legs & ~red)
    L['body'] = np.where(body[..., None], rgba, 0).astype(np.uint8)
    L['_legref'] = (rgb, legs & al & ~red)
    return L

def to_cell(layer, F, off):
    s, tx, ty = FIT[F]
    M = np.float32([[s, 0, tx + off[0]], [0, s, ty + off[1]]])
    return cv2.warpAffine(layer, M, (512, 360), flags=cv2.INTER_AREA, borderValue=(0, 0, 0, 0))

def swing_series(F):
    """arm swing per frame from TA shoulder->grip angle, scaled to Luca's +-15 deg about the mid pose."""
    out = {}
    for side in 'RL':
        a = []
        for i in range(12):
            j = J[f'walk_{F}'][f'f{i:02d}']['joints']; d = np.subtract(j[f'{side}_axe_grip'], j[f'{side}_shoulder'])
            a.append(np.degrees(np.arctan2(d[0], d[1])))
        a = np.unwrap(np.radians(a)); a = np.degrees(a - a.mean()); k = 15 / max(1e-3, np.abs(a).max())
        out[side] = a * k - (a * k)[0]                      # the repaint IS the f00 pose: f00 = 0 deg, the cycle spans 30 deg
    return out

def leg_layer(F, i, raise_px, ref):
    v = np.asarray(Image.open(R + f'walk_v2_frames/ironjaw_walk_{F}_f{i:02d}.png').convert('RGBA')).copy()
    j = J[f'walk_{F}'][f'f{i:02d}']; jj = j['joints']; order = [p for p in j['draw_order']]
    red = is_red(v[..., :3]); out = np.zeros_like(v); taken = np.zeros((360, 512), bool)
    near_first = sorted('RL', key=lambda s: min([order.index(p) for p in order if p.startswith(s + '_') and any(k in p for k in ('thigh', 'shin', 'boot'))] or [99]))
    pieces = {}
    for side in near_first:                                   # nearest leg claims overlapping pixels
        m = (fx.capsule((360, 512), jj[f'{side}_hip'], jj[f'{side}_knee'], 15) | fx.capsule((360, 512), jj[f'{side}_knee'], jj[f'{side}_ankle'], 13)
             | fx.capsule((360, 512), jj[f'{side}_heel'], jj[f'{side}_toe'], 12) | fx.capsule((360, 512), jj[f'{side}_ankle'], jj[f'{side}_toe'], 12))
        m &= (v[..., 3] > 127) & ~red & ~taken; taken |= m; pieces[side] = m
    rgb_ref, mref = ref
    graded = fx.lab_match(v[..., :3], taken, rgb_ref, mref, 0.85)
    for side in reversed(near_first):                         # far leg first, near leg on top
        m = pieces[side]; lay = np.zeros_like(v); lay[m] = np.dstack([graded, v[..., 3:]])[m]
        hip, ank = jj[f'{side}_hip'], jj[f'{side}_ankle']
        if raise_px:
            Mx = fx.axis_stretch(hip, ank, (hip[0], hip[1] - raise_px))
            foot = fx.capsule((360, 512), jj[f'{side}_heel'], jj[f'{side}_toe'], 13) | fx.capsule((360, 512), ank, ank, 13)
            legpart = lay.copy(); legpart[foot] = 0; footpart = lay.copy(); footpart[~foot] = 0
            legpart = cv2.warpAffine(legpart, np.float32(Mx), (512, 360), flags=cv2.INTER_LINEAR)
            lay = fx.over(legpart, footpart)                  # boot unchanged: plants, skate and soles stay exactly v2
        out = fx.over(out, lay)
    return out

def frame(F, i, L, sw):
    A = ANN[F]; jj = J[f'walk_{F}'][f'f{i:02d}']['joints']; s = FIT[F][0]
    pel = np.array(jj['pelvis']) - (0, A['raise_px'])
    base = np.array(A['pelvis']) * s + FIT[F][1:]
    off = pel - base
    ph = 2 * np.pi * i / 12
    sway = -np.sin(ph - 0.9)                                   # lags the pelvis (one-two frames)
    c = A['cape']
    cape = fx.cape_sway(L['cape'], c['top'], c['hem'], c['amp'] * sway, lift=c['hem_lift'] - 4 * np.cos(2 * ph - 1.0), ripple=c['ripple'], phase=ph * 2)
    cell = lambda lay: to_cell(lay, F, off)
    arms = []
    for arm, side in zip(A['arms'], 'RL'):
        a = arm['sign'] * sw[side][i]
        if F == 'E':   # back view: mostly foreshortening + a little rotation
            arms.append(cell(fx.lbs_swing(L[arm['name']], arm['pivot'], 0.25 * a, arm['r0'], arm['r1'], stretch=1 - 0.004 * arm['sign'] * a, axis=arm['axis'])))
        else:
            arms.append(cell(fx.lbs_swing(L[arm['name']], arm['pivot'], a, arm['r0'], arm['r1'])))
    legs = leg_layer(F, i, A['raise_px'], L['_legref'])
    o = np.zeros((360, 512, 4), np.uint8)
    if not A['cape_front']:
        o = fx.over(o, cell(cape)); o = fx.over(o, arms[1]); o = fx.over(o, legs); o = fx.over(o, cell(L['body'])); o = fx.over(o, arms[0])
    else:
        o = fx.over(o, legs); o = fx.over(o, cell(L['body'])); o = fx.over(o, cell(cape)); o = fx.over(o, arms[0]); o = fx.over(o, arms[1])
    a = o[..., 3] > 127; o[..., 3] = a * 255; o[~a] = 0           # binary alpha, black under alpha 0 (house rule)
    return o

if __name__ == '__main__':
    import os; os.makedirs(R + 'claude/proto_frames', exist_ok=True)
    for F in sys.argv[1:] or 'SE':
        L = layers(F); sw = swing_series(F)
        print(F, 'swing R', np.round(sw['R'], 1).tolist())
        for i in range(12):
            Image.fromarray(frame(F, i, L, sw)).save(R + f'claude/proto_frames/ironjaw_walk_{F}_f{i:02d}.png')
