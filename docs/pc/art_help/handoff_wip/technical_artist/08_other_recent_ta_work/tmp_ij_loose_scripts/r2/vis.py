from PIL import Image
import numpy as np, glob, os, sys
d=sys.argv[1] if len(sys.argv)>1 else 'renders_512/sides'
for col,name in (((220,60,210),'axe_L'),((36,78,170),'hand_L'),((52,106,206),'forearm_L')):
    r=[]
    for p in sorted(glob.glob(d+'/*_E*.png')):
        a=np.array(Image.open(p).convert('RGBA')).astype(int)
        m=(np.abs(a[...,:3]-np.array(col)).sum(-1)<40)&(a[...,3]>0)
        r.append((os.path.basename(p)[:-4],int(m.sum())))
    print(name,r)
