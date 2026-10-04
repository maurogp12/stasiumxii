"""lowgrid.py OUT F frames dir [sc]  lower body (belt->soles) of several frames, one row"""
import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
out, F, frames, d = sys.argv[1], sys.argv[2], [int(x) for x in sys.argv[3].split(',')], sys.argv[4]; sc = float(sys.argv[5]) if len(sys.argv) > 5 else 2.5
FNT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 12); tl = []
for fi in frames:
    im = Image.open(f'{d}/ironjaw_walk_{F}_f{fi:02d}.png').convert('RGBA'); a = np.asarray(im)[..., 3] > 0; ys, xs = np.nonzero(a); y1 = ys.max()
    c = im.crop((150, y1 - 125, 380, y1 + 4)); t = Image.new('RGBA', c.size, (120, 120, 120, 255)); t.alpha_composite(c)
    t = t.resize((int(t.width * sc), int(t.height * sc)), Image.LANCZOS); ImageDraw.Draw(t).text((3, 3), f'f{fi:02d}', fill=(255, 255, 0), font=FNT); tl.append(t)
M = Image.new('RGB', (sum(t.width + 4 for t in tl), tl[0].height), (30, 30, 30)); x = 0
for t in tl: M.paste(t.convert('RGB'), (x, 0)); x += t.width + 4
M.save(out)
