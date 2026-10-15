import numpy as np, cv2, scipy.ndimage as nd
from PIL import Image, ImageDraw, ImageFilter
src=open('../walk_v3/glide.py').read(); exec(src[:src.index('MAP=')])
CW,CH,OXc,OYc=640,440,176,104     # attack cell; key cell pasted at (96,104) -> base at (240,404)
# staff geometry in key-cell px (hand pivot, staff end points) from keys_turned
GEO={'front':dict(piv=(96,138),a=(12,288),b=(104,118),hand=(94,140)),'back':dict(piv=(203,106),a=(150,215),b=(244,28),hand=(203,106))}
ANG={'front':dict(w=290.0,s=165.0),'back':dict(w=-98.0,s=-12.0)}
# arm rig (key px): shoulder, elbow, hand ; per-frame upper-arm / forearm rotation (deg) for wind-up W and strike S
ARM={'front':dict(sh=(114,110),el=(106,124),hd=(96,139),wu=58,wf=34,su=-14,sf=-22),'back':dict(sh=(160,108),el=(174,121),hd=(189,117),wu=-62,wf=-38,su=14,sf=24)}   # screen angle (deg, y down) of the staff TIP direction
def segmask(a,b,r):
    a=np.array(a,float); b=np.array(b,float); v=b-a; t=np.clip(((xx-a[0])*v[0]+(yy-a[1])*v[1])/(v@v),0,1)
    return np.hypot(xx-(a[0]+t*v[0]),yy-(a[1]+t*v[1]))<r
def rotM(deg,piv):
    t=np.radians(deg); c,s=np.cos(t),np.sin(t); R=np.array([[c,-s],[s,c]]); P=np.array(piv,float)
    return np.float32(np.hstack([R,(P-R@P)[:,None]]))
ease=lambda u:u*u*(3-2*u)
def build(k):
    g=GEO[k]; P=list(prep(k)); body=P[0].copy(); main=P[1]
    allm=body[...,3]>0; seg=segmask(g['a'],g['b'],9)
    st=allm&(seg|(np.hypot(xx-g['hand'][0],yy-g['hand'][1])<11))
    lb_,n_=nd.label(allm,np.ones((3,3)))   # any loose piece (staff tip spikes) that touches the staff line goes with the staff
    for j in range(1,n_+1):
        cm=lb_==j
        if (cm&seg).any() and cm.sum()<3000: st|=cm
    P[3]=[S for S in P[3] if not (S&st).any()]
    R=ARM[k]; circ=lambda c,r:np.hypot(xx-c[0],yy-c[1])<r
    hc=circ(R['hd'],10)|circ(g['hand'],11); st=st&~(hc&~seg); fo=allm&~(st&~hc)&(segmask(R['el'],R['hd'],7)|circ(R['el'],8)|hc)
    up=allm&~st&~fo&(segmask(R['sh'],R['el'],8)|circ(R['sh'],9))
    LAY={n_:np.where(m_[...,None],body,0).astype(np.uint8) for n_,m_ in (('up',up),('fo',fo))}
    STAFF=np.where(st[...,None],body,0).astype(np.uint8)
    st=st|fo|up
    # fill the vacated pixels that lie inside her silhouette with nearby robe (clone, darkened); outside -> transparent
    sil=nd.binary_closing(main&~st,iterations=4)&st
    b2=body.copy(); b2[st]=0; ok=b2[...,3]>0; ys,xs=np.nonzero(sil)
    for dx_ in (10,-10,16,-16,0):
        sx=np.clip(xs+dx_,0,287); sy=np.clip(ys+(8 if dx_==0 else 0),0,335); g_=ok[sy,sx]&~(b2[ys,xs,3]>0)
        b2[ys[g_],xs[g_]]=(body[sy[g_],sx[g_]]*np.array([.8,.8,.8,1])).astype(np.uint8)
    P[0]=b2; P[1]=b2[...,3]>0; P[2]=np.zeros_like(main)
    tip=np.array(g['a'] if k=='front' else g['b'],float)-np.array(g['piv'],float); a0=np.degrees(np.arctan2(tip[1],tip[0]))
    return P,STAFF,a0,LAY
def place(L,deg,P0,Q):   # rotate layer (key-cell px) by deg about P0 then move P0->Q (big-cell px)
    S=np.zeros((CH,CW,4),np.uint8); S[OYc:OYc+336,OXc:OXc+288]=L; p=np.array(P0,float)+[OXc,OYc]
    M=rotM(deg,p); M[:,2]+=np.float32(np.array(Q,float)-p)
    return cv2.warpAffine(S,M,(CW,CH),flags=cv2.INTER_NEAREST,borderValue=(0,0,0,0))
def rv(v,deg): t=np.radians(deg); return np.array([np.cos(t)*v[0]-np.sin(t)*v[1],np.sin(t)*v[0]+np.cos(t)*v[1]])
def bodyoff(P,f,tx,pt):   # where the glide warp moves a body point (so the arm rides the bob/lean, no seam)
    b=np.zeros_like(P[0]); x,y=pt; b[y-3:y+4,x-3:x+4]=255
    q=np.array(frame([b,P[1],np.zeros_like(P[1]),[],P[4]],f,tx))[...,0]>200
    ys,xs=np.nonzero(q); return np.array([xs.mean()-x,ys.mean()-y]) if len(xs) else np.zeros(2)
def staff_at(STAFF,k,ang,a0):   # warped in the big attack cell so the raised/extended staff is never clipped
    S=np.zeros((CH,CW,4),np.uint8); S[OYc:OYc+336,OXc:OXc+288]=STAFF; pv=(GEO[k]['piv'][0]+OXc,GEO[k]['piv'][1]+OYc)
    return cv2.warpAffine(S,rotM(ang-a0,pv),(CW,CH),flags=cv2.INTER_NEAREST,borderValue=(0,0,0,0))
def shiftx(a,dx):
    o=np.zeros_like(a)
    if dx>0: o[:,dx:]=a[:,:-dx]
    elif dx<0: o[:,:dx]=a[:,-dx:]
    else: o=a.copy()
    return o
def big(cell): o=Image.new('RGBA',(CW,CH)); o.alpha_composite(cell,(OXc,OYc)); return o
def fxlayer(fn,blur):
    L=Image.new('L',(CW,CH)); fn(ImageDraw.Draw(L)); return L.filter(ImageFilter.GaussianBlur(blur))
def addfx(im,L,col,al):
    c=Image.new('RGBA',(CW,CH),col+(0,)); c.putalpha(L.point(lambda v:int(v*al))); im.alpha_composite(c); return im
def attack(k):
    P,STAFF,a0,LAY=build(k); R=ARM[k]; tx=-1 if k=='front' else 1; A=ANG[k]; piv=np.array(GEO[k]['piv'])+[OXc,OYc]
    # staff angle schedule over 14 frames
    def lerpa(a,b,u): return a+(b-a)*u
    sched=[a0]+[lerpa(a0,A['w'] if k=='back' else A['w'],ease(i/4)) for i in range(1,5)]+[A['w'],None,A['s'],A['s']]+[lerpa(A['s'],a0,ease(i/5)) for i in range(1,6)]
    lean=[0,-1,-2,-3,-4,-4,5,7,6,4,3,2,1,0]
    wv=[0]+[ease(i/4) for i in range(1,5)]+[1,None,0,0]+[0]*5; sv=[0]*6+[None,1,1]+[1-ease(i/5) for i in range(1,6)]
    def arm(f):
        if wv[f] is None: return R['wu']*0.3+R['su']*0.7, R['wf']*0.3+R['sf']*0.7
        return R['wu']*wv[f]+R['su']*sv[f], R['wf']*wv[f]+R['sf']*sv[f]
    INFOA.setdefault(k,[])
    out=[]
    for f,ang in enumerate(sched):
        cell=frame(P,f%NF,tx)                      # glide body (bob, trail, smoke, shards, shadow), staff removed
        a=np.array(cell); a=shiftx(a,int(tx*lean[f])); body=Image.fromarray(a)
        o=big(body); sh=int(tx*lean[f])
        ang_=lerpa(A['w'],A['s'],0.7) if ang is None else ang
        du,df=arm(f); off=bodyoff(P,f%NF,tx,R['sh'])+[OXc+sh,OYc]
        S0=np.array(R['sh'],float); E0=np.array(R['el'],float); H0=np.array(R['hd'],float)
        Sq=S0+off; Eq=Sq+rv(E0-S0,du); Hq=Eq+rv(H0-E0,du+df)
        Lu=place(LAY['up'],du,S0,Sq); Lf=place(LAY['fo'],du+df,E0,Eq); Ls=place(STAFF,ang_-a0,H0,Hq)
        bm=np.array(o)[...,3]>0; dil=lambda m:nd.binary_dilation(m,iterations=1)
        mu,mf,ms=Lu[...,3]>0,Lf[...,3]>0,Ls[...,3]>0
        CONN.append((k,f,int((dil(mu)&bm).sum()),int((dil(mf)&mu).sum()),int((dil(ms)&mf).sum()),int(nd.label(bm|mu|mf|ms,np.ones((3,3)))[1])))
        o.alpha_composite(Image.fromarray(Lu)); o.alpha_composite(Image.fromarray(Lf))
        st=Image.fromarray(Ls); piv=Hq.copy(); piv[0]-=sh
        if ang is None:
            a1,a2=(A['s'],A['w']) if k=='front' else (A['w'],A['s'])
            a2m=A['s']+(A['w']-A['s'])*0.35 if k=='front' else A['w']+(A['s']-A['w'])*0.65
            bx=[piv[0]-190+sh,piv[1]-190,piv[0]+190+sh,piv[1]+190]
            o=addfx(o,fxlayer(lambda d:(d.pieslice(bx,min(a2m,A['w']) if k=='front' else A['w'],max(a2m,A['w']) if k=='front' else a2m,fill=255),d.ellipse([piv[0]-70+sh,piv[1]-70,piv[0]+70+sh,piv[1]+70],fill=0)),6),(110,170,230),0.35)
        INFOA[k].append((f,Sq,Eq,Hq,ang_))
        o.alpha_composite(st)
        L_=165
        if ang is None or f==7:
            a1,a2=sorted([A['w'],A['s']]); 
            if k=='front': a1,a2=A['s'],A['w']
            box=[piv[0]-L_+sh,piv[1]-L_,piv[0]+L_+sh,piv[1]+L_]
            al=0.75 if ang is None else 0.4
            o=addfx(o,fxlayer(lambda d:d.arc(box,a1,a2,fill=255,width=22),7),(120,190,255),al*0.7)
            o=addfx(o,fxlayer(lambda d:d.arc(box,a1,a2,fill=255,width=6),1.5),(200,230,255),al)
        if f in (7,8,9):   # ice-shard burst flying forward from the strike tip
            u=(f-7)/2; rr=np.random.default_rng(5); d_=np.array([np.cos(np.radians(A['s'])),np.sin(np.radians(A['s']))])
            tipp=piv+d_*150+[sh,0]
            def fn(d,u=u):
                for i in range(18):
                    sp=rr.uniform(0.4,1.0); ang_=np.radians(A['s'])+rr.uniform(-0.45,0.45); dist=(30+120*sp)*(0.3+u)
                    x=tipp[0]+np.cos(ang_)*dist; y=tipp[1]+np.sin(ang_)*dist; r=rr.uniform(3,6)*(1-0.4*u)
                    d.polygon([(x-r*1.6*np.cos(ang_),y-r*1.6*np.sin(ang_)),(x+r*0.6*np.sin(ang_),y-r*0.6*np.cos(ang_)),(x+r*1.6*np.cos(ang_),y+r*1.6*np.sin(ang_)),(x-r*0.6*np.sin(ang_),y+r*0.6*np.cos(ang_))],fill=255)
            o=addfx(o,fxlayer(fn,1.0),(170,215,255),0.9*(1-0.5*u))
        q=np.array(o); s_=q[...,3]>0
        c=q[...,:3].astype(float); L=c@[.299,.587,.114]; sat=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1)
        m=(q[...,3]>=200)&(L>215)&(sat<0.15); q[m,:3]=(c[m]*(215/L[m])[:,None]).astype(np.uint8)   # no white solids
        out.append(Image.fromarray(q))
    return out,A,a0
MAP={'n':('back',True),'e':('back',False),'s':('front',True),'w':('front',False)}
OUT={}; INFO={}; INFOA={}; CONN=[]
for k in ('front','back'): OUT[k],A,a0=attack(k); INFO[k]=(A,a0); print(k,'rest staff angle',round(a0,1),A)
for dn,(k,mir) in MAP.items():
    s=Image.new('RGBA',(CW*14,CH))
    for i,im in enumerate(OUT[k]): s.alpha_composite(im.transpose(Image.FLIP_LEFT_RIGHT) if mir else im,(i*CW,0))
    s.save(f'serra14_attack_{dn}.png')
G=Image.new('RGB',(14*320,4*220),(26,28,36))
for r,dn in enumerate('nesw'):
    s=Image.open(f'serra14_attack_{dn}.png'); bg=Image.new('RGBA',s.size,(26,28,36,255)); bg.alpha_composite(s); G.paste(bg.convert('RGB').resize((14*320,220)),(0,r*220))
G.save('attack_contact.png')
import json; json.dump({k:[(f,list(map(float,S)),list(map(float,E)),list(map(float,H)),float(a)) for f,S,E,H,a in v] for k,v in INFOA.items()},open('arm_track.json','w'))
print('k f  up~body fore~up staff~fore  components');[print(*c) for c in CONN]
