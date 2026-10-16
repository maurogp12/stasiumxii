import numpy as np, cv2, sys
from PIL import Image
sys.argv=['x']
exec(open('/workspace/stasium-pc-look/ship/lakes_v1/src/build.py').read().split('# ---------- 1. TILES')[0])
sys.path.insert(0,'/workspace/stasium-pc-look/ship/lakes_v1/src'); from clean import clean, EX, EY
K=46/128
def hero_mask(cl,box):
    x0,y0,x1,y1=box; m=np.zeros(cl.shape[:2],bool)
    sub=cl[y0:y1,x0:x1].astype(np.uint8); bg=cv2.medianBlur(sub,21).astype(float)
    L=sub.astype(float).mean(2); Lb=bg.mean(2)
    mm=(Lb-L>14)|(np.abs(sub.astype(float)-bg).sum(2)>70)
    mm=cv2.morphologyEx(mm.astype(np.uint8),cv2.MORPH_CLOSE,np.ones((3,3)))
    n,lab,st,_=cv2.connectedComponentsWithStats(mm)
    if n>1:
        k=1+np.argmax(st[1:,4]); keep=np.isin(lab,[i for i in range(1,n) if st[i,4]>25 and (i==k or st[i,4]>60)])
        keep=cv2.dilate(keep.astype(np.uint8),np.ones((2,2)))>0
        m[y0:y1,x0:x1]=keep
    return m
def cell_top(O,x0,y0,tx,ty): return O+(tx-x0)*EX+(ty-y0)*EY
def put(im,spr,px,py,sc=1.0):
    s=spr.convert('RGBA'); s=s.resize((max(1,round(s.width*K*sc)),max(1,round(s.height*K*sc))),Image.LANCZOS)
    im.alpha_composite(s,(int(round(px-s.width/2)),int(round(py-s.height))))
