import numpy as np, json
from PIL import Image
from scipy import ndimage as ndi
K='/workspace/stasium-pc-look/ship/l9_v1_decor/'
def L(x): return x[...,0]*0.2126+x[...,1]*0.7152+x[...,2]*0.0722
def metric(a,c):
    solid=a>0.985
    d,(iy,ix)=ndi.distance_transform_edt(~solid,return_indices=True)
    ref=c[iy,ix]; edge=(a>0.06)&(a<0.94)&(d<=4)
    dl=L(c[edge])-L(ref[edge])
    return dict(mean=round(float(dl.mean()),2),p5=round(float(np.percentile(dl,5)),1),p95=round(float(np.percentile(dl,95)),1),
                light25=round(float((dl>25).mean()),4),dark25=round(float((dl<-25).mean()),4))
out={}
for name in ['leaf_frame_left','leaf_frame_right','leaf_frame_top']:
    im=np.asarray(Image.open(K+name+'@2x.png').convert('RGBA')).astype(np.float64)/255
    for s in [0.14,0.3,0.59]:
        h,w=im.shape[:2]; nw,nh=max(8,int(w*s)),max(8,int(h*s))
        pm=im.copy(); pm[...,:3]*=pm[...,3:4]
        # ideal: premultiplied box/area downscale
        r=np.asarray(Image.fromarray((pm*65535).astype(np.uint16)[...,0]).resize((nw,nh),Image.BOX)) # dummy for shape
        chans=[np.asarray(Image.fromarray((pm[...,i]*255).astype(np.float32),mode='F').resize((nw,nh),Image.BOX)) for i in range(4)]
        a=chans[3]/255; c=np.stack(chans[:3],-1)/np.maximum(a[...,None],1e-3)
        out[f'{name} ideal x{s}']=metric(a,c)
        # straight bilinear (what Godot Image.resize does on straight RGBA, approx)
        chs=[np.asarray(Image.fromarray((im[...,i]*255).astype(np.float32),mode='F').resize((nw,nh),Image.BILINEAR)) for i in range(4)]
        a2=chs[3]/255; c2=np.stack(chs[:3],-1)
        out[f'{name} straight-bilinear x{s}']=metric(a2,c2)
for k,v in out.items(): print(k,v)
json.dump(out,open('/workspace/scratch/l9_v1_decor_check/cap/halo_ideal_reference.json','w'),indent=1)
