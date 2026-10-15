import numpy as np, cv2, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage as nd
sys.path.insert(0,'/workspace/foe_walks/fly_back'); import dspk, fxlib
Y,X=np.mgrid[0:336,0:288].astype(float)
def polym(p):
    m=Image.new('L',(288,336)); ImageDraw.Draw(m).polygon(p,fill=255); return np.array(m)>0
def M_rot(ang,piv,dx=0,dy=0):
    t=np.radians(ang); c,s=np.cos(t),np.sin(t); px,py=piv
    return np.array([[c,s,px-c*px-s*py+dx],[-s,c,py+s*px-c*py+dy],[0,0,1]])
def apply(im,M): return cv2.warpAffine(im,M[:2],(288,336),flags=cv2.INTER_NEAREST,borderValue=(0,0,0,0))
def paste(o,p): o=o.copy(); m=p[...,3]>0; o[m]=p[m]; return o
def lean(img,dx,dy,zs=200):
    w=np.clip((zs-Y)/zs,0,1)**0.8; sx=np.round(X-dx*w).astype(int); sy=np.round(Y-dy*w).astype(int); ok=(sx>=0)&(sx<288)&(sy>=0)&(sy<336)
    o=np.zeros_like(img); o[ok]=img[sy[ok],sx[ok]]; return o
def shift(img,dx,dy): return apply(img,M_rot(0,(0,0),dx,dy))
def rimc(o,t,col=(255,110,50)):
    o=o.copy(); a=o[...,3]>0; r=a&~nd.binary_erosion(a,iterations=4); f=o[...,:3].astype(float)
    f[a]=f[a]*(1-t*0.4)+np.array(col)*t*0.4; f[r]=f[r]*(1-t)+np.array(col)*t; o[...,:3]=np.clip(f,0,255).astype(np.uint8); return o
def clamp(o):
    o=o.copy(); h=o[...,3]>=128; c=o[...,:3].astype(float); L=c@[.299,.587,.114]; sat=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1); m=h&(L>135)&(sat<0.25)
    o[m,:3]=(o[m,:3].astype(float)*(135/L[m])[:,None]).astype(np.uint8); o[~h]=0; o[h,3]=255; return o
def outer1(o):  # darken outer 1px
    o=o.copy(); a=o[...,3]>0; e=a&~nd.binary_erosion(a); o[e,:3]=(o[e,:3]*0.7).astype(np.uint8); return o
def solid(o): return outer1(clamp(dspk.clean(o)))
def fx(o,layers):
    for a,c in layers: o=fxlib.comp(o,a,c,add=ADD)
    return o
def stroke(fn,blur,col,alpha):
    m=Image.new('L',(288,336)); fn(ImageDraw.Draw(m)); a=np.array(m.filter(ImageFilter.GaussianBlur(blur))).astype(float)/255*alpha
    return a,np.zeros((336,288,3))+col
def embers(rng,n,cx,cy,sx,sy,up=0):
    pts=[(cx+rng.normal(0,sx),cy+rng.normal(0,sy)-abs(rng.normal(0,up)),rng.uniform(1.5,3.2),[(255,150,50),(255,110,40),(230,80,30)][rng.integers(3)]) for _ in range(n)]
    return fxlib.soft_dots(pts,1.6,1.0)
# --- rig per dir (cell coords). Locked anatomy: 2 arms (rock fists), 2 legs, head-in-torso, NO weapons.
RIG={'e':dict(LA=[(6,140),(60,116),(98,132),(98,196),(82,224),(88,282),(6,282)], RA=[(194,140),(228,128),(284,146),(284,282),(206,282),(206,230),(214,200),(194,176)],
              LL=[(64,192),(142,192),(142,306),(60,306)], RL=[(142,192),(206,192),(206,232),(218,306),(142,306)],
              ls=(76,136),rs=(204,146),lh=(104,198),rh=(176,198)),
     'n':dict(LA=[(4,130),(60,108),(96,124),(94,200),(78,232),(84,282),(4,282)], RA=[(198,124),(232,108),(286,130),(286,282),(206,282),(204,232),(212,200),(200,170)],
              LL=[(66,206),(144,206),(144,306),(60,306)], RL=[(144,206),(222,206),(226,306),(144,306)],
              ls=(76,124),rs=(206,124),lh=(106,212),rh=(186,212))}
def build(d):
    img=np.array(Image.open(f'base_{d}.png')); a=img[...,3]>0; R=RIG[d]; P={}
    used=np.zeros_like(a)
    for k in ('LA','RA','LL','RL'):
        m=polym(R[k])&a&~used; used|=m; P[k]=np.where(m[...,None],img,0).astype(np.uint8)
    tor=np.where((a&~used)[...,None],img,0).astype(np.uint8)
    # behind each moved limb: clone torso texture from ONE offset, darkened (no repeated tiles)
    sil=nd.binary_fill_holes(nd.binary_closing(a,iterations=5)); hole=used&sil&~(Y>R['lh'][1]+4); hole&=(X>R['ls'][0]+4)&(X<R['rs'][0]-4)
    ok=tor[...,3]>0; o=tor.copy(); ys,xs=np.nonzero(hole)
    for side in (-1,1):
        sel=(xs<144) if side<0 else (xs>=144); yy,xx=ys[sel],xs[sel]
        if not len(yy): continue
        best=max(((ok[np.clip(yy,0,335),np.clip(xx-side*dx,0,287)].mean(),dx) for dx in range(10,120,4)))
        dx=best[1]; sx=np.clip(xx-side*dx,0,287); g=ok[yy,sx]; o[yy[g],xx[g]]=(tor[yy[g],sx[g]]*np.array([0.62,0.6,0.6,1])).astype(np.uint8)
    return img,P,o
def compose(d,Pt,tor,la=0,ra=0,ll=0,rl=0,lly=0,rly=0,arm_dy=0,lx=0,ly=0,bob=0):
    R=RIG[d]; s=1
    body=lean(tor,lx,ly); 
    legs=paste(apply(Pt['LL'],M_rot(ll,R['lh'],0,-lly)),apply(Pt['RL'],M_rot(rl,R['rh'],0,-rly)))
    arms=[apply(shift(Pt['LA'],lx*0.8,ly*0.8+arm_dy),M_rot(la,(R['ls'][0]+lx*0.8,R['ls'][1]+ly*0.8))),apply(shift(Pt['RA'],lx*0.8,ly*0.8+arm_dy),M_rot(ra,(R['rs'][0]+lx*0.8,R['rs'][1]+ly*0.8)))]
    o=paste(legs,shift(body,0,bob)); 
    for A_ in arms: o=paste(o,shift(A_,0,bob))
    return o
rng=np.random.default_rng(4); ADD=0.3
ELB={'e':((54,178),(226,182)),'n':((52,172),(234,172))}
def ang_to(v0,v1):
    best=None
    for a in np.arange(-180,180,0.5):
        t=np.radians(a); c,s_=np.cos(t),np.sin(t); w=(c*v0[0]+s_*v0[1],-s_*v0[0]+c*v0[1])
        e=np.hypot(w[0]/np.hypot(*v0)-v1[0]/np.hypot(*v1),w[1]/np.hypot(*v0)-v1[1]/np.hypot(*v1))
        if best is None or e<best[0]: best=(e,a)
    return best[1]
def ik(S,L1,L2,T,bend):
    S=np.array(S,float); T=np.array(T,float); d=np.clip(np.linalg.norm(T-S),1e-3,L1+L2-1e-3); u=(T-S)/np.linalg.norm(T-S)
    a=(L1*L1-L2*L2+d*d)/(2*d); h=np.sqrt(max(L1*L1-a*a,0)); n=np.array([-u[1],u[0]])*bend
    return S+u*a+n*h
def splitarm(P,el):
    a=P[...,3]>0; up=a&(Y<el[1]); fo=a&~up
    U=np.where(up[...,None],P,0).astype(np.uint8); F=np.where(fo[...,None],P,0).astype(np.uint8)
    ys,xs=np.nonzero(fo); return U,F,np.array([xs.mean(),ys.mean()])
def arm2(P,sh,el,fist_t,bend):
    U,F,fc=splitarm(P,el); L1=np.hypot(*(np.array(el)-sh)); L2=np.hypot(*(fc-el))
    E=ik(sh,L1,L2,fist_t,bend)
    au=ang_to(np.array(el)-sh,E-np.array(sh)); af=ang_to(fc-np.array(el),np.array(fist_t)-E)
    Uw=apply(U,M_rot(au,sh)); Fw=apply(F,M_rot(af,el,E[0]-el[0],E[1]-el[1]))
    return Uw,Fw,E
def edge(P,f=0.5,it=2):
    P=P.copy(); a=P[...,3]>0; e=a&~nd.binary_erosion(a,iterations=it); P[e,:3]=(P[e,:3]*f).astype(np.uint8); return P
def ikpose(d,Pt,tor,lt,rt,lb,rb,lx=0,ly=0,fist_behind=False,shrug=0):
    R_=RIG[d]; body=lean(tor,lx,ly); k=0.8
    sh=[np.array(R_['ls'])+[lx*k,ly*k-shrug],np.array(R_['rs'])+[lx*k,ly*k-shrug]]; el=[np.array(e)+[lx*k,ly*k-shrug] for e in ELB[d]]
    LA=edge(shift(Pt['LA'],lx*k,ly*k-shrug)); RA=edge(shift(Pt['RA'],lx*k,ly*k-shrug))
    lu,lf,_=arm2(LA,sh[0],el[0],lt,lb); ru,rf,_=arm2(RA,sh[1],el[1],rt,rb); lf,rf=edge(lf,0.45,3),edge(rf,0.45,3)
    legs=paste(Pt['LL'],Pt['RL'])
    if fist_behind: o=paste(paste(paste(lf,rf),legs),body); o=paste(paste(o,lu),ru)
    else: o=paste(paste(paste(legs,body),lu),ru); o=paste(paste(o,lf),rf)
    return o
def fillgaps(o,tor):
    o=o.copy(); a=o[...,3]>0; g=nd.binary_fill_holes(nd.binary_closing(a,iterations=4))&~a; g[230:]=False
    ys,xs=np.nonzero(g); ok=tor[...,3]>0
    for i in range(len(ys)):
        for dx in (0,12,-12,24,-24,36,-36,48,-48):
            x=int(np.clip(xs[i]+dx,0,287))
            if ok[ys[i],x]: o[ys[i],xs[i]]=(tor[ys[i],x]*np.array([.6,.58,.58,1])).astype(np.uint8); break
    return o
_g=nd.gaussian_filter(np.random.default_rng(5).random((336,288)),2.5); N2=(np.argsort(np.argsort(_g.ravel()))/_g.size).reshape(_g.shape)
OUT={}
for d in 'en':
    img,Pt,tor=build(d); R=RIG[d]
    rest=compose(d,Pt,tor)
    contact=compose(d,Pt,tor,ll=-26,rl=26,la=3,ra=3,bob=5)
    passing=compose(d,Pt,tor,ll=6,rl=-14,rly=24,la=-5,ra=-5,bob=-1)
    # two-fisted overhead slam
    wind=fillgaps(ikpose(d,Pt,tor,(116,52),(172,52),1,-1,lx=0,ly=-8,fist_behind=False,shrug=0),tor)
    strike=fillgaps(ikpose(d,Pt,tor,(118,238),(172,240),1,-1,ly=14),tor)
    lf=np.array([120,240]); rf=np.array([172,244])
    arcs=[]
    lf=np.array([118,262]); rf=np.array([172,264])
    for ep,cc in ((lf,1),(rf,-1)):
        pts=[(144-cc*12-cc*70*np.sin(np.pi*u)+(ep[0]-144+cc*12)*u, 40+(ep[1]-40)*u) for u in np.linspace(0,1,24)]
        arcs.append(stroke(lambda dr,pts=pts:dr.line(pts,fill=255,width=12),5,(255,120,40),0.5))
        arcs.append(stroke(lambda dr,pts=pts:dr.line(pts,fill=255,width=4),1.5,(255,180,90),0.65))
    for sp,ep,cc in ():
        cx=sp[0]; arcs.append(stroke(lambda dr,sp=sp,cc=cc:dr.arc([sp[0]-96,sp[1]-96,sp[0]+96,sp[1]+96],(250 if cc>0 else 120),(420 if cc>0 else 290),fill=255,width=14),6,(255,120,40),0.55))
        arcs.append(stroke(lambda dr,sp=sp,cc=cc:dr.arc([sp[0]-96,sp[1]-96,sp[0]+96,sp[1]+96],(250 if cc>0 else 120),(420 if cc>0 else 290),fill=255,width=4),1.5,(255,170,80),0.7))
    imp=[stroke(lambda dr:dr.ellipse([70,272,224,310],fill=255),7,(255,120,40),0.55),stroke(lambda dr:dr.ellipse([112,282,182,300],fill=255),4,(255,190,90),0.5)]+[embers(rng,30,147,272,46,8,34)]
    # stomp: knee up then slam the foot down
    sraise=compose(d,Pt,tor,rly=34,rl=-8,lx=-4,ly=-3,la=-3,ra=4)
    sdown=compose(d,Pt,tor,rl=4,ly=7,bob=3,la=10,ra=-6)
    stimp=[stroke(lambda dr:dr.ellipse([130,278,240,310],fill=255),7,(255,110,40),0.5),embers(rng,20,186,288,26,5,24)]
    # cast: fists out, core flares, embers rise
    cast=compose(d,Pt,tor,la=-4,ra=4,ly=-4)
    cfx=[stroke(lambda dr:dr.ellipse([100,110,190,190],fill=255),18,(255,120,40),0.35),embers(rng,30,144,120,70,30,40)]
    # hit
    hit=apply(lean(rest,-12,-2),M_rot(4,(144,300))); hit=clamp(rimc(solid(hit),0.15))
    hitfx=[embers(rng,10,170,140,26,30)]
    # death: ember-burst dissolve into a smouldering slag heap (no falling)
    heap=np.zeros_like(rest); src=paste(tor,paste(Pt['LA'],Pt['RA'])); sa=src[...,3]>0; sy_,sx_=np.nonzero(sa); hr=np.random.default_rng(11)
    for row in range(6):
        yb=236+row*12; half=115*np.sqrt(max(0.05,1-((yb-306)/80)**2))
        for k in range(int(4+row*1.8)):
            r=hr.uniform(14,22); cx=144+hr.uniform(-half+r*0.5,half-r*0.5); cy=yb+hr.uniform(-4,4)
            while True:
                j=hr.integers(len(sy_)); px,py=sx_[j],sy_[j]
                if 25<px<263 and 30<py<240: break
            m=((X-cx)/r)**2+((Y-cy)/(r*0.8))**2+0.2*np.sin(X*0.6+k)*np.cos(Y*0.5)<1
            sx=np.clip((X-cx+px).astype(int),0,287); sy=np.clip((Y-cy+py).astype(int),0,335); m&=sa[sy,sx]&(Y<=303)
            ch=src[sy,sx].copy(); ch[...,:3]=(ch[...,:3]*(0.66+0.07*row)).astype(np.uint8); heap[m]=ch[m]
    burst=rest.copy(); burst[N2<0.36]=0; burst[heap[...,3]>0]=0; burst=paste(burst,np.where((N2<0.45)[...,None],heap,0).astype(np.uint8))
    bfx=[embers(rng,60,144,170,70,70,40),stroke(lambda dr:dr.ellipse([60,120,230,300],fill=255),26,(255,100,40),0.25)]
    smoke=[stroke(lambda dr,i=i:dr.ellipse([110+i*14,230-i*16,140+i*14,262-i*16],fill=255),9,(120,108,98),0.35) for i in range(4)]
    hfx=smoke+[embers(rng,10,144,285,50,8,8),stroke(lambda dr:dr.ellipse([90,280,200,306],fill=255),8,(255,90,30),0.18)]
    L=[('rest',solid(rest),[]),('walk contact (bob 5)',solid(contact),[]),('walk passing',solid(passing),[]),
       ('slam wind-up',solid(wind),[]),('slam strike',solid(strike),arcs+imp),('stomp raise',solid(sraise),[]),('stomp impact',solid(sdown),stimp),
       ('cast',solid(cast),cfx),('hit',hit,hitfx),('death ember burst',solid(burst),bfx),('death end: slag heap',solid(heap),hfx)]
    OUT[d]=[(n,fx(o,f)) for n,o,f in L]
    for i,(n,o) in enumerate(OUT[d]): Image.fromarray(o).save(f'/workspace/foe_walks/slag_out/work/v2_still_{d}_{i:02d}.png')
f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',24)
nc=len(OUT['e']); S=Image.new('RGB',(576*nc,(672+40)*2),(28,24,22)); dr=ImageDraw.Draw(S)
for r,d in enumerate('en'):
    for i,(n,o) in enumerate(OUT[d]):
        im=Image.fromarray(o).resize((576,672),Image.NEAREST); S.paste(im,(i*576,r*712+40),im); dr.text((i*576+10,r*712+8),f'{d.upper()}  {n}',font=f,fill=(240,215,180))
S.save('/workspace/foe_walks/slag_out/slagheart_poses_contact_v2.png'); print(S.size)
