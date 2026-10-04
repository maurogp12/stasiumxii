"""per frame support sole point, candidate vs v2 clay (same rule as kestrel_metric.py). usage: sole_dbg.py F DIR"""
import sys, json, numpy as np
from PIL import Image
import kestrel_metric as MM
from kcommon import B, J
F, D = sys.argv[1], sys.argv[2]; JJ = J['walk_' + F]
for i in range(12):
    jj = JJ[f'f{i:02d}']['joints']; sup = 'R' if jj['R_ankle'][1] >= jj['L_ankle'][1] else 'L'
    xs = [jj[f'{sup}_toe'][0], jj[f'{sup}_heel'][0], jj[f'{sup}_ankle'][0]]; y0 = jj[f'{sup}_ankle'][1] - 4
    rc, mc = MM.load(D, F, i); rv, mv = MM.load(B + 'clay', F, i)
    pc = MM.sole(mc & ~MM.cloth(rc), min(xs) - 12, max(xs) + 12, y0); pv = MM.sole(mv & ~MM.cloth(rv), min(xs) - 12, max(xs) + 12, y0)
    print(i, sup, 'cand', (round(pc[0], 1), pc[1]), 'clay', (round(pv[0], 1), pv[1]), 'd', (round(pc[0] - pv[0], 1), pc[1] - pv[1]))
