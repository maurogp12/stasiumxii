"""Cut E leg pieces (thigh / greave / boot) from Luca's stride repaint rp_E_stride_t2.jpg.
Pieces are saved upright (hip/knee axis vertical) in the legs_v4 sheet format: RGBA, 6 px transparent pad.
Crimson cape strands overlapping a piece are removed and the hole is inpainted from that piece's own steel."""
import sys, json, numpy as np, cv2
from PIL import Image
from scipy import ndimage as ndi
sys.path.insert(0, '/workspace/handoff/ironjaw_walk_claude/claude_reply/scripts'); from cut import cut_target
sys.path.insert(0, '/workspace/scratch/ij_walk/v5'); from layers5 import inpaint_fill, poly
T = '/workspace/scratch/ij_walk/repaint_E2/rp_E_stride_t2.jpg'; OUT = '/workspace/scratch/ij_walk/v6/legs_t2/'
import os; os.makedirs(OUT, exist_ok=True)
rgb, al, bg = cut_target(T); H = rgb.shape[:2]
lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(int); a_, b_ = lab[..., 1] - 128, lab[..., 2] - 128
red = (a_ > 6) & (a_ > b_ * 1.2); red = cv2.morphologyEx(red.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)) > 0
red = ndi.binary_dilation(red, iterations=1) & al
P = json.load(open('/workspace/scratch/ij_walk/v6/legs_t2_polys.json'))
info = {}
for nm, spec in P.items():
    m = poly(H, spec['poly']) & al
    hole = m & red
    keep = m & ~red
    img = inpaint_fill(rgb, keep, hole, r=4) if hole.any() else rgb
    a = m.astype(np.uint8) * 255
    rgba = np.dstack([img, a])
    ang = spec.get('rot_deg', 0.0)
    ys, xs = np.nonzero(m); y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    crop = rgba[y0:y1 + 1, x0:x1 + 1]
    if ang:
        im = Image.fromarray(crop, 'RGBA'); im = im.rotate(ang, resample=Image.BICUBIC, expand=True)
        crop = np.asarray(im).copy(); crop[..., 3] = np.where(crop[..., 3] > 127, 255, 0)
        yy, xx = np.nonzero(crop[..., 3]); crop = crop[yy.min():yy.max() + 1, xx.min():xx.max() + 1]
    pad = np.zeros((crop.shape[0] + 12, crop.shape[1] + 12, 4), np.uint8); pad[6:-6, 6:-6] = crop
    pad[pad[..., 3] == 0] = 0
    Image.fromarray(pad, 'RGBA').save(f'{OUT}E_{nm}.png')
    info[nm] = dict(bbox=[int(x0), int(y0), int(x1), int(y1)], size=list(pad.shape[:2]), red_px_inpainted=int(hole.sum()), rot_deg=ang)
json.dump(info, open(f'{OUT}seg_info.json', 'w'), indent=1); print(json.dumps(info))
