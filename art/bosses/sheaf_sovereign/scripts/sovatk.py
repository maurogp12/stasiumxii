# Sheaf Sovereign attack stills W/E: overhead scythe strike + 6 sickles whirling in its wake, black smoke wave, melee 1 tile.
import sys; sys.path.insert(0,'/workspace/foe_walks/harvest_spell_v1')
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import sheet as SH, sov3, sov4
from rig2 import rot
from crows4 import SMK, sc, alpha
PP={s:sov4.prep(sov3.build(s)) for s in ('front','back')}
BS=0.31
_s=np.array(SMK).astype(float); _s[...,:3]=_s[...,:3]*0.12+4; BSMK=Image.fromarray(_s.astype(np.uint8))
def tip_key(side):
    a=np.array(PP[side]['scy'])[...,3]; ys,xs=np.nonzero(a>40); k=ys.argmax(); return xs[k],ys[k]   # blade point = lowest pixel of the hanging scythe
TIPK={s:tip_key(s) for s in PP}
def R2(x,y,cx,cy,a):
    a=np.radians(a); dx,dy=x-cx,y-cy; return cx+dx*np.cos(a)+dy*np.sin(a), cy-dx*np.sin(a)+dy*np.cos(a)
def boss(side,lead,pend,tilt,gk,t=0.3):
    P=PP[side]; R=P['R']; OX,OY=500,400; can=Image.new('RGBA',(1640,1500)); hip=R['hip']; fx0=P['foot'][0]
    def add(im,dx=0,dy=0): can.alpha_composite(im,(int(OX+dx),int(OY+dy)))
    add(P['under'])
    for i,j,s,(cx,y0) in P['strips']:
        a1=lead*5+2*np.sin(2*t-(4-i)*.5)*lead
        if j==0: add(rot(s,a1,(cx,hip)))
        else:
            L=y0-hip; add(rot(s,a1+lead*6,(cx,y0)),L*np.sin(np.radians(-a1)),L*(np.cos(np.radians(a1))-1))
    hx,hy=P['hand']; pad=500; big=Image.new('RGBA',(640+2*pad,720+2*pad)); big.alpha_composite(P['scy'],(pad,pad))
    big=rot(rot(big,pend*lead,(hx+pad,hy+pad)),tilt*lead,(fx0+pad,hip+pad)); add(big,-pad,-pad)
    add(rot(P['upper'],tilt*lead,(fx0,hip)))
    ga=np.array(P['glow']); ga[...,3]=(ga[...,3]*gk).astype(np.uint8); add(rot(Image.fromarray(ga),tilt*lead,(fx0,hip)))
    add(rot(P['head'],tilt*lead,(fx0,hip)))
    ma=np.array(P['mask']); ma[...,3]=(ma[...,3]*gk*1.2).clip(0,255).astype(np.uint8); add(rot(Image.fromarray(ma),tilt*lead,(fx0,hip)))
    def tip(p):
        x,y=R2(*TIPK[side],hx,hy,p*lead); x,y=R2(x,y,fx0,hip,tilt*lead); return OX+x,OY+y
    hr=R2(hx,hy,fx0,hip,tilt*lead)
    return can,(OX+fx0,OY+P['foot'][1]),(OX+hr[0],OY+hr[1]),tip
# pend: 0 = scythe hanging (blade low). -150 = raised overhead behind (blade up, tip curling forward). -40 = level at the target.
PH={'idle':dict(pend=0,tilt=0,lift=0,gk=0.35),'windup':dict(pend=-150,tilt=-5,lift=10,gk=0.55),
    'strike':dict(pend=-62,tilt=7,lift=5,gk=0.8),'impact':dict(pend=-38,tilt=9,lift=3,gk=0.7),'recover':dict(pend=-12,tilt=3,lift=1,gk=0.45)}
def sickle_img(side,i,ang,scl,dark=1.0,k=1.0):
    s=PP[side]['sick'][i]; s=s.resize((max(1,int(s.width*scl)),max(1,int(s.height*scl))),Image.LANCZOS).rotate(ang,expand=True,resample=Image.BICUBIC)
    a=np.array(s).astype(float); a[...,:3]*=dark; a[...,3]*=k; return Image.fromarray(a.astype(np.uint8))
def cell(dn,ph,label):
    W=dn=='w'; side='front' if W else 'back'; lead=1 if W else -1; Q=PH[ph]
    Ld=SH.LAY[dn]; IJ=np.array(Ld['ij'],float); KE=Ld['ke']
    # melee: W one tile up-right of Ironjaw along facing; E one tile to his left (adjacent diagonal), boss drawn behind him
    BP=IJ+(np.array([48,-24]) if W else np.array([-96,0]))
    im,(fx,fy),(hx,hy),tipf=boss(side,lead,Q['pend'],Q['tilt'],Q['gk'])
    im=im.resize((int(im.width*BS),int(im.height*BS)),Image.LANCZOS)
    h=17+Q['lift']; ox,oy=BP[0]-fx*BS,BP[1]-fy*BS-h
    T=lambda p:(ox+tipf(p)[0]*BS,oy+tipf(p)[1]*BS); H=(ox+hx*BS,oy+hy*BS)
    g=SH.FL.copy(); hit=ph=='impact'
    # draw order: boss (with shadow) before Ironjaw/Kestrel in both rows
    k=1-(h-15)/20*.4; shd=Image.new('RGBA',g.size); sw=50*k
    ImageDraw.Draw(shd).ellipse([BP[0]-sw,BP[1]-sw*.28,BP[0]+sw,BP[1]+sw*.28],fill=(0,0,0,int(115*k))); g.alpha_composite(shd.filter(ImageFilter.GaussianBlur(5)))
    for kk in range(5): sov4.rig4.smoke  # (hem smoke is part of the float rig in video; stills keep a few dark puffs)
    lay=Image.new('RGBA',g.size)
    for kk in range(6):
        p=BSMK.rotate(kk*60,expand=True); p=sc(p,0.05+0.012*kk); lay.alpha_composite(alpha(p,0.55),(int(BP[0]+lead*(kk*9-20)-p.width/2),int(BP[1]-h-4-p.height/2)))
    g.alpha_composite(lay)
    # sickles: positions per phase (screen space)
    cx0,cy0=BP[0],BP[1]-h-115; rx,ry=88,28; SK=[]
    pv=None
    if ph in('strike','impact'):
        pv=np.linspace(-150,Q['pend'],40); path=np.array([T(p) for p in pv])
    for i in range(6):
        if ph=='idle':
            a=2*np.pi*i/6+0.4; x,y=cx0+rx*np.cos(a),cy0+ry*np.sin(a)-18*np.cos(a); z=np.sin(a); ang=0
        elif ph=='windup':     # gathered in a tight crown-ring above/behind the raised blade
            a=2*np.pi*i/6; tp=T(-150); x,y=cx0+lead*70+46*np.cos(a),cy0-30+20*np.sin(a); z=np.sin(a); ang=-lead*a*57+30*lead
        elif ph in('strike','impact'):   # strung along the blade path, trailing the tip
            f=0.92-i*0.15; j=int(f*(len(path)-1)); x,y=path[j]; nx,ny=path[min(len(path)-1,j+1)]-path[max(0,j-1)]
            vv=np.array([x,y])-np.array(H); vv/=np.hypot(*vv)+1e-6; o_=-12 if W else 30; x+=vv[0]*o_; y+=vv[1]*o_
            x+=np.random.default_rng(i).normal(0,6); y+=np.random.default_rng(i+9).normal(0,6)
            ang=np.degrees(np.arctan2(-ny,nx))-90; z=1; 
        else:                  # recovery: flung back out, returning to orbit
            a=2*np.pi*i/6+1.2; x,y=cx0+rx*1.25*np.cos(a),cy0+ry*1.25*np.sin(a)-18*np.cos(a); z=np.sin(a); ang=lead*25*np.cos(a)
        SK.append((z,i,x,y,ang))
    def draw_sick(front):
        for z,i,x,y,ang in sorted(SK):
            if (z>=0)!=front: continue
            s=sickle_img(side,i,ang,BS*1.05,1.0 if z>=0 else 0.75)
            if ph in('strike','impact'):   # faint motion trail: 2 fading copies behind along the path
                for q,kq in ((1,0.18),(2,0.08)):
                    tq=sickle_img(side,i,ang-lead*14*q,BS*1.05,1.0,kq); g.alpha_composite(tq,(int(x+lead*10*q-tq.width/2),int(y-8*q*(-1 if ph=='impact' else 1)-tq.height/2)))
            g.alpha_composite(s,(int(x-s.width/2),int(y-s.height/2)))
    draw_sick(False)
    g.alpha_composite(im,(int(ox),int(oy)))
    # black smoke wave along the scythe tip path
    if pv is not None:
        fade=1.0 if ph=='strike' else 0.8; wl=Image.new('RGBA',g.size); d=ImageDraw.Draw(wl); r=np.random.default_rng(4); n=len(path)
        for kk in range(60):
            f=(kk/59)**0.8; P0=path[min(n-1,int(f*(n-1)))]; v=P0-np.array(H); rr=np.hypot(*v)+1e-6
            Qp=P0-v/rr*r.uniform(0,26)*f; an=np.degrees(np.arctan2(-v[1],v[0]))
            st=sc(BSMK,0.08+0.09*f).rotate(an+r.uniform(-25,25),expand=True,resample=Image.BICUBIC)
            wl.alpha_composite(alpha(st,(0.3+0.7*f)*fade),(int(Qp[0]-st.width/2),int(Qp[1]-st.height/2)))
        for kk in range(320):
            f=r.random()**0.6; i_=min(n-2,int(f*(n-1))); P0=path[i_]; P1=path[i_+1]; v=P0-np.array(H); rr=np.hypot(*v)+1e-6
            Qp=P0-v/rr*abs(r.normal(0,1))*14*f; dv=P1-P0; dl=np.hypot(*dv)+1e-6; L=r.uniform(8,22)
            d.line([Qp[0],Qp[1],Qp[0]+dv[0]/dl*L,Qp[1]+dv[1]/dl*L],fill=[(8,6,10),(20,14,22),(34,22,34)][r.choice([0,1,2],p=[.6,.3,.1])]+(int(255*(0.3+0.7*f)*fade),),width=int(r.integers(2,5)))
        wl=wl.filter(ImageFilter.GaussianBlur(0.7))
        A_=np.array(wl)[...,3].astype(float); E_=np.array(Image.fromarray(A_.astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(2.5))).astype(float)
        rim=np.zeros(A_.shape+(4,),np.uint8); rim[...,0]=120; rim[...,1]=44; rim[...,2]=150; rim[...,3]=(np.clip(E_-A_*0.85,0,255)*0.75).astype(np.uint8)
        g=SH.screen(g,Image.fromarray(rim),(0,0),1.0); g.alpha_composite(wl)
    # heroes
    for c in ('ij','ke'):
        hm=SH.hero(c,'hit' if (hit and c=='ij') else 'idle',Ld['hk'],1 if (hit and c=='ij') else 0)
        if hit and c=='ij': hm=SH.tint(hm,0.07)
        SH.put(g,hm,*Ld[c],30)
    draw_sick(True)
    if hit:   # dark impact burst on Ironjaw (black smoke stamps + faint purple)
        lay=Image.new('RGBA',g.size); r=np.random.default_rng(12)
        for a in np.linspace(0,6.28,8):
            p=sc(BSMK,0.06).rotate(np.degrees(a),expand=True); lay.alpha_composite(alpha(p,0.6),(int(IJ[0]+np.cos(a)*26-p.width/2),int(IJ[1]-55+np.sin(a)*14-p.height/2)))
        g.alpha_composite(lay)
    d=ImageDraw.Draw(g); d.text((10,8),f'{dn.upper()} {label}',font=SH.fnt,fill=(255,236,170,255),stroke_width=3,stroke_fill=(0,0,0,255))
    return g
PHL=[('idle','1 idle'),('windup','2 windup'),('strike','3 strike'),('impact','4 impact'),('recover','5 recover')]
if __name__=='__main__':
  rows=[[cell(dn,p,l) for p,l in PHL] for dn in ('w','e')]
  SH.sheet(rows,'/workspace/foe_walks/harvest_v2/sov_attack_stills_WE.png','')
