import numpy as np
from PIL import Image
from scipy import ndimage as nd
k=np.array(Image.open('slamkey2.jpg').convert('RGB')).astype(float)
L=k@[.299,.587,.114]; sat=(k.max(-1)-k.min(-1))/np.maximum(k.max(-1),1)
fg=(L<150)|((sat>0.30)&(k[...,0]>120))
fg=nd.binary_opening(fg,iterations=1); 
base=np.array(Image.open('base_e.png')); ba=base[...,3]>0; bc=base[...,:3][ba].astype(float)
def stats(c,m): 
    rock=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1)<0.45
    return c[rock].mean(0),c[rock].std(0)
bm,bs=stats(bc,None)
out={}
for nm,(x0,x1) in {'wind':(0,600),'strike':(600,1280)}.items():
    m=fg.copy(); m[:,:x0]=0; m[:,x1:]=0
    lab,n=nd.label(m); sz=nd.sum(m,lab,range(1,n+1)); keep=np.isin(lab,1+np.nonzero(sz>=max(40,sz.max()*0.002))[0])
    if nm=='wind': keep=lab==(np.argmax(sz)+1)
    keep=nd.binary_fill_holes(keep)&(fg|nd.binary_fill_holes(keep)&(L<150))
    ys,xs=np.nonzero(keep)
    rgba=np.zeros(k.shape[:2]+(4,),np.uint8); rgba[...,:3]=k.astype(np.uint8); rgba[...,3]=keep*255
    out[nm]=(rgba,keep)
# scale: match rock area of rig rest
area_rig=ba.sum(); bx=np.nonzero(ba)
def place(rgba,keep,sc,cx=None):
    im=Image.fromarray(rgba).resize((round(1280*sc),round(720*sc)),Image.LANCZOS); a=np.array(im)
    h=a[...,3]>=128; cc=a[...,:3].astype(float); LL=cc@[.299,.587,.114]; ss=(cc.max(-1)-cc.min(-1))/np.maximum(cc.max(-1),1); h&=~((ss<0.1)&(LL>150)); lb,nn=nd.label(h); sz=nd.sum(h,lb,range(1,nn+1)); h=np.isin(lb,1+np.nonzero(sz>=6)[0]); a[...,3]=h*255; a[~h]=0
    ys,xs=np.nonzero(h); bot=np.percentile(ys,99.7); cx=(np.percentile(xs,1)+np.percentile(xs,99))/2 if cx is None else cx
    o=np.zeros((336,288,4),np.uint8); dy=int(round(302-bot)); dx=int(round(144-cx))
    yy,xx=ys+dy,xs+dx; ok=(yy>=0)&(yy<336)&(xx>=0)&(xx<288); o[yy[ok],xx[ok]]=a[ys[ok],xs[ok]]; return o,ok.mean()
sc=0.39
print('scale',round(sc,3))
for nm,(rgba,keep) in out.items():
    o,fit=place(rgba,keep,sc); c=o[...,:3].astype(float); _L=c@[.299,.587,.114]; _s=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1)
    yy=np.arange(336)[:,None]; o[(yy>280)&(_s<0.14)&(_L>55)]=0   # grey ground shadow under feet
    a=o[...,3]>0; c=o[...,:3].astype(float)
    s_=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1); rock=a&(s_<0.45)
    km,ks=c[rock].mean(0),c[rock].std(0)
    c2=c.copy()   # per-channel histogram match (quantile map) of the painted key onto the rig key palette
    BL=bc@[.299,.587,.114]; KL=c[a]@[.299,.587,.114]
    qk=np.argsort(np.argsort(KL))/max(1,len(KL)-1); tgtL=np.quantile(BL,qk)
    ratio=(tgtL+1)/(KL+1); c2[a]=c[a]*ratio[:,None]
    # hue: push rock toward rig brown and lava toward rig orange
    c2[a&rock]=c2[a&rock]*0.5+((c2[a&rock]@[.299,.587,.114])[:,None]*(bm/max(1,bm@[.299,.587,.114])))*0.5
    o[...,:3]=np.clip(c2,0,255).astype(np.uint8)
    ys,xs=np.nonzero(a); print(nm,'fit',round(fit,3),'bbox',xs.min(),xs.max(),ys.min(),ys.max())
    cc=o[...,:3].astype(float); gm=(o[...,3]>0)&(cc[...,1]>cc[...,0]); r_=cc[...,:3].max(-1)
    cc[gm]=np.stack([r_[gm],r_[gm]*0.62,r_[gm]*0.2],-1); o[...,:3]=cc.astype(np.uint8)   # no green tints in the hot core
    Image.fromarray(o).save(f'slam_{nm}_e.png')
    # N (back view) derived: mirror + darken front highlights (lava cracks dimmed, rock lit less)
    n=o[:,::-1].copy(); cn=n[...,:3].astype(float); an=n[...,3]>0
    sn=(cn.max(-1)-cn.min(-1))/np.maximum(cn.max(-1),1); lavn=an&(sn>0.45)
    # back view: paint over face/eyes and chest core with back-rock texture cloned from sc_n (base_n)
    bnk=np.array(Image.open('base_n.png')); cn0=n[...,:3].astype(float); Ln=cn0@[.299,.587,.114]
    br=(n[...,3]>0)&(Ln>185)&(np.arange(336)[:,None]<235); br=nd.binary_dilation(br,iterations=3); lb_,nl_=nd.label(br)
    if nl_: br=lb_==(np.argmax(nd.sum(br,lb_,range(1,nl_+1)))+1)
    yy_,xx_=np.nonzero(br)
    if len(yy_):
        cy_,cx_=np.median(yy_),np.median(xx_); YY,XX=np.mgrid[0:336,0:288]
        mk=((((XX-cx_)/30)**2+((YY-cy_)/28)**2<1)|(((XX-cx_)/30)**2+((YY-(cy_-40))/24)**2<1))&(n[...,3]>0)
        oy,ox=int(140-cy_),int(144-cx_); sy=np.clip(YY+oy,0,335); sx=np.clip(XX+ox,0,287); okb=bnk[sy,sx,3]>0
        m2=mk&okb; n[m2,:3]=(bnk[sy[m2],sx[m2],:3]*0.55).astype(np.uint8); print('backmask',int(m2.sum()),int(cy_),int(cx_))
    cn=n[...,:3].astype(float)
    bn=np.array(Image.open('base_n.png')); bnc=bn[...,:3][bn[...,3]>0].astype(float); BLn=bnc@[.299,.587,.114]
    KLn=cn[an]@[.299,.587,.114]; qn=np.argsort(np.argsort(KLn))/max(1,len(KLn)-1); tg=np.quantile(BLn,qn)
    cn[an]=cn[an]*((tg+1)/(KLn+1))[:,None]; cn[lavn]*=0.92   # back view: luminance matched to the back rig key, front highlights toned down
    n[...,:3]=np.clip(cn,0,255).astype(np.uint8); Image.fromarray(n).save(f'slam_{nm}_n.png')
