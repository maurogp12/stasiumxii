import sys, json, subprocess
F, sd, i = sys.argv[1], sys.argv[2], int(sys.argv[3]); vals = [float(v) for v in sys.argv[4].split(',')]; what = sys.argv[5] if len(sys.argv) > 5 else 'rot'
PY = '/workspace/.venv/bin/python'; D = '/workspace/scratch/k3/try'; cp = 'kcfg.json'; base = json.load(open(cp))
for v in vals:
    c = json.loads(json.dumps(base)); f = c[F]
    if what == 'rot':
        r = f.setdefault('foot_rot', {'R': [0.0] * 12, 'L': [0.0] * 12}); r[sd][i] = v
    else:
        x, y = [float(t) for t in what.split(':')] if ':' in what else (0, 0)
        fx = f.setdefault('foot_fix', {'R': [[0, 0]] * 12, 'L': [[0, 0]] * 12}); fx[sd][i] = [v, y] if what.startswith('x') else [x, v]
    json.dump(c, open(cp, 'w'), indent=1)
    subprocess.run([PY, 'kbuild.py', '--only', F, '--frames', str(i), '--out', D], check=True, capture_output=True)
    o = subprocess.run([PY, 'sole_dbg.py', F, D], check=True, capture_output=True, text=True).stdout.split('\n')[i]
    print(v, o)
json.dump(base, open(cp, 'w'), indent=1)
