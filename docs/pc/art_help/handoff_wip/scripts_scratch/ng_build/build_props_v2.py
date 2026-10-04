"""F) snow drift overlays + H) crag props -> props/ (1x) + props/_2x/ (world layout); writes tmp/props_meta.json"""
from ngc import *
import pickle
C=pickle.load(open('tmp/cuts.pkl','rb'))   # v1 cuts (drifts replaced below)
META={}
AO_COL=np.array([0.12,0.12,0.14])
def snowlike(rgb):
    L=lum(rgb); sat=rgb.max(-1)-rgb.min(-1)
    return smoothstep(0.66,0.78,L)*smoothstep(0.22,0.12,sat)
def fp_poly_dist(W,H,fp):
    """signed px distance (2x) to the footprint diamond (<0 inside), canvas coords, anchor (W/2,H)"""
    ax,ay=W/2,H
    yy,xx=np.mgrid[0:H,0:W]+0.5
    def dia(cx,cy): return (np.abs(xx-cx)/64+np.abs(yy-cy)/32-1)*32
    fx,fy=fp
    d=np.full((H,W),1e9)
    for i in range(fx):
        for j in range(fy):
            # cells of the footprint relative to the front (anchor) cell: x-i, y-j
            cx=ax+(-i+j)*64; cy=ay-32+(-i-j)*32
            d=np.minimum(d,dia(cx,cy))
    return d
def paste(W,H,rgb,a,ox,oy):
    Cc=np.zeros((H,W,3)); A=np.zeros((H,W)); h,w=a.shape
    x0=max(0,ox); y0=max(0,oy); x1=min(W,ox+w); y1=min(H,oy+h)
    Cc[y0:y1,x0:x1]=rgb[y0-oy:y1-oy,x0-ox:x1-ox]; A[y0:y1,x0:x1]=a[y0-oy:y1-oy,x0-ox:x1-ox]
    clipped=bool(ox<0 or oy<0 or ox+w>W or oy+h>H) and bool(a[:max(0,-oy)].max(initial=0)>0.05 or a[:, :max(0,-ox)].max(initial=0)>0.05 or a[:, W-ox:].max(initial=0)>0.05)
    return Cc,A,clipped
def add_ao(Cc,A,fp,cx,cy,rx,ry,st=0.24):
    H,W=A.shape
    yy,xx=np.mgrid[0:H,0:W]+0.5
    r2=((xx-cx)/rx)**2+((yy-cy)/ry)**2
    f=st*np.exp(-2.2*r2)*(r2<1.8)
    d=fp_poly_dist(W,H,fp)
    f=f*smoothstep(1,-4,d)*smoothstep(H-0.5,H-4,yy)
    return over(np.ones((H,W,3))*AO_COL,np.minimum(f,0.3),Cc,A)
def save_prop(pid, Cc, A, fp, kind, layer, note, extra=None, clipped=False):
    arr=to_rgba8(Cc,A)
    # kill green spill completely on every non-opaque or edge pixel (snow is white/blue; nothing green belongs on a fringe)
    save_world(arr,'props',pid)
    H,W=A.shape; ax,ay=W//2,H
    op=arr[...,3]>128; ys,xs=np.nonzero(op); ys0,xs0=np.nonzero(arr[...,3]>0)
    gf=green_fringe_stats(arr)
    META[pid]=dict(id=pid,file='props/'+pid+'.png',file_2x='props/_2x/'+pid+'.png',size=[W//2,H//2],size_2x=[W,H],
        anchor_px_2x=[ax,ay],anchor_px_1x=[ax//2,ay//2],footprint_cells=list(fp),kind=kind,layer=layer,
        art_height_px_2x=int(ay-ys.min()),height_cells=round((ay-ys.min()-32)/64,2) if False else None,
        lowest_opaque_gap_px_2x=int(ay-1-ys.max()),art_x_from_anchor_2x=[int(xs.min()-ax),int(xs.max()-ax)],
        green_fringe_share=round(gf[0],4),note=note,clipped=clipped)
    del META[pid]['height_cells']
    if extra: META[pid].update(extra)
    print(f"{pid:22s} {W}x{H} fp{fp} h{META[pid]['art_height_px_2x']} gap{META[pid]['lowest_opaque_gap_px_2x']} x{META[pid]['art_x_from_anchor_2x']} fringe {gf[0]*100:.2f}% of {gf[1]}{' CLIPPED' if clipped else ''}")
    return arr
def final_despill(rgb,a):
    lim=np.maximum(rgb[...,0],rgb[...,2])
    g=np.minimum(rgb[...,1],lim+0.005)
    edge=(a<0.995)|ndi.binary_dilation(a<0.5,iterations=2)
    out=rgb.copy(); out[...,1]=np.where(edge,g,rgb[...,1]); return out
# ================= H) crag props (v2 raw: crag_props.jpg, 3x4 sheet on light grey, top dusting, no skirts) =================
from keygrey import *
SHEET=loadv2('crag_props.jpg')
BG,BGM,MED=bg_model(SHEET)
def cut_rocks():
    img=SHEET
    L=lum(img)
    a,F,obj,lbg=key_flood(img,BG,BGM,gthr=0.2,open_it=3,erode_px=2.0,dark_stop=0.66)
    # painted ground shadow still glued to the base: drop smooth, darker-than-sheet pixels in the lowest 30% of each rock
    rg=ndi.gaussian_filter(L/np.maximum(lum(BG),1e-3),1.2)
    g=np.hypot(ndi.sobel(rg,0),ndi.sobel(rg,1))/8.0*10
    tex=ndi.maximum_filter(g,3)
    out=[]
    H0,W0=L.shape
    for r_ in range(3):
        for c_ in range(4):
            cell=np.zeros_like(obj); cell[r_*240:(r_+1)*240,c_*320:(c_+1)*320]=True
            o=obj&cell
            lab,n=ndi.label(o); sz=ndi.sum(o,lab,range(1,n+1))
            big=max(sz); o=np.isin(lab,[i+1 for i,v in enumerate(sz) if v>=0.04*big])
            ys,xs=np.nonzero(o); y0,y1=ys.min(),ys.max()
            low=(np.arange(H0)[:,None]>y0+0.70*(y1-y0))
            # only a thin rim (<= 6 px from the outside) can be leftover shadow; deeper shaded faces are rock
            near=ndi.distance_transform_edt(o)<=6
            sh=low&near&(L<lum(lbg)*0.99)&(tex<0.5)&((img.max(-1)-img.min(-1))<0.05)
            sh|=low&near&(np.sqrt(((img-lbg)**2).sum(-1))<0.06)          # grey-like = sheet / painted shadow, not rock
            o=o&~sh
            o=ndi.binary_opening(o,iterations=1); o=ndi.binary_fill_holes(ndi.binary_closing(o,iterations=2))
            lab,n=ndi.label(o); sz=ndi.sum(o,lab,range(1,n+1)); big=max(sz)
            o=np.isin(lab,[i+1 for i,v in enumerate(sz) if v>=0.04*big])
            aa,FF,_,_=finish_rim(img,o,lbg,erode_px=1.5)
            ys,xs=np.nonzero(aa>0.03)
            sl=(slice(ys.min()-2,ys.max()+3),slice(xs.min()-2,xs.max()+3))
            out.append(dict(rgb=FF[sl],a=aa[sl],cell=(r_,c_),halo=halo_stats(FF[sl],aa[sl],MED)))
    return out
ROCKS=cut_rocks()
# map by size and shape (row, col on the sheet) -> kept ids
MAP={'crag_spire_a':(0,1),'crag_spire_b':(0,3),'crag_outcrop_a':(1,1),'crag_outcrop_b':(2,1),
     'crag_outcrop_c':(0,0),'crag_outcrop_d':(1,2),'crag_boulders_a':(0,2),'crag_boulders_b':(1,0),
     'crag_boulders_c':(1,3),'crag_boulders_d':(2,3),'crag_split_shrub':(2,2),'crag_cairn_flag':(2,0)}
BYCELL={o['cell']:o for o in ROCKS}
BIG={'crag_spire_a','crag_spire_b','crag_outcrop_a','crag_outcrop_b'}
TALL={'crag_cairn_flag'}
print('rock halos',[round(o['halo'][0],4) for o in ROCKS])
for i,(pid,cell) in enumerate(MAP.items()):
    o=BYCELL[cell]; rgb,a=o['rgb'],o['a']
    h,w=a.shape
    # base = widest opaque row in the lowest 30%
    best=None
    rows=np.nonzero((a>0.5).any(1))[0]; yb=rows.max()
    for r_ in range(int(yb-0.30*h),yb+1):
        c=np.nonzero(a[r_]>0.5)[0]
        if len(c) and (best is None or c.max()-c.min()>best[1]-best[0]): best=(c.min(),c.max(),r_)
    wb=best[1]-best[0]; scx=(best[0]+best[1])/2
    scy=yb-0.10*(yb-rows.min())*0.0-2      # sit the lowest rows on the anchor line (a hair inside)
    big=pid in BIG
    fp=(2,2) if big else (1,1)
    hr=yb-rows.min()
    s=(208.0 if big else 108.0)/wb
    if not big and pid not in TALL: s=min(s,96.0/hr,118.0/w)     # small rocks stay inside 128x128
    if pid in TALL: s=min(s,150.0/hr)
    rgb2,a3=scale_rgba(rgb,a,s)
    # plate grade: keep the painted warm grey, lift it a touch toward the plate stone / cliff white
    rgb2=grade(rgb2,sat=1.0,gain=1.06)
    rgb2=rock_grade(rgb2,0.35)
    if big: W,H=256,384; tcx,tcy=128,384-64+8
    else:
        W,H=128,128; tcx,tcy=64,96+8
        if (scy*s)>tcy-6 or pid in TALL: W,H=128,224; tcy=224-32+8
    # the base row lands ~8 px below the footprint centre line (front half of the cell), like the other kits
    ox=int(round(tcx-scx*s)); oy=int(round(tcy-scy*s))
    Cc,A,cl=paste(W,H,rgb2,a3,ox,oy)
    d=fp_poly_dist(W,H,fp); yyc=np.mgrid[0:H,0:W][0]
    A=np.where(yyc>tcy-10,A*smoothstep(4,-2,d),A)
    # soft contact AO under the base (alpha <= 0.3), like the eastmarch / southbridge kits
    Cc,A=add_ao(Cc,A,fp,W/2,tcy-2,(50 if not big else 100),(16 if not big else 30),st=0.26)
    Cc=final_despill(Cc,A)
    save_prop(pid,Cc,A,fp,'rock','prop','crag rock (v2 raw crag_props.jpg r%dc%d): warm grey, top dusting only, no skirt; soft contact AO baked (alpha<=0.3)'%(cell[0]+1,cell[1]+1),clipped=cl)
    META[pid]['height_steps_20px']=int(round(META[pid]['art_height_px_2x']/20.0))
    META[pid]['source']='v2/crag_props.jpg row %d col %d'%(cell[0]+1,cell[1]+1)
# ================= F) drifts (v2 raw: snow_drifts_iso.jpg, light drifts roughly on the iso axis) =================
DSH=loadv2('snow_drifts_iso.jpg')
DBG,DBGM,DMED=bg_model(DSH)
def cut_drifts():
    img=DSH; L=lum(img)
    a,F,obj,lbg=key_flood(img,DBG,DBGM,gthr=0.12,open_it=2,erode_px=1.0,min_size=300)
    obj=ndi.binary_fill_holes(ndi.binary_closing(obj,iterations=4))
    rg=ndi.gaussian_filter(L/np.maximum(lum(DBG),1e-3),1.2)
    g=np.hypot(ndi.sobel(rg,0),ndi.sobel(rg,1))/8.0*10; tex=ndi.maximum_filter(g,3)
    sat=img.max(-1)-img.min(-1)
    lab,n=ndi.label(obj); out=[]
    for k,sl in enumerate(ndi.find_objects(lab)):
        o=(lab==k+1)
        ys,xs=np.nonzero(o); y0,y1=ys.min(),ys.max()
        low=np.arange(img.shape[0])[:,None]>y0+0.55*(y1-y0)
        sh=low&(L<lum(lbg)-0.01)&(sat<0.03)&(tex<0.4)
        o=o&~sh; o=ndi.binary_opening(o,iterations=1); o=ndi.binary_fill_holes(o)
        l2,n2=ndi.label(o); sz=ndi.sum(o,l2,range(1,n2+1)); o=(l2==(int(np.argmax(sz))+1))
        aa,FF,_,_=finish_rim(img,o,lbg,erode_px=1.0)
        ys,xs=np.nonzero(aa>0.03)
        sl2=(slice(ys.min()-2,ys.max()+3),slice(xs.min()-2,xs.max()+3))
        out.append(dict(rgb=FF[sl2],a=aa[sl2],cx=float(xs.mean()),cy=float(ys.mean()),w=int(xs.max()-xs.min()),halo=halo_stats(FF[sl2],aa[sl2],DMED)))
    return out
DRS=cut_drifts()
for o in DRS:
    # the sheet paints snow as pale grey; lift it to snow white (shade stays cool, lit side ~0.96)
    c=o['rgb']; l=lum(c)[...,None]
    c=1-(1-c)*0.62
    o['rgb']=np.clip(c*np.array([0.995,0.997,1.0]),0,0.975)
def find(cx,cy): return min(DRS,key=lambda o:(o['cx']-cx)**2+(o['cy']-cy)**2)
SRC={'tl':find(240,180),'tc':find(640,175),'tr':find(1050,170),'ml':find(278,395),'mr':find(1000,375),'bl':find(285,610)}
print('drift halos',{k:round(v['halo'][0],4) for k,v in SRC.items()})
def axis_slope(a):
    ys,xs=np.nonzero(a>0.5); w=a[a>0.5]
    x=xs-xs.mean(); y=ys-ys.mean()
    cxx=(x*x).mean(); cxy=(x*y).mean(); cyy=(y*y).mean()
    ang=0.5*math.atan2(2*cxy,cxx-cyy)
    return math.tan(ang)
def vshear(rgb,a,k):
    """y' = y + k*(x - w/2) (shear_rgba)"""
    return shear_rgba(rgb,a,k)
def iso_long(o, length, thick, flip=False):
    rgb,a=o['rgb'].copy(),o['a'].copy()
    if flip: rgb,a=rgb[:,::-1],a[:,::-1]
    m=axis_slope(a)
    rgb,a=vshear(rgb,a,0.5-m)
    rgb,a=crop_bbox(rgb,a,th=0.05)
    m2=axis_slope(a)
    xs=np.nonzero((a>0.5).any(0))[0]; ext=xs.max()-xs.min()
    s=length/ext
    # vertical thickness after removing the 2:1 slope
    h,w=a.shape
    cols=[(a[:,x]>0.5).sum() for x in range(w) if (a[:,x]>0.5).any()]
    T=np.median(cols)
    sy=min(s,thick/max(T,1))
    rgb,a=scale_rgba(rgb,a,s,sy)
    return rgb,a,m,m2
for pid,src,typ,flip in [('drift_wall_long_a','tl','wall',True),('drift_wall_long_b','tr','wall',False),('drift_wall_long_c','tc','wall',False),
                         ('drift_fence_a','tl','fence',True),('drift_tree_ring_a','mr','ring',False),('drift_tree_ring_b','ml','ring',True),
                         ('drift_patch_a','ml','patch',False),('drift_patch_b','bl','patch',False)]:
    o=SRC[src]
    if typ in ('wall','fence'):
        if typ=='wall': fp=(2,1); W,H=192,160; L_,T_=124,22; cxp,cyp=66,113+3; Hc,Df=14,14
        else:           fp=(1,1); W,H=128,128; L_,T_=66,16; cxp,cyp=64,96+3; Hc,Df=10,10
        rgb,a,m0,m1=iso_long(o,L_,T_,flip)
        h,w=a.shape
        ys,xs=np.nonzero(a>0.3); cx_,cy_=xs.mean(),ys.mean()
        ox=int(round(cxp-cx_)); oy=int(round(cyp-cy_))
        Cc,A,cl=paste(W,H,rgb,a,ox,oy)
        yyc,xxc=np.mgrid[0:H,0:W]+0.5
        x0_=ox+xs.min(); x1_=ox+xs.max()
        t=np.clip((xxc-x0_)/max(x1_-x0_,1),0,1)
        endt=np.sin(np.pi*t)**0.45
        A=A*(0.55+0.45*endt)                     # faded far tails (light dusting)
        tcx,tcy=W/2,H-32
        extra=dict(axis='+x (flip_h for +y)',slope='2:1 iso (sheared from %.2f to 0.50)'%(-m0 if flip else m0),crest_px_2x=Hc,front_px_2x=Df,
                   source='v2/snow_drifts_iso.jpg top row '+{'tl':'left','tc':'middle','tr':'right'}[src])
    else:
        fp=(1,1); W,H=128,128; tcx,tcy=64,96
        tw=96 if typ=='ring' else 84
        rgb,a=o['rgb'],o['a']
        if flip: rgb,a=rgb[:,::-1],a[:,::-1]
        s_=tw/o['w']; sy=s_*(0.62 if src=='bl' else 0.85)
        rgb,a=scale_rgba(rgb,a,s_,sy)
        h,w=a.shape; ys,xs=np.nonzero(a>0.3); cx_,cy_=xs.mean(),ys.mean()
        ox=int(round(tcx-cx_)); oy=int(round(tcy-cy_))
        Cc,A,cl=paste(W,H,rgb,a,ox,oy)
        yq,xq=np.mgrid[0:H,0:W]+0.5
        rr=np.sqrt(((xq-tcx)/(tw/2))**2+((yq-tcy)/(tw/4))**2)
        A=A*(1-0.5*smoothstep(0.35,1.0,rr))        # radial outer fade (~0.5 at the rim)
        extra=dict(axis='none',source='v2/snow_drifts_iso.jpg '+{'mr':'row 2 right (flat oval)','ml':'row 2 left (flat patch)','bl':'row 3 left (flattened 0.62)'}[src])
        if typ=='ring':
            extra['hole_px_2x']=[0,-32]
            extra['use']='under a tree on the same cell, drawn before it: the trunk base covers the centre (offset from anchor given)'
    d=fp_poly_dist(W,H,fp)
    yyc,xxc=np.mgrid[0:H,0:W]+0.5
    slope=0.5 if typ in ('wall','fence') else 0.0
    front=yyc>tcy+slope*(xxc-tcx)-2
    A=np.where(front,A*smoothstep(7,1,d),A)
    Cc=final_despill(Cc,A)
    note={'wall':'light snow along the base of a wall, 2 cells along +x; draw after the ground, before the wall',
          'fence':'light snow along a fence run, 1 cell along +x; draw after the ground, before the fence',
          'ring':'light drift at a tree base; draw after the ground, before the tree',
          'patch':'loose flat drift patch on ground'}[typ]
    save_prop(pid,Cc,A,fp,'drift','ground_overlay',note,extra=extra,clipped=cl)
json.dump(META,open('tmp/props_meta.json','w'),indent=1)
print(len(META),'props')
