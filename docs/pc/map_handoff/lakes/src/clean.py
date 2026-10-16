import numpy as np, cv2
from PIL import Image
CAP='/workspace/cloud-agent-artifacts/bc-1acb5d36-2a38-561a-924e-370f130cb048/blightwood_v2/'
EX=np.array([23.0,11.4]); EY=np.array([-23.0,11.35])
def clean(cap,O,x0,x1,y0,y1):
    img=np.array(Image.open(CAP+cap).convert('RGB')).astype(float); H,W=img.shape[:2]
    Mi=np.linalg.inv(np.array([EX,EY]).T)
    yy,xx=np.mgrid[0:H,0:W]; rel=np.stack([xx-O[0],yy-O[1]],-1)@Mi.T
    tx=rel[...,0]+x0; ty=rel[...,1]+y0
    rect=(tx>=x0)&(tx<x1)&(ty>=y0)&(ty<y1); rect[H-30:]=False
    ring=(tx>=x0-1.5)&(tx<x1+1.5)&(ty>=y0-1.5)&(ty<y1+1.5)&~((tx>=x0-.2)&(tx<x1+.2)&(ty>=y0-.2)&(ty<y1+.2))
    ring&=(img.sum(2)>120)
    si=img[rect].std(0); so=img[ring].std(0); a=float(np.clip(1-(si/so).mean(),0.05,0.8))
    C=(img[rect].mean(0)-img[ring].mean(0)*(1-a))/a
    cl=img.copy(); cl[rect]=(img[rect]-a*C)/(1-a)
    fx=np.abs(tx-np.round(tx)); fy=np.abs(ty-np.round(ty))
    line=((fx*23<2.4)|(fy*23<2.4))&(tx>=x0-.15)&(tx<=x1+.15)&(ty>=y0-.15)&(ty<=y1+.15)
    cl=np.clip(cl,0,255).astype(np.uint8)
    cl=cv2.inpaint(cl,line.astype(np.uint8)*255,4,cv2.INPAINT_TELEA).astype(float)
    return img,cl,tx,ty,rect
