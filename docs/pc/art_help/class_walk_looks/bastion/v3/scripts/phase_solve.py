"""constant sub-pixel phase of the target layers (trunk map). The match_metric fit searches translations on an integer
lattice anchored at the candidate's centroid / top row, so depending on the trunk's sub-pixel phase it can land up to
0.5 px off (and a scale step low) although the candidate's upper body IS the target there; that only costs SSIM. This picks
the phase (x and y in 0..0.9) whose metric fit reproduces the real placement best (highest upper SSIM at the fit).
Visual change < 1 px, the same for every frame (bob unchanged). usage: phase_solve.py F"""
import sys, os, json, itertools, numpy as np
sys.argv, A = sys.argv[:1], sys.argv[1:]
from PIL import Image
import build_hybrid as BH, bastion_metric as MM
F = A[0]; HERE = os.path.dirname(os.path.abspath(__file__)); cfgp = os.path.join(HERE, 'cfg_hybrid.json')
T = '/workspace/handoff/class_walk_blockouts/targets/'; MM.PREFIX = 'bastion'
trgb = np.asarray(Image.open(f'{T}bastion_rp_{F}_f00.jpg').convert('RGB')); ta = np.asarray(Image.open(f'{T}bastion_rp_{F}_f00_alpha.png').convert('L')) > 127
BH.prepare_h(F); keys, _ = BH.thigh_keys(F); py = int(round(BH.frames(F)[0]['joints']['pelvis'][1]))
up = np.zeros((360, 512), bool); up[:py] = True; best = None
for px, pyh in itertools.product(np.arange(0, 1, 0.2), np.arange(0, 1, 0.25)):
    BH.TCFG[F]['phase'] = [float(px), float(pyh)]
    rgb, al, layers, owner, Ms, meta, order = BH.render_h(F, 0, keys)
    cell, _ = BH.clean_cell(BH.compose_cell(rgb, al)); cr, cm = cell[..., :3], cell[..., 3] > 0
    iu, s, tx, ty = MM.fit(trgb, ta, cm, py); tr, tm = MM.place(trgb, ta, s, tx, ty)
    v = MM.mssim(MM.comp(cr, cm), MM.comp(tr, tm), (cm | tm) & up)
    print(round(px, 2), round(pyh, 2), 'fit', round(s, 4), round(tx, 2), round(ty, 2), 'ssim_up', round(v, 3), flush=True)
    if best is None or v > best[0]: best = (v, [round(float(px), 2), round(float(pyh), 2)])
c = json.load(open(cfgp)); c[F]['T']['phase'] = best[1]; json.dump(c, open(cfgp, 'w'), indent=1); print('best', best)
