"""B) transition tiles in the world autotile grammar:
   frost_grass_edge_<sides> / frost_grass_corner_<c>  (frost_grass family, golden_plains on the named side)
   snow_edge_<sides> / snow_corner_<c>                  (snow family, frost_grass on the named side)
   crag_edge_<sides> / crag_corner_<c>                  (crag top family, clean snow cornice on the named side)"""
from build_tiles_helpers import *
import itertools
T=np.load('tmp/tex.npz')
gold=np.asarray(Image.open(REPO+'tiles/_2x/golden_plains_a.png').convert('RGB'),dtype=np.float32)/255.
frost=render_uv(T['frost_a']); snow=render_uv(T['snow_a'])
crag_imgs={k:np.asarray(Image.open(SHIP+'tiles/_2x/'+k+'.png').convert('RGB'),dtype=np.float32)/255. for k in ('crag_a','crag_b','crag_c')}
SIDES={'ne':(lambda u,v: v, lambda u,v: u),'nw':(lambda u,v: u, lambda u,v: v),
       'se':(lambda u,v: 1-u, lambda u,v: v),'sw':(lambda u,v: 1-v, lambda u,v: u)}
CORN={'n':(0,0),'e':(1,0),'s':(1,1),'w':(0,1)}
COMBOS=[]
for n in range(1,5):
    for c in itertools.combinations(['nw','ne','se','sw'],n): COMBOS.append(list(c))
def noise1d(t,seed,freqs):
    r=rng(seed); out=np.zeros_like(t)
    for f,a in freqs:
        out+=a*np.sin(2*np.pi*f*t+r.uniform(0,2*np.pi))
    return out
def warp2d(seed,amp,scale):
    n=smooth_noise(U.shape,scale,seed); return n*amp
def side_d(side,seed,W0,mid,amp):
    df,tf=SIDES[side]; d=df(U,V); t=tf(U,V)
    taper=np.sin(np.pi*np.clip(t,0,1))**0.8
    w=W0+taper*((mid-W0)+noise1d(t,seed,[(1.3,amp*0.45),(2.7,amp*0.35),(5.9,amp*0.25),(11.3,amp*0.12)]))
    # domain warp for an organic (not 1-D) boundary, zero at the band ends
    d=d+taper*warp2d(seed+50,0.018,10)+taper*warp2d(seed+51,0.008,3.5)
    return d-w            # <0 inside the neighbour band
def corner_d(c,seed,W0,bulge,amp):
    cu,cv=CORN[c]; du=np.abs(U-cu); dv=np.abs(V-cv)
    dist=np.sqrt(du**2+dv**2); ang=np.arctan2(dv,du)/(np.pi/2)   # 0..1 between the two seam lines
    taper=np.sin(np.pi*np.clip(ang,0,1))**0.8
    rr=W0+taper*(bulge+noise1d(ang,seed,[(1.5,amp*0.5),(3.1,amp*0.3),(6.3,amp*0.2)]))
    dist=dist+taper*warp2d(seed+60,0.014,8)*np.clip(dist/0.2,0,1)
    return dist-rr
def cov(sd,soft=0.006):
    """signed distance (<0 inside) at SS -> coverage at 2x"""
    a=smoothstep(soft,-soft,sd)
    return down(a[...,None])[...,0], a
def clumps(seed, sd, n, rmin, rmax, band=(0.0,0.08), sy=0.5):
    """small blobs scattered on the far side of a boundary, in screen space (iso-flattened)"""
    r=rng(seed); H,W=U.shape
    yy,xx=np.mgrid[0:H,0:W].astype(np.float32)/SS
    out=np.zeros((H,W),np.float32)
    cand=np.argwhere((sd>band[0])&(sd<band[1]))
    if len(cand)==0: return out
    for i in range(n):
        y,x=cand[r.integers(len(cand))]/SS
        rad=r.uniform(rmin,rmax)
        d=np.sqrt(((xx-x)/rad)**2+((yy-y)/(rad*sy))**2)
        d=d+0.25*smooth_noise((H,W),3,seed*7+i)
        out=np.maximum(out,smoothstep(1.0,0.8,d))
    return out
SIDE_SEEDS={'nw':1,'ne':2,'se':3,'sw':4}
def make_family(fam, base_rgb, nb_rgb, kind, W0, mid, amp, seed0, decor):
    """fam: id prefix; base_rgb: the family's own texture (2x); nb_rgb: neighbour texture (2x) on the named side"""
    made=[]
    for combo in COMBOS:
        sd=np.min([side_d(s,seed0+SIDE_SEEDS[s],W0,mid,amp) for s in combo],axis=0)
        made.append(compose(fam+'_edge_'+'_'.join(combo), sd, base_rgb, nb_rgb, decor, seed0+len(made)*13, floor=True, nsides=combo))
    for i,c in enumerate(['n','e','s','w']):
        sd=corner_d(c,seed0+30+i,W0,0.06,amp*0.7)
        made.append(compose(fam+'_corner_'+c, sd, base_rgb, nb_rgb, decor, seed0+200+i, floor=False))
    return made
def compose(name, sd, base_rgb, nb_rgb, decor, seed, floor=True, nsides=None):
    c2,c_ss=cov(sd)
    ex=decor(seed, sd, c2, base_rgb, nb_rgb)
    rgb,a_nb=ex
    if floor:
        finish(rgb, 'tiles', name)
    else:
        # corner decal: neighbour texture only where the bump is (alpha), drawn over the family floor
        A=np.clip(a_nb,0,1)*ALPHA
        arr=to_rgba8(rgb,A); save_world(arr,'tiles',name)
    return name

# ---------- decor painters ----------
def decor_frost_gold(seed, sd, c2, base, nb):
    """golden grass band into frost grass: grass clumps reach into the frost, frost speckles sit on the grass rim,
       a thin darker root line where the taller golden grass meets the frost"""
    g_cl=clumps(seed+1, sd, 9, 2.0, 4.5, band=(0.004,0.07))
    f_cl=clumps(seed+2, -sd, 10, 1.6, 3.6, band=(0.006,0.08))
    gc=down(g_cl[...,None])[...,0]; fc=down(f_cl[...,None])[...,0]
    a_nb=np.clip(np.maximum(c2,gc)-fc*0.85,0,1)
    # root shade: just outside the golden boundary on the frost side, cast down-right
    edge=np.clip(1-np.abs(down(sd[...,None])[...,0])/0.03,0,1)
    shade=edge*(1-a_nb)*0.18
    rgb=base*(1-shade[...,None])
    rgb=rgb*(1-a_nb[...,None])+nb*a_nb[...,None]
    # frost glitter on the golden rim (cool white flecks)
    return np.clip(rgb,0,1), a_nb
def decor_snow_frost(seed, sd, c2, base, nb):
    """frost grass on the named side of a snow cell: lumpy snow edge with a lavender lee shadow,
       grass tufts poking through the snow, snow clumps lying on the frost grass"""
    n_cl=clumps(seed+3, sd, 12, 1.5, 3.5, band=(0.004,0.07))           # grass tufts poking through near the edge
    s_cl=clumps(seed+4, -sd, 11, 1.8, 4.2, band=(0.006,0.09))          # snow clumps on the frost side
    nc=down(n_cl[...,None])[...,0]; sc=down(s_cl[...,None])[...,0]
    a_nb=np.clip(np.maximum(c2,nc*0.9)-sc,0,1)
    snowm=1-a_nb
    # snow thickness: highlight on the upper-left rim of the snow edge, lavender shadow just inside the lower-right rim
    sm=ndi.gaussian_filter(snowm,1.2)
    gy=np.gradient(sm,axis=0); gx=np.gradient(sm,axis=1)
    lit=np.clip((gy*0.8+gx*0.5)*3.0,0,1)*snowm
    dark=np.clip(-(gy*0.8+gx*0.5)*3.0,0,1)
    rgb=base.copy()
    rgb=rgb*(1-0.10*dark[...,None])+np.array([0.62,0.64,0.86])*0.10*dark[...,None]
    rgb=np.clip(rgb+0.05*lit[...,None],0,1)
    # the frost grass right at the snow line is shaded (snow wall)
    shade=np.clip(dark*1.4,0,1)*a_nb*0.25
    nbs=nb*(1-shade[...,None])
    rgb=rgb*(1-a_nb[...,None])+nbs*a_nb[...,None]
    return np.clip(rgb,0,1), a_nb
def decor_crag_snow(seed, sd, c2, base, nb):
    """wind cornice on the named (cliff) side of a crag-top cell: a slightly raised bright snow lip with a soft
       lavender lee shadow on the inner side; no hard line"""
    s_cl=clumps(seed+5, -sd, 7, 2.0, 4.6, band=(0.008,0.10))
    sc=down(s_cl[...,None])[...,0]
    a_nb=np.clip(np.maximum(c2,sc*0.95),0,1)
    sm=ndi.gaussian_filter(a_nb,1.6)
    shade=np.clip(sm-a_nb,0,1)*2.2                  # just inside the lip
    shade=ndi.gaussian_filter(shade,1.2)
    lav=np.array([0.70,0.72,0.92])
    rgb=base*(1-0.16*shade[...,None])+lav*0.16*shade[...,None]
    gy=np.gradient(sm,axis=0); gx=np.gradient(sm,axis=1)
    lit=np.clip((gy*0.8+gx*0.5)*2.5,0,1)
    snowc=np.clip(nb*1.02+0.05*lit[...,None],0,0.99)
    rgb=rgb*(1-a_nb[...,None])+snowc*a_nb[...,None]
    return np.clip(rgb,0,1), a_nb


made=[]
made+=make_family('frost_grass', frost, gold, 'tiles', 0.21, 0.28, 0.10, 1000, decor_frost_gold)
made+=make_family('snow', snow, frost, 'tiles', 0.20, 0.28, 0.10, 2000, decor_snow_frost)
made+=make_family('crag', render_uv(T['snow_b']), snow, 'tiles', 0.16, 0.22, 0.06, 3000, decor_crag_snow)
json.dump(made,open('tmp/trans_ids.json','w'))
print(len(made),'transition tiles')
