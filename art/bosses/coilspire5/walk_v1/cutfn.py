import numpy as np, scipy.ndimage as nd
from PIL import Image
def cut(c):
    a=np.asarray(c).astype(float); h,w,_=a.shape
    bd=np.zeros((h,w),bool); bd[:10]=bd[-10:]=bd[:,:10]=bd[:,-10:]=True
    yy,xx=np.mgrid[0:h,0:w]; X=np.stack([np.ones(bd.sum()),xx[bd],yy[bd],xx[bd]**2,yy[bd]**2],1); bg=np.zeros_like(a)
    for ch in range(3):
        co,*_=np.linalg.lstsq(X,a[...,ch][bd],rcond=None); bg[...,ch]=co[0]+co[1]*xx+co[2]*yy+co[3]*xx**2+co[4]*yy**2
    L=a@[.299,.587,.114]; Lb=bg@[.299,.587,.114]; sat=a.max(-1)-a.min(-1)
    m=nd.uniform_filter(L,5); sd=np.sqrt(np.maximum(nd.uniform_filter(L*L,5)-m*m,0))
    fg=(np.abs(L-Lb)>14)|(sat>30)|(sd>7)
    fg=nd.binary_opening(fg,iterations=1); fg=nd.binary_closing(fg,iterations=3); fg=nd.binary_fill_holes(fg)
    fg&=~((sd<9)&(sat<24)&(L>38)); fg&=~((sat<22)&(L>92))   # painted ground shadow + grey glow haze
    fg=nd.binary_opening(fg,iterations=1); fg=nd.binary_closing(fg,iterations=1)
    fg=nd.binary_fill_holes(fg)
    lb,n=nd.label(fg); sz=nd.sum(fg,lb,range(1,n+1)); big=np.argmax(sz)+1
    keep=np.isin(lb,[i+1 for i,s in enumerate(sz) if s>=400 or i+1==big])
    inner=nd.binary_erosion(keep,iterations=1)
    o=np.zeros((h,w,4),np.uint8); rim=inner&~nd.binary_erosion(inner,iterations=2)
    out=a.copy(); out[rim]=np.minimum(out[rim],(out[rim]*0.7))  # darken rim, no grey fringe
    o[...,:3]=out.clip(0,255); o[...,3]=inner*255
    ys,xs=np.nonzero(inner); return Image.fromarray(o).crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1))
