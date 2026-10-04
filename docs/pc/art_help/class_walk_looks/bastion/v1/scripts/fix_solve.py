"""per-frame per-side sabaton nudge (TCFG boot_fix) on top of the planted-joint anchoring: put every support sole within
1.7 px of the blockout sole (metric) while a planted contact moves at most `slide` px between consecutive planted frames
(heel or toe planted in both frames). Linear model (a nudge moves the sole point by itself), SLSQP, then re-measured.
usage: fix_solve.py F [slide=1.0] [tol=1.7]"""
import sys, json, subprocess, os, numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
F = sys.argv[1]; SLIDE = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0; TOL = float(sys.argv[3]) if len(sys.argv) > 3 else 1.7
PY = '/workspace/.venv/bin/python'; TMP = '/workspace/scratch/bastion/cal'; cfgp = os.path.join(HERE, 'cfg_hybrid.json')
sys.argv = sys.argv[:1]
import build as BM
PL = BM.plants(F)
def measure():
    subprocess.run([PY, os.path.join(HERE, 'build_hybrid.py'), '--only', F, '--out', TMP], check=True, capture_output=True)
    out = subprocess.run([PY, os.path.join(HERE, 'sole_dbg.py'), F, TMP, TMP + '/sole.png'], check=True, capture_output=True, text=True).stdout
    R = {}
    for line in out.strip().split('\n'):
        i = int(line.split()[0]); R[i] = (line.split()[1], np.array(eval(line.split(' d ')[1]), float))
    return R
c = json.load(open(cfgp)); cur = c[F]['T'].get('boot_fix', {'R': [[0, 0]] * 12, 'L': [[0, 0]] * 12})
cur = {s: np.array(cur.get(s, [[0, 0]] * 12), float) for s in 'RL'}
R = measure()
base = {i: (sup, e - cur[sup][i]) for i, (sup, e) in R.items()}      # error with zero nudge (linear model)
idx = lambda s, i, k: ('RL'.index(s) * 12 + i) * 2 + k
pairs = [(s, i) for s in 'RL' for i in range(12) if (PL[s]['heel'][i] and PL[s]['heel'][(i + 1) % 12]) or (PL[s]['toe'][i] and PL[s]['toe'][(i + 1) % 12])]
full = lambda s, i: all(PL[s][j][k] for j in ('heel', 'toe') for k in (i, (i + 1) % 12))
SLIDE_PIVOT = float(os.environ.get('SLIDE_PIVOT', SLIDE))
# LP (HiGHS): vars = 48 nudges + 48 |nudge| bounds; box tolerance per support frame, slide box per planted pair
from scipy.optimize import linprog
nv = 48; Aub, bub = [], []
def row(): return np.zeros(2 * nv)
TOLXY = (TOL, max(0.6, TOL - 0.4))
for i, (sup, e0) in base.items():
    for k in range(2):
        r = row(); r[idx(sup, i, k)] = 1; Aub.append(r); bub.append(TOLXY[k] - e0[k])
        r = row(); r[idx(sup, i, k)] = -1; Aub.append(r); bub.append(TOLXY[k] + e0[k])
for s_, i in pairs:
    for k in range(2):
        sl = SLIDE if full(s_, i) else SLIDE_PIVOT
        r = row(); r[idx(s_, (i + 1) % 12, k)] = 1; r[idx(s_, i, k)] -= 1; Aub.append(r); bub.append(sl)
        r = -r; Aub.append(r); bub.append(sl)
for v in range(nv):
    r = row(); r[v] = 1; r[nv + v] = -1; Aub.append(r); bub.append(0)
    r = row(); r[v] = -1; r[nv + v] = -1; Aub.append(r); bub.append(0)
cobj = np.r_[np.zeros(nv), np.ones(nv)]
res = minimize = None
res = linprog(cobj, A_ub=np.array(Aub), b_ub=np.array(bub), bounds=[(-6, 6)] * nv + [(0, None)] * nv, method='highs')
class _R: pass
if res.status != 0:
    print('LP infeasible:', res.message); sys.exit(1)
def unpack(x): return {s: x[idx(s, 0, 0):idx(s, 0, 0) + 24].reshape(12, 2) for s in 'RL'}
res.success = True; res.message = 'LP optimal'
f = unpack(res.x); print('solver', res.success, res.message)
c[F]['T']['boot_fix'] = {s: np.round(f[s], 2).tolist() for s in 'RL'}; json.dump(c, open(cfgp, 'w'))
R2 = measure()
errs = [round(float(np.hypot(*R2[i][1])), 2) for i in range(12)]
print('sole err after', errs, 'max', max(errs))
sl = [(s, i, np.round(f[s][(i + 1) % 12] - f[s][i], 2).tolist()) for s, i in pairs]
print('nudge steps: fully planted max', max([float(np.abs(np.array(v)).max()) for s_, i, v in sl if full(s_, i)] or [0]),
      '| pivot (heel-only / toe-only) max', max([float(np.abs(np.array(v)).max()) for s_, i, v in sl if not full(s_, i)] or [0]))
print(json.dumps(c[F]['T']['boot_fix']))
