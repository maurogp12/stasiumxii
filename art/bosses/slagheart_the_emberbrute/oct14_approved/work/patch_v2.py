s=open('poses.py').read()
def R(a,b):
    global s; assert a in s,a; s=s.replace(a,b)
R("""    o=o.copy(); h=o[...,3]>=128; L=o[...,:3].astype(float)@[.299,.587,.114]; m=h&(L>135)""",
"""    o=o.copy(); h=o[...,3]>=128; c=o[...,:3].astype(float); L=c@[.299,.587,.114]; sat=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1); m=h&(L>135)&(sat<0.25)""")
R("def solid(o): return outer1(clamp(dspk.clean(clamp(o))))","def solid(o): return outer1(clamp(dspk.clean(o)))")
R("for a,c in layers: o=fxlib.comp(o,a,c,add=0.0)","for a,c in layers: o=fxlib.comp(o,a,c,add=ADD)")
R("rng=np.random.default_rng(4)","""rng=np.random.default_rng(4); ADD=0.3
ELB={'e':((52,188),(228,192)),'n':((50,182),(236,182))}
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
def ikpose(d,Pt,tor,lt,rt,lb,rb,lx=0,ly=0,fist_behind=False):
    R_=RIG[d]; body=lean(tor,lx,ly); k=0.8
    sh=[np.array(R_['ls'])+[lx*k,ly*k],np.array(R_['rs'])+[lx*k,ly*k]]; el=[np.array(e)+[lx*k,ly*k] for e in ELB[d]]
    LA=shift(Pt['LA'],lx*k,ly*k); RA=shift(Pt['RA'],lx*k,ly*k)
    lu,lf,_=arm2(LA,sh[0],el[0],lt,lb); ru,rf,_=arm2(RA,sh[1],el[1],rt,rb)
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
    return o""")
R("ll=-18,rl=18,la=9,ra=9,bob=5","ll=-26,rl=26,la=10,ra=10,bob=5")
R("ll=4,rl=-2,rly=16,la=-4,ra=-4,bob=-1","ll=6,rl=-14,rly=24,la=-5,ra=-5,bob=-1")
R("    wind=compose(d,Pt,tor,la=-138,ra=138,ly=-4,arm_dy=14)","""    wind=fillgaps(ikpose(d,Pt,tor,(134,40),(154,40),-1,1,lx=0,ly=-8,fist_behind=True),tor)""")
R("    strike=compose(d,Pt,tor,la=40,ra=-40,ly=9,arm_dy=12,ll=-6,rl=6)","""    strike=fillgaps(ikpose(d,Pt,tor,(122,268),(170,268),1,-1,ly=10),tor)""")
R("""    for sp,ep,cc in ((R['ls'],lf,1),(R['rs'],rf,-1)):""","""    lf=np.array([122,268]); rf=np.array([170,268])
    for ep,cc in ((lf,1),(rf,-1)):
        pts=[(144-cc*12-cc*70*np.sin(np.pi*u)+(ep[0]-144+cc*12)*u, 40+(ep[1]-40)*u) for u in np.linspace(0,1,24)]
        arcs.append(stroke(lambda dr,pts=pts:dr.line(pts,fill=255,width=12),5,(255,120,40),0.5))
        arcs.append(stroke(lambda dr,pts=pts:dr.line(pts,fill=255,width=4),1.5,(255,180,90),0.65))
    for sp,ep,cc in ():""")
R("imp=[stroke(lambda dr:dr.ellipse([80,262,210,306],fill=255),8,(255,110,40),0.45)]+[embers(rng,26,146,262,40,10,30)]",
  "imp=[stroke(lambda dr:dr.ellipse([70,272,224,310],fill=255),7,(255,120,40),0.55),stroke(lambda dr:dr.ellipse([112,282,182,300],fill=255),4,(255,190,90),0.5)]+[embers(rng,30,147,272,46,8,34)]")
R("la=-32,ra=32,ly=-4","la=-14,ra=14,ly=-4")
R("""    heap_m=((X-144)/92)**2+((Y-306)/46)**2<1; heap_m&=Y<=303
    heapsrc=shift(tor,0,120)  # torso rock texture slid down onto the mound
    heap=np.where((heap_m&(heapsrc[...,3]>0)&(N2>0.06))[...,None],heapsrc,0).astype(np.uint8)
    heap[...,:3]=(heap[...,:3]*0.72).astype(np.uint8)""","""    heap=np.zeros_like(rest); src=paste(tor,paste(Pt['LA'],Pt['RA'])); sa=src[...,3]>0; sy_,sx_=np.nonzero(sa); hr=np.random.default_rng(11)
    for row in range(6):
        yb=236+row*12; half=115*np.sqrt(max(0.05,1-((yb-306)/80)**2))
        for k in range(int(4+row*1.8)):
            r=hr.uniform(14,22); cx=144+hr.uniform(-half+r*0.5,half-r*0.5); cy=yb+hr.uniform(-4,4)
            while True:
                j=hr.integers(len(sy_)); px,py=sx_[j],sy_[j]
                if 25<px<263 and 30<py<240: break
            m=((X-cx)/r)**2+((Y-cy)/(r*0.8))**2+0.2*np.sin(X*0.6+k)*np.cos(Y*0.5)<1
            sx=np.clip((X-cx+px).astype(int),0,287); sy=np.clip((Y-cy+py).astype(int),0,335); m&=sa[sy,sx]&(Y<=303)
            ch=src[sy,sx].copy(); ch[...,:3]=(ch[...,:3]*(0.66+0.07*row)).astype(np.uint8); heap[m]=ch[m]""")
open('poses.py','w').write(s)
