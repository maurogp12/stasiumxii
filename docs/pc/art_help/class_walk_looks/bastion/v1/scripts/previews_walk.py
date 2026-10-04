"""walk_{S,E}.gif (17.144 fps: 60/60/60/60/60/50 ms x2 = 700 ms per 12-frame cycle, on neutral gray) and
compare_f00_f06_vs_target.png (S and E: f00, f06, approved target fitted like match_metric). usage: previews_walk.py"""
import os, json, numpy as np
from PIL import Image, ImageDraw
import bastion_metric as MM
HERE = os.path.dirname(os.path.abspath(__file__)); V1 = os.path.join(HERE, '..'); FR = os.path.join(V1, 'frames')
ROOT = '/workspace/handoff/class_walk_blockouts/'; MM.PREFIX = 'bastion'
DUR = [60, 60, 60, 60, 60, 50] * 2; BG = (128, 128, 128)
def on_bg(a):
    out = np.zeros(a.shape[:2] + (3,), np.uint8); out[:] = BG; m = a[..., 3] > 0; out[m] = a[..., :3][m]; return Image.fromarray(out)
for F in 'SE':
    ims = [on_bg(np.asarray(Image.open(f'{FR}/bastion_walk_{F}_f{i:02d}.png'))) for i in range(12)]
    ims[0].save(os.path.join(V1, f'walk_{F}.gif'), save_all=True, append_images=ims[1:], duration=DUR, loop=0, disposal=1)
rows = []
for F in 'SE':
    J = json.load(open(ROOT + 'bastion/joints_512.json'))['facings'][f'walk_{F}']; py = int(round(J['f00']['joints']['pelvis'][1]))
    cr, cm = MM.load(FR, F, 0)
    trgb = np.asarray(Image.open(f'{ROOT}targets/bastion_rp_{F}_f00.jpg').convert('RGB')); ta = np.asarray(Image.open(f'{ROOT}targets/bastion_rp_{F}_f00_alpha.png').convert('L')) > 127
    _, s, tx, ty = MM.fit(trgb, ta, cm, py); tr, tm = MM.place(trgb, ta, s, tx, ty)
    t = np.dstack([tr, tm * 255]).astype(np.uint8)
    cells = [np.asarray(Image.open(f'{FR}/bastion_walk_{F}_f{i:02d}.png')) for i in (0, 6)] + [t]
    row = Image.new('RGB', (512 * 3, 380), BG); d = ImageDraw.Draw(row)
    for k, (c, lab) in enumerate(zip(cells, [f'{F} f00', f'{F} f06', f'{F} approved target (fitted)'])):
        row.paste(on_bg(c), (512 * k, 20)); d.text((512 * k + 6, 4), lab, fill=(255, 255, 255))
    rows.append(row)
out = Image.new('RGB', (512 * 3, 380 * 2)); [out.paste(r, (0, 380 * k)) for k, r in enumerate(rows)]
out.save(os.path.join(V1, 'compare_f00_f06_vs_target.png')); print('ok')
