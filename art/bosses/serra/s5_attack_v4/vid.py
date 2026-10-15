import numpy as np, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
FPS=24; AF=12; K=0.66; CW,CH=640,440; BX,BY=320,404
DV={'n':(-2,-1),'e':(2,-1),'s':(2,1),'w':(-2,1)}; TF={'n':'S','e':'W','s':'N','w':'E'}
FR={d:[Image.open(f'serra5_attack_{d}.png').crop((i*CW,0,i*CW+CW,CH)).resize((round(CW*K),round(CH*K)),Image.LANCZOS) for i in range(16)] for d in 'nesw'}
import json
TRK=json.load(open('tip_track.json')); MAPK={'n':('back',True),'e':('back',False),'s':('front',True),'w':('front',False)}
def strip(p,cw):
    im=Image.open(p).convert('RGBA'); return [im.crop((x*cw,0,x*cw+cw,im.height)) for x in range(im.width//cw)]
CHR={'ij':dict(cw=161,piv=(80,133),k=1.03,p='/workspace/art/ironjaw_full/v2/{a}/ironjaw_{a}_{K}_strip.png'),'ke':dict(cw=116,piv=(68,141),k=0.95,p='/workspace/art/kestrel_full/v3/{a}/kestrel_{a}_{K}_strip.png')}
SPR={(c,a,K_):[f.resize((round(f.width*v['k']),round(f.height*v['k'])),Image.LANCZOS) for f in strip(v['p'].format(a=a,K=K_),v['cw'])] for c,v in CHR.items() for a in ('idle','hit') for K_ in 'NESW'}
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
        sp=np.array([480,312])-dv*100; tp=np.array([480,312])+dv*95
        lt=t%PER; fi=min(15,int(lt*AF)); hit_t=9/AF; ag=lt-hit_t
        items=[]
        sim=FR[dn][fi]; items.append((sp[1],sim,(round(sp[0]-BX*K),round(sp[1]-BY*K))))
        tf=TF[dn]
        T={'ij':tp+np.array([-46,-5]),'ke':tp+np.array([46,5])}; HITS=[]
        for i_,(c_,p_) in enumerate(T.items()):
            v=CHR[c_]; a2=ag-0.04*i_
            if 0<=a2<0.33: fs=SPR[(c_,'hit',tf)]; tim=tint(fs[min(len(fs)-1,int(a2*12))],0.14*(1-a2/0.33))
            else: fs=SPR[(c_,'idle',tf)]; tim=fs[int(t*6)%len(fs)]
            push=dv*(7*max(0,1-a2/0.25) if 0<=a2<0.25 else 0); tq=p_+push; HITS.append((a2,tq))
            sh=Image.new('RGBA',(960,540)); ImageDraw.Draw(sh).ellipse([tq[0]-30,tq[1]-8,tq[0]+30,tq[1]+8],fill=(0,0,0,90)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(2)))
            items.append((tq[1],tim,(round(tq[0]-v['piv'][0]*v['k']),round(tq[1]-v['piv'][1]*v['k']))))
        for _,im,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(im,xy)
        # blizzard stream: cone from the staff tip to the targets, crystals + snow streaks
        k_,mir=MAPK[dn]; tr=TRK[k_][fi]; tip=np.array([CW-tr[1] if mir else tr[1],tr[2]]); tipv=sp+(tip-[BX,BY])*K
        su=lt-7/AF
        if 0<=su<0.42:
            tgt=tp+[0,-55]; dvec=tgt-tipv; Ld=np.linalg.norm(dvec); u_=dvec/Ld; nn=np.array([-u_[1],u_[0]])
            fade=1 if su<0.3 else 1-(su-0.3)/0.12
            g.alpha_composite(soft(lambda d:d.polygon([tuple(tipv+nn*6),tuple(tgt+nn*58),tuple(tgt-nn*58),tuple(tipv-nn*6)],fill=255),14,(110,165,225),0.32*fade))
            rr=np.random.default_rng(int(su*1000)%7+1)
            def crys(d):
                for i in range(30):
                    ph=(rr.uniform(0,1)+su*2.6)%1.0; w_=rr.uniform(-1,1)*(6+52*ph); p=tipv+dvec*ph+nn*w_; s_=rr.uniform(2.5,5)
                    d.polygon([tuple(p-u_*s_*2.2),tuple(p+nn*s_*.6),tuple(p+u_*s_*2.2),tuple(p-nn*s_*.6)],fill=255)
            g.alpha_composite(soft(crys,0.5,(205,232,255),0.95*fade))
            def snow(d):
                for i in range(18):
                    ph=(rr.uniform(0,1)+su*3.2)%1.0; w_=rr.uniform(-1,1)*(6+48*ph); p=tipv+dvec*ph+nn*w_; d.line([tuple(p-u_*14),tuple(p+u_*4)],fill=255,width=1)
            g.alpha_composite(soft(snow,0.6,(225,240,255),0.8*fade))
        for a2,tq in HITS:
            if 0<=a2<0.5:   # crystals shatter on target + frost-crystal crust flash
                u=a2/0.5; c=tq+[0,-55]
                if u<0.5: g.alpha_composite(soft(lambda d:d.ellipse([c[0]-34,c[1]-44,c[0]+34,c[1]+44],fill=255),10,(150,205,255),0.22*(1-u/0.5)))
                rr=np.random.default_rng(13)
                def crust(d):
                    for i in range(9):
                        x=tq[0]+rr.uniform(-26,26); y=tq[1]-rr.uniform(4,70); h=rr.uniform(8,16)*(1-0.6*u); w=rr.uniform(2.5,4)
                        d.polygon([(x-w,y),(x,y-h),(x+w,y),(x,y+h*0.3)],fill=255)
                g.alpha_composite(soft(crust,0.5,(200,230,255),0.8*(1-u)))
                def shat(d):
                    for i in range(16):
                        a=rr.uniform(-np.pi,0.3); s_=rr.uniform(.4,1); x=c[0]+np.cos(a)*60*s_*u; y=c[1]+np.sin(a)*45*s_*u+45*u*u; r=rr.uniform(2,4)*(1-.5*u)
                        d.polygon([(x,y-r*1.6),(x+r,y),(x,y+r*1.6),(x-r,y)],fill=255)
                g.alpha_composite(soft(shat,0.7,(195,228,255),0.9*(1-u)))
        d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
        cc=np.array([150,48]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
        n_=np.array([-dv[1],dv[0]]); d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+n_*14),tuple(b_-dv*6-n_*14)],fill=(140,200,255,255))
        G.alpha_composite(g,((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_f',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame(i).save(f'_f/{i:05d}.png',compress_level=1)
