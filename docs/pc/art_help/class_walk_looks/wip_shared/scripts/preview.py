"""Preview sheets for the blockouts: TA-style guide (clay over iso grid, part IDs below), contact sheet and GIFs.
usage: python preview.py <class> <outdir>"""
import sys, json, math
import numpy as np
from PIL import Image, ImageDraw

W, H, PIV = 512, 360, (256, 329)
ORTHO = 494.6236559139785
PX = W / ORTHO

def ground_px(x, y):
    """world ground point (x, y, 0) -> cell px, for the camera at azimuth -45, elevation 30 (matches blockout.py)."""
    r = np.array([1, 1, 0]) / math.sqrt(2)                     # screen right
    fwd = np.array([-1, 1, 0]) / math.sqrt(2)                  # away from camera on the ground
    p = np.array([x, y, 0.0])
    sx = np.dot(p, r) * PX; sy = -np.dot(p, fwd) * math.sin(math.radians(30)) * PX
    return PIV[0] + sx, PIV[1] + sy

def grid_bg(scroll=(0, 0)):
    im = Image.new('RGB', (W, H), (236, 234, 228)); d = ImageDraw.Draw(im); g = 64.0
    for k in range(-12, 13):
        for a, b in (((k * g, -800), (k * g, 800)), ((-800, k * g), (800, k * g))):
            p, q = ground_px(*a), ground_px(*b)
            d.line([(p[0] + scroll[0], p[1] + scroll[1]), (q[0] + scroll[0], q[1] + scroll[1])], fill=(70, 110, 220), width=1)
    d.line([(0, PIV[1]), (W, PIV[1])], fill=(225, 40, 40), width=1)
    return im

def on(bg, path):
    im = Image.open(path).convert('RGBA'); o = bg.copy(); o.paste(im, (0, 0), im); return o

def main():
    cls, out = sys.argv[-2], sys.argv[-1]
    meta = json.load(open(f'{out}/joints_512.json'))['meta']
    lab = meta['label']
    # TA-style guide at f00 (S) and f00 (E)
    G = Image.new('RGB', (2 * W + 8, 2 * H + 32), (236, 234, 228)); d = ImageDraw.Draw(G)
    for c, (F, txt) in enumerate((('S', '3/4 front'), ('E', '3/4 back'))):
        G.paste(on(grid_bg(), f'{out}/clay/{cls}_walk_{F}_f00.png'), (c * (W + 8), 16))
        d.text((c * (W + 8) + 6, 2), f'{lab}  walk {F} f00 ({txt})  1:1 cell px', fill=(20, 20, 20))
        G.paste(on(Image.new('RGB', (W, H), (236, 234, 228)), f'{out}/id/{cls}_walk_{F}_f00.png'), (c * (W + 8), H + 32))
    G.save(f'{out}/{cls}_guide_f00.png')
    # contact sheet: every frame, clay row then id row, both facings
    sc = 0.5; w, h = int(W * sc), int(H * sc)
    CS = Image.new('RGB', (12 * w, 4 * h + 4 * 14), (236, 234, 228)); d = ImageDraw.Draw(CS)
    for r, (F, kind) in enumerate((('S', 'clay'), ('S', 'id'), ('E', 'clay'), ('E', 'id'))):
        for i in range(12):
            im = on(grid_bg() if kind == 'clay' else Image.new('RGB', (W, H), (236, 234, 228)), f'{out}/{kind}/{cls}_walk_{F}_f{i:02d}.png')
            CS.paste(im.resize((w, h), Image.LANCZOS), (i * w, r * (h + 14) + 14))
            d.text((i * w + 3, r * (h + 14)), f'{F} f{i:02d} {kind}', fill=(20, 20, 20))
    CS.save(f'{out}/{cls}_walk_contact.png')
    # GIFs: clay with the ground grid scrolling at the walk speed (feet must stick), id beside it
    J = json.load(open(f'{out}/joints_512.json'))['facings']
    for F in 'SE':
        frames = []
        # scroll so the planted foot's toe stays fixed on screen: accumulate the support-foot drift
        acc = np.zeros(2)
        for i in range(12):
            j0 = J[f'walk_{F}'][f'f{i:02d}']['joints']; j1 = J[f'walk_{F}'][f'f{(i + 1) % 12:02d}']['joints']
            fr = Image.new('RGB', (2 * W, H), (236, 234, 228))
            fr.paste(on(grid_bg(tuple(acc)), f'{out}/clay/{cls}_walk_{F}_f{i:02d}.png'), (0, 0))
            fr.paste(on(Image.new('RGB', (W, H), (236, 234, 228)), f'{out}/id/{cls}_walk_{F}_f{i:02d}.png'), (W, 0))
            ImageDraw.Draw(fr).text((6, 4), f'{lab} walk {F} f{i:02d}', fill=(20, 20, 20))
            frames.append(fr.convert('P', palette=Image.ADAPTIVE, colors=128))
            sup = 'R' if j0['R_heel'][1] >= j0['L_heel'][1] else 'L'
            acc += np.array(j1[f'{sup}_heel']) - np.array(j0[f'{sup}_heel'])
        frames[0].save(f'{out}/{cls}_walk_{F}.gif', save_all=True, append_images=frames[1:], duration=58, loop=0)

if __name__ == '__main__':
    main()
