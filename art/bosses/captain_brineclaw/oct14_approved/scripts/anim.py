import numpy as np, os, sys, json
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as nd
sys.path.insert(0,'/workspace/foe_walks/fly_back'); import dspk, fxlib
src=open('/workspace/foe_walks/fly/keyact.py').read(); exec(src[:src.index('def build')])
OD='/workspace/foe_walks/cb3_out/captain_brineclaw_v3'; NM='captain_brineclaw'; os.makedirs(OD,exist_ok=True)
ld=lambda n: np.array(Image.open(f'{n}.png'))
BE,BN=ld('key_f_rest'),ld('key_b_rest'); STEP={'f':ld('key_f_step'),'b':ld('key_b_step')}; KW,KS,KC,KD=ld('key_windup'),ld('key_strike'),ld('key_cast'),ld('key_dying')
def legrig(img):
    a=img[...,3]>0; ys,xs=np.nonzero(a); top,bot=ys.min(),ys.max(); h=bot-top; hip=top+0.6*h
    feet=a.copy(); feet[:int(top+0.84*h)]=0
    lab,n=nd.label(feet); cen=nd.center_of_mass(feet,lab,range(1,n+1)); sz=nd.sum(feet,lab,range(1,n+1))
    order=np.argsort([c[1] for c in cen]); grp=np.zeros(n+1,int)
    k=0
    for i in order:
        if sz[i]<15: grp[i+1]=k%2; continue
        grp[i+1]=k%2; k+=1
    _,ind=nd.distance_transform_edt(lab==0,return_indices=True)
    G=grp[lab[ind[0],ind[1]]]; return dict(hip=hip,bot=bot,G=G,a=a)
def legs(img,R,p,amp=8,lift=7,bob=2.0):
    w=np.clip((Y-R['hip'])/(R['bot']-R['hip']),0,1)**1.2; g=R['G']; ph=p+np.pi*g
    dx=amp*(-np.cos(ph)); dy=-lift*np.maximum(0,np.sin(ph)); b=round(bob*abs(np.sin(p)))
    sx=np.round(X-dx*w).astype(int); sy=np.round(Y-dy*w-b*(1-w)).astype(int)
    ok=(sx>=0)&(sx<288)&(sy>=0)&(sy<336); out=np.zeros_like(img); out[ok]=img[sy[ok],sx[ok]]
    # legs of other group must not be pulled from wrong group: mask by source group
    bad=ok.copy(); bad[ok]=g[sy[ok],sx[ok]]!=g[ok]; low=w>0.05; out[bad&low&(img[np.clip(sy,0,335),np.clip(sx,0,287)][...,3]>0)]=out[bad&low&(img[np.clip(sy,0,335),np.clip(sx,0,287)][...,3]>0)]
    return out
def tint(o,t,col=(200,40,40)):
    o=o.copy(); m=o[...,3]>0; f=o[...,:3].astype(float); f=f*(1-t)+np.array(col)*t; o[...,:3][m]=np.clip(f[m],0,215).astype(np.uint8); return o
def stroke(fn,blur,col,alpha):
    m=Image.new('L',(288,336)); fn(ImageDraw.Draw(m)); a=np.array(m.filter(ImageFilter.GaussianBlur(blur))).astype(float)/255*alpha
    return a, np.zeros((336,288,3))+col
def addfx(o,layers):
    for a,c in layers: o=fxlib.comp(o,a,c,add=0.5)
    return o
def swoosh(k,cx,cy,r,a0,a1,back=False):
    if k<=0: return []
    def fn(d,w):
        d.arc([cx-r,cy-r*0.8,cx+r,cy+r*0.8],a0,a0+(a1-a0)*min(1,k),fill=255,width=w)
    al=1.0 if k<=1 else max(0,1-(k-1)*1.5)
    return [stroke(lambda d:fn(d,14),5,(60,170,165),0.65*al),stroke(lambda d:fn(d,4),1.2,(150,225,215),0.9*al)]
def water(f,hgt,cx=222,base=298,alpha=1.0):
    if hgt<=0: return []
    m=Image.new('L',(288,336)); d=ImageDraw.Draw(m); m2=Image.new('L',(288,336)); d2=ImageDraw.Draw(m2)
    for y in range(int(base-hgt),base):
        u=(base-y)/max(hgt,1); x=cx+9*np.sin(y/16-f*0.9)+4*np.sin(y/7+f*1.3); w=12+10*(1-u)+4*np.sin(y/11+f)
        d.line([(x-w,y),(x+w,y)],fill=200); d2.line([(x-w*0.35,y),(x+w*0.35,y)],fill=255)
    d.ellipse([cx-34,base-8,cx+34,base+6],fill=170)
    a1=np.array(m.filter(ImageFilter.GaussianBlur(3))).astype(float)/255*0.8*alpha; a2=np.array(m2.filter(ImageFilter.GaussianBlur(2))).astype(float)/255*0.6*alpha
    return [(a1,np.zeros((336,288,3))+(40,150,150)),(a2,np.zeros((336,288,3))+(150,225,215))]
rng=np.random.default_rng(4)
def bursts(src,f0,n):
    m=src[...,3]>0; ys,xs=np.nonzero(m); P=[]
    for j in rng.choice(len(ys),n,replace=False):
        wat=rng.random()<0.6
        P.append(dict(f0=f0,x=xs[j],y=ys[j],vx=rng.uniform(-5,5),vy=rng.uniform(-6,-1),c=(70,180,175) if wat else (95,85,60),sz=rng.uniform(3,6),life=int(rng.integers(4,7)),wat=wat))
    return P
def drawP(o,P,f):
    pts=[]
    for p in P:
        t=f-p['f0']
        if t<0 or t>p['life']+3: continue
        x=p['x']+p['vx']*t; y=min(299,p['y']+p['vy']*t+0.7*t*t)
        fade=max(0,1-t/(p['life']+3)) if p['wat'] else 1
        pts.append((x,y,p['sz']*fade,p['c']))
    a,c=fxlib.soft_dots(pts,2.2,1.0); return fxlib.comp(o,a,c,add=0.3)
def heap(Dk):
    a=Dk[...,3]>0; ys,xs=np.nonzero(a); top,bot=ys.min(),ys.max(); h=bot-top
    low=Dk.copy(); low[:int(top+0.32*h)]=0
    pile=xf(low,sy=-0.45,sx=0.2)
    hat=Dk.copy(); hat[int(top+0.17*h):]=0; hy=np.nonzero(hat[...,3]>0)[0]
    hat=xf(hat,rot=-18,dy=(bot-8-hy.max())+ -int(0.3*h*0.38),dx=18)
    o=pile.copy(); m=hat[...,3]>0; o[m]=hat[m]; return o
NOISE=np.clip(nd.gaussian_filter(np.random.default_rng(2).random((336,288)),5)*6-2.5,0,1)
T=2*np.pi
def mirlegs(img):
    a=img[...,3]>0; ys,xs=np.nonzero(a); top,bot=ys.min(),ys.max(); hip=int(top+0.62*(bot-top))
    low=np.zeros_like(img); low[hip:]=img[hip:]; lx=np.nonzero(low[...,3].any(0))[0]; cx=(lx.min()+lx.max())//2
    fl=np.zeros_like(img); src=low[:, ::-1]; sh=cx-(287-cx); fl=np.roll(src,sh,axis=1)
    o=img.copy(); o[hip+6:]=0; m=fl[...,3]>0; m[:hip]=False; o[m]=fl[m]; return dspk.clean(o)
def build_dir(base,front):
    R=legrig(base); out={}
    out['idle']=[legs(base,R,T*i/6+np.pi/2,amp=0,lift=0,bob=1.5) for i in range(6)]
    st=STEP['f' if front else 'b']; sm=mirlegs(st)
    out['walk']=[xf(x,dy=d) if d else x.copy() for x,d in ((base,0),(st,2),(st,1),(base,-1),(base,0),(sm,2),(sm,1),(base,-1))]
    rest=base
    if front:
        seq=[(rest,{},None),(rest,dict(dx=2,sy=-0.03),None),(KW,dict(dy=1,sy=-0.03),None),(KW,dict(dx=-2),None),(KW,dict(dx=-3,dy=-1),None),
             (KS,dict(dx=8,smear=0),1.0),(KS,dict(dx=4),1.5),(KS,dict(dx=2),1.8),(KS,{},2.2),(rest,dict(dx=-3),None),(rest,dict(dx=-1),None),(rest,{},None)]
        att=[addfx(xf(i,**p) if p else i.copy(), swoosh(k,150,150,95,200,340) if k else []) for i,p,k in seq]
    else:
        seq=[({},None),(dict(rot=-3,dy=1),None),(dict(rot=-6,dx=-4,dy=2,sy=-0.03),None),(dict(rot=-7,dx=-5,dy=2),None),(dict(rot=6,dx=8,sy=0.02),0.6),
             (dict(rot=9,dx=12,smear=8),1.0),(dict(rot=7,dx=10),1.5),(dict(rot=5,dx=7),1.8),(dict(rot=3,dx=4),2.2),(dict(rot=1,dx=2),None),({},None),({},None)]
        att=[addfx(xf(rest,**p) if p else rest.copy(), swoosh(k,170,120,90,250,400) if k else []) for p,k in seq]
    out['attack']=att
    hp=[{},dict(dx=-10,dy=-3,rot=-5,tint=0.0),dict(dx=-11,dy=-3,rot=-6),dict(dx=-7,dy=-2,rot=-4),dict(dx=-2,rot=-1),{}]
    out['hit']=[xf(rest,**p) if p else rest.copy() for p in hp]; out['hit'][1]=tint(out['hit'][1],0.45); out['hit'][2]=tint(out['hit'][2],0.2)
    C=KC if front else rest; cs=[]
    for f in range(14):
        img=rest if f<2 or f>=12 else C
        p=dict(dx=[0,1,0,0,0,1,0,-1,0,1,0,0,-1,0][f],dy=[0,1,2,1,0,0,1,0,0,1,0,0,0,0][f])
        if not front and 2<=f<12: p.update(rot=-4,dy=1)
        h=[0,0,40,90,140,180,200,210,215,210,190,120,50,0][f]
        o=xf(img,**p); cs.append(addfx(o,water(f,h,cx=222 if front else 230,alpha=1 if f<11 else 0.6)))
    out['cast']=cs
    Dk=KD if front else rest; H=heap(KD) if front else heap(KD)[:, ::-1].copy()
    P=bursts(Dk,1,40); dt=[]; dt.append(tint(Dk,0.4))
    for k,(dx,dy) in enumerate([(-3,0),(3,-1),(-2,1),(2,0)]):
        P+=bursts(Dk,k+2,14); dt.append(drawP(tint(xf(Dk,dx=dx,dy=dy),0.1),P,k+1))
    dm=Dk[...,3]>0; od_=nd.distance_transform_edt(dm); od_=0.7*od_/od_.max()+0.3*NOISE
    hm=H[...,3]>0; hy=np.nonzero(hm)[0]; ho=0.75*(hy.max()-Y)/(hy.max()-hy.min()+1)+0.25*NOISE; prev=dm
    for k,p in enumerate([0.3,0.55,0.8,1.01]):
        cur=dm&(od_>=p); P+=bursts(np.dstack([Dk[...,:3],(prev&~cur)*255]).astype(np.uint8),5+k,30) if (prev&~cur).sum()>30 else []; prev=cur
        o=np.zeros_like(Dk); o[cur]=Dk[cur]; hv=hm&(ho<p-0.05); o[hv]=H[hv]; dt.append(drawP(o,P,5+k))
    for f in range(9,16): dt.append(drawP(H,P,f))
    out['death']=dt
    for k in ('idle','walk','hit'): out[k]=[dspk.clean(x) for x in out[k]]
    return out
res={}
for d,base,front in (('s',BE,True),('e',BN,False)):
    o=build_dir(base,front)
    for d2,mir in ((d,False),({'s':'w','e':'n'}[d],True)):
        for act,fr in o.items():
            ff=[x[:,::-1].copy() for x in fr] if mir else fr
            dd=f'{OD}/{act}_frames_{d2}'; os.makedirs(dd,exist_ok=True); [os.remove(f'{dd}/{x}') for x in os.listdir(dd)]
            for i,a in enumerate(ff): Image.fromarray(a).save(f'{dd}/{i:02d}.png')
            Image.fromarray(np.concatenate(ff,1)).save(f'{OD}/{NM}_{act}_{d2}.png')
            arr=np.stack(ff); res[f'{act}_{d2}']=dict(frames=len(ff),residue_px=int(dspk.residue(arr.reshape(-1,288,4)).sum()),semi_alpha_px=int(((arr[...,3]>0)&(arr[...,3]<255)).sum()))
json.dump(res,open(f'{OD}/qa.json','w'),indent=1); print(res)
