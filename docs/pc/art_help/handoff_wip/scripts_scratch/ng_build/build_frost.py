"""D) frost tint: tileable 512x512 screen-space overlay + diamond overlays frost_overlay_a/b"""
from build_tiles_helpers import *
fg=load('frost_grass_swatch.jpg')
l=lum(fg); sat=fg.max(-1)-fg.min(-1)
# frostness: whitish / blue-white areas (b >= g or low saturation) that are bright
f=smoothstep(0.70,0.90,l)*np.clip(smoothstep(-0.06,0.04,fg[...,2]-fg[...,1])+smoothstep(0.12,0.05,sat),0,1)
f=np.clip(f,0,1)
src=np.stack([f,l,fg[...,2]-fg[...,1]],-1).astype(np.float32)
# --- 512x512 tileable screen-space swatch ---
N=512
def samp(org,k):
    def fn(u,v): return bilinear(src,org[0]+u*N*k,org[1]+v*N*k)
    return fn
P=make_periodic(samp((300,90),1.05),N)
fa=np.clip(P[...,0],0,1)
fs=ndi.gaussian_filter(fa,4.0,mode='wrap')
crys=np.clip((P[...,1]-ndi.gaussian_filter(P[...,1],2.0,mode='wrap'))*6,0,1)   # fine bright flecks
alpha=np.clip(0.20+0.42*smoothstep(0.05,0.6,fs)+0.30*crys*(0.4+fs),0,0.80)
fa=fs
col=np.stack([0.86+0.10*fa,0.91+0.07*fa,np.full_like(fa,0.99)],-1)
col=np.clip(col+0.03*crys[...,None],0,1)
arr=to_rgba8(col,alpha)
save_world(arr,'overlays','frost_tint_swatch')
print('swatch alpha mean',alpha.mean())
# seam check (wrap)
d=np.abs(arr[:,0].astype(int)-arr[:,-1].astype(int)).mean(), np.abs(arr[0].astype(int)-arr[-1].astype(int)).mean()
print('wrap edge diff',d)
# --- diamond overlays (uv periodic, shared border band) ---
def uvt(org,k,flip=False,rot=0.0): return make_periodic(src_sampler(src,org,k,flip=flip,rot=rot),R)
base=uvt((640,360),2.6)
for nm,seed,org,flip in (('a',61,(300,250),False),('b',62,(950,480),True)):
    r=rng(seed)
    var=uvt(org,2.6*r.uniform(0.95,1.05),flip,r.uniform(-0.1,0.1))
    S=var_blend(base,var,MINT)
    Sx=sample_uv(S,np.mod(U,1),np.mod(V,1))
    fa=np.clip(ndi.gaussian_filter(Sx[...,0],5.0),0,1); ll=Sx[...,1]
    crys=np.clip((ll-ndi.gaussian_filter(ll,3.0))*6,0,1)
    a=np.clip(0.20+0.42*smoothstep(0.05,0.6,fa)+0.30*crys*(0.4+fa),0,0.80)
    c=np.stack([0.86+0.10*fa,0.91+0.07*fa,np.full_like(fa,0.99)],-1)+0.03*crys[...,None]
    rgb=down(np.clip(c,0,1)); A=down(a[...,None])[...,0]*HARD2
    save_world(to_rgba8(rgb,A),'tiles','frost_overlay_'+nm)
print('frost done')
