"""poly_ov.py F x0,y0,x1,y1 scale out 'x,y x,y ...' ['x,y ...'] : target crop with polygon outlines (target px)"""
import sys, numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, '/workspace/handoff/class_walk_blockouts/kestrel/v2/scripts')
from kcommon import target
F = sys.argv[1]; x0, y0, x1, y1 = map(int, sys.argv[2].split(',')); z = float(sys.argv[3]); out = sys.argv[4]
rgb, al = target(F); im = rgb.copy(); im[~al] = 128
c = Image.fromarray(im[y0:y1, x0:x1]).resize((int((x1 - x0) * z), int((y1 - y0) * z)), Image.LANCZOS); d = ImageDraw.Draw(c)
cols = [(255, 0, 0), (0, 255, 255), (255, 255, 0), (255, 0, 255)]
for k, ps in enumerate(sys.argv[5:]):
    P = [tuple(map(float, p.split(','))) for p in ps.split()]; P = [((x - x0) * z, (y - y0) * z) for x, y in P]
    d.line(P + [P[0]], fill=cols[k % 4], width=2)
for yy in range((y0 // 50 + 1) * 50, y1, 50): d.text((2, (yy - y0) * z), str(yy), fill=(255, 255, 0))
for xx in range((x0 // 50 + 1) * 50, x1, 50): d.text(((xx - x0) * z, 2), str(xx), fill=(255, 255, 0))
c.save(out)
