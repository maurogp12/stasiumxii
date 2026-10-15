import numpy as np, glob, os, json, sys
from PIL import Image
sys.path.insert(0,'/workspace/foe_walks/cb3'); sys.argv=['x']
src=open('/workspace/foe_walks/cb3_out/scripts/despeck_all.py').read(); exec(src[:src.index('q={}')])   # fix(), OD, NM
only=sys.stdin.read().split() if False else ['walk','idle','death']
q=json.load(open(f'{OD}/despeck2_qa.json'))
for dd in sorted(glob.glob(f'{OD}/*_frames_*')):
    act,d=os.path.basename(dd).rsplit('_frames_',1)
    if act not in only: continue
    fr=[]
    for p in sorted(glob.glob(f'{dd}/*.png')):
        o=fix(np.array(Image.open(p).convert('RGBA'))); c=o[...,:3].astype(float); L=c@[.299,.587,.114]; sat=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1)
        w=(o[...,3]>0)&(L>150)&(sat<0.3); o[...,:3][w]=np.clip(c[w]*np.array([0.45,0.7,0.7]),0,255).astype(np.uint8)
        g=(o[...,3]>0)&(sat<0.08)&(L>90); o[g]=0     # grey seam / ground-shadow pixels anywhere
        Image.fromarray(o).save(p); fr.append(o)
    arr=np.concatenate(fr,1); Image.fromarray(arr).save(f'{OD}/{NM}_{act}_{d}.png')
    c=arr[...,:3].astype(float); L=c@[.299,.587,.114]; sat=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1)
    q[f'{act}_{d}']=dict(opaque_residue_px=int(dspk.residue(np.where((arr[...,3]==255)[...,None],arr,0)).sum()),near_white_px=int(((arr[...,3]>0)&(L>185)&(sat<0.25)).sum()))
json.dump(q,open(f'{OD}/despeck2_qa.json','w'),indent=1); print({k:v for k,v in q.items() if k.split('_')[0] in only})
