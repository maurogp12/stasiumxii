# Sheaf Sovereign HIT + DEATH stills W/E (Spanish labels). Hit: recoil away, subtle warm tint, sickles jolt. Death: no fall -> smoke/wisps burst, sickles scatter & drop, crown + 6 sickles on ash/chaff heap.
import sys; sys.path.insert(0,'/workspace/foe_walks/harvest_spell_v1')
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFilter
import sheet as SH
from sovatk import PP, boss, BSMK, sickle_img, BS
from crows4 import SMK, sc, alpha

from crows4 import flare, pc
def warm(im,k):
    a=np.array(im).astype(float); a[...,0]*=1+k; a[...,1]*=1-k*0.3; a[...,2]*=1-k*0.4; return Image.fromarray(a.clip(0,255).astype(np.uint8))
def mblur(im,n):
    a=np.array(im).astype(np.float32); pm=a[...,:3]*a[...,3:]/255; k=np.ones((1,n),np.float32)/n
    pm=cv2.filter2D(pm,-1,k); al=cv2.filter2D(a[...,3],-1,k)
    rgb=np.where(al[...,None]>0,pm*255/np.maximum(al[...,None],1),0); return Image.fromarray(np.dstack([rgb,al]).clip(0,255).astype(np.uint8))
def crown(side):
    P=PP[side]; m=P['crown'].reshape(720,640); h=np.array(P['head']).copy(); h[...,3]=(h[...,3]*(m>0)).astype(np.uint8)
    ys,xs=np.nonzero(h[...,3]>20); c=h[ys.min():ys.max()+1,xs.min():xs.max()+1].astype(float)
    H=c.shape[0]; c[...,3]*=np.clip((H-np.arange(H)[:,None])/(H*0.25),0,1)   # fade the cut at the brow
    return Image.fromarray(c.astype(np.uint8))
CR={s:crown(s) for s in PP}
def ash_heap(w,seed=2):
    H=int(w*0.38); r=np.random.default_rng(seed); Y,X=np.mgrid[0:H,0:w].astype(float)
    nx=(X-w/2)/(w/2); top=H*(1-0.62*np.clip(1-nx**2,0,1)**0.8)+cv2.GaussianBlur(r.normal(0,1,(H,w)).astype(np.float32),(0,0),2)*2
    al=np.clip((Y-top)/3,0,1)*np.clip((H-Y)/2+0.3,0,1)
    n=cv2.GaussianBlur(r.normal(0,1,(H,w)).astype(np.float32),(0,0),1.2)
    sh=0.55+0.45*np.clip(1-(Y-top)/(H*0.6),0,1)
    rgb=np.dstack([22+10*n,19+8*n,20+9*n])*sh[...,None]
    im=Image.fromarray(np.dstack([rgb.clip(0,255),al*235]).astype(np.uint8)); d=ImageDraw.Draw(im)
    for j in range(int(w*0.25)):   # wheat chaff flecks
        x=r.uniform(0.1,0.9)*w; yt=H*(1-0.62*max(0,1-((x-w/2)/(w/2))**2)**0.8); y=r.uniform(yt+1,H-1); a=r.uniform(0,np.pi); L=r.uniform(2,5)
        d.line([x,y,x+L*np.cos(a),y-L*np.sin(a)*0.5],fill=(int(r.uniform(70,110)),int(r.uniform(55,80)),35,int(r.uniform(60,120))),width=1)
    return im
def wisps(g,cx,cy,k,seed,spread=1.0):
    r=np.random.default_rng(seed); lay=Image.new('RGBA',g.size); d=ImageDraw.Draw(lay)
    for j in range(16):
        a=r.uniform(0,2*np.pi); L=r.uniform(40,110)*spread; pts=[]
        for u in np.linspace(0,1,14):
            pts.append((cx+np.cos(a)*L*u+8*np.sin(u*6+j), cy+np.sin(a)*L*u*0.6-60*u*u*spread))
        for q in range(len(pts)-1):
            f=1-q/len(pts); d.line([pts[q],pts[q+1]],fill=(150,140,170,int(150*k*f)),width=max(1,int(3*f+1)))
    g.alpha_composite(lay.filter(ImageFilter.GaussianBlur(1.2)))
CFG={'h1':dict(push=10,tilt=-8,tint=0.07,gk=0.6,jolt=1.0,lift=0),
     'h2':dict(push=16,tilt=-4,tint=0.035,gk=0.45,jolt=0.45,lift=-3),
     'h3':dict(push=4,tilt=-1,tint=0.0,gk=0.35,jolt=0.1,lift=0),
     'd1':dict(push=0,tilt=3,tint=0.0,gk=1.6,lift=3),'d2':dict(push=0,tilt=0,tint=0,gk=2.0,lift=5),'d3':{},'d4':{}}
def cell(dn,ph,label):
    W=dn=='w'; side='front' if W else 'back'; lead=1 if W else -1; Ld=SH.LAY[dn]; Q=CFG[ph]
    IJ=np.array(Ld['ij'],float); KE=np.array(Ld['ke'],float)
    BP=IJ+(np.array([48,-24]) if W else np.array([-96,0]))
    v=BP-(IJ+KE)/2; v/=np.linalg.norm(v)
    g=SH.FL.copy(); h=17+Q.get('lift',0); pos=BP+v*Q.get('push',0)*np.array([1,0.5])
    cx0,cy0=pos[0],pos[1]-h-115; rx,ry=88,28
    alive=ph in('h1','h2','h3','d1','d2')
    # shadow under the unit (shrinks as he dissolves)
    shk={'d2':0.55,'d3':0.25}.get(ph,1.0)
    if ph!='d4':
        k=1-(h-15)/20*.4; sw=50*k*shk; s=Image.new('RGBA',g.size)
        ImageDraw.Draw(s).ellipse([pos[0]-sw,pos[1]-sw*.28,pos[0]+sw,pos[1]+sw*.28],fill=(0,0,0,int(115*k*shk))); g.alpha_composite(s.filter(ImageFilter.GaussianBlur(5)))
    # sickles
    SK=[]
    for i in range(6):
        a=2*np.pi*i/6+0.4
        if ph.startswith('h'):
            j=Q['jolt']; rr=1+0.22*j; a+=0.25*j
            x,y=cx0+rx*rr*np.cos(a)+v[0]*14*j,cy0+ry*rr*np.sin(a)-18*np.cos(a)-6*j; z=np.sin(a); ang=lead*30*j*(1 if i%2 else -1)
        elif ph=='d1':
            rr=1.15; x,y=cx0+rx*rr*np.cos(a),cy0+ry*rr*np.sin(a)-18*np.cos(a)-8; z=np.sin(a); ang=lead*15*np.sin(i*2.1)
        elif ph=='d2':   # flung outward
            rr=1.75; x,y=cx0+rx*rr*np.cos(a),cy0+ry*rr*np.sin(a)-30*np.cos(a)-20+[0,-14,6,-8,10,-4][i]; z=np.sin(a); ang=[70,-130,160,-40,110,-90][i]*lead
        elif ph=='d3':   # tumbling down, two already landed
            fx_=[-60,-30,10,40,70,-10][i]; fy_=[-70,-30,-5,-55,-20,-110][i]
            x,y=pos[0]+fx_*lead,pos[1]+fy_*0.9; z=1; ang=[200,-120,95,250,-160,30][i]*lead
        else:
            continue
        SK.append((z,i,x,y,ang))
    def draw_sick(front):
        for z,i,x,y,ang in sorted(SK):
            if (z>=0)!=front: continue
            dk=1.0 if z>=0 else 0.75
            if ph in('h1','d2','d3'):   # short motion streak
                for q,kq in ((1,0.18),(2,0.08)):
                    dx,dy=(v[0]*-8*q,0) if ph=='h1' else ((x-cx0)*-0.08*q,(y-cy0)*-0.08*q) if ph=='d2' else (0,-10*q)
                    t_=sickle_img(side,i,ang,BS*1.05,dk,kq); g.alpha_composite(t_,(int(x+dx-t_.width/2),int(y+dy-t_.height/2)))
            s=sickle_img(side,i,ang,BS*1.05,dk); g.alpha_composite(s,(int(x-s.width/2),int(y-s.height/2)))
    draw_sick(False)
    if alive:
        im,(fx,fy),_,_=boss(side,lead,0,Q['tilt'],Q['gk'])
        im=im.resize((int(im.width*BS),int(im.height*BS)),Image.LANCZOS)
        if Q['tint']>0: im=warm(im,Q['tint'])
        if ph=='d1': im=mblur(im,7)
        if ph=='d2': im=SH.dissolve(im,0.6,seed=4)
        ox,oy=pos[0]-fx*BS-(5*lead if ph=='d1' else 0),pos[1]-fy*BS-h
        g.alpha_composite(im,(int(ox),int(oy)))
    chest=(pos[0]+(-4 if W else 4),pos[1]-h-118)
    if ph=='h1':
        g=SH.screen(g,flare(18,1.3),(chest[0]-63,chest[1]-43),0.55)
        pc(g,sc(BSMK,0.22).rotate(90 if W else -90,expand=True),chest[0]+v[0]*20,chest[1]+18,0.7)
    if ph=='h2': pc(g,sc(BSMK,0.15).rotate(80,expand=True),chest[0]+v[0]*34,chest[1]+28,0.4)
    if ph=='d1':
        g=SH.screen(g,flare(16,1.6),(chest[0]-56,chest[1]-56),0.8); wisps(g,chest[0],chest[1]+10,0.45,3,0.6)
    if ph=='d2':
        for j,(dx,dy,s) in enumerate([(0,-40,0.42),(-30,10,0.34),(28,-5,0.36),(0,40,0.3),(-10,-100,0.3),(5,-60,0.38)]):
            pc(g,sc(BSMK,s).rotate(90+30*j,expand=True,resample=Image.BICUBIC),pos[0]+dx,pos[1]-h-90+dy,0.85)
        wisps(g,chest[0],chest[1],1.0,5,1.2); g=SH.screen(g,flare(14,1.0),(chest[0]-49,chest[1]-49),0.3)
    if ph=='d3':
        for j,(dx,dy,s,a_) in enumerate([(0,-120,0.36,0.5),(-20,-180,0.3,0.35),(15,-60,0.3,0.55)]):
            pc(g,sc(BSMK,s).rotate(90+40*j,expand=True),pos[0]+dx,pos[1]+dy,a_)
        wisps(g,pos[0],pos[1]-150,0.5,9,1.5)
        c=CR[side]; c=sc(c,BS*1.05).rotate(35*lead,expand=True,resample=Image.BICUBIC); pc(g,c,pos[0]-8*lead,pos[1]-95)   # crown falling
    if ph=='d4':
        s=Image.new('RGBA',g.size); ImageDraw.Draw(s).ellipse([pos[0]-52,pos[1]-13,pos[0]+52,pos[1]+13],fill=(0,0,0,90)); g.alpha_composite(s.filter(ImageFilter.GaussianBlur(5)))
        hp=ash_heap(120); g.alpha_composite(hp,(int(pos[0]-hp.width/2),int(pos[1]-hp.height+12)))
        for i,(dx,dy,ang) in enumerate([(-38,2,100),(34,-4,-80),(-14,8,170),(18,6,-150),(-50,-6,60),(48,4,-110)]):
            s_=sickle_img(side,i,ang*lead,BS*0.95,0.85); g.alpha_composite(s_,(int(pos[0]+dx*lead-s_.width/2),int(pos[1]+dy-s_.height/2)))
        hp2=ash_heap(64,5); g.alpha_composite(hp2,(int(pos[0]-hp2.width/2-14*lead),int(pos[1]-hp2.height+16)))
        c=sc(CR[side],BS*1.25).rotate(-18*lead,expand=True,resample=Image.BICUBIC); g.alpha_composite(c,(int(pos[0]-c.width/2+6*lead),int(pos[1]-c.height+2)))
        r=np.random.default_rng(8); lay=Image.new('RGBA',g.size); d=ImageDraw.Draw(lay)
        for j in range(12):
            x=pos[0]+r.normal(0,26); y=pos[1]-4-abs(r.normal(0,10)); q=r.uniform(0.6,1.1); d.ellipse([x-q,y-q,x+q,y+q],fill=(190,150,230,int(r.uniform(60,150))))
        g.alpha_composite(lay.filter(ImageFilter.GaussianBlur(0.7))); wisps(g,pos[0],pos[1]-10,0.25,11,0.5)
    for c in ('ij','ke'): SH.put(g,SH.hero(c,'idle',Ld['hk'],0),*Ld[c],30)
    draw_sick(True)
    return g
PHL=[('h1','GOLPE'),('h2','RETROCESO'),('h3','RECUPERA'),('d1','ESTREMECIMIENTO'),('d2','ESTALLIDO DE HUMO'),('d3','HOCES CAEN'),('d4','RESTOS')]
if __name__=='__main__':
    CW,CHh=274,343; S=Image.new('RGB',(1920,1080),(10,10,14)); d=ImageDraw.Draw(S)
    d.text((960,22),'SOBERANO DE LA GAVILLA — IMPACTO Y MUERTE (W / E)',font=SH.fnt,fill=(255,236,170),anchor='mt',stroke_width=3,stroke_fill=(0,0,0))
    for r_,dn in enumerate('we'):
        for k,(p,l) in enumerate(PHL):
            c=cell(dn,p,l).crop((0,60,384,540) if dn=='w' else (0,0,384,480)).resize((CW,CHh),Image.LANCZOS); x=k*CW+1; y=70+r_*(CHh+130)
            S.paste(c.convert('RGB'),(x,y)); d.text((x+8,y+6),dn.upper(),font=SH.fnt,fill=(255,236,170),stroke_width=3,stroke_fill=(0,0,0))
            d.text((x+CW//2,y+CHh+8),f'{k+1} {l}',font=SH.fnt,fill=(255,236,170),anchor='mt',stroke_width=2,stroke_fill=(0,0,0))
        d.text((10,y+CHh+50),'',font=SH.fnt)
    d.line([(3*CW,70),(3*CW,1070)],fill=(255,236,170),width=2)
    d.text((1.5*CW,1050),'IMPACTO',font=SH.fnt,fill=(200,190,150),anchor='mm'); d.text((5*CW,1050),'MUERTE',font=SH.fnt,fill=(200,190,150),anchor='mm')
    S.save('/workspace/foe_walks/harvest_v2/sov_hit_death_stills_WE_v1.png')
    for dn in 'we':
        for p,l in PHL: cell(dn,p,l).save(f'/tmp/sovhd_{dn}_{p}.png')
