import sys; sys.path.insert(0,'/workspace/foe_walks/coilspire_v2/spell_v1')
from sheet import *
os.chdir('/workspace/foe_walks/coilspire_v2/hitdeath_v1')
R=RIG['front']; A=R['a']
def crop_rgba(a):
    ys,xs=np.nonzero(a[...,3]>0); return Image.fromarray(a[ys.min():ys.max()+1,xs.min():xs.max()+1])
legs=[crop_rgba(l['src']) for l in R['legs']]
skull=A[290:480,150:340].copy(); yy,xx=np.mgrid[290:480,150:340]
skull[((xx-245)/95)**2+((yy-392)/88)**2>1]=0; skull=crop_rgba(skull)
sp=A[0:250,300:460].copy(); c_=sp[...,:3].astype(int); sat=c_.max(-1)-c_.min(-1); L_=c_.mean(-1)
sp[(sat<25)&(L_>60)]=0; spine=crop_rgba(sp)
W0,H0=620,400; C=Image.new('RGBA',(W0,H0))
rng=np.random.default_rng(3)
# legs lying in a heap, crossing (6 legs)
ang=[78,-70,95,-100,62,-58]; pos=[(170,215),(440,210),(250,235),(370,235),(210,250),(410,252)]
for L,a,p in zip(legs,ang,pos):
    L2=L.resize((int(L.width*0.75),int(L.height*0.75)),Image.LANCZOS).rotate(a,expand=True,resample=Image.BICUBIC)
    C.alpha_composite(L2,(int(p[0]-L2.width/2),int(p[1]-L2.height/2)))
# cracked spine: two broken pieces lying across the heap
s1=spine.crop((0,0,spine.width,spine.height//2)); s2=spine.crop((0,spine.height//2,spine.width,spine.height))
for s,a,p in ((s2,-62,(390,175)),(s1,-48,(495,150))):
    s=s.resize((int(s.width*0.8),int(s.height*0.8)),Image.LANCZOS).rotate(a,expand=True,resample=Image.BICUBIC); C.alpha_composite(s,(int(p[0]-s.width/2),int(p[1]-s.height/2)))
sk=skull.resize((int(skull.width*0.85),int(skull.height*0.85)),Image.LANCZOS).rotate(-8,expand=True,resample=Image.BICUBIC)
C.alpha_composite(sk,(int(300-sk.width/2),int(185-sk.height/2)))
a=np.array(C); a[a[...,3]<128]=0; a[a[...,3]>0,3]=255
m=a[...,3]>0
# rim light: lilac on the upper-left edges, plus an inner violet glow from the cracks
edge=m&~nd.binary_erosion(m,iterations=2); up=np.roll(m,4,0)&~m  # unused helper
sh=m&~np.roll(np.roll(m,3,0),3,1)
c=a[...,:3].astype(np.float32); c[sh]=c[sh]*0.4+np.array([190,150,255])*0.6; c[m]*=1.15
a[...,:3]=np.clip(c,0,255).astype(np.uint8); out=Image.fromarray(a)
glow=Image.fromarray((m*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10)); gl=Image.new('RGBA',out.size,(140,70,230,0)); gl.putalpha(glow.point(lambda v:int(v*0.45)))
fin=Image.new('RGBA',out.size); fin.alpha_composite(gl); fin.alpha_composite(out)
fin.save('remains_raw.png'); print(fin.size)
