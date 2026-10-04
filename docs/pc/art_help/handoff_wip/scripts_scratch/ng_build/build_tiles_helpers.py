from ngc import *
U,V=tile_uv()
ALPHA,MASK=diamond_alpha()
uR=(np.arange(R)+0.5)/R; UU,VV=np.meshgrid(uR,uR)
DE=np.minimum.reduce([UU,1-UU,VV,1-VV])
MINT=smoothstep(0.09,0.24,DE)
def uv_to_screen(u,v): return (u-v)*64.0,(u+v)*32.0
def src_sampler(src, origin, k, flip=False, rot=0.0):
    ca,sa=math.cos(rot),math.sin(rot)
    def f(u,v):
        x,y=uv_to_screen(u,v)
        if flip: x=-x
        xr=x*ca-y*sa; yr=x*sa+y*ca
        return bilinear(src, origin[0]+xr*k, origin[1]+yr*k)
    return f
def render_uv(S):
    """uv texture (R,R,3) -> 128x64 rgb (supersampled)"""
    return down(sample_uv(S,np.mod(U,1),np.mod(V,1)))
def var_blend(base, var, m):
    mean=base.reshape(-1,3).mean(0)
    w0=(1-m)[...,None]; w1=m[...,None]
    den=np.sqrt(w0**2+w1**2)
    return np.clip(mean+(w0*(base-mean)+w1*(var-mean))/den,0,1)
def finish(rgb, kind, name, alpha=None):
    a=ALPHA if alpha is None else alpha
    arr=to_rgba8(rgb,a)
    save_world(arr, kind, name)
    return arr
def finish_decal(rgb_ss, a_ss, kind, name, clip=True):
    rgb=down(rgb_ss*a_ss[...,None]); a=down(a_ss[...,None])[...,0]
    rgb=np.where(a[...,None]>1e-4,rgb/np.maximum(a[...,None],1e-4),0)
    if clip: a=a*ALPHA
    arr=to_rgba8(rgb,a); save_world(arr,kind,name); return arr
def flatten(S, sigma, amt):
    """remove low-frequency structure (periodic, uv space) so the 1-cell repeat does not read as a lattice"""
    lo=ndi.gaussian_filter(S,(sigma,sigma,0),mode='wrap')
    return np.clip(S-(lo-S.reshape(-1,3).mean(0))*amt,0,1)
# repo floor tiles carry a slightly wider AA rim than diamond_alpha; overlays must cover it or a hairline of the
# floor below shows through. HARD2 = 2x mask, HARD_SS = supersampled
_ra=np.asarray(Image.open(REPO+'tiles/_2x/water_a.png'))[...,3]
HARD2=((_ra>0)|(ALPHA>0)).astype(np.float32)
HARD_SS=np.repeat(np.repeat(HARD2,SS,0),SS,1)
