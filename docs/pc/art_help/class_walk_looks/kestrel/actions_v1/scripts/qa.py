"""Kestrel actions v1 - house-format and planted-feet checks -> qa.json.
  format   every frame 512x360 RGBA, alpha only 0 / 255, RGB 0 under alpha 0, figure inside the cell (not touching an edge)
  counts   frames per action and facing = the blockout's
  skate    for each foot and each pair of consecutive frames where the blockout heel AND toe stay put (< 0.25 px), the
           painted heel and toe (rig points, frames/_build_info.json) must move < 1 px; also measured on the painted boot
           itself: the lowest-row centroid of the boot's alpha around the rig heel/toe.
usage: qa.py"""
import os, json, math, numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..')
ACTS = {'idle': 12, 'attack': 12, 'skill': 12, 'hit': 8, 'death': 13}
J = json.load(open(f'{ROOT}/blockout/joints_actions_512.json'))['facings']
B = json.load(open(f'{ROOT}/frames/_build_info.json'))['frames']
out = {'format': {}, 'counts': {}, 'skate': {}}
bad = []
for F in 'SE':
    for act, n in ACTS.items():
        key = f'{act}_{F}'; files = [f'{ROOT}/frames/{act}_{F}_f{i:02d}.png' for i in range(n)]
        out['counts'][key] = dict(frames=sum(os.path.exists(p) for p in files), blockout=len(J[key]))
        bb = []
        for p in files:
            a = np.asarray(Image.open(p)); assert a.shape == (360, 512, 4), p
            al = a[..., 3]; ok_a = bool(np.isin(al, (0, 255)).all()); ok_k = bool((a[al == 0, :3] == 0).all())
            ys, xs = np.nonzero(al); bbx = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
            inside = bbx[0] > 0 and bbx[1] > 0 and bbx[2] < 511 and bbx[3] < 359
            if not (ok_a and ok_k and inside): bad.append((os.path.basename(p), ok_a, ok_k, bbx))
            bb.append(bbx)
        out['format'][key] = dict(bbox_union=[min(b[0] for b in bb), min(b[1] for b in bb), max(b[2] for b in bb), max(b[3] for b in bb)])
        sk = {}
        for sd in 'RL':
            worst = 0.0; pairs = 0; moved = 0
            for i in range(n - 1):
                j0, j1 = J[key][f'f{i:02d}']['joints'], J[key][f'f{i + 1:02d}']['joints']
                still = all(math.dist(j0[f'{sd}_{k}'], j1[f'{sd}_{k}']) < 0.25 for k in ('heel', 'toe'))
                m0, m1 = B[F][act][f'f{i:02d}'][sd], B[F][act][f'f{i + 1:02d}'][sd]
                d = max(math.dist(m0[k], m1[k]) for k in ('heel', 'toe'))
                sh = B[F][act][f'f{i + 1:02d}']['shift'] - B[F][act][f'f{i:02d}']['shift']
                d = max(math.dist(m0[k], (m1[k][0], m1[k][1] - sh)) for k in ('heel', 'toe'))
                if still: pairs += 1; worst = max(worst, d)
                else: moved += 1
            sk[sd] = dict(planted_pairs=pairs, max_px=round(worst, 3), pairs_where_the_blockout_moves_the_foot=moved)
        out['skate'][key] = sk
out['problems'] = bad
json.dump(out, open(f'{ROOT}/qa.json', 'w'), indent=1)
for k, v in out['skate'].items(): print(k, out['counts'][k], v, out['format'][k])
print('problems', bad)
# ---- arm keys: per frame, the painted key used per arm and its stretch (bone length / key length) for the upper sleeve
# and the forearm. Rule (round 2): within +-15 % on every frame.
arms = {}; worst = 0.0
for F in 'SE':
    for act, n in ACTS.items():
        for i in range(n):
            m = B[F][act][f'f{i:02d}']
            row = {sd: dict(key=m['arm_' + sd]['key'], up=m['arm_' + sd]['up'], fore=m['arm_' + sd]['fore']) for sd in 'RL'}
            st_ = max(max(abs(v['up'] - 1), abs(v['fore'] - 1)) for v in row.values()); row['max_dev'] = round(st_, 3)
            worst = max(worst, st_); arms[f'{act}_{F}_f{i:02d}'] = row
out['arm_stretch'] = dict(max_dev=round(worst, 3), frames=arms)
json.dump(out, open(f'{ROOT}/qa.json', 'w'), indent=1)
print('arm stretch max deviation', round(worst, 3), 'worst frames', sorted(arms, key=lambda k: -arms[k]['max_dev'])[:6])
