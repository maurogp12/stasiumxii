import sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np
REFPIC='/home/box/agent-data/agents/8537bb43-4235-475e-8472-f01692203a1d/attachments/9defce0032b7f9ae804c3c235a0389e6d8887621e3c8f8cca2143f226abe315c.png'
HD='/workspace/art/ironjaw_full/v4_hd/idle/ironjaw_idle_%s_f00.png'
src=sys.argv[1]; out=sys.argv[2]; H=int(sys.argv[3]) if len(sys.argv)>3 else 420
names=sys.argv[4].split(',') if len(sys.argv)>4 else ['clay/idle_S','sides/idle_S','clay/walk_S_f00','clay/idle_E']
def bbox_alpha(im):
    a=np.array(im)[:,:,3]>0; ys=np.where(a.any(1))[0]; xs=np.where(a.any(0))[0]; return xs[0],ys[0],xs[-1]+1,ys[-1]+1
def fit(c,h):
    s=h/c.height; return c.resize((max(1,round(c.width*s)),h),Image.LANCZOS)
ref=Image.open(REFPIC).convert('RGBA').crop((0,0,440,460))   # figure only (helm top ~0 to sole ~455), drop the caption
# reference: background is light grey, figure helm->sole ~ rows 2..455
cells=[('reference (Luca)',fit(ref,H))]
for F in 'SE':
    im=Image.open(HD%F).convert('RGBA'); cells.append(('HD idle '+F,fit(im.crop(bbox_alpha(im)),H)))
for n in names:
    im=Image.open('%s/%s.png'%(src,n)).convert('RGBA'); cells.append((n,fit(im.crop(bbox_alpha(im)),H)))
pad=12; W=sum(c.width+pad for _,c in cells)+pad
can=Image.new('RGB',(W,H+30),(236,234,228)); d=ImageDraw.Draw(can)
try: f=ImageFont.load_default(size=16)
except TypeError: f=ImageFont.load_default()
x=pad
for l,c in cells:
    can.paste(c,(x,26),c); d.text((x,4),l,fill=(0,0,0),font=f); x+=c.width+pad
can.save(out); print(can.size)
