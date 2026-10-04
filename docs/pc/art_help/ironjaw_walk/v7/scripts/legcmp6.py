import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
out, fac = sys.argv[1], sys.argv[2]; frames = [int(x) for x in sys.argv[3].split(',')]; items = sys.argv[4:]
FNT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13); BG = (120, 120, 120, 255)
rows = []
for fi in frames:
    tl = []
    for it in items:
        lab, d = it.split(':', 1); im = Image.open(f'{d}/ironjaw_walk_{fac}_f{fi:02d}.png').convert('RGBA')
        a = np.asarray(im)[..., 3] > 0; ys, xs = np.nonzero(a); y1 = ys.max(); y0 = y1 - 95; cx = int(np.median(xs[ys > y0]))
        c = im.crop((cx - 70, y0, cx + 70, y1 + 4)); t = Image.new('RGBA', c.size, BG); t.alpha_composite(c)
        t = t.resize((t.width * 3, t.height * 3), Image.LANCZOS); ImageDraw.Draw(t).text((4, 3), f'{lab} f{fi:02d}', fill=(255, 255, 0), font=FNT); tl.append(t)
    r = Image.new('RGBA', (sum(t.width + 6 for t in tl), tl[0].height), (30, 30, 30, 255)); x = 0
    for t in tl: r.paste(t, (x, 0)); x += t.width + 6
    rows.append(r)
M = Image.new('RGBA', (max(r.width for r in rows), sum(r.height + 6 for r in rows)), (30, 30, 30, 255)); y = 0
for r in rows: M.paste(r, (0, y)); y += r.height + 6
M.convert('RGB').save(out)
