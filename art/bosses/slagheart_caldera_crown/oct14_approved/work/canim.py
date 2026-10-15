import numpy as np, os
from PIL import Image
exec(open('clib.py').read()); exec(open('hipfix.py').read())
OUTD='/workspace/foe_walks/caldera_out/strips'; os.makedirs(OUTD+'/body_only',exist_ok=True)
ease=lambda u:u*u*(3-2*u)
def lerp(a,b,u): return {k:a.get(k,0)*(1-u)+b.get(k,0)*u for k in set(a)|set(b)}
def keys(K,nf):
    out=[]
    for f in range(nf):
        for (f0,a),(f1,b) in zip(K,K[1:]):
            if f0<=f<=f1: break
        out.append(lerp(a,b,0 if f1==f0 else ease((f-f0)/(f1-f0))))
    return out
def xfade(A,B,u):  # hard-alpha noise crossfade A->B
    o=A.copy(); m=N2<u; o[m]=B[m]; return o
def heapimg(tor,Pt,seed=11):
    heap=np.zeros((336,288,4),np.uint8); src_=paste(tor,paste(Pt['LA'],Pt['RA'])); sa=src_[...,3]>0; sy_,sx_=np.nonzero(sa); hr=np.random.default_rng(seed)
    for row in range(6):
        yb=236+row*12; half=115*np.sqrt(max(0.05,1-((yb-306)/80)**2))
        for k in range(int(4+row*1.8)):
            r=hr.uniform(14,22); cx=144+hr.uniform(-half+r*0.5,half-r*0.5); cy=yb+hr.uniform(-4,4)
            while True:
                j=hr.integers(len(sy_)); px,py=sx_[j],sy_[j]
                if 25<px<263 and 30<py<240: break
            m=((X-cx)/r)**2+((Y-cy)/(r*0.8))**2+0.2*np.sin(X*0.6+k)*np.cos(Y*0.5)<1
            sx=np.clip((X-cx+px).astype(int),0,287); sy=np.clip((Y-cy+py).astype(int),0,335); m&=sa[sy,sx]&(Y<=303)
            ch=src_[sy,sx].copy(); ch[...,:3]=(ch[...,:3]*(0.66+0.07*row)).astype(np.uint8); heap[m]=ch[m]
    return heap
def glow(box,blur,col,al): return stroke(lambda dr:dr.ellipse(box,fill=255),blur,col,al)
def crack(rng,cx,cy,n=9,L=60,al=0.7):
    def fn(dr):
        for i in range(n):
            a=np.pi*(i/n)+rng.uniform(-0.15,0.15); p=[(cx,cy)]
            for s_ in range(5): p.append((p[-1][0]+np.cos(a)*L/5*(1 if i%2 else -1)*rng.uniform(.7,1.2)+rng.normal(0,2),p[-1][1]+abs(np.sin(a))*L/18+rng.normal(0,1.5)))
            dr.line(p,fill=255,width=3)
    return stroke(fn,1.2,(255,140,40),al)
L_LEG=100.0; AW=26.0
STEP_CELL=2*L_LEG*np.sin(np.radians(AW))/4   # stance foot travel per frame (pinned feet)
def walkp(f):
    p=(f/8.0)%1.0; P={}
    for side,ph in (('l',p),('r',(p+0.5)%1)):
        if ph<0.5: u=ph/0.5; x=L_LEG*np.sin(np.radians(AW))*(1-2*u); lift=0   # stance: foot moves back linearly
        else: u=(ph-0.5)/0.5; x=L_LEG*np.sin(np.radians(AW))*(-1+2*ease(u)); lift=22*np.sin(np.pi*u)
        P[side+'l']=np.degrees(np.arcsin(np.clip(x/L_LEG,-1,1))); P[side+'ly']=lift
    bob=5*abs(np.cos(2*np.pi*p))  # down at contact (legs spread), up at passing
    return dict(ll=P['ll'],rl=P['rl'],lly=P['lly'],rly=P['rly'],la=-3*np.sin(2*np.pi*p),ra=-3*np.sin(2*np.pi*p),bob=bob-2.5)
def C(d,Pt,tor,p): 
    q={k:p.get(k,0) for k in ('la','ra','ll','rl','lly','rly','arm_dy','lx','ly','bob')}; return compose(d,Pt,tor,**q)
STR={}; BODY={}
for d in 'en':
    img,Pt,tor=build(d); Pt,tor=_fixparts(d,Pt,tor); R=RIG[d]; S={}; F={}
    rest=C(d,Pt,tor,{})
    S['walk']=[C(d,Pt,tor,walkp(f)) for f in range(8)]
    S['idle']=[C(d,Pt,tor,dict(ly=2*np.sin(np.pi*i/6)**2,bob=1.5*np.sin(np.pi*i/6)**2,la=1.5*np.sin(2*np.pi*i/6),ra=-1.5*np.sin(2*np.pi*i/6))) for i in range(6)]
    W=np.array(Image.open(f'slam_wind_{d}.png')); K=np.array(Image.open(f'slam_strike_{d}.png'))
    _m=K[...,3]>0; _lb,_n=nd.label(_m,np.ones((3,3))); _s=nd.sum(_m,_lb,range(1,_n+1)); K[(_lb>0)&(_lb!=np.argmax(_s)+1)]=0   # drop loose painted pebbles
    # slam 12: rig raise (0-2) -> noise blend into painted wind-up (3-4) hold (5) -> painted strike (6-8) -> blend back (9-11)
    pre=keys([(0,{}),(3,dict(la=-24,ra=24,ly=-6,arm_dy=-6))],4)
    sl=[C(d,Pt,tor,pre[0]),C(d,Pt,tor,pre[1]),C(d,Pt,tor,pre[2])]
    r3=C(d,Pt,tor,pre[3])
    # anticipation hold, then a 3-step crossfade with the rig scaled toward the painted wind-up height (feet anchored)
    wa=W[...,3]>0; ra_=r3[...,3]>0; hw=300-np.nonzero(wa.any(1))[0].min(); hr_=300-np.nonzero(ra_.any(1))[0].min()
    def scl(o,k): return apply(o,np.array([[1+0*k,0,0],[0,k,300*(1-k)],[0,0,1]]))
    def smear(o,dy):  # solid motion smear: stacked offsets of one pose, trailing copies darker (no two-pose mix)
        acc=np.zeros_like(o)
        for j,t in enumerate(np.linspace(1,0,7)):
            q=shift(o,0,dy*t); q[...,:3]=(q[...,:3]*(0.55+0.45*(1-t))).astype(np.uint8); acc=paste(acc,q)
        return acc
    SMW=smear(W,24); SMR=smear(rest,-18)
    sl+=[r3,SMW,W,W,W,K,K,K,SMR,rest,rest]
    SMEAR_IDX=(4,11)
    S['slam']=sl
    stp=keys([(0,{}),(3,dict(rly=34,rl=-8,lx=-4,ly=-3,la=-3,ra=4)),(4,dict(rly=36,rl=-9,lx=-4,ly=-4,la=-3,ra=4)),(5,dict(rl=4,ly=7,bob=3,la=8,ra=-6)),(6,dict(rl=3,ly=6,bob=3,la=7,ra=-5)),(9,{})],10)
    S['stomp']=[C(d,Pt,tor,p) for p in stp]
    cst=keys([(0,{}),(3,dict(la=-5,ra=5,ly=-7,arm_dy=-4)),(7,dict(la=-6,ra=6,ly=-8,arm_dy=-5)),(9,{})],10)
    S['cast_meteor']=[C(d,Pt,tor,p) for p in cst]
    ce=keys([(0,{}),(3,dict(ly=-4,arm_dy=-4,la=-3,ra=3)),(5,dict(ly=8,arm_dy=8,bob=2,la=4,ra=-4)),(6,dict(ly=8,arm_dy=8,bob=2,la=4,ra=-4)),(9,{})],10)
    S['cast_eruption']=[C(d,Pt,tor,p) for p in ce]
    ht=keys([(0,{}),(1,dict(lx=-12,ly=-2)),(2,dict(lx=-10,ly=-2)),(5,{})],6); tl=[0,4,3,1.5,0.5,0]; rm=[0,0.15,0.1,0.05,0.02,0]
    S['hit']=[clamp(rimc(apply(C(d,Pt,tor,p),M_rot(tl[i],(144,300))),rm[i])) if rm[i] else apply(C(d,Pt,tor,p),M_rot(tl[i],(144,300))) for i,p in enumerate(ht)]
    heap=heapimg(tor,Pt,seed=13)
    hh_=heap[...,3]>0; hole=nd.binary_fill_holes(nd.binary_closing(hh_,iterations=6))&~hh_
    for dx_ in (18,-18,30,-30,42,-42,0):
        if not hole.any(): break
        ys_,xs_=np.nonzero(hole); sx_=np.clip(xs_+dx_,0,287); sy_=np.clip(ys_+(8 if dx_==0 else 0),0,335); okk=hh_[sy_,sx_]
        heap[ys_[okk],xs_[okk]]=(heap[sy_[okk],sx_[okk]]*np.array([.85,.85,.85,1])).astype(np.uint8); hole[ys_[okk],xs_[okk]]=False; hh_=heap[...,3]>0
    hm=heap[...,3]>0; c_=heap[...,:3].astype(float); s_=(c_.max(-1)-c_.min(-1))/np.maximum(c_.max(-1),1); m_=hm&(s_>0.45); c_[m_]=np.minimum(255,c_[m_]*1.35); heap[...,:3]=c_.astype(np.uint8)
    # crown: spiked head/crown region, enlarged 1.5x, set upright on top of the heap
    a_=rest[...,3]>0; top_=np.nonzero(a_.any(1))[0].min(); cm=a_&(Y<top_+46)&(X>90)&(X<198)
    cyx=np.nonzero(cm); cimg=rest[cyx[0].min():cyx[0].max()+1,cyx[1].min():cyx[1].max()+1].copy(); cimg[~cm[cyx[0].min():cyx[0].max()+1,cyx[1].min():cyx[1].max()+1]]=0
    ci=np.array(Image.fromarray(cimg).resize((int(cimg.shape[1]*1.5),int(cimg.shape[0]*1.5)),Image.NEAREST))
    hy=np.nonzero(heap[...,3].any(1))[0].min()
    CROWN=np.zeros_like(rest); y0=hy+34-ci.shape[0]; x0=144-ci.shape[1]//2; CROWN[y0:y0+ci.shape[0],x0:x0+ci.shape[1]]=ci
    de=[]
    for f in range(16):
        u=f/15; k=ease(min(1,u/0.75)); hk=ease(np.clip((u-0.15)/0.6,0,1))
        b=rest.copy(); b[N2<k*1.1-0.05]=0
        hp=heap.copy(); hp[N2>hk*1.05]=0
        cr=CROWN.copy(); cr[N2>hk*1.05]=0
        de.append(paste(paste(b,cr),hp) if f<15 else paste(CROWN,heap))
    S['death']=de
    for a in S: S[a]=[solid(o) for o in S[a]]
    BODY[d]={a:[o.copy() for o in v] for a,v in S.items()}
    # --- soft lava fx baked onto strips
    rg=np.random.default_rng(7)
    for i in SMEAR_IDX:   # orange motion arc on the smear frame
        S['slam'][i]=fx(S['slam'][i],[stroke(lambda dr:dr.arc([54,30,234,250],200,340,fill=255,width=16),6,(255,120,40),0.55),stroke(lambda dr:dr.arc([54,30,234,250],200,340,fill=255,width=5),1.5,(255,175,80),0.7)])
    for i in range(8,11):
        t=(i-8)/2
        S['slam'][i]=fx(S['slam'][i],[glow([60-10*t,270,228+10*t,312],8,(255,110,40),0.55*(1-0.4*t)),crack(np.random.default_rng(3),144,290,11,70+20*t,0.7*(1-0.3*t)),embers(rg,int(30-8*t),144,270-20*t,40+20*t,10+8*t,30+30*t)])
    for i in (5,6,7):
        t=(i-5)/2; S['stomp'][i]=fx(S['stomp'][i],[glow([126-12*t,280,244+12*t,312],7,(255,110,40),0.5*(1-0.4*t)),crack(np.random.default_rng(4),186,296,7,40+16*t,0.6*(1-0.3*t)),embers(rg,18,186,288-14*t,24+12*t,5,24)])
    HC=(127,162) if d=='e' else (140,150)
    for i in range(10):
        g=np.sin(np.pi*i/9)
        if g>0.05: S['cast_meteor'][i]=fx(S['cast_meteor'][i],[glow([HC[0]-34-20*g,HC[1]-34-20*g,HC[0]+34+20*g,HC[1]+34+20*g],14,(255,130,40),0.5*g),embers(rg,int(34*g),144,110-i*5,50,26,50)])
        if 4<=i<=7: S['cast_eruption'][i]=fx(S['cast_eruption'][i],[glow([80,282,208,310],7,(255,110,40),0.45*(1-(i-4)/4)),embers(rg,16,144,288,40,6,20)])
    S['hit'][1]=fx(S['hit'][1],[embers(rg,12,170,140,26,30),shards(rg,8,170,140,26,30)])
    for f in range(16):
        u=f/15; g=np.sin(np.pi*min(1,u/0.8))
        L_=[embers(rg,int(60*g)+4,144,170+60*u,60+40*u,60,40),shards(rg,int(36*g)+2,144,170+60*u,70+40*u,60)]
        if u<0.8: L_.append(glow([60,120,230,300],26,(255,100,40),0.25*g))
        if u>0.5: L_+=[stroke(lambda dr,i=i:dr.ellipse([110+i*14,214-i*16,140+i*14,246-i*16],fill=255),9,(120,108,98),0.3*(u-0.5)*2) for i in range(4)]
        S['death'][f]=fx(S['death'][f],L_)
    STR[d]=S
# naming per verify.json facing: front key = s (down-right), mirror w; back key = e (up-right), mirror n
def degreen(o):
    o=o.copy(); c=o[...,:3].astype(float); mx=c.max(-1); mn=c.min(-1); sat=(mx-mn)/np.maximum(mx,1)
    r,g,b=c[...,0],c[...,1],c[...,2]; d=np.maximum(mx-mn,1e-6)
    h=np.where(mx==r,(60*((g-b)/d))%360,np.where(mx==g,60*((b-r)/d)+120,60*((r-g)/d)+240))
    m=(o[...,3]>0)&(h>=70)&(h<=170)&(sat>0.2); L=c@[.299,.587,.114]
    hot=m&(L>70); cold=m&~hot
    o[hot,:3]=np.stack([np.minimum(255,L[hot]*1.9),L[hot]*1.0,L[hot]*0.3],-1).clip(0,255).astype(np.uint8)
    o[cold,:3]=np.stack([L[cold]*1.25,L[cold]*0.95,L[cold]*0.8],-1).clip(0,255).astype(np.uint8)
    return o
for st in (STR,BODY):
    for d_ in st:
        for a_ in st[d_]: st[d_][a_]=[degreen(o) for o in st[d_][a_]]
MAP={'s':('e',True),'w':('e',False),'e':('n',False),'n':('n',True)}   # n,e unchanged; s=-n, w=-e (front key faces down-left as painted)
for dn,(src_d,mir) in MAP.items():
    for a in STR[src_d]:
        for store,D_ in ((STR,OUTD),(BODY,OUTD+'/body_only')):
            L_=[o[:,::-1] if mir else o for o in store[src_d][a]]
            Image.fromarray(np.concatenate(L_,1)).save(f'{D_}/caldera_{a}_{dn}.png')
print('STEP_CELL',round(STEP_CELL,2),{a:len(v) for a,v in STR['e'].items()})
