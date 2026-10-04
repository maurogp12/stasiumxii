"""C) crag cliffs: full faces crag_cliff_{left,right}_h1..h3, world-loader step strips crag_side_{left,right}_{top,a,b,base_ground},
   snow cornice lips crag_lip_{left,right} + crag_lip_corner_{front,left,right}"""
from ngc import *
# ---- v1 raw: kept ONLY as the source of the snow cornice lips (crag_lip_*), which the v2 brief does not replace ----
c=load('crag_cliff_strip.jpg')
F,A,K=key_green(c,protect_interior=True,key_rows=slice(0,40))
H0,W0=A.shape
top=np.array([np.nonzero(A[:,x]>0.5)[0].min() for x in range(W0)],np.float32)
# ---- v2 raw: warm grey / cliff-white face, thin top snow, dry hay tufts (faces h1..h3 + side strips) ----
from keygrey import *
c2=loadv2('crag_cliff_strip.jpg')
bg2,bgm2,med2=bg_model(c2)
a2,F2,obj2,lbg2=key_flood(c2,bg2,bgm2,gthr=0.2,open_it=2,erode_px=1.0,dark_stop=0.66,min_size=5000)
H2,W2=a2.shape
hsv2=cv2.cvtColor(c2.astype(np.float32),cv2.COLOR_RGB2HSV)
sat2=c2.max(-1)-c2.min(-1)
tuft2=(sat2>0.12)&(hsv2[...,0]>25)&(hsv2[...,0]<60)
body=(a2>0.5)&~ndi.binary_dilation(tuft2,iterations=1)
top2=np.array([np.nonzero(body[:,x])[0].min() if body[:,x].any() else 0 for x in range(W2)],np.float32)
bot2=np.array([np.nonzero(a2[:,x]>0.5)[0].max() if (a2[:,x]>0.5).any() else 0 for x in range(W2)],np.float32)
# the painted face top is a near-straight line: use one flat top row (75th pct of the per-column snow top) so the
# flattening does not wiggle the texture; same for the usable face height (15th pct of the column heights)
_valid=(bot2-top2)>100
tops=np.full(W2,np.percentile(top2[_valid],75),np.float32)
Hr=int(np.percentile((bot2-tops)[_valid],15))
yy=np.arange(Hr+6)[:,None]
RGBA2=np.concatenate([F2,a2[...,None]],2)
flat=np.zeros((len(yy),W2,4),np.float32)
for x in range(W2):
    src=np.clip(tops[x]+yy[:,0],0,H2-1.001)
    y0=np.floor(src).astype(int); fy=(src-y0)[:,None]
    flat[:,x]=RGBA2[y0,x]*(1-fy)+RGBA2[np.minimum(y0+1,H2-1),x]*fy
flat[...,3]=np.where(np.arange(len(yy))[:,None]<3,np.maximum(flat[...,3],flat[3:4,:,3]),flat[...,3])
# value: remove the raw's top-to-bottom light falloff so any depth band has the same value (strips == one-piece faces)
Lf=lum(flat[...,:3]); snowf=snowlike_mask(flat[...,:3]); rockm=(flat[...,3]>0.5)&(snowf<0.5)
rowm=np.array([Lf[r][rockm[r]].mean() if rockm[r].sum()>50 else np.nan for r in range(len(yy))])
ok=~np.isnan(rowm); rowm=np.interp(np.arange(len(yy)),np.nonzero(ok)[0],rowm[ok])
rowm=ndi.gaussian_filter1d(rowm,12)
tgt=np.median(rowm[int(0.10*Hr):int(0.85*Hr)])
gain=np.clip(tgt/np.maximum(rowm,1e-3),0.85,1.25)
gain[:int(0.08*Hr)]=1.0
flat[...,:3]=np.clip(flat[...,:3]*gain[:,None,None],0,1)
flat[...,:3]=rock_grade(flat[...,:3],0.30)
print('v2 cliff: face height',Hr,'px raw; row gain range',round(gain.min(),2),round(gain.max(),2))
KY=Hr/60.0; FACE_LEN=math.hypot(64,32); PW=int(round(FACE_LEN*KY)); OV=64
CAP_SKIP=0
strips={'left':periodic_strip(flat,30,PW,OV),'right':periodic_strip(flat,min(640,W2-PW-OV-2),PW,OV)}
for k,v in strips.items():
    Image.fromarray((np.clip(v[...,:3]*v[...,3:]+0.5*(1-v[...,3:]),0,1)*255).astype(np.uint8)).save(f'tmp/strip_{k}.png')
SS2=4
def noise_ts(t, s, scale, seed):
    """noise in face coordinates (t = px below the top edge, s = 0..1 along the edge), periodic in s so chained faces match"""
    Hn,Wn=160*SS2,64*SS2
    N=smooth_noise((Hn,Wn),scale,seed)
    return bilinear(N[...,None],np.mod(s,1)*Wn-0.5,np.clip((t+20)*SS2,0,Hn-1.001),wrap=True)[...,0]
def face_img(side, D, depth0=0.0, ledges=False, foot=True, seed=0, s_off=0.0):
    """parallelogram face, D px tall (2x), sampling the flattened strip from depth0 (2x px below the top)"""
    Wf=64; Hh=32+D
    X=(np.arange(Wf*SS2)+0.5)/SS2; Y=(np.arange(Hh*SS2)+0.5)/SS2; X,Y=np.meshgrid(X,Y)
    s=X/64.0
    topl=32*s if side=='left' else 32-32*s
    t=Y-topl
    a=smoothstep(-0.5,0.5,t)*smoothstep(D+0.5,D-0.5,t)
    S=strips[side]
    src=bilinear(S,np.mod(s+s_off,1)*PW,np.clip((t+depth0)*KY+CAP_SKIP,0,S.shape[0]-1.001))
    rgb=src[...,:3]; sa=src[...,3]
    # behind any hole in the painted strip: dark granite (never see-through)
    rgb=rgb*sa[...,None]+np.array([0.34,0.335,0.34])*(1-sa[...,None])
    dep=t+depth0
    rgb=rgb*(1-0.0*dep)[...,None] if False else rgb   # v2: no depth darkening (strips match one-piece faces)          # deeper = darker (absolute depth: stacks stay consistent)
    if side=='left':
        rgb=rgb*(0.86+0.14*KEY)*1.05
    else:
        rgb=rgb*SHADE_N*0.97
        rgb=rgb*(1+0.10*smoothstep(3,0,X))[...,None]                  # fold highlight at the front corner
    if ledges:
        n=noise_ts(t,s,6,seed+3)
        # dark crack along the bottom 2 px, thin snow ledge on the top 2 px (hides the strip-to-strip joint)
        crack=smoothstep(D-3.2,D-0.4,t+0.6*n)
        rgb=rgb*(1-0.10*crack[...,None])          # v2: faint joint only (depth bands are continuous)
        if depth0>0:
            led=smoothstep(2.0,0.6,t+0.9*n)*smoothstep(0.35,0.7,n)*0.7
            sn=np.array([0.92,0.92,0.95]) if side=='left' else np.array([0.74,0.76,0.84])
            rgb=rgb*(1-led[...,None])+sn*led[...,None]
    if foot:
        # snow banked at the foot, irregular top edge, cool shade on the right face
        n=noise_ts(t,s,7,seed+9)
        bank=smoothstep(D-4.2,D-2.4,t+2.0*n)*smoothstep(-0.6,0.2,n)      # v2: light, broken dusting at the foot
        sn=np.array([0.95,0.95,0.97]) if side=='left' else np.array([0.76,0.78,0.86])
        sh=smoothstep(D-7,D-4.2,t+2.0*n)*(1-bank)
        rgb=rgb*(1-0.25*sh[...,None])
        rgb=rgb*(1-bank[...,None])+sn*bank[...,None]
    else:
        rgb=rgb*(1-0.04*smoothstep(D-6,D,t))[...,None]
    rgb=np.clip(rgb,0,1)
    rgb_d=down(rgb*a[...,None],SS2); a_d=down(a[...,None],SS2)[...,0]
    rgb_d=np.where(a_d[...,None]>1e-4,rgb_d/np.maximum(a_d[...,None],1e-4),0)
    return to_rgba8(rgb_d,a_d)
FACES=[]
for side in ('left','right'):
    for st in (1,2,3):
        save_world(face_img(side,20*st,0,False,True,seed=st),'tiles',f'crag_cliff_{side}_h{st}'); FACES.append(f'crag_cliff_{side}_h{st}')
    save_world(face_img(side,20,0,True,False,seed=11),'tiles',f'crag_side_{side}_top')
    save_world(face_img(side,20,20,True,False,seed=12),'tiles',f'crag_side_{side}_a')
    save_world(face_img(side,20,20,True,False,seed=13,s_off=0.5),'tiles',f'crag_side_{side}_b')
    save_world(face_img(side,20,40,True,True,seed=14),'tiles',f'crag_side_{side}_base_ground')
    FACES+=[f'crag_side_{side}_{v}' for v in ('top','a','b','base_ground')]
# ---------- snow cornice lips ----------
cap_rows=slice(0,95)          # flattened cap region (row 0 = cap top)
UP=8; DOWN=12
# lip source: the ORIGINAL (unflattened) lumpy cap, keyed, restricted to snow pixels
def snow_cls(rgb):
    L=lum(rgb); sat=rgb.max(-1)-rgb.min(-1)
    return smoothstep(0.55,0.72,L)*smoothstep(0.30,0.14,sat)
lipsrc=np.concatenate([F,(A*snow_cls(F))[...,None]],2)
# keep only the cap band: rows from the silhouette down to ~75 px
rows=np.arange(H0)[:,None]
band=(rows<top[None,:]+78)
lipsrc[...,3]*=band
# remove isolated snow bits lower on the face
lab,n=ndi.label(lipsrc[...,3]>0.3); sz=ndi.sum(np.ones_like(lab),lab,range(1,n+1))
big=np.isin(lab,[i+1 for i,v in enumerate(sz) if v>800]); lipsrc[...,3]*=ndi.binary_dilation(big,iterations=2)
lipsrc[...,3]=ndi.gaussian_filter(lipsrc[...,3],0.6)
r_edge=int(np.median(top))+30        # this source row lands on the cell edge line
KYl=4.6; PWl=int(round(FACE_LEN*KYl))
lipstrip={'left':periodic_strip(lipsrc,100,PWl,50,0,None),'right':periodic_strip(lipsrc,700,PWl,50,0,None)}
def lip(side):
    Wf=64; Hh=32+UP+DOWN
    X=(np.arange(Wf*SS2)+0.5)/SS2; Y=(np.arange(Hh*SS2)+0.5)/SS2; X,Y=np.meshgrid(X,Y)
    s=X/64.0
    edge=UP+(32*s if side=='left' else 32-32*s)
    t=Y-edge
    S=lipstrip[side]
    src=bilinear(S,np.mod(s,1)*PWl,np.clip(r_edge+t*KYl,0,S.shape[0]-1.001))
    C=src[...,:3]; Al=src[...,3]
    Al=Al*smoothstep(-UP,-UP+4,t)*smoothstep(DOWN,DOWN-3,t)
    Al=Al*smoothstep(7.5,4.0,t+1.5*noise_ts(t,s,5,77))     # direction update: thin hang (~5-7 px)
    # overhang part in shade, cooler on the right face
    hang=np.clip(t/10.0,0,1)
    C=C*(1-0.18*hang)[...,None]
    if side=='right': C=C*(1-(1-SHADE_N)*np.clip(hang+0.25,0,1)[...,None])
    C=np.minimum(C,0.985)
    # soft contact AO under the hanging lip on the rock
    ao=smoothstep(DOWN+2,DOWN-3,t)*smoothstep(1,5,t)*(1-Al)*0.22
    Af=Al+ao
    Cf=np.where(Af[...,None]>1e-5,(C*Al[...,None]+np.array([0.12,0.12,0.14])*ao[...,None])/np.maximum(Af,1e-5)[...,None],0)
    rgb=down(Cf*Af[...,None],SS2); a=down(Af[...,None],SS2)[...,0]
    rgb=np.where(a[...,None]>1e-4,rgb/np.maximum(a[...,None],1e-4),0)
    return to_rgba8(np.clip(rgb,0,1),np.clip(a,0,1))
save_world(lip('left'),'tiles','crag_lip_left'); save_world(lip('right'),'tiles','crag_lip_right')
FACES+=['crag_lip_left','crag_lip_right']
def lip_corner(name, seed):
    W=40; Hh=40; VX=20; VY=12
    X=(np.arange(W*SS2)+0.5)/SS2; Y=(np.arange(Hh*SS2)+0.5)/SS2; X,Y=np.meshgrid(X,Y)
    dx=X-VX; t=Y-VY
    S=lipstrip['left']
    src=bilinear(S,np.mod(dx/64.0+0.37+seed*0.21,1)*PWl,np.clip(r_edge+t*KYl,0,S.shape[0]-1.001))
    C=src[...,:3]; Al=np.maximum(src[...,3],0.0)
    n=smooth_noise(X.shape,6,seed+40)
    if name=='front': rr=np.sqrt((dx/15.0)**2+(np.minimum(t,0)/8.0)**2+(np.maximum(t,0)/11.0)**2)
    elif name=='left': rr=np.sqrt((np.minimum(dx+4,0)/7.0)**2+(np.maximum(dx-13,0)/5.0)**2+(np.minimum(t,0)/8.0)**2+(np.maximum(t,0)/11.0)**2)
    else: rr=np.sqrt((np.maximum(dx-4,0)/7.0)**2+(np.minimum(dx+13,0)/5.0)**2+(np.minimum(t,0)/8.0)**2+(np.maximum(t,0)/11.0)**2)
    shape=smoothstep(1.0,0.82,rr+0.10*n)*smoothstep(7.5,4.0,t)
    snowc=np.array([0.96,0.96,0.99])
    C=C*0.5+snowc*0.5
    Al=np.clip(shape*np.maximum(Al,0.85),0,1)
    hang=np.clip(t/10.0,0,1)
    C=C*(1-0.18*hang)[...,None]
    if name=='right' or (name=='front'): C=np.where(((dx>0) if name=='front' else (dx>-99))[...,None],C*(1-(1-SHADE_N)*hang[...,None]),C)
    rgb=down(C*Al[...,None],SS2); a=down(Al[...,None],SS2)[...,0]
    rgb=np.where(a[...,None]>1e-4,rgb/np.maximum(a[...,None],1e-4),0)
    return to_rgba8(np.clip(rgb,0,1),np.clip(a,0,1))
for i,nm in enumerate(('front','left','right')):
    save_world(lip_corner(nm,i),'tiles','crag_lip_corner_'+nm); FACES.append('crag_lip_corner_'+nm)
json.dump(dict(faces=FACES,KY=KY,PW=PW,UP=UP,DOWN=DOWN),open('tmp/cliff_meta.json','w'))
print('cliff done',len(FACES))
