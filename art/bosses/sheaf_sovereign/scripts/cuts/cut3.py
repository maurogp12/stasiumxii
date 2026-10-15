import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFilter
pl=np.array(Image.open('sov_hands_v2_plate.jpg').convert('RGB')).astype(float); H,W=pl.shape[:2]
O=(60,120)
def P(pts): return [(x+O[0],y+O[1]) for x,y in pts]
POLY={
 'h1':P([(160,40),(200,30),(250,45),(262,110),(258,200),(275,300),(330,420),(350,520),(205,520),(185,420),(160,300),(140,200),(150,90)]),
 'h2':P([(250,215),(300,200),(360,220),(372,300),(395,440),(405,520),(290,520),(275,420),(258,320)]),
 'h3':P([(330,40),(380,30),(420,50),(440,140),(460,230),(470,300),(540,380),(565,520),(425,520),(400,420),(400,320),(388,240),(360,150),(335,80)]),
}
def mask(pts,fe=5):
    im=Image.new('L',(W,H)); ImageDraw.Draw(im).polygon(pts,fill=255); m=np.array(im.filter(ImageFilter.GaussianBlur(fe))).astype(float)/255
    return m
r,g,b=pl[...,0],pl[...,1],pl[...,2]; lum=pl.mean(-1)
Yh,Xh=np.mgrid[0:H,0:W]
ijbox=(Xh>262)&(Xh<452)&(Yh>185)&(Yh<385); kebox=(Xh>455)&(Xh<610)&(Yh>265)&(Yh<405)
hero=(ijbox&(r>g*1.9)&(r>b*1.6)&(r>60))|(kebox&(g>r*0.95)&(g>b*1.3)&(g>50))
hero=cv2.morphologyEx(hero.astype(np.uint8),cv2.MORPH_CLOSE,np.ones((9,9),np.uint8)); hero=cv2.dilate(hero,np.ones((5,5),np.uint8))
hero=cv2.GaussianBlur(hero.astype(np.float32),(0,0),2)
gold=np.clip((r-b-25)/50,0,1)
for k,pts in POLY.items():
    m=mask(pts)
    # inside the column keep everything (smoke and straw), fade the bottom 60 px into the ground
    ys,xs=np.nonzero(m>0.01); y0,y1,x0,x1=ys.min(),ys.max(),xs.min(),xs.max()
    Y=np.arange(H)[:,None]; bot=np.clip((y1-Y)/70,0,1)
    a=m*bot*(1-hero*1.0)
    # soften flat cobble patches: keep gold or dark-smoke texture, drop mid-grey flat floor near edges
    edge=np.clip((m-0.0)/0.6,0,1)
    a*=np.clip(0.55+gold+np.clip((60-lum)/40,0,1),0,1)*edge+ (1-edge)*0
    out=np.dstack([pl,a*255]).astype(np.uint8)[y0:y1+1,x0:x1+1]
    Image.fromarray(out).save(f'hands_v2/{k}.png')
# spray: embers/sparks above the hands (luminance key, used with screen blend)
sp=pl[60:360,100:620].copy(); k=np.clip((sp.max(-1)-90)/120,0,1); Image.fromarray(np.dstack([sp,k*255]).astype(np.uint8)).save('hands_v2/spray.png')
# burst/rays: the glow fountain under the boss
bu=pl[330:560,760:1080].copy(); k=np.clip((bu.max(-1)-70)/140,0,1)
Y,X=np.mgrid[0:bu.shape[0],0:bu.shape[1]]; k*=np.clip(1-(((X-160)/160)**2+((Y-120)/120)**2),0,1)**0.5
Image.fromarray(np.dstack([bu,k*255]).astype(np.uint8)).save('hands_v2/burst.png')
# rune circle: polar unwrap of the boss-side ring (visible arc -18..80 deg), tiled x4 into a full top-down disc
cx,cy,rx,ry=800,505,262,158; A0,A1=np.radians(-18),np.radians(80)
S=900; Yd,Xd=np.mgrid[0:S,0:S]; R1=1.2; dx=(Xd-S/2)/(S/2/R1); dy=(Yd-S/2)/(S/2/R1); rr=np.hypot(dx,dy); aa=np.mod(np.arctan2(dy,dx),2*np.pi)
seg=np.mod(aa,np.pi/2)/(np.pi/2); segB=np.mod(seg+0.5,1.0); wB=np.clip(1-np.minimum(seg,1-seg)/0.14,0,1)[...,None]
rs=np.where(rr<0.83,0.45+(rr/0.83)*0.38,rr)          # interior compressed onto the cracked ground just inside the band
def samp(sg):
    sa=A0+(A1-A0)*sg; xs=np.clip(cx+rx*rs*np.cos(sa),0,W-1).astype(int); ys=np.clip(cy+ry*rs*np.sin(sa),0,H-1).astype(int); return pl[ys,xs]
col=samp(seg)*(1-wB)+samp(segB)*wB; inside=rr<=R1
k=np.clip((col.max(-1)-80)/110,0,1)
band=(rr>0.83)&(rr<1.2); dark=band*0.55+(rr<=0.83)*0.25
a_=np.clip(np.maximum(k,dark),0,1)*inside*np.clip((R1-rr)/0.03,0,1)
crk=cv2.resize(pl[470:720,300:800].astype(np.float32),(S,S)); ins=(rr<0.86)
kc=np.clip((crk.max(-1)-90)/120,0,1)
col=np.where(ins[...,None],crk,col); a_=np.where(ins,np.maximum(kc,0.3)*np.clip((0.86-rr)/0.04,0,1)+a_*np.clip((rr-0.82)/0.04,0,1),a_)
out=np.dstack([col,a_*255]).astype(np.uint8)
Image.fromarray(out).save('hands_v2/rune_circle_topdown.png')
print('ok')
