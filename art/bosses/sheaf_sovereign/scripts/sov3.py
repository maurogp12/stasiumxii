# Sheaf Sovereign walk v3: jointed rig (hip/torso/head/scythe/hem strips), heavy regal stride,
# scythe pendulum, 6 orbiting sickles, falling straw bits (cut from the key), crown sheen glint.
import numpy as np, os, subprocess, sys, cv2
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as nd
import rig2
from rig2 import load, poly, rot, floor, fnt, KEY, DIRV, QW, QH
SC=0.38; DUR=8.0; CYC=4/3; SPEED=0.75      # 6 strides per loop, 6 tiles per loop -> seamless
def ease(x): x=np.clip(x,0,1); return x*x*(3-2*x)
def build(side):
    a=load(f'sov_{side}.png'); R=rig2.RIG[('sov',side)]; P=dict(R=R); sh=a.shape[:2]
    sick=rig2.sick_parts(a)
    if side=='front':   # 6th sickle overlaps the robe at lower right: lift it with a tight alpha-shape cut
        Y,X=np.mgrid[0:720,0:640]; mm=(((X>500)&(Y>385)&(Y<468))|((X>548)&(Y>385)&(Y<510)))&(a[...,3]>0)
        ys,xs=np.nonzero(mm); p=a.copy(); p[~mm,3]=0; a[mm,3]=0
        sick.append(Image.fromarray(p).crop((xs.min()-2,ys.min()-2,xs.max()+3,ys.max()+3)))
    if len(sick)<6: sick.append(sick[1].transpose(Image.FLIP_LEFT_RIGHT))   # back key: 5 free sickles painted, 6th = mirrored copy
    assert len(sick)==6, len(sick)
    P['sick']=sick
    sm=poly(sh,R['scy']['poly'])&(a[...,3]>0)
    scy=a.copy(); scy[~sm,3]=0; P['scy']=Image.fromarray(scy); P['hand']=R['hand']
    # fill under the scythe: robe texture only where robe exists on both sides, else open
    rb=((a[...,3]>120)&~sm).astype(np.uint8); n=30; L=np.zeros_like(rb); Rr=np.zeros_like(rb)
    for d in range(1,n): L[:,d:]|=rb[:,:-d]; Rr[:,:-d]|=rb[:,d:]
    U=np.zeros_like(rb); D=np.zeros_like(rb)
    for d in range(1,n): U[d:]|=rb[:-d]; D[:-d]|=rb[d:]
    robe=((L&Rr)|(U&D)).astype(bool)
    rgb=np.ascontiguousarray(a[...,:3]).copy()
    off=40 if side=='front' else -40; tex=np.roll(a,-off,axis=1); tm=np.roll(sm,-off,axis=1)
    fill=cv2.inpaint(rgb,cv2.dilate(sm.astype(np.uint8)*255,np.ones((3,3),np.uint8)),7,cv2.INPAINT_TELEA)
    fill=np.where(((tex[...,3]>120)&~tm)[...,None],tex[...,:3],fill)
    a=a.copy(); a[...,:3][sm]=fill[sm]; a[...,3][sm]=np.where(robe[sm],255,0)
    lab,nl=nd.label(a[...,3]>40); sz=nd.sum(np.ones(sh),lab,range(1,nl+1))
    a[...,3][(lab>0)&np.isin(lab,np.nonzero(sz<1500)[0]+1)]=0
    ys,xs=np.nonzero(a[...,3]>40); bot=ys.max(); P['bot']=bot; P['top']=ys.min(); P['xl'],P['xr']=xs.min(),xs.max()
    P['foot']=((xs[ys>bot-30].min()+xs[ys>bot-30].max())/2,bot)
    hip=R['hip']; Y=np.arange(720)[:,None].astype(float); X=np.arange(640)[None,:].astype(float)
    hb=poly(sh,R['head']); fh=cv2.GaussianBlur(hb.astype(np.float32),(0,0),7); fh=np.clip((fh-0.1)/0.8,0,1)
    up=a.copy(); up[...,3]=(up[...,3]*np.clip((hip+25-Y)/40,0,1)).astype(np.uint8); P['upper']=Image.fromarray(up)
    un=a.copy(); un[...,:3]=(un[...,:3]*0.8).astype(np.uint8); un[...,3]=(un[...,3]*np.clip((Y-(hip-40))/30,0,1)).astype(np.uint8); P['under']=Image.fromarray(un)
    hd=a.copy(); hd[...,3]=(hd[...,3]*fh).astype(np.uint8); P['head']=Image.fromarray(hd)
    # crown sheen mask: bright gold pixels in the top of the head box
    hy0=R['head'][0][1]; cr=(Y<hy0+70)&hb
    g=a[...,:3].astype(float); gold=np.clip((g[...,0]-90)/80,0,1)*(g[...,0]>g[...,2]+30)
    P['crown']=(gold*cr*(a[...,3]/255)).astype(np.float32)
    mid=hip+(bot-hip)*0.5; edges=np.linspace(P['xl']-5,P['xr']+5,6); strips=[]
    for i in range(5):
        x0,x1=edges[i],edges[i+1]; fe=16; wx=np.clip(np.minimum(X-x0+fe,x1-X+fe)/(2*fe),0,1)
        for j,(y0,y1) in enumerate(((hip,mid),(mid,bot+10))):
            wy=np.clip(np.minimum(Y-y0+fe*(2 if j==0 else 1),y1-Y+fe)/(2*fe),0,1)
            s=a.copy(); s[...,3]=(s[...,3]*wx*wy).astype(np.uint8); strips.append((i,j,Image.fromarray(s),((x0+x1)/2,y0)))
    P['strips']=strips
    # straw bits: small painted fragments from the cape fringe (gold strands)
    rng=np.random.default_rng(3); bits=[]
    cand=np.argwhere((gold>0.6)&(a[...,3]>200)&(Y>hip-60)&(Y<bot-40))
    for k in range(14):
        y,x=cand[rng.integers(len(cand))]; w,h=int(rng.integers(10,18)),int(rng.integers(18,30))
        b=a[y-h//2:y+h//2,x-w//2:x+w//2].copy()
        ys_,xs_=np.mgrid[0:b.shape[0],0:b.shape[1]]
        el=((xs_-b.shape[1]/2)/(b.shape[1]/2))**2+((ys_-b.shape[0]/2)/(b.shape[0]/2))**2
        gb=b[...,:3].astype(float); gm=np.clip((gb[...,0]-80)/70,0,1)
        b[...,3]=(b[...,3]*np.clip(1.2-el,0,1)*np.clip(gm*1.6,0,1)).astype(np.uint8)
        bits.append(Image.fromarray(b))
    P['bits']=bits
    return P
def pose(P,t,fwd):
    R=P['R']; ph=2*np.pi*t/CYC; OX,OY=260,200; W,Hh=1160,1080
    can=Image.new('RGBA',(W,Hh))
    def add(im,dx=0,dy=0): can.alpha_composite(im,(int(round(OX+dx)),int(round(OY+dy))))
    c2=np.cos(2*ph)                 # +1 at foot contact
    bob=16*c2+4                     # heavy drop on contact
    sway=8*np.sin(ph)
    hip=R['hip']; lead=1 if fwd[0]<0 else -1; fx0=P['foot'][0]
    # sickles: orbit ellipse around the chest, bob, small rock (never flipped)
    cx=(P['xl']+P['xr'])/2; cy=P['top']+(P['bot']-P['top'])*0.36; rx=(P["xr"]-P["xl"])*0.78; ry=rx*0.34
    SK=[]
    for i,s in enumerate(P['sick']):
        ang=2*np.pi*i/6+2*np.pi*t/DUR; z=np.sin(ang); scl=0.9+0.18*(z+1)/2
        x=cx+rx*np.cos(ang)+sway*0.4; y=cy+ry*z+12*np.sin(2*np.pi*t/2+i*1.05)+bob*0.25-60*np.cos(ang)
        ss=s.resize((max(1,int(s.width*scl)),max(1,int(s.height*scl))),Image.LANCZOS).rotate(10*np.sin(2*np.pi*t/4+i),resample=Image.BICUBIC,expand=True)
        if z<0: ss=Image.fromarray((np.array(ss)*np.array([0.78,0.78,0.78,1])).astype(np.uint8))
        SK.append((z,ss,x,y))
    for z,ss,x,y in sorted(SK,key=lambda q:q[0]):
        if z<0: add(ss,x-ss.width/2,y-ss.height/2)
    add(P['under'],sway*0.5,bob*0.7)
    # hem: cape sway lags the stride; lower segments kick forward alternately (left/right legs under the robe)
    for i,j,s,(cx_,y0) in P['strips']:
        k=(4-i)*0.45; legph=ph if i<2.5 else ph+np.pi
        a1=5*np.sin(ph-k)*lead+2*np.sin(2*ph-k)
        if j==0: add(rot(s,a1,(cx_,hip)),sway*0.5,bob*0.7)
        else:
            kick=max(0,np.sin(legph))*(1 if i!=2 else 0.5)
            a2=a1+6*np.sin(ph-k-1.1)*lead-9*kick*lead
            Ls=y0-hip; ex=Ls*np.sin(np.radians(-a1)); ey=Ls*(np.cos(np.radians(a1))-1)
            add(rot(s,a2,(cx_,y0)),ex+sway*0.5+fwd[0]*10*kick,ey+bob*0.7+fwd[1]*10*kick-6*kick)
    tilt=lead*4+1.5*np.sin(ph)*lead
    hx,hy=P['hand']; pend=10*np.sin(ph-1.0)*lead+3*lead       # pendulum, biased toward travel
    sc=rot(P['scy'],pend,(hx,hy))
    add(rot(sc,tilt,(fx0,hip)),sway,bob)
    add(rot(P['upper'],tilt,(fx0,hip)),sway,bob)
    hl=-6*max(0,np.cos(2*ph-0.9))
    hd=rot(P['head'],tilt+1.2*np.sin(2*ph-0.9),(fx0,hip))
    # crown glint: a sheen band sweeps across the crown every 2 s
    u=(t%2.0)/0.6
    if u<1:
        Y,X=np.mgrid[0:720,0:640]; band=np.exp(-((X-(P['xl']+(P['xr']-P['xl'])*(u*1.4-0.2))+(Y-100)*0.6)/14.0)**2)
        m=P['crown']*band*np.sin(np.pi*u)
        ha=np.array(hd).astype(float); ha[...,:3]=np.clip(ha[...,:3]+m[...,None]*np.array([140,110,60]),0,255)
        hd2=Image.fromarray(ha.astype(np.uint8))
    else: hd2=hd
    add(hd2,sway,bob+hl)
    for z,ss,x,y in sorted(SK,key=lambda q:q[0]):
        if z>=0: add(ss,x-ss.width/2,y-ss.height/2)
    fx,fy=OX+fx0,OY+P['foot'][1]; sq=0.025*c2
    can=can.resize((int(W*(1+sq)),int(Hh*(1-sq))),Image.BICUBIC); fx*=1+sq; fy*=1-sq
    can=can.rotate(lead*3,center=(fx,fy),resample=Image.BICUBIC)
    return can,(fx,fy)
def straw(g,P,px,py,fs,t,front,mir):
    # bits shed from the cape: fall with tumble, settle, then slide back with the floor (camera follows)
    N=10; rng=np.random.default_rng(11); bits=P['bits']
    for i in range(N):
        if (i%2==0)!=front: continue
        life=1.6; tt=(t+i*0.83)%2.0     # 2 s period -> 4 lives per loop (seamless)
        if tt>life: continue
        x0=px+rng.uniform(-55,55); y0=py-rng.uniform(60,150)
        fall=min(tt/0.9,1); yy=y0+(py+rng.uniform(-6,10)-y0)*fall**2
        back=-fs*SPEED*np.array([rig2.TW/2,rig2.TH/2])*tt  # world-locked: slide back with the floor
        xx=x0+back[0]+rng.uniform(-8,8)*np.sin(tt*6+i); yy=yy+back[1]
        b=bits[i%len(bits)]; b=b.resize((max(1,int(b.width*SC*2.2)),max(1,int(b.height*SC*2.2))),Image.LANCZOS)
        b=b.rotate((tt*300+i*40)*(1-fall*0.8),expand=True,resample=Image.BICUBIC)
        al=np.clip((life-tt)/0.4,0,1)*np.clip(tt/0.1,0,1)
        ba=np.array(b); ba[...,3]=(ba[...,3]*al).astype(np.uint8)
        g.alpha_composite(Image.fromarray(ba),(int(xx-b.width/2),int(yy-b.height/2)))
def frameS(PP,t):
    S=Image.new('RGB',(1920,1080))
    for k,dn in enumerate('nesw'):
        side,mir=KEY[dn]; vx,vy=DIRV[dn]
        fwd=np.array([vx*(-1 if mir else 1),vy],float); fwd/=np.linalg.norm(fwd)
        fs=np.array([vx,vy],float); fs/=np.linalg.norm(fs)
        g=floor(dn,(SPEED*t)%2)
        spr,(fx,fy)=pose(PP[side],t,fwd)
        if mir: spr=spr.transpose(Image.FLIP_LEFT_RIGHT); fx=spr.width-fx
        spr=spr.resize((int(spr.width*SC),int(spr.height*SC)),Image.LANCZOS); fx*=SC; fy*=SC
        px,py=480,340
        sh=Image.new('RGBA',g.size); sw=80; ImageDraw.Draw(sh).ellipse([px-sw,py-sw*.27,px+sw,py+sw*.27],fill=(0,0,0,130)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
        straw(g,PP[side],px,py,fs,t,False,mir)
        g.alpha_composite(spr,(int(px-fx),int(py-fy)))
        straw(g,PP[side],px,py,fs,t,True,mir)
        ImageDraw.Draw(g).text((16,10),dn.upper(),font=fnt,fill=(255,236,170,255),stroke_width=4,stroke_fill=(0,0,0,255))
        S.paste(g.convert('RGB'),((k%2)*QW,(k//2)*QH))
    return S
if __name__=='__main__':
    PP={s:build(s) for s in ('front','back')}
    if len(sys.argv)>1:
        for t in [float(x) for x in sys.argv[1].split(',')]: frameS(PP,t).save(f'/tmp/s3_{t}.png')
        sys.exit()
    d='/tmp/_s3'; os.makedirs(d,exist_ok=True)
    for i in range(int(DUR*24)): frameS(PP,i/24).save(f'{d}/{i:04d}.png')
    subprocess.run(f'ffmpeg -y -loglevel error -framerate 24 -i {d}/%04d.png -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 16 -movflags +faststart /workspace/foe_walks/harvest_v2/sheaf_sovereign_walk_4dir_v3.mp4',shell=True,check=True)
