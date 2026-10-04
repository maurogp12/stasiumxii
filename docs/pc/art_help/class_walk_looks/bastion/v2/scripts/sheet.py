"""contact sheet of frames on grey 128: sheet.py DIR F out.png [frames]"""
import sys, numpy as np
from PIL import Image
D, F, OUT = sys.argv[1:4]; fl = [int(x) for x in sys.argv[4].split(',')] if len(sys.argv) > 4 else list(range(12))
tiles = []
for i in fl:
    im = Image.open(f'{D}/bastion_walk_{F}_f{i:02d}.png').convert('RGBA'); bg = Image.new('RGBA', im.size, (128, 128, 128, 255)); bg.alpha_composite(im)
    tiles.append(bg.crop((96, 40, 416, 360)))
n = len(tiles); cols = min(n, 4); rows = (n + cols - 1) // cols; W, H = tiles[0].size
S = Image.new('RGB', (W * cols, H * rows))
for k, t in enumerate(tiles): S.paste(t.convert('RGB'), ((k % cols) * W, (k // cols) * H))
S.save(OUT)
