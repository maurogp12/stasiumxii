"""Bastion actions v1 - contact sheets: per facing, every frame of every action, painted (top row) over the blockout clay it
is rigged on (middle row, blockout/clay, aim fix) and the approved blockout clay (bottom row, blockout/approved/clay, the
poses of bastion_actions.mp4). Red line = pivot row 329; all tiles share one crop and scale.
usage: asheets.py [out_dir]"""
import os, sys, json, numpy as np
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..')
OUT = sys.argv[1] if len(sys.argv) > 1 else ROOT
ACTS = {'idle': 12, 'attack': 12, 'skill': 12, 'hit': 8, 'death': 13}
BOX = (0, 0, 512, 360); SC = 0.45; BG = (172, 172, 172)
def font(sz):
    for p in ('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',):
        if os.path.exists(p): return ImageFont.truetype(p, sz)
    return ImageFont.load_default()
FT = font(14); FB = font(18)

def tile(path):
    a = Image.open(path).convert('RGBA'); b = Image.new('RGBA', a.size, BG + (255,)); b.alpha_composite(a)
    d = ImageDraw.Draw(b); d.line([(0, 329), (512, 329)], fill=(200, 60, 60))
    b = b.crop(BOX).convert('RGB'); return b.resize((int(b.width * SC), int(b.height * SC)), Image.LANCZOS)

def sheet(F):
    tw, th = int((BOX[2] - BOX[0]) * SC), int((BOX[3] - BOX[1]) * SC); lw = 120
    rows = []
    for act, n in ACTS.items():
        rows += [(act, 'painted', [f'{ROOT}/frames/{act}_{F}_f{i:02d}.png' for i in range(n)]),
                 (act, 'rig clay', [f'{ROOT}/blockout/clay/bastion_{act}_{F}_f{i:02d}.png' for i in range(n)]),
                 (act, 'approved', [f'{ROOT}/blockout/approved/clay/bastion_{act}_{F}_f{i:02d}.png' for i in range(n)])]
    S = Image.new('RGB', (lw + 13 * tw, 40 + len(rows) * (th + 4) + 5 * 10), (235, 235, 230)); d = ImageDraw.Draw(S)
    d.text((10, 10), f'Bastion actions v1, facing {F}: painted frames over the rig clay (aim fix) and the approved blockout clay. '
                     f'Frame numbers on top; red = pivot row.', fill=(20, 20, 20), font=FB)
    y = 40; last = None
    for act, kind, paths in rows:
        if act != last and last is not None: y += 10
        last = act
        d.text((8, y + th // 2 - 16), act, fill=(20, 20, 20), font=FB); d.text((8, y + th // 2 + 6), kind, fill=(90, 90, 90), font=FT)
        for i, p in enumerate(paths):
            S.paste(tile(p), (lw + i * tw, y))
            if kind == 'painted': d.text((lw + i * tw + 4, y + 2), f'f{i:02d}', fill=(30, 30, 30), font=FT)
        y += th + 4
    S.save(f'{OUT}/contact_{F}.png')

if __name__ == '__main__':
    for F in 'SE': sheet(F)
