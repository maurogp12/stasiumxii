"""grey-background keying for the v2 raws: per-pixel background model + unmixing + edge decontamination"""
from ngc import *
V2=RAW+'v2/'
def loadv2(f): return np.asarray(Image.open(V2+f).convert('RGB'),dtype=np.float32)/255.0
def bg_model(img, thr=0.035, grow=6):
    """smooth background estimate: pixels close to the border median and locally flat -> normalized-conv fill"""
    h,w,_=img.shape
    border=np.concatenate([img[:8].reshape(-1,3),img[-8:].reshape(-1,3),img[:,:8].reshape(-1,3),img[:,-8:].reshape(-1,3)])
    med=np.median(border,0)
    d=np.abs(img-med).max(-1)
    loc=ndi.uniform_filter(img,(7,7,1)); sd=np.sqrt(np.maximum(ndi.uniform_filter(img**2,(7,7,1))-loc**2,0)).max(-1)
    bgm=(d<thr*2.2)&(sd<0.012)
    bgm=ndi.binary_erosion(bgm,iterations=grow)
    wgt=ndi.gaussian_filter(bgm.astype(np.float32),25)
    bg=np.stack([ndi.gaussian_filter(img[...,c]*bgm,25) for c in range(3)],-1)/np.maximum(wgt[...,None],1e-4)
    bg=np.where(wgt[...,None]>1e-3,bg,med)
    return bg,bgm,med
def unmix(img,bg,a):
    aa=np.maximum(a,1e-3)[...,None]
    return np.clip((img-(1-a[...,None])*bg)/aa,0,1)
def key_objects(img, bg, lo=0.035, hi=0.10, fill=True, min_size=400, close=2):
    """opaque-object key (rocks, cliff): colour distance from the bg model, holes filled, small specks dropped"""
    d=np.sqrt(((img-bg)**2).sum(-1))
    core=d>hi
    core=ndi.binary_closing(core,iterations=close)
    if fill: core=ndi.binary_fill_holes(core)
    lab,n=ndi.label(core); sz=ndi.sum(core,lab,range(1,n+1))
    core=np.isin(lab,[i+1 for i,v in enumerate(sz) if v>=min_size])
    soft=smoothstep(lo,hi,d)
    # alpha: solid inside the core (eroded 1px), soft distance ramp in a 3px band around it
    inner=ndi.binary_erosion(core,iterations=1)
    band=ndi.binary_dilation(core,iterations=3)&~inner
    a=np.where(inner,1.0,np.where(band,soft,0.0)).astype(np.float32)
    a=np.maximum(a,ndi.gaussian_filter(inner.astype(np.float32),0.7)*inner)
    return a,core
def key_white(img, bg, fg=np.array([0.97,0.975,0.99]), lo=0.02, gain=1.0):
    """semi-transparent white matter (snow flecks / drifts) over a darker bg: alpha by luminance unmixing toward fg"""
    L=lum(img); Lb=lum(bg); Lf=lum(fg)
    a=np.clip((L-Lb-lo)/np.maximum(Lf-Lb-lo,1e-3),0,1)*gain
    return np.clip(a,0,1)
def halo_stats(rgb,a,bgc,tol=0.035):
    """fraction of soft-edge pixels whose (unmixed) colour is still ~the sheet grey -> halo"""
    e=(a>0.05)&(a<0.95)
    if e.sum()==0: return 0.0,0
    d=np.abs(rgb[e]-bgc).max(-1)
    return float((d<tol).mean()),int(e.sum())
def key_textured(img, bg, thr=0.55, erode=2, min_size=2000):
    """rocks on a grey sheet with painted soft ground shadows: the rock is textured, the shadow is smooth.
    returns alpha (soft 1px edge), unmixed colour, core mask"""
    L=lum(img); r=L/np.maximum(lum(bg),1e-3)
    rg=ndi.gaussian_filter(r,1.0)
    g=np.hypot(ndi.sobel(rg,0),ndi.sobel(rg,1))
    tex=ndi.maximum_filter(g,5)
    core=tex>thr
    core=ndi.binary_fill_holes(core)
    core=ndi.binary_opening(core,iterations=2)
    core=ndi.binary_fill_holes(core)
    lab,n=ndi.label(core); sz=ndi.sum(core,lab,range(1,n+1))
    core=np.isin(lab,[i+1 for i,v in enumerate(sz) if v>=min_size])
    core=ndi.binary_erosion(core,iterations=erode)
    a=ndi.gaussian_filter(core.astype(np.float32),0.8)
    a=np.where(core,np.maximum(a,0.75),a)
    a=np.clip((a-0.15)/0.85,0,1)
    return a,core
def key_flood(img, bg, bgm, gthr=0.06, sigma=1.2, min_size=1500, edge_px=1.0, open_it=1, drop_shadowlike=False, restore=True, erode_px=1.5, dark_stop=None):
    """objects with painted soft shadows: flood the background (incl. the smooth painted shadow) from known-bg seeds
    through smooth pixels; whatever the flood cannot reach is the object. Returns alpha, unmixed colour, local bg."""
    L=lum(img); r=L/np.maximum(lum(bg),1e-3)
    rg=ndi.gaussian_filter(r,sigma)
    g=np.hypot(ndi.sobel(rg,0),ndi.sobel(rg,1))/8.0*10   # ~ per-px ratio change x10
    cg=np.sqrt(sum(ndi.sobel(ndi.gaussian_filter(img[...,c],sigma),0)**2+ndi.sobel(ndi.gaussian_filter(img[...,c],sigma),1)**2 for c in range(3)))/8.0*10
    smooth=(g<gthr)&(cg<gthr*1.4)
    smooth&=~(L>lum(bg)+0.035)          # brighter than the sheet = snow on the object: never flood it
    if dark_stop is not None: smooth&=~(L<lum(bg)*dark_stop)   # painted ground shadows never get this dark; shaded faces do
    lab,n=ndi.label(smooth)
    ids=np.unique(lab[bgm&smooth]); ids=ids[ids>0]
    reach=np.isin(lab,ids)
    obj=~reach
    # leftover slivers of painted shadow: darker than the sheet, neutral, untextured
    sat=img.max(-1)-img.min(-1)
    tex=ndi.maximum_filter(g,3)
    shadowlike=(L<lum(bg)*0.985)&(sat<0.045)&(tex<gthr*2.5)
    if drop_shadowlike: obj&=~shadowlike
    obj0=obj.copy()
    obj=ndi.binary_opening(obj,iterations=open_it)
    if restore and open_it>1:
        # give back fine silhouette detail (spires, snow lumps) that is textured or brighter than the sheet
        tex2=ndi.maximum_filter(g,3)
        keep=obj0&ndi.binary_dilation(obj,iterations=open_it+1)&((tex2>gthr*3)|(L>lum(bg)+0.02))
        obj=obj|keep
    obj=ndi.binary_fill_holes(obj)
    lab2,n2=ndi.label(obj); sz=ndi.sum(obj,lab2,range(1,n2+1))
    obj=np.isin(lab2,[i+1 for i,v in enumerate(sz) if v>=min_size])
    # local background (sheet grey + painted shadow) for unmixing the rim
    rm=(~ndi.binary_dilation(obj,iterations=2)).astype(np.float32)
    w=ndi.gaussian_filter(rm,4)
    lbg=np.stack([ndi.gaussian_filter(img[...,c]*rm,4) for c in range(3)],-1)/np.maximum(w[...,None],1e-4)
    lbg=np.where(w[...,None]>1e-3,lbg,bg)
    return finish_rim(img,obj,lbg,erode_px=erode_px)
def finish_rim(img,obj,lbg,erode_px=1.5,dec_px=3.0):
    """pull the silhouette in (the painted rim is a rock/grey mix), antialias it, and decontaminate rim colours that
    still look like the sheet grey by pulling them toward the nearby interior colour"""
    din=ndi.distance_transform_edt(obj)
    sd=din-erode_px
    a=np.clip(sd+0.5,0,1).astype(np.float32)
    a=ndi.gaussian_filter(a,0.5)*(din>0)
    inner=(din>dec_px+erode_px).astype(np.float32)
    w=ndi.gaussian_filter(inner,3.0)
    ic=np.stack([ndi.gaussian_filter(img[...,c]*inner,3.0) for c in range(3)],-1)/np.maximum(w[...,None],1e-4)
    rim=(din>0)&(din<=dec_px+erode_px)&(w>1e-3)
    bgl=np.clip(1-np.sqrt(((img-lbg)**2).sum(-1))/0.16,0,1)
    t=(bgl*rim)[...,None]
    F=img*(1-t)+ic*t
    return a,np.clip(F,0,1),obj,lbg
