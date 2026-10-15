import numpy as np, os, sys
from PIL import Image, ImageDraw, ImageFont
K=0.8; FPS=24; NF=12; AFPS=10
DV={'n':(-2,-1),'e':(2,-1),'s':(2,1),'w':(-2,1)}
FR={d:[Image.open(f'serra5_walk_{d}.png').crop((i*288,0,i*288+288,336)).resize((round(288*K),round(336*K)),Image.LANCZOS) for i in range(NF)] for d in 'nesw'}
fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',56); TWp,THp=120,60
def floor(w,h,cx,cy):
    im=Image.new('RGBA',(w,h),(16,18,24,255)); d=ImageDraw.Draw(im)
    for i in range(-10,11):
        for j in range(-10,11):
            x=cx+(i-j)*TWp/2; y=cy+(i+j)*THp/2
            d.polygon([(x,y-THp/2),(x+TWp/2,y),(x,y+THp/2),(x-TWp/2,y)],fill=(38,42,54,255) if (i+j)%2 else (30,34,44,255),outline=(48,54,68,255))
    return im
FL=floor(960,540,480,330)
def frame(n):
    t=n/FPS; G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'):
        g=FL.copy(); dv=np.array(DV[dn],float)/np.sqrt(5); per=4.0; u=(t%per)/per; s=(u-0.5)*2*170   # glide across, 2 passes in 8 s
        bx=480+dv[0]/abs(dv[0])*s; by=330+dv[1]/abs(dv[0])*s
        im=FR[dn][int(t*AFPS)%NF]; fa=min(1,u/0.15,(1-u)/0.15); fa=fa*fa*(3-2*fa)   # eased fade at both ends of each pass (no wrap pop)
        if fa<1: a=np.array(im); a[...,3]=(a[...,3]*fa).astype(np.uint8); im=Image.fromarray(a)
        g.alpha_composite(im,(round(bx-144*K),round(by-300*K)))
        d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
        c=np.array([150,48]); a_=c-dv*40; b_=c+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
        nn=np.array([-dv[1],dv[0]]); d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+nn*14),tuple(b_-dv*6-nn*14)],fill=(140,200,255,255))
        G.alpha_composite(g,((q%2)*960,(q//2)*540))
    return G.convert('RGB')
os.makedirs('_f',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
for i in range(a,b): frame(i).save(f'_f/{i:05d}.png',compress_level=1)
