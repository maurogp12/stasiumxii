"""Bastion actions v1 - close-up strip of the key frames at 2x (nearest), S over E: idle f00, attack wind-up (f03, f04)
and smash (f06, f08), skill guard (f06), hit (f02), death mid-fall (f06) and lying (f12).
usage: closeup.py OUT.png"""
import os, sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__)); FR = os.path.join(HERE, '..', 'frames')
KEYS = [('idle', 0), ('attack', 3), ('attack', 4), ('attack', 6), ('attack', 8), ('skill', 6), ('hit', 2), ('death', 6), ('death', 12)]
X0, X1, Y0, Y1, SC = 40, 472, 0, 360, 2
FT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 22)
tw, th = (X1 - X0) * SC, (Y1 - Y0) * SC
S = Image.new('RGB', (len(KEYS) * tw, 2 * th + 2 * 34), (235, 235, 230)); d = ImageDraw.Draw(S)
for r, F in enumerate('SE'):
    for k, (a, i) in enumerate(KEYS):
        im = Image.open(f'{FR}/{a}_{F}_f{i:02d}.png').convert('RGBA'); bg = Image.new('RGBA', im.size, (172, 172, 172, 255)); bg.alpha_composite(im)
        t = bg.crop((X0, Y0, X1, Y1)).resize((tw, th), Image.NEAREST).convert('RGB'); y = r * (th + 34) + 34
        S.paste(t, (k * tw, y)); d.text((k * tw + 8, y - 30), f'{F}  {a} f{i:02d}', fill=(20, 20, 20), font=FT)
S.save(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'closeup_keys.png'))
