"""direct search for one frame's support-boot nudge (in-process render, metric sole) within a box around the current
value; keeps the planted-pair slide limits given on the command line. usage: fix_search.py F frame side x0 x1 y0 y1"""
import sys, json, numpy as np
args = sys.argv[1:]; sys.argv = sys.argv[:1]
import build_hybrid as BH, bastion_metric as MM
F, fi, side = args[0], int(args[1]), args[2]; x0, x1, y0, y1 = map(float, args[3:7])
BH.prepare_h(F); keys, _ = BH.thigh_keys(F); MM.PREFIX = 'bastion'
J = BH.frames(F); jj = J[fi]['joints']; sup = 'R' if jj['R_ankle'][1] >= jj['L_ankle'][1] else 'L'
xw = [jj[f'{sup}_toe'][0], jj[f'{sup}_heel'][0], jj[f'{sup}_ankle'][0]]; ya = jj[f'{sup}_ankle'][1] - 4
rv, mv = MM.load(BH.B + 'clay', F, fi); pv = MM.sole(mv & ~MM.cloth(rv), min(xw) - 12, max(xw) + 12, ya)
bf = BH.TCFG[F]['boot_fix']; best = None
for dx in np.arange(x0, x1 + 1e-6, 0.5):
    for dy in np.arange(y0, y1 + 1e-6, 0.5):
        bf[side][fi] = [float(dx), float(dy)]
        rgb, al, layers, owner, Ms, meta, order = BH.render_h(F, fi, keys)
        cell, _ = BH.clean_cell(BH.compose_cell(rgb, al)); m = cell[..., 3] > 0; r = cell[..., :3]
        pc = MM.sole(m & ~MM.cloth(r), min(xw) - 12, max(xw) + 12, ya)
        e = float(np.hypot(pc[0] - pv[0], pc[1] - pv[1]))
        if best is None or e < best[0] - 1e-6 or (abs(e - best[0]) < 0.05 and abs(dx) + abs(dy) < abs(best[1]) + abs(best[2])): best = (e, float(dx), float(dy))
print(json.dumps(dict(frame=fi, side=side, support=sup, best_err=round(best[0], 2), fix=[best[1], best[2]])))
