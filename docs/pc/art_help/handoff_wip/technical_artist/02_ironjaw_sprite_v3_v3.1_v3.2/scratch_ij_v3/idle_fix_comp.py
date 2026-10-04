import numpy as np; from PIL import Image
V='/workspace/art/ironjaw_full/v3'
L=lambda s,i=0,f='S': np.array(Image.open(f'{V}/{s}/ironjaw_{s}_{f}_f{i:02d}.png').convert('RGBA'))
def seam_curve(spec, w=165):
    S=np.zeros(w,int)
    for (x0,x1,y) in spec: S[x0:x1+1]=y
    return S
def composite(idle, walk, S, fill_box=None):
    h,w=idle.shape[:2]; Y=np.arange(h)[:,None]
    below=Y>=S[None,:]
    out=np.where(below[...,None], walk, idle).copy()
    if fill_box:
        x0,y0,x1,y1=fill_box
        reg=np.zeros((h,w),bool); reg[y0:y1+1,x0:x1+1]=True
        m=reg & ~below & (idle[...,3]==0) & (walk[...,3]>0)
        out[m]=walk[m]
    out[out[...,3]==0]=0
    return out
# hand-picked: idle axe-horn tip strip (light edge + its underside shading) that crosses below the seam curve; always idle
STRIP=[(69,114),(69,115),(69,116),(70,115),(70,116),(70,117),(71,116),(71,117),(71,118),(72,117),(72,118),
       (73,117),(73,118),(74,118),(75,118),(75,119),(76,119),(76,120),(77,119)]
SPEC=[(0,43,104),(44,61,109),(62,69,112),(70,79,118),(80,90,120),(91,104,114),(105,164,120)]
FILL=(62,90,104,125)
def build(idle_f, walk0):
    S=seam_curve(SPEC); o=composite(idle_f, walk0, S, FILL)
    for x,y in STRIP: o[y,x]=idle_f[y,x]
    o[o[...,3]==0]=0
    return o
def components(a):
    import sys; sys.path.insert(0,'/workspace/stasium-pc-look/tools')
    from check_chars import label
    lab,n=label(a[...,3]>0)
    sizes=np.bincount(lab.ravel())[1:]
    return lab,n,sizes
def holes(a):
    import sys; sys.path.insert(0,'/workspace/stasium-pc-look/tools')
    from check_chars import label
    m=a[...,3]>0; lab,n=label(~m)
    border=set(lab[0])|set(lab[-1])|set(lab[:,0])|set(lab[:,-1])
    return int(sum((lab==k).sum() for k in range(1,n+1) if k not in border))
