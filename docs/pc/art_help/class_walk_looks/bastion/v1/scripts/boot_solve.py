"""solve the constant sabaton world offset (boot_w: painted heel - heel joint) that best puts the painted support sole on the
blockout sole (least squares over the 12 frames, linear in the offset), write it to cfg_hybrid.json. usage: boot_solve.py F"""
import sys, json, subprocess, os, numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); F = sys.argv[1]; PY = '/workspace/.venv/bin/python'
TMP = '/workspace/scratch/bastion/cal'; cfgp = os.path.join(HERE, 'cfg_hybrid.json')
J = json.load(open('/workspace/handoff/class_walk_blockouts/bastion/joints_512.json'))['facings'][f'walk_{F}']
def run():
    subprocess.run([PY, os.path.join(HERE, 'build_hybrid.py'), '--only', F, '--out', TMP], check=True, capture_output=True)
    out = subprocess.run([PY, os.path.join(HERE, 'sole_dbg.py'), F, TMP, TMP + '/sole.png'], check=True, capture_output=True, text=True).stdout
    E, A = [], []
    for line in out.strip().split('\n'):
        i = int(line.split()[0]); sup = line.split()[1]; d = eval(line.split(' d ')[1]); E += [d[0], d[1]]
        j = J[f'f{i:02d}']['joints']; u = np.subtract(j[f'{sup}_toe'], j[f'{sup}_heel']); u = u / np.linalg.norm(u); n = np.array([-u[1], u[0]])
        A += [[u[0], n[0]], [u[1], n[1]]]
    return np.array(E, float), np.array(A)
for it in range(int(sys.argv[2]) if len(sys.argv) > 2 else 2):
    E, A = run(); x, *_ = np.linalg.lstsq(A, -E, rcond=None)
    c = json.load(open(cfgp)); bo = c[F]['C']['boot_o']
    print(it, 'max err', round(float(np.abs(E).max()), 2), 'per-frame', [tuple(np.round(E[k:k + 2], 1)) for k in range(0, 24, 2)], 'step', np.round(x, 2))
    for s in 'RL': bo[s] = [round(bo[s][0] + float(x[0]), 2), round(bo[s][1] + float(x[1]), 2)]
    json.dump(c, open(cfgp, 'w'))
E, A = run(); print('final', [tuple(np.round(E[k:k + 2], 1)) for k in range(0, 24, 2)], json.load(open(cfgp))[F]['C']['boot_o'])
