import numpy as np, scipy.ndimage as nd, glob
from PIL import Image
for p in glob.glob('serra14_*_*.png'):
    s=np.array(Image.open(p))
    for it in range(2):
        m=s[...,3]==255; nb=nd.convolve(m.astype(int),np.ones((3,3)),mode='constant')-m; h=(~m)&(nb>=7); acc=np.zeros(s.shape[:2]+(3,))
        for dy in (-1,0,1):
            for dx in (-1,0,1):
                if dy or dx: acc+=np.roll(np.roll(s,dy,0),dx,1)[...,:3]*np.roll(np.roll(m,dy,0),dx,1)[...,None]
        s[h,:3]=(acc[h]/nb[h][:,None]).astype(np.uint8); s[h,3]=255
    Image.fromarray(s).save(p)
