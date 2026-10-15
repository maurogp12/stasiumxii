import numpy as np, os, sys, json
TRK=json.load(open('arm_track.json')); MAPK={'n':('back',True),'e':('back',False),'s':('front',True),'w':('front',False)}
from PIL import Image, ImageDraw, ImageFont, ImageFilter
FPS=24; AF=12; K=0.66; CW,CH=640,440; BX,BY=320,404; NFR=18; PER=2.25
DV={'n':(-2,-1),'e':(2,-1),'s':(2,1),'w':(-2,1)}; TF={'n':'S','e':'W','s':'N','w':'E'}
FR={d:[Image.open(f'serra14_spell_{d}.png').crop((i*CW,0,i*CW+CW,CH)).resize((round(CW*K),round(CH*K)),Image.LANCZOS) for i in range(NFR)] for d in 'nesw'}
def strip(p,cw): im=Image.open(p).convert('RGBA'); return [im.crop((x*cw,0,x*cw+cw,im.height)) for x in range(im.width//cw)]
def sc(fs,k): return [f.resize((round(f.width*k),round(f.height*k)),Image.LANCZOS) for f in fs]
CH_={'ij':dict(cw=161,piv=(80,133),k=1.03,p='/workspace/art/ironjaw_full/v2/{a}/ironjaw_{a}_{K}_strip.png'),
     'ke':dict(cw=116,piv=(68,141),k=0.95,p='/workspace/art/kestrel_full/v3/{a}/kestrel_{a}_{K}_strip.png')}
SP={(c,a,Kk):sc(strip(v['p'].format(a=a,K=Kk),v['cw']),v['k']) for c,v in CH_.items() for a in ('idle','hit') for Kk in 'NESW'}
fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',56); TWp,THp=120,60
def floor():
    im=Image.new('RGBA',(960,540),(16,18,24,255)); d=ImageDraw.Draw(im)
    for i in range(-10,11):
        for j in range(-10,11):
            x=480+(i-j)*TWp/2; y=312+(i+j)*THp/2
            d.polygon([(x,y-THp/2),(x+TWp/2,y),(x,y+THp/2),(x-TWp/2,y)],fill=(38,42,54,255) if (i+j)%2 else (30,34,44,255),outline=(48,54,68,255))
    return im
FL=floor()
def tint(im,t):
    a=np.array(im); m=a[...,3]>0; f=a[...,:3].astype(float); f=f*(1-t)+np.array([150,200,255])*t; a[...,:3][m]=np.clip(f[m],0,230).astype(np.uint8); return Image.fromarray(a)
def soft(fn,blur,col,al):
    L=Image.new('L',(960,540)); fn(ImageDraw.Draw(L)); L=L.filter(ImageFilter.GaussianBlur(blur)); c=Image.new('RGBA',(960,540),col+(0,)); c.putalpha(L.point(lambda v:int(v*al))); return c
def shard(d,x,y,a,r):
    c,s=np.cos(a),np.sin(a); d.polygon([(x-c*r*2,y-s*r*2),(x-s*r*.5,y+c*r*.5),(x+c*r*2,y+s*r*2),(x+s*r*.5,y-c*r*.5)],fill=255)
VS=5/AF; RAIN=9/AF; HIT=11/AF   # vortex forms, rain starts, first impacts (s)
CAST={}
def frame(n):
    t=n/FPS; G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'):
        g=FL.copy(); dv=np.array(DV[dn],float); dv/=np.linalg.norm(dv); nn=np.array([-dv[1],dv[0]])
        C=np.array([480,312]); sp=C-dv*125; tp=C+dv*110
        lt=t%PER; fi=min(NFR-1,int(lt*AF))
        T=[('ij',tp+np.array([-56,-6])),('ke',tp+np.array([56,6]))]
        # ground frost (under everything)
        fr=lt-HIT
        if fr>0:
            a_=min(1,fr/0.25)*(1 if fr<0.9 else max(0,1-(fr-0.9)/0.35))
            g.alpha_composite(soft(lambda d:d.ellipse([tp[0]-115,tp[1]-42,tp[0]+115,tp[1]+42],fill=255),10,(120,180,235),0.18*a_))
            rr=np.random.default_rng(9)
            def crk(d):
                for i in range(26):
                    x=tp[0]+rr.uniform(-105,105); y=tp[1]+rr.uniform(-36,36)
                    if ((x-tp[0])/110)**2+((y-tp[1])/40)**2<1: shard(d,x,y,rr.uniform(0,np.pi),rr.uniform(1.5,3))
            g.alpha_composite(soft(crk,0.5,(200,230,255),0.7*a_))
        items=[(sp[1],FR[dn][fi],(round(sp[0]-BX*K),round(sp[1]-BY*K)))]
        for i,(c,p) in enumerate(T):
            v=CH_[c]; ag=lt-HIT-0.06*i
            if 0<=ag<0.4: fs=SP[(c,'hit',TF[dn])]; im=tint(fs[min(len(fs)-1,int(ag*12))],0.14*(1-ag/0.4))
            else: fs=SP[(c,'idle',TF[dn])]; im=fs[int(t*6)%len(fs)]
            sh=Image.new('RGBA',(960,540)); ImageDraw.Draw(sh).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(2)))
            items.append((p[1],im,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
        for _,im,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(im,xy)
        # vortex above targets
        VC=tp+[0,-188]; vu=lt-VS
        if 0<=vu<1.25:
            grow=min(1,vu/0.35); fade=1 if vu<0.95 else max(0,1-(vu-0.95)/0.3)
            g.alpha_composite(soft(lambda d:d.ellipse([VC[0]-95*grow,VC[1]-26*grow,VC[0]+95*grow,VC[1]+26*grow],fill=255),12,(110,160,220),0.45*fade))
            rr=np.random.default_rng(4)
            def vort(d):
                for i in range(40):
                    a=rr.uniform(0,2*np.pi)+vu*(5+rr.uniform(0,3)); r=rr.uniform(0.3,1)*95*grow
                    x=VC[0]+np.cos(a)*r; y=VC[1]+np.sin(a)*r*0.28-rr.uniform(-8,8); shard(d,x,y,a+1.6,rr.uniform(1.5,3.5))
            g.alpha_composite(soft(vort,0.6,(200,230,255),0.9*fade))
            g.alpha_composite(soft(lambda d:[d.arc([VC[0]-r_*grow,VC[1]-r_*.28*grow,VC[0]+r_*grow,VC[1]+r_*.28*grow],(vu*400+j*120)%360,(vu*400+j*120+80)%360,fill=255,width=3) for j,r_ in enumerate((90,65,40))],1.5,(170,215,255),0.6*fade))
        # cast streak: frost ribbon from her raised hand to the vortex (shows cast direction)
        k_,mir=MAPK[dn]; H=np.array(TRK[k_][min(fi,17)][3]); H[0]=CW-H[0] if mir else H[0]; Hv=sp+(H-[BX,BY])*K
        if 6<=fi<=9:
            cu=(lt-6/AF)/(4/AF); P1=Hv+(VC-Hv)*min(1,cu*1.6); P0=Hv+(VC-Hv)*max(0,cu*1.6-0.6)
            g.alpha_composite(soft(lambda d:d.line([tuple(P0),tuple(P1)],fill=255,width=9),4,(120,185,255),0.6))
            g.alpha_composite(soft(lambda d:d.line([tuple(P0),tuple(P1)],fill=255,width=3),1,(210,235,255),0.85))
        CAST[dn]=(Hv,VC)
        # icicle rain: each icicle falls from the vortex to a ground spot around the targets
        ru=lt-RAIN
        if 0<=ru<0.9:
            rr=np.random.default_rng(7)
            def rain(d):
                for i in range(22):
                    t0=rr.uniform(0,0.45); gx=tp[0]+rr.uniform(-100,100); gy=tp[1]+rr.uniform(-30,30)-10; u=(ru-t0)/0.18
                    if 0<=u<1:
                        y=VC[1]+(gy-VC[1])*u; x=gx+(1-u)*(VC[0]-gx)*0.25; d.line([(x,y-22),(x,y)],fill=255,width=3); shard(d,x,y,np.pi/2,3)
            g.alpha_composite(soft(rain,0.6,(205,232,255),0.95))
            def spl(d):
                for i in range(22):
                    t0=rr.uniform(0,0.45); gx=tp[0]+rr.uniform(-100,100); gy=tp[1]+rr.uniform(-30,30)-10; u=(ru-t0-0.18)/0.2
                    if 0<=u<1:
                        for j in range(5): a=-np.pi*(0.1+0.8*j/4); r=14*u; shard(d,gx+np.cos(a)*r,gy+np.sin(a)*r*0.6-10*u+14*u*u,a,2.4*(1-0.5*u))
            g.alpha_composite(soft(spl,0.6,(190,225,255),0.85))
        for i,(c,p) in enumerate(T):   # big ice-splash on each target at its hit
            ag=lt-HIT-0.06*i
            if 0<=ag<0.4:
                u=ag/0.4; cc=p+[0,-55]
                g.alpha_composite(soft(lambda d:d.ellipse([cc[0]-40,cc[1]-32,cc[0]+40,cc[1]+32],fill=255),12,(140,200,255),0.16*(1-u)))
                rr=np.random.default_rng(11+i)
                def bur(d):
                    for j in range(16):
                        a=rr.uniform(-np.pi,0.2); s_=rr.uniform(.4,1); shard(d,cc[0]+np.cos(a)*60*s_*u,cc[1]+np.sin(a)*45*s_*u+50*u*u,a,rr.uniform(2,4)*(1-.5*u))
                g.alpha_composite(soft(bur,0.8,(195,228,255),0.9*(1-u)))
        d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
        cc=np.array([150,48]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
        d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+nn*14),tuple(b_-dv*6-nn*14)],fill=(140,200,255,255))
        G.alpha_composite(g,((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_f',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame(i).save(f'_f/{i:05d}.png',compress_level=1)
