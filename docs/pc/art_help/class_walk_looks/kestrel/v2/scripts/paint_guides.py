"""Track B paint guides: full-figure composites (target upper body + the sheet-B legs) on flat grey 172, ~1024 px tall, for the
keys f00/f03/f06/f09, S and E -> paint_guides/{S,E}_fNN.png (+ _joints.json: leg joints in that image's px).
Reads the RS=4 composites legs_sheet_b.py leaves in /tmp/legs_b_imgs.npz.  usage: paint_guides.py [out_dir]"""
import sys, os, json, numpy as np, cv2
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kbuild as KB
from kcommon import *
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'paint_guides'); OH = 1024; GREY = 172; HI = 4
Z = np.load('/tmp/legs_b_imgs.npz'); os.makedirs(OUT, exist_ok=True); KB.RS = 1
for F in 'SE':
    KB.load_layers(F)
    for i in (0, 3, 6, 9):
        im = Z[f'{F}_{i}_full'].astype(np.float32) / 255.; a = im[..., 3:]
        ys, xs = np.nonzero(a[..., 0] > 0.02); p = int((ys.max() - ys.min()) * 0.03)
        y0, y1, x0, x1 = max(ys.min() - p, 0), min(ys.max() + p, im.shape[0]), max(xs.min() - p, 0), min(xs.max() + p, im.shape[1])
        k = OH / (y1 - y0); c = im[y0:y1, x0:x1]; pm = np.dstack([c[..., :3] * c[..., 3:], c[..., 3:]])
        pm = cv2.resize(pm, (int(round((x1 - x0) * k)), OH), interpolation=cv2.INTER_AREA if k < 1 else cv2.INTER_CUBIC)
        out = pm[..., :3] + (1 - pm[..., 3:]) * GREY / 255.
        Image.fromarray(np.clip(out * 255 + .5, 0, 255).astype(np.uint8)).save(f'{OUT}/{F}_f{i:02d}.png')
        sc = HI * k; off = (-x0 * k, -y0 * k); J = {}
        for sd in 'RL':
            g = KB.leg_geo(F, i, sd); A = KB.anchors(F)
            for nm, v in (('hip', g['hip']), ('knee', g['kn']), ('ankle', g['an']), ('heel', KB.apm(g['Mf'], A['heel'])), ('toe', KB.apm(g['Mf'], A['toe']))):
                J[f'{sd}_{nm}'] = [round(float(v[0]) * sc + off[0], 1), round(float(v[1]) * sc + off[1], 1)]
        json.dump(dict(size=[out.shape[1], OH], grey=GREY, joints=J, cell_to_img=dict(scale=sc, offset=off)), open(f'{OUT}/{F}_f{i:02d}_joints.json', 'w'), indent=1)
        print(F, i, out.shape)
