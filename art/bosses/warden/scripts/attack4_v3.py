import sys, os, subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import crows4 as C4
from crows4 import SH, sc, alpha, pc, puff, cl, PP, SMK
from rig3 import rot
import rig2
def ease(x): x=cl(x); return x*x*(3-2*x)
MELEE=float(os.environ.get('MELEE','1.0')); T=3.0; NF=int(T*24); BS=0.31
# E fix: the back key's own blade hooks down; use the front scythe mirrored (blade opens toward travel), seated in the back hand
fs=np.array(PP['front']['scy']); ms=fs[:,::-1].copy(); fh=PP['front']['hand']; bh=PP['back']['hand']
dx=int(bh[0]-(640-fh[0])); dy=int(bh[1]-fh[1]); ms=np.roll(np.roll(ms,dx,axis=1),dy,axis=0)
SCY={'front':PP['front']['scy'],'back':Image.fromarray(ms)}
def boss(side,t,pend,tilt,glowk,swell):
    P=PP[side]; R=P['R']; OX,OY=500,300; can=Image.new('RGBA',(1640,1280)); hip=R['hip']; fx0=P['foot'][0]; lead=1 if side=='front' else -1
    def add(im,dx=0,dy=0): can.alpha_composite(im,(int(OX+dx),int(OY+dy)))
    add(P['under'])
    for i,j,s,(cx,y0) in P['strips']:
        a1=lead*3+2.5*np.sin(np.pi*t*2-(4-i)*.5)*lead+swell*lead*(i-2)*1.5
        if j==0: add(rot(s,a1,(cx,hip)))
        else:
            L_=y0-hip; add(rot(s,a1+2*np.sin(np.pi*t*2-(4-i)*.5-1)*lead,(cx,y0)),L_*np.sin(np.radians(-a1)),L_*(np.cos(np.radians(a1))-1))
    hx,hy=P['hand']; pad=400; big=Image.new('RGBA',(640+2*pad,720+2*pad)); big.alpha_composite(SCY[side],(pad,pad))
    big=rot(rot(big,pend*lead,(hx+pad,hy+pad)),tilt*lead,(fx0+pad,hip+pad)); add(big,-pad,-pad)
    add(rot(P['upper'],tilt*lead,(fx0,hip)))
    ga=np.array(P['glow']); ga[...,3]=(ga[...,3]*glowk).astype(np.uint8); add(rot(Image.fromarray(ga),tilt*lead,(fx0,hip)))
    add(rot(P['head'],tilt*lead,(fx0,hip)))
    th=np.radians(tilt*lead); px,py=hx-fx0,hy-hip
    hxr=fx0+px*np.cos(th)+py*np.sin(th); hyr=hip-px*np.sin(th)+py*np.cos(th)
    return can,(OX+fx0,OY+P['foot'][1]),(OX+hxr,OY+hyr)
def _tip(side):
    a=np.array(SCY[side])[...,3]; hx,hy=PP[side]["hand"]; a[int(hy)-40:]=0; ys,xs=np.nonzero(a>40); k=(xs.argmin() if side=="front" else xs.argmax()); return xs[k],ys[k]  # blade point = outermost pixel of the head
TIP={k:_tip(k) for k in SCY}
def tip_at(side,pend,tilt):
    # same transforms as boss(): rotate about hand by pend*lead (PIL CCW), then about hip by tilt*lead
    P=PP[side]; lead=1 if side=='front' else -1; hx,hy=P['hand']; fx0=P['foot'][0]; hip=P['R']['hip']; OX,OY=500,300
    def R(x,y,cx,cy,a):
        a=np.radians(a); dx,dy=x-cx,y-cy; return cx+dx*np.cos(a)+dy*np.sin(a), cy-dx*np.sin(a)+dy*np.cos(a)  # PIL CCW in y-down
    x,y=R(*TIP[side],hx,hy,pend*lead); x,y=R(x,y,fx0,hip,tilt*lead); return OX+x,OY+y
_s=np.array(SMK).astype(float); _s[...,:3]=_s[...,:3]*0.12+4; BSMK=Image.fromarray(_s.astype(np.uint8))
FLW=rig2.floor('w',0); FLE=rig2.floor('e',0)
def pend_of(t):
    w=ease((t-0.45)/0.55)                       # wind-up: draw back
    s=ease((t-1.05)/0.32)                       # slash
    r=ease((t-1.75)/0.8)                        # recover
    return (-38*w*(1-s)+74*s)*(1-r)
def tile(base,t):
    W=base=='w'; side='front' if W else 'back'; Ld=SH.LAY[base]; lead=1 if W else -1
    ox_=480-(175 if W else 225); oy_=20 if W else -10
    IJ=(Ld['ij'][0]+ox_,Ld['ij'][1]+oy_); KE=(Ld['ke'][0]+ox_,Ld['ke'][1]+oy_)
    FD=np.array([-rig2.TW/2,rig2.TH/2] if W else [rig2.TW/2,-rig2.TH/2])   # one tile along facing
    BP=np.array(IJ,float)-FD*MELEE; tg=BP+FD
    g=(FLW if W else FLE).copy()
    wind=ease((t-0.45)/0.55)*(1-ease((t-1.05)/0.3)); s=ease((t-1.05)/0.32); rcv=ease((t-1.75)/0.8)
    lunge=(-0.05*wind+0.15*s)*(1-rcv)
    pos=BP+FD*lunge
    pend=pend_of(t); tilt=-4*wind+6*s*(1-rcv)
    h=17+3*np.sin(np.pi*t)+10*wind+4*s*(1-rcv)
    im,(fx,fy),(hx,hy)=boss(side,t,pend,tilt,0.45+0.25*wind+0.3*s*(1-rcv),swell=1.2*wind+0.6*s*(1-rcv))
    imr=sc(im,BS); ox,oy=pos[0]-fx*BS,pos[1]-fy*BS-h; HX,HY=ox+hx*BS,oy+hy*BS
    hit=1.38<t<1.95
    def draw_boss(g):
        k=1-(h-15)/25*.4; sh=Image.new('RGBA',g.size); sw=44*k
        ImageDraw.Draw(sh).ellipse([pos[0]-sw,pos[1]-sw*.28,pos[0]+sw,pos[1]+sw*.28],fill=(0,0,0,int(110*k))); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
        # smoke wake during the glide
        if 1.0<t<2.2:
            for i in range(5): puff(g,pos[0]-(tg-BP)[0]*0.12*i*s*(1-rcv),pos[1]-h-8-(tg-BP)[1]*0.06*i*s,0.1+0.03*i,0.5*s*(1-rcv)*(1-i/6),rot_=90)
        g.alpha_composite(imr,(int(ox),int(oy)))
    items=[(IJ[1],'ij'),(KE[1],'ke'),(pos[1],'b')]
    for _,c in sorted(items):
        if c=='b': draw_boss(g)
        else:
            if c=='ij' and hit: hm=SH.tint(SH.hero('ij','hit',Ld['hk'],min(3,int((t-1.38)/0.57*4))),0.07)
            else: hm=SH.hero(c,'idle',Ld['hk'],0)
            SH.put(g,hm,*Ld[c] if False else (IJ if c=='ij' else KE),30)
    # painted gold arc: trails the blade tip from the top of the wind-up to the current blade angle
    if 1.05<t<2.0:
        R_=150*BS*1.9; a_now=90+pend; a0=90-38
        fade=1-ease((t-1.5)/0.5)
        lay=Image.new('RGBA',g.size); rimL=Image.new('RGBA',g.size); d=ImageDraw.Draw(lay); r=np.random.default_rng(4)
        tilt_now=tilt; pv=np.linspace(-38,pend,60)
        pts=[]
        for p in pv:
            x,y=tip_at(side,p,tilt_now); X,Y=ox+x*BS,oy+y*BS
            if not W: pass
            pts.append((X,Y))
        pts=np.array(pts); n=len(pts)
        # BLACK wave: painted smoke stamps (darkened) along the tip path + dark strokes, faint purple/ember rim
        for kk in range(46):
            f=(kk/45)**0.8; i=min(n-1,int(f*(n-1))); P0=pts[i]; v=P0-np.array((HX,HY)); rr=np.hypot(*v)+1e-6
            Q=P0-v/rr*(r.uniform(0,14)*f); ang=np.degrees(np.arctan2(-v[1],v[0]))
            st=sc(BSMK,0.07+0.07*f).rotate(ang+r.uniform(-25,25),expand=True,resample=Image.BICUBIC)
            k_=(0.35+0.65*f)*fade; xy=(int(Q[0]-st.width/2),int(Q[1]-st.height/2))
            rimL.alpha_composite(alpha(st,k_),xy); lay.alpha_composite(alpha(st,k_),xy)
        for kk in range(260):
            f=r.random()**0.6; i=min(n-2,int(f*(n-1))); P0=pts[i]; P1=pts[i+1]
            v=P0-np.array((HX,HY)); rr=np.hypot(*v)+1e-6; Q=P0-v/rr*abs(r.normal(0,1))*10*f
            dv=P1-P0; dl=np.hypot(*dv)+1e-6; L=r.uniform(8,20)
            d.line([Q[0],Q[1],Q[0]+dv[0]/dl*L,Q[1]+dv[1]/dl*L],fill=[(8,6,10),(20,14,22),(34,22,34)][r.choice([0,1,2],p=[.6,.3,.1])]+(int(255*(0.3+0.7*f)*fade),),width=int(r.integers(2,5)))
        lay=lay.filter(ImageFilter.GaussianBlur(0.7))
        A_=np.array(lay)[...,3].astype(float); E_=np.array(Image.fromarray(A_.astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(2.5))).astype(float)
        edge=np.clip(E_-A_*0.85,0,255); rim=np.zeros(A_.shape+(4,),np.uint8); rim[...,0]=120; rim[...,1]=44; rim[...,2]=150; rim[...,3]=(edge*0.75).astype(np.uint8)
        # ember flecks on the leading 30% only
        g=SH.screen(g,Image.fromarray(rim),(0,0),1.0); g.alpha_composite(lay)
        for kk in range(40):
            f=0.7+0.3*r.random(); P0=pts[min(n-1,int(f*(n-1)))]; e=r.normal(0,6,2)
            ImageDraw.Draw(g).point((P0[0]+e[0],P0[1]+e[1]),fill=(200,80,40,int(200*fade)))
    if 1.38<t<1.8:   # small painted impact on Ironjaw
        u=(t-1.38)/0.42; v=SH.L('/workspace/foe_walks/harvest_spell_v1/plates/VORT_plate.png').resize((int(70+40*u),int(40+24*u)),Image.LANCZOS)
        va=np.array(v).astype(float); lum=va[...,:3].max(-1)/255; dk=np.zeros_like(va); dk[...,:3]=10; dk[...,3]=va[...,3]*lum*0.85*(1-u)
        xy=(int(IJ[0]-v.width/2),int(IJ[1]-60-v.height/2)); g.alpha_composite(Image.fromarray(dk.astype(np.uint8)),xy)
        pu=va.copy(); pu[...,0]=pu[...,0]*0.35; pu[...,1]*=0.12; pu[...,2]=pu[...,2]*0.0+lum*150; g=SH.screen(g,alpha(Image.fromarray(np.clip(pu,0,255).astype(np.uint8)),(1-u)*0.35),xy,1.0)
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
        for t in [float(x) for x in sys.argv[1].split(',')]: frame(t).save(f'/tmp/a4v3_{t}.png')
        sys.exit()
    d='/tmp/_a4v3'; os.makedirs(d,exist_ok=True)
    for i in range(NF): frame(i/24).save(f'{d}/{i:04d}.png')
    subprocess.run(f'ffmpeg -y -loglevel error -framerate 24 -i {d}/%04d.png -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 16 -movflags +faststart /workspace/foe_walks/harvest_v2/warden_attack_4dir_v3.mp4',shell=True,check=True)
