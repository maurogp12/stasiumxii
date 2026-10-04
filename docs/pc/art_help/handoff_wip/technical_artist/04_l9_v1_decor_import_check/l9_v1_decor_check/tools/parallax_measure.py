import numpy as np, json, sys
from PIL import Image
S='/workspace/scratch/l9_v1_decor_check/cap/'
def load(p): return np.asarray(Image.open(p).convert('L')).astype(np.float64)
def shift(a,b):
    # phase correlation: returns (dy,dx) such that b ~ a shifted by (dy,dx)
    a=a-a.mean(); b=b-b.mean()
    w=np.outer(np.hanning(a.shape[0]),np.hanning(a.shape[1]))
    F=np.fft.fft2(a*w); G=np.fft.fft2(b*w)
    R=G*np.conj(F); R/=np.abs(R)+1e-9
    r=np.fft.ifft2(R).real
    dy,dx=np.unravel_index(np.argmax(r),r.shape)
    if dy>a.shape[0]//2: dy-=a.shape[0]
    if dx>a.shape[1]//2: dx-=a.shape[1]
    return int(dy),int(dx),float(r.max())
out={}
for proj in sys.argv[1:]:
    for w in ['1280','1920']:
        try: info=json.load(open(f'{S}{proj}/info_{w}.json'))
        except FileNotFoundError: continue
        k=int(w)/1280
        p0=load(f'{S}{proj}/pan_p0_{w}.png')
        # sky window: inside the clearing's hole (top centre); ground window: lower-left clearing ground
        H,W=p0.shape
        sky=(slice(int(0.06*H),int(0.26*H)),slice(int(0.30*W),int(0.62*W)))
        ground=(slice(int(0.45*H),int(0.80*H)),slice(int(0.20*W),int(0.60*W)))
        res={}
        for pan,ref in [('px',150),('py',100)]:
            p1=load(f'{S}{proj}/pan_{pan}_{w}.png')
            s=shift(p0[sky],p1[sky]); g=shift(p0[ground],p1[ground])
            axis=1 if pan=='px' else 0
            res[pan]={'camera_pan_world':ref,'sky_shift_px':s[:2],'ground_shift_px':g[:2],
                      'sky_fraction':round(-s[axis]/ (ref*k) ,3),'clearing_fraction':round(-g[axis]/(ref*k),3),
                      'expected_if_separate':{'sky':0.08,'clearing':0.4}}
        out[f'{proj}_{w}']=res
        print(proj,w,json.dumps(res))
json.dump(out,open(S+'parallax_result.json','w'),indent=1)
