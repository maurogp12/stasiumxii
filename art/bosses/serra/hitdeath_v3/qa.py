import numpy as np, scipy.ndimage as nd
from PIL import Image
tot=dict(specks=0,holes=0,semi_body=0,frames=0)
for a,n in (('hit',8),('death',22),('idle',12)):
    for d in 'nesw':
        s=np.array(Image.open(f'serra14_{a}_{d}.png'))
        for f in range(n):
            A=s[:,f*640:(f+1)*640,3]; m=A==255; lb,k=nd.label(m,np.ones((3,3)))
            if k: tot['specks']+=int((nd.sum(m,lb,range(1,k+1))<8).sum())
            nb=nd.convolve(m.astype(int),np.ones((3,3)),mode='constant')-m
            tot['holes']+=int(((~m)&(nb>=7)).sum())          # 1-px seams/pinholes inside sprite
            tot['semi_body']+=int(((A>0)&(A<255)&(s[:,f*640:(f+1)*640,:3].max(-1)>60)).sum())   # soft alpha on lit (non-shadow) pixels
            tot['frames']+=1
print(tot)
