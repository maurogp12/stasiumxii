import numpy as np, scipy.ndimage as nd, cv2
from PIL import Image
def seg(side):
    a=np.array(Image.open(f'keys/raw_{side}.png')); m=a[...,3]>0; H,W=m.shape
    k=cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(51,51))
    body=cv2.morphologyEx(m.astype(np.uint8),cv2.MORPH_OPEN,k)>0
    lb,n=nd.label(body); sz=nd.sum(body,lb,range(1,n+1)); body=lb==(np.argmax(sz)+1)
    bd=nd.binary_dilation(body,iterations=4)
    rest=m&~bd; lb,n=nd.label(rest,np.ones((3,3)))
    comps=[]
    for i in range(1,n+1):
        c=lb==i; ys,xs=np.nonzero(c)
        if c.sum()>150 and ys.max()>0.55*H: comps.append((c.sum(),i,xs.mean(),ys.max()))
    return a,m,body,lb,comps
if __name__=='__main__':
    for s in ('front','back'):
        a,m,body,lb,comps=seg(s); print(s,len(comps),[(int(c[0]),int(c[2]),int(c[3])) for c in comps])
        v=np.zeros(m.shape+(3,),np.uint8); v[m]=80; v[body]=(0,0,200)
        cols=[(255,0,0),(0,255,0),(255,255,0),(0,255,255),(255,0,255),(255,128,0),(128,255,128),(255,255,255)]
        for j,c in enumerate(comps): v[lb==c[1]]=cols[j%8]
        Image.fromarray(v).save(f'keys/seg_{s}.png')
