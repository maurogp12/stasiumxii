import numpy as np, json, glob, os
from PIL import Image
from scipy import ndimage as ndi
S='/workspace/scratch/l9_v1_decor_check/cap/'
def L(x): return x[...,0]*0.2126+x[...,1]*0.7152+x[...,2]*0.0722
def solve(kp,wp,region=None):
    K=np.asarray(Image.open(kp).convert('RGB')).astype(np.float64)
    W=np.asarray(Image.open(wp).convert('RGB')).astype(np.float64)
    a=1.0-(W-K).mean(-1)/255.0
    a=np.clip(a,0,1)
    c=K/np.maximum(a[...,None],1e-3)
    solid=a>0.985
    d,(iy,ix)=ndi.distance_transform_edt(~solid,return_indices=True)
    ref=c[iy,ix]
    edge=(a>0.06)&(a<0.94)&(d<=4)
    if region is not None:
        m=np.zeros_like(edge); m[region]=True; edge&=m
    dl=L(c[edge])-L(ref[edge])
    lo=edge&(a<0.35)
    ratio=(L(c[lo])+1)/(L(ref[lo])+1)
    # band ring: pixels 1-2px outside solid with alpha>0.06: compare composited-over-grey vs ideal
    return {'edge_px':int(edge.sum()),'fringe_minus_interior_luma_mean':round(float(dl.mean()),2),
            'p5':round(float(np.percentile(dl,5)),1),'p95':round(float(np.percentile(dl,95)),1),
            'light_rim_frac_gt25':round(float((dl>25).mean()),4),'dark_rim_frac_lt-25':round(float((dl<-25).mean()),4),
            'light_rim_frac_gt50':round(float((dl>50).mean()),4),'dark_rim_frac_lt-50':round(float((dl<-50).mean()),4),
            'lowalpha_luma_ratio_median':round(float(np.median(ratio)),3) if lo.sum() else None,
            'lowalpha_mean_a':round(float(a[lo].mean()),3) if lo.sum() else None}, (a,c,ref,edge,dl)
out={}
for proj in ['proj_wired','proj_patch']:
    for w in ['1280','1920']:
        for cam in ['zoom1','fit']:
            for s in ['s0','s1']:
                kp=f'{S}{proj}/leaves_{cam}_{s}_k_{w}.png'; wp=kp.replace('_k_','_w_')
                if not os.path.exists(kp): continue
                r,_=solve(kp,wp)
                out[f'leaves {proj} {w} {cam} {s}']=r
for w in ['1280','1920']:
    for cam in ['zoom1','fit']:
        kp=f'{S}clearing/clearing_over_k_{cam}_{w}.png'; wp=kp.replace('_k_','_w_')
        r,_=solve(kp,wp)
        out[f'clearing(plate CPU) {w} {cam}']=r
for k,v in out.items(): print(k, json.dumps(v))
json.dump(out,open(S+'halo_result.json','w'),indent=1)
