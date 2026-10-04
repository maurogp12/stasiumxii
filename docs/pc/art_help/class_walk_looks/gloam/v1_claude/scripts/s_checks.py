"""S walk checks per frame (cell px), written to s_checks.json next to the frames' parent dir:
  crotch_gap_px  background pixels (alpha 0 in the final frame) inside the convex hull of the two legs, over the rows above
                 the higher knee (smaller y): see-through between the thighs. Target: 0 on every frame.
  thigh_deg      hip -> knee screen angle off vertical per leg, + = forward (the screen walk direction: +x for S and E).
                 swing_fwd_deg = the largest forward thigh angle of a non-planted leg (rule: <= 25).
  far_boot       far-boot visible % and the gap between the boots (from boot_vis.measure; rule: >= 60 %).
usage: s_checks.py [F] [frames_dir] [out.json]"""
import os, sys, json, math, numpy as np, cv2
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import grig, boot_vis
FWD = {'S': 1.0, 'E': 1.0}   # both walk toward screen right (S down-right, E up-right)
def check(F, i, D):
    dy = grig.get_dy(F); pl = grig.plants(F)
    a = np.asarray(Image.open(f'{D}/gloam_walk_{F}_f{i:02d}.png'))[..., 3] > 127
    P = {sd: grig.leg_pose(F, i, sd, dy, pl) for sd in 'RL'}
    legs = np.zeros_like(a)
    for sd in 'RL':
        L = grig.skin(F, grig.tname(F, sd), P[sd], boot_vis.RS)[..., 3]
        legs |= cv2.resize(L, (grig.CW, grig.CH), interpolation=cv2.INTER_AREA) > 0.5
    kyf = min(P['R']['knee'][1], P['L']['knee'][1]); ky = int(math.floor(kyf))
    gap = int((grig.legs_hull(legs, kyf) & ~a).sum())
    th = {}
    for sd in 'RL':
        v = P[sd]['knee'] - P[sd]['hip']; th[sd] = round(FWD[F] * math.degrees(math.atan2(v[0], v[1])), 1)
    sw = [th[sd] for sd in 'RL' if not P[sd]['planted']]
    return dict(crotch_gap_px=gap, knee_row=ky, thigh_deg=th, planted={sd: P[sd]['planted'] for sd in 'RL'},
                swing_fwd_deg=max(sw) if sw else None, far_boot=boot_vis.measure(F, i))

if __name__ == '__main__':
    F = sys.argv[1] if len(sys.argv) > 1 else 'S'
    D = sys.argv[2] if len(sys.argv) > 2 else os.path.join(grig.HERE, '..', 'frames')
    res = {f'f{i:02d}': check(F, i, D) for i in range(12)}
    for k, v in res.items():
        print(k, 'gap', v['crotch_gap_px'], 'thigh', v['thigh_deg'], 'planted', v['planted'], 'swing', v['swing_fwd_deg'],
              'boot', v['far_boot']['visible_pct'], v['far_boot']['far'], 'gap', v['far_boot']['gap_px'])
    if len(sys.argv) > 3: json.dump(res, open(sys.argv[3], 'w'), indent=1)
