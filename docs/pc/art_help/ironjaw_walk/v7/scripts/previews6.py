import numpy as np
from PIL import Image, ImageDraw, ImageFont
V3 = '/workspace/art/ironjaw_full/v4_hd/_v6'; ROOT = '/workspace/art/ironjaw_full/v4_hd/_v7'; T = f'{ROOT}/_test'
DUR = [60, 60, 60, 60, 60, 50, 60, 60, 60, 60, 60, 50]; BG = (0x6b, 0x68, 0x60)
try: FNT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 14)
except Exception: FNT = ImageFont.load_default()
def fr(F, i, tag='rim', root=ROOT):
    d = f'{root}/walk' if tag == 'rim' else f'{root}/_norim/walk'
    return Image.open(f'{d}/ironjaw_walk_{F}_f{i:02d}.png').convert('RGBA')
def on(bg, im):
    c = Image.new('RGBA', im.size, bg + (255,)); c.alpha_composite(im); return c
for F in 'SE':
    ims = [on(BG, fr(F, i)).convert('RGB') for i in range(12)]
    pal = ims[0].quantize(colors=255, method=Image.MEDIANCUT, kmeans=1)
    q = [im.quantize(palette=pal, dither=Image.FLOYDSTEINBERG) for im in ims]
    q[0].save(f'{T}/walk_{F}.gif', save_all=True, append_images=q[1:], duration=DUR, loop=0, disposal=1, optimize=False)
S30 = 0.30; NCYC = 3; NF = 12 * NCYC; TILE_W = 64 / S30
def panel(F, n):
    dx, dy = (12, 6) if F == 'S' else (12, -6)
    W = 512 + dx * NF; H = 360 + abs(dy) * NF; oy0 = 0 if dy > 0 else abs(dy) * NF
    c = Image.new('RGBA', (W, H), (0x7a, 0x9a, 0x5a, 255)); d = ImageDraw.Draw(c); px, py = 256, 329 + oy0
    for k in range(-30, 31):
        for sgn in (1, -1):
            x0 = px + k * TILE_W; d.line([(x0 - 3000, py - sgn * 1500), (x0 + 3000, py + sgn * 1500)], fill=(0x6e, 0x8c, 0x50, 255), width=3)
    c.alpha_composite(fr(F, n % 12), (dx * n, oy0 + dy * n)); return c
frames = []
for n in range(NF):
    ps_ = [panel(F, n) for F in 'SE']; ps_ = [p.resize((round(p.width * S30), round(p.height * S30)), Image.LANCZOS) for p in ps_]
    c = Image.new('RGB', (sum(p.width for p in ps_) + 8, max(p.height for p in ps_)), (40, 40, 40)); x = 0
    for p in ps_: c.paste(p.convert('RGB'), (x, 0)); x += p.width + 8
    frames.append(c)
pal = frames[0].quantize(colors=255, method=Image.MEDIANCUT, kmeans=1)
q = [f.quantize(palette=pal, dither=Image.NONE) for f in frames]
q[0].save(f'{T}/walk_game030_SE.gif', save_all=True, append_images=q[1:], duration=DUR * NCYC, loop=0, disposal=1, optimize=False)
def bbox(ims, pad=6):
    a = np.zeros((360, 512), bool)
    for im in ims: a |= np.asarray(im)[..., 3] > 0
    ys, xs = np.nonzero(a); return (max(xs.min() - pad, 0), max(ys.min() - pad, 0), min(xs.max() + pad + 1, 512), min(ys.max() + pad + 1, 360))
SEL = [0, 2, 4, 6, 8, 10]; SC = 0.6; LAB = 14; rows = []
for F in 'SE':
    ims = [fr(F, i) for i in SEL]; bb = bbox(ims); cw, ch = round((bb[2] - bb[0]) * SC), round((bb[3] - bb[1]) * SC)
    R = Image.new('RGB', (cw * len(SEL), ch + LAB), BG); d = ImageDraw.Draw(R)
    for j, (i, im) in enumerate(zip(SEL, ims)):
        R.paste(on(BG, im).crop(bb).resize((cw, ch), Image.LANCZOS).convert('RGB'), (j * cw, LAB)); d.text((j * cw + 3, 1), f'{F} f{i:02d}', fill=(255, 255, 255))
    rows.append(R)
M = Image.new('RGB', (max(r.width for r in rows), sum(r.height for r in rows)), BG); y = 0
for r in rows: M.paste(r, (0, y)); y += r.height
M.save(f'{T}/walk_review_v7.png')
# v3 vs v4 full figures
cells = []
for F in 'SE':
    for i in (0, 6):
        a = fr(F, i, root=V3); b = fr(F, i)
        bb = bbox([a, b]); cells.append((F, i, on(BG, a).crop(bb).convert('RGB'), on(BG, b).crop(bb).convert('RGB')))
cw = max(c[2].width for c in cells); LB = 18
M = Image.new('RGB', (2 * cw + 10, sum(c[2].height + LB for c in cells)), BG); d = ImageDraw.Draw(M); y = 0
for F, i, a, b in cells:
    M.paste(a, (0, y + LB)); M.paste(b, (cw + 10, y + LB))
    d.text((3, y + 2), f'v6  {F} f{i:02d}', fill=(255, 255, 255), font=FNT); d.text((cw + 13, y + 2), f'v7  {F} f{i:02d}', fill=(255, 255, 255), font=FNT)
    d.line([(cw + 4, y), (cw + 4, y + a.height + LB)], fill=(30, 30, 30), width=2); y += a.height + LB
M.save(f'{T}/walk_v6_vs_v7.png')
# leg close-ups v3 vs v4 (norim, 3x): S f00/f04/f06/f10, E f00/f06
specs = [('S', 0), ('S', 6), ('E', 0), ('E', 3), ('E', 4), ('E', 5), ('E', 6), ('E', 9)]
tiles = []
for F, i in specs:
    a = fr(F, i, 'norim', V3); b = fr(F, i, 'norim')
    def legbox(im):
        al = np.asarray(im)[..., 3] > 0; ys, xs = np.nonzero(al); y1 = ys.max(); sel = ys > y1 - 140
        cx = int(np.median(xs[sel])); return (cx - 130, y1 - 140, cx + 130, y1 + 6)
    ta = on(BG, a).crop(legbox(a)).convert('RGB'); tb = on(BG, b).crop(legbox(b)).convert('RGB')
    ta = ta.resize((ta.width * 3, ta.height * 3), Image.LANCZOS); tb = tb.resize((tb.width * 3, tb.height * 3), Image.LANCZOS)
    t = Image.new('RGB', (ta.width * 2 + 8, ta.height + 22), (30, 30, 30)); t.paste(ta, (0, 22)); t.paste(tb, (ta.width + 8, 22))
    dd = ImageDraw.Draw(t); dd.text((4, 3), f'v6 legs  {F} f{i:02d}', fill=(255, 255, 255), font=FNT); dd.text((ta.width + 12, 3), f'v7 legs  {F} f{i:02d}', fill=(255, 255, 255), font=FNT)
    tiles.append(t)
Wd = max(t.width for t in tiles); M = Image.new('RGB', (Wd, sum(t.height + 6 for t in tiles)), (30, 30, 30)); y = 0
for t in tiles: M.paste(t, (0, y)); y += t.height + 6
M.save(f'{T}/walk_legs_v6_vs_v7_closeup.png')
# v4 f00 next to the repaint target (S, E): repaint scaled to the same helm-to-sole height
RP = '/workspace/scratch/ij_walk/repaint/'; V3S = '/workspace/scratch/ij_walk/v3/'
cols = []
for F in 'SE':
    if True:
        import sys; sys.path.insert(0, '/workspace/handoff/ironjaw_walk_claude/claude_reply/scripts'); from cut import cut_target
        _r, _a, _bg = cut_target('/workspace/scratch/ij_walk/repaint_E2/' + ('rp_E_stride_t2.jpg' if F == 'E' else 'rp_S_turn_t1.jpg')); sys.path.insert(0, '/workspace/scratch/ij_walk/v7'); from pockets import find_pockets; _a = _a & ~find_pockets(_r, _a, _bg)[0]; rp = Image.fromarray(_r); m = Image.fromarray(_a.astype(np.uint8) * 255)
    else:
        rp = Image.open(f'{RP}rp_{F}_f00_t1.jpg').convert('RGB'); m = Image.open(f'{V3S}rp_{F}_mask.png').convert('L')
    rgba = rp.copy(); rgba.putalpha(m); bb_r = rgba.getbbox(); rc = on(BG, rgba.crop(bb_r)).convert('RGB')
    v = fr(F, 0, 'norim'); bb = v.getbbox(); vc = on(BG, v.crop(bb)).convert('RGB')
    h = vc.height * 2; rc = rc.resize((round(rc.width * h / rc.height), h), Image.LANCZOS); vc = vc.resize((vc.width * 2, h), Image.LANCZOS)
    c = Image.new('RGB', (rc.width + vc.width + 30, h + 26), BG); c.paste(rc, (10, 24)); c.paste(vc, (rc.width + 20, 24))
    dd = ImageDraw.Draw(c); dd.text((10, 4), (f'repaint target {F} rp_E_stride_t2 (scaled to v7 height)' if F == 'E' else f'repaint target {F} rp_S_turn_t1 (scaled to v7 height)'), fill=(255, 255, 255), font=FNT); dd.text((rc.width + 20, 4), f'v7 {F} f00 (norim, 2x)', fill=(255, 255, 255), font=FNT)
    cols.append(c)
M = Image.new('RGB', (max(c.width for c in cols), sum(c.height for c in cols)), BG); y = 0
for c in cols: M.paste(c, (0, y)); y += c.height
M.save(f'{T}/walk_vs_repaint_f00.png')
# E: v6 (old target) vs v7 (new stride target) vs both targets
import sys; sys.path.insert(0, '/workspace/handoff/ironjaw_walk_claude/claude_reply/scripts'); from cut import cut_target
sys.path.insert(0, '/workspace/scratch/ij_walk/v7'); from pockets import find_pockets
for FF, OLDT, NEWT, NL in (('E', 'rp_E_f00_t1', 'rp_E_stride_t2', 'walk_E_targets_v6_v7.png'), ('S', 'rp_S_f00_t1', 'rp_S_turn_t1', 'walk_S_targets_v6_v7.png')):
  tiles = []
  for lab, kind, p in ((f'old target {OLDT}', 't', f'/workspace/scratch/ij_walk/repaint/{OLDT}.jpg'), (f'v6 {FF} f00', 'f', V3), (f'new target {NEWT}', 't', f'/workspace/scratch/ij_walk/repaint_E2/{NEWT}.jpg'), (f'v7 {FF} f00', 'f', ROOT)):
      if kind == 't':
          r_, a_, bg_ = cut_target(p); a_ = a_ & ~find_pockets(r_, a_, bg_)[0]; im = Image.fromarray(np.dstack([r_, a_.astype(np.uint8) * 255]), 'RGBA')
      else:
          im = fr(FF, 0, 'norim', p)
      im = im.crop(im.getbbox()); tiles.append((lab, im))
  H = 420; tiles = [(l, i.resize((round(i.width * H / i.height), H), Image.LANCZOS)) for l, i in tiles]
  M = Image.new('RGB', (sum(i.width for _, i in tiles) + 15 * len(tiles), H + 24), BG); d = ImageDraw.Draw(M); x = 0
  for l, i in tiles: M.paste(on(BG, i).convert('RGB'), (x, 24)); d.text((x + 4, 4), l, fill=(255, 255, 255), font=FNT); x += i.width + 15
  M.save(f'{T}/{NL}')

print('ok')
