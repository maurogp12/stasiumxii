import numpy as np, cv2, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy import ndimage as nd
def load(n): return np.array(Image.open(n).convert('RGBA'))
def poly(shape,pts,w=None):
    im=Image.new('L',(shape[1],shape[0])); d=ImageDraw.Draw(im)
    if w: d.line(pts,fill=255,width=w)
    else: d.polygon(pts,fill=255)
    return np.array(im)>0
# landmarks in key-half coords (640x720)
RIG={
 ('war','front'):dict(neck=(285,155),head=[(235,30),(330,30),(330,160),(235,160)],
     arm=[(140,165),(240,165),(245,440),(140,440)],sh=(228,180),
     scy=dict(poly=[(398,15),(480,15),(610,80),(610,310),(550,310),(462,125),(445,330),(382,338),(415,110)],shaft=[(392,330),(300,682)],w=20),hand=(395,325),newrot=150,
     hip=430),
 ('war','back'):dict(neck=(255,135),head=[(205,30),(310,30),(310,140),(205,140)],
     arm=[(85,140),(175,140),(180,430),(85,430)],sh=(165,150),
     scy=dict(poly=[(372,38),(462,28),(558,140),(548,302),(505,302),(452,112),(425,245),(392,255),(408,100)],shaft=[(405,258),(396,600)],w=18),hand=(405,255),newrot=0,
     hip=430),
 ('sov','front'):dict(neck=(330,175),head=[(262,25),(392,25),(392,180),(262,180)],
     arm=[(395,240),(472,250),(478,412),(398,412)],sh=(405,250),
     scy=dict(poly=[(40,370),(110,368),(235,355),(242,398),(122,447),(102,530),(197,642),(150,655),(42,560)],shaft=None),hand=(225,378),newrot=0,
     hip=450),
 ('sov','back'):dict(neck=(300,175),head=[(232,20),(368,20),(368,180),(232,180)],
     arm=[(118,200),(198,200),(200,425),(118,425)],sh=(195,205),
     scy=dict(poly=[(418,343),(472,358),(582,388),(578,562),(482,632),(448,626),(530,540),(520,452),(470,422),(418,402)],shaft=None),hand=(430,372),newrot=0,
     hip=450),
}
def sick_parts(a):
    m=a[...,3]>40; lab,k=nd.label(nd.binary_dilation(m,iterations=2)); sz=nd.sum(m,lab,range(1,k+1)); main=np.argmax(sz)+1; out=[]
    for l in range(1,k+1):
        if l!=main and sz[l-1]>800:
            mm=lab==l; ys,xs=np.nonzero(mm); p=a.copy(); p[~mm,3]=0; a[mm,3]=0; out.append(Image.fromarray(p).crop((xs.min()-2,ys.min()-2,xs.max()+3,ys.max()+3)))
    return out
def inpaint(a,mask,fill_alpha):
    rgb=np.ascontiguousarray(a[...,:3]); m=(mask.astype(np.uint8)*255)
    m=cv2.dilate(m,np.ones((5,5),np.uint8)); known=(a[...,3]>200)&(m==0)
    res=cv2.inpaint(rgb,np.where(known,0,255).astype(np.uint8),9,cv2.INPAINT_TELEA)
    o=a.copy(); mm=m>0; o[...,:3][mm]=res[mm]; o[...,3][mm]=fill_alpha[mm]; return o
def build(boss,side):
    a=load(f'{boss}_{side}.png'); R=RIG[(boss,side)]; P=dict(R=R)
    sick=sick_parts(a) if boss=='sov' else []
    if boss=='sov' and side=='front':
        Y,X=np.mgrid[0:720,0:640]; mm=(((X>500)&(Y>385)&(Y<468))|((X>548)&(Y>385)&(Y<510)))&(a[...,3]>0); ys,xs=np.nonzero(mm); p=a.copy(); p[~mm,3]=0; a[mm,3]=0
        sick.append(Image.fromarray(p).crop((xs.min()-2,ys.min()-2,xs.max()+3,ys.max()+3)))
    while boss=='sov' and len(sick)<6: sick.append(sick[len(sick)%5].transpose(Image.FLIP_LEFT_RIGHT))
    P['sick']=sick
    sh=a.shape[:2]; al=a[...,3]>40
    # body silhouette used to decide where holes become robe (closing bridges cuts through the robe)
    S=R['scy']; sm=poly(sh,S['poly'])
    if S['shaft']: sm|=poly(sh,S['shaft'],S['w'])
    sm&=a[...,3]>0
    scy=a.copy(); scy[~sm,3]=0; P['scy']=Image.fromarray(scy)
    rest=al&~sm; sil=cv2.morphologyEx(rest.astype(np.uint8),cv2.MORPH_CLOSE,np.ones((31,31),np.uint8))>0
    am=poly(sh,R['arm'])&al; arm=a.copy(); fm=cv2.GaussianBlur((poly(sh,R['arm'])).astype(np.float32),(0,0),7); fm=np.clip((fm-0.15)/0.7,0,1); arm[...,3]=(arm[...,3]*fm).astype(np.uint8); P['arm']=Image.fromarray(arm)
    hm=poly(sh,R['head'])&al; head=a.copy(); fh=cv2.GaussianBlur(poly(sh,R['head']).astype(np.float32),(0,0),5); fh=np.clip((fh-0.15)/0.7,0,1); head[...,3]=(head[...,3]*fh).astype(np.uint8); P['head']=Image.fromarray(head)
    hole=sm|am
    fa=np.where(sil,255,0).astype(np.uint8); fa=np.where(am,np.where(nd.binary_erosion(sil,iterations=6),255,0),fa).astype(np.uint8)
    base=inpaint(a,hole,fa)
    base[...,3]=np.where(hole&~sil,0,base[...,3])
    P['base']=base
    ys,xs=np.nonzero(base[...,3]>40); P['bot']=ys.max(); P['foot']=((xs[ys>ys.max()-30].min()+xs[ys>ys.max()-30].max())/2,ys.max())
    P['top']=ys.min(); P['xl'],P['xr']=xs.min(),xs.max()
    # hem: 5 vertical strips x 2 segments below hip
    hip=R['hip']; bot=P['bot']; mid=hip+(bot-hip)*0.5; edges=np.linspace(P['xl']-5,P['xr']+5,6)
    strips=[]
    X=np.arange(640)[None,:]; Yv=np.arange(720)[:,None]
    for i in range(5):
        x0,x1=edges[i],edges[i+1]; fe=14
        wx=np.clip(np.minimum(X-x0+fe,x1-X+fe)/(2*fe),0,1)
        for j,(y0,y1) in enumerate(((hip,mid),(mid,bot+10))):
            wy=np.clip(np.minimum(Yv-y0+fe,y1-Yv+fe)/(2*fe),0,1) if j else np.clip(np.minimum(Yv-y0+fe*2,y1-Yv+fe)/(2*fe),0,1)
            s=base.copy(); s[...,3]=(s[...,3]*wx*wy).astype(np.uint8); strips.append((i,j,Image.fromarray(s),((x0+x1)/2,y0)))
    P['strips']=strips
    up=base.copy(); Yf=np.arange(720)[:,None]; up[...,3]=(up[...,3]*np.clip((hip+20-Yf)/30,0,1)).astype(np.uint8); P['upper']=Image.fromarray(up)
    under=base.copy(); under[...,:3]=(under[...,:3]*0.75).astype(np.uint8); P['under']=Image.fromarray(under)
    # roots: two clumps of the bottom fringe
    fx=P['foot'][0]; P['roots']=[]
    for dx in (-45,45):
        r=base.copy(); m=poly(sh,[(fx+dx-30,bot-40),(fx+dx+30,bot-40),(fx+dx+30,bot+2),(fx+dx-30,bot+2)]); r[~m,3]=0
        ys,xs=np.nonzero(r[...,3]>0); P['roots'].append((Image.fromarray(r).crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1)),(fx+dx,bot)))
    return P
def rot(im,ang,c): return im.rotate(ang,center=c,resample=Image.BICUBIC)
def pose(P,t,fwd,boss,sp_key):
    R=P['R']; ph=2*np.pi*t/1.0; OX,OY=180,120; W,Hh=640+360,720+200
    can=Image.new('RGBA',(W,Hh)); off=(OX,OY)
    def add(im,dx=0,dy=0): can.alpha_composite(im,(int(OX+dx),int(OY+dy)))
    bob=-26*abs(np.sin(ph))+10   # key px (x0.38 on screen ~ 10px)
    lag=lambda k:np.sin(ph-k)
    # sickles (back half)
    SK=[]
    if P['sick']:
        cx=(P['xl']+P['xr'])/2; cy=P['top']+(P['bot']-P['top'])*0.33; rx=(P['xr']-P['xl'])*0.78; ry=rx*0.3
        for i,s in enumerate(P['sick']):
            ang=2*np.pi*i/6+2*np.pi*t/8.0; z=np.sin(ang); sc=0.85+0.2*(z+1)/2
            x=cx+rx*np.cos(ang); y=cy+ry*z+14*np.sin(2*np.pi*t*0.5+i*1.3)+bob*0.3
            ss=s.resize((int(s.width*sc),int(s.height*sc))).rotate(45*t+i*60,resample=Image.BICUBIC,expand=True)
            SK.append((z,ss,x,y))
        for z,ss,x,y in sorted(SK,key=lambda q:q[0]):
            if z<0: add(ss,x-ss.width/2,y-ss.height/2)
    # roots: alternate stepping under hem (stance slides back with the floor)
    for k,(r,(rx_,ry_)) in enumerate(P['roots']):
        u=((t+0.5*k)%1.0); 
        if u<0.5: s=-1+4*u; lift=0         # swing forward
        else: s=1-4*(u-0.5)*1.0; lift=0
        lift=-14*np.sin(np.pi*min(1,u*2)) if u<0.5 else 0
        dx=fwd[0]*22*s; dy=fwd[1]*22*s+lift+8
        add(r,rx_-r.width/2+dx,ry_-r.height+dy)
    add(P['under'],0,bob*0.4)
    # hem strips: lag + follow-through, wave travels down
    hip=R['hip']
    for i,j,s,(cx,y0) in P['strips']:
        a1=7*lag(0.9+0.25*i)*(-fwd[0] if fwd[0] else 1)
        if j==0: add(rot(s,a1,(cx,hip)),0,bob*0.6)
        else:
            a2=a1+6*lag(1.8+0.25*i)*(-fwd[0] if fwd[0] else 1)
            # lower segment hangs from the rotated upper segment's end
            L=(y0-hip); ex=cx+L*np.sin(np.radians(-a1)); ey=hip+L*np.cos(np.radians(a1))
            add(rot(s,a2,(cx,y0)),ex-cx,ey-y0+bob*0.6)
    # upper body, arm, head
    add(P['upper'],0,bob)
    sw=20*np.sin(ph)
    arm=rot(P['arm'],sw,R['sh']); add(arm,0,bob)
    nod=-4*np.cos(2*ph); hd=rot(P['head'],nod*(1 if fwd[0]<0 else -1),R['neck']); add(hd,0,bob-3*np.cos(2*ph))
    # scythe
    sc=P['scy']; hx,hy=R['hand']
    if R['newrot']: sc=rot(sc,R['newrot'],(hx,hy))
    sc=rot(sc,10*np.sin(ph+0.6),(hx,hy)); add(sc,0,bob+6*np.sin(2*ph))
    for z,ss,x,y in sorted(SK,key=lambda q:q[0]):
        if z>=0: add(ss,x-ss.width/2,y-ss.height/2)
    # global: squash/stretch with the bob, lean toward travel, about the feet
    fx,fy=OX+P['foot'][0],OY+P['foot'][1]
    sq=0.03*np.cos(2*ph)
    can=can.resize((int(W*(1+sq)),int(Hh*(1-sq))),Image.BICUBIC); fx*=1+sq; fy*=1-sq
    lean=7*(1 if fwd[0]<0 else -1)
    can=can.rotate(lean,center=(fx,fy),resample=Image.BICUBIC)
    return can,(fx,fy)
# ---------------- scene (camera follows, tiles scroll) ----------------
QW,QH=960,540; TW,TH=96,48
DIRV={'n':(-1,-1),'e':(1,-1),'s':(1,1),'w':(-1,1)}
KEY={'w':('front',False),'s':('front',True),'e':('back',False),'n':('back',True)}
def floor(dn,off):
    im=Image.new('RGBA',(QW,QH),(16,18,24,255)); d=ImageDraw.Draw(im); vx,vy=DIRV[dn]
    ox=-vx*off*TW/2; oy=-vy*off*TH/2
    for i in range(-16,17):
        for j in range(-16,17):
            x=480+(i-j)*TW/2+ox; y=330+(i+j)*TH/2+oy
            if x<-60 or x>QW+60 or y<-40 or y>QH+40: continue
            onp=(j==0) if vx*vy>0 else (i==0)
            col=((70,62,44,255) if (i+j)%2 else (62,55,40,255)) if onp else ((38,42,54,255) if (i+j)%2 else (30,34,44,255))
            d.polygon([(x,y-TH/2),(x+TW/2,y),(x,y+TH/2),(x-TW/2,y)],fill=col,outline=(48,54,68,255))
    return im
fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',40)
def frameS(PP,boss,t,scale,dur):
    S=Image.new('RGB',(1920,1080))
    for k,dn in enumerate('nesw'):
        side,mir=KEY[dn]; vx,vy=DIRV[dn]
        fwd=np.array([vx*(-1 if mir else 1),vy],float); fwd/=np.linalg.norm(fwd)  # travel in key space
        tiles=2*t/1.0   # 1 tile step (half-diagonal) per half stride -> 2 steps per 1 s cycle
        g=floor(dn,tiles%2 if False else tiles%2)
        spr,(fx,fy)=pose(PP[side],t,fwd,boss,None)
        if mir: spr=spr.transpose(Image.FLIP_LEFT_RIGHT); fx=spr.width-fx
        spr=spr.resize((int(spr.width*scale),int(spr.height*scale)),Image.LANCZOS); fx*=scale; fy*=scale
        px,py=480,330
        sh=Image.new('RGBA',g.size); sw=75; ImageDraw.Draw(sh).ellipse([px-sw,py-sw*.27,px+sw,py+sw*.27],fill=(0,0,0,125)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
        g.alpha_composite(spr,(int(px-fx),int(py-fy)))
        ImageDraw.Draw(g).text((16,10),dn.upper(),font=fnt,fill=(255,236,170,255),stroke_width=4,stroke_fill=(0,0,0,255))
        S.paste(g.convert('RGB'),((k%2)*QW,(k//2)*QH))
    return S
if __name__=='__main__':
    boss=sys.argv[1]; scale=0.38; dur=8.0
    PP={s:build(boss,s) for s in ('front','back')}
    if len(sys.argv)>2:
        ts=[float(x) for x in sys.argv[2].split(',')]; C=Image.new('RGB',(640*len(ts),360))
        for j,t in enumerate(ts): C.paste(frameS(PP,boss,t,scale,dur).resize((640,360)),(j*640,0))
        C.save(f'/tmp/r2_{boss}_{sys.argv[2]}.png'); sys.exit()
    d=f'/tmp/_r2_{boss}'; os.makedirs(d,exist_ok=True)
    for i in range(int(dur*24)): frameS(PP,boss,i/24,scale,dur).save(f'{d}/{i:04d}.png')
    name={'war':'warden','sov':'sheaf_sovereign'}[boss]
    subprocess.run(f'ffmpeg -y -loglevel error -framerate 24 -i {d}/%04d.png -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 16 -movflags +faststart /workspace/foe_walks/harvest_v2/{name}_walk_4dir_v2.mp4',shell=True,check=True)
