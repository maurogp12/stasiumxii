"""Bastion actions v1 - house-format and planted-feet checks -> ../qa.json.
  format   every frame 512x360 RGBA, alpha only 0 / 255, RGB 0 under alpha 0
  inside   nothing of the figure falls outside the cell: the rig renders on a padded canvas and counts the pixels that land
           outside it (frames/_build_info.json lost_px_outside_cell, must be 0 on every side); frames whose figure touches
           the cell border row/column are listed too (the S sabaton reaches row 359 in idle, as in the LOCKED walk f00-f02)
  counts   frames per action and facing = the blockout's
  skate    for each foot and each pair of consecutive frames where the blockout heel AND toe stay put (< 0.25 px), the
           painted sabaton's heel and toe (rig points) must move < 1 px (death lift subtracted)
  stretch  max / min arm bone and mace length factor vs the painting (rule: +-15 %), max leg along-bone k (walk rule <= 1.1)
usage: qa.py"""
import os, json, math, numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..')
ACTS = {'idle': 12, 'attack': 12, 'skill': 12, 'hit': 8, 'death': 13}
J = json.load(open(f'{ROOT}/blockout/joints_actions_512.json'))['facings']
B = json.load(open(f'{ROOT}/frames/_build_info.json'))['frames']
out = {'format': {}, 'counts': {}, 'skate': {}, 'touch_border': [], 'stretch': {}}
bad = []; ks = []; kl = []; km = []
for F in 'SE':
    for act, n in ACTS.items():
        key = f'{act}_{F}'; files = [f'{ROOT}/frames/{act}_{F}_f{i:02d}.png' for i in range(n)]
        out['counts'][key] = dict(frames=sum(os.path.exists(p) for p in files), blockout=len(J[key]))
        bb = []
        for i, p in enumerate(files):
            a = np.asarray(Image.open(p)); assert a.shape == (360, 512, 4), p
            al = a[..., 3]; ok_a = bool(np.isin(al, (0, 255)).all()); ok_k = bool((a[al == 0, :3] == 0).all())
            ys, xs = np.nonzero(al); bbx = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
            m = B[F][act][f'f{i:02d}']; lost = sum(m['lost_px_outside_cell'].values())
            if not (ok_a and ok_k and lost == 0): bad.append((os.path.basename(p), ok_a, ok_k, m['lost_px_outside_cell']))
            if bbx[0] == 0 or bbx[1] == 0 or bbx[2] == 511 or bbx[3] == 359: out['touch_border'].append([os.path.basename(p), bbx])
            bb.append(bbx); ks += m['arm_R']['k'] + m['arm_L']['k']; km.append(m['mace']['k']); kl += [m['R']['k'], m['L']['k']]
        out['format'][key] = dict(bbox_union=[min(b[0] for b in bb), min(b[1] for b in bb), max(b[2] for b in bb), max(b[3] for b in bb)])
        sk = {}
        for sd in 'RL':
            worst = 0.0; pairs = 0; moved = 0
            for i in range(n - 1):
                j0, j1 = J[key][f'f{i:02d}']['joints'], J[key][f'f{i + 1:02d}']['joints']
                still = all(math.dist(j0[f'{sd}_{k}'], j1[f'{sd}_{k}']) < 0.25 for k in ('heel', 'toe'))
                m0, m1 = B[F][act][f'f{i:02d}'][sd], B[F][act][f'f{i + 1:02d}'][sd]
                sh = B[F][act][f'f{i + 1:02d}']['lift_px'] - B[F][act][f'f{i:02d}']['lift_px']
                d = max(math.dist(m0[k], m1[k]) for k in ('heel', 'toe'))
                if still: pairs += 1; worst = max(worst, d)
                else: moved += 1
            sk[sd] = dict(planted_pairs=pairs, max_px=round(worst, 3), pairs_where_the_blockout_moves_the_foot=moved)
        out['skate'][key] = sk
out['stretch'] = dict(arm_bone_k=[round(min(ks), 3), round(max(ks), 3)], mace_k=[round(min(km), 3), round(max(km), 3)], leg_k_max=round(max(kl), 3))
out['problems'] = bad
json.dump(out, open(f'{ROOT}/qa.json', 'w'), indent=1)
for k, v in out['skate'].items(): print(k, out['counts'][k], v, out['format'][k])
print('stretch', out['stretch']); print('touch', len(out['touch_border']), [t[0] for t in out['touch_border']]); print('problems', bad)
