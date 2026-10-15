import numpy as np,cv2
from PIL import Image,ImageFilter,ImageDraw
V='/workspace/foe_walks/serra_v2/'
R=np.array(Image.open(V+'hitdeath_v3/remains_170.png')).astype(np.float32)
# paler ghostly palette: desaturate, lift, push to pale cyan
rgb=R[...,:3]/255; L=rgb@[.3,.59,.11]; L=L[...,None]
g=0.45*rgb+0.55*L; g=0.06+0.94*g**0.92; g=g*np.array([.86,.96,1.04]); R[...,:3]=np.clip(g*255,0,255)
# ★5 staff from the front key
K=np.array(Image.open(V+'s5_walk/keys/s5_front.png')); p0=np.array((90,298.)); p1=np.array((225,101.))
yy,xx=np.mgrid[:K.shape[0],:K.shape[1]]; v=p1-p0; t=np.clip(((xx-p0[0])*v[0]+(yy-p0[1])*v[1])/(v@v),0,1)
d=np.hypot(xx-p0[0]-t*v[0],yy-p0[1]-t*v[1]); top=(t>.8)
S=np.load('/tmp/staff5.npy'); S[S[...,3]<255]=0; S[~((d<5)|((t<0.3)&(d<12)))]=0; p0,p1=p1,p0; v=p1-p0
# rotate so tip (p1) points up-left like old staff: old staff (125,116)->(5,26)
ang_src=np.degrees(np.arctan2(v[1],v[0])); tgt=np.degrees(np.arctan2(26-116,5-125))
L0=np.linalg.norm(v); sc=158/L0; c=(p0+p1)/2
M=cv2.getRotationMatrix2D(tuple(c),ang_src-tgt,sc); M[:,2]+=np.array([65,71])-c
ST=cv2.warpAffine(S,M,(170,158),flags=cv2.INTER_NEAREST)
rim=(ST[...,3]==255)&~(cv2.erode((ST[...,3]==255).astype(np.uint8),np.ones((3,3)))>0)
up=np.zeros_like(rim); up[1:]=rim[:-1]&(ST[:-1,...,3]==255)   # top-facing edge pixels
ST[rim,:3]=np.clip(ST[rim,:3]*0.45+np.array([150,215,240])*0.55,0,255)
# erase old staff band, re-fill from neighbours (median of crystal), then lay new staff
a0=np.array((5,26.));a1=np.array((125,116.)); yy,xx=np.mgrid[:158,:170]; w=a1-a0
t=np.clip(((xx-a0[0])*w[0]+(yy-a0[1])*w[1])/(w@w),0,1); dd=np.hypot(xx-a0[0]-t*w[0],yy-a0[1]-t*w[1])
band=(dd<6)&(R[...,3]>0); Ru=R.astype(np.uint8)
Ru[...,:3]=cv2.inpaint(Ru[...,:3],band.astype(np.uint8),5,cv2.INPAINT_TELEA)
out=Ru.copy(); m=ST[...,3]==255; out[m]=ST[m]
# glow tip
gl=np.zeros((158,170),np.float32); gl[ST[...,3]==255]=0; gl[0:45,0:50]=(ST[0:45,0:50,3]==255); gl=cv2.GaussianBlur(gl,(0,0),4)*1.1
out[...,:3]=np.clip(out[...,:3]+gl[...,None]*np.array([120,190,255])*(out[...,3:]>0),0,255)
out[...,3]=np.where(out[...,3]>127,255,0); Image.fromarray(out).save('remains_s5_170_v2.png')
# still on arena-ish floor with shadow under the cluster base
W,H=640,440; bg=Image.new('RGBA',(W,H),(36,40,52,255)); sh=Image.new('L',(W,H),0)
ys,xs=np.nonzero(out[...,3]); base=ys.max()
ImageDraw.Draw(sh).ellipse((320-80,250+base-10,320+80,250+base+8),fill=230); sh=sh.filter(ImageFilter.GaussianBlur(7))
bg.paste((10,12,20,255),mask=sh); big=Image.fromarray(out).resize((340,316),Image.NEAREST)
bg.alpha_composite(big,(150,250+2*base-316-180)) if False else None
canvas=bg.copy(); ox,oy=320-85,250+base-157+157-158//1 ; canvas.alpha_composite(Image.fromarray(out),(320-85,250))
canvas.save('remains_still_v2_1x.png'); canvas.crop((160,180,480,440)).resize((640,520),Image.NEAREST).save('remains_still_v2.png')
