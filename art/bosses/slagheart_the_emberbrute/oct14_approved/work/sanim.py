import numpy as np, os
from PIL import Image
src=open('poses.py').read(); exec(src[:src.index('OUT={}')]); exec(open('/workspace/foe_walks/caldera_out/work/hipfix.py').read())
OUTD='/workspace/foe_walks/slag_out/strips'; os.makedirs(OUTD+'/body_only',exist_ok=True)
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
    # slam 12: rig raise (0-2) -> noise blend into painted wind-up (3-4) hold (5) -> painted strike (6-8) -> blend back (9-11)
    pre=keys([(0,{}),(3,dict(la=-24,ra=24,ly=-6,arm_dy=-6))],4)
    sl=[C(d,Pt,tor,pre[0]),C(d,Pt,tor,pre[1]),C(d,Pt,tor,pre[2])]
    r3=C(d,Pt,tor,pre[3])
    # anticipation hold, then a 3-step crossfade with the rig scaled toward the painted wind-up height (feet anchored)
    wa=W[...,3]>0; ra_=r3[...,3]>0; hw=300-np.nonzero(wa.any(1))[0].min(); hr_=300-np.nonzero(ra_.any(1))[0].min()
    def scl(o,k): return apply(o,np.array([[1+0*k,0,0],[0,k,300*(1-k)],[0,0,1]]))
    sl+=[r3]
    for u in (0.25,0.5,0.75):
        kk=1+(hw/hr_-1)*u; sl.append(xfade(scl(r3,kk),W,u))
    sl+=[W,K,K,K,xfade(K,rest,0.35),xfade(K,rest,0.7),rest]
    S['slam']=sl
    stp=keys([(0,{}),(3,dict(rly=34,rl=-8,lx=-4,ly=-3,la=-3,ra=4)),(4,dict(rly=36,rl=-9,lx=-4,ly=-4,la=-3,ra=4)),(5,dict(rl=4,ly=7,bob=3,la=8,ra=-6)),(6,dict(rl=3,ly=6,bob=3,la=7,ra=-5)),(9,{})],10)
    S['stomp']=[C(d,Pt,tor,p) for p in stp]
    cst=keys([(0,{}),(3,dict(la=-4,ra=4,ly=-5,arm_dy=-3)),(7,dict(la=-5,ra=5,ly=-6,arm_dy=-4)),(9,{})],10)
    S['cast']=[C(d,Pt,tor,p) for p in cst]
    ht=keys([(0,{}),(1,dict(lx=-12,ly=-2)),(2,dict(lx=-10,ly=-2)),(5,{})],6); tl=[0,4,3,1.5,0.5,0]; rm=[0,0.15,0.1,0.05,0.02,0]
    S['hit']=[clamp(rimc(apply(C(d,Pt,tor,p),M_rot(tl[i],(144,300))),rm[i])) if rm[i] else apply(C(d,Pt,tor,p),M_rot(tl[i],(144,300))) for i,p in enumerate(ht)]
    heap=heapimg(tor,Pt)
    de=[]
    for f in range(16):
        u=f/15; k=ease(min(1,u/0.75)); hk=ease(np.clip((u-0.15)/0.6,0,1))
        b=rest.copy(); b[N2<k*1.1-0.05]=0
        hp=heap.copy(); hp[N2>hk*1.05]=0
        de.append(paste(b,hp) if f<15 else heap.copy())
    S['death']=de
    for a in S: S[a]=[solid(o) for o in S[a]]
    BODY[d]={a:[o.copy() for o in v] for a,v in S.items()}
    # --- soft lava fx baked onto strips
    rg=np.random.default_rng(7)
    for i in range(8,11):
        t=(i-8)/2
        S['slam'][i]=fx(S['slam'][i],[glow([60-10*t,270,228+10*t,312],8,(255,110,40),0.55*(1-0.4*t)),crack(np.random.default_rng(3),144,290,11,70+20*t,0.7*(1-0.3*t)),embers(rg,int(30-8*t),144,270-20*t,40+20*t,10+8*t,30+30*t)])
    for i in (5,6,7):
        t=(i-5)/2; S['stomp'][i]=fx(S['stomp'][i],[glow([126-12*t,280,244+12*t,312],7,(255,110,40),0.5*(1-0.4*t)),crack(np.random.default_rng(4),186,296,7,40+16*t,0.6*(1-0.3*t)),embers(rg,18,186,288-14*t,24+12*t,5,24)])
    for i in range(10):
        g=np.sin(np.pi*i/9)
        if g>0.05: S['cast'][i]=fx(S['cast'][i],[glow([100,105,190,195],18,(255,120,40),0.35*g),embers(rg,int(30*g),144,120-i*4,60,30,40)])
    S['hit'][1]=fx(S['hit'][1],[embers(rg,12,170,140,26,30)])
    for f in range(16):
        u=f/15; g=np.sin(np.pi*min(1,u/0.8))
        L_=[embers(rg,int(60*g)+4,144,170+60*u,60+40*u,60,40)]
        if u<0.8: L_.append(glow([60,120,230,300],26,(255,100,40),0.25*g))
        if u>0.5: L_+=[stroke(lambda dr,i=i:dr.ellipse([110+i*14,214-i*16,140+i*14,246-i*16],fill=255),9,(120,108,98),0.3*(u-0.5)*2) for i in range(4)]
        S['death'][f]=fx(S['death'][f],L_)
    STR[d]=S
# naming per verify.json facing: front key = s (down-right), mirror w; back key = e (up-right), mirror n
MAP={'s':('e',False),'w':('e',True),'e':('n',False),'n':('n',True)}
for dn,(src_d,mir) in MAP.items():
    for a in STR[src_d]:
        for store,D_ in ((STR,OUTD),(BODY,OUTD+'/body_only')):
            L_=[o[:,::-1] if mir else o for o in store[src_d][a]]
            Image.fromarray(np.concatenate(L_,1)).save(f'{D_}/slagheart_{a}_{dn}.png')
print('STEP_CELL',round(STEP_CELL,2),{a:len(v) for a,v in STR['e'].items()})
