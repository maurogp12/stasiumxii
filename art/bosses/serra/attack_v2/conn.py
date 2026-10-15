import numpy as np, json, scipy.ndimage as nd
from PIL import Image
T=json.load(open('arm_track.json')); bad=0; rep=[]
for d,k in (('e','back'),('w','front')):
    s=np.array(Image.open(f'serra14_attack_{d}.png'))[...,3]
    for f,S,E,H,a in T[k]:
        A=s[:,f*640:(f+1)*640]>0; lab,_=nd.label(A,np.ones((3,3)))
        pts=[np.array(S)+(np.array(E)-S)*t for t in np.linspace(0,1,12)]+[np.array(E)+(np.array(H)-E)*t for t in np.linspace(0,1,12)]
        gaps=sum(not A[int(round(p[1])),int(round(p[0]))] for p in pts)
        # component of hand == component of torso (shoulder)?
        def comp(p):
            y,x=int(round(p[1])),int(round(p[0])); w=lab[y-2:y+3,x-2:x+3]; v=w[w>0]; return np.bincount(v).argmax() if v.size else 0
        same=comp(H)==comp(S)!=0
        if gaps>1 or not same: bad+=1
        rep.append(f'{d} f{f:2d} gaps={gaps} hand~torso={same}')
print('\n'.join(rep)); print('BAD',bad)
