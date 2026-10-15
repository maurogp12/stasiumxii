import numpy as np, os, json
from PIL import Image
exec(open('clib.py').read()); exec(open('hipfix.py').read())
src=open('canim.py').read(); exec(src[src.index('def degreen'):src.index('for st in (STR,BODY)')])
ease=lambda u:u*u*(3-2*u)
OUTD='/workspace/foe_walks/caldera_out/strips'
HA=14.0
def legparts(P,hip):
    a=P[...,3]>0; ys,xs=np.nonzero(a); kn_y=int((hip[1]+ys.max())/2)+4
    th=P.copy(); th[Y>=kn_y]=0; sh=P.copy(); sh[Y<kn_y]=0
    band=P.copy(); band[(Y<kn_y-2)|(Y>kn_y+18)]=0; acc=np.zeros_like(P)
    for k in range(24,0,-2): q=shift(band,0,-k); q[...,:3]=(q[...,:3]*0.75).astype(np.uint8); acc=paste(acc,q)
    sh=paste(acc,sh)   # shin extended up behind the knee so the bend never opens a gap
    kx=xs[(ys>kn_y-3)&(ys<kn_y+3)].mean(); return th,sh,np.array([kx,kn_y],float)
def legpose(ph,HA=HA):
    """ph 0..1; 0-0.5 stance (hip +HA -> -HA, knee straight), 0.5-1 swing (knee bends and lifts)"""
    if ph<0.5: u=ph/0.5; return HA*(1-2*u),0.0
    u=(ph-0.5)/0.5; return -HA+2*HA*ease(u)+8*np.sin(np.pi*u), -30*np.sin(np.pi*u)
def leg(th,sh,hip,kn,a_h,a_k):
    T=apply(th,M_rot(a_h,hip)); M=M_rot(a_h,hip); kn2=M[:2,:2]@kn+M[:2,2]
    S_=apply(sh,M_rot(a_h+a_k,kn,kn2[0]-kn[0],kn2[1]-kn[1])); return paste(S_,T)
def walkframe(d,Pt,tor,PV,L,Rr,f):
    R=RIG[d]; p=f/8.0; out={}
    phl=p%1; phr=(p+0.5)%1
    if d=='e':   # front key: per-leg hip amplitude so both soles travel the same distance per frame (no slide)
        Lh={k_:np.linalg.norm(SOLE[d][k_][0]-np.array(R['lh' if k_=='LL' else 'rh'],float)) for k_ in ('LL','RL')}; Lm=np.mean(list(Lh.values()))
        hal=np.degrees(np.arcsin(Lm*np.sin(np.radians(HA))/Lh['LL'])); har=np.degrees(np.arcsin(Lm*np.sin(np.radians(HA))/Lh['RL']))
        al,kl=legpose(phl,hal); ar,kr=legpose(phr,har)
    else: al,kl=legpose(phl); ar,kr=legpose(phr)
    if d=='e': al,kl,ar,kr=-al,-kl,-ar,-kr   # front key is painted facing screen-left: forward = -x, so planted foot sweeps +x and the knee bends to +x (behind)
    LLi=leg(L[0],L[1],np.array(R['lh'],float),L[2],al,kl); RLi=leg(Rr[0],Rr[1],np.array(R['rh'],float),Rr[2],ar,kr)
    stance_l=phl<0.5
    k_='LL' if stance_l else 'RL'; s0,tgt=SOLE[d][k_]; hp=np.array(R['lh' if stance_l else 'rh'],float)
    M=M_rot(al if stance_l else ar,hp); sp=M[:2,:2]@s0+M[:2,2]; PL=LLi if stance_l else RLi; dy=tgt-np.nonzero(PL[...,3]>0)[0].max()   # exact pixel sole on its line
    # swing foot: guaranteed clearance (knee lift), never dips below its ground line
    sw='RL' if stance_l else 'LL'; uph=(phr if stance_l else phl); lift=16*np.sin(np.pi*max(0,(uph-0.5)/0.5))
    SW=RLi if stance_l else LLi; yb=np.nonzero(SW[...,3]>0)[0].max()+dy; need=SOLE[d][sw][1]-lift
    if yb>need or lift<1: SW=shift(SW,0,need-yb)
    if stance_l: RLi=SW
    else: LLi=SW
    # weight over planted leg (x), down bob at contact (frames 0,4), up at passing
    side=-1 if stance_l else 1; wx=side*2.5*np.sin(np.pi*((p*2)%1))
    bob=3*np.cos(2*np.pi*p*2)*0.5+1.5 if False else 3*max(0,np.cos(4*np.pi*p))   # 3px down on contact
    cs=4*np.sin(2*np.pi*p)   # arm counter swing
    body=shift(lean(tor,0,0),wx,bob); pv=shift(PV,wx,bob)
    arms=[shift(apply(Pt['LA'],M_rot(cs,R['ls'])),wx,bob),shift(apply(Pt['RA'],M_rot(-cs,R['rs'])),wx,bob)]
    legs=paste(LLi,RLi) if not stance_l else paste(RLi,LLi)
    o=paste(paste(legs,pv),body)
    for A_ in arms: o=paste(o,A_)
    # grounding: planted foot sole -> y=300 exactly
    # grounding: track the planted leg's rest sole point through its hip rotation; near foot rests on y=300,
    # the far foot keeps its 3/4 depth offset from the key (it is further up the tile), so the hip height never jumps
    o=shift(o,0,dy)
    return o,(sp[0],sp[1]+dy)
res={}; SOLE={}; FX={}
for d in 'en':
    img,Pt,tor=build(d); Pt,tor=_fixparts(d,Pt,tor); R=RIG[d]
    LL=_extleg(Pt['LL'],R,0); RL=_extleg(Pt['RL'],R,1); PV=_pelvis(d,Pt,tor)
    L=legparts(LL,R['lh']); Rr=legparts(RL,R['rh'])
    SOLE[d]={}; bots={}
    for k_ in ('LL','RL'):
        ys,xs=np.nonzero(Pt[k_][...,3]>0); bots[k_]=(np.array([xs[ys>ys.max()-4].mean(),ys.max()],float))
    mx=max(b[1] for b in bots.values())
    for k_,b in bots.items(): SOLE[d][k_]=(b,300-(mx-b[1]))
    fr=[walkframe(d,Pt,tor,PV,L,Rr,f) for f in range(8)]
    fx=[x[1][0] for x in fr]; print(d,'planted sole y',[round(x[1][1],1) for x in fr]); fr=[degreen(solid(x[0])) for x in fr]
    # stance foot travel per frame (cell px) -> ground speed
    trav=[abs(fx[f]-fx[f+1]) for f in range(8) if (f%4)!=3]
    res[d]=(fr,float(np.mean(trav))); FX[d]=[float(x) for x in fx]
    print(d,'stance foot x',[round(v,1) for v in fx],'travel/frame',round(np.mean(trav),2))
MAP={'s':('e',True),'w':('e',False),'e':('n',False),'n':('n',True)}   # n,e unchanged; s=-n, w=-e (front key faces down-left as painted)
for dn,(sd,mir) in [(k,v_) for k,v_ in MAP.items() if k in 'sw']:   # n/e locked
    L_=[o[:,::-1] if mir else o for o in res[sd][0]]
    for D_ in (OUTD,OUTD+'/body_only'): Image.fromarray(np.concatenate(L_,1)).save(f'{D_}/caldera_walk_{dn}.png')
json.dump({k:v[1] for k,v in res.items()},open('walk_step.json','w'))

json.dump(FX,open('walk_solex.json','w'))
