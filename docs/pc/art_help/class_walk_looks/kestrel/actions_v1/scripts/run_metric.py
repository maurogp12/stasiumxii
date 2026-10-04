"""Score the idle (f00 look) with the same metric as the walk: v3_claude/scripts/run_metric.py runs
bastion/v2/scripts/bastion_metric.py (unchanged) on <prefix>_walk_{F}_fNN.png frames. Here the 12 idle frames and the idle
blockout clay are linked under those names in a temp dir and the joints file's walk_{F} entry is the idle_{F} entry, so the
metric's look (fit on f00, ssim, iou, palette, height) is the idle f00 against the same approved target, binary target
alpha copy as in the walk. The metric's motion part compares the idle with its own clay (support sole and bob).
usage: run_metric.py [frames_dir] [out_dir]"""
import os, sys, json, subprocess, tempfile, numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
LOOKS = os.path.abspath(os.path.join(HERE, '../../..')) + '/'
MET = LOOKS + 'bastion/v2/scripts/bastion_metric.py'
BLK = os.path.join(ROOT, 'blockout')
cand = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'frames')
out = sys.argv[2] if len(sys.argv) > 2 else ROOT
J = json.load(open(f'{BLK}/joints_actions_512.json'))
tmp = tempfile.mkdtemp(); res = {}
for F in 'SE':
    cd, vd = os.path.join(tmp, f'c{F}'), os.path.join(tmp, f'v{F}'); os.makedirs(cd); os.makedirs(vd)
    for i in range(12):
        os.symlink(os.path.abspath(f'{cand}/idle_{F}_f{i:02d}.png'), f'{cd}/kestrel_walk_{F}_f{i:02d}.png')
        os.symlink(os.path.abspath(f'{BLK}/clay/kestrel_idle_{F}_f{i:02d}.png'), f'{vd}/kestrel_walk_{F}_f{i:02d}.png')
    jj = {'meta': J['meta'], 'facings': {f'walk_{F}': J['facings'][f'idle_{F}']}}
    jp = os.path.join(tmp, f'joints_{F}.json'); json.dump(jj, open(jp, 'w'))
    a = Image.open(f'{LOOKS}targets/kestrel_rp_{F}_f00_alpha.png')
    m = np.asarray(a)[..., 3] if a.mode == 'RGBA' else np.asarray(a.convert('L'))
    ta = os.path.join(tmp, f'alpha_{F}.png'); Image.fromarray(((m > 127) * 255).astype(np.uint8)).save(ta)
    cmd = [sys.executable, MET, '--prefix', 'kestrel', '--facing', F, '--cand', cd, '--v2', vd,
           '--target', f'{LOOKS}targets/kestrel_rp_{F}_f00.jpg', '--target_alpha', ta,
           '--idle', f'{BLK}/clay/kestrel_idle_{F}_f00.png', '--joints', jp, '--out', os.path.join(out, f'metric_idle_{F}.json')]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
    r = json.load(open(os.path.join(out, f'metric_idle_{F}.json'))); res[F] = r
    print(F, {k: r[k] for k in ('look_score', 'ssim_upper', 'ssim_lower', 'iou', 'palette', 'height_vs_idle', 'bob_err', 'motion_score', 'PASS')})
    print('  look_hold_upper', r['look_hold_upper'])
