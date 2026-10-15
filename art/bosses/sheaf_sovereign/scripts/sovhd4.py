# Sheaf Sovereign hit + death, 4 directions: hit (0.5) -> pause -> shudder -> smoke burst, sickles flung & drop, crown falls -> remains hold.
import sys, os, subprocess; sys.path.insert(0,'/workspace/foe_walks/harvest_spell_v1')
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import sheet as SH, rig2
from sovatk import boss, BSMK, sickle_img, BS
from crows4 import sc, flare, pc
from sovhd import warm, mblur, CR, ash_heap, wisps
T=6.0; NF=int(T*24)
def cl(x): return float(np.clip(x,0,1))
def ease(x): x=cl(x); return x*x*(3-2*x)
def bump(t,a,b,c): return ease((t-a)/(b-a))*(1-ease((t-b)/(c-b)))
FLW=rig2.floor('w',0); FLE=rig2.floor('e',0)
REMP=[(-38,2,100),(34,-4,-80),(-14,8,170),(18,6,-150),(-50,-6,60),(48,4,-110)]
def ij_frame(t):
    u=(t-0.05)/0.6
    if 0<=u<1: return 'attack',min(5,int(u*6))
    return 'idle',0
def tile(base,t):
    W=base=='w'; side='front' if W else 'back'; lead=1 if W else -1; Ld=SH.LAY[base]
    ox_=480-(175 if W else 225); oy_=20 if W else 45
    IJ=np.array(Ld['ij'],float)+[ox_,oy_]; KE=np.array(Ld['ke'],float)+[ox_,oy_]
    BP=IJ+(np.array([48,-24]) if W else np.array([-96,0]))
    v=BP-(IJ+KE)/2; v/=np.linalg.norm(v)
    g=(FLW if W else FLE).copy()
    rec=bump(t,0.5,0.62,1.3); stag=bump(t,0.6,0.85,1.5)
    push=10*rec+8*stag; tilt=-8*bump(t,0.5,0.6,1.0)-3*stag+3*bump(t,1.9,2.2,2.6); lift=-3*stag+3*bump(t,1.9,2.3,2.6)+2*np.sin(np.pi*t)
    tint=0.07*bump(t,0.5,0.54,0.95); jolt=bump(t,0.5,0.56,1.1)
    shud=1.9<t<2.55; gk=0.4+0.25*bump(t,0.5,0.55,0.9)+1.6*bump(t,1.9,2.4,2.7)
    diss=ease((t-2.45)/0.5)
    h=17+lift; pos=BP+v*push*np.array([1,0.5])
    if shud: pos=pos+[5*np.sin((t-1.9)*2*np.pi*9)*lead*min(1,(t-1.9)/0.2),0]
    remc=BP+(np.array([16,-11]) if W else 0)          # W: heap nudged back on his tile, clear of the heroes
    cx0,cy0=pos[0],pos[1]-h-115; rx,ry=88,28
    shk=1-diss*0.85
    if t<3.6:
        k=1-(h-15)/20*.4; sw=50*k*shk; s=Image.new('RGBA',g.size)
        ImageDraw.Draw(s).ellipse([pos[0]-sw,BP[1]-sw*.28,pos[0]+sw,BP[1]+sw*.28],fill=(0,0,0,int(115*k*shk*(1-ease((t-3.2)/0.4))))); g.alpha_composite(s.filter(ImageFilter.GaussianBlur(5)))
    rk=ease((t-3.15)/0.5)
    if rk>0:
        s=Image.new('RGBA',g.size); ImageDraw.Draw(s).ellipse([remc[0]-52,remc[1]-13,remc[0]+52,remc[1]+13],fill=(0,0,0,int(90*rk))); g.alpha_composite(s.filter(ImageFilter.GaussianBlur(5)))
        hp=ash_heap(120); a=np.array(hp); a[...,3]=(a[...,3]*rk).astype(np.uint8); g.alpha_composite(Image.fromarray(a),(int(remc[0]-hp.width/2),int(remc[1]-hp.height+12)))
    # sickles
    SK=[]; spin=2*np.pi*min(t,2.5)/4.0
    for i in range(6):
        a=2*np.pi*i/6+0.4+spin+0.25*jolt; rr=1+0.22*jolt+0.15*bump(t,1.9,2.3,2.6)
        orb=np.array([cx0+rx*rr*np.cos(a)+v[0]*14*jolt,cy0+ry*rr*np.sin(a)-18*np.cos(a)-6*jolt]); z=np.sin(a)
        ang=lead*30*jolt*(1 if i%2 else -1)+8*np.sin(t*3+i)
        dx,dy,ra=REMP[i]; land=np.array([remc[0]+dx*lead,remc[1]+dy]); landa=ra*lead
        F=np.array([cx0+rx*1.75*np.cos(a),cy0+ry*1.75*np.sin(a)-30*np.cos(a)-20])
        t0=2.5+0.03*i; u1=ease((t-t0)/0.35); u2=cl((t-t0-0.35)/(0.5+0.04*i))
        if t<t0: P=orb; an=ang; mot=0
        elif u2<=0: P=orb*(1-u1)+F*u1; an=ang+lead*400*u1*(1 if i%2 else -1); z=z*(1-u1)+u1; mot=1
        else:
            P=F*(1-u2)+land*u2-np.array([0,60*4*u2*(1-u2)*0.5]); P[1]=F[1]+(land[1]-F[1])*u2**2-40*u2*(1-u2)
            sp=lead*(400+300*u2)*(1 if i%2 else -1); an0=ang+sp*0+lead*400*(1 if i%2 else -1)
            an=an0*(1-u2)+landa*u2+ (1-u2)*sp*0.5; z=1; mot=1 if u2<1 else 0
        landed=u2>=1
        SK.append((z,i,P,an,mot,landed))
    def draw_sick(front):
        for z,i,P,an,mot,landed in sorted(SK,key=lambda q:q[0]):
            if (z>=0)!=front: continue
            dk=0.85 if landed else (1.0 if z>=0 else 0.75); scl=BS*(0.95 if landed else 1.05)
            if mot or jolt>0.5:
                for q,kq in ((1,0.16),(2,0.07)):
                    tq=sickle_img(side,i,an-lead*12*q,scl,dk,kq); g.alpha_composite(tq,(int(P[0]+lead*6*q-tq.width/2),int(P[1]-6*q-tq.height/2)))
            s=sickle_img(side,i,an,scl,dk); g.alpha_composite(s,(int(P[0]-s.width/2),int(P[1]-s.height/2)))
    # draw landed/back sickles + boss
    draw_sick(False)
    if diss<1:
        im,(fx,fy),_,_=boss(side,lead,0,tilt,gk,t)
        im=im.resize((int(im.width*BS),int(im.height*BS)),Image.LANCZOS)
        if tint>0.003: im=warm(im,tint)
        if shud: im=mblur(im,int(2+5*min(1,(t-1.9)/0.3)))
        if diss>0:
            im=SH.dissolve(im,diss,seed=4)
            if t>2.65:   # crown separates from the dissolving body
                pass
        g.alpha_composite(im,(int(pos[0]-fx*BS),int(pos[1]-fy*BS-h)))
    chest=(pos[0]+(-4 if W else 4),pos[1]-h-118)
    u=(t-0.5)/0.6
    if 0<u<1:
        fk=cl(1-u/0.35)
        if fk>0: g=SH.screen(g,flare(18,1.3),(chest[0]-63,chest[1]-43),0.55*fk)
        pc(g,sc(BSMK,0.16+0.12*u).rotate(90 if W else -90,expand=True),chest[0]+v[0]*(14+20*u),chest[1]+18-10*u,0.75*(1-u))
    fk=bump(t,2.0,2.4,2.7)
    if fk>0: g=SH.screen(g,flare(16,1.6),(chest[0]-56,chest[1]-56),0.8*fk); wisps(g,chest[0],chest[1]+10,0.45*fk,3,0.6)
    if 2.45<t<4.2:
        u=(t-2.45)/1.75
        for j,(dx,dy,s) in enumerate([(0,-40,0.42),(-30,10,0.34),(28,-5,0.36),(0,40,0.3),(-10,-100,0.3),(5,-60,0.38)]):
            gr=0.6+0.7*ease(u*2); pc(g,sc(BSMK,s*gr).rotate(90+30*j+40*u,expand=True,resample=Image.BICUBIC),pos[0]+dx*gr,pos[1]-h-90+dy*gr-30*u,0.85*ease(u*6)*(1-ease((u-0.3)/0.7)))
        wisps(g,chest[0],chest[1]-40*u,(1-ease((u-0.4)/0.6))*ease(u*5),5,0.8+0.8*u)
        fk=cl(1-u/0.15)
        if fk>0: g=SH.screen(g,flare(14,1.0),(chest[0]-49,chest[1]-49),0.35*fk)
    # crown: pops off at burst, tumbles down onto the heap
    c0=np.array([pos[0]-2*lead,pos[1]-h-178]); cend=np.array([remc[0]+6*lead,remc[1]+2])
    ck=cl((t-2.7)/0.6); CS=BS*1.5
    if t>2.7:
        P=c0*(1-ck)+cend*ck; P[1]=c0[1]+(cend[1]-c0[1])*ck**2-25*ck*(1-ck); ang=-18*lead*ck+(1-ck)*lead*25*np.sin(ck*7)
    if W: pass
    cr_draw=None
    if t>2.7:
        c=sc(CR[side],CS*(1-0.3*(1-ck) if False else 1)).rotate(ang,expand=True,resample=Image.BICUBIC)
        if ck>=1: cr_draw=(c,cend[0]-c.width/2,cend[1]-c.height+2)
        else: cr_draw=(c,P[0]-c.width/2,P[1]-c.height*0.7)
    if rk>0:
        hp2=ash_heap(64,5); a=np.array(hp2); a[...,3]=(a[...,3]*rk).astype(np.uint8); g.alpha_composite(Image.fromarray(a),(int(remc[0]-hp2.width/2-14*lead),int(remc[1]-hp2.height+16)))
    if cr_draw and ck>=1:
        c,x,y=cr_draw; g=SH.screen(g,flare(10,0.6),(x+c.width/2-35,y+c.height/2-35),0.18); g.alpha_composite(c,(int(x),int(y)))
    if rk>0:
        r=np.random.default_rng(8); lay=Image.new('RGBA',g.size); d=ImageDraw.Draw(lay)
        for j in range(12):
            x=remc[0]+r.normal(0,26); y=remc[1]-4-abs(r.normal(0,10)); q=r.uniform(0.6,1.1); fl=0.5+0.5*np.sin(t*6+j*1.7)
            d.ellipse([x-q,y-q,x+q,y+q],fill=(190,150,230,int(r.uniform(60,150)*rk*fl)))
        g.alpha_composite(lay.filter(ImageFilter.GaussianBlur(0.7))); wisps(g,remc[0],remc[1]-10,0.25*rk,11,0.5+0.1*np.sin(t))
    for cn,p in sorted((('ij',IJ),('ke',KE)),key=lambda x:x[1][1]):
        a_,f_=ij_frame(t) if cn=='ij' else ('idle',0)
        SH.put(g,SH.hero(cn,a_,Ld['hk'],f_),*p,30)
    draw_sick(True)
    if cr_draw and ck<1: c,x,y=cr_draw; g.alpha_composite(c,(int(x),int(y)))
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
        for t in [float(x) for x in sys.argv[1].split(',')]: frame(t).save(f'/tmp/shd_{t}.png')
        sys.exit()
    d='/tmp/_shd'; os.makedirs(d,exist_ok=True)
    for i in range(NF): frame(i/24).save(f'{d}/{i:04d}.png')
    subprocess.run(f'ffmpeg -y -loglevel error -framerate 24 -i {d}/%04d.png -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 16 -movflags +faststart /workspace/foe_walks/harvest_v2/sov_hit_death_4dir.mp4',shell=True,check=True)
