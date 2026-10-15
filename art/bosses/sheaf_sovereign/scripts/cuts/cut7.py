import numpy as np, cv2
from PIL import Image
from scipy import ndimage as nd
pl=np.array(Image.open('sov_hand_grip.jpg').convert('RGB')).astype(float)
lum=pl.max(-1); key=np.clip((lum-30)/80,0,1)
for name,(x0,x1) in (('grip_open',(180,580)),('grip_fist',(690,1100))):
    k=key[:,x0:x1]; c=pl[:,x0:x1]
    sil=(cv2.GaussianBlur(k,(0,0),2)>0.3).astype(np.uint8)
    sil=cv2.morphologyEx(sil,cv2.MORPH_CLOSE,np.ones((31,31),np.uint8))
    n,lab=cv2.connectedComponents(sil); sz=np.bincount(lab.ravel()); sz[0]=0; sil=(lab==sz.argmax())
    sil=nd.binary_fill_holes(sil); sil=cv2.morphologyEx(sil.astype(np.uint8),cv2.MORPH_OPEN,np.ones((9,9),np.uint8)).astype(np.float32)
    sil=cv2.GaussianBlur(sil,(0,0),1.8)
    a=np.maximum(k**1.6*0.9,sil)            # solid interior; sparks/smoke keep the soft key outside
    # interior dark straw instead of see-through black: lift interior colour slightly toward deep brown
    inner=(sil>0.5)&(k<0.3); c=c.copy(); c[inner]=np.maximum(c[inner],np.array([26,18,10]))
    ys,xs=np.nonzero(a>0.06); y1=ys.max(); Y=np.arange(a.shape[0])[:,None]; a*=np.clip((y1-Y)/50,0,1)
    out=np.dstack([c,a*255]).astype(np.uint8)[ys.min():y1+1,xs.min():xs.max()+1]
    Image.fromarray(out).save(f'hands_v2/{name}.png'); print(name,out.shape)
