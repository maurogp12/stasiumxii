import sys
from PIL import Image
import numpy as np
B='/workspace/art_src/blockout/ironjaw_walk/'
REF='/workspace/art/ironjaw_full/'
src=sys.argv[1]; tag=sys.argv[2]; names=sys.argv[3].split(',')
def bbox(im):
    a=np.array(im)[:,:,3]>0; ys=np.where(a.any(1))[0]; xs=np.where(a.any(0))[0]; return xs[0],ys[0],xs[-1],ys[-1]
def fit(im,h):
    x0,y0,x1,y1=bbox(im); c=im.crop((x0,y0,x1+1,y1+1)); s=h/(y1-y0+1); return c.resize((max(1,round(c.width*s)),h),Image.LANCZOS)
refs={'S':'v4_hd/_test/ironjaw_idle_S_f00_A_raw.png','E':'v4_hd/_test/ironjaw_idle_E_f00_bulky.png'}
F=names[0].split('_')[1] if names[0].startswith('walk') else names[0][-1]
h=330
row=[fit(Image.open(REF+refs[F]).convert('RGBA'),h)]
for n in names:
    row.append(fit(Image.open(B+src+'/'+n+'.png'),h))
W=sum(i.width+6 for i in row); out=Image.new('RGB',(W,h),(232,232,232)); x=0
for i in row: out.paste(i,(x,0),i); x+=i.width+6
out.save(B+'qa/look/'+tag+'.jpg',quality=88); print(out.size)
