# Sheaf Sovereign attack, 4 directions, 3 s: idle -> overhead windup (sickles gather) -> strike (black wave, sickles staggered along the blade path) -> impact -> recover -> idle
import sys, os, subprocess; sys.path.insert(0,'/workspace/foe_walks/harvest_spell_v1')
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import sheet as SH, rig2
from sovatk import PP, boss, BSMK, sickle_img, BS
from crows4 import sc, alpha
T=3.0; NF=72
def ease(x): x=np.clip(x,0,1); return x*x*(3-2*x)
def pend_of(t):
    w=ease((t-0.35)/0.6); s=ease((t-1.0)/0.22); i=ease((t-1.22)/0.18); r=ease((t-1.65)/0.95)
    return (-150*w*(1-s)+(-62)*s*(1-i)+(-38)*i)*(1-r)
def params(t):
    w=ease((t-0.35)/0.6)*(1-ease((t-1.0)/0.22)); s=ease((t-1.0)/0.22); r=ease((t-1.65)/0.95)
    tilt=-5*w+9*s*(1-r); lift=10*w+3*s*(1-r); gk=0.35+0.2*w+0.45*s*(1-r)
    return pend_of(t),tilt,lift+2*np.sin(2*np.pi*t/T),gk,w,s,r
FLW=rig2.floor('w',0); FLE=rig2.floor('e',0)
def tile(base,t):
    W=base=='w'; side='front' if W else 'back'; lead=1 if W else -1; dn=base
    Ld=SH.LAY[dn]; ox_=480-(175 if W else 225); oy_=20 if W else 45
    IJ=np.array(Ld['ij'],float)+[ox_,oy_]; KE=(Ld['ke'][0]+ox_,Ld['ke'][1]+oy_)
    BP=IJ+(np.array([48,-24]) if W else np.array([-96,0]))
    pend,tilt,lift,gk,w,s,r=params(t)
    im,(fx,fy),(hx,hy),tipf=boss(side,lead,pend,tilt,gk,t)
    im=im.resize((int(im.width*BS),int(im.height*BS)),Image.LANCZOS)
    h=17+lift; ox,oy=BP[0]-fx*BS,BP[1]-fy*BS-h
    def tipat(p,tl=tilt):
        x,y=tipf(p); return np.array([ox+x*BS,oy+y*BS])
    H=np.array([ox+hx*BS,oy+hy*BS])
    g=(FLW if W else FLE).copy()
    k=1-(h-15)/20*.4; shd=Image.new('RGBA',g.size); sw=50*k
    ImageDraw.Draw(shd).ellipse([BP[0]-sw,BP[1]-sw*.28,BP[0]+sw,BP[1]+sw*.28],fill=(0,0,0,int(115*k))); g.alpha_composite(shd.filter(ImageFilter.GaussianBlur(5)))
    lay=Image.new('RGBA',g.size)
    for kk in range(6):
        p=sc(BSMK.rotate(kk*60+t*40,expand=True),0.05+0.012*kk); lay.alpha_composite(alpha(p,0.5+0.1*np.sin(t*3+kk)),(int(BP[0]+lead*(kk*9-20)-p.width/2),int(BP[1]-h-4-p.height/2)))
    g.alpha_composite(lay)
    # sickles: blend orbit -> gathered ring -> staggered along blade path -> wide orbit -> orbit
    cx0,cy0=BP[0],BP[1]-h-115; rx,ry=88,28
    strike_w=ease((t-0.95)/0.12)*(1-ease((t-1.55)/0.35))
    SK=[]
    for i in range(6):
        a=2*np.pi*i/6+2*np.pi*t/4.0
        orb=np.array([cx0+rx*np.cos(a),cy0+ry*np.sin(a)-18*np.cos(a)]); zo=np.sin(a); ango=8*np.sin(t*3+i)
        b=2*np.pi*i/6+t*3; ring=np.array([cx0+lead*70+46*np.cos(b),cy0-30+20*np.sin(b)]); angr=-lead*np.degrees(b)*0.3+30*lead
        # path: each sickle trails the tip by its own delay; radial stagger so they fan out (W inside/outside alternating)
        lag=0.075*(i+1); pp=pend_of(t-lag); P0=tipat(pp); P1=tipat(pend_of(t-lag+0.02))
        vv=P0-H; vv/=np.hypot(*vv)+1e-6
        off=([-34,6,-14,22,-26,14][i]) if W else 30+6*i
        if W: off=[30,58,38,66,46,74][i]   # W: staggered inward so they stay clear of the blade and inside the cell
        path=P0+vv*off; d_=P1-P0; angp=np.degrees(np.arctan2(-d_[1],d_[0]+1e-6))-90
        wr=w*(1-strike_w); wp=strike_w; wo=1-wr-wp
        pos=orb*wo+ring*wr+path*wp
        if r>0 and wp<0.5: pos=pos+ (pos-np.array([cx0,cy0]))*0.25*np.sin(np.pi*r)
        z=zo*wo+np.sin(b)*wr+1*wp; ang=ango*wo+angr*wr+angp*wp
        SK.append((z,i,pos,ang,wp))
    def draw_sick(front):
        for z,i,pos,ang,wp in sorted(SK,key=lambda q:q[0]):
            if (z>=0)!=front: continue
            x,y=pos
            if wp>0.3:
                for q,kq in ((1,0.2),(2,0.09)):
                    tq=sickle_img(side,i,ang-lead*14*q,BS*1.05,1.0,kq*wp); g.alpha_composite(tq,(int(x+lead*9*q-tq.width/2),int(y-7*q-tq.height/2)))
            sI=sickle_img(side,i,ang,BS*1.05,1.0 if z>=0 else 0.75); g.alpha_composite(sI,(int(x-sI.width/2),int(y-sI.height/2)))
    draw_sick(False)
    g.alpha_composite(im,(int(ox),int(oy)))
    # black smoke wave along the tip path (draws on during the strike, fades after impact)
    if 1.0<t<2.0:
        fade=1-ease((t-1.45)/0.5); pv=np.linspace(-150,pend,40); path=np.array([tipat(p) for p in pv]); n=len(path)
        wl=Image.new('RGBA',g.size); d=ImageDraw.Draw(wl); rr_=np.random.default_rng(4)
        for kk in range(60):
            f=(kk/59)**0.8; P0=path[min(n-1,int(f*(n-1)))]; v=P0-H; rr=np.hypot(*v)+1e-6
            Qp=P0-v/rr*rr_.uniform(0,26)*f; an=np.degrees(np.arctan2(-v[1],v[0]))
            st=sc(BSMK,0.08+0.09*f).rotate(an+rr_.uniform(-25,25),expand=True,resample=Image.BICUBIC)
            wl.alpha_composite(alpha(st,(0.3+0.7*f)*fade),(int(Qp[0]-st.width/2),int(Qp[1]-st.height/2)))
        for kk in range(320):
            f=rr_.random()**0.6; i_=min(n-2,int(f*(n-1))); P0=path[i_]; P1=path[i_+1]; v=P0-H; rr=np.hypot(*v)+1e-6
            Qp=P0-v/rr*abs(rr_.normal(0,1))*14*f; dv=P1-P0; dl=np.hypot(*dv)+1e-6; L=rr_.uniform(8,22)
            d.line([Qp[0],Qp[1],Qp[0]+dv[0]/dl*L,Qp[1]+dv[1]/dl*L],fill=[(8,6,10),(20,14,22),(34,22,34)][rr_.choice([0,1,2],p=[.6,.3,.1])]+(int(255*(0.3+0.7*f)*fade),),width=int(rr_.integers(2,5)))
        wl=wl.filter(ImageFilter.GaussianBlur(0.7))
        A_=np.array(wl)[...,3].astype(float); E_=np.array(Image.fromarray(A_.astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(2.5))).astype(float)
        rim=np.zeros(A_.shape+(4,),np.uint8); rim[...,0]=120; rim[...,1]=44; rim[...,2]=150; rim[...,3]=(np.clip(E_-A_*0.85,0,255)*0.75).astype(np.uint8)
        g=SH.screen(g,Image.fromarray(rim),(0,0),1.0); g.alpha_composite(wl)
    hit=1.25<t<1.85
    for c in ('ij','ke'):
        if hit and c=='ij': hm=SH.tint(SH.hero('ij','hit',Ld['hk'],min(3,int((t-1.25)/0.6*4))),0.07)
        else: hm=SH.hero(c,'idle',Ld['hk'],0)
        SH.put(g,hm,*(IJ if c=='ij' else KE),30)
    draw_sick(True)
    if 1.25<t<1.75:
        u=(t-1.25)/0.5; lay=Image.new('RGBA',g.size)
        for a in np.linspace(0,6.28,8):
            p=sc(BSMK,0.05+0.03*u).rotate(np.degrees(a),expand=True); lay.alpha_composite(alpha(p,0.65*(1-u)),(int(IJ[0]+np.cos(a)*(20+16*u)-p.width/2),int(IJ[1]-55+np.sin(a)*(10+8*u)-p.height/2)))
        g.alpha_composite(lay)
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
        for t in [float(x) for x in sys.argv[1].split(',')]: frame(t).save(f'/tmp/sa4_{t}.png')
        sys.exit()
    d='/tmp/_sa4'; os.makedirs(d,exist_ok=True)
    for i in range(NF): frame(i/24).save(f'{d}/{i:04d}.png')
    subprocess.run(f'ffmpeg -y -loglevel error -framerate 24 -i {d}/%04d.png -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 16 -movflags +faststart /workspace/foe_walks/harvest_v2/sov_attack_4dir.mp4',shell=True,check=True)
