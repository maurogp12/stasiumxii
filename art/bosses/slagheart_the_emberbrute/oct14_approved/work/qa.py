import numpy as np, glob, json
from PIL import Image
from scipy import ndimage as nd
R={}
for f in sorted(glob.glob('/workspace/foe_walks/slag_out/strips/body_only/*.png')):
    im=np.array(Image.open(f)); n=im.shape[1]//288; fr=[im[:,i*288:(i+1)*288] for i in range(n)]; nm=f.split('/')[-1][10:-4]
    r=dict(frames=n,nearwhite=0,white1=0,jumps=[])
    for i,o in enumerate(fr):
        h=o[...,3]>=128; c=o[...,:3].astype(float); L=c@[.299,.587,.114]; s=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1)
        w=h&(L>135)&(s<0.25); r['nearwhite']+=int(w.sum())
        r['white1']+=int((w&(nd.convolve(w.astype(int),np.ones((3,3)),mode='constant')<=1)).sum())
        if i: r['jumps'].append(round(float(np.abs(o.astype(float)-fr[i-1].astype(float)).mean()),2))
    if nm.startswith('walk'): r['loop']=round(float(np.abs(fr[0].astype(float)-fr[-1].astype(float)).mean()),2)
    r['maxjump']=max(r['jumps']); r['med']=float(np.median(r['jumps'])); R[nm]=r
json.dump(R,open('/workspace/foe_walks/slag_out/qa.json','w'),indent=1)
for k,v in R.items(): print(k,v['frames'],'nw',v['nearwhite'],'w1',v['white1'],'max/med',v['maxjump'],round(v['med'],2),v.get('loop',''), 'jumps',v['jumps'] if k.startswith(('slam','walk')) else '')
