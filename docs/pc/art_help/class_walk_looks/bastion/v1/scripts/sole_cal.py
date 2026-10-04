"""iterate the per-frame support-boot nudge (TCFG boot_fix in cfg_hybrid.json) until every sole is within 1 px of the blockout.
usage: sole_cal.py F [iters]"""
import sys, json, subprocess, os
HERE = os.path.dirname(os.path.abspath(__file__)); F = sys.argv[1]; N = int(sys.argv[2]) if len(sys.argv) > 2 else 3
TMP = '/workspace/scratch/bastion/cal'; PY = '/workspace/.venv/bin/python'
cfgp = os.path.join(HERE, 'cfg_hybrid.json')
for it in range(N):
    subprocess.run([PY, os.path.join(HERE, 'build_hybrid.py'), '--only', F, '--out', TMP], check=True, capture_output=True)
    out = subprocess.run([PY, os.path.join(HERE, 'sole_dbg.py'), F, TMP, TMP + '/sole.png'], check=True, capture_output=True, text=True).stdout
    cfg = json.load(open(cfgp)); fix = cfg[F]['T'].get('boot_fix', [[0, 0] for _ in range(12)])
    errs = []
    for line in out.strip().split('\n'):
        i = int(line.split()[0]); d = eval(line.split(' d ')[1]); errs.append(d)
        fix[i] = [round(fix[i][0] - d[0] * 0.9, 1), round(fix[i][1] - d[1] * 0.9, 1)]
    print(it, [tuple(e) for e in errs])
    if all(abs(e[0]) <= 1 and abs(e[1]) <= 1 for e in errs): break
    cfg[F]['T']['boot_fix'] = fix; json.dump(cfg, open(cfgp, 'w'))
print('fix', fix)
