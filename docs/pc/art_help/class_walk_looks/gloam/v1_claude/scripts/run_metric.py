"""Score the v3 frames with the Bastion metric (bastion/v2/scripts/bastion_metric.py, unchanged) on the Gloam blockout (S v3.1 42d8d7cc, E v3 ffbfe3a9).
The S target alpha file is an RGBA cut-out (its alpha channel is the mask) and the metric reads --target_alpha with
.convert('L'), which would read the painting instead; so a binary L copy of each mask is written to a temp dir first.
Also writes the support-sole error as a vector per frame (cand - clay, px) next to the metric json.
usage: run_metric.py [frames_dir] [out_dir]"""
import os, sys, json, subprocess, tempfile, numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import grig
LOOKS = os.path.join(grig.REPO, 'docs/pc/art_help/class_walk_looks/')
MET = LOOKS + 'bastion/v2/scripts/bastion_metric.py'
cand = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'frames')
out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, '..')
tmp = tempfile.mkdtemp()
for F in 'SE':
    a = Image.open(f'{LOOKS}targets/gloam_rp_{F}_f00_alpha.png')
    m = np.asarray(a)[..., 3] if a.mode == 'RGBA' else np.asarray(a.convert('L'))
    ta = os.path.join(tmp, f'alpha_{F}.png'); Image.fromarray(((m > 127) * 255).astype(np.uint8)).save(ta)
    cmd = [sys.executable, MET, '--prefix', 'gloam', '--facing', F, '--cand', cand, '--v2', grig.bd(F) + 'clay',
           '--target', f'{LOOKS}targets/gloam_rp_{F}_f00.jpg', '--target_alpha', ta,
           '--idle', f'{grig.bd(F)}clay/gloam_idle_{F}_f00.png', '--joints', grig.bd(F) + 'joints_512.json',
           '--out', os.path.join(out, f'metric_{F}.json')]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
    r = json.load(open(os.path.join(out, f'metric_{F}.json')))
    print(F, {k: r[k] for k in ('look_score', 'ssim_upper', 'ssim_lower', 'iou', 'palette', 'height_vs_idle', 'bob_err', 'motion_score', 'PASS')})
    print('  sole_err', r['sole_err'])
