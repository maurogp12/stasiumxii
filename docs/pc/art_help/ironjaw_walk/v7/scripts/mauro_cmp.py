"""walk frame next to the approved idle, full figure + legs zoomed 3x.  mauro_cmp.py OUT FACINGS FRAME label=dir [label=dir ...]"""
import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, '/workspace/scratch/ij_walk/v7'); import legval as LV
FNT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13); BG = (120, 120, 120, 255)
out, facs, fi = sys.argv[1], sys.argv[2], int(sys.argv[3]); items = [a.split('=', 1) for a in sys.argv[4:]]
def tile(im, lab, Lp, j=None):
    a = np.asarray(im)[..., 3] > 0; ys, xs = np.nonzero(a)
    full = im.crop((xs.min() - 3, ys.min() - 3, xs.max() + 4, ys.max() + 4)); f = Image.new('RGBA', full.size, BG); f.alpha_composite(full)
    f = f.resize((f.width * 2, f.height * 2), Image.LANCZOS)
    y1 = ys.max(); y0 = y1 - 125; cx = int(np.median(xs[ys > y1 - 60])) if j is None else int(round((j['R_ankle'][0] + j['L_ankle'][0]) / 2))
    leg = im.crop((cx - 100, y0, cx + 100, y1 + 4)); l = Image.new('RGBA', leg.size, BG); l.alpha_composite(leg); l = l.resize((l.width * 3, l.height * 3), Image.LANCZOS)
    H = max(f.height, l.height) + 24; t = Image.new('RGBA', (f.width + l.width + 10, H), (40, 40, 40, 255)); t.paste(f, (0, 24)); t.paste(l, (f.width + 10, 24))
    ImageDraw.Draw(t).text((4, 4), f'{lab}   leg L* p95 {Lp:.1f}', fill=(255, 255, 0), font=FNT); return t
rows = []
for F in facs:
    im, m, lab = LV.idle_legs(F); tl = [tile(Image.fromarray(im), f'APPROVED idle {F} f00  (leg L* p95, box mask)', LV.p95(lab, m))]
    for nm, d in items:
        p = f'{d}/ironjaw_walk_{F}_f{fi:02d}.png'; w, mw, lw = LV.walk_legs(p, F, fi)
        tl.append(tile(Image.open(p).convert('RGBA'), f'{nm} walk {F} f{fi:02d}  (leg L* p95, TA-capsule mask)', LV.p95(lw, mw) if mw.any() else float('nan'), LV.J[f'walk_{F}'][f'f{fi:02d}']['joints']))
    r = Image.new('RGBA', (sum(t.width + 12 for t in tl), max(t.height for t in tl)), (40, 40, 40, 255)); x = 0
    for t in tl: r.paste(t, (x, 0)); x += t.width + 12
    rows.append(r)
M = Image.new('RGBA', (max(r.width for r in rows), sum(r.height + 8 for r in rows)), (40, 40, 40, 255)); y = 0
for r in rows: M.paste(r, (0, y)); y += r.height + 8
M.convert('RGB').save(out)
