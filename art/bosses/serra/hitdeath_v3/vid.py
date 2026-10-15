import numpy as np, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
FPS=24; K=0.66; CW,CH=640,440; BX,BY=320,404
DV={'n':(-2,-1),'e':(2,-1),'s':(2,1),'w':(-2,1)}; TF={'n':'S','e':'W','s':'N','w':'E'}
def cells(p,cw,k=1): im=Image.open(p).convert('RGBA'); fs=[im.crop((x*cw,0,x*cw+cw,im.height)) for x in range(im.width//cw)]; return [f.resize((round(f.width*k),round(f.height*k)),Image.LANCZOS) for f in fs]
SR={(a,d):cells(f'serra14_{a}_{d}.png',CW,K) for a in ('idle','hit','death') for d in 'nesw'}
CH_={'ij':dict(cw=161,piv=(80,133),k=1.03,p='/workspace/art/ironjaw_full/v2/{a}/ironjaw_{a}_{K}_strip.png'),
     'ke':dict(cw=116,piv=(68,141),k=0.95,p='/workspace/art/kestrel_full/v3/{a}/kestrel_{a}_{K}_strip.png')}
SP={(c,a,Kk):cells(v['p'].format(a=a,K=Kk),v['cw'],v['k']) for c,v in CH_.items() for a in ('idle','attack') for Kk in 'NESW'}
fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',56); TWp,THp=120,60
def floor():
    im=Image.new('RGBA',(960,540),(16,18,24,255)); d=ImageDraw.Draw(im)
    for i in range(-10,11):
        for j in range(-10,11):
            x=480+(i-j)*TWp/2; y=312+(i+j)*THp/2
            d.polygon([(x,y-THp/2),(x+TWp/2,y),(x,y+THp/2),(x-TWp/2,y)],fill=(38,42,54,255) if (i+j)%2 else (30,34,44,255),outline=(48,54,68,255))
    return im
FL=floor()
# timeline (s): attacker, attack start ; impact = start+3/12
ATK=[('ij',0.6),('ke',2.2),('ij',3.8)]; IMP=[s+3/12 for _,s in ATK]; DEATH=IMP[2]
def serra(t,dn):
    for i in (0,1):
        u=t-IMP[i]
        if 0<=u<8/12: return SR[('hit',dn)][int(u*12)]
    if t>=DEATH: return SR[('death',dn)][min(21,int((t-DEATH)*12))]
    return SR[('idle',dn)][int(t*12)%12]
def soft(fn,blur,col,al):
    L=Image.new('L',(960,540)); fn(ImageDraw.Draw(L)); L=L.filter(ImageFilter.GaussianBlur(blur)); c=Image.new('RGBA',(960,540),col+(0,)); c.putalpha(L.point(lambda v:int(v*al))); return c
def frame(n):
    t=n/FPS; G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'):
        g=FL.copy(); dv=np.array(DV[dn],float); dv/=np.linalg.norm(dv)
        C=np.array([480,312]); sp=C-dv*95; tp=C+dv*105
        T={'ij':tp+np.array([-50,-6]),'ke':tp+np.array([50,6])}
        items=[(sp[1],serra(t,dn),(round(sp[0]-BX*K),round(sp[1]-BY*K)))]
        for c,p in T.items():
            v=CH_[c]; fs=SP[(c,'idle',TF[dn])]; im=fs[int(t*6)%len(fs)]
            for a_,s_ in ATK:
                if a_==c and 0<=t-s_<0.5: fs=SP[(c,'attack',TF[dn])]; im=fs[min(5,int((t-s_)*12))]
            sh=Image.new('RGBA',(960,540)); ImageDraw.Draw(sh).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(2)))
            items.append((p[1],im,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
        for _,im,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(im,xy)
        hp=sp+[0,-95]
        for (a_,s_),im_ in zip(ATK,IMP):
            if a_=='ke' and s_+2/12<=t<im_:   # arrow streak
                u=(t-s_-2/12)/(im_-s_-2/12); P0=T['ke']+[0,-70]; P1=P0+(hp-P0)*u; P2=P0+(hp-P0)*max(0,u-0.35)
                g.alpha_composite(soft(lambda d:d.line([tuple(P2),tuple(P1)],fill=255,width=3),1,(230,220,190),0.9))
            u=t-im_
            if 0<=u<0.3:   # small impact flash on Serra
                g.alpha_composite(soft(lambda d:[d.line([tuple(hp+r*np.array([np.cos(a),np.sin(a)])*0.4),tuple(hp+r*np.array([np.cos(a),np.sin(a)]))],fill=255,width=3) for a,r in zip(np.linspace(0,6.28,9)[:-1],[34+60*u]*8)],1.2,(200,225,255),0.8*(1-u/0.3)))
        d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
        cc=np.array([150,48]); nn=np.array([-dv[1],dv[0]]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
        d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+nn*14),tuple(b_-dv*6-nn*14)],fill=(140,200,255,255))
        G.alpha_composite(g,((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_f',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame(i).save(f'_f/{i:05d}.png',compress_level=1)
