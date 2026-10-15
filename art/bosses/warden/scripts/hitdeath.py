import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import crows4 as C4
from crows4 import SH, sc, alpha, pc, puff, addglow, flare, cl, CROWS, EMB, SMK, rim, FEATH, PP
from rig3 import rot
KEY=Image.open('war_front_v5.png').convert('RGBA')
def polycut(img,poly,feather=1.5):
    m=Image.new('L',img.size); ImageDraw.Draw(m).polygon(poly,fill=255); m=m.filter(ImageFilter.GaussianBlur(feather))
    a=np.array(img).astype(float); a[...,3]*=np.array(m)/255; o=Image.fromarray(a.astype(np.uint8))
    xs=[p[0] for p in poly]; ys=[p[1] for p in poly]; return o.crop((min(xs)-3,min(ys)-3,max(xs)+3,max(ys)+3))
MASK=polycut(KEY,[(318,89),(340,86),(362,89),(369,104),(368,124),(360,142),(350,158),(340,164),(330,158),(320,142),(312,124),(311,104)])
FRINGE=polycut(KEY,[(150,610),(600,610),(610,690),(140,690)],4)
def scythe_whole():
    a=np.array(PP['front']['scy']).copy(); top=a.copy(); top[281:]=0; low=a.copy(); low[:281]=0
    low=np.roll(np.roll(low,-36,axis=0),-5,axis=1)          # close the hand gap: slide the lower shaft up along its line
    o=Image.fromarray(top); o.alpha_composite(Image.fromarray(low)); a2=np.array(o); ys,xs=np.nonzero(a2[...,3]>20)
    return o.crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1))
SCY=scythe_whole()
def mound(w,h):
    a=np.array(FRINGE.resize((w,int(FRINGE.height*1.6)),Image.LANCZOS)).astype(float); a[...,:3]*=0.62
    H,W=a.shape[:2]; Y,X=np.mgrid[0:H,0:W]; top=H*(0.85-0.6*np.sqrt(np.clip(1-((X-W/2)/(W/2))**2,0,1)))
    a[...,3]*=np.clip((Y-top)/10,0,1)*np.clip((1-((X-W/2)/(W/2))**2)/0.15,0,1)
    return Image.fromarray(a.astype(np.uint8))
def remains(flipx):
    W,H=700,380; im=Image.new('RGBA',(W,H))
    sm=sc(SMK,0.9).rotate(90,expand=True); im.alpha_composite(alpha(sm,0.7),(int(W/2-sm.width/2),int(H-80-sm.height/2)))
    back=mound(420,0); im.alpha_composite(back,(int(W/2-back.width/2),H-back.height-34))
    s_=SCY.rotate(-80,expand=True,resample=Image.BICUBIC); s_=sc(s_,0.62)
    im.alpha_composite(s_,(int(W/2-s_.width/2+40),int(H-s_.height-60)))
    fr=mound(330,0); a=np.array(fr); a[...,3]=(a[...,3]*0.9).astype(np.uint8); fr=Image.fromarray(a)
    im.alpha_composite(fr,(int(W/2-fr.width/2-20),H-fr.height-22))       # straw spills over the shaft
    mk=sc(MASK.rotate(18,expand=True,resample=Image.BICUBIC),1.3)
    im.alpha_composite(mk,(int(W/2-mk.width/2-60),int(H-mk.height-62)))
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flipx else im
BS=0.31
_b=np.array(SMK).astype(float); _b[...,:3]=_b[...,:3]*0.35+4; BLACK=Image.fromarray(_b.clip(0,255).astype(np.uint8))   # near-black smoke for the burst
import matte as MT
_o,_f=MT.matte('war_remains_src.jpg',th=18); _src=np.array(Image.open('war_remains_src.jpg').convert('RGB')).astype(float); _bg=np.median(_src[:8].reshape(-1,3),0)
_al=_o[...,3].astype(float)/255; _al=np.clip((_al-0.15)/0.85,0,1)
_o[...,:3]=np.clip((_src-_bg*(1-_al[...,None]))/np.maximum(_al[...,None],0.2),0,255); _o[...,3]=(_al*255).astype(np.uint8); _o=Image.fromarray(_o); _a=np.array(_o); ys,xs=np.nonzero(_a[...,3]>30)
REM=_o.crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1)); REM_S=112/REM.width; REM=sc(REM,REM_S)
_ra=np.array(REM)[...,3]>120; _yy,_xx=np.nonzero(_ra); REM_GP=(float(_xx.mean()),float(_yy.mean())+0.18*(_yy.max()-_yy.mean()))   # ground point: heap centre
def cell(dn,ph,label):
    W=dn=='w'; side='front' if W else 'back'; lead=1 if W else -1; Ld=SH.LAY[dn]; g=SH.FL.copy()
    bx,by=Ld['b']; tx=(Ld['ij'][0]+Ld['ke'][0])/2; ty=(Ld['ij'][1]+Ld['ke'][1])/2
    v=np.array([bx-tx,by-ty]); v/=np.linalg.norm(v)    # away from heroes
    cfg=dict(hit1=dict(tilt=-9,push=14,glow=0.5,lift=0),hit2=dict(tilt=-4,push=22,glow=0.45,lift=-4),
             d1=dict(tilt=2,push=0,glow=2.2,lift=2),d2=dict(tilt=0,push=0,glow=2.5,lift=4),d3=None)[ph]
    items=[(Ld['ij'][1],'ij'),(Ld['ke'][1],'ke'),(by,'b')]
    for _,c in sorted(items):
        if c!='b':
            SH.put(g,SH.hero(c,'idle',Ld['hk'],0),*Ld[c],30); continue
        if cfg is None:
            r=REM if W else REM.transpose(Image.FLIP_LEFT_RIGHT); gx=REM_GP[0] if W else REM.width-REM_GP[0]
            sh=Image.new('RGBA',g.size); ImageDraw.Draw(sh).ellipse([bx-50,by-12,bx+50,by+12],fill=(0,0,0,80)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
            g.alpha_composite(r,(int(bx-gx),int(by-REM_GP[1]))); continue
        im,(fx,fy)=C4.boss(side,0.3,tilt=cfg['tilt'],glowk=cfg['glow'],swell=1.0 if ph=='d1' else 0)
        a=np.array(im); ys,xs=np.nonzero(a[...,3]>10); im=im.crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1)); fx-=xs.min(); fy-=ys.min()
        if ph.startswith('hit'):
            a=np.array(im).astype(float); k_=0.07 if ph=='hit1' else 0.035; a[...,0]*=1+k_; a[...,1]*=1-k_*0.3; a[...,2]*=1-k_*0.4; im=Image.fromarray(a.clip(0,255).astype(np.uint8))
        if ph=='d1':   # shudder: clean sideways shake = one offset copy with a short horizontal motion blur (no double image)
            import cv2
            a=np.array(im).astype(np.float32); pm=a[...,:3]*a[...,3:]/255; k=np.ones((1,9),np.float32)/9
            pm=cv2.filter2D(pm,-1,k); al=cv2.filter2D(a[...,3],-1,k)
            rgb=np.where(al[...,None]>0,pm*255/np.maximum(al[...,None],1),0); im=Image.fromarray(np.dstack([rgb,al]).clip(0,255).astype(np.uint8))
            fx-=7*lead
        if ph=='d2': im=SH.dissolve(im,0.62,seed=4)
        h=17+cfg['lift']; ox=bx+v[0]*cfg['push']; oy=by+v[1]*cfg['push']*0.5
        k=1-(h-15)/20*.4; sh=Image.new('RGBA',g.size); sw=44*k*(0.6 if ph=='d2' else 1); ImageDraw.Draw(sh).ellipse([ox-sw,oy-sw*.28,ox+sw,oy+sw*.28],fill=(0,0,0,int(110*k))); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
        imr=sc(im,BS); px,py=ox-fx*BS,oy-fy*BS-h; g.alpha_composite(imr,(int(px),int(py)))
        chest=(ox+(-4 if W else 4),oy-h-118)
        if ph=='hit1': puff(g,chest[0]-v[0]*22,chest[1]+18,0.26,0.95,rot_=90 if W else -90)
        if ph=='hit2': puff(g,chest[0]+v[0]*34,chest[1]+28,0.16,0.5,rot_=80)
        if ph=='d1':
            g=SH.screen(g,flare(16,1.6),(chest[0]-56,chest[1]-56),0.9)
            g=addglow(g,sc(EMB,0.3),chest[0],chest[1],0.8)
        if ph=='d2':
            for j,(dx,dy,s) in enumerate([(0,-40,0.42),(-30,10,0.34),(28,-5,0.36),(0,40,0.3),(-10,-100,0.3),(5,-60,0.38)]):
                pc(g,BLACK.rotate(90+30*j,expand=True).resize((int(BLACK.height*s),int(BLACK.width*s))) if False else sc(BLACK,s).rotate(90+30*j,expand=True,resample=Image.BICUBIC),ox+dx,oy-h-90+dy,0.95)
            g=SH.screen(g,flare(14,1.0),(chest[0]-49,chest[1]-49),0.35)
            for j,(dx,dy,ang) in enumerate([(-70,-150,25),(60,-170,-20),(-95,-60,10),(85,-80,-15)]):
                c=CROWS[j%3] if dx<0 else CROWS[j%3].transpose(Image.FLIP_LEFT_RIGHT)
                c=rim(sc(c,0.3),0.6).rotate(ang,expand=True,resample=Image.BICUBIC); pc(g,c,ox+dx,oy-h+dy-20)
            r=np.random.default_rng(5)
            for j in range(10): f=FEATH[j%3].rotate(r.uniform(0,360),expand=True); pc(g,f,ox+r.normal(0,55),oy-h-110+r.normal(0,45),0.9)
    if ph=='d3':
        r=np.random.default_rng(8); lay=Image.new('RGBA',g.size); d=ImageDraw.Draw(lay)
        for j in range(14):
            x=bx+r.normal(0,24); y=by-8-abs(r.normal(0,14)); q=r.uniform(0.6,1.1); d.ellipse([x-q,y-q,x+q,y+q],fill=(255,180,80,int(r.uniform(80,180))))
        g.alpha_composite(lay.filter(ImageFilter.GaussianBlur(0.7)))
        puff(g,bx+10,by-30,0.2,0.35,rot_=90)
    ImageDraw.Draw(g).text((10,8),f'{dn.upper()} {label}',font=SH.fnt,fill=(255,236,170,255),stroke_width=3,stroke_fill=(0,0,0,255))
    return g
PH=[('hit1','1 hit recoil'),('hit2','2 stagger'),('d1','3 death shudder'),('d2','4 burst'),('d3','5 remains')]
rows=[[cell(dn,p,l) for p,l in PH] for dn in ('w','e')]
SH.sheet(rows,'/workspace/foe_walks/harvest_v2/warden_hit_death_stills_WE_v2.png','')
