import numpy as np, cv2, scipy.ndimage as nd, json
from PIL import Image, ImageDraw, ImageFilter
src=open('../attack_v2/atk.py').read(); exec(src[:src.index("MAP={'n'")])
# free (non-staff) arm: shoulder, elbow, hand in key px; raise = upper-arm rot, bent forearm rel rot, extended rel rot
FREE={'front':dict(sh=(162,112),el=(168,134),hd=(172,157),up=-152.7,bend=55.0,ext=-60.0),
      'back': dict(sh=(112,100),el=(100,122),hd=(88,140),up=139.6,bend=-55.0,ext=60.0)}
NFR=18
def buildF(k):
    R=FREE[k]; P=list(prep(k)); body=P[0].copy(); main=P[1]; allm=body[...,3]>0
    circ=lambda c,r:np.hypot(xx-c[0],yy-c[1])<r
    fo=allm&(segmask(R['el'],R['hd'],7)|circ(R['el'],8)|circ(R['hd'],8))
    up=allm&~fo&(segmask(R['sh'],R['el'],8)|circ(R['sh'],9))
    LAY={n:np.where(m[...,None],body,0).astype(np.uint8) for n,m in (('up',up),('fo',fo))}
    cut=up|fo; P[3]=[S for S in P[3] if not (S&cut).any()]
    sil=nd.binary_closing(main&~cut,iterations=4)&cut
    b2=body.copy(); b2[cut]=0; ok=b2[...,3]>0; ys,xs=np.nonzero(sil)
    for dx_ in (10,-10,16,-16,0):
        sx=np.clip(xs+dx_,0,287); sy=np.clip(ys+(8 if dx_==0 else 0),0,335); g_=ok[sy,sx]&~(b2[ys,xs,3]>0)
        b2[ys[g_],xs[g_]]=(body[sy[g_],sx[g_]]*np.array([.8,.8,.8,1])).astype(np.uint8)
    P[0]=b2; P[1]=b2[...,3]>0
    return P,LAY
def sched(f):   # (upper-arm rot weight, forearm rel angle) ; 0 rest, 1-4 raise bent, 5-7 extend, 8-12 hold, 13-17 recover
    if f==0: return 0,0
    if f<=4: u=ease(f/4); return u,'bend',u
    if f<=7: u=ease((f-4)/3); return 1,'mix',u
    if f<=12: return 1,'ext',1
    u=1-ease(min(1,(f-12)/3)); return u,'rec',u   # arm folds tight and drops along the body, at rest by f15
CONN=[]; TRK={}
def spell(k):
    P,LAY=buildF(k); R=FREE[k]; tx=-1 if k=='front' else 1; out=[]; TRK[k]=[]
    S0,E0,H0=(np.array(R[n],float) for n in ('sh','el','hd'))
    for f in range(NFR):
        s=sched(f)
        if len(s)==2: du=df=0.0
        else:
            w,mode,u=s; du=R['up']*w
            df={'bend':R['bend']*u,'mix':R['bend']*(1-u)+R['ext']*u,'ext':R['ext']*u,'rec':R['ext']*u*u-R['up']*u*(1-u)}[mode]
        cell=frame(P,f%NF,tx); o=big(cell)
        off=bodyoff(P,f%NF,tx,R['sh'])+[OXc,OYc]
        Sq=S0+off; Eq=Sq+rv(E0-S0,du); Hq=Eq+rv(H0-E0,du+df)
        Lu=place(LAY['up'],du,S0,Sq); Lf=place(LAY['fo'],du+df,E0,Eq)
        bm=np.array(o)[...,3]>0; dil=lambda m:nd.binary_dilation(m,iterations=1); mu,mf=Lu[...,3]>0,Lf[...,3]>0
        CONN.append((k,f,int((dil(mu)&bm).sum()),int((dil(mf)&mu).sum())))
        o.alpha_composite(Image.fromarray(Lu)); o.alpha_composite(Image.fromarray(Lf))
        if 2<=f<=13:   # thin frost rim along the raised arm so it separates from the dark robe
            gr=min(1,(f-1)/3)*(1 if f<=11 else (14-f)/3)
            o=addfx(o,fxlayer(lambda d:d.line([tuple(Sq),tuple(Eq),tuple(Hq)],fill=255,width=12,joint='curve'),5),(110,170,235),0.32*gr)
        if 3<=f<=12:   # frost glow + rising motes at the summoning hand
            g=min(1,(f-2)/3)*(1 if f<=10 else (13-f)/3)
            o=addfx(o,fxlayer(lambda d:d.ellipse([Hq[0]-14,Hq[1]-14,Hq[0]+14,Hq[1]+14],fill=255),6),(120,190,255),0.75*g)
            rr=np.random.default_rng(f)
            def mot(d):
                for i in range(7):
                    a=rr.uniform(0,2*np.pi); r_=rr.uniform(6,22); x=Hq[0]+np.cos(a)*r_; y=Hq[1]+np.sin(a)*r_-rr.uniform(0,18); d.polygon([(x,y-3),(x+2,y),(x,y+3),(x-2,y)],fill=255)
            o=addfx(o,fxlayer(mot,0.6),(190,225,255),0.9*g)
        q=np.array(o); c=q[...,:3].astype(float); L=c@[.299,.587,.114]; sat=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1)
        m=(q[...,3]>=200)&(L>215)&(sat<0.15); q[m,:3]=(c[m]*(215/L[m])[:,None]).astype(np.uint8)
        q[...,3]=np.where(q[...,3]>0,255,0).astype(np.uint8) if False else q[...,3]
        out.append(Image.fromarray(q)); TRK[k].append([f,list(map(float,Sq)),list(map(float,Eq)),list(map(float,Hq))])
    return out
MAP={'n':('back',True),'e':('back',False),'s':('front',True),'w':('front',False)}
OUT={k:spell(k) for k in ('front','back')}
for dn,(k,mir) in MAP.items():
    s=Image.new('RGBA',(CW*NFR,CH))
    for i,im in enumerate(OUT[k]): s.alpha_composite(im.transpose(Image.FLIP_LEFT_RIGHT) if mir else im,(i*CW,0))
    s.save(f'serra14_spell_{dn}.png')
json.dump(TRK,open('arm_track.json','w'))
bad=[c for c in CONN if c[2]==0 or c[3]==0]
print('frames',len(CONN),'joint-contact failures',bad, 'min up~body',min(c[2] for c in CONN),'min fore~up',min(c[3] for c in CONN))
