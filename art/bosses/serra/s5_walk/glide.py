import numpy as np, cv2, scipy.ndimage as nd, sys
from PIL import Image, ImageDraw, ImageFilter
NF=12; SFALL={}; STAFF5={'front':((90,298),(225,101)),'back':((179,281),(249,51))}; KD='/workspace/foe_walks/serra_v2/s5_walk/keys'
yy,xx=np.mgrid[0:336,0:288].astype(np.float32)
def prep(k):
    a=np.array(Image.open(f'{KD}/s5_{k}.png')); body=a.copy(); body[a[...,3]<255]=0   # drop baked soft shadow; re-drawn per frame
    m=body[...,3]>0; lb,n=nd.label(m,np.ones((3,3))); s=nd.sum(m,lb,range(1,n+1)); big=np.argmax(s)+1
    main=lb==big; ys,xs=np.nonzero(main)
    # staff: line from the right-most top tip to the left-most point of the main silhouette
    up=(ys<120)&(xs>xs.mean()); i=np.argmax(xs[up]-ys[up]*0.5); p1=np.array([xs[up][i],ys[up][i]],float)
    j=np.argmin(xs); p0=np.array([xs[j],ys[j]],float)
    p0,p1=STAFF5[k]; p0=np.array(p0,float); p1=np.array(p1,float)
    v=p1-p0; t=np.clip(((xx-p0[0])*v[0]+(yy-p0[1])*v[1])/(v@v),0,1); dist=np.hypot(xx-(p0[0]+t*v[0]),yy-(p0[1]+t*v[1]))
    staff=main&(dist<4); global SFALL; SFALL[k]=np.clip((dist-3)/22,0,1).astype(np.float32)
    shards=[(lb==i+1) for i in range(n) if i+1!=big]
    return body,main,staff,shards,(p0,p1)
def remap(img,mx,my): return cv2.remap(img,mx,my,cv2.INTER_NEAREST,borderValue=(0,0,0,0))
def frame(P,f,tx):
    body,main,staff,shards,_=P; kf=SFALL['front' if tx<0 else 'back']; p=f/NF; ph=2*np.pi*p
    bob=3.0*np.sin(ph)                         # + = down
    lean=tx*3.0*np.clip((300-yy)/270,0,1)      # top leans into travel
    w=np.clip((yy-150)/150,0,1)**1.4           # robe / smoke weight (0 at chest, 1 at base)
    hair=np.clip(1-np.abs(yy-110)/50,0,1)*(np.abs(xx-150)>18)*0.6
    trail=-tx*(5*w+3*hair)*(1+0.25*np.sin(ph-yy/28))          # trails opposite to travel
    swirl=w**2*2.5*np.sin(ph*2-yy/14+xx/40)                   # smoke churn at the base
    dx=lean+(trail+swirl)*kf; dy=bob+0*w   # sway fades out near the staff so it stays straight (no tear)
    o=np.zeros_like(body)
    soft=np.where(main[...,None],body,0).astype(np.uint8)
    o=remap(soft,(xx-dx).astype(np.float32),(yy-dy).astype(np.float32))
    for i,S in enumerate(shards):   # shards drift on small orbits
        a=ph+i*1.7; ox=4*np.cos(a); oy=2*np.sin(a)+bob*0.6
        sh=np.where(S[...,None],body,0).astype(np.uint8); sh=cv2.warpAffine(sh,np.float32([[1,0,ox],[0,1,oy]]),(288,336),flags=cv2.INTER_NEAREST,borderValue=(0,0,0,0))
        m_=sh[...,3]>0; o[m_]=sh[m_]
    o[...,3]=np.where(o[...,3]>=128,255,0); o[o[...,3]==0]=0
    _m=o[...,3]>0; _lb,_n=nd.label(_m,np.ones((3,3))); _s=nd.sum(_m,_lb,range(1,_n+1)); o[np.isin(_lb,[i+1 for i,s_ in enumerate(_s) if s_<8])]=0   # no specks
    # shadow: smaller at the top of the bob (bob<0 = up)
    ys,xs=np.nonzero(main); sw=(np.ptp(xs)*0.6)*(1+0.05*bob/3); cell=Image.new('RGBA',(288,336)); sd=Image.new('RGBA',(288,336))
    ImageDraw.Draw(sd).ellipse([144-sw/2,300-sw*0.11,144+sw/2,300+sw*0.11],fill=(0,0,0,int(105+8*bob/3)))
    cell.alpha_composite(sd.filter(ImageFilter.GaussianBlur(4))); cell.alpha_composite(Image.fromarray(o)); return cell
MAP={'n':('back',True),'e':('back',False),'s':('front',True),'w':('front',False)}
OUT={}
for k in ('front','back'):
    P=prep(k); tx=-1 if k=='front' else 1   # front key travels screen-left (down-left), back key screen-right (up-right)
    OUT[k]=[frame(P,f,tx) for f in range(NF)]
    print(k,'staff px',int(P[2].sum()),'shards',len(P[3]),'staff line',P[4])
for dn,(k,mir) in MAP.items():
    fr=[im.transpose(Image.FLIP_LEFT_RIGHT) if mir else im for im in OUT[k]]
    s=Image.new('RGBA',(288*NF,336))
    for i,im in enumerate(fr): s.alpha_composite(im,(i*288,0))
    s.save(f'serra5_walk_{dn}.png')
