import sys
from ngc import *
# usage: prev_patch.py out.png n id1 id2 ...  (random variants)
out=sys.argv[1]; n=int(sys.argv[2]); ids=sys.argv[3:]
W=n*128+40; H=n*64+40
can=Image.new('RGBA',(W,H),(110,110,110,255))
r=rng(3)
for x in range(n):
    for y in range(n):
        iid=ids[r.integers(len(ids))]
        im=Image.open(SHIP+'tiles/_2x/'+iid+'.png')
        cx=W//2+(x-y)*64; cy=20+(x+y)*32+32
        can.alpha_composite(im,(cx-64,cy-32))
can.save(out)
