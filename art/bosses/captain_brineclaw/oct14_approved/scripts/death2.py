import numpy as np, os, sys, json
from PIL import Image
from scipy import ndimage as nd
sys.path.insert(0,'/workspace/foe_walks/fly_back'); import dspk, fxlib
import legs as LG
src=open('/workspace/foe_walks/fly/keyact.py').read(); exec(src[:src.index('def build')])
OD='/workspace/foe_walks/cb3_out/captain_brineclaw_v3'; NM='captain_brineclaw'
Y,X=np.mgrid[0:336,0:288].astype(float)
K=np.array(Image.open('death3.jpg').convert('RGB')).astype(float)[:600]
bgc=np.median(K[0],0)
def cut(x0,x1):
    sub=K[:,x0:x1]; d=np.abs(sub-bgc).max(-1); L=sub@[.299,.587,.114]; sat=(sub.max(-1)-sub.min(-1))/np.maximum(sub.max(-1),1)
    fg=(d>24)&~((d<55)&(sat<0.1))
    water=fg&(L>120)&(sub[...,2]>=sub[...,0]-5)&(sat<0.35)
    solid=fg&~water; solid=nd.binary_opening(solid)
    lab,n=nd.label(solid); sz=nd.sum(solid,lab,range(1,n+1)); big=np.argmax(sz)+1
    body=lab==big; debris=solid&~body&np.isin(lab,np.nonzero(sz>25)[0]+1)
    wa=np.clip((d-20)/60,0,1)*water
    return sub,body,debris,wa
def scale_place(sub,mask,s,cx,bot,alpha=None):
    H,W=sub.shape[:2]; im=Image.fromarray(np.dstack([sub,(mask*255 if alpha is None else alpha*255)]).astype(np.uint8))
    im=im.resize((round(W*s),round(H*s)),Image.LANCZOS); a=np.array(im); out=np.zeros((336,288,4),np.uint8)
    ox=int(cx-a.shape[1]/2); oy=bot-a.shape[0]
    xs0=max(0,-ox); xs1=min(a.shape[1],288-ox); ys0=max(0,-oy)
    out[oy+ys0:oy+a.shape[0],ox+xs0:ox+xs1]=a[ys0:,xs0:xs1]
    if alpha is None: out[...,3]=np.where(out[...,3]>=140,255,0); out[out[...,3]==0]=0
    return out
cols=[(0,430),(430,860),(860,1280)]
parts=[cut(*c) for c in cols]
# scale: match blow body height to strike-key family -> use body width of the rest key
rest=LG.deshadow(np.array(Image.open('key_f_rest.png'))); rx=np.nonzero(rest[...,3].any(0))[0]
sub,body,_,_=parts[0]; bx=np.nonzero(body.any(0))[0]; by=np.nonzero(body.any(1))[0]
kw=np.array(Image.open('key_windup.png')); wy=np.nonzero(kw[...,3].any(1))[0]; s=(wy.max()-wy.min())/np.ptp(by); print('scale',s)
def lay(i,bot=300):
    sub,body,deb,wa=parts[i]; yb=np.nonzero(body.any(1))[0].max(); pad=sub.shape[0]-1-yb   # align body bottom to bot
    b=dspk.clean(scale_place(sub,body,s,144,bot+int(pad*s)))
    d=dspk.clean(scale_place(sub,deb,s,144,bot+int(pad*s)))
    w=scale_place(sub,None,s,144,bot+int(pad*s),alpha=wa)
    return b,d,w
BL,BLd,BLw=lay(0); BR,BRd,BRw=lay(1,bot=285); HP,HPd,HPw=lay(2)
heap=HP.copy(); m=HPd[...,3]>0; heap[m]=HPd[m]
NOISE=np.clip(nd.gaussian_filter(np.random.default_rng(2).random((336,288)),5)*6-2.5,0,1)
def tint(o,t,col=(200,40,40)):
    o=o.copy(); m=o[...,3]>0; f=o[...,:3].astype(float); f=f*(1-t)+np.array(col)*t; o[...,:3][m]=np.clip(f[m],0,215).astype(np.uint8); return o
def over(o,l,alpha=1.0):
    o=o.copy(); a=l[...,3].astype(float)/255*alpha; m=a>0.02
    o[...,:3][m]=(o[...,:3][m]*(1-a[m,None])+l[...,:3][m]*a[m,None]).astype(np.uint8); o[...,3][m]=np.maximum(o[...,3][m],(a[m]*255).astype(np.uint8)); return o
def shift(o,dx,dy,sc=1.0,cx=144,cy=150):
    sx=np.round((X-dx-cx)/sc+cx).astype(int); sy=np.round((Y-dy-cy)/sc+cy).astype(int); ok=(sx>=0)&(sx<288)&(sy>=0)&(sy<336)
    r=np.zeros_like(o); r[ok]=o[sy[ok],sx[ok]]; return r
# debris pieces from break-up pose fly out and land
lab,n=nd.label(BRd[...,3]>0); pieces=[]
rng=np.random.default_rng(5)
for i in range(1,n+1):
    m=lab==i
    if m.sum()<6: continue
    ys,xs=np.nonzero(m); pc=np.zeros_like(BRd); pc[m]=BRd[m]; cx=xs.mean(); cy=ys.mean()
    vx=(cx-144)*0.12+rng.uniform(-2,2); vy=rng.uniform(-7,-3); pieces.append(dict(img=pc,cx=cx,cy=cy,bot=ys.max(),vx=vx,vy=vy))
def debris_at(t):
    o=np.zeros((336,288,4),np.uint8)
    for p in pieces:
        x=p['vx']*t; y=p['vy']*t+0.9*t*t
        if p['bot']+y>300: # landed
            tl=(-p['vy']+np.sqrt(max(p['vy']**2+3.6*(300-p['bot']),0)))/1.8; x=p['vx']*tl; y=300-p['bot']
        sh=shift(p['img'],x,y); m=sh[...,3]>0; o[m]=sh[m]
    return o
def hat_of(base):
    a=base[...,3]>0; ys,xs=np.nonzero(a); top=ys.min(); h=ys.max()-top
    c=base[...,:3].astype(int); hm=a.copy(); hm[int(top+0.16*h):]=0
    hm&=~((c[...,1]>c[...,0]+25)&(c[...,1]>c[...,2]+10))   # drop green beard/hair
    lab,n=nd.label(hm); sz=nd.sum(hm,lab,range(1,n+1)); hm=lab==(np.argmax(sz)+1); hm=nd.binary_fill_holes(hm)
    o=np.zeros_like(base); o[hm]=base[hm]; yy,xx=np.nonzero(hm); return o,yy.max(),xx.mean()
def puddle(alpha,cx=144,cy=298,rx=60,ry=12):
    a=np.clip(1-((X-cx)/rx)**2-((Y-cy)/ry)**2,0,1)**0.6*alpha*0.7; o=np.zeros((336,288,4),np.uint8)
    o[...,0]=40; o[...,1]=140; o[...,2]=140; o[...,3]=(a*255).astype(np.uint8); return o
def build(front):
    base=rest if front else LG.deshadow(np.array(Image.open('key_b_rest.png')))
    blow=BL if front else base; brk=BR if front else base
    H,hb,hx=hat_of(base); hat_body=base.copy(); hat_body[H[...,3]>0]=0
    fr=[base.copy(), tint(base,0.35)]
    for k in range(3):
        o=tint(shift(blow,[-3,2,-1][k],[0,-1,0][k]),[0.25,0.1,0][k]); w=shift(BLw,0,0 if front else 10,sc=0.6+0.25*k,cy=170)
        fr.append(over(o,w,1.0))
    bm=brk[...,3]>0; od_=nd.distance_transform_edt(bm); od_=0.7*od_/max(od_.max(),1)+0.3*NOISE
    # hat path: leaves head at frame 5, falls, bounces, lies tilted
    fall=300-hb; path=[(0,0,0),(2,fall*0.15,-8),(5,fall*0.45,-18),(8,fall*0.85,-30),(10,fall,-38),(11,fall-9,-34),(12,fall,-40),(12,fall-3,-40),(12,fall,-41)]
    def hat_at(i):
        i=min(i,len(path)-1); dx,dy,r=path[i]; return xf(H,dx=dx,dy=dy,rot=r)
    nb=8
    for k in range(nb):       # break-up mid-air: body dissolves, debris flies out, hat drops
        p=(k+1)/nb*1.01; cur=bm&(od_>=p); b2=np.zeros_like(brk); b2[cur]=brk[cur]
        if front: hcut=hat_of(brk)[0][...,3]>0; b2[hcut]=0
        else: b2[H[...,3]>0]=0
        o=b2; dd=debris_at(k*1.4+1); dd=dissolve(dd,max(0,(k-3)/5)); m=dd[...,3]>0; o=o.copy(); o[m]=dd[m]
        o=over(o,shift(BRw,0,0,sc=1.0+0.08*k,cy=250),max(0,1-k/6))
        o=over(o,puddle(min(1,k/4)))
        hh=hat_at(k); m=hh[...,3]>0; o[m]=hh[m]; fr.append(o)
    for k in range(7):        # only the hat remains, puddle fades
        o=np.zeros_like(base); o=over(o,puddle(max(0,1-(k+2)/7)))
        hh=hat_at(nb+k); m=hh[...,3]>0; o[m]=hh[m]; fr.append(o)
    return fr
def dissolve(o,fa):
    o=o.copy(); o[NOISE<fa]=0; return o
res={}
for d,front in (('s',True),('e',False)):
    fr=build(front)
    for d2,mir in ((d,False),({'s':'w','e':'n'}[d],True)):
        ff=[x[:,::-1].copy() for x in fr] if mir else fr
        dd=f'{OD}/death_frames_{d2}'; os.makedirs(dd,exist_ok=True); [os.remove(f'{dd}/{x}') for x in os.listdir(dd)]
        for i,a in enumerate(ff): Image.fromarray(a).save(f'{dd}/{i:02d}.png')
        Image.fromarray(np.concatenate(ff,1)).save(f'{OD}/{NM}_death_{d2}.png')
    res[d]=len(fr)
print(res,'pieces',len(pieces))
