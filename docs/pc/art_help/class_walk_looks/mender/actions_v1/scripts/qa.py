"""Mender actions v1 - house-format, planted-feet and stretch checks -> ../qa.json (same checks as bastion/actions_v1/scripts/qa.py).
  format       every frame 512x360 RGBA, alpha only 0 / 255, RGB 0 under alpha 0
  inside       nothing of the figure falls outside the cell (the rig renders on a padded canvas and counts the pixels that land
               outside it: frames/_build_info.json lost_px_outside_cell must be 0 on every side, death included); frames
               whose figure touches the cell border row / column are listed too
  counts       frames per action and facing = the blockout's
  skate        for each foot and each pair of consecutive frames where the blockout heel AND toe stay put (< 0.25 px), the
               painted boot's heel and toe (rig points) must move < 1 px
  arm_stretch  min / max arm bone length factor vs the painting per action (rule: within +-15 %), and per bone; the
               staff, lantern and arm pieces are rigid (scale s only)
  leg_k        max leg along-bone k (walk rule <= 1.10) and the largest gap left under the robe when a leg is short
usage: qa.py"""
import os, json, math, numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..')
ACTS = {'idle': 12, 'attack': 12, 'skill': 12, 'hit': 8, 'death': 13}
J = json.load(open(f'{ROOT}/blockout/joints_actions_512.json'))['facings']
B = json.load(open(f'{ROOT}/frames/_build_info.json'))['frames']
out = {'format': {}, 'counts': {}, 'skate': {}, 'touch_border': [], 'arm_stretch': {}, 'leg_k': {}, 'staff_tip_corr_deg': {}}
bad = []; ks_all = []
for F in 'SE':
    for act, n in ACTS.items():
        key = f'{act}_{F}'; files = [f'{ROOT}/frames/{act}_{F}_f{i:02d}.png' for i in range(n)]
        out['counts'][key] = dict(frames=sum(os.path.exists(p) for p in files), blockout=len(J[key]))
        bb = []; ks = {'R_upper': [], 'R_fore': [], 'L_upper': [], 'L_fore': []}; kl = []; short = []; corr = []
        for i, p in enumerate(files):
            a = np.asarray(Image.open(p)); assert a.shape == (360, 512, 4), p
            al = a[..., 3]; ok_a = bool(np.isin(al, (0, 255)).all()); ok_k = bool((a[al == 0, :3] == 0).all())
            ys, xs = np.nonzero(al); bbx = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
            m = B[F][act][f'f{i:02d}']; lost = sum(m['lost_px_outside_cell'].values())
            if not (ok_a and ok_k and lost == 0): bad.append((os.path.basename(p), ok_a, ok_k, m['lost_px_outside_cell']))
            if bbx[0] == 0 or bbx[1] == 0 or bbx[2] == 511 or bbx[3] == 359: out['touch_border'].append([os.path.basename(p), bbx])
            bb.append(bbx)
            for sd in 'RL':
                ks[f'{sd}_upper'].append(m['arm_' + sd]['k'][0]); ks[f'{sd}_fore'].append(m['arm_' + sd]['k'][1])
            kl += [m['R']['k'], m['L']['k']]; short += [m['R']['short'], m['L']['short']]; corr.append(abs(m['staff']['top_corr_deg']))
        out['format'][key] = dict(bbox_union=[min(b[0] for b in bb), min(b[1] for b in bb), max(b[2] for b in bb), max(b[3] for b in bb)])
        allk = sum(ks.values(), []); ks_all += allk
        out['arm_stretch'][key] = dict(min=round(min(allk), 3), max=round(max(allk), 3), **{k: [round(min(v), 3), round(max(v), 3)] for k, v in ks.items()})
        out['leg_k'][key] = dict(max=round(max(kl), 3), max_short_px=round(max(short), 2))
        out['staff_tip_corr_deg'][key] = round(max(corr), 1)
        sk = {}
        for sd in 'RL':
            worst = 0.0; pairs = 0; moved = 0
            for i in range(n - 1):
                j0, j1 = J[key][f'f{i:02d}']['joints'], J[key][f'f{i + 1:02d}']['joints']
                still = all(math.dist(j0[f'{sd}_{k}'], j1[f'{sd}_{k}']) < 0.25 for k in ('heel', 'toe'))
                m0, m1 = B[F][act][f'f{i:02d}'][sd], B[F][act][f'f{i + 1:02d}'][sd]
                d = max(math.dist(m0[k], m1[k]) for k in ('heel', 'toe'))
                if still: pairs += 1; worst = max(worst, d)
                else: moved += 1
            sk[sd] = dict(planted_pairs=pairs, max_px=round(worst, 3), pairs_where_the_blockout_moves_the_foot=moved)
        out['skate'][key] = sk
out['arm_stretch']['all'] = dict(min=round(min(ks_all), 3), max=round(max(ks_all), 3),
                                 max_abs_pct=round(100 * max(abs(1 - min(ks_all)), abs(max(ks_all) - 1)), 1))
out['problems'] = bad
json.dump(out, open(f'{ROOT}/qa.json', 'w'), indent=1)
for k, v in out['skate'].items(): print(k, out['counts'][k], v, out['format'][k], out['arm_stretch'][k]['min'], out['arm_stretch'][k]['max'], out['leg_k'][k])
print('arm_stretch', out['arm_stretch']['all']); print('touch', len(out['touch_border']), [t[0] for t in out['touch_border']]); print('problems', bad)
