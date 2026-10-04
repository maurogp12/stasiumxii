"""Kestrel actions v1 - close-up strip of the frames under review: attack S f05, skill S f06, attack E f05, hit S f03,
death E f12, each cropped to the figure, 3x nearest-neighbour on grey 172, with idle f00 of the same facing for scale.
usage: closeup.py [out.png]"""
import os, sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__)); FR = os.path.join(HERE, '..', 'frames')
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'closeups.png')
SHOTS = [('idle', 'S', 0), ('attack', 'S', 5), ('skill', 'S', 6), ('hit', 'S', 3), ('idle', 'E', 0), ('attack', 'E', 5), ('death', 'E', 12)]
SC = 3; BG = (172, 172, 172)
FT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 22)
tiles = []
for act, F, i in SHOTS:
    a = Image.open(f'{FR}/{act}_{F}_f{i:02d}.png').convert('RGBA')
    al = np.asarray(a)[..., 3] > 0; ys, xs = np.nonzero(al)
    box = (max(0, xs.min() - 6), max(0, ys.min() - 6), min(512, xs.max() + 7), min(360, ys.max() + 7))
    b = Image.new('RGBA', a.size, BG + (255,)); b.alpha_composite(a); b = b.crop(box).convert('RGB')
    b = b.resize((b.width * SC, b.height * SC), Image.NEAREST); tiles.append((f'{act} {F} f{i:02d}', b))
H = max(t.height for _, t in tiles) + 40; W = sum(t.width + 12 for _, t in tiles)
S = Image.new('RGB', (W, H), (235, 235, 230)); d = ImageDraw.Draw(S); x = 0
for name, t in tiles:
    S.paste(t, (x, 40 + (H - 40 - t.height))); d.text((x + 4, 8), name, fill=(20, 20, 20), font=FT); x += t.width + 12
S.save(OUT); print(OUT, S.size)
