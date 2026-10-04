"""S swing-foot before/after strip f03-f07 (legs crop x2): rows = given frame dirs (top to bottom), with the swing (L) boot drop.
usage: swing_strip.py OUT.png DROP_JSON label1=dir1 label2=dir2 ..."""
import sys, json, numpy as np
from PIL import Image, ImageDraw
OUT, DROP = sys.argv[1], json.load(open(sys.argv[2])); rows = [a.split('=', 1) for a in sys.argv[3:]]
X0, Y0, X1, Y1, Z = 196, 186, 352, 360, 2; FR = range(3, 8)
w, h = (X1 - X0) * Z, (Y1 - Y0) * Z; o = Image.new('RGB', (w * len(FR), (h + 18) * len(rows) + 22), (30, 30, 30)); d0 = ImageDraw.Draw(o)
for r, (lab, d) in enumerate(rows):
    for k, i in enumerate(FR):
        a = np.asarray(Image.open(f'{d}/bastion_walk_S_f{i:02d}.png')); bg = np.full((360, 512, 3), 128, np.uint8); m = a[..., 3] > 0; bg[m] = a[..., :3][m]
        p = Image.fromarray(bg[Y0:Y1, X0:X1]).resize((w, h), Image.LANCZOS); dr = ImageDraw.Draw(p)
        for y in range(0, h, 20): dr.line([(w - 6, y), (w, y)], fill=(255, 255, 0))      # 10 px ticks
        o.paste(p, (k * w, r * (h + 18) + 18)); d0.text((k * w + 6, r * (h + 18) + 3), f'{lab}  f{i:02d}', fill=(255, 255, 255))
d0.text((6, o.height - 18), 'S swing (L) boot drop vs v2, px: ' + '  '.join(f'f{i:02d} {DROP[str(i)]:+.1f}' for i in FR) +
        '   (f06 = heel-strike contact, pinned to the clay sole; ticks = 10 px)', fill=(255, 255, 160))
o.save(OUT); print('ok', o.size)
