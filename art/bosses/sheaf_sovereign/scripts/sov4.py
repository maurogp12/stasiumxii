# Sheaf Sovereign v4: spectral-king float (Warden v6 float rig adapted) + 6 spinning orbiting sickles.
import numpy as np, os, subprocess, sys, cv2
from PIL import Image, ImageDraw, ImageFilter
import sov3, rig4
from rig2 import rot, floor, fnt, KEY, DIRV, QW, QH
SC=0.38; DUR=8.0
def prep(P):
    P=rig4.prep(P)    # ragged smoke dissolve on the hem + gold glow layer
    a=np.array(P['head']).astype(float); R=P['R']; hy0=R['head'][0][1]
    Y=np.arange(720)[:,None]; band=((Y>hy0+60)&(Y<hy0+150)).astype(float)
    g=np.clip((a[...,0]-90)/80,0,1)*(a[...,0]>a[...,2]+30)*(a[...,3]/255)*band
    m=np.zeros_like(a); m[...,0]=255; m[...,1]=200; m[...,2]=90; m[...,3]=g*255
    P['mask']=Image.fromarray(m.astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))
    return P
def sickles(P,t,sway,bob):
    cx=(P['xl']+P['xr'])/2; cy=P['top']+(P['bot']-P['top'])*0.38; rx=(P['xr']-P['xl'])*0.8; ry=rx*0.33; out=[]
    for i,s in enumerate(P['sick']):
        for g_,dt in ((0,0),(1,0.05),(2,0.10),(3,0.15)):      # current + 3 fading trail samples
            tt=t-dt; ang=2*np.pi*i/6+2*np.pi*tt/4.0; z=np.sin(ang); scl=0.88+0.22*(z+1)/2
            x=cx+rx*np.cos(ang)+sway*0.4; y=cy+ry*z+10*np.sin(2*np.pi*tt/2+i*1.05)+bob*0.3-50*np.cos(ang)
            spin=-360*tt/2.0+i*60                                  # own-axis spin, 1 rev / 2 s
            ss=s.resize((max(1,int(s.width*scl)),max(1,int(s.height*scl))),Image.LANCZOS).rotate(spin,resample=Image.BICUBIC,expand=True)
            k=[1,0.22,0.13,0.07][g_]; d=0.75 if z<0 else 1.0
            sa=np.array(ss).astype(float); sa[...,:3]*=d; sa[...,3]*=k; out.append((z,g_,Image.fromarray(sa.astype(np.uint8)),x,y))
    return out
def pose(P,t,fwd):
    R=P['R']; OX,OY=260,200; W,Hh=1160,1080; can=Image.new('RGBA',(W,Hh))
    def add(im,dx=0,dy=0): can.alpha_composite(im,(int(round(OX+dx)),int(round(OY+dy))))
    hb=np.pi*t; bob=6*np.sin(hb); lead=1 if fwd[0]<0 else -1; hip=R['hip']; fx0=P['foot'][0]
    drift=10*np.sin(2*np.pi*t/4)
    SK=sickles(P,t,drift,bob)
    for z,g_,ss,x,y in sorted(SK,key=lambda q:(q[0],-q[1])):
        if z<0: add(ss,x-ss.width/2,y-ss.height/2)
    add(P['under'],drift*0.5,bob*0.6)
    for i,j,s,(cx,y0) in P['strips']:
        k=(4-i)*0.5; a1=lead*5+3*np.sin(hb*2-k)*lead
        if j==0: add(rot(s,a1,(cx,hip)),drift*0.5,bob*0.6)
        else:
            a2=a1+lead*6+4*np.sin(hb*2-k-1.1)*lead; L=y0-hip; ex=L*np.sin(np.radians(-a1)); ey=L*(np.cos(np.radians(a1))-1)
            add(rot(s,a2,(cx,y0)),ex+drift*0.5,ey+bob*0.6)
    tilt=lead*3+1.5*np.sin(hb-0.6)*lead
    hx,hy=P['hand']; pend=9*np.sin(hb-1.0)*lead+3*lead
    add(rot(rot(P['scy'],pend,(hx,hy)),tilt,(fx0,hip)),drift,bob)
    add(rot(P['upper'],tilt,(fx0,hip)),drift,bob)
    pulse=0.5+0.5*np.sin(2*np.pi*t/2)
    ga=np.array(P['glow']); ga[...,3]=(ga[...,3]*(0.2+0.3*pulse)).astype(np.uint8); add(rot(Image.fromarray(ga),tilt,(fx0,hip)),drift,bob)
    hd=rot(P['head'],tilt+1.2*np.sin(hb-0.9),(fx0,hip))
    u=(t%2.0)/0.6
    if u<1:
        Y,X=np.mgrid[0:720,0:640]; band=np.exp(-((X-(P['xl']+(P['xr']-P['xl'])*(u*1.4-0.2))+(Y-100)*0.6)/14.0)**2)
        m=P['crown']*band*np.sin(np.pi*u); ha=np.array(hd).astype(float); ha[...,:3]=np.clip(ha[...,:3]+m[...,None]*np.array([150,120,60]),0,255); hd=Image.fromarray(ha.astype(np.uint8))
    hl=-3*max(0,np.sin(hb-0.9)); add(hd,drift,bob+hl)
    ma=np.array(P['mask']); ma[...,3]=(ma[...,3]*(0.15+0.55*(0.5+0.5*np.sin(2*np.pi*t/2-1.0)))).astype(np.uint8)
    add(rot(Image.fromarray(ma),tilt+1.2*np.sin(hb-0.9),(fx0,hip)),drift,bob+hl)
    for z,g_,ss,x,y in sorted(SK,key=lambda q:(q[0],-q[1])):
        if z>=0: add(ss,x-ss.width/2,y-ss.height/2)
    fx,fy=OX+fx0,OY+P['foot'][1]
    can=can.rotate(lead*3,center=(fx,fy),resample=Image.BICUBIC)
    return can,(fx,fy)
def wisps(g,P,px,py,fs,t,front):
    # straw wisps peel off the hem and stream back against travel (2 s life, loop-safe)
    rng=np.random.default_rng(5); back=-fs
    for i in range(12):
        if (i%3==0)!=front: rng.random(4); continue
        ph,sx,sp,rr=rng.random(4); a=(t/2+ph)%1.0
        x=px+(sx-0.5)*90*(1-a*0.5)+back[0]*a*120+(-back[1])*12*np.sin(a*5+i); y=py-14+back[1]*a*60-a*40+4*np.sin(a*6+i)
        b=P['bits'][i%len(P['bits'])]; b=b.resize((max(1,int(b.width*SC*2)),max(1,int(b.height*SC*2))),Image.LANCZOS).rotate(a*200*(1 if sp>0.5 else -1)+i*30,expand=True,resample=Image.BICUBIC)
        ba=np.array(b); ba[...,3]=(ba[...,3]*np.sin(np.pi*a)).astype(np.uint8); g.alpha_composite(Image.fromarray(ba),(int(x-b.width/2),int(y-b.height/2)))
def frameS(PP,t):
    S=Image.new('RGB',(1920,1080))
    for k,dn in enumerate('nesw'):
        side,mir=KEY[dn]; vx,vy=DIRV[dn]
        fwd=np.array([vx*(-1 if mir else 1),vy],float); fwd/=np.linalg.norm(fwd)
        fs=np.array([vx,vy],float); fs/=np.linalg.norm(fs)
        g=floor(dn,t%2)
        spr,(fx,fy)=pose(PP[side],t,fwd)
        if mir: spr=spr.transpose(Image.FLIP_LEFT_RIGHT); fx=spr.width-fx
        spr=spr.resize((int(spr.width*SC),int(spr.height*SC)),Image.LANCZOS); fx*=SC; fy*=SC
        h=17.5+2.5*np.sin(np.pi*t); px,py=480,340; k_=1-(h-15)/5*0.25
        sh=Image.new('RGBA',g.size); sw=76*k_; ImageDraw.Draw(sh).ellipse([px-sw,py-sw*.27,px+sw,py+sw*.27],fill=(0,0,0,int(120*k_*0.85)))
        g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(float(6+3*(1-k_)))))
        rig4.smoke(g,px,py-h,fs,t,False); wisps(g,PP[side],px,py-h,fs,t,False)
        g.alpha_composite(spr,(int(px-fx),int(py-fy-h)))
        rig4.smoke(g,px,py-h,fs,t,True); wisps(g,PP[side],px,py-h,fs,t,True)
        ImageDraw.Draw(g).text((16,10),dn.upper(),font=fnt,fill=(255,236,170,255),stroke_width=4,stroke_fill=(0,0,0,255))
        S.paste(g.convert('RGB'),((k%2)*QW,(k//2)*QH))
    return S
if __name__=='__main__':
    PP={s:prep(sov3.build(s)) for s in ('front','back')}
    if len(sys.argv)>1:
        for t in [float(x) for x in sys.argv[1].split(',')]: frameS(PP,t).save(f'/tmp/s4_{t}.png')
        sys.exit()
    d='/tmp/_s4'; os.makedirs(d,exist_ok=True)
    for i in range(int(DUR*24)): frameS(PP,i/24).save(f'{d}/{i:04d}.png')
    subprocess.run(f'ffmpeg -y -loglevel error -framerate 24 -i {d}/%04d.png -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 16 -movflags +faststart /workspace/foe_walks/harvest_v2/sheaf_sovereign_walk_4dir_v4.mp4',shell=True,check=True)
