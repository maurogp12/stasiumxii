import numpy as np, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFilter
import rig3
from rig3 import build, rot
from rig2 import KEY, DIRV, QW, QH, floor, fnt
SC=0.38
def smokefade(im,bot,seed):
    a=np.array(im); H,W=a.shape[:2]; rng=np.random.default_rng(seed)
    n=np.array(Image.fromarray((rng.random((H//8+1,W//8+1))*255).astype(np.uint8)).resize((W,H),Image.BICUBIC))[:H,:W]/255.
    Y=np.arange(H)[:,None]; f=np.clip((bot-20-Y)/120+ (n-0.5)*0.6,0,1)   # ragged dissolve over the bottom ~120 px
    a[...,3]=(a[...,3]*f).astype(np.uint8); return Image.fromarray(a)
def prep(P):
    b=P['bot']; P['under']=smokefade(P['under'],b,1)
    P['strips']=[(i,j,smokefade(s,b,2+i) if j==1 else s,c) for i,j,s,c in P['strips']]
    u=np.array(P['upper']).astype(float); r,g,bb=u[...,0],u[...,1],u[...,2]
    m=np.clip((r-110)/60,0,1)*np.clip((g-70)/50,0,1)*(r>bb+40)*(u[...,3]/255)   # gold rib glow pixels
    gl=np.zeros_like(u); gl[...,0]=255; gl[...,1]=200; gl[...,2]=90; gl[...,3]=m*255
    P['glow']=Image.fromarray(gl.astype(np.uint8)).filter(ImageFilter.GaussianBlur(4)); P['glow2']=Image.fromarray(gl.astype(np.uint8))
    return P
def pose(P,t,fwd):
    R=P['R']; OX,OY=200,140; W,Hh=1040,960; can=Image.new('RGBA',(W,Hh))
    def add(im,dx=0,dy=0): can.alpha_composite(im,(int(round(OX+dx)),int(round(OY+dy))))
    hb=np.pi*t                                # 2 s bob
    bob=6*np.sin(hb)                          # +-6 key px around the hover (hover handled on screen)
    lead=1 if fwd[0]<0 else -1; hip=R['hip']; fx0=P['foot'][0]
    drift=10*np.sin(2*np.pi*t/4)              # slow side drift, 4 s
    add(P['under'],drift*0.5,bob*0.6)
    for i,j,s,(cx,y0) in P['strips']:
        k=(4-i)*0.5
        a1=lead*5+3*np.sin(hb*2-k)*lead      # streams back against travel, rippling
        if j==0: add(rot(s,a1,(cx,hip)),drift*0.5,bob*0.6)
        else:
            a2=a1+lead*6+4*np.sin(hb*2-k-1.1)*lead
            L=y0-hip; ex=L*np.sin(np.radians(-a1)); ey=L*(np.cos(np.radians(a1))-1)
            add(rot(s,a2,(cx,y0)),ex+drift*0.5,ey+bob*0.6)
    tilt=lead*3+1.5*np.sin(hb-0.6)*lead
    hx,hy=P['hand']; pend=9*np.sin(hb-1.0)*lead      # pendulum lags the bob
    sc=rot(P['scy'],pend,(hx,hy)); sc=Image.fromarray(np.roll(np.array(sc),int(round(5*np.sin(2*hb-1.3))),axis=0))
    add(rot(sc,tilt,(fx0,hip)),drift,bob)
    add(rot(P['upper'],tilt,(fx0,hip)),drift,bob)
    pulse=0.5+0.5*np.sin(2*np.pi*t/2*2)      # 1 s pulse
    g=P['glow'].copy(); ga=np.array(g); ga[...,3]=(ga[...,3]*(0.25+0.35*pulse)).astype(np.uint8)
    add(rot(Image.fromarray(ga),tilt,(fx0,hip)),drift,bob)
    hd=rot(P['head'],tilt+1.2*np.sin(hb-0.9),(fx0,hip)); add(hd,drift,bob-3*max(0,np.sin(hb-0.9)))
    fx,fy=OX+fx0,OY+P['foot'][1]
    can=can.rotate(lead*3,center=(fx,fy),resample=Image.BICUBIC)
    return can,(fx,fy)
def smoke(g,px,py,fwd_s,t,front):
    lay=Image.new('RGBA',g.size); d=ImageDraw.Draw(lay); N=22; rng=np.random.default_rng(7)
    ph=rng.random(N); sx=rng.uniform(-45,45,N); cr=rng.uniform(0.6,1.4,N); emb=rng.random(N)<0.3
    back=-fwd_s
    for i in range(N):
        if (i%3==0)!=front: continue
        a=(t/2+ph[i])%1.0                     # 2 s life, loops
        dist=a*110; curl=14*np.sin(a*5+i)*cr[i]
        x=px+sx[i]*(1-a*0.5)+back[0]*dist+(-back[1])*curl; y=py-8+back[1]*dist*0.5+back[0]*curl*0.3-a*35
        r=(9+a*24)*cr[i]; al=int(185*np.sin(np.pi*a)**1.2*(0.6 if front else 1))
        col=(96,74,44,al) if emb[i] else (58,56,66,al)
        d.ellipse([x-r*1.4,y-r*0.7,x+r*1.4,y+r*0.7],fill=col)
    lay=lay.filter(ImageFilter.GaussianBlur(6)); g.alpha_composite(lay)
    if not front:
        e=Image.new('RGBA',g.size); de=ImageDraw.Draw(e)
        for i in range(N):
            if not emb[i]: continue
            a=(t/2+ph[i]+0.1)%1.0; x=px+sx[i]*0.6+back[0]*a*120; y=py-12+back[1]*a*60-a*45+6*np.sin(a*7+i)
            de.ellipse([x-1.6,y-1.6,x+1.6,y+1.6],fill=(255,190,90,int(170*np.sin(np.pi*a))))
        g.alpha_composite(e.filter(ImageFilter.GaussianBlur(0.8)))
def frameS(PP,t):
    S=Image.new('RGB',(1920,1080))
    for k,dn in enumerate('nesw'):
        side,mir=KEY[dn]; vx,vy=DIRV[dn]
        fwd=np.array([vx*(-1 if mir else 1),vy],float); fwd/=np.linalg.norm(fwd)
        fs=np.array([vx,vy],float); fs/=np.linalg.norm(fs)          # screen travel dir
        g=floor(dn,t%2)
        spr,(fx,fy)=pose(PP[side],t,fwd)
        if mir: spr=spr.transpose(Image.FLIP_LEFT_RIGHT); fx=spr.width-fx
        spr=spr.resize((int(spr.width*SC),int(spr.height*SC)),Image.LANCZOS); fx*=SC; fy*=SC
        h=17.5+2.5*np.sin(np.pi*t)            # hover 15-20 px screen, 2 s
        px,py=480,330; k_=1-(h-15)/5*0.25
        sh=Image.new('RGBA',g.size); sw=72*k_; ImageDraw.Draw(sh).ellipse([px-sw,py-sw*.27,px+sw,py+sw*.27],fill=(0,0,0,int(120*k_*0.85)))
        g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(float(6+3*(1-k_)))))
        smoke(g,px,py-h,fs,t,False)
        g.alpha_composite(spr,(int(px-fx),int(py-fy-h)))
        smoke(g,px,py-h,fs,t,True)
        ImageDraw.Draw(g).text((16,10),dn.upper(),font=fnt,fill=(255,236,170,255),stroke_width=4,stroke_fill=(0,0,0,255))
        S.paste(g.convert('RGB'),((k%2)*QW,(k//2)*QH))
    return S
if __name__=='__main__':
    PP={s:prep(build(s)) for s in ('front','back')}
    if len(sys.argv)>1:
        for t in [float(x) for x in sys.argv[1].split(',')]: frameS(PP,t).save(f'/tmp/r6_{t}.png')
        sys.exit()
    d='/tmp/_r6_war'; os.makedirs(d,exist_ok=True)
    for i in range(192): frameS(PP,i/24).save(f'{d}/{i:04d}.png')
    subprocess.run(f'ffmpeg -y -loglevel error -framerate 24 -i {d}/%04d.png -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 16 -movflags +faststart /workspace/foe_walks/harvest_v2/warden_walk_4dir_v6.mp4',shell=True,check=True)
