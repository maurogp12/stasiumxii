"""apply a flat roof snow cap to a cottage sprite (the README recipe, done in numpy):
   1) roof alpha = the roof layer's alpha (here derived: blue slate pixels, biggest component, holes filled)
   2) fit the eave + ridge lines of the visible slope (2:1, sign by slope side)
   3) shear the cap per column so its eave row sits on the eave line; scale it so its top edge lands in the top third
   4) cap alpha *= roof alpha, where the roof alpha is extended DOWNWARD by lip_px only below the eave (icicles hang over)"""
from ngc import *
ROOF=SHIP+'roof/_2x/'
RM=json.load(open(B+'tmp/roof_meta.json'))
def roof_mask(im):
    r,g,b,a=[im[...,i] for i in range(4)]
    m=(b>r+35)&(b>g+10)&(a>128)
    lab,n=ndi.label(m); sz=ndi.sum(m,lab,range(1,n+1))
    big=lab==(np.argmax(sz)+1)
    big=ndi.binary_fill_holes(ndi.binary_closing(big,iterations=2))
    big=ndi.binary_opening(big,iterations=1)
    return big
def fit_line(xs,ys,kexp):
    best=None
    w=8
    d=(ys[w:]-ys[:-w])/np.maximum(xs[w:]-xs[:-w],1)
    ok=np.abs(d-kexp)<0.2
    # longest run of ok steps
    i=0
    while i<len(ok):
        if ok[i]:
            j=i
            while j<len(ok) and ok[j]: j+=1
            if best is None or j-i>best[1]-best[0]: best=(i,j)
            i=j
        else: i+=1
    i0,i1=best; i1=i1+w-1
    i0+=2; i1-=2
    sel=slice(i0,i1+1)
    k,c=np.polyfit(xs[sel],ys[sel],1)
    return k,c,(int(xs[i0]),int(xs[i1]))
def snow_roof(cottage_png, cap_id, side, top_frac=None, xoff=37, shade=1.0, return_debug=False, back=True, band=None):
    im=np.asarray(Image.open(cottage_png).convert('RGBA')).astype(np.float32)
    H,W=im.shape[:2]
    M=roof_mask(im)
    cols=np.nonzero(M.any(0))[0]
    bot=np.array([np.nonzero(M[:,x])[0].max() for x in cols],np.float32)
    top=np.array([np.nonzero(M[:,x])[0].min() for x in cols],np.float32)
    kexp=0.5 if side=='left' else -0.5
    def robust_c(ys):
        # iso roofs are exactly 2:1: fix the slope, fit the intercept robustly (mode of y - k x)
        r=ys-kexp*cols
        h,e=np.histogram(r,bins=np.arange(r.min()-1,r.max()+2,1.0))
        c0=e[np.argmax(ndi.uniform_filter1d(h.astype(float),3))]+0.5
        sel=np.abs(r-c0)<2.5
        return float(np.median(r[sel])),(int(cols[sel].min()),int(cols[sel].max())),int(sel.sum())
    ce,re,ne=robust_c(bot); cr,rr,nr=robust_c(top)
    k=ke=kr=kexp
    depth=(ce+ke*W/2)-(cr+kr*W/2)
    cap=np.asarray(Image.open(ROOF+cap_id+'.png').convert('RGBA')).astype(np.float32)/255.
    m=RM[cap_id]; eave=m['eave_px_2x']; ctop=m['top_px_2x']; lip=m['lip_px_2x']
    # vertical scale: cap top lands top_frac of the slope depth below the ridge
    if top_frac is None: top_frac={'full':0.05}.get(m.get('coverage'),0.33)   # direction update: light caps start a third down
    sy=(1-top_frac)*depth/max(eave-ctop,1)
    SYL=1.1     # icicles / lip keep their painted proportions
    yy,xx=np.mgrid[0:H,0:W].astype(np.float32)
    eline=ce+k*xx-1.0
    srow=np.where(yy<eline,eave-(eline-yy)/sy,eave+(yy-eline)/SYL)
    scol=np.mod(xx+xoff,cap.shape[1])
    pm=cap.copy(); pm[...,:3]*=pm[...,3:4]
    S=cv2.remap(pm,scol,srow,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
    # roof alpha, soft edge, extended down by the lip only below the eave line
    Ms=ndi.gaussian_filter(M.astype(np.float32),0.6)
    L=int(math.ceil(lip*SYL))+2
    Md=Ms.copy()
    for d in range(1,L+1): Md[d:]=np.maximum(Md[d:],Ms[:-d])
    below=smoothstep(-1.0,1.0,yy-eline)
    mask=np.maximum(Ms,Md*below)
    # never onto transparent pixels of the sprite above the eave (keeps the outline), icicles may hang below
    A=S[...,3]*mask
    # direction update: light caps (patchy/dust) are a broken band in the TOP THIRD of the slope (no eave lip / icicles).
    # band=(t0,t1) as fractions of the ridge->eave depth; default (0.03,0.36) for patchy/dust, None (=full slope + lip) for full.
    if band is None and m.get('coverage') in ('patchy','dust'): band=(0.03,0.36)
    if band is not None:
        t0,t1=band
        rline=cr+k*xx
        sy0=0.9*depth/max(eave-ctop,1)
        srow2=ctop+(yy-(rline+t0*depth))/sy0
        S=cv2.remap(pm,scol,srow2.astype(np.float32),cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
        nz=smooth_noise((H,W),6,sum(map(ord,cap_id))%997,periodic=False)
        fade=smoothstep(t1*depth+3.0,t1*depth-5.0,yy-rline+5.0*nz)
        A=S[...,3]*Ms*fade
    rgb=np.where(S[...,3:4]>1e-4,S[...,:3]/np.maximum(S[...,3:4],1e-4),0)*shade
    # snow lies ON the tiles: borrow the roof's own relief (high-pass luminance) as soft bumps in the snow
    Lr=lum(im[...,:3]/255.)
    hp=(Lr-ndi.gaussian_filter(Lr,3.0))*M
    hp=ndi.gaussian_filter(hp,1.0)
    rgb=np.clip(rgb*(1+0.42*hp[...,None]),0,0.985)
    out=im/255.
    Cc,Aa=over(out[...,:3],out[...,3],rgb,A)
    # back slope: the far roof plane shows as a dark strip above the ridge line (and past the gable); give it plain body
    # snow (no lip), a little darker because it faces away from the key light
    if back:
        r_,g_,b_,a_=[im[...,i] for i in range(4)]
        loose=(b_>r_+20)&(b_>g_+5)&(a_>128)&~ndi.binary_dilation(M,iterations=1)
        rline=cr+k*xx
        loose&=(yy<rline+3)
        lab,n=ndi.label(loose)
        if n:
            sz=ndi.sum(loose,lab,range(1,n+1))
            keepb=np.isin(lab,[i+1 for i,v in enumerate(sz) if v>=40])
            keepb=ndi.binary_fill_holes(ndi.binary_closing(keepb,iterations=1))
            Mb=ndi.gaussian_filter(keepb.astype(np.float32),0.6)
            brow=ctop+6+np.mod(yy-k*xx,28.0)
            Sb=cv2.remap(pm,scol,brow.astype(np.float32),cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
            Ab=Sb[...,3]*Mb
            rgbb=np.where(Sb[...,3:4]>1e-4,Sb[...,:3]/np.maximum(Sb[...,3:4],1e-4),0)*0.86*shade
            Cc,Aa=over(Cc,Aa,rgbb,Ab)
    res=to_rgba8(np.nan_to_num(Cc),np.nan_to_num(Aa))
    if return_debug: return res,dict(M=M,eave=(ke,ce,re),ridge=(kr,cr,rr),k=k,depth=depth,sy=sy,capA=A)
    return res
