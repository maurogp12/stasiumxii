"""global foot offset (foot_o: along heel->toe, along the normal) so the painted support sole sits on the clay sole:
least squares over the 12 support frames, iterated (render + sole_dbg). usage: foot_solve.py F [iters]"""
import sys, json, os, subprocess, numpy as np
from kcommon import *
F = sys.argv[1]; it = int(sys.argv[2]) if len(sys.argv) > 2 else 3; TMP = f'/workspace/scratch/k2/cal_{F}'; os.makedirs(TMP, exist_ok=True)
PY = '/workspace/.venv/bin/python'; cfgp = os.path.join(HERE, 'kcfg.json')
for k in range(it):
    subprocess.run([PY, os.path.join(HERE, 'kbuild.py'), '--only', F, '--out', TMP], check=True, capture_output=True)
    out = subprocess.run([PY, os.path.join(HERE, 'sole_dbg.py'), F, TMP], check=True, capture_output=True, text=True).stdout.strip().split('\n')
    W = frames(F); du, dn, E = [], [], []
    for line in out:
        i = int(line.split()[0]); sup = line.split()[1]; d = np.array(eval(line.split(' d ')[1]), float)
        u = unit(jnt(W[i], sup + '_toe') - jnt(W[i], sup + '_heel')); n = np.array([-u[1], u[0]])
        du.append(d @ u); dn.append(d @ n); E.append(float(np.hypot(*d)))
    c = json.load(open(cfgp)) if os.path.exists(cfgp) else {}; c.setdefault(F, {})
    o = np.array(c[F].get('foot_o', [0.0, 0.0]), float) - np.array([np.mean(du), np.mean(dn)])
    print(k, 'err', np.round(E, 2).tolist(), '-> foot_o', np.round(o, 2).tolist())
    c[F]['foot_o'] = np.round(o, 2).tolist(); json.dump(c, open(cfgp, 'w'), indent=1)
