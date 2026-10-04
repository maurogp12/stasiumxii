import sys
from PIL import Image, ImageDraw
import numpy as np
B='/workspace/art_src/blockout/ironjaw_walk/'
REF='/workspace/art/ironjaw_full/'
def bbox(im):
    a=np.array(im)[:,:,3]>0; ys=np.where(a.any(1))[0]; xs=np.where(a.any(0))[0]; return xs[0],ys[0],xs[-1],ys[-1]
def fit(im, h):
    x0,y0,x1,y1=bbox(im); c=im.crop((x0,y0,x1+1,y1+1)); s=h/(y1-y0+1)
    return c.resize((max(1,round(c.width*s)),h),Image.LANCZOS)
tag=sys.argv[1] if len(sys.argv)>1 else 'cmp'
cols=[]
for F,ref,v32 in [('S','v4_hd/_test/ironjaw_idle_S_f00_A_raw.png','v3.2/idle/ironjaw_idle_S_f00.png'),('E','v4_hd/_test/ironjaw_idle_E_f00_bulky.png','v3.2/idle/ironjaw_idle_E_f00.png')]:
    mine=Image.open(B+f'renders/clay/idle_{F}.png'); h=bbox(mine)[3]-bbox(mine)[1]+1
    row=[fit(Image.open(REF+ref).convert('RGBA'),h), fit(Image.open(REF+v32).convert('RGBA'),h), fit(mine,h), fit(Image.open(B+f'renders/sides/idle_{F}.png'),h), fit(Image.open(B+f'renders/clay/walk_{F}_f00.png'),h)]
    cols.append(row)
Wt=max(sum(i.width+10 for i in r) for r in cols); Ht=sum(max(i.height for i in r)+10 for r in cols)
out=Image.new('RGB',(Wt,Ht),(230,230,230)); y=0
for r in cols:
    x=0
    for i in r: out.paste(i,(x,y),i); x+=i.width+10
    y+=max(i.height for i in r)+10
out.save(B+f'qa/look/{tag}.jpg',quality=88)
print(out.size)
