import numpy as np, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
FPS=24; AF=12; K=0.66; CW,CH=640,440; BX,BY=320,404
DV={'n':(-2,-1),'e':(2,-1),'s':(2,1),'w':(-2,1)}; TF={'n':'S','e':'W','s':'N','w':'E'}
FR={d:[Image.open(f'serra14_attack_{d}.png').crop((i*CW,0,i*CW+CW,CH)).resize((round(CW*K),round(CH*K)),Image.LANCZOS) for i in range(14)] for d in 'nesw'}
def strip(p,cw):
    im=Image.open(p).convert('RGBA'); return [im.crop((x*cw,0,x*cw+cw,im.height)) for x in range(im.width//cw)]
IJ={(a,k):[f.resize((round(f.width*1.25),round(f.height*1.25)),Image.LANCZOS) for f in strip(f'/workspace/art/ironjaw_full/v2/{a}/ironjaw_{a}_{k}_strip.png',161)] for a in ('idle','hit') for k in 'NESW'}
PIV=(80,133)
fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',56); TWp,THp=120,60
def floor():
    im=Image.new('RGBA',(960,540),(16,18,24,255)); d=ImageDraw.Draw(im)
    for i in range(-10,11):
        for j in range(-10,11):
            x=480+(i-j)*TWp/2; y=300+(i+j)*THp/2
            d.polygon([(x,y-THp/2),(x+TWp/2,y),(x,y+THp/2),(x-TWp/2,y)],fill=(38,42,54,255) if (i+j)%2 else (30,34,44,255),outline=(48,54,68,255))
    return im
FL=floor()
def tint(im,t):
    a=np.array(im); m=a[...,3]>0; f=a[...,:3].astype(float); f=f*(1-t)+np.array([150,200,255])*t; a[...,:3][m]=np.clip(f[m],0,230).astype(np.uint8); return Image.fromarray(a)
def soft(fn,blur,col,al,size=(960,540)):
    L=Image.new('L',size); fn(ImageDraw.Draw(L)); L=L.filter(ImageFilter.GaussianBlur(blur)); c=Image.new('RGBA',size,col+(0,)); c.putalpha(L.point(lambda v:int(v*al))); return c
PER=2.0
def frame(n):
    t=n/FPS; G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'):
        g=FL.copy(); dv=np.array(DV[dn],float); dv/=np.linalg.norm(dv)
        sp=np.array([480,312])-dv*120; tp=np.array([480,312])+dv*130     # serra base / target feet
        lt=t%PER; fi=min(13,int(lt*AF)); hit_t=7/AF; ag=lt-hit_t
        items=[]
        sim=FR[dn][fi]; items.append((sp[1],sim,(round(sp[0]-BX*K),round(sp[1]-BY*K))))
        tf=TF[dn]
        if 0<=ag<0.33: tim=IJ[('hit',tf)][min(len(IJ[('hit',tf)])-1,int(ag*12))]; tim=tint(tim,0.35*(1-ag/0.33))
        else: tim=IJ[('idle',tf)][int(t*6)%4]
        push=dv*(6*max(0,1-ag/0.25) if 0<=ag<0.25 else 0)
        tq=tp+push; items.append((tq[1],tim,(round(tq[0]-PIV[0]*1.25),round(tq[1]-PIV[1]*1.25))))
        sh=Image.new('RGBA',(960,540)); ImageDraw.Draw(sh).ellipse([tq[0]-34,tq[1]-9,tq[0]+34,tq[1]+9],fill=(0,0,0,90)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(2)))
        for _,im,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(im,xy)
        if 0<=ag<0.5:   # frost slash across the target + ice splash
            u=ag/0.5; c=tq+[0,-70]; nn=np.array([-dv[1],dv[0]])
            g.alpha_composite(soft(lambda d:[d.line([tuple(c-nn*60+dv*k*10-dv*20),tuple(c+nn*60+dv*k*10+dv*20)],fill=255,width=7) for k in (-1,0,1)],2,(170,220,255),0.85*(1-u)))
            rr=np.random.default_rng(3)
            def sp_(d):
                for i in range(22):
                    a=rr.uniform(0,2*np.pi); s_=rr.uniform(0.4,1); x=c[0]+np.cos(a)*90*s_*u+dv[0]*40*u; y=c[1]+np.sin(a)*55*s_*u+60*u*u; r=rr.uniform(3,7)*(1-0.5*u)
                    d.polygon([(x,y-r*1.5),(x+r,y),(x,y+r*1.5),(x-r,y)],fill=255)
            g.alpha_composite(soft(sp_,1.2,(190,225,255),0.9*(1-u)))
            if u<0.4: g.alpha_composite(soft(lambda d:d.ellipse([c[0]-50,c[1]-35,c[0]+50,c[1]+35],fill=255),14,(140,200,255),0.5*(1-u/0.4)))
        d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
        cc=np.array([150,48]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
        n_=np.array([-dv[1],dv[0]]); d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+n_*14),tuple(b_-dv*6-n_*14)],fill=(140,200,255,255))
        G.alpha_composite(g,((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_f',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame(i).save(f'_f/{i:05d}.png',compress_level=1)
