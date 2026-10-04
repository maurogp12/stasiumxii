import numpy as np, sys
sys.path.insert(0,'.'); from m32 import *
from check_chars import label
def blobs(a, band=16):
    m = a[...,3]>127; s = C.sole_row(m); B = np.zeros_like(m); B[max(0,s-band):s+1] = True
    lab, n = label(m & B); out=[]
    for k in range(1,n+1):
        ys,xs=np.where(lab==k)
        if len(ys)>=25: out.append((ys,xs))
    return out
def blob_track(a,b,ys,xs,rx=16,ry=10):
    A=a.astype(float);B=b.astype(float);h,w=a.shape[:2];best=None
    for dy in range(-ry,ry+1):
        for dx in range(-rx,rx+1):
            y2,x2=ys+dy,xs+dx; ok=(y2>=0)&(y2<h)&(x2>=0)&(x2<w)
            pa=A[ys[ok],xs[ok]];pb=B[y2[ok],x2[ok]]
            e=(np.abs(pa[:,:3]-pb[:,:3]).mean(1)*(pb[:,3]>127)+160*(pb[:,3]<=127)).mean()
            if best is None or e<best[2]: best=(dx,dy,e)
    return best
if __name__=="__main__":
    V=sys.argv[1]; fcs=sys.argv[2]
    for fc in fcs:
        fr=[load(V,'walk',fc,i) for i in range(12)]
        print('==',fc)
        for i in range(12):
            a,b=fr[i],fr[(i+1)%12]; res=[]
            for ys,xs in blobs(a):
                dx,dy,e=blob_track(a,b,ys,xs); res.append(f'x{xs.min()}-{xs.max()} y{ys.min()}-{ys.max()} n{len(ys)} -> ({dx},{dy}) e{e:.0f}')
            print(f'f{i:02d}->f{(i+1)%12:02d}', ' || '.join(res))
