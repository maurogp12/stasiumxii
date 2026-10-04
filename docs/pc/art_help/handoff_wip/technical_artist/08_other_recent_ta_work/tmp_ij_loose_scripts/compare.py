from PIL import Image, ImageDraw, ImageFont
import numpy as np, os
B='/workspace/art_src/blockout/ironjaw_walk'
OUT='/workspace/luca_pics/chars/ironjaw_hold_compare.jpg'
H=440
def bb(im):
    a=np.array(im)[:,:,3]>0; ys=np.where(a.any(1))[0]; xs=np.where(a.any(0))[0]; return xs[0],ys[0],xs[-1]+1,ys[-1]+1
def fit(c,h,nearest=False):
    s=h/c.height; return c.resize((round(c.width*s),h),Image.NEAREST if nearest else Image.LANCZOS)
ref=Image.open(B+'/ref/luca_hold_reference.png').convert('RGBA').crop((0,0,440,460))
hd=Image.open('/workspace/art/ironjaw_full/v4_hd/idle/ironjaw_idle_S_f00.png').convert('RGBA'); hd=hd.crop(bb(hd))
idle=Image.open(B+'/renders_512/clay/idle_S.png').convert('RGBA'); idle=idle.crop(bb(idle))
walk=Image.open(B+'/renders_512/clay/walk_S_f04.png').convert('RGBA'); walk=walk.crop(bb(walk))
cells=[[('Luca\'s reference (target)',fit(ref,H)),('NEW blockout: idle S, clay',fit(idle,H,True))],
       [('HD idle S (final painting)',fit(hd,H)),('NEW blockout: walk S f04, clay',fit(walk,H,True))]]
try:
    F=ImageFont.load_default(size=20); Fs=ImageFont.load_default(size=14)
except TypeError:
    F=Fs=ImageFont.load_default()
cw=[max(cells[r][c][1].width for r in range(2)) for c in range(2)]
pad=16; top=34; lab=28
Wt=pad*3+sum(cw)+12; Ht=top+2*(lab+H+pad)
can=Image.new('RGB',(Wt,Ht),(238,236,230)); d=ImageDraw.Draw(can)
d.text((pad,8),'Ironjaw arm + axe hold: reference (left) vs new 3D underlay (right). All figures scaled to the same helm-to-sole height (%d px).'%H,fill=(0,0,0),font=Fs)
x0=[pad, pad*2+cw[0]+12]
d.line([(x0[1]-pad//2-6,top),(x0[1]-pad//2-6,Ht-pad)],fill=(150,150,150),width=2)
for r in range(2):
    y=top+r*(lab+H+pad)
    for c in range(2):
        l,im=cells[r][c]; x=x0[c]+(cw[c]-im.width)//2
        d.text((x0[c],y+2),l,fill=(150,0,0) if c else (0,0,0),font=F)
        can.paste(im,(x,y+lab),im)
for q in (90,85,80,75,70):
    can.save(OUT,quality=q,optimize=True)
    if os.path.getsize(OUT)<300*1024: break
print(can.size, os.path.getsize(OUT), q)
