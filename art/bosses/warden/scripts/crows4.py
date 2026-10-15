import sys, os, subprocess
sys.path.insert(0,'/workspace/foe_walks/harvest_spell_v1'); os.chdir('/workspace/foe_walks/harvest_v2')
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as nd
import sheet as SH, rig2, rig3, rig4
from rig3 import rot
A_='spell_concepts/assets/'
PP={s:rig4.prep(rig3.build(s)) for s in ('front','back')}
BS=0.31; T_END=3.25; NF=int(T_END*24)
def cl(x): return float(np.clip(x,0,1))
def ease(x): x=cl(x); return x*x*(3-2*x)
def L(p): return Image.open(p).convert('RGBA')
def sc(im,s): return im.resize((max(1,int(im.width*s)),max(1,int(im.height*s))),Image.LANCZOS)
def alpha(im,k): a=np.array(im); a[...,3]=(a[...,3]*cl(k)).astype(np.uint8); return Image.fromarray(a)
def pc(g,im,x,y,k=1): g.alpha_composite(alpha(im,k),(int(x-im.width/2),int(y-im.height/2)))
def rim(im,k):
    # thin gold ember rim on the solid silhouette only (top/forward edges), painted crow kept underneath
    a=np.array(im).astype(float); al=a[...,3]/255; Lm=a[...,:3].mean(-1); mb=nd.binary_fill_holes(nd.binary_opening((al>0.6)&(Lm<28),iterations=1)); lab,n=nd.label(mb)
    if n>1: sz=nd.sum(mb,lab,range(1,n+1)); mb=lab==(sz.argmax()+1)
    m=nd.gaussian_filter(mb.astype(float),0.6)
    e=np.clip(m-nd.grey_erosion(m,size=3),0,1)*(al>0.3)
    sh=np.clip(m-np.roll(m,2,axis=0),0,1)            # bias to the upper edge (lit from the embers above)
    e=np.clip(e*0.5+sh*0.8,0,1)*k
    o=a.copy(); gold=np.array([255,170,64]); w=e[...,None]*0.85
    o[...,:3]=o[...,:3]*(1-w)+gold*w; return Image.fromarray(o.clip(0,255).astype(np.uint8))
CROWS=[L(A_+f'crow{i}.png').transpose(Image.FLIP_LEFT_RIGHT) for i in range(3)]
SMK=L(A_+'smoke.png'); EMB=L(A_+'embers.png')
FEATH=[c.crop(b) for c,b in ((CROWS[0],(10,10,40,40)),(CROWS[1],(20,5,50,35)),(CROWS[0],(40,60,70,90)))]
FEATH=[rim(sc(f,0.85),1.0) for f in FEATH]
def puff(g,x,y,s,k,rot_=0): pc(g,sc(SMK,s).rotate(rot_,expand=True,resample=Image.BICUBIC),x,y,k)
def addglow(g,im,x,y,k):
    gl=SH.glow(alpha(im,k),6,1.3); xy=(x-im.width/2,y-im.height/2); return SH.screen(SH.screen(g,gl,xy,0.7),alpha(im,k),xy,1.0)
def flare(r,k):
    im=Image.new('RGBA',(int(r*7),int(r*7))); d=ImageDraw.Draw(im); c=r*3.5
    for i in range(10,0,-1): d.ellipse([c-r*i/5,c-r*i/5*0.8,c+r*i/5,c+r*i/5*0.8],fill=(255,180,80,int(min(255,48*k))))
    return im.filter(ImageFilter.GaussianBlur(r*0.3))
def boss(side,t,tilt=0,glowk=0.45,swell=0):
    P=PP[side]; R=P['R']; OX,OY=500,300; can=Image.new('RGBA',(1640,1280)); hip=R['hip']; fx0=P['foot'][0]; lead=1 if side=='front' else -1
    def add(im,dx=0,dy=0): can.alpha_composite(im,(int(OX+dx),int(OY+dy)))
    add(P['under'])
    for i,j,s,(cx,y0) in P['strips']:
        a1=lead*3+2.5*np.sin(np.pi*t*2-(4-i)*.5)*lead+swell*lead*(i-2)*1.5   # robe flares outward on the burst
        if j==0: add(rot(s,a1,(cx,hip)))
        else:
            L_=y0-hip; add(rot(s,a1+2*np.sin(np.pi*t*2-(4-i)*.5-1)*lead,(cx,y0)),L_*np.sin(np.radians(-a1)),L_*(np.cos(np.radians(a1))-1))
    hx,hy=P['hand']; pad=400; big=Image.new('RGBA',(640+2*pad,720+2*pad)); big.alpha_composite(P['scy'],(pad,pad))
    pend=4*np.sin(np.pi*t-1.0)*lead
    big=rot(rot(big,pend,(hx+pad,hy+pad)),tilt*lead,(fx0+pad,hip+pad)); add(big,-pad,-pad)
    add(rot(P['upper'],tilt*lead,(fx0,hip)))
    ga=np.array(P['glow']); ga[...,3]=(ga[...,3]*glowk).astype(np.uint8); add(rot(Image.fromarray(ga),tilt*lead,(fx0,hip)))
    add(rot(P['head'],tilt*lead,(fx0,hip)))
    return can,(OX+fx0,OY+P['foot'][1])
def bez(p0,p1,p2,u): return ((1-u)**2*p0[0]+2*(1-u)*u*p1[0]+u*u*p2[0],(1-u)**2*p0[1]+2*(1-u)*u*p1[1]+u*u*p2[1])
FLW=rig2.floor('w',0); FLE=rig2.floor('e',0)
def tile(base,t):
    W=base=='w'; side='front' if W else 'back'; Ld=SH.LAY[base]
    ox_=480-(175 if W else 225); oy_=20 if W else -10
    BP=(Ld['b'][0]+ox_,Ld['b'][1]+oy_); IJ=(Ld['ij'][0]+ox_,Ld['ij'][1]+oy_); KE=(Ld['ke'][0]+ox_,Ld['ke'][1]+oy_)
    g=(FLW if W else FLE).copy()
    cast=ease((t-0.15)/0.4)*(1-ease((t-0.9)/0.4)); hit=1.45<t<2.45
    # boss
    im,(fx,fy)=boss(side,t,tilt=-3*cast,glowk=0.45+0.5*cast+0.25*cl(1-abs(t-0.6)/0.3),swell=cast)
    h=17+3*np.sin(np.pi*t)+6*cast; s=BS; imr=sc(im,s); bx,by=BP[0]-fx*s,BP[1]-fy*s-h
    chest=(BP[0]+(-4 if W else 4),BP[1]-h-(118 if W else 112))
    tg=[(IJ[0],IJ[1]-118),(KE[0],KE[1]-108)]
    k=1-(h-15)/20*.4; sh=Image.new('RGBA',g.size); sw=44*k
    ImageDraw.Draw(sh).ellipse([BP[0]-sw,BP[1]-sw*.28,BP[0]+sw,BP[1]+sw*.28],fill=(0,0,0,int(110*k))); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    # crows
    NC=7; crows=[]
    for i in range(NC):
        t0=0.5+0.075*i; u=(t-t0)/0.85; tgt=tg[i%2]
        jit=[(-34,22),(30,10),(-4,-6),(36,34),(-36,44),(6,-14),(14,40)][i]; end=(tgt[0]+jit[0],tgt[1]+jit[1])
        if u<0: continue
        dx=end[0]-chest[0]; ctrl=(chest[0]+dx*0.25+(-1 if W else 1)*(10*(i%3)), chest[1]-130-18*(i%3))
        if u<=1:
            x,y=bez(chest,ctrl,end,ease(u)); x2,y2=bez(chest,ctrl,end,ease(min(1,u+0.04)))
        else:
            w=t-t0-0.85; x=end[0]+7*np.sin(w*14+i)*np.exp(-w*0.5); y=end[1]+6*np.cos(w*17+i)-5*abs(np.sin(w*9+i)); x2,y2=x+(-1 if W else 1),y+0.5*np.sin(w*30+i)
        # crows face their flight; W: plate crow flipped faces left; E: unflipped faces right
        vx_,vy_=x2-x,y2-y; facing=-1 if (vx_<0 if abs(vx_)>0.3 else W) else 1
        ang=np.degrees(np.arctan2(-vy_,abs(vx_)+1e-6))*1.0; ang=float(np.clip(ang,-40,40))
        fade=1-ease((t-2.3-0.04*i)/0.45); sz=(0.34+0.06*(i%3))*min(1,0.35+u*2)*(1-0.35*cl((u-0.8)/0.3))
        crows.append((y,i,x,y,ang,sz,fade,u,facing))
    def drawcrow(g,c,front):
        _,i,x,y,ang,sz,fade,u,facing=c
        if fade<=0: return
        if u<1.1 and not front: puff(g,x-facing*18,y+4,0.12+0.06*min(u,1),0.6*fade,rot_=80)
        cim=CROWS[i%3] if facing<0 else CROWS[i%3].transpose(Image.FLIP_LEFT_RIGHT)
        rk=0.15+0.6*cl((u-0.8)/0.3)     # rim brightens as they land
        cim=rim(sc(cim,sz),rk).rotate(ang*(-facing),expand=True,resample=Image.BICUBIC)
        pc(g,cim,x,y,fade)
        if fade<0.9: puff(g,x,y,0.13,min(1,0.8*(1-fade)*fade*3),rot_=40*i)
    for c in sorted(crows):
        if c[7]<=0.9: drawcrow(g,c,False)
    g.alpha_composite(imr,(int(bx),int(by)))
    # gold flare at the chest as the crows burst out of the robe
    fk=cl(1-abs(t-0.62)/0.35)
    if fk>0:
        g=SH.screen(g,flare(30,1.0),(chest[0]-105,chest[1]-105),fk)
        g=addglow(g,sc(EMB,0.38).rotate(90 if W else -90,expand=True),chest[0],chest[1]-10,fk)
        puff(g,chest[0],chest[1]+20,0.3,0.8*fk,rot_=90)
    for c in sorted(crows):
        if c[7]<=0.9 and c[7]<0.25: drawcrow(g,c,True)   # just-emerged crows in front of the robe
    for cn,pos in sorted((('ij',IJ),('ke',KE)),key=lambda x:x[1][1]):
        hm=SH.hero(cn,'hit' if hit else 'idle',Ld['hk'],1 if hit else 0)
        if hit: hm=SH.tint(hm,0.07)
        SH.put(g,hm,*pos,30)
    for c in sorted(crows):
        if c[7]>0.9: drawcrow(g,c,True)
    if 1.3<t<2.9:
        r=np.random.default_rng(3)
        for kk in range(30):
            tt=1.3+r.random()*0.95; a=(t-tt)/0.95; rs=r.normal(0,1,4); sd=r.choice([-1,1])
            if 0<a<1:
                tgt=tg[kk%2]; x=tgt[0]+rs[0]*22+a*rs[1]*28; y=tgt[1]+rs[2]*12+a*45
                f=FEATH[kk%3].rotate(a*300*sd,expand=True); pc(g,f,x,y,np.sin(np.pi*a))
        k_=np.sin(np.pi*cl((t-1.3)/1.5))
        for tgt in tg: puff(g,tgt[0],tgt[1]+15,0.22,0.55*k_,rot_=90)
    return g
def frame(t):
    S=Image.new('RGB',(1920,1080)); cache={}
    for k,dn in enumerate('nesw'):
        base='w' if dn in 'ws' else 'e'
        if base not in cache: cache[base]=tile(base,t)
        g=cache[base]
        if dn in 'sn': g=g.transpose(Image.FLIP_LEFT_RIGHT)
        g=g.copy(); ImageDraw.Draw(g).text((16,10),dn.upper(),font=rig2.fnt,fill=(255,236,170,255),stroke_width=4,stroke_fill=(0,0,0,255))
        S.paste(g.convert('RGB'),((k%2)*rig2.QW,(k//2)*rig2.QH))
    return S
if __name__=='__main__':
    if len(sys.argv)>1:
        for t in [float(x) for x in sys.argv[1].split(',')]: frame(t).save(f'/tmp/c4_{t}.png')
        sys.exit()
    d='/tmp/_c4'; os.makedirs(d,exist_ok=True)
    for i in range(NF): frame(i/24).save(f'{d}/{i:04d}.png')
    subprocess.run(f'ffmpeg -y -loglevel error -framerate 24 -i {d}/%04d.png -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 16 -movflags +faststart /workspace/foe_walks/harvest_v2/warden_spell_crows_4dir.mp4',shell=True,check=True)
