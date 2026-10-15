import numpy as np, glob, os, json, sys
from PIL import Image
from scipy import ndimage as nd
sys.path.insert(0,'/workspace/foe_walks/fly_back'); import dspk
OD='/workspace/foe_walks/cb3_out/captain_brineclaw_v3'; NM='captain_brineclaw'
TEALC=np.array([110,200,195.])
def fix(o):
    o=o.copy(); c=o[...,:3].astype(float); a=o[...,3]; L=c@[.299,.587,.114]; sat=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1)
    semi=(a>0)&(a<255)
    # effects (semi alpha): light/white -> soft teal, capped
    w=semi&(L>150)
    c[w]=TEALC*0.75+c[w]*0.25*np.array([0.6,0.9,0.9]); o[...,:3]=np.clip(c,0,255).astype(np.uint8)
    # opaque: pass-2 despeck on the opaque layer only
    op=o.copy(); op[a<255]=0; cl=dspk.clean(op); m=a==255; o[m]=cl[m]
    # isolated light pixels anywhere
    c=o[...,:3].astype(float); L=c@[.299,.587,.114]; vis=o[...,3]>0
    nb=nd.convolve(vis.astype(int),np.ones((3,3)))-1
    o[vis&(L>140)&(nb<=2)]=0
    lab,n=nd.label(o[...,3]==255); sz=nd.sum(lab>0,lab,range(1,n+1)); o[np.isin(lab,np.nonzero(sz<4)[0]+1)]=0
    o[o[...,3]==0]=0; return o
q={}
for dd in sorted(glob.glob(f'{OD}/*_frames_*')):
    act,d=os.path.basename(dd).rsplit('_frames_',1); fr=[]
    for p in sorted(glob.glob(f'{dd}/*.png')):
        o=fix(np.array(Image.open(p).convert('RGBA'))); Image.fromarray(o).save(p); fr.append(o)
    Image.fromarray(np.concatenate(fr,1)).save(f'{OD}/{NM}_{act}_{d}.png')
    arr=np.concatenate(fr,1); c=arr[...,:3].astype(float); L=c@[.299,.587,.114]; sat=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1)
    q[f'{act}_{d}']=dict(opaque_residue_px=int(dspk.residue(np.where((arr[...,3]==255)[...,None],arr,0)).sum()),near_white_px=int(((arr[...,3]>0)&(L>185)&(sat<0.25)).sum()))
json.dump(q,open(f'{OD}/despeck2_qa.json','w'),indent=1); print(q)
