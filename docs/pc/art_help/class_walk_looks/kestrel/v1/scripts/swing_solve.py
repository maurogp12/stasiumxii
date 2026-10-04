"""swing_drop: in swing frames (no heel/toe planted) lower the foot and the IK ankle so the visible heel/toe contact is no
higher above its ground track than the blockout's (floor 1 px so the toe never scuffs). Frames where that leg is the
metric's support leg (lower blockout ankle) are left alone: there the visible sole already matches the blockout's. usage: swing_solve.py [iters]  (the toe-off part of mauro_checks reads the last render in /workspace/scratch/k2/try)"""
import sys, os, json, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kcommon import frames
HERE = os.path.dirname(os.path.abspath(__file__)); PY = sys.executable; CF = os.path.join(HERE, 'kcfg.json'); TMP = '/tmp/kswing.json'
for it in range(int(sys.argv[1]) if len(sys.argv) > 1 else 3):
    subprocess.run([PY, os.path.join(HERE, 'mauro_checks.py'), TMP, '/workspace/scratch/k2/try'], check=True, capture_output=True)
    r = json.load(open(TMP)); c = json.load(open(CF)); mx = 0
    for F in 'SE':
        sd_ = c[F].setdefault('swing_drop', {'R': [0.0] * 12, 'L': [0.0] * 12})
        for sd in 'RL':
            L = r[F]['swing_lift'][sd]
            for j in L['swing_frames']:
                jj = frames(F)[j]['joints']; sup = 'R' if jj['R_ankle'][1] >= jj['L_ankle'][1] else 'L'
                if sup == sd: sd_[sd][j] = 0.0; continue
                e = L['cand'][j] - max(L['clay'][j], 1.0)
                if e > 0.05 or (e < -0.05 and sd_[sd][j] > 0): sd_[sd][j] = round(max(0.0, sd_[sd][j] + e), 2); mx = max(mx, abs(e))
    json.dump(c, open(CF, 'w'), indent=1); print(it, 'max adj', round(mx, 2), {F: c[F]['swing_drop'] for F in 'SE'})
