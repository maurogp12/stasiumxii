"""E) ice overlays for water cells: water_ice_edge_{nw,ne,se,sw}, water_ice_corner_{n,e,s,w}, water_ice_a/b.
All pieces share one uv-periodic plate field, so overlaps and joins between cells are consistent."""
from build_tiles_helpers import *
from scipy.spatial import cKDTree
raw=load('ice_edge_water.jpg')
# ---- v2 raw: clear blue water with a painted ice-plate field. Made seamless (offset + heal), it drives the plate
# colour, the painted inner cracks / grain, the channel (crack) blue and the outer-shadow blue; floes are cut from it.
RAW2=np.asarray(Image.open(RAW+'v2/ice_water.jpg').convert('RGB'),dtype=np.float32)/255.0
def _seamless(img,ov=96):
    h,w,_=img.shape
    a=periodic_strip(img,0,w-ov,ov)
    return np.ascontiguousarray(periodic_strip(np.ascontiguousarray(a.transpose(1,0,2)),0,h-ov,ov).transpose(1,0,2))
RAW2S=_seamless(RAW2)
Image.fromarray((RAW2S*255).astype(np.uint8)).save(B+'tmp/v2/ice_water_seamless.png')
_L2=lum(RAW2S); _sat2=RAW2S.max(-1)-RAW2S.min(-1)
PLATE2=ndi.binary_opening(ndi.binary_fill_holes((_L2>0.80)&(RAW2S[...,0]>0.70)),iterations=3)
WATER2=(RAW2S[...,2]-RAW2S[...,0]>0.25)&~ndi.binary_dilation(PLATE2,iterations=2)
PC2=np.median(RAW2S[PLATE2],0); WC2=np.median(RAW2S[WATER2],0); WD2=np.percentile(RAW2S[WATER2],15,axis=0)
print('v2 ice: plate',np.round(PC2*255),'water',np.round(WC2*255),'deep',np.round(WD2*255))
r=rng(77)
NS=34
seeds=r.uniform(0,1,(NS,2))
rep=np.concatenate([seeds+np.array([i,j]) for i in (-1,0,1) for j in (-1,0,1)])
sid=np.tile(np.arange(NS),9)
def scr(u,v): return np.stack([(u-v)*64.0,(u+v)*32.0],-1)
tree=cKDTree(scr(rep[:,0],rep[:,1]))
Uw=np.mod(U,1); Vw=np.mod(V,1)
P=scr(Uw,Vw).reshape(-1,2)
dd,ii=tree.query(P,k=2)
F1=dd[:,0].reshape(U.shape); F2=dd[:,1].reshape(U.shape)
NEAR=sid[ii[:,0]].reshape(U.shape)
SEEDU=rep[ii[:,0],0].reshape(U.shape)-np.floor(U)*0+ (np.floor(U))   # seed in this tile's unwrapped frame
SEEDV=rep[ii[:,0],1].reshape(U.shape)+np.floor(V)
SEEDU=rep[ii[:,0],0].reshape(U.shape)+np.floor(U)
crack=F2-F1                                  # screen px (2x) to the plate border
# ---- plate colour field (periodic) ----
tone=r.uniform(-1,1,NS)
pc=PC2*0.96+np.array([0.0,0.0,0.01])   # v2: painted plate colour (pale lake blue)
# per-plate shading: lit toward upper-left of the plate
sx=scr(SEEDU,SEEDV); px=scr(U,V)
off=px-sx
lit=np.clip(-(off[...,0]*0.5+off[...,1]*0.9)/14.0,-1,1)
grain_src=make_periodic(src_sampler(RAW2S,(640,360),1.25),R)
g=grain_src-ndi.gaussian_filter(grain_src,(3,3,0),mode='wrap')
gs=sample_uv(g,Uw,Vw)
col=pc[None,None,:]+0.035*tone[NEAR][...,None]+0.03*lit[...,None]*np.array([1,0.8,0.6])+gs*0.75
cl=smoothstep(2.2,0.4,crack)       # crack line
hl=smoothstep(4.5,2.2,crack)*(1-cl)   # bright bevel next to the crack
col=col*(1-hl[...,None]*0.5)+np.array([0.93,0.97,1.0])*hl[...,None]*0.5
col=col*(1-cl[...,None])+WC2*cl[...,None]          # channel blue from the raw
ICE=np.clip(col,0,1)
SNOW_C=np.array([0.95,0.96,0.99])
def taper(t): return smoothstep(0.06,0.25,t)*smoothstep(0.94,0.75,t)
def n1(t,seed,amp):
    q=rng(seed); out=np.zeros_like(t)
    for f,a in ((1.3,0.5),(2.9,0.3),(6.1,0.2)): out+=amp*a*np.sin(2*np.pi*f*t+q.uniform(0,6.28))
    return out
SIDES={'ne':(lambda u,v: v, lambda u,v: u),'nw':(lambda u,v: u, lambda u,v: v),
       'se':(lambda u,v: 1-u, lambda u,v: v),'sw':(lambda u,v: 1-v, lambda u,v: u)}
W0=0.26; MID=0.36
HARD=HARD_SS
def make_piece(name, inc_pix, dist_land, seed):
    """inc_pix: bool plate inclusion (by seed) at SS; dist_land: uv distance to the land side (for snow rim)"""
    inc=inc_pix.astype(np.float32)
    # soften the plate-border cut by the crack width
    a_ice=np.clip(inc,0,1)
    a_ice=ndi.gaussian_filter(a_ice,0.8)
    # outer shadow + foam just beyond the ice
    outside=1-inc
    dist_out=ndi.distance_transform_edt(outside)/SS     # 2x px from the ice
    shadow=np.clip(1-dist_out/6.0,0,1)**1.5*0.38*outside
    foam_n=smooth_noise(U.shape,2.0,seed)
    foam=(dist_out<3.2)*(foam_n>0.6)*outside*0.85
    # snow rim on the land side, wavy
    nz=smooth_noise(U.shape,10,seed+1)*0.03+smooth_noise(U.shape,3,seed+2)*0.012
    snow=smoothstep(0.11,0.07,dist_land+nz)*inc
    rgb=ICE*(1-snow[...,None])+SNOW_C*snow[...,None]
    # snow casts a little shade on the ice just outside it
    sh2=np.clip(ndi.gaussian_filter(snow,3)-snow,0,1)*0.6*inc
    rgb=rgb*(1-0.18*sh2[...,None])
    a=np.clip(a_ice+shadow+foam,0,1)*HARD
    dark=WD2*0.55                                     # outer shadow: deep channel blue from the raw
    rgb=np.where(a_ice[...,None]>0.5,rgb,0)
    wsum=a_ice+shadow+foam+1e-6
    rgb=(rgb*a_ice[...,None]+dark*shadow[...,None]+np.array([0.95,0.96,0.98])*foam[...,None])/wsum[...,None]
    finish_decal(rgb,a,'tiles',name,clip=False); return name
seedd=np.stack([SEEDU,SEEDV],-1)
made=[]
for i,(s,(df,tf)) in enumerate(SIDES.items()):
    ds=df(SEEDU,SEEDV); ts=np.clip(tf(SEEDU,SEEDV),0,1)
    w=W0+taper(ts)*((MID-W0)+n1(ts,900+i,0.10))
    inc=ds<w
    made.append(make_piece('water_ice_edge_'+s, inc, df(U,V), 910+i)); 
CORN={'n':(0,0),'e':(1,0),'s':(1,1),'w':(0,1)}
for i,(c,(cu,cv)) in enumerate(CORN.items()):
    def pol(u,v):
        du=np.abs(u-cu); dv=np.abs(v-cv)
        return np.sqrt(du**2+dv**2), np.arctan2(dv,du)/(np.pi/2)
    dist,ang=pol(SEEDU,SEEDV)
    rr=W0+taper(np.clip(ang,0,1))*(0.05+n1(np.clip(ang,0,1),950+i,0.05))
    inc=dist<rr
    dpx,_=pol(U,V)
    made.append(make_piece('water_ice_corner_'+c, inc, dpx, 960+i))
# ---- floes: whole painted plates cut from the v2 raw (keyed against the channel blue) ----
lab,n=ndi.label(PLATE2)
fl=[]
H2,W2=PLATE2.shape
for k,sl in enumerate(ndi.find_objects(lab)):
    hh=sl[0].stop-sl[0].start; ww=sl[1].stop-sl[1].start
    if sl[0].start<4 or sl[1].start<4 or sl[0].stop>H2-4 or sl[1].stop>W2-4: continue
    if ww<80 or hh<60 or ww>260: continue
    y0=sl[0].start-4; y1=sl[0].stop+4; x0=sl[1].start-4; x1=sl[1].stop+4
    m=(lab[y0:y1,x0:x1]==k+1)
    a=ndi.gaussian_filter(m.astype(np.float32),1.2)
    a=np.clip((a-0.2)/0.6,0,1)
    reg=RAW2S[y0:y1,x0:x1]
    aa=np.maximum(a,0.2)[...,None]
    F=np.clip((reg-(1-a[...,None])*WC2)/aa,0,1)
    F=np.where(a[...,None]<0.6,np.maximum(F,PC2*0.98),F)        # rim: no blue fringe
    fl.append((F,a,ww))
print('floes',len(fl))
fl.sort(key=lambda f:-f[2])
def place_floes(name, picks, seed):
    q=rng(seed)
    H,W=64,128
    rgb=np.zeros((H,W,3)); A=np.zeros((H,W))
    for (fi,cx,cy,sc) in picks:
        F,a,_=fl[fi%len(fl)]
        F_w=F.shape[1]; Fs,As=scale_rgba(F,a,sc*34.0/F_w,sc*34.0/F_w*0.62)
        # contact shadow (water darkens under the floe, offset down-right)
        h_,w_=As.shape; x0=int(cx-w_/2); y0=int(cy-h_/2)
        shp=np.zeros((H,W)); 
        for (img,al,dx,dy,isr) in ((None,As*0.35,1,2,False),(Fs,As,0,0,True)):
            ys=slice(max(y0+dy,0),min(y0+dy+h_,H)); xs=slice(max(x0+dx,0),min(x0+dx+w_,W))
            sy=slice(ys.start-(y0+dy),ys.stop-(y0+dy)); sx=slice(xs.start-(x0+dx),xs.stop-(x0+dx))
            src=(WD2*0.5)[None,None,:]*np.ones_like(Fs) if not isr else Fs
            rgb[ys,xs],A[ys,xs]=over(rgb[ys,xs],A[ys,xs],src[sy,sx],al[sy,sx])
    A=A*HARD2
    arr=to_rgba8(rgb,A); save_world(arr,'tiles',name); return name
made.append(place_floes('water_ice_a',[(0,46,28,0.55),(3,78,36,0.5),(5,62,46,0.45),(1,88,22,0.4)],1))
made.append(place_floes('water_ice_b',[(2,40,34,0.5),(4,70,24,0.55),(6,84,40,0.45),(7,58,44,0.4),(8,96,30,0.35)],2))
json.dump(made,open('tmp/ice_ids.json','w'))
print(made)
