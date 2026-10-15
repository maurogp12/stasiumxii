import numpy as np
from PIL import Image
from scipy import ndimage as nd
def matte(p,th=26):
    a=np.array(Image.open(p).convert('RGB')).astype(int); bg=np.median(np.concatenate([a[:8].reshape(-1,3),a[-8:].reshape(-1,3),a[:,:8].reshape(-1,3),a[:,-8:].reshape(-1,3)]),0)
    d=np.abs(a-bg).max(-1); f=d>th; f=nd.binary_opening(f,iterations=1); lab,k=nd.label(f); sz=nd.sum(f,lab,range(1,k+1)); f=np.isin(lab,np.nonzero(sz>40)[0]+1)
    al=np.clip((d-th*0.6)/(th*0.8),0,1)*255*nd.binary_dilation(f,iterations=1)
    o=np.dstack([a,al]).astype(np.uint8); return o,f
if __name__=='__main__':
    for n in ['sov_cast_f','sov_cast_b','war_cast_b','sov_rem']:
        o,f=matte(f'plates/{n}.jpg'); lab,k=nd.label(nd.binary_dilation(f,iterations=3)); sz=nd.sum(f,lab,range(1,k+1)); ob=nd.find_objects(lab)
        print(n,k,[(i+1,int(sz[i]),(ob[i][1].start,ob[i][0].start,ob[i][1].stop,ob[i][0].stop)) for i in range(k) if sz[i]>300])
        Image.fromarray(o).save(f'plates/{n}_m.png')
