"""cape hem clearance: lowest visible cape px vs the support sole row (blockout sole, metric definition), per frame.
usage: hem_check.py F [cfg overrides as json for TCFG]"""
import sys, json, numpy as np
sys.argv, args = sys.argv[:1], sys.argv[1:]
import build_hybrid as BH
import bastion_metric as MM
F = args[0]
if len(args) > 1: BH.TCFG[F].update(json.loads(args[1]))
BH.prepare_h(F); keys, _ = BH.thigh_keys(F)
J = BH.frames(F); MM.PREFIX = 'bastion'; CL = BH.B + 'clay'
out = []
for i in range(12):
    rgb, al, layers, owner, Ms, meta, order = BH.render_h(F, i, keys)
    vis = owner == order.index('cape'); ys, xs = np.nonzero(vis)
    jj = J[i]['joints']; sup = 'R' if jj['R_ankle'][1] >= jj['L_ankle'][1] else 'L'
    xw = [jj[f'{sup}_toe'][0], jj[f'{sup}_heel'][0], jj[f'{sup}_ankle'][0]]
    rv, mv = MM.load(CL, F, i); pv = MM.sole(mv & ~MM.cloth(rv), min(xw) - 12, max(xw) + 12, jj[f'{sup}_ankle'][1] - 4)
    out.append(dict(f=i, hem=int(ys.max()), hem_x=int(xs[ys >= ys.max() - 2].mean()), sole=pv[1], clear=int(pv[1] - ys.max())))
print(json.dumps(out)); print('min clear', min(o['clear'] for o in out))
