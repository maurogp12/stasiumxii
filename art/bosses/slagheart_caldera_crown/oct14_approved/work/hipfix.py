# hip seam fix: legs extended up under torso (>=24px overlap, behind torso), pelvis filler attached to torso, bob clamped
def _extleg(P,R,side):
    a=P[...,3]>0; ys,xs=np.nonzero(a); top=ys.min(); band=P.copy(); band[Y>top+30]=0
    acc=np.zeros_like(P)
    for k in range(28,0,-4): q=shift(band,0,-k); q[...,:3]=(q[...,:3]*0.7).astype(np.uint8); acc=paste(acc,q)
    return paste(acc,P)
def _pelvis(d,Pt,tor):
    R=RIG[d]; full=paste(paste(Pt['LL'],Pt['RL']),tor); hy=int(min(R['lh'][1],R['rh'][1]))
    m=(full[...,3]>0)&(Y>hy-30)&(Y<hy+22)&(X>R['lh'][0]-22)&(X<R['rh'][0]+22)
    m&=((X-(R['lh'][0]+R['rh'][0])/2)/((R['rh'][0]-R['lh'][0])/2+22))**2+((Y-hy+4)/26)**2<1
    o=np.where(m[...,None],full,0).astype(np.uint8); o[m,:3]=(o[m,:3]*0.8).astype(np.uint8); return o
_EXT={}
def compose(d,Pt,tor,la=0,ra=0,ll=0,rl=0,lly=0,rly=0,arm_dy=0,lx=0,ly=0,bob=0):
    R=RIG[d]; key=(d,id(Pt))
    if key not in _EXT: _EXT[key]=(_extleg(Pt['LL'],R,0),_extleg(Pt['RL'],R,1),_pelvis(d,Pt,tor))
    LL,RL,PV=_EXT[key]; bob=float(np.clip(bob,-3,3))
    body=lean(tor,lx,ly)
    legs=paste(apply(LL,M_rot(ll,R['lh'],0,-lly)),apply(RL,M_rot(rl,R['rh'],0,-rly)))
    arms=[apply(shift(Pt['LA'],lx*0.8,ly*0.8+arm_dy),M_rot(la,(R['ls'][0]+lx*0.8,R['ls'][1]+ly*0.8))),apply(shift(Pt['RA'],lx*0.8,ly*0.8+arm_dy),M_rot(ra,(R['rs'][0]+lx*0.8,R['rs'][1]+ly*0.8)))]
    o=paste(legs,shift(lean(PV,lx,ly),0,bob)); o=paste(o,shift(body,0,bob))
    for A_ in arms: o=paste(o,shift(A_,0,bob))
    return o
def _fixparts(d,Pt,tor):
    # torso/limb fragments that only touch other parts in the rest pose: hand them to the part they hang from
    for k in ('tor','LA','RA','LL','RL'):
        P=tor if k=='tor' else Pt[k]; m=P[...,3]>0; lb,n=nd.label(m,np.ones((3,3)))
        if n<2: continue
        sz=nd.sum(m,lb,range(1,n+1)); big=np.argmax(sz)+1
        for j in range(1,n+1):
            if j==big: continue
            f=lb==j; ring=nd.binary_dilation(f,iterations=3)&~f; best=None
            for k2 in ('tor','LA','RA','LL','RL'):
                if k2==k: continue
                Q=tor if k2=='tor' else Pt[k2]; c=(Q[...,3][ring]>0).sum()
                if best is None or c>best[0]: best=(c,k2)
            Q=tor if best[1]=='tor' else Pt[best[1]]; Q[f]=P[f]; P[f]=0
    return Pt,tor
