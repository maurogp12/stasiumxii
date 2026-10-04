import json, numpy as np
from PIL import Image, ImageDraw
ROOT = '/workspace/art/ironjaw_full/v4_hd'; T = f'{ROOT}/_test'
GUIDE = '/workspace/art_src/blockout/ironjaw_walk/renders_512/clay'
DUR = [60, 60, 60, 60, 60, 50, 60, 60, 60, 60, 60, 50]      # 700 ms / 12 = 58.33 ms = 17.144 fps
def fr(F, i, tag='rim'):
    d = f'{ROOT}/walk' if tag == 'rim' else f'{ROOT}/_norim/walk'
    return Image.open(f'{d}/ironjaw_walk_{F}_f{i:02d}.png').convert('RGBA')
def on(bg, im):
    c = Image.new('RGBA', im.size, bg + (255,)); c.alpha_composite(im); return c
# 1x GIFs
for F in 'SE':
    ims = [on((0x6b, 0x68, 0x60), fr(F, i)).convert('RGB') for i in range(12)]
    pal = ims[0].quantize(colors=255, method=Image.MEDIANCUT, kmeans=1)
    q = [im.quantize(palette=pal, dither=Image.FLOYDSTEINBERG) for im in ims]
    q[0].save(f'{T}/walk_{F}.gif', save_all=True, append_images=q[1:], duration=DUR, loop=0, disposal=1, optimize=False)
# game 0.30, translating along the 2:1 diagonal (161 cell px / cycle = (12,6) per frame)
S30 = 0.30; NCYC = 3; NF = 12 * NCYC
TILE_W, TILE_H = 64 / S30, 32 / S30
def panel(F, n):
    dx, dy = (12, 6) if F == 'S' else (12, -6)
    W = 512 + dx * NF; H = 360 + abs(dy) * NF
    oy0 = 0 if dy > 0 else abs(dy) * NF
    c = Image.new('RGBA', (W, H), (0x7a, 0x9a, 0x5a, 255)); d = ImageDraw.Draw(c)
    # iso board lines (64x32 tiles at 0.30), anchored to the first frame's pivot
    px, py = 256, 329 + oy0
    for k in range(-30, 31):
        for sgn in (1, -1):
            x0 = px + k * TILE_W; y0 = py
            pts = [(x0 - 3000, y0 - sgn * 1500), (x0 + 3000, y0 + sgn * 1500)]
            d.line(pts, fill=(0x6e, 0x8c, 0x50, 255), width=3)
    c.alpha_composite(fr(F, n % 12), (dx * n, oy0 + dy * n))
    return c
frames = []
for n in range(NF):
    ps_ = [panel(F, n) for F in 'SE']
    ps_ = [p.resize((round(p.width * S30), round(p.height * S30)), Image.LANCZOS) for p in ps_]
    W = sum(p.width for p in ps_) + 8; H = max(p.height for p in ps_)
    c = Image.new('RGB', (W, H), (40, 40, 40)); x = 0
    for p in ps_: c.paste(p.convert('RGB'), (x, 0)); x += p.width + 8
    frames.append(c)
pal = frames[0].quantize(colors=255, method=Image.MEDIANCUT, kmeans=1)
q = [f.quantize(palette=pal, dither=Image.NONE) for f in frames]
q[0].save(f'{T}/walk_game030_SE.gif', save_all=True, append_images=q[1:], duration=DUR * NCYC, loop=0, disposal=1, optimize=False)
# painted vs clay guide
for F in 'SE':
    M = Image.new('RGB', (2048, 6 * 360), (200, 200, 200)); d = ImageDraw.Draw(M)
    for i in range(12):
        x = (i % 2) * 1024; y = (i // 2) * 360
        M.paste(on((0x6b, 0x68, 0x60), fr(F, i)).convert('RGB'), (x, y))
        g = Image.open(f'{GUIDE}/walk_{F}_f{i:02d}.png').convert('RGBA')
        M.paste(on((0x6b, 0x68, 0x60), g).convert('RGB'), (x + 512, y))
        d.text((x + 6, y + 6), f'painted {F} f{i:02d}', fill=(255, 255, 255)); d.text((x + 518, y + 6), f'clay guide {F} f{i:02d}', fill=(255, 255, 255))
        d.line([(x + 1023, y), (x + 1023, y + 359)], fill=(0, 0, 0), width=2); d.line([(x, y + 359), (x + 1023, y + 359)], fill=(0, 0, 0), width=1)
    M.save(f'{T}/walk_vs_guide_{F}.png')
# contact sheet S/E (0.5x)
M = Image.new('RGB', (12 * 256, 2 * 180 + 2 * 14), (0x6b, 0x68, 0x60)); d = ImageDraw.Draw(M)
for r, F in enumerate('SE'):
    for i in range(12):
        im = on((0x6b, 0x68, 0x60), fr(F, i)).resize((256, 180), Image.LANCZOS).convert('RGB')
        M.paste(im, (i * 256, r * 194 + 14)); d.text((i * 256 + 4, r * 194 + 1), f'{F} f{i:02d}', fill=(255, 255, 255))
M.save(f'{T}/walk_contact_S_E.png')
# vs Luca's reference at the same helm-to-sole height
ref = Image.open('/workspace/art_src/blockout/ironjaw_walk/ref/luca_hold_reference.png').convert('RGB')
ra = np.asarray(ref).astype(int); bgc = np.median(ra[:5, :5].reshape(-1, 3), 0)
fig = (np.abs(ra - bgc).sum(2) > 40)
rowc = fig[:, :int(ra.shape[1] * 0.86)].sum(1); cut = next(y for y in range(int(ra.shape[0] * 0.75), ra.shape[0]) if rowc[y] == 0)
fig[cut:] = False     # drop caption row
fig[:, int(ra.shape[1] * 0.86):] = False                                        # drop the v3.2 sliver at right
ys, xs = np.nonzero(fig); refc = ref.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
w = fr('S', 0); a = np.asarray(w)[..., 3] > 0; wy, wx = np.nonzero(a)
h = wy.max() - wy.min() + 1
refs = refc.resize((round(refc.width * h / refc.height), h), Image.LANCZOS)
wc = on((0xec, 0xeb, 0xe8), w).crop((wx.min() - 10, wy.min() - 10, wx.max() + 11, wy.max() + 11)).convert('RGB')
M = Image.new('RGB', (wc.width + refs.width + 40, h + 50), (0xec, 0xeb, 0xe8)); d = ImageDraw.Draw(M)
M.paste(wc, (10, 30)); M.paste(refs, (wc.width + 30, 40))
d.text((12, 8), 'painted walk S f00 (rig)', fill=(0, 0, 0)); d.text((wc.width + 32, 8), "Luca's hold reference (same height)", fill=(0, 0, 0))
M.save(f'{T}/walk_vs_luca_ref.png')
print('ok')
