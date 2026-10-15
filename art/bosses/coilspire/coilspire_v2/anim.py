import numpy as np, scipy.ndimage as nd, cv2, os, sys, json
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from seg import seg
FPS=24; DUR=6.0; T=1.0; K=0.46
DV={'n':(-2,-1),'e':(2,-1),'s':(2,1),'w':(-2,1)}; TF={'n':'S','e':'W','s':'N','w':'E'}
MAP={'n':('back',True),'e':('back',False),'s':('front',True),'w':('front',False)}
P0,P1=-200,60; V=(P1-P0)/DUR          # screen px/s along facing
D=V/K*T/2                              # raw stance stroke so planted tips are ground-fixed
RIG={}
for side in ('front','back'):
    a,m,body,lb,comps=seg(side); H,W=m.shape
    comps=sorted(comps,key=lambda c:-c[0])[:6]
    legs=[]
    for c in comps:
        L=lb==c[1]; ys,xs=np.nonzero(L)
        bd=nd.binary_dilation(body,iterations=6); hh=np.nonzero(L&bd)
        hip=np.array([hh[1].mean(),hh[0].mean()]) if len(hh[0]) else np.array([xs.mean(),ys.min()])
        dd=np.hypot(xs-hip[0],ys-hip[1]); tip=np.array([xs[dd.argmax()],ys[dd.argmax()]])
        src=np.zeros_like(a); src[L]=a[L]; legs.append(dict(mask=L,src=src,hip=hip,tip=tip,behind=False))
    if side=='front' and len(legs)==5:   # 6th leg is hidden behind the skull in the painted key: clone the short left leg, mirrored, peeking from under the right side
        b=min(legs,key=lambda l:l['mask'].sum()); ys,xs=np.nonzero(b['mask'])
        nhip=np.array([395.,425.]); nx=(2*b['hip'][0]-xs)-b['hip'][0]+nhip[0]; ny=ys-b['hip'][1]+nhip[1]+20
        k=(nx>=0)&(nx<W)&(ny>=0)&(ny<H); M=np.zeros_like(m); src=np.zeros_like(a)
        M[ny[k].astype(int),nx[k].astype(int)]=True; src[ny[k].astype(int),nx[k].astype(int)]=a[ys[k],xs[k]]
        c_=src[...,:3].astype(np.float32)*0.8; src[...,:3]=c_.astype(np.uint8)   # slightly darker: rear leg
        tip=np.array([2*b['hip'][0]-b['tip'][0]-b['hip'][0]+nhip[0],b['tip'][1]-b['hip'][1]+nhip[1]+20])
        legs.append(dict(mask=M,src=src,hip=nhip,tip=tip,behind=True))
    legs.sort(key=lambda l:l['tip'][0])
    for i,l in enumerate(legs): l['g']=i%2       # alternating tripods
    yy,xx=np.mgrid[0:H,0:W].astype(np.float32)
    for l in legs:
        v=l['tip']-l['hip']; w=((xx-l['hip'][0])*v[0]+(yy-l['hip'][1])*v[1])/(v@v); l['w']=np.clip(w,0,1).astype(np.float32)
    rgb=a[...,:3].astype(np.float32); purple=((rgb[...,2]-rgb[...,1])>35)&((rgb[...,0]-rgb[...,1])>15)
    RIG[side]=dict(a=a,legs=legs,H=H,W=W,xx=xx,yy=yy,purple=purple,gy=float(np.mean([l['tip'][1] for l in legs])),cx=W/2)
    print(side,'legs',len(legs),[(tuple(l['hip'].astype(int)),tuple(l['tip']),l['g']) for l in legs])
def u_of(side): v=np.array((-2,1) if side=='front' else (2,-1),float); return v/np.linalg.norm(v)
def sprite(side,t,stats=None):
    R=RIG[side]; a=R['a']; xx,yy=R['xx'],R['yy']; u=u_of(side)
    bob=2.5*np.sin(4*np.pi*t/T)                      # 2 steps per cycle
    out=a.copy(); 
    legmask=np.zeros(a.shape[:2],bool)
    for l in R['legs']: legmask|=l['mask']
    out[legmask]=0
    out=np.roll(out,int(round(bob)),axis=0)
    rng=np.random.default_rng(int(t*FPS)*7+1); f=0.75+0.5*rng.random()   # lightning flicker
    pm=np.roll(R['purple'],int(round(bob)),axis=0)
    if True:
        c=out[...,:3].astype(np.float32); c[pm]=np.clip(c[pm]*f,0,255); out[...,:3]=c.astype(np.uint8)
    tips=[]
    for l in R['legs']:
        p=(t/T+l['g']*0.5)%1
        if p<0.5: off=D*(0.5-2*p); lift=0
        else: q=(p-0.5)*2; e=q*q*(3-2*q); off=D*(-0.5+e); lift=16*np.sin(np.pi*q)
        tx,ty=u*off; ty-=lift
        w=l['w']; knee=np.clip(w/0.55,0,1)               # lift concentrates in the lower (tibia) segment
        dx=w*tx; dy=w*ty+bob*(1-w)                       # hip rides with body, tip stays put
        dy=dy-lift*0.25*(knee-w)                          # knee raises a little more than linear (joint bend)
        src=l['src']
        o=cv2.remap(src,(xx-dx).astype(np.float32),(yy-dy).astype(np.float32),cv2.INTER_LINEAR,borderValue=(0,0,0,0))
        al=o[...,3]>=128; o[~al]=0; o[al,3]=255
        if l['behind']: put=al&(out[...,3]==0); out[put]=o[put]
        else: out[al]=o[al]
        tips.append((l['tip'][0]+tx,l['tip'][1]+ty,lift))
        if stats is not None: stats.append(int(nd.label(al,np.ones((3,3)))[1]))
    mm=out[...,3]>0; lb,n=nd.label(mm,np.ones((3,3))); s=nd.sum(mm,lb,range(1,n+1)); out[np.isin(lb,[i+1 for i,v in enumerate(s) if v<20])]=0
    return out,tips,bob
if __name__=='__main__':
    os.makedirs('strips',exist_ok=True); NS=24
    for dn,(side,mir) in MAP.items():
        R=RIG[side]; S=Image.new('RGBA',(R['W']*NS//2,R['H']//2))
        for i in range(NS):
            o,_,_=sprite(side,i*T/NS); im=Image.fromarray(o)
            if mir: im=im.transpose(Image.FLIP_LEFT_RIGHT)
            S.alpha_composite(im.resize((R['W']//2,R['H']//2),Image.LANCZOS),(i*(R['W']//2),0))
        S.save(f'strips/coilspire14_walk_{dn}.png')
