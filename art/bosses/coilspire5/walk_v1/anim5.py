import numpy as np, scipy.ndimage as nd, cv2, os
from PIL import Image
FPS=24; DUR=6.0; T=1.0; K=0.46
DV={'n':(-2,-1),'e':(2,-1),'s':(2,1),'w':(-2,1)}; TF={'n':'S','e':'W','s':'N','w':'E'}
MAP={'n':('back',True),'e':('back',False),'s':('front',True),'w':('front',False)}
P0,P1=-200,60; V=(P1-P0)/DUR; D=V/K*T/2
# legs as painted: (tip_x, band x0,x1, top y). Pincers: (x0,x1,y0,root)
CFG={'front':dict(legs=[(156,130,200,400),(420,390,460,430),(510,460,530,420),(574,530,589,340)],
                  pinc=[(0,130,290,(130,330)),(185,340,470,(300,470))],tail=(lambda x,y:(y<235)&(x>250),235)),
     'back': dict(legs=[(134,110,190,400),(295,250,340,470),(450,410,490,480),(571,530,585,440),(596,586,640,450)],
                  pinc=[(640,800,250,(640,330)),(0,110,300,(110,330))],tail=(lambda x,y:(y<330)&(x<420),330))}
RIG={}
for side,cf in CFG.items():
    SB=0.8 if side=='back' else 1.0   # match body size between the two painted keys
    im_=Image.open(f'/workspace/foe_walks/coilspire5_v1/keys/raw_{side}.png'); im_=im_.resize((round(im_.width*SB),round(im_.height*SB)),Image.LANCZOS)
    a=np.array(im_); a[a[...,3]<128]=0; a[a[...,3]>0,3]=255; m=a[...,3]>0; H,W=m.shape
    cf=dict(legs=[tuple(int(v*SB) for v in L) for L in cf['legs']],pinc=[(int(x0*SB),int(x1*SB),int(y0*SB),(root[0]*SB,root[1]*SB)) for x0,x1,y0,root in cf['pinc']],
            tail=((lambda f,S:(lambda x,y:f(x/S,y/S)))(cf['tail'][0],SB),cf['tail'][1]*SB))
    yy,xx=np.mgrid[0:H,0:W].astype(np.float32)
    bot=lambda x:int(max(np.nonzero(m[:,xx_])[0].max() for xx_ in range(max(0,x-3),min(W,x+4)) if m[:,xx_].any()))
    legs=[]
    for i,(tx,x0,x1,yt) in enumerate(sorted(cf['legs'])):
        ty=bot(tx); band=((xx>=x0)&(xx<x1)).astype(np.float32); w=np.clip((yy-yt)/max(1,ty-yt),0,1)*band
        legs.append(dict(tip=np.array([tx,ty],float),w=w,g=i%2))
    pz=[]
    for x0,x1,y0,root in cf['pinc']:
        z=((xx>=x0)&(xx<x1)&(yy>=y0)).astype(np.float32); pz.append((z,root))
    pmask=sum(z for z,_ in pz); 
    for l in legs: l['w']*=(1-np.clip(pmask,0,1))
    tf,tb=cf['tail']; tw=(tf(xx,yy)).astype(np.float32)*np.clip((tb-yy)/tb,0,1)
    rgb=a[...,:3].astype(np.float32); purple=((rgb[...,2]-rgb[...,1])>35)&((rgb[...,0]-rgb[...,1])>15)
    gy=float(np.mean([l['tip'][1] for l in legs]))
    RIG[side]=dict(a=a,legs=legs,pz=pz,tw=tw,H=H,W=W,xx=xx,yy=yy,purple=purple,gy=gy,cx=W/2)
    print(side,'legs',len(legs),[tuple(l['tip'].astype(int)) for l in legs],'pincers',len(pz))
def u_of(side): v=np.array((-2,1) if side=='front' else (2,-1),float); return v/np.linalg.norm(v)
def sprite(side,t,stats=None):
    R=RIG[side]; a=R['a']; xx,yy=R['xx'],R['yy']; u=u_of(side); ph=2*np.pi*t/T
    bob=2.5*np.sin(2*ph); dx=np.zeros_like(xx); dy=np.full_like(xx,bob); tips=[]
    for l in R['legs']:
        p=(t/T+l['g']*0.5)%1
        if p<0.5: off=D*(0.5-2*p); lift=0
        else: q=(p-0.5)*2; e=q*q*(3-2*q); off=D*(-0.5+e); lift=14*np.sin(np.pi*q)
        tx,ty=u*off; ty-=lift; w=l['w']
        dx+=w*tx; dy+=w*(ty-bob)            # tip cancels the bob -> stays planted
        tips.append((l['tip'][0]+tx,l['tip'][1]+ty,lift))
    for i,(z,root) in enumerate(R['pz']):    # pincers sway (small rotation about root)
        ang=np.deg2rad(2.0*np.sin(ph+i*1.3)); rx,ry=xx-root[0],yy-root[1]
        dx+=z*(rx*(np.cos(ang)-1)-ry*np.sin(ang)); dy+=z*(rx*np.sin(ang)+ry*(np.cos(ang)-1))
    dx+=R['tw']*6*np.sin(ph*0.5); dy+=R['tw']*2*np.cos(ph*0.5)   # slow tail/orb sway
    dx=cv2.GaussianBlur(dx,(0,0),5); dy=cv2.GaussianBlur(dy,(0,0),5)
    o=cv2.remap(a,(xx-dx).astype(np.float32),(yy-dy).astype(np.float32),cv2.INTER_LINEAR,borderValue=(0,0,0,0))
    al=o[...,3]>=128; o[~al]=0; o[al,3]=255
    f=0.75+0.5*np.random.default_rng(int(t*FPS)*7+1).random()
    pm=cv2.remap(R['purple'].astype(np.uint8),(xx-dx).astype(np.float32),(yy-dy).astype(np.float32),cv2.INTER_NEAREST)>0
    c=o[...,:3].astype(np.float32); c[pm]=np.clip(c[pm]*f,0,255); o[...,:3]=c.astype(np.uint8)
    mm=o[...,3]>0; lb,n=nd.label(mm,np.ones((3,3))); s=nd.sum(mm,lb,range(1,n+1)); o[np.isin(lb,[i+1 for i,v in enumerate(s) if v<20])]=0
    if stats is not None: stats.append(n)
    return o,tips,bob
