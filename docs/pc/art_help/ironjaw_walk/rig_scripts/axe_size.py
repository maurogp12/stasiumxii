import sys; sys.path.insert(0,'.')
from build import *
from scipy.spatial import ConvexHull
def feret(m):
    ys,xs=np.nonzero(m); pts=np.c_[xs,ys]; h=pts[ConvexHull(pts).vertices]
    d=np.sqrt(((h[:,None]-h[None])**2).sum(-1)); return round(float(d.max()),1), int(m.sum())
prepare()
for fac,boxes in (('E',{'R':(345,215,512,360),'L':(0,215,175,360)}),('S',{'R':(0,210,165,360),'L':(345,190,512,360)})):
    ref=np.asarray(Image.open(f'/workspace/art/ironjaw_full/v4_hd/_norim/idle/ironjaw_idle_{fac}_f00.png'))[...,3]>0
    idle=J['idle_'+fac]; rgb,al,layers,owner,Ms,meta,order=render(fac,idle,idle)
    for sd,(x0,y0,x1,y1) in boxes.items():
        m=np.zeros_like(ref); m[y0:y1,x0:x1]=ref[y0:y1,x0:x1]
        lab,n=ndi.label(m); sz=np.bincount(lab.ravel()); sz[0]=0; m=lab==np.argmax(sz)
        # our head only: axe layer (unclipped geometry) pixels beyond the handle
        w=warp(TEX[(fac,f'{sd}_axe')],Ms[f'{sd}_axe'],PRE[(fac,f'{sd}_axe')]); _,lay=to_layer(w)
        print(fac,sd,'painted idle head region feret/px',feret(m),'ours axe piece feret/px',feret(lay))
