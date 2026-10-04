"""F) snow drift overlays + H) crag props -> props/ (1x) + props/_2x/ (world layout); writes tmp/props_meta.json"""
from ngc import *
import pickle
C=pickle.load(open('tmp/cuts.pkl','rb'))
META={}
AO_COL=np.array([0.10,0.10,0.16])
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
# ================= H) crag props =================
NAMES=['crag_spire_a','crag_outcrop_a','crag_outcrop_b','crag_spire_b',
       'crag_boulders_a','crag_boulders_b','crag_outcrop_c','crag_boulders_c',
       'crag_boulders_d','crag_split_shrub','crag_outcrop_d','crag_cairn_flag']
BIG={'crag_spire_a','crag_spire_b','crag_outcrop_a','crag_outcrop_b'}
for i,(o,pid) in enumerate(zip(C['props'],NAMES)):
    rgb,a=crop_bbox(o['rgb'],o['a'],pad=0)
    h,w=a.shape
    # skirt = widest opaque row in the lowest 30%
    rows=np.nonzero((a>0.5).any(1))[0]; yb=rows.max()
    best=None
    for r_ in range(int(yb-0.30*h),yb+1):
        c=np.nonzero(a[r_]>0.5)[0]
        if len(c) and (best is None or c.max()-c.min()>best[1]-best[0]): best=(c.min(),c.max(),r_)
    wb=best[1]-best[0]; scx=(best[0]+best[1])/2; scy=best[2]
    # rock vs snow
    sn=snowlike(rgb); rock=(sn<0.5)&(a>0.5)
    near=ndi.gaussian_filter(ndi.binary_dilation(rock,iterations=int(0.035*wb)+2).astype(float),2.0)
    yy,xx=np.mgrid[0:h,0:w]
    rr=np.sqrt(((xx-scx)/(wb/2))**2+((yy-scy)/(wb/4.2))**2)
    nz=smooth_noise((h,w),max(3,wb/40),100+i,periodic=False)
    nz=(nz-nz.mean())/nz.std()
    fade=smoothstep(0.92,0.50,rr+0.10*nz)
    low=smoothstep(scy-0.32*wb/2,scy-0.05*wb/2,yy)       # only the skirt zone (around/below the base line)
    keep=np.maximum(np.maximum(fade,near),1-low)
    a2=a*np.clip(keep,0,1)
    big=pid in BIG
    fp=(2,2) if big else (1,1)
    s=(212.0 if big else 112.0)/wb
    rgb2,a3=scale_rgba(final_despill(rgb,a2),a2,s)
    rgb2=grade(rgb2,sat=1.05,gain=1.02)
    rgb2=rock_grade(rgb2,0.85)      # direction update: warm grey / cliff white granite, snow untouched
    if big: W,H=256,384; tcx,tcy=128,384-64
    else:
        W,H=128,128; tcx,tcy=64,96
        top=tcy-scy*s
        if top<6: W,H=128,224; tcy=224-32
    ox=int(round(tcx-scx*s)); oy=int(round(tcy-scy*s))
    Cc,A,cl=paste(W,H,rgb2,a3,ox,oy)
    # trim anything that leaked outside the footprint at ground level (front half)
    d=fp_poly_dist(W,H,fp); yyc=np.mgrid[0:H,0:W][0]
    A=np.where(yyc>tcy-8,A*smoothstep(4,-2,d),A)
    Cc,A=add_ao(Cc,A,fp,tcx,tcy+2,(46 if not big else 92),(16 if not big else 32))
    Cc=final_despill(Cc,A)
    kindp='rock'
    save_prop(pid,Cc,A,fp,kindp,'prop','crag rock, snow skirt faded inside the footprint; contact AO baked (alpha<=0.3)',
              extra=dict(blocks='cover' if not big else 'los',height_steps=round((META.get(pid,{}).get('art_height_px_2x',0))/20) if False else None),clipped=cl)
    META[pid]['height_steps_20px']=int(round(META[pid]['art_height_px_2x']/20.0)); META[pid].pop('height_steps',None)
# ================= F) drifts =================
D=C['drifts']
# explicit reading order by sheet position
order=sorted(range(len(D)),key=lambda k:(int(D[k]['y']/160),D[k]['x']))
D=[D[k] for k in order]
print('drift order',[(d['x'],d['y']) for d in D])
DR=[('drift_wall_long_a',0,'wall'),('drift_wall_long_b',1,'wall'),('drift_wall_long_c',3,'wall'),('drift_fence_a',2,'fence'),
    ('drift_tree_ring_a',4,'ring'),('drift_tree_ring_b',5,'ring'),('drift_patch_a',6,'patch'),('drift_patch_b',7,'patch')]
def base_slope(a):
    xs=[];ys=[]
    for x in range(a.shape[1]):
        c=np.nonzero(a[:,x]>0.5)[0]
        if len(c): xs.append(x); ys.append(c.max())
    xs=np.array(xs); ys=np.array(ys)
    m=(xs>np.percentile(xs,15))&(xs<np.percentile(xs,85))
    return np.polyfit(xs[m],ys[m],1)[0]
for pid,k,typ in DR:
    o=D[k]; rgb,a=crop_bbox(o['rgb'],o['a'])
    rgb=final_despill(rgb,a)
    if typ in ('wall','fence'):
        # warp the painted drift onto the iso +x axis: per column its painted crest..foot span is mapped onto a mound
        # whose foot runs along the 2:1 line (in front of the wall/fence) and whose crest rises over the line
        if typ=='wall':
            fp=(2,1); W,H=192,160; xs,xe=4,132; yc0,xc0=128,96; Hc,Df=14,14
        else:
            fp=(1,1); W,H=128,128; xs,xe=26,100; yc0,xc0=96,64; Hc,Df=10,10
        hcol=(a>0.5).sum(0).astype(np.float32)
        good=np.nonzero(hcol>0.30*hcol.max())[0]; c0,c1=good.min(),good.max()
        crest=np.array([np.nonzero(a[:,x]>0.5)[0].min() if hcol[x]>0 else 0 for x in range(a.shape[1])],np.float32)
        foot=np.array([np.nonzero(a[:,x]>0.5)[0].max() if hcol[x]>0 else 0 for x in range(a.shape[1])],np.float32)
        crest=ndi.gaussian_filter1d(crest,3); foot=ndi.gaussian_filter1d(foot,6)
        hn=ndi.gaussian_filter1d(hcol,4)/max(hcol.max(),1)
        yyc,xxc=np.mgrid[0:H,0:W].astype(np.float32)
        t=(xxc+0.5-xs)/(xe-xs)
        xr=c0+np.clip(t,-0.08,1.08)*(c1-c0)
        xri=np.clip(xr,0,a.shape[1]-1.001)
        def at(arr1d): 
            i0=np.floor(xri).astype(int); f=xri-i0; i1=np.minimum(i0+1,len(arr1d)-1); return arr1d[i0]*(1-f)+arr1d[i1]*f
        endt=np.maximum(np.sin(np.pi*np.clip(t,0,1)),0)**0.45
        e=np.clip((0.35+0.65*at(hn))*endt,0,1)
        yc=yc0+0.5*(xxc+0.5-xc0)
        relx=xxc+0.5-W/2
        allowed=np.where(relx>0,32-relx,32.0)-2.0          # px from the centreline to the footprint's front edge
        ytop=yc-Hc*e-1.5; ybot=yc+np.clip(np.minimum(Df*np.sqrt(np.clip(endt,0,1)),allowed),2.0,None)+1.0
        q=(yyc+0.5-ytop)/np.maximum(ybot-ytop,1.0)
        cr=at(crest); fo=at(foot)
        yr=cr+q*(fo-cr)
        smp=bilinear(np.concatenate([rgb*a[...,None],a[...,None]],2),xri-0.5,np.clip(yr,0,a.shape[0]-1.001))
        inside=(t>-0.08)&(t<1.08)&(q>-0.6)&(q<1.4)
        Aw=np.clip(smp[...,3],0,1)*inside*smoothstep(-0.07,0.01,t)*smoothstep(1.03,0.96,t)
        Aw=Aw*(0.55+0.45*endt)          # direction update: far tails fade (light dusting)
        Cw=np.where(Aw[...,None]>1e-4,smp[...,:3]/np.maximum(smp[...,3:4],1e-4),0)
        Cc,A,cl=Cw,Aw,False
        rgb,a=None,None
        tcx,tcy=xc0,yc0
        extra=dict(axis='+x (flip_h for +y)',slope='2:1 iso',crest_px_2x=Hc,front_px_2x=Df)
    else:
        fp=(1,1); W,H=128,128; tcx,tcy=64,96
        tw=96 if typ=='ring' else 84
        s=tw/a.shape[1]; sy=s*(1.45 if typ=='ring' else 1.2)
        rgb,a=scale_rgba(rgb,a,s,sy)
        extra=dict(axis='none')
    if rgb is not None:
        h,w=a.shape
        yy,xx=np.mgrid[0:h,0:w]
        if typ=='ring':
            hole=(a<0.3)&ndi.binary_fill_holes(a>0.3)
            if hole.sum()>10: cy_,cx_=np.argwhere(hole).mean(0)
            else: cy_,cx_=h*0.55,w/2
        else:
            wl=a*(yy>h*0.4)
            cy_=(wl*yy).sum()/wl.sum(); cx_=(wl*xx).sum()/wl.sum()
        ox=int(round(tcx-cx_)); oy=int(round(tcy-cy_))
        Cc,A,cl=paste(W,H,rgb,a,ox,oy)
        # direction update: radial outer fade to ~0.5 so the rim reads as a dusting, not a bank
        yq,xq=np.mgrid[0:H,0:W]+0.5
        rr=np.sqrt(((xq-tcx)/(tw/2))**2+((yq-tcy)/(tw/4))**2)
        A=A*(1-0.5*smoothstep(0.35,1.0,rr))
    else:
        ox=oy=0; cx_=tcx; cy_=tcy
    d=fp_poly_dist(W,H,fp)
    yyc,xxc=np.mgrid[0:H,0:W]+0.5
    slope=0.5 if typ in ('wall','fence') else 0.0
    front=yyc>tcy+slope*(xxc-tcx)-2          # only the ground-contact (front) half is held to the footprint
    A=np.where(front,A*smoothstep(7,1,d),A)
    Cc=final_despill(Cc,A)
    if typ=='ring':
        extra['hole_px_2x']=[int(round(cx_+ox-W/2)),int(round(cy_+oy-H))]
        extra['use']='under a tree on the same cell: tree trunk base sits in the hole (hole offset from anchor given)'
    note={'wall':'snow banked along the base of a wall, 2 cells along +x; draw after the ground, before the wall',
          'fence':'snow along a fence run, 1 cell along +x; draw after the ground, before the fence',
          'ring':'ring drift at a tree base; draw after the ground, before the tree',
          'patch':'loose drift patch on ground'}[typ]
    save_prop(pid,Cc,A,fp,'drift','ground_overlay',note,extra=extra,clipped=cl)
json.dump(META,open('tmp/props_meta.json','w'),indent=1)
print(len(META),'props')
