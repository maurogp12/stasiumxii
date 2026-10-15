import sys; sys.path.insert(0,'/workspace/foe_walks/coilspire_v2'); import os; os.chdir('/workspace/foe_walks/coilspire_v2')
from anim import *
from PIL import ImageChops
src=open('/workspace/foe_walks/serra_v2/hitdeath_v3/vid.py').read()
exec(src[src.index('def cells'):src.index('SR=')]); exec(src[src.index('CH_='):src.index('# timeline')].replace("('idle','attack')","('idle','hit')"))
os.chdir('/workspace/foe_walks/coilspire_v2/attack_v1')
TIP={'front':(408,6),'back':(185,6)}; ORB={'front':[(248,313),(225,385)],'back':[]}
PAD=90
def pose(side,rear,lift,lunge,charge,pin=True):
    R=RIG[side]; a=R['a']; xx,yy=R['xx'],R['yy']; u=u_of(side); H,W=R['H'],R['W']
    fwd=np.array([np.sign(u[0]),0.])
    proj=[(l['tip']-np.array([W/2,0]))@fwd for l in R['legs']]; med=np.median(proj)
    out=a.copy(); lm=np.zeros(a.shape[:2],bool)
    for l in R['legs']: lm|=l['mask']
    out[lm]=0
    legs=[]
    for l,p in zip(R['legs'],proj):
        front=p>med; w=l['w']
        dy=-(lift if front else 0)*np.clip(w/0.5,0,1)        # front legs raise (knee leads)
        dx=(fwd[0]*lift*0.35 if front else 0)*w
        o0=D*(0.5 if l['g']==0 else -0.5); dx=dx+w*u[0]*o0; dy=dy+w*u[1]*o0   # rest = walk frame 0
        o=cv2.remap(l['src'],(xx-dx).astype(np.float32),(yy-dy).astype(np.float32),cv2.INTER_LINEAR,borderValue=(0,0,0,0))
        al=o[...,3]>=128; o[~al]=0; o[al,3]=255; legs.append((l['behind'],al,o,front,l,np.array([l['tip'][0]+u[0]*o0,l['tip'][1]+u[1]*o0])))
    for b,al,o,*_ in legs:
        if b: put=al&(out[...,3]==0); out[put]=o[put]
    # body rears: rotate about the hind ground point, front lifts (rear>0) or dips (rear<0)
    piv=(W/2-fwd[0]*W*0.3,R['gy']); ang=rear*fwd[0]   # deg; + lifts the front side
    P=PAD; M=cv2.getRotationMatrix2D(piv,ang,1.0); M[0,2]+=fwd[0]*lunge+P; M[1,2]+=P
    body=cv2.warpAffine(out,M,(W+2*P,H+2*P),flags=cv2.INTER_LINEAR,borderValue=(0,0,0,0))
    out=body
    for b,al,o,front,l,tip0 in legs:
        if not b:
            o2=cv2.warpAffine(o,M,(W+2*P,H+2*P),flags=cv2.INTER_LINEAR,borderValue=(0,0,0,0))
            if pin and not front:   # hind legs: solve so the tip stays where it was on the ground
                tw=M@np.array([tip0[0],tip0[1],1.]); d=np.array([tip0[0]+P,tip0[1]+P])-tw
                w2=cv2.warpAffine(l['w'],M,(W+2*P,H+2*P)); X,Y=np.meshgrid(np.arange(W+2*P,dtype=np.float32),np.arange(H+2*P,dtype=np.float32))
                o2=cv2.remap(o2,(X-w2*d[0]).astype(np.float32),(Y-w2*d[1]).astype(np.float32),cv2.INTER_LINEAR,borderValue=(0,0,0,0))
            # planted (hind) legs keep tips on the ground: blend warped near hip, original near tip
            out_al=o2[...,3]>=128; out[out_al]=o2[out_al]; out[out_al,3]=255
    out[out[...,3]<128]=0; out[out[...,3]>0,3]=255
    c=out[...,:3].astype(np.float32); pm=cv2.warpAffine(R['purple'].astype(np.uint8),M,(W+2*P,H+2*P))>0
    c[pm]=np.clip(c[pm]*(1+0.6*charge),0,255); out[...,:3]=c.astype(np.uint8)
    T=lambda p:M@np.array([p[0],p[1],1.])
    return Image.fromarray(out),T(TIP[side]),[T(p) for p in ORB[side]]
def glowlayer(size,draw,col,blur,al):
    L=Image.new('L',size); draw(ImageDraw.Draw(L)); L=L.filter(ImageFilter.GaussianBlur(blur)) if blur else L
    c=Image.new('RGBA',size,col+(0,)); c.putalpha(L.point(lambda v:int(min(255,v*al)))); return c
def bolt(p0,p1,rng,rough=0.18,n=6):
    pts=[np.array(p0,float),np.array(p1,float)]
    for k in range(n):
        new=[pts[0]]
        for a_,b_ in zip(pts[:-1],pts[1:]):
            d=b_-a_; nn=np.array([-d[1],d[0]]); m=(a_+b_)/2+nn*rng.normal(0,rough)
            new+= [m,b_]
        pts=new; rough*=0.6
    return [tuple(p) for p in pts]
def paint_bolt(g,paths,inten):
    for w,blur,col,al in ((26,14,(120,40,220),0.7),(12,6,(170,90,255),0.9),(5,2,(215,170,255),1.0),(2,0,(250,240,255),1.0)):
        g.alpha_composite(glowlayer(g.size,lambda d:[d.line(p,fill=255,width=max(1,int(w*(0.6 if i else 1)))) for i,p in enumerate(paths)],col,blur,al*inten))
def glow(g,c,r,inten,col=(170,90,255)):
    g.alpha_composite(glowlayer(g.size,lambda d:d.ellipse([c[0]-r,c[1]-r,c[0]+r,c[1]+r],fill=255),col,r*0.5,inten))
    g.alpha_composite(glowlayer(g.size,lambda d:d.ellipse([c[0]-r*.3,c[1]-r*.3,c[0]+r*.3,c[1]+r*.3],fill=255),(245,230,255),r*0.15,inten))
def sparks(g,c,rng,inten):
    paths=[]
    for k in range(9):
        a_=rng.uniform(0,6.28); r=rng.uniform(18,38); paths.append(bolt(c,(c[0]+r*np.cos(a_),c[1]+r*np.sin(a_)*0.7),rng,0.25,3))
    paint_bolt(g,paths,inten*0.8); glow(g,c,26,inten)
def tint(im,k):
    a=np.array(im).astype(np.float32); m=a[...,3]>0; a[m,:3]=a[m,:3]*(1-k)+np.array([200,170,255])*k; return Image.fromarray(a.astype(np.uint8))
# key poses: rear deg, front lift, lunge px(raw), charge, phase
KP=[('1 WIND-UP',14,110,-20,1.0,'charge'),('2 STRIKE',-5,0,40,1.0,'bolt'),('3 IMPACT',-3,0,34,0.6,'impact'),('4 RECOVER',2,10,10,0.15,'rest')]
BIG=Image.new('RGBA',(2400,1600),(16,18,24,255)); _d=ImageDraw.Draw(BIG)
for i in range(-30,31):
    for j in range(-30,31):
        x=1200+(i-j)*TWp/2; y=842+(i+j)*THp/2
        _d.polygon([(x,y-THp/2),(x+TWp/2,y),(x,y+THp/2),(x-TWp/2,y)],fill=(38,42,54,255) if (i+j)%2 else (30,34,44,255),outline=(48,54,68,255))
fnt2=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',30)
def scene(dn,kp):
    name,rear,lift,lunge,charge,ph=kp; side,mir=MAP[dn]; R=RIG[side]; rng=np.random.default_rng(7)
    g=Image.new('RGBA',(2400,1600)); dv=np.array(DV[dn],float); dv/=np.linalg.norm(dv)
    C=np.array([1200,820])-dv*60; bp=C+dv*0; tp=C+dv*245
    Tg={'ij':tp+np.array([-55,-6]),'ke':tp+np.array([55,6])}
    im,tip,orbs=pose(side,rear,lift,lunge,charge)
    if mir: im=im.transpose(Image.FLIP_LEFT_RIGHT); tip=(R['W']+2*PAD-tip[0],tip[1]); orbs=[(R['W']+2*PAD-o[0],o[1]) for o in orbs]
    im=im.resize((round(im.width*K),round(im.height*K)),Image.LANCZOS); ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K
    S=lambda p:(ox+p[0]*K,oy+p[1]*K)
    sh=Image.new('RGBA',g.size); sw=R['W']*K*0.62; ImageDraw.Draw(sh).ellipse([bp[0]+dv[0]*lunge*K*0.5-sw/2,bp[1]-4-sw*.13,bp[0]+dv[0]*lunge*K*0.5+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    items=[(bp[1],im,(round(ox),round(oy)))]
    for c,p in Tg.items():
        v=CH_[c]; hit=ph=='impact'; fs=SP[(c,'hit' if hit else 'idle',TF[dn])]; hm=fs[1] if hit else fs[0]
        if hit: hm=tint(hm,0.1)
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
    for _,i_,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(i_,xy)
    st=S(tip)
    if ph=='charge':
        for o in orbs: glow(g,S(o),30,0.8)
        sp=[bolt((st[0]+rng.normal(0,8),st[1]+40),(st[0]+rng.normal(0,30),st[1]+130),rng,0.3,4) for _ in range(3)]
        paint_bolt(g,sp,0.7); glow(g,st,34,1.0)
    if ph in('bolt','impact'):
        hits=[(p[0],p[1]-60) for p in Tg.values()]; mid=(np.array(st)+np.mean(hits,0))/2-np.array([0,70])
        trunk=bolt(st,tuple(mid),rng,0.22); paths=[trunk]+[bolt(tuple(mid),h,rng,0.2) for h in hits]
        paint_bolt(g,paths,1.0 if ph=='bolt' else 0.45); glow(g,st,40,1.0)
        for o in orbs: glow(g,S(o),24,0.6)
        if ph=='impact':
            for h in hits: sparks(g,h,rng,1.0)
        else:
            for h in hits: glow(g,h,20,0.7)
    if ph=='rest': glow(g,st,14,0.35)
    bb=im.getbbox(); xs_=[ox+bb[0],ox+bb[2]]+[p[0]+v for p in Tg.values() for v in (-60,60)]; ys_=[oy+bb[1],oy+bb[3]]+[p[1]-150 for p in Tg.values()]+[p[1]+15 for p in Tg.values()]
    if ph in('bolt','impact','charge'): ys_.append(st[1]-45)
    w_=max(480,max(xs_)-min(xs_)+40,(max(ys_)-min(ys_)+70)*480/540); h_=w_*540/480
    cx=(max(xs_)+min(xs_))/2; cy=(max(ys_)+min(ys_))/2+10
    big=BIG.copy(); big.alpha_composite(g,(0,0))
    g=big.crop((int(cx-w_/2),int(cy-h_/2),int(cx+w_/2),int(cy+h_/2))).resize((480,540),Image.LANCZOS)
    d=ImageDraw.Draw(g); d.text((14,10),f'{dn.upper()}  {name}',font=fnt2,fill=(220,235,255,255),stroke_width=3,stroke_fill=(0,0,0,255)); return g
if __name__=='__main__':
    Sh=Image.new('RGB',(1920,1080))
    for r,dn in enumerate('we'):
        for c,kp in enumerate(KP): Sh.paste(scene(dn,kp).convert('RGB'),(c*480,r*540))
    Sh.save('coilspire14_attack_stills_WE.png'); print('ok')
