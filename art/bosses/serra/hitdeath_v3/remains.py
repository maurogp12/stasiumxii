import numpy as np, scipy.ndimage as nd
from PIL import Image
src=open('../matte.py').read(); exec(src[:src.index('def fit')])
P='/cursor/stores/store-c01dd204-c037-4a89-b6fe-7a06d7c1b2f9/grok-bot/agents/10888a55-2177-4c78-97bf-f62165f60d9b/attachments/1900a99441a5497ae8fce2bb445cf1036338b29d827d1e562806bd56121410c0.jpg'
im=Image.open(P).convert('RGB'); a=np.asarray(im).astype(float); H,W,_=a.shape
bd=np.zeros((H,W),bool); bd[:12]=bd[-12:]=bd[:,:12]=bd[:,-12:]=True; yy,xx=np.mgrid[0:H,0:W]
X=np.stack([np.ones(bd.sum()),xx[bd],yy[bd],xx[bd]**2,yy[bd]**2],1); bg=np.zeros_like(a)
for c in range(3):
    co,*_=np.linalg.lstsq(X,a[...,c][bd],rcond=None); bg[...,c]=co[0]+co[1]*xx+co[2]*yy+co[3]*xx**2+co[4]*yy**2
d=np.linalg.norm(a-bg,axis=-1); L=a@[.299,.587,.114]; Lb=bg@[.299,.587,.114]; sat=a.max(-1)-a.min(-1)
fg=(d>34)|((sat>22)&(d>16))
shadow=(L<Lb)&(sat<14)&(d<60)          # painted soft ground shadow (darker neutral grey) -> drop, we draw our own
fg&=~shadow
fg=nd.binary_opening(fg,iterations=1); fg=nd.binary_closing(fg,iterations=2); fg=nd.binary_fill_holes(fg)
lb,n=nd.label(fg); sz=nd.sum(fg,lb,range(1,n+1)); big=np.argmax(sz)+1
keep=np.isin(lb,[i+1 for i,s in enumerate(sz) if s>=150])
inner=nd.binary_erosion(keep,iterations=1); ring=inner&~nd.binary_erosion(inner,iterations=2)
out=a.copy(); al=np.clip(d/70,0.35,1)[ring][:,None]; out[ring]=np.clip((a[ring]-bg[ring]*(1-al))/al,0,255)*0.85
o=np.zeros((H,W,4),np.uint8); o[...,:3]=out.clip(0,255); o[...,3]=inner*255
ys,xs=np.nonzero(inner); o=o[ys.min():ys.max()+1,xs.min():xs.max()+1]
im2=Image.fromarray(o); k=170/im2.width; im2=im2.resize((170,round(im2.height*k)),Image.LANCZOS)
q=np.array(im2); q[...,3]=np.where(q[...,3]>=140,255,0)
c=q[...,:3].astype(float); Lq=c@[.299,.587,.114]; s=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1)
m=(q[...,3]>0)&(Lq>215)&(s<0.15); q[m,:3]=(c[m]*(215/Lq[m])[:,None]).astype(np.uint8)
mm=q[...,3]==255; lb,n=nd.label(mm,np.ones((3,3))); sz=nd.sum(mm,lb,range(1,n+1)); q[np.isin(lb,np.nonzero(sz<8)[0]+1)]=0
q[q[...,3]==0]=0; Image.fromarray(q).save('remains_170.png'); print(q.shape)
