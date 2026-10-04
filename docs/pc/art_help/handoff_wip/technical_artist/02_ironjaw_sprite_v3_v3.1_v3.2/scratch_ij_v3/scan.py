import numpy as np, sys, os
from PIL import Image
from multiprocessing import Pool
Image.MAX_IMAGE_PIXELS=None
V2='/workspace/art/ironjaw_full/v2'
def L(p): return np.array(Image.open(p).convert('RGBA'))
pats=[]
for name,(y0,y1,x0,x1) in [('walk/ironjaw_walk_S_f11.png',(96,105,144,156)),('attack/ironjaw_attack_S_f02.png',(30,40,144,156))]:
    a=L(f'{V2}/{name}'); p=a[y0:y1,x0:x1]
    assert (p[...,3]>0).mean()>0.6
    pats.append((name,'S',p)); pats.append((name,'flip',p[:,::-1]))
def scan(path):
    try:
        im=Image.open(path)
        if im.width*im.height>12e6: return None
        a=np.array(im.convert('RGBA'))
    except Exception as e: return None
    hits=[]
    for name,o,p in pats:
        m=p[...,3]>0; ys,xs=np.where(m); ay,ax=ys[0],xs[0]; c=p[ay,ax,:3]
        cand=np.argwhere((a[...,0]==c[0])&(a[...,1]==c[1])&(a[...,2]==c[2])&(a[...,3]>0))
        if len(cand)>20000: cand=cand[:20000]
        for y,x in cand:
            Y,X=y-ay,x-ax
            if Y<0 or X<0 or Y+p.shape[0]>a.shape[0] or X+p.shape[1]>a.shape[1]: continue
            w=a[Y:Y+p.shape[0],X:X+p.shape[1]]
            if np.array_equal(w[...,:3][m],p[...,:3][m]):
                hits.append((name,o,int(X),int(Y),a.shape[1],a.shape[0]))
    return (path,hits) if hits else None
if __name__=='__main__':
    files=[l.strip() for l in open('pngs.txt')]
    with Pool(8) as pool:
        for r in pool.imap_unordered(scan,files,chunksize=16):
            if r: print(r,flush=True)
    print('DONE',flush=True)
