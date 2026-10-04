import numpy as np, json, sys
from PIL import Image
from scipy import ndimage as ndi
K='/workspace/stasium-pc-look/ship/l9_v1_decor/'
def luma(rgb): return rgb[...,0]*0.2126+rgb[...,1]*0.7152+rgb[...,2]*0.0722
out={}
for name in ['clearing@2x','clearing','leaf_frame_left@2x','leaf_frame_left','leaf_frame_right@2x','leaf_frame_right','leaf_frame_top@2x','leaf_frame_top','leaf_frame_bottom@2x','leaf_frame_bottom']:
    a=np.asarray(Image.open(K+name+'.png').convert('RGBA')).astype(np.float32)
    rgb=a[...,:3]; al=a[...,3]
    z=al==0; full=al==255; semi=(al>0)&(al<255)
    # nearest fully-opaque pixel for each pixel
    d,(iy,ix)=ndi.distance_transform_edt(~full,return_indices=True)
    near=rgb[iy,ix]
    # RGB under alpha0 near edge (within 4px of any alpha>0)
    nz=al>0
    dz=ndi.distance_transform_edt(~nz)
    zb=z&(dz<=4)
    under=rgb[zb]; under_ref=near[zb]
    r={}
    r['alpha0_frac']=float(z.mean()); r['semi_frac']=float(semi.mean())
    r['under_a0_black_frac']=float((under.max(1)<8).mean()) if len(under) else None
    r['under_a0_white_frac']=float((under.min(1)>247).mean()) if len(under) else None
    r['under_a0_vs_nearest_opaque_meanabs']=float(np.abs(under-under_ref).mean()) if len(under) else None
    r['under_a0_luma_mean']=float(luma(under).mean()) if len(under) else None
    # fringe: semi pixels within 3px of opaque
    fs=semi&(d<=3)
    fr=rgb[fs]; ref=near[fs]; fa=al[fs]/255.
    dl=luma(fr)-luma(ref)
    r['fringe_n']=int(fs.sum())
    r['fringe_luma_minus_interior_mean']=float(dl.mean())
    r['fringe_luma_minus_interior_p5_p95']=[float(np.percentile(dl,5)),float(np.percentile(dl,95))]
    r['fringe_light_rim_frac(>+25)']=float((dl>25).mean()); r['fringe_dark_rim_frac(<-25)']=float((dl<-25).mean())
    # premultiply test: low-alpha fringe luma ratio vs interior
    lo=fa<0.35
    ratio=(luma(fr[lo])+1)/(luma(ref[lo])+1)
    r['lowalpha_fringe_luma_ratio_median']=float(np.median(ratio)) if lo.sum() else None
    r['lowalpha_mean_alpha']=float(fa[lo].mean()) if lo.sum() else None
    # composite halo on mid grey with straight vs premult interpretation not needed
    out[name]=r
    print(name, json.dumps(r))
json.dump(out,open('/workspace/scratch/l9_v1_decor_check/alpha/alpha_stats_source.json','w'),indent=1)
