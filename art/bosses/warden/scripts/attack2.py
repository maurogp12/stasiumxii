import sys; sys.path.insert(0,'/workspace/foe_walks/harvest_spell_v1')
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import sheet as SH, rig4
from rig3 import build, rot
PL='/workspace/foe_walks/harvest_spell_v1/plates/'
PP={s:rig4.prep(build(s)) for s in ('front','back')}
def boss(side,lead,pend,tilt,t=0.3,glowk=0.4):
    P=PP[side]; R=P['R']; OX,OY=500,300; can=Image.new("RGBA",(1640,1280)); hip=R['hip']; fx0=P['foot'][0]
    def add(im,dx=0,dy=0): can.alpha_composite(im,(int(OX+dx),int(OY+dy)))
    add(P['under'])
    for i,j,s,(cx,y0) in P['strips']:
        a1=lead*4+2*np.sin(2*t-(4-i)*.5)*lead
        if j==0: add(rot(s,a1,(cx,hip)))
        else:
            L=y0-hip; add(rot(s,a1+lead*4,(cx,y0)),L*np.sin(np.radians(-a1)),L*(np.cos(np.radians(a1))-1))
    hx,hy=P['hand']; pad=400; big=Image.new('RGBA',(640+2*pad,720+2*pad)); big.alpha_composite(P['scy'],(pad,pad))
    big=rot(rot(big,pend*lead,(hx+pad,hy+pad)),tilt*lead,(fx0+pad,hip+pad)); add(big,-pad,-pad)
    add(rot(P['upper'],tilt*lead,(fx0,hip)))
    ga=np.array(P['glow']); ga[...,3]=(ga[...,3]*glowk).astype(np.uint8); add(rot(Image.fromarray(ga),tilt*lead,(fx0,hip)))
    add(rot(P['head'],tilt*lead,(fx0,hip)))
    a=np.array(can); ys,xs=np.nonzero(a[...,3]>10); can=can.crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1))
    return can,(OX+P['foot'][0]-xs.min(),OY+P['foot'][1]-ys.min()), (OX+hx-xs.min(),OY+hy-ys.min())
BS=0.31
def smokeblobs(g,pts,seed=3,col=(74,72,84),amax=150):
    lay=Image.new('RGBA',g.size); d=ImageDraw.Draw(lay); r=np.random.default_rng(seed)
    for (x,y,s) in pts:
        for _ in range(3):
            ox,oy=r.normal(0,s*.5,2); rr=s*r.uniform(.6,1.2); c=(96,74,44) if r.random()<.3 else col
            d.ellipse([x+ox-rr*1.4,y+oy-rr*.7,x+ox+rr*1.4,y+oy+rr*.7],fill=c+(int(amax*r.uniform(.5,1)),))
    g.alpha_composite(lay.filter(ImageFilter.GaussianBlur(5)))
ARC=SH.L(PL+'WB_vfx.png'); ARC=ARC.crop((230,0,539,200))
VORT=SH.L(PL+'VORT_plate.png')
def cell(dn,ph,label):
    W=dn=='w'; side='front' if W else 'back'; lead=1 if W else -1
    P_={'idle':(0,0,0,0.35),'windup':(-38,-4,10,0.5),'swing':(50,6,6,0.65),'hit':(72,8,4,0.7),'recover':(20,3,2,0.45)}[ph]
    pend,tilt,lift,gk=P_
    if not W and pend>0: pend=min(pend,22)
    lunge={'idle':0,'windup':-0.05,'swing':0.35,'hit':0.8,'recover':0.18}[ph]
    lunge*=1.0 if W else 0.55
    im,(fx,fy),(hx,hy)=boss(side,lead,pend,tilt,glowk=gk)
    im=im.resize((int(im.width*BS),int(im.height*BS)),Image.LANCZOS); fx*=BS; fy*=BS; hx*=BS; hy*=BS
    g=SH.FL.copy(); Ld=SH.LAY[dn]; bx,by=Ld['b']; h=17+lift
    tx0=(Ld['ij'][0]+Ld['ke'][0])/2; ty0=(Ld['ij'][1]+Ld['ke'][1])/2
    bx=bx+(tx0-bx)*lunge; by=by+(ty0-by)*lunge*(1.0 if W else 0.75)
    hit=ph=='hit'
    items=[(Ld['ij'][1],'ij'),(Ld['ke'][1],'ke'),(by-h*0.0,'b')]
    for _,c in sorted(items):
        if c=='b':
            k=1-(h-15)/20*.4; sh=Image.new('RGBA',g.size); sw=44*k
            ImageDraw.Draw(sh).ellipse([bx-sw,by-sw*.28,bx+sw,by+sw*.28],fill=(0,0,0,int(110*k))); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
            smokeblobs(g,[(bx+lead*(10+i*13)+(-lead*30 if lunge>0.2 else 0)*i/5,by-h-2-i*3,8+i*2.5) for i in range(6)],seed=5,amax=185)
            ox,oy=int(bx-fx),int(by-fy-h); g.alpha_composite(im,(ox,oy))
        else:
            hm=SH.hero(c,'hit' if hit else 'idle',Ld['hk'],1 if hit else 0)
            if hit: hm=SH.tint(hm,0.07)
            SH.put(g,hm,*Ld[c],30)
    tx=(Ld['ij'][0]+Ld['ke'][0])/2; ty=(Ld['ij'][1]+Ld['ke'][1])/2-50
    if ph in('swing','hit'):
        # painted gold chaff arc swept from the boss toward the heroes, with smoke behind it
        cx,cy=ox+hx,oy+hy; v=np.array([tx-cx,ty-cy]); ang=np.degrees(np.arctan2(-v[1],v[0]))
        R_=100; th0=np.radians(125 if W else 150); th1=np.arctan2(-(ty-cy),(tx-cx))
        if W and th1<th0: th1+=2*np.pi
        lay=Image.new('RGBA',g.size); d=ImageDraw.Draw(lay); r=np.random.default_rng(4); end=1.0 if ph=='swing' else 0.75
        for k in range(260):
            f=r.random()**0.7*end; th=th0+(th1-th0)*f; rr=R_*(1-0.25*f)+r.normal(0,9*(1-f*.5))
            x,y=cx+rr*np.cos(th),cy-rr*np.sin(th); L=r.uniform(6,16); dt=L/rr*(1 if th1>th0 else -1)
            x2,y2=cx+rr*np.cos(th-dt),cy-rr*np.sin(th-dt); c=r.choice([0,1,2],p=[.55,.3,.15])
            col=[(232,180,82),(180,120,48),(255,230,160)][c]; al=int(255*(0.35+0.65*f)*(0.7 if ph=='hit' else 1))
            d.line([x,y,x2,y2],fill=col+(al,),width=int(r.integers(1,4)))
        lay=lay.filter(ImageFilter.GaussianBlur(0.6))
        smokeblobs(g,[(cx+(R_-20)*np.cos(th0+(th1-th0)*f),cy-(R_-20)*np.sin(th0+(th1-th0)*f),8) for f in np.linspace(0,.6,5)],seed=9,amax=175)
        g.alpha_composite(SH.glow(lay,5,0.6)); g.alpha_composite(lay)
    if hit:
        v=VORT.resize((110,64),Image.LANCZOS); g=SH.screen(g,SH.glow(v,6,1.4),(tx-55,ty-32),0.8); g=SH.screen(g,v,(tx-55,ty-32),1.0)
        smokeblobs(g,[(tx+np.cos(a)*30,ty+np.sin(a)*14,7) for a in np.linspace(0,6.28,7)],seed=11,amax=150)
    d=ImageDraw.Draw(g); d.text((10,8),f'{dn.upper()} {label}',font=SH.fnt,fill=(255,236,170,255),stroke_width=3,stroke_fill=(0,0,0,255))
    return g
PH=[('idle','1 idle'),('windup','2 windup'),('swing','3 swing'),('hit','4 hit'),('recover','5 recover')]
rows=[[cell(dn,p,l) for p,l in PH] for dn in ('w','e')]
SH.sheet(rows,'/workspace/foe_walks/harvest_v2/warden_attack_stills_WE_v2.png','')
