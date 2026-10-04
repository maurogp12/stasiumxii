"""Ironjaw actions v1 - score idle f00 with the walk's own metric: match_metric.py (claude/ironjaw-walk-help-reply,
unchanged), the metric the v7 walk was scored with (score6.sh: S target rp_S_f00_t1.jpg, E target rp_E_f00_t1.jpg,
--idle = the approved idle set hd_set_idle/ironjaw_idle_{F}_f00.png).
match_metric reads <dir>/ironjaw_walk_{F}_fNN.png and the joints file's walk_{F} entry, so the 12 idle frames and the idle
blockout clay are linked under those names in a temp dir and walk_{F} is the idle_{F} blockout entry. Look = idle f00
against the approved target; the metric's motion part compares the idle with its own clay (support sole and bob).
Also written, for information: the same look score against the walk's own targets (rp_S_turn_t1 / rp_E_stride_t2).
usage: run_metric.py [frames_dir] [out_dir]"""
import os, sys, json, subprocess, tempfile, shutil
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..')
sys.path.insert(0, HERE)
import ijcut                                   # source tree (IJ_SRC) with match_metric.py, targets and the idle set
R = ijcut.R
MET = R + 'claude/scripts/match_metric.py'
BLK = os.path.join(ROOT, 'blockout')
cand = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'frames')
out = sys.argv[2] if len(sys.argv) > 2 else ROOT
J = json.load(open(f'{BLK}/joints_actions_512.json'))
tmp = tempfile.mkdtemp(prefix='ij_act_metric_'); res = {}
TG = {'S': ('repaint_targets/rp_S_f00_t1.jpg', 'v7/targets/rp_S_turn_t1.jpg'), 'E': ('repaint_targets/rp_E_f00_t1.jpg', 'v7/targets/rp_E_stride_t2.jpg')}
try:
    for F in 'SE':
        cd, vd = os.path.join(tmp, f'c{F}'), os.path.join(tmp, f'v{F}'); os.makedirs(cd); os.makedirs(vd)
        for i in range(12):
            os.symlink(os.path.abspath(f'{cand}/idle_{F}_f{i:02d}.png'), f'{cd}/ironjaw_walk_{F}_f{i:02d}.png')
            os.symlink(os.path.abspath(f'{BLK}/clay/ironjaw_idle_{F}_f{i:02d}.png'), f'{vd}/ironjaw_walk_{F}_f{i:02d}.png')
        jj = {'meta': J['meta'], 'facings': {f'walk_{F}': J['facings'][f'idle_{F}']}}
        jp = os.path.join(tmp, f'joints_{F}.json'); json.dump(jj, open(jp, 'w'))
        for tag, tg in (('', TG[F][0]), ('_vs_walk_target', TG[F][1])):
            o = os.path.join(out, f'metric_idle_{F}{tag}.json')
            cmd = [sys.executable, MET, '--facing', F, '--cand', cd, '--v2', vd, '--target', R + tg,
                   '--idle', R + f'hd_set_idle/ironjaw_idle_{F}_f00.png', '--joints', jp, '--out', o]
            subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
            r = json.load(open(o)); r['target'] = tg; json.dump(r, open(o, 'w'), indent=1); res[F + tag] = r
            print(F + tag, {k: r[k] for k in ('look_score', 'ssim_upper', 'ssim_lower', 'iou', 'palette', 'height_vs_idle', 'bob_err', 'motion_score', 'PASS')})
finally:
    shutil.rmtree(tmp, ignore_errors=True)
