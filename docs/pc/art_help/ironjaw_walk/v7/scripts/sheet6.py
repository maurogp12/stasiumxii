import sys, numpy as np
from PIL import Image
d, fac, out = sys.argv[1], sys.argv[2], sys.argv[3]; sc = float(sys.argv[4]) if len(sys.argv) > 4 else 2
ims = [Image.open(f'{d}/ironjaw_walk_{fac}_f{i:02d}.png').convert('RGBA') for i in range(12)]
A = np.zeros(ims[0].size[::-1], bool)
for im in ims: A |= np.asarray(im)[..., 3] > 200
ys, xs = np.nonzero(A); b = (xs.min()-4, ys.min()-4, xs.max()+5, ys.max()+5)
cs = [im.crop(b) for im in ims]; w, h = cs[0].size
sh = Image.new('RGBA', (w*6, h*2), (120, 120, 120, 255))
for i, c in enumerate(cs): sh.alpha_composite(c, ((i % 6)*w, (i//6)*h))
sh.resize((int(sh.width*sc), int(sh.height*sc)), Image.NEAREST).save(out); print(b, w, h)
