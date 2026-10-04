"""per-frame lower-cape length (cape_low_k list): the longest cape (closest to the approved target) whose hem stays
>= CLEAR px above the blockout support sole in every frame, changing by <= STEP per frame (cloth, not popping).
usage: cape_k_solve.py F [clear=9] [step=0.015]"""
import sys, json, subprocess, os, numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); F = sys.argv[1]
CLEAR = float(sys.argv[2]) if len(sys.argv) > 2 else 9; STEP = float(sys.argv[3]) if len(sys.argv) > 3 else 0.015
PY = '/workspace/.venv/bin/python'; cfgp = os.path.join(HERE, 'cfg_hybrid.json')
def hem(kv):
    out = subprocess.run([PY, os.path.join(HERE, 'hem_check.py'), F, json.dumps({'cape_low_k': kv})], capture_output=True, text=True, check=True).stdout
    return json.loads(out.strip().split('\n')[-2])
k = [1.0] * 12
for it in range(4):
    H = hem(k); req = []
    for o, kk in zip(H, k):
        # lower panel from the pelvis row (~212) to the hem: linear in k
        L = o['hem'] - 212.0; need = o['hem'] - (o['sole'] - CLEAR)
        req.append(min(1.0, kk * (L - max(0, need)) / L) if need > 0 else kk)
    k = [min(req[j] + STEP * min(abs(f - j), 12 - abs(f - j)) for j in range(12)) for f in range(12)]
    print(it, 'clear', [o['clear'] for o in H], 'k', [round(v, 3) for v in k])
H = hem(k); print('final clear', [o['clear'] for o in H], 'min', min(o['clear'] for o in H))
c = json.load(open(cfgp)); c[F]['T']['cape_low_k'] = [round(v, 3) for v in k]; json.dump(c, open(cfgp, 'w'))
