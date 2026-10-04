"""S foot-track sweep (run once per blockout render; MBLOCK_S_DIR = a rendered mender/ blockout folder at some foot_w).
Per S frame on the rigged painted legs: (a) shins cross = the two knee->ankle segments intersect on screen (an X below the
knees); (b) far-boot visible % (boot_vis.measure); (c) the contact heel-pair angle at f00 / f06 = atan2 of (front heel - back
heel) on screen, from the blockout heel joints (travel diagonal = 26.6 deg; Kestrel v3.2 approved 41/27, v3.1 rejected 78/9,
Gloam v3.1 approved 88/6). Writes <out>.json and the rigged f00/f01/f03/f06/f09 (+ the lowest far-boot frame) cells to <out>_fNN.png.
usage: MBLOCK_S_DIR=... s_track.py out_prefix"""
import os, sys, json, math, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mrig as grig, boot_vis
from PIL import Image
F = 'S'; WD = grig.unit([2.0, 1.0])

def seg_x(p1, p2, q1, q2):
    d = lambda a, b, c: (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    return (d(p1, p2, q1) * d(p1, p2, q2) < 0) and (d(q1, q2, p1) * d(q1, q2, p2) < 0)

def contact_angle(i):
    fr = grig.frames(F)[i]; h = {sd: grig.jnt(fr, sd + '_heel') for sd in 'RL'}
    fw = max('RL', key=lambda sd: h[sd] @ WD); bk = 'L' if fw == 'R' else 'R'; v = h[fw] - h[bk]
    return round(math.degrees(math.atan2(v[1], v[0])), 1)

if __name__ == '__main__':
    out = sys.argv[1]; dy = grig.get_dy(F); pl = grig.plants(F); res = dict(blockout=grig.bd(F), frames={})
    for i in range(12):
        P = {sd: grig.leg_pose(F, i, sd, dy, pl) for sd in 'RL'}
        cross = seg_x(P['R']['knee'], P['R']['ankle'], P['L']['knee'], P['L']['ankle'])
        m = boot_vis.measure(F, i)
        res['frames'][f'f{i:02d}'] = dict(shins_cross=bool(cross), far_boot_pct=m['visible_pct'], far=m['far'])
    res['cross_frames'] = [k for k, v in res['frames'].items() if v['shins_cross']]
    res['far_boot_min'] = min(v['far_boot_pct'] for v in res['frames'].values())
    res['far_boot_min_frame'] = min(res['frames'], key=lambda k: res['frames'][k]['far_boot_pct'])
    res['contact_angle_f00_f06'] = [contact_angle(0), contact_angle(6)]
    json.dump(res, open(out + '.json', 'w'), indent=1)
    for i in sorted({0, 1, 3, 6, 9, int(res['far_boot_min_frame'][1:])}):
        img, _ = grig.render(F, i, 3); Image.fromarray(grig.to_cell(img, 3, F)).save(f'{out}_f{i:02d}.png')
    print(os.path.basename(out), 'cross', res['cross_frames'], 'far min', res['far_boot_min'], res['far_boot_min_frame'],
          'angle', res['contact_angle_f00_f06'], [v['far_boot_pct'] for v in res['frames'].values()])
