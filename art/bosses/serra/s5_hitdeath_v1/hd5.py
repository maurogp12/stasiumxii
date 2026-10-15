import numpy as np, cv2, scipy.ndimage as nd, json
from PIL import Image, ImageDraw, ImageFilter
src=open('../s5_attack_v3/atk6.py').read(); exec(src[:src.index("def run")])
BXc,BYc=OXc+144,OYc+300                     # base point in big cell (320,404)
def bigarr(a): o=np.zeros((CH,CW,4),np.uint8); o[OYc:OYc+336,OXc:OXc+288]=a; return o
def split_shadow(cell):   # glide cell -> (hard body, soft shadow)
    a=np.array(cell); b=a.copy(); b[a[...,3]<255]=0; s=a.copy(); s[a[...,3]==255]=0; return b,s
def fx(o,fn,blur,col,al): return addfx(o,fxlayer(fn,blur),col,al)
def clean(q):   # no white solids, hard alpha, drop specks < 8 px
    c=q[...,:3].astype(float); L=c@[.299,.587,.114]; sat=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1)
    m=(q[...,3]>=200)&(L>215)&(sat<0.15); q[m,:3]=(c[m]*(215/L[m])[:,None]).astype(np.uint8); return q
def despeck(a):
    m=a[...,3]==255; lb,n=nd.label(m,np.ones((3,3)))
    if n: s=nd.sum(m,lb,range(1,n+1)); small=np.isin(lb,np.nonzero(s<8)[0]+1); a[small]=0
    return a
def lab2pc(a): return np.ones(a.shape[:2])
def tintarr(a,t):
    m=a[...,3]==255; f=a[...,:3].astype(float); f=f*(1-t)+np.array([170,210,255])*t; a[...,:3][m]=np.clip(f[m],0,225).astype(np.uint8); return a
# ---------------- HIT (8 frames) ----------------
def hit(k):
    P=list(prep(k)); tx=-1 if k=='front' else 1; out=[]
    rec=[0,12,18,16,11,6,2,0]; lean=[0,4,6,5,3,2,1,0]; flare=[0,5,7,6,4,2,1,0]; tint=[0,.16,.11,.06,.02,0,0,0]
    for f in range(8):
        cell=np.array(frame(P,(f*1)%NF,tx)); b,s=split_shadow(cell)
        hgt=np.clip((300-yy)/260,0,1); w=np.clip((yy-170)/130,0,1)**1.3
        dx=-tx*(lean[f]*hgt)*-1*-1   # top leans BACK (away from facing)
        mx=(xx+tx*lean[f]*hgt - (-tx)*0 + tx*flare[f]*w*np.sin(yy/18)*0.6).astype(np.float32); my=(yy+0*yy).astype(np.float32)
        # backward flare of robe: sample from the facing side so robe streams away from attacker
        mx=mx+np.float32(tx*flare[f]*w)
        b=cv2.remap(b,mx,my,cv2.INTER_NEAREST,borderValue=(0,0,0,0)); b=tintarr(b,tint[f])
        o=np.zeros((CH,CW,4),np.uint8); sh_=bigarr(s); sh_=shiftx(sh_,int(-tx*rec[f]*0.4)); o=sh_.copy()
        B=shiftx(bigarr(b),int(-tx*rec[f])); oi=Image.fromarray(o); oi.alpha_composite(Image.fromarray(B))
        if 1<=f<=6:   # shards knocked loose, flying back (hard alpha, palette colours)
            rr=np.random.default_rng(21); u=(f-1)/5; d_=ImageDraw.Draw(oi)
            for i in range(9):
                sx=BXc+rr.uniform(-40,40)-tx*rec[f]; sy=BYc-rr.uniform(90,220); vx=-tx*rr.uniform(30,70); vy=rr.uniform(-30,10)
                x=sx+vx*u; y=sy+vy*u+60*u*u; r=rr.uniform(2.5,4.5); a=np.arctan2(vy,vx)
                c=tuple(int(v) for v in rr.choice([(150,175,205),(110,130,165),(185,205,228)]))+(255,)
                if u<0.95: d_.polygon([(x-np.cos(a)*r*2,y-np.sin(a)*r*2),(x-np.sin(a)*r*.6,y+np.cos(a)*r*.6),(x+np.cos(a)*r*2,y+np.sin(a)*r*2),(x+np.sin(a)*r*.6,y-np.cos(a)*r*.6)],fill=c)
            if f<=2: oi=fx(oi,lambda d:d.ellipse([BXc+tx*40-30,BYc-200,BXc+tx*40+30,BYc-140],fill=255),10,(160,205,255),0.22*(1 if f==1 else .5))
        out.append(Image.fromarray(despeck(clean(np.array(oi)))))
    return out
# ---------------- DEATH (22 frames) ----------------
def death(k):
    P=list(prep(k)); tx=-1 if k=='front' else 1
    Pr,STAFF,a0,LAY=build(k)                          # staff-free body (+arm layers) from attack rig
    cell=np.array(frame(Pr,0,tx)); b,s=split_shadow(cell)
    bi=Image.fromarray(bigarr(b)); bi.alpha_composite(Image.fromarray(place(LAY['up'],0,ARM[k]['sh'],np.array(ARM[k]['sh'])+[OXc,OYc]))); bi.alpha_composite(Image.fromarray(place(LAY['fo'],0,ARM[k]['el'],np.array(ARM[k]['el'])+[OXc,OYc])))
    BODY=np.array(bi); BODY[BODY[...,3]<255]=0; SH=bigarr(s); g_=GEO[k]; STAFF=np.where((~((np.hypot(xx-g_['hand'][0],yy-g_['hand'][1])<12)&~segmask(g_['a'],g_['b'],4)))[...,None],STAFF,0).astype(np.uint8); A_=np.array(g_['a'],float); B_=np.array(g_['b'],float); lo=A_ if k=='back' else B_; hi=B_ if k=='back' else A_; mid=lo+(hi-lo)*0.5
    keep=segmask(mid,hi,9)|segmask(lo,mid,6); STAFF=np.where(keep[...,None],STAFF,0).astype(np.uint8); lb_,n_=nd.label(STAFF[...,3]==255,np.ones((3,3))); sz_=nd.sum(STAFF[...,3]==255,lb_,range(1,n_+1)); STAFF[~np.isin(lb_,np.nonzero(sz_>=60)[0]+1)]=0; tip=A_ if k=='front' else B_; tail=B_ if k=='front' else A_; vv=(tail-tip)/np.linalg.norm(tail-tip)
    blade=(np.hypot(xx-tip[0],yy-tip[1])<46)&(STAFF[...,3]==255)&segmask(tip,tip+vv*46,7); NS=np.zeros_like(STAFF)
    si=Image.fromarray(NS); dd=ImageDraw.Draw(si); s0=tuple(tip+vv*36); s1=tuple(tail+vv*6)
    dd.line([s0,s1],fill=(34,38,52,255),width=4); dd.line([tuple(np.array(s0)+[0,-1]),tuple(np.array(s1)+[0,-1])],fill=(92,110,140,255),width=1)
    NS=np.array(si); NS[blade]=STAFF[blade]; STAFF=NS; STB=bigarr(STAFF.copy())
    full=np.array(frame(P,0,tx)); FB,_=split_shadow(full); FB=bigarr(FB)
    # crown = top 30 px of the head column
    if k=='front' or 'CROWNSRC' not in globals():
        pass
    m=BODY[...,3]==255; ys,xs=np.nonzero(m&(yy2<OYc+150)); i=np.argmin(ys); cx,cy=xs[i],ys[i]
    crown=m&(yy2>=cy)&(yy2<cy+40)&(np.abs(xx2-cx)<28); lb,n=nd.label(crown,np.ones((3,3)))
    if n: sz=nd.sum(crown,lb,range(1,n+1)); crown=lb==(np.argmax(sz)+1)
    CR=np.where(crown[...,None],BODY,0).astype(np.uint8); BODYnc=BODY.copy(); BODYnc[crown]=0
    cyx=np.array(nd.center_of_mass(crown))[::-1]
    global CROWNSRC
    if k=='front': CROWNSRC=(CR.copy(),cyx.copy())
    else:   # back view: drop the FRONT tiara (reads as a crown from any side), positioned at this head
        C0,c0=CROWNSRC; CR=place(C0[OYc:OYc+336,OXc:OXc+288],0,c0-[OXc,OYc],cyx)
    ys_,xs_=np.nonzero(CR[...,3]==255); cc=CR[ys_.min():ys_.max()+1,xs_.min():xs_.max()+1]; cc=cv2.resize(cc,None,fx=1.6,fy=1.6,interpolation=cv2.INTER_NEAREST)
    CR=np.zeros_like(CR); h_,w_=cc.shape[:2]; y0=int(cyx[1]-h_/2); x0=int(cyx[0]-w_/2); CR[y0:y0+h_,x0:x0+w_]=cc; CRH=h_
    # heap: robe bottom squashed into a low mound + black-ice spikes
    rob=BODY[OYc+180:OYc+302].copy(); hh=104; hw=170
    hp=cv2.resize(rob,(hw,hh),interpolation=cv2.INTER_NEAREST); hp[...,:3]=(hp[...,:3]*0.72).astype(np.uint8)
    HEAP=np.zeros((CH,CW,4),np.uint8); x0=BXc-hw//2; HEAP[BYc-hh+4:BYc+4,x0:x0+hw]=hp
    # dome mound (robe texture) + outward-leaning black-ice spikes, like pose 4
    dome=((xx2-BXc)/(hw/2))**2+((yy2-(BYc+4))/hh)**2<1; dome&=yy2<=BYc+4
    tex=cv2.resize(rob,(CW,CH),interpolation=cv2.INTER_NEAREST); tex[...,:3]=(tex[...,:3]*0.9).astype(np.uint8)
    base=np.array([34,38,52,255],np.uint8); H=np.where(dome[...,None],np.where(tex[...,3:4]==255,tex,base),0).astype(np.uint8); H[dome,3]=255
    hm=Image.fromarray(H); d=ImageDraw.Draw(hm); rr=np.random.default_rng(3)
    for i in range(44):
        t=rr.uniform(0.05,0.95)*np.pi; ex=BXc-np.cos(t)*hw/2*rr.uniform(0.55,0.95); ey=BYc+4-np.sin(t)*hh*rr.uniform(0.55,0.95)
        ang=-np.pi/2-(np.pi/2-t)*1.1+rr.uniform(-0.25,0.25); L=rr.uniform(20,46); bw=rr.uniform(5,9)
        nx,ny=np.cos(ang),np.sin(ang); px,py=-ny,nx
        c=tuple(int(v) for v in rr.choice([(30,34,48),(44,52,70),(64,78,102),(100,124,155)]))+(255,)
        d.polygon([(ex-px*bw,ey-py*bw),(ex+nx*L,ey+ny*L),(ex+px*bw,ey+py*bw)],fill=c)
    HEAP=despeck(np.array(hm)); hmk=HEAP[...,3]==255; rim=nd.binary_dilation(hmk)&~hmk&(yy2<BYc+2); HEAP[rim]=(84,104,136,255)
    heap_top=np.nonzero(HEAP[...,3].any(1))[0].min()
    # Voronoi pieces of the body
    rr=np.random.default_rng(8); ys,xs=np.nonzero(BODYnc[...,3]==255); seeds=np.c_[xs,ys][rr.choice(len(xs),70,replace=False)]
    lab=np.full((CH,CW),-1); from scipy.spatial import cKDTree
    _,idx=cKDTree(seeds).query(np.c_[xs,ys]); lab[ys,xs]=idx
    cen=np.array([BXc,BYc-150.0]); noise=rr.random((CH,CW))
    RD=np.zeros((CH,CW)); 
    for j in range(len(seeds)):
        sel=lab==j
        pass
    EDGE=np.zeros((CH,CW),bool)
    for dy_,dx_ in ((0,1),(0,-1),(1,0),(-1,0)): EDGE|=(lab!=np.roll(np.roll(lab,dy_,0),dx_,1))
    EDGE&=lab>=0
    vel=[]; 
    for j in range(70):
        c=seeds[j]-cen; vel.append(c/np.maximum(np.linalg.norm(c),1)*rr.uniform(40,95)+[0,-rr.uniform(50,110)])
    # crack polylines inside the body
    cracks=[]
    for i in range(9):
        p=np.array([BXc+rr.uniform(-40,40),BYc-rr.uniform(60,230)]); pts=[p.copy()]
        for j in range(7): p=p+rr.normal(0,1,2)*[6,8]+[0,rr.choice([-1,1])*4]; pts.append(p.copy())
        cracks.append(pts)
    # staff layout: original -> lying on the heap
    stm=STB[...,3]==255; sc=np.array(nd.center_of_mass(stm))[::-1]
    lie=(170.0 if k=='front' else 8.0)-a0   # rotation to lie near-horizontal along her side
    lie_c=np.array([BXc+tx*4,BYc+4-hh*0.45])
    crown_end=np.array([BXc*1.0,BYc+4-hh-CRH/2+10.0])
    out=[]; T={}
    for f in range(22):
        o=Image.new('RGBA',(CW,CH))
        sw=1.0 if f<6 else max(0.55,1-(f-6)/8*0.45)   # shadow shrinks to the heap
        Sh=cv2.resize(SH,None,fx=1,fy=1); M=np.float32([[sw,0,BXc*(1-sw)],[0,sw,BYc*(1-sw)]]); o.alpha_composite(Image.fromarray(cv2.warpAffine(SH,M,(CW,CH),flags=cv2.INTER_LINEAR)))
        if f>=8:   # crystal-cluster remains (approved painting) spike up from the base
            g=ease(min(1,(f-7)/6)); RM=REM; w_=max(1,round(RM.width*(0.55+0.45*g))); h_=max(1,round(RM.height*g)); r_=RM.resize((w_,h_),Image.NEAREST); o.alpha_composite(r_,(int(BXc-w_/2),int(BYc+8-h_)))
        if f<6:    # shudder + cracks (staff still in hand)
            j=int(round((2 if f%2 else -2)*(f/5+0.3))); B=shiftx(FB.copy(),j); B=tintarr(B,0.04*f)
            o.alpha_composite(Image.fromarray(B)); g=f/5
            o=fx(o,lambda d:[d.line([tuple(p+[j,0]) for p in c],fill=255,width=5) for c in cracks],3,(110,190,255),0.5*g)
            q=np.array(o); L=Image.new('L',(CW,CH)); ImageDraw.Draw(L).line([],fill=0)
            dd=ImageDraw.Draw(L); [dd.line([tuple(p+[j,0]) for p in c],fill=255,width=1) for c in cracks]
            cm=(np.array(L)>0)&(q[...,3]==255)&(rr.random((CH,CW))<0.35+0.65*g); q[cm,:3]=(150,215,255); o=Image.fromarray(q)
        else:      # shatter: pieces fly out/up and dissolve (hard alpha), smoke rises
            u=(f-6)/11.0; Bo=np.zeros((CH,CW,4),np.uint8)
            if u<1.05:
                for j in range(70):
                    sel=lab==j
                    if not sel.any(): continue
                    py,px=np.nonzero(sel); dv=vel[j]*u+[0,40*u*u]; sc_=max(0.0,1-u**1.15); mx_,my_=px.mean(),py.mean(); nx=np.clip(np.round(mx_+(px-mx_)*sc_+dv[0]).astype(int),0,CW-1); ny=np.clip(np.round(my_+(py-my_)*sc_+dv[1]).astype(int),0,CH-1)
                    keep=np.ones(len(px),bool) if sc_>0.12 else np.zeros(len(px),bool); edg=EDGE[py,px]; c=BODYnc[py,px].copy(); c[:,:3]=np.clip(c[:,:3]*(1+0.25*u)+18*u,0,215).astype(np.uint8); c[edg&(u>0.04)]=(172,202,232,255)
                    Bo[ny[keep],nx[keep]]=c[keep]
                Bo=despeck(Bo)
                o.alpha_composite(Image.fromarray(Bo))
            sm=min(1,(f-5)/3)*max(0,1-(f-11)/9)
            if sm>0:
                rr2=np.random.default_rng(31)
                def smoke(d):
                    for i in range(16):
                        a=rr2.uniform(-np.pi,0); sp=rr2.uniform(.4,1); x=BXc+np.cos(a)*120*sp*u; y=BYc-150+np.sin(a)*90*sp*u-60*u; r=12+30*u*rr2.uniform(.6,1)
                        d.ellipse([x-r,y-r,x+r,y+r],fill=255)
                o=fx(o,smoke,10,(30,34,52),0.55*sm)
                o=fx(o,lambda d:d.ellipse([BXc-60,BYc-230,BXc+60,BYc-60],fill=255),18,(130,190,255),0.35*max(0,1-(f-6)/3)) if f<9 else o
            # staff/crown fall only until the crystal remains cover them (remains carry the painted ones)
            if f>10: continue_sc=False
            else: continue_sc=True
            v=min(1,(f-6)/5)**2; ang=lie*v; cpos=sc+[OXc*0,0]; cpos=sc+(lie_c-sc)*v
            if continue_sc: o.alpha_composite(Image.fromarray(place(STB[OYc:OYc+336,OXc:OXc+288],ang,sc-[OXc,OYc],cpos)))
            # crown drops onto the heap
            v2=min(1,max(0,(f-7)/5))**2; cp=cyx+(crown_end-cyx)*v2; False and o.alpha_composite(Image.fromarray(place(CR[OYc:OYc+336,OXc:OXc+288],0*v2,cyx-[OXc,OYc],cp)))
            if False:  # (v2 rim, unused) (palette) round crown + staff so they read on the black heap
                L1=place(STB[OYc:OYc+336,OXc:OXc+288],ang,sc-[OXc,OYc],cpos)[...,3]==255
                L2=place(CR[OYc:OYc+336,OXc:OXc+288],0*v2,cyx-[OXc,OYc],cp)[...,3]==255
                q=np.array(o); rim=nd.binary_dilation(L1|L2,iterations=1)&~(L1|L2); q[rim]=(120,160,200,255); r2=nd.binary_dilation(L2,iterations=2)&~L2; q[r2]=(165,200,235,255); o=Image.fromarray(q)
                o.alpha_composite(Image.fromarray(place(STB[OYc:OYc+336,OXc:OXc+288],ang,sc-[OXc,OYc],cpos))); o.alpha_composite(Image.fromarray(place(CR[OYc:OYc+336,OXc:OXc+288],0*v2,cyx-[OXc,OYc],cp)))
        q=despeck(clean(np.array(o))); out.append(Image.fromarray(q))
    T=dict(heap_top=int(heap_top),crown=list(map(float,crown_end)),staff=list(map(float,lie_c)))
    return out,T
yy2,xx2=np.mgrid[0:CH,0:CW]
REM=Image.open('remains_s5_170_v2.png')
MAP={'n':('back',True),'e':('back',False),'s':('front',True),'w':('front',False)}
INFO={}
for name,fnc in (('death',death),('idle',None)):
    R={}
    for k in (('front','back') if True else ()):
        if fnc is None:
            P=list(prep(k)); tx=-1 if k=='front' else 1; R[k]=[Image.fromarray(despeck(clean(bigarr(np.array(frame(P,f,tx)))))) for f in range(NF)]
        elif name=='death': R[k],INFO[k]=fnc(k)
        else: R[k]=fnc(k)
    for dn,(k,mir) in MAP.items():
        n=len(R[k]); s=Image.new('RGBA',(CW*n,CH))
        for i,im in enumerate(R[k]): s.alpha_composite(im.transpose(Image.FLIP_LEFT_RIGHT) if mir else im,(i*CW,0))
        s.save(f'serra5_{name}_{dn}.png')
json.dump(INFO,open('death_info.json','w')); print(INFO)
