import numpy as np, os, subprocess, sys, cv2
from PIL import Image, ImageDraw, ImageFilter
import rig2
from rig2 import load, poly, rot, floor, fnt, KEY, DIRV, QW, QH
def build(side):
    a=load('war_front_v5.png' if side=='front' else f'war_{side}.png'); R=dict(rig2.RIG[('war',side)]); P=dict(R=R); sh=a.shape[:2]
    if side=='front': R['head']=[(285,38),(382,38),(382,172),(285,172)]   # repainted v5 front key: hood moved, scythe now on viewer's left
    P['blade']=None
    ys,xs=np.nonzero(a[...,3]>40); bot=ys.max(); P['bot']=bot; P['foot']=((xs[ys>bot-30].min()+xs[ys>bot-30].max())/2,bot); P['xl'],P['xr']=xs.min(),xs.max()
    hip=R['hip']; Y=np.arange(720)[:,None].astype(float); X=np.arange(640)[None,:].astype(float)
    # scythe: cut cleanly (blade over open grey, shaft strip over robe filled from robe texture); hand stays on the torso
    if side=='front': SP=dict(poly=[(0,15),(212,15),(212,262),(150,300),(70,300),(60,330),(0,330)],shaft=[(176,282),(230,672)],w=38,hand=(178,282),handbox=[(160,262),(200,262),(200,300),(160,300)])
    else: SP=dict(poly=[(355,15),(620,15),(620,340),(500,340),(442,150),(428,250),(392,255),(385,100)],shaft=[(405,258),(396,610)],w=34,hand=(405,255),handbox=[(392,238),(430,238),(430,280),(392,280)])
    sm=(poly(sh,SP['poly'])|poly(sh,SP['shaft'],SP['w']))&(a[...,3]>0)&~poly(sh,SP['handbox'])
    scy=a.copy(); scy[~sm,3]=0; P['scy']=Image.fromarray(scy); P['hand']=SP['hand']
    rgb=np.ascontiguousarray(a[...,:3]).copy(); bodyc=a[...,:3][(a[...,3]>200)&~sm].mean(0)
    rgb[(a[...,3]<200)&~sm]=bodyc.astype(np.uint8)          # transparent pixels read as robe tone, not matte grey
    fill=cv2.inpaint(rgb,cv2.dilate(sm.astype(np.uint8)*255,np.ones((3,3),np.uint8)),9,cv2.INPAINT_TELEA)
    from scipy import ndimage as nd
    rb=((a[...,3]>120)&~sm).astype(np.uint8); n=26
    left=np.zeros_like(rb); right=np.zeros_like(rb)
    for d in range(1,n):
        left[:,d:]|=rb[:,:-d]; right[:,:-d]|=rb[:,d:]
    robe=(left&right).astype(bool); hy=bot-80; robe[hy:]|=(left|right).astype(bool)[hy:]   # hem: fringe spreads past the shaft, fill it        # robe only where there is robe on both sides of the shaft
    off=48 if side=='front' else -48; tex=np.roll(a,-off,axis=1)   # robe texture patch from beside the shaft
    tex=np.roll(tex,0,axis=0); fill=np.where((tex[...,3:]>120)&~np.roll(sm,-off,axis=1)[...,None],tex[...,:3],fill)
    a=a.copy(); a[...,:3][sm]=fill[sm]; a[...,3][sm]=np.where(robe[sm],255,0)
    lab,nl=nd.label(a[...,3]>40); sz=nd.sum(np.ones(sh),lab,range(1,nl+1)); main=sz.argmax()+1
    a[...,3][(lab>0)&(lab!=main)&np.isin(lab,np.nonzero(sz<1500)[0]+1)&poly(sh,SP['poly']+[],0) if False else (lab>0)&np.isin(lab,np.nonzero(sz<1500)[0]+1)]=0   # drop orphan shaft fragments
    shaft=None
    fh=cv2.GaussianBlur(poly(sh,R['head']).astype(np.float32),(0,0),9); fh=np.clip((fh-0.1)/0.8,0,1)
    wu=np.clip((hip+25-Y)/40,0,1)
    up=a.copy(); up[...,3]=(up[...,3]*wu*(1-fh)).astype(np.uint8)
    if shaft is not None:
        so=Image.fromarray(shaft); so.alpha_composite(Image.fromarray(up)); up=np.array(so)   # whole shaft, torso drawn over the hand as painted
    P['upper']=Image.fromarray(up)
    if P['blade'] is not None: P['blade']=Image.fromarray(P['blade']).rotate(-50,center=(432,40),resample=Image.BICUBIC)   # arc the mirrored blade up over the hood
    un=a.copy(); un[...,3]=(un[...,3]*np.clip((Y-(hip-40))/30,0,1)).astype(np.uint8); P['under']=Image.fromarray(un)   # robe backdrop below the waist only
    # head: feathered copy (original stays underneath; it only ever rises, so nothing is uncovered)
    hd=a.copy(); hd[...,3]=(hd[...,3]*fh).astype(np.uint8); P['head']=Image.fromarray(hd)
    mid=hip+(bot-hip)*0.5; edges=np.linspace(P['xl']-5,P['xr']+5,6); strips=[]
    for i in range(5):
        x0,x1=edges[i],edges[i+1]; fe=16; wx=np.clip(np.minimum(X-x0+fe,x1-X+fe)/(2*fe),0,1)
        for j,(y0,y1) in enumerate(((hip,mid),(mid,bot+10))):
            wy=np.clip(np.minimum(Y-y0+fe*(2 if j==0 else 1),y1-Y+fe)/(2*fe),0,1)
            s=a.copy(); s[...,3]=(s[...,3]*wx*wy).astype(np.uint8); strips.append((i,j,Image.fromarray(s),((x0+x1)/2,y0)))
    P['strips']=strips
    fx=P['foot'][0]; P['roots']=[]
    for dx in (-55,55):
        r=a.copy(); m=poly(sh,[(fx+dx-34,bot-55),(fx+dx+34,bot-55),(fx+dx+34,bot+2),(fx+dx-34,bot+2)]); r[~m,3]=0
        r[...,:3]=(r[...,:3]*0.8).astype(np.uint8); yy,xx=np.nonzero(r[...,3]>0)
        P['roots'].append((Image.fromarray(r).crop((xx.min(),yy.min(),xx.max()+1,yy.max()+1)),(fx+dx,bot)))
    return P
def flip_blade(a,sx=432):
    # front key's blade opens to the right; mirror only the blade about the shaft top so it opens to the travel side
    Y,X=np.mgrid[0:720,0:640]; m=(((X>=445)&(Y<=120))|((X>=470)&(Y<312)))&(a[...,3]>0)
    bl=a.copy(); bl[~m,3]=0; a=a.copy(); a[m,3]=0
    fl=np.zeros_like(bl); xs=np.arange(640); nx=2*sx-xs; ok=(nx>=0)&(nx<640); fl[:,nx[ok]]=bl[:,xs[ok]]
    return a,fl
STEP=141.0   # key px per stride-half: matches 1 tile step per 1 s cycle on screen (scale 0.38)
def pose(P,t,fwd):
    R=P['R']; ph=2*np.pi*t; OX,OY=200,140; W,Hh=1040,960
    can=Image.new('RGBA',(W,Hh))
    def add(im,dx=0,dy=0): can.alpha_composite(im,(int(round(OX+dx)),int(round(OY+dy))))
    c2=np.cos(2*ph)                      # +1 at contact (t=0, .5), -1 at passing
    bob=14*c2+4                          # down on contact, up on passing (key px; ~5 px screen each way)
    sway=9*np.sin(ph)                    # weight shifts side to side once per cycle
    hip=R['hip']; lead=1 if fwd[0]<0 else -1
    # roots: alternate step out from under the hem, lift, plant; stance slides back with the floor
    for k,(r,(rx_,ry_)) in enumerate(P['roots']):
        u=(t+0.5*k)%1.0
        if u<0.5: s=-1+2*ease(u/0.5); lift=-22*np.sin(np.pi*u/0.5)
        else: s=1-2*(u-0.5)/0.5; lift=0
        d=STEP*0.5*s
        add(r,rx_-r.width/2+fwd[0]*d,ry_-r.height+fwd[1]*d+lift+14)
    add(P['under'],sway*0.5,bob*0.7)
    # hem strips: wave starts at the right strip and travels left, lower piece lags further
    for i,j,s,(cx,y0) in P['strips']:
        k=(4-i)*0.45
        a1=6*np.sin(ph-k)*lead+2.5*np.sin(2*ph-k)
        if j==0: add(rot(s,a1,(cx,hip)),sway*0.5,bob*0.7)
        else:
            a2=a1+7*np.sin(ph-k-1.1)*lead
            L=y0-hip; ex=L*np.sin(np.radians(-a1)); ey=L*(np.cos(np.radians(a1))-1)
            add(rot(s,a2,(cx,y0)),ex+sway*0.5,ey+bob*0.7)
    # upper body (torso + arm + upright scythe, all as painted) leans forward over the hip
    tilt=lead*6+1.5*np.sin(ph)*lead
    # scythe: pendulum at the hand, lagging the bob, plus a small blade bob; rides the torso transform
    hx,hy=P['hand']; pend=9*np.sin(ph-1.0)*lead
    sc=rot(P['scy'],pend,(hx,hy)); sc=Image.fromarray(np.roll(np.array(sc),int(round(5*np.sin(2*ph-1.3))),axis=0))
    add(rot(sc,tilt,(P['foot'][0],hip)),sway,bob)
    up=rot(P['upper'],tilt,(P['foot'][0],hip)); add(up,sway,bob)
    if P['blade'] is not None: add(rot(P['blade'],tilt,(P['foot'][0],hip)),sway,bob)   # in front of the shoulder, behind the hood
    hl=-7*max(0,np.cos(2*ph-0.9))        # hood rises a beat late (lag); never drops below the key
    hd=rot(P['head'],tilt+1.5*np.sin(2*ph-0.9),(P['foot'][0],hip)); add(hd,sway,bob+hl)
    fx,fy=OX+P['foot'][0],OY+P['foot'][1]; sq=0.03*c2
    can=can.resize((int(W*(1+sq)),int(Hh*(1-sq))),Image.BICUBIC); fx*=1+sq; fy*=1-sq
    can=can.rotate(lead*6,center=(fx,fy),resample=Image.BICUBIC)   # whole-body lean: scythe ends ~12° forward
    return can,(fx,fy)
def ease(x): return x*x*(3-2*x)
def frameS(PP,t,scale=0.38):
    S=Image.new('RGB',(1920,1080))
    for k,dn in enumerate('nesw'):
        side,mir=KEY[dn]; vx,vy=DIRV[dn]
        fwd=np.array([vx*(-1 if mir else 1),vy],float); fwd/=np.linalg.norm(fwd)
        g=floor(dn,t%2)
        spr,(fx,fy)=pose(PP[side],t,fwd)
        if mir: spr=spr.transpose(Image.FLIP_LEFT_RIGHT); fx=spr.width-fx
        spr=spr.resize((int(spr.width*scale),int(spr.height*scale)),Image.LANCZOS); fx*=scale; fy*=scale
        px,py=480,330
        sh=Image.new('RGBA',g.size); sw=75; ImageDraw.Draw(sh).ellipse([px-sw,py-sw*.27,px+sw,py+sw*.27],fill=(0,0,0,125)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
        g.alpha_composite(spr,(int(px-fx),int(py-fy)))
        ImageDraw.Draw(g).text((16,10),dn.upper(),font=fnt,fill=(255,236,170,255),stroke_width=4,stroke_fill=(0,0,0,255))
        S.paste(g.convert('RGB'),((k%2)*QW,(k//2)*QH))
    return S
if __name__=='__main__':
    PP={s:build(s) for s in ('front','back')}
    if len(sys.argv)>1:
        ts=[float(x) for x in sys.argv[1].split(',')]
        for t in ts: frameS(PP,t).save(f'/tmp/r5b_{t}.png')
        sys.exit()
    d='/tmp/_r5b_war'; os.makedirs(d,exist_ok=True)
    for i in range(192): frameS(PP,i/24).save(f'{d}/{i:04d}.png')
    subprocess.run(f'ffmpeg -y -loglevel error -framerate 24 -i {d}/%04d.png -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 16 -movflags +faststart /workspace/foe_walks/harvest_v2/warden_walk_4dir_v5.mp4',shell=True,check=True)
