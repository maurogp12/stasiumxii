import sys, os, subprocess, cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import hitdeath as HD
from hitdeath import C4, SH, sc, alpha, pc, addglow, flare, cl, CROWS, EMB, rim, FEATH, REM, REM_GP, BLACK
import rig2
def ease(x): x=cl(x); return x*x*(3-2*x)
T=6.5; NF=int(T*24); BS=0.31
FLW=rig2.floor('w',0); FLE=rig2.floor('e',0)
def mblur(im,n):
    if n<2: return im
    a=np.array(im).astype(np.float32); pm=a[...,:3]*a[...,3:]/255; k=np.ones((1,n),np.float32)/n
    pm=cv2.filter2D(pm,-1,k); al=cv2.filter2D(a[...,3],-1,k)
    rgb=np.where(al[...,None]>0,pm*255/np.maximum(al[...,None],1),0); return Image.fromarray(np.dstack([rgb,al]).clip(0,255).astype(np.uint8))
def warm(im,k):
    if k<=0.002: return im
    a=np.array(im).astype(float); a[...,0]*=1+k; a[...,1]*=1-k*0.3; a[...,2]*=1-k*0.4; return Image.fromarray(a.clip(0,255).astype(np.uint8))
def ij_frame(t):
    for t0 in (0.75,2.95):
        u=(t-t0)/0.6
        if 0<=u<1: return 'attack',min(5,int(u*6))
    return 'idle',0
def bump(t,a,b,c): return ease((t-a)/(b-a))*(1-ease((t-b)/(c-b)))
def tile(base,t):
    W=base=='w'; side='front' if W else 'back'; Ld=SH.LAY[base]; lead=1 if W else -1
    ox_=480-(175 if W else 225); oy_=20 if W else -10
    BP=np.array([Ld['b'][0]+ox_,Ld['b'][1]+oy_],float); IJ=(Ld['ij'][0]+ox_,Ld['ij'][1]+oy_); KE=(Ld['ke'][0]+ox_,Ld['ke'][1]+oy_)
    g=(FLW if W else FLE).copy()
    tg=np.array([(IJ[0]+KE[0])/2,(IJ[1]+KE[1])/2]); v=BP-tg; v/=np.linalg.norm(v)
    # ---- boss state ----
    rec=bump(t,1.15,1.35,2.4); stag=bump(t,1.3,1.65,2.5)
    tilt=-9*bump(t,1.15,1.3,2.0)-3*stag; push=14*rec+10*stag; lift=-4*stag
    tint=0.07*bump(t,1.15,1.2,1.7)+0.06*bump(t,3.35,3.4,3.9)
    sh_=0
    if 3.35<t<4.05: w=t-3.35; sh_=7*np.sin(w*2*np.pi*9)*(1-w/0.7)       # sideways shake
    vel=abs(np.cos((t-3.35)*2*np.pi*9))*(1 if 3.35<t<4.05 else 0)
    glowk=0.45+2.0*ease((t-3.4)/0.5)*(1-ease((t-4.25)/0.2))+0.6*bump(t,1.15,1.2,1.5)
    diss=ease((t-4.0)/0.45)
    h=17+3*np.sin(np.pi*t)+lift
    pos=BP+v*push*np.array([1,0.5])+np.array([sh_*lead,0])
    k=1-(h-15)/20*.4; shk=(1-diss)
    sh=Image.new('RGBA',g.size); sw=44*k*max(shk,0.0)
    if sw>2: ImageDraw.Draw(sh).ellipse([pos[0]-sw,BP[1]-sw*.28,pos[0]+sw,BP[1]+sw*.28],fill=(0,0,0,int(110*k*shk))); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    rem_k=ease((t-4.45)/0.6)
    if rem_k>0:   # remains: own contact shadow + plate, ground point on the unit's spot
        r=REM if W else REM.transpose(Image.FLIP_LEFT_RIGHT); gx=REM_GP[0] if W else REM.width-REM_GP[0]
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([BP[0]-50,BP[1]-12,BP[0]+50,BP[1]+12],fill=(0,0,0,int(80*rem_k))); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(5)))
        g.alpha_composite(alpha(r,rem_k),(int(BP[0]-gx),int(BP[1]-REM_GP[1])))
        rr=np.random.default_rng(8); lay=Image.new('RGBA',g.size); d=ImageDraw.Draw(lay)
        for j in range(12):
            x=BP[0]+rr.normal(0,24); y=BP[1]-8-abs(rr.normal(0,12)); q=rr.uniform(0.6,1.1); fl=0.5+0.5*np.sin(t*7+j*1.7)
            d.ellipse([x-q,y-q,x+q,y+q],fill=(255,180,80,int(rr.uniform(70,170)*fl*rem_k)))
        g.alpha_composite(lay.filter(ImageFilter.GaussianBlur(0.7)))
    chest=(pos[0]+(-4 if W else 4),pos[1]-h-118)
    if diss<1:
        im,(fx,fy)=C4.boss(side,t,tilt=tilt,glowk=glowk,swell=0.8*bump(t,3.4,3.8,4.1))
        a=np.array(im); ys,xs=np.nonzero(a[...,3]>10); im=im.crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1)); fx-=xs.min(); fy-=ys.min()
        im=warm(im,tint)
        imr=sc(im,BS)
        if vel>0: imr=mblur(imr,int(1+6*vel*(1-(t-3.35)/0.7)))
        if diss>0: imr=SH.dissolve(imr,diss,seed=4)
        g.alpha_composite(imr,(int(pos[0]-fx*BS),int(pos[1]-fy*BS-h)))
    # hit 1: smoke puff off the robe + brief bright flash (reads in E too)
    for th_,big in ((1.15,1),(3.35,0.7)):
        u=(t-th_)/0.6
        if 0<u<1:
            fk=cl(1-u/0.35)
            if fk>0: g=SH.screen(g,flare(18,1.3),(chest[0]-v[0]*-6-63,chest[1]+20-63),fk*0.9)
            pc(g,sc(BLACK if th_>3 else HD.SMK,0.16+0.16*u*big).rotate(90 if W else -90,expand=True),chest[0]-v[0]*(14+20*u),chest[1]+22-10*u,0.9*(1-u))
    if 3.4<t<4.3:   # rib flare
        fk=ease((t-3.4)/0.5)*(1-ease((t-4.1)/0.2))
        g=SH.screen(g,flare(16,1.6),(chest[0]-56,chest[1]-56),0.9*fk); g=addglow(g,sc(EMB,0.3),chest[0],chest[1],0.8*fk)
    if 4.0<t<5.6:   # black burst, crows, feathers
        u=(t-4.0)/1.6
        for j,(dx,dy,s) in enumerate([(0,-40,0.42),(-30,10,0.34),(28,-5,0.36),(0,40,0.3),(-10,-100,0.3),(5,-60,0.38)]):
            gr=0.6+0.7*ease(u*2); pc(g,sc(BLACK,s*gr).rotate(90+30*j+40*u,expand=True,resample=Image.BICUBIC),pos[0]+dx*gr,pos[1]-h-90+dy*gr-20*u,0.95*(1-ease((u-0.35)/0.65)))
        for j in range(7):
            cu=cl((t-4.02-0.03*j)/1.15)
            if 0<cu<1:
                th=np.radians([200,150,105,60,20,-20,240][j]); sz=[0.5,0.36,0.44,0.3,0.54,0.4,0.33][j]; bend=[1,-1,1,-1,1,-1,1][j]*0.55
                def P_(u):
                    d=45+170*(1-(1-u)**2.2); ang=th+bend*u
                    return pos[0]+d*np.cos(ang), pos[1]-h-105-d*np.sin(ang)*0.75-25*u
                x,y=P_(cu); x2,y2=P_(min(1,cu+0.02)); vx,vy=x2-x,y2-y
                face=-1 if vx<0 else 1
                fi=int((t*14+j*1.3))%3                                # wing-beat: cycle the three painted crow poses
                c=CROWS[[0,2,1][fi]]; c=c if face<0 else c.transpose(Image.FLIP_LEFT_RIGHT)
                fl=0.82+0.18*np.cos(t*2*np.pi*7+j)                   # squash on the beat
                c=c.resize((max(1,int(c.width*sz)),max(1,int(c.height*sz*fl))),Image.LANCZOS)
                tilt_=float(np.clip(np.degrees(np.arctan2(-vy,abs(vx)+1e-6)),-30,30))*(-face)
                c=rim(c,0.5).rotate(tilt_,expand=True,resample=Image.BICUBIC)
                c=c.filter(ImageFilter.GaussianBlur(0.4))
                pc(g,c,x,y,ease(cu/0.08)*(1-ease((cu-0.6)/0.4)))
        r=np.random.default_rng(5)
        for j in range(12):
            st=r.uniform(0,0.3); fu=cl((u-st)/0.7); x0=pos[0]+r.normal(0,55); y0=pos[1]-h-110+r.normal(0,45); sd=r.choice([-1,1])
            if 0<fu<1: f=FEATH[j%3].rotate(fu*300*sd,expand=True); pc(g,f,x0+12*np.sin(fu*6+j),y0+fu*(BP[1]-y0-10)*0.8,np.sin(np.pi*fu))
    # heroes
    for cn,p in sorted((('ij',IJ),('ke',KE)),key=lambda x:x[1][1]):
        a_,f_=ij_frame(t) if cn=='ij' else ('idle',0)
        SH.put(g,SH.hero(cn,a_,Ld['hk'],f_),*p,30)
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
        for t in [float(x) for x in sys.argv[1].split(',')]: frame(t).save(f'/tmp/hd4b_{t}.png')
        sys.exit()
    d='/tmp/_hd4b'; os.makedirs(d,exist_ok=True)
    for i in range(NF): frame(i/24).save(f'{d}/{i:04d}.png')
    subprocess.run(f'ffmpeg -y -loglevel error -framerate 24 -i {d}/%04d.png -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 16 -movflags +faststart /workspace/foe_walks/harvest_v2/warden_hit_death_4dir_v2.mp4',shell=True,check=True)
