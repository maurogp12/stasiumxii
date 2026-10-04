"""Ironjaw actions v1 - house-format, inside-the-cell, frame-count, planted-feet, stretch and clean-up checks -> ../qa.json.
  format       every frame 512x360 RGBA, alpha only 0 / 255, RGB 0 under alpha 0
  inside       nothing of the figure falls outside the cell: the rig renders on a padded canvas and counts the pixels that
               land outside it (frames/_build_info.json lost_px_outside_cell, must be 0 on every side); frames touching the
               border row / column are listed
  counts       frames per action and facing = the blockout's
  skate        for each foot and each pair of consecutive frames where the blockout heel AND toe stay put (< 0.25 px), the
               painted boot's ground point, heel and toe (rig points the boot is pinned to) must move < 1 px
  arm_stretch  upper-arm bone length factor vs the painting (rule +-15 %) and the forearm + fist + axe piece (rigid, 1.00);
               edge_turn = how far a forearm + axe piece was turned about the elbow to stay inside the cell
  legs         max leg k (along the bone, only when the IK is out of reach) and the effective span factor
  clean        speck islands, pin holes and dark edge (halo) pixels: what the rig's clean-up found and fixed per frame, and
               a re-check on the written frames (enclosed holes < 24 px and isolated islands < 8 px must be 0)
usage: qa.py"""
import os, json, math, numpy as np
from PIL import Image
from scipy import ndimage as ndi
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..')
ACTS = {'idle': 12, 'attack': 12, 'skill': 12, 'hit': 8, 'death': 13}
J = json.load(open(f'{ROOT}/blockout/joints_actions_512.json'))['facings']
B = json.load(open(f'{ROOT}/frames/_build_info.json'))['frames']
out = {'format': {}, 'counts': {}, 'skate': {}, 'touch_border': [], 'arm_stretch': {}, 'edge_turn': [], 'clean': {}}
bad = []; ku = []; kf = []; kl = []; ke = []; halo = 0; holes = 0; rest_holes = 0; rest_specks = 0
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
            bb.append(bbx)
            for sd in 'RL':
                ku.append(m[f'arm_{sd}']['k'][0]); kf.append(m[f'arm_{sd}']['k'][1])
                if m[f'arm_{sd}'].get('edge_turn_deg'): out['edge_turn'].append([os.path.basename(p), sd, m[f'arm_{sd}']['edge_turn_deg']])
            kl += [m['R']['k'], m['L']['k']]; ke.append([max(m['R']['k_eff'], m['L']['k_eff']), os.path.basename(p)]); halo += m['cleanup']['halo_px']; holes += m['cleanup']['holes_closed']
            msk = al > 0; hl, hn = ndi.label(ndi.binary_fill_holes(msk) & ~msk)
            if hn: sz = np.bincount(hl.ravel())[1:]; rest_holes += int((sz < 24).sum())
            il, inn = ndi.label(msk, np.ones((3, 3)))
            if inn: sz = np.bincount(il.ravel())[1:]; rest_specks += int((sz < 8).sum())
        out['format'][key] = dict(bbox_union=[min(b[0] for b in bb), min(b[1] for b in bb), max(b[2] for b in bb), max(b[3] for b in bb)])
        sk = {}
        for sd in 'RL':
            worst = 0.0; pairs = 0; moved = 0
            for i in range(n - 1):
                j0, j1 = J[key][f'f{i:02d}']['joints'], J[key][f'f{i + 1:02d}']['joints']
                still = all(math.dist(j0[f'{sd}_{k}'], j1[f'{sd}_{k}']) < 0.25 for k in ('heel', 'toe'))
                m0, m1 = B[F][act][f'f{i:02d}'][sd], B[F][act][f'f{i + 1:02d}'][sd]
                sh = np.array([B[F][act][f'f{i + 1:02d}']['side_px'] - B[F][act][f'f{i:02d}']['side_px'],
                               -(B[F][act][f'f{i + 1:02d}']['lift_px'] - B[F][act][f'f{i:02d}']['lift_px'])])
                d = max(math.dist(np.add(m0[k], sh), m1[k]) for k in ('heel', 'toe'))
                if still: pairs += 1; worst = max(worst, d)
                else: moved += 1
            sk[sd] = dict(planted_pairs=pairs, max_px=round(worst, 3), pairs_where_the_blockout_moves_the_foot=moved)
        out['skate'][key] = sk
out['arm_stretch'] = dict(upper_arm_k=[round(min(ku), 3), round(max(ku), 3)], forearm_axe_k=[round(min(kf), 3), round(max(kf), 3)],
                          max_abs_stretch_pct=round(100 * max(abs(1 - min(ku)), abs(max(ku) - 1), abs(1 - min(kf)), abs(max(kf) - 1)), 1))
out['legs'] = dict(leg_k_max=round(max(kl), 3), leg_k_effective_max=round(max(ke)[0], 3), frames_over_1_10=[f for k_, f in ke if k_ > 1.1001],
                   note='k: the IK bone scale (1.00-1.10). k_effective: hip-to-ankle span / idle leg length; above 1.10 the shin takes the rest')
out['clean'] = dict(halo_px_recoloured=halo, pin_hole_px_closed=holes, small_holes_left=rest_holes, specks_left=rest_specks)
out['problems'] = bad
json.dump(out, open(f'{ROOT}/qa.json', 'w'), indent=1)
for k, v in out['skate'].items(): print(k, out['counts'][k], v, out['format'][k])
print('arm_stretch', out['arm_stretch'], 'legs', out['legs']); print('edge_turn', out['edge_turn'])
print('touch', len(out['touch_border']), [t[0] for t in out['touch_border']]); print('clean', out['clean']); print('problems', bad)
