import sys; sys.path.insert(0, '/workspace/scratch/wp10a_joins')
import numpy as np, cv2, json
from scipy.ndimage import binary_fill_holes
import wp10a_props as P
from wp10a_common import load_raw, save_rgba
RAW = '/workspace/stasium-pc-look/raw/wp10a_joins/'
rep_all = {}
for n in ['stone_ford', 'cliff_pass_steps', 'sign_rowanvale', 'sign_windmere']:
    rgb = load_raw(RAW + n + '.png')
    rep = {}
    cut, rep = P.key_background(rgb, 'white', 'hybrid', rep, shadow_cut=False)
    cut = P.clean_components(cut, rep)
    a = cut[..., 3]
    filled = binary_fill_holes(a > 0.5)
    holes = filled & (a < 0.98)
    # enclosed white (snow caps on white bg): restore the painted colour fully opaque
    cut[..., 3] = np.where(holes, 1.0, a)
    cut[..., :3] = np.where(holes[..., None], rgb, cut[..., :3])
    rep['holes_filled_px'] = int(holes.sum())
    save_rgba(f'src/{n}_cut.png', cut)
    rep_all[n] = {k: v for k, v in rep.items() if not k.startswith('_')}
    print(n, rep_all[n].get('rembg_rescued_px'), rep['holes_filled_px'], rep_all[n].get('warnings'))
json.dump(rep_all, open('src/cut_report.json', 'w'), indent=1, default=float)
