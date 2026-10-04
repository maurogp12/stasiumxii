import sys, numpy as np
from PIL import Image, ImageDraw
F, box, out = sys.argv[1], [int(v) for v in sys.argv[2].split(',')], sys.argv[3]; sc = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
T = '/workspace/handoff/class_walk_blockouts/targets/'
t = Image.open(f'{T}kestrel_rp_{F}_f00.jpg').convert('RGB')
ap = '/workspace/scratch/k3/kestrel_rp_S_f00_alphabin.png' if F == 'S' else f'{T}kestrel_rp_E_f00_alpha.png'
a = Image.open(ap).convert('L'); bg = Image.new('RGB', t.size, (128, 128, 128)); bg.paste(t, (0, 0), a)
c = bg.crop(box); c = c.resize((int(c.width * sc), int(c.height * sc))); d = ImageDraw.Draw(c)
x0, y0 = box[0], box[1]; step = int(sys.argv[5]) if len(sys.argv) > 5 else 20
for x in range((x0 // step + 1) * step, box[2], step):
    X = (x - x0) * sc; d.line([(X, 0), (X, c.height)], fill=(255, 0, 0) if x % 100 == 0 else (255, 200, 200)); 
    if x % 100 == 0: d.text((X + 2, 2), str(x), fill=(255, 255, 0))
for y in range((y0 // step + 1) * step, box[3], step):
    Y = (y - y0) * sc; d.line([(0, Y), (c.width, Y)], fill=(255, 0, 0) if y % 100 == 0 else (255, 200, 200))
    if y % 100 == 0: d.text((2, Y + 2), str(y), fill=(255, 255, 0))
c.save(out)
