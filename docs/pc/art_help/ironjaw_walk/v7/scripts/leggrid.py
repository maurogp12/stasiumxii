"""leggrid.py OUT F frames label=dir ...  -> rows = frames, cols = idle legs + variants (legs zoomed 3x)"""
import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, '/workspace/scratch/ij_walk/v7'); import legval as LV
FNT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 12); BG = (120, 120, 120, 255)
out, F = sys.argv[1], sys.argv[2]; frames = [int(x) for x in sys.argv[3].split(',')]; items = [a.split('=', 1) for a in sys.argv[4:]]
def legs(im, lab, sc=3):
    a = np.asarray(im)[..., 3] > 0; ys, xs = np.nonzero(a); y1 = ys.max(); y0 = y1 - 100; cx = int(np.median(xs[ys > y0]))
    c = im.crop((cx - 62, y0, cx + 62, y1 + 4)); t = Image.new('RGBA', c.size, BG); t.alpha_composite(c); t = t.resize((t.width * sc, t.height * sc), Image.LANCZOS)
    ImageDraw.Draw(t).text((3, 3), lab, fill=(255, 255, 0), font=FNT); return t
idle = legs(Image.fromarray(LV.idle_legs(F)[0]), f'idle {F}')
rows = []
for fi in frames:
    tl = [idle] + [legs(Image.open(f'{d}/ironjaw_walk_{F}_f{fi:02d}.png').convert('RGBA'), f'{n} f{fi:02d}') for n, d in items]
    r = Image.new('RGBA', (sum(t.width + 4 for t in tl), tl[0].height), (30, 30, 30, 255)); x = 0
    for t in tl: r.paste(t, (x, 0)); x += t.width + 4
    rows.append(r)
M = Image.new('RGBA', (rows[0].width, sum(r.height + 4 for r in rows)), (30, 30, 30, 255)); y = 0
for r in rows: M.paste(r, (0, y)); y += r.height + 4
M.convert('RGB').save(out)
