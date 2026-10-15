import os, sys
src=open('sheet.py').read(); exec(src[:src.index("fnt=ImageFont")])
from PIL import ImageFont
DV={'n':(-2,-1),'e':(2,-1),'s':(2,1),'w':(-2,1)}; TF={'n':'S','e':'W','s':'N','w':'E'}
MAPK={'n':('back',True),'e':('back',False),'s':('front',True),'w':('front',False)}
SPR={(c,a,K_):strip(v['p'].format(a=a,K=K_),v['cw'],v['k']) for c,v in CHR.items() for a in ('idle','hit') for K_ in 'NESW'}
FPS=24; CYC=4.0
WALK0={k:np.array(Image.open(f'../s5_walk/serra5_walk_{d}.png'))[:,0:288] for k,d in (('front','w'),('back','e'))}
def bigarr(a): o=np.zeros((CH,CW,4),np.uint8); o[OYc:OYc+336,OXc:OXc+288]=a; return o
REST={k:Image.fromarray(bigarr(WALK0[k])) for k in WALK0}
_,_,LO0,HI0,_=None,None,None,None,None
sm=lambda u:u*u*(3-2*u)
def pose_w(t):   # weights (raise, slam) from timeline
    if t<0.35: return None
    if t<1.05: u=sm((t-0.35)/0.7); return (u,0)
    if t<1.25: u=sm((t-1.05)/0.2); return (1-u,u)
    if t<3.55: return (0,1)
    if t<4.0: u=sm((t-3.55)/0.45); return (0,1-u) if u<0.999 else None
    return None
CACHE={}
def serra(k,t):
    w=pose_w(t)
    a0=BUILD[k][2]; R_=POSE[k]['raise']; S_=POSE[k]['slam']
    if w is None:
        key=(k,'rest')
        if key not in CACHE:
            o,c,lo,hi,_=pose(k,0,0,a0); CACHE[key]=(REST[k],c,lo,hi)
        return CACHE[key]
    wr,ws=w; key=(k,round(wr,2),round(ws,2))
    if key not in CACHE:
        du=R_[0]*wr+S_[0]*ws; df=R_[1]*wr+S_[1]*ws; da=R_[2]*wr+S_[2]*ws
        o,c,lo,hi,_=pose(k,du,df,a0+da,f=0); CACHE[key]=(o,c,lo,hi)
    return CACHE[key]
def rot(a,deg):
    h,w=a.shape[:2]; M=cv2.getRotationMatrix2D((w/2,h/2),deg,1.0); return cv2.warpAffine(a,M,(w,h),flags=cv2.INTER_LINEAR)
RSQ=rs(RING,190,190*RING.shape[0]/RING.shape[1])
def cage_grow(c,u):   # u 0..1 growth over ~8 frames: clip-reveal bottom->top + overshoot scale
    if u<=0: return None
    sc=1+0.10*np.sin(np.pi*min(1,u*1.0))*(u>0.6) if u<1 else 1.0
    sc=(0.85+0.15*sm(min(1,u)))*(1+0.08*np.sin(np.pi*np.clip((u-0.55)/0.45,0,1)))
    a=rs(c,c.shape[1]*sc,c.shape[0]*sc); H=a.shape[0]; rows=int(H*min(1,u/0.75)); out=np.zeros_like(a)
    if rows>0: out[H-rows:]=a[H-rows:]; edge=min(26,rows); out[H-rows:H-rows+edge]*=np.linspace(0,1,edge)[:,None,None]
    return out
fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',56)
def quad(dn,t):
    k,mir=MAPK[dn]; g=floor(); dv=np.array(DV[dn],float); dv/=np.linalg.norm(dv)
    C=np.array([480,312]); sp=C-dv*100; tp=C+dv*95; T={'ij':tp+np.array([-46,-5]),'ke':tp+np.array([46,5])}
    o,c,lo,hi=serra(k,t); im=o.transpose(Image.FLIP_LEFT_RIGHT) if mir else o
    lo=np.array(lo,float); hi=np.array(hi,float)
    if mir: lo[0]=CW-lo[0]; hi[0]=CW-hi[0]
    im=im.resize((round(CW*K),round(CH*K)),Image.LANCZOS); lov=sp+(lo-[BX,BY])*K; hiv=sp+(hi-[BX,BY])*K
    # contact point fixed at the slam pose
    _,_,slo,_=serra(k,2.0); slo=np.array(slo,float)
    if mir: slo[0]=CW-slo[0]
    cp=sp+(slo-[BX,BY])*K
    # ring: in 1.25-1.55, rotating, fades 3.55-4.0
    if 1.25<=t<4.0:
        sc=sm(min(1,(t-1.25)/0.3))*(1+0.06*np.sin(np.pi*np.clip((t-1.4)/0.3,0,1))); fade=1 if t<3.55 else 1-(t-3.55)/0.45
        r=rot(RSQ,-(t-1.25)*14); r=rs(r,r.shape[1]*max(sc,0.05),r.shape[0]*max(sc,0.05)*0.5); g=add(g,r,cp[0],cp[1],0.8*fade)
    CAGEu=(t-1.55)/(8/24); hold=1.55+8/24<=t<3.55; shat=3.55<=t<4.0
    items=[(sp[1],im,(round(sp[0]-BX*K),round(sp[1]-BY*K)),None,None)]
    for i_,(cn,p) in enumerate(T.items()):
        v=CHR[cn]; hit=1.55<=t<3.55
        if hit: fs=SPR[(cn,'hit',TF[dn])]; tim=tint(fs[1],0.12)
        elif shat: fs=SPR[(cn,'hit',TF[dn])]; tim=tint(fs[min(2,len(fs)-1)],0.10*(1-(t-3.55)/0.45))
        else: fs=SPR[(cn,'idle',TF[dn])]; tim=fs[int(t*6)%len(fs)]
        if shat: p=p+dv*6*np.sin(np.pi*min(1,(t-3.55)/0.3))
        sh=Image.new('RGBA',(960,540)); ImageDraw.Draw(sh).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],tim,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k'])),cn,p))
    items.sort(key=lambda s:s[0])
    for it in items:
        cn,p=it[3],it[4]
        if cn:
            cw_=150 if cn=='ij' else 128; back,front,_=cage_parts(cw_)
            mist=np.clip((np.linspace(0,1,front.shape[0])[:,None,None]-0.72)/0.1,0,1); front=front*(1-0.55*mist)   # lighter ground mist on the front
            if 1.55<=t<3.55:
                bk=cage_grow(back,CAGEu); fr=cage_grow(front,CAGEu)
                if bk is not None: g=add(g,bk,p[0],p[1]+14,1.0,'b')
            if t>=3.55 and t<4.9:
                fade=1 if t<4.3 else 1-(t-4.3)/0.6; g=add(g,stumps(back+front),p[0],p[1]+14,0.9*fade,'b')
        g.alpha_composite(it[1],it[2])
        if cn:
            if 1.55<=t<3.55 and fr is not None: g=add(g,fr,p[0],p[1]+14,0.55,'b')
            if shat:
                u=(t-3.55)/0.45; bw=(150 if cn=='ij' else 130)*(0.6+0.6*u); g=add(g,rs(BURST,bw,bw*BURST.shape[0]/BURST.shape[1]),p[0],p[1]-55,0.65*(1-u**1.5))
            if 3.55<=t<4.9: g=add(g,stumps(back+front),p[0],p[1]+14,0.4*(1 if t<4.3 else 1-(t-4.3)/0.6),'b')
    if 0.35<=t<1.25:   # tip glow builds on raise
        gl=sm(min(1,(t-0.35)/0.6))*(1 if t<1.05 else 1-(t-1.05)/0.2)
        g.alpha_composite(soft(lambda d:d.ellipse([hiv[0]-22,hiv[1]-22,hiv[0]+22,hiv[1]+22],fill=255),10,(80,220,255),0.75*gl))
        g.alpha_composite(soft(lambda d:d.ellipse([hiv[0]-7,hiv[1]-7,hiv[0]+7,hiv[1]+7],fill=255),3,(200,245,255),0.9*gl))
    if 1.2<=t<1.6:     # frost flash at contact
        u=(t-1.2)/0.4; fl=np.sin(np.pi*min(1,u*1.6)) if u<0.62 else max(0,1-(u-0.62)/0.38)*0.9
        g=add(g,rs(BURST,60+50*u,(60+50*u)*BURST.shape[0]/BURST.shape[1]*0.6),cp[0],cp[1]-4,0.85*fl)
        g.alpha_composite(soft(lambda d:d.ellipse([cp[0]-34,cp[1]-15,cp[0]+34,cp[1]+15],fill=255),9,(150,225,255),0.6*fl))
    d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
    cc=np.array([150,48]); nn=np.array([-dv[1],dv[0]]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
    d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+nn*14),tuple(b_-dv*6-nn*14)],fill=(140,200,255,255))
    return g
def frame_v(n):
    t=(n/FPS)%CYC; G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'): G.alpha_composite(quad(dn,t),((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_f',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame_v(i).save(f'_f/{i:05d}.png',compress_level=1)
