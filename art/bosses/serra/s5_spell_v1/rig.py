import numpy as np, cv2, scipy.ndimage as nd, json
from PIL import Image, ImageDraw, ImageFilter
src=open('../attack_v2/atk.py').read().replace("../walk_v3/glide.py","../s5_walk/glide.py")
old=src[src.index("    sil=nd.binary_closing(main&~st,iterations=4)&st"):src.index("    P[0]=b2;")]
src=src.replace(old,"""    sil=nd.binary_closing(main&~st,iterations=14)&st
    b2=body.copy(); b2[st]=0; ok=b2[...,3]>0
    _,(iy,ix)=nd.distance_transform_edt(~ok,return_indices=True)       # nearest remaining fur pixel
    ys,xs=np.nonzero(sil); b2[ys,xs]=(body[iy[ys,xs],ix[ys,xs]]*0+b2[iy[ys,xs],ix[ys,xs]]*np.array([.85,.85,.85,1])).astype(np.uint8)
"""); exec(src[:src.index("MAP={'n'")])
GEO={'front':dict(piv=(188,152),a=(90,298),b=(225,101),hand=(188,152)),'back':dict(piv=(226,121),a=(179,281),b=(249,51),hand=(226,121))}
ARM={'front':dict(sh=(155,118),el=(170,140),hd=(188,152)),'back':dict(sh=(196,104),el=(208,124),hd=(226,121))}
# staff tip screen angles (deg): wind-up (back & up), cast (along facing, swept over the top)
ANGS={'front':dict(w=192.0,s=153.0),'back':dict(w=-120.0,s=-26.6)}
ARMA={'front':dict(wu=-40,wf=-20,su=22,sf=25),'back':dict(wu=-120,wf=-20,su=-60,sf=20)}
NFR=16
W=[0]+[ease(i/5) for i in range(1,6)]+[1,.3,0,0,0,0]+[0,0,0,0]
S=[0]*7+[.7,1,1,1,1]+[1-ease(i/3) for i in range(1,4)]+[0]
LUNGE=[0,-1,-2,-3,-4,-4,-4,5,9,9,8,7,4,2,1,0]
def bigarr(a): o=np.zeros((CH,CW,4),np.uint8); o[OYc:OYc+336,OXc:OXc+288]=a; return o
CONN=[]; TRK={}
def run(k):
    P,STAFF,a0,LAY=build(k); R=ARM[k]; A=ARMA[k]; G=ANGS[k]; tx=-1 if k=='front' else 1; fy=1 if k=='front' else -1
    Pw=list(prep(k)); out=[]; TRK[k]=[]
    S0,E0,H0=(np.array(R[n],float) for n in ('sh','el','hd'))
    tipv=np.array(GEO[k]['a'] if k=='front' else GEO[k]['b'],float)-H0; L_tip=np.linalg.norm(tipv)
    for f in range(NFR):
        if f in (0,NFR-1):   # identical to walk frame 0
            o=Image.fromarray(bigarr(np.array(frame(Pw,0,tx)))); ang=a0; Hq=H0+[OXc,OYc]
        else:
            du=A['wu']*W[f]+A['su']*S[f]; df=A['wf']*W[f]+A['sf']*S[f]
            gs=G['s']+(360 if (f>=12 and G['s']<-180) else 0)
            ang=a0+(G['w']-a0)*W[f]+(gs-a0)*S[f]
            lx=int(tx*LUNGE[f]); ly=int(fy*LUNGE[f]*0.4)
            cell=np.array(frame(P,f%NF,tx)); b=cell.copy(); b[cell[...,3]<255]=0; s=cell.copy(); s[cell[...,3]==255]=0
            o=Image.fromarray(bigarr(s)); B=shiftx(np.roll(bigarr(b),ly,0),lx); o.alpha_composite(Image.fromarray(B))
            off=bodyoff(P,f%NF,tx,R['sh'])+[OXc+lx,OYc+ly]
            Sq=S0+off; Eq=Sq+rv(E0-S0,du); Hq=Eq+rv(H0-E0,du+df)
            Lu=place(LAY['up'],du,S0,Sq); Lf=place(LAY['fo'],du+df,E0,Eq); Ls=place(STAFF,ang-a0,H0,Hq)
            bm=np.array(o)[...,3]==255; dil=lambda m:nd.binary_dilation(m,iterations=1); mu,mf,ms=Lu[...,3]>0,Lf[...,3]>0,Ls[...,3]>0
            CONN.append((k,f,int((dil(mu)&bm).sum()),int((dil(mf)&mu).sum()),int((dil(ms)&mf).sum())))
            for L_ in (Lu,Lf,Ls): o.alpha_composite(Image.fromarray(L_))
        tip=Hq+L_tip*np.array([np.cos(np.radians(ang)),np.sin(np.radians(ang))])
        if 2<=f<=7:   # crystals gather & swirl at the tip
            g=min(1,(f-1)/4); o=addfx(o,fxlayer(lambda d:d.ellipse([tip[0]-18,tip[1]-18,tip[0]+18,tip[1]+18],fill=255),8),(120,190,255),0.75*g)
            rr=np.random.default_rng(2)
            def sw(d):
                for i in range(12):
                    a=rr.uniform(0,6.28)+f*0.9; r_=(34-16*g)*rr.uniform(.5,1); x=tip[0]+np.cos(a)*r_; y=tip[1]+np.sin(a)*r_*0.7; s_=rr.uniform(2,3.5)
                    d.polygon([(x,y-s_*1.8),(x+s_*.7,y),(x,y+s_*1.8),(x-s_*.7,y)],fill=255)
            o=addfx(o,fxlayer(sw,0.5),(205,232,255),0.95)
        if 7<=f<=11:   # muzzle flash at the tip
            o=addfx(o,fxlayer(lambda d:d.ellipse([tip[0]-22,tip[1]-22,tip[0]+22,tip[1]+22],fill=255),9),(150,205,255),0.6 if f<=9 else 0.3)
        q=np.array(o); c=q[...,:3].astype(float); Lm=c@[.299,.587,.114]; sat=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1)
        m=(q[...,3]>=200)&(Lm>215)&(sat<0.15); q[m,:3]=(c[m]*(215/Lm[m])[:,None]).astype(np.uint8)
        if f not in (0,NFR-1):
            hm=q[...,3]==255; lb,n=nd.label(hm,np.ones((3,3)))
            if n: sz=nd.sum(hm,lb,range(1,n+1)); q[np.isin(lb,np.nonzero(sz<8)[0]+1)&hm]=0
        out.append(Image.fromarray(q)); TRK[k].append([f,float(tip[0]),float(tip[1]),float(ang)])
    return out

def pose(k,du,df,ang,f=0,lift=0):
    P,STAFF,a0,LAY=BUILD[k]; R=ARM[k]; tx=-1 if k=='front' else 1
    S0,E0,H0=(np.array(R[n],float) for n in ('sh','el','hd'))
    cell=np.array(frame(P,f%NF,tx)); b=cell.copy(); b[cell[...,3]<255]=0; s=cell.copy(); s[cell[...,3]==255]=0
    o=Image.fromarray(bigarr(s)); B=bigarr(b); o.alpha_composite(Image.fromarray(B))
    off=bodyoff(P,f%NF,tx,R['sh'])+[OXc,OYc]
    Sq=S0+off; Eq=Sq+rv(E0-S0,du); Hq=Eq+rv(H0-E0,du+df)+[0,lift]
    Lu=place(LAY['up'],du,S0,Sq); Lf=place(LAY['fo'],du+df,E0,Eq); Ls=place(STAFF,ang-a0,H0,Hq)
    bm=np.array(o)[...,3]==255; dil=lambda m:nd.binary_dilation(m,iterations=1); mu,mf,ms=Lu[...,3]>0,Lf[...,3]>0,Ls[...,3]>0
    conn=(int((dil(mu)&bm).sum()),int((dil(mf)&mu).sum()),int((dil(ms)&mf).sum()))
    for L_ in (Lu,Lf,Ls): o.alpha_composite(Image.fromarray(L_))
    ys,xs=np.nonzero(ms); lo=np.argmax(ys); hi=np.argmin(ys)
    return o,conn,(xs[lo],ys[lo]),(xs[hi],ys[hi]),a0
BUILD={k:build(k) for k in ('front','back')}
