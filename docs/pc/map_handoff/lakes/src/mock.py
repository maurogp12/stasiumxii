import numpy as np, cv2, json, sys
from PIL import Image
sys.argv=['x']; exec(open('/workspace/stasium-pc-look/ship/lakes_v1/src/build.py').read().split('# ---------- 1. TILES')[0])
R='/workspace/stasium-pc-look/ship/lakes_v1'
ANIMIDS=set(); ANIMPOS=[]
GRADE=np.array([.66,.74,.84]); SC={}
EX=np.array([23.0,11.4]); EY=np.array([-23.0,11.35]); K=46/128  # 2x master -> capture scale
def setup(o):
    O=np.array(o,float); M=np.array([EX,EY]).T; Mi=np.linalg.inv(M)
    def scr(tx,ty,x0,y0): return O+(tx-x0)*EX+(ty-y0)*EY
    return O,Mi,scr
def build(zone,cap,O,x0,x1,y0,y1,shape,props,out,restore=None):
    img=np.array(Image.open(CAP+cap).convert('RGB')).astype(float); H,W=img.shape[:2]
    Mi=np.linalg.inv(np.array([EX,EY]).T)
    yy,xx=np.mgrid[0:H,0:W]; rel=np.stack([xx-O[0],yy-O[1]],-1)@Mi.T
    tx=rel[...,0]+x0; ty=rel[...,1]+y0
    rect=(tx>=x0)&(tx<x1)&(ty>=y0)&(ty<y1); rect[H-30:]=False
    ring=(tx>=x0-1.5)&(tx<x1+1.5)&(ty>=y0-1.5)&(ty<y1+1.5)&~((tx>=x0-.2)&(tx<x1+.2)&(ty>=y0-.2)&(ty<y1+.2))
    ring&=(img.sum(2)>120)  # skip void
    # de-overlay: obs = o(1-a)+aC
    si=img[rect].std(0); so=img[ring].std(0); a=float(np.clip(1-(si/so).mean(),0.05,0.8))
    C=(img[rect].mean(0)-img[ring].mean(0)*(1-a))/a
    clean=img.copy(); clean[rect]=(img[rect]-a*C)/(1-a)
    fx=np.abs(tx-np.round(tx)); fy=np.abs(ty-np.round(ty))
    line=((fx*23<2.4)|(fy*23<2.4))&(tx>=x0-.15)&(tx<=x1+.15)&(ty>=y0-.15)&(ty<=y1+.15)
    clean=np.clip(clean,0,255).astype(np.uint8)
    clean=cv2.inpaint(clean,line.astype(np.uint8)*255,4,cv2.INPAINT_TELEA).astype(float)
    print(zone,'overlay alpha',round(a,3),'C',C.round())
    # lake distance (tiles)
    d=shape(tx,ty)
    g=globals()
    for nm in (['WD','WS','WM','GR'] if g['WD'].shape[0]>92 else []):
        t=g[nm]; g[nm]=np.array(Image.fromarray(np.clip(t,0,255).astype(np.uint8)).resize((92,92),Image.LANCZOS)).astype(float)
    kind='row' if zone=='rowanvale' else 'win'
    f=field_rgb(kind,d,W,H,0,0,11)
    if kind=='row': al=np.clip((d+.45)/.45,0,1)
    else:
        al=np.clip((d+.6)/.6,0,1)
    if kind=='row':
        lipm=((d>-.16)&(d<.03))[...,None]; nn=noise(W,H,4,9)[...,None]
        f=np.where(lipm,np.array([96,72,44.])*(.8+.4*nn),f); al=np.where(lipm[...,0],1.0,al); al=np.where(d<-.16,0,al)
        dk=np.clip(d/2.5,0,1)[...,None]*(d>0)[...,None]; f=f*(1-.28*dk)*np.where(d[...,None]>0,np.array([.86,.92,.94]),1)
    else:
        n1=noise(W,H,10,21); n2=noise(W,H,40,22)
        icec=np.array([112,138,160.])*(.88+.24*n1[...,None])
        frost=np.clip((n2-.55)/.12,0,1)[...,None]; icec=icec*(1-frost*.6)+np.array([186,200,210.])*frost*.6
        deep=np.clip(d/2.2,0,1)[...,None]; icec=icec*(1-.25*deep)
        lip=((d>0)&(d<.12))[...,None]; icec=np.where(lip,icec*.62,icec)
        snow=np.array([214,222,230.])*(.9+.12*n1[...,None]); snow=np.where(((d>-.12)&(d<=0))[...,None],snow*.8,snow)
        f=np.where((d>0)[...,None],icec,snow)*np.array([.86,.9,.96])
        rim_out=-.38-.06*np.sin(tx*7)*np.cos(ty*5)
        al=(d>rim_out).astype(float)
    res=clean*(1-al[...,None])+f*al[...,None]
    im=Image.fromarray(np.clip(res,0,255).astype(np.uint8))
    if kind=='win':
        ice_area=Image.fromarray(((d>0.05)*255).astype(np.uint8))
        cr=cracks(im.copy(),5,1400,col=(206,220,230),dark=(40,56,72),sc=1.3); im=Image.composite(cr,im,ice_area)
    im=im.convert('RGBA')
    if kind=='row' or True:
        import random as _r; rr=_r.Random(4); dr=ImageDraw.Draw(im)
        ys_,xs_=np.nonzero((d>-.3)&(d<-.12) if kind=='row' else (d>-.42)&(d<-.3))
        for k in range(0,len(xs_),max(1,len(xs_)//(70 if kind=='row' else 55))):
            x_,y_=xs_[k],ys_[k]; s_=rr.uniform(2,4.5) if kind=='row' else rr.uniform(3,6)
            base=(118,116,108) if kind=='row' else (92,100,112)
            dr.ellipse([x_-s_,y_-s_*.6,x_+s_,y_+s_*.6],fill=base); dr.ellipse([x_-s_*.7,y_-s_*.75,x_+s_*.5,y_],fill=(150,146,136) if kind=='row' else (220,228,236))
    for (px,py,spr) in sorted(props,key=lambda p:p[1]):
        if not isinstance(spr,str) and id(spr) in ANIMIDS: ANIMPOS.append((zone,px,py,spr)); continue
        if isinstance(spr,str): s=Image.open(R+'/'+spr) if not spr.startswith('/') else Image.open(spr)
        else: s=spr
        s=s.convert('RGBA'); sc=K*SC.get(id(spr),1) if not isinstance(spr,str) else K*SC.get(spr,1)
        if kind=='win':
            a_=np.array(s).astype(float); a_[...,:3]*=GRADE; s=Image.fromarray(np.clip(a_,0,255).astype(np.uint8))
        s=s.resize((max(1,round(s.width*sc)),max(1,round(s.height*sc))),Image.LANCZOS)
        im.alpha_composite(s,(int(px-s.width/2),int(py-s.height)))
    if restore is not None:
        m=restore(clean,rect)&(d>-1.5)
        m=cv2.dilate(m.astype(np.uint8),np.ones((2,2)))>0
        arr=np.array(im); arr[m,:3]=clean[m]; im=Image.fromarray(arr)
    im.convert('RGB').save(R+'/'+out); return im
def centre(O,x0,y0,tx,ty): return O+(tx+.5-x0)*EX+(ty+.5-y0)*EY+np.array([0,0])
def south(O,x0,y0,tx,ty): return O+(tx+1-x0)*EX+(ty+1-y0)*EY
def blob(cx,cy,rx,ry,seed):
    def f(tx,ty):
        ang=np.arctan2((ty-cy)/ry,(tx-cx)/rx); r=np.sqrt(((tx-cx)/rx)**2+((ty-cy)/ry)**2)
        w=1+.07*np.sin(3*ang+seed)+.05*np.sin(5*ang+2*seed)
        return (w-r)*min(rx,ry)
    return f
# ---- Rowanvale
O=np.array([842.5,258.5])
sh=blob(25.0,5.6,4.5,3.2,1.3)
fr=Image.open(R+'/rowanvale/anim/lake_jump_strip_2x.png'); LJ=json.load(open(R+'/rowanvale/anim/anim_meta.json'))['lake_jump']['_2x']
fish=fr.crop((7*LJ['frame_w'],0,8*LJ['frame_w'],LJ['frame_h']))
ring=Image.open(R+'/rowanvale/props/_2x/lake_spot_ring.png')
def at(tx,ty,dy=0): p=centre(O,20,2,tx,ty); return (p[0],p[1]+dy)
SC['rowanvale/props/_2x/lake_spot_ring.png']=.55; SC[id(fish)]=.6; ANIMIDS.add(id(fish))
pr=[]
pr+=[(*at(23,4.6,6),'rowanvale/props/_2x/lake_spot_ring.png'),(*at(23,4.6,6+ (LJ['frame_h']-LJ['pivot'][1])*K*.6),fish)]
pr+=[(*at(26.6,6.4,6),'rowanvale/props/_2x/lake_spot_ring.png')]
pr+=[(*at(24.3,7.95,8),'rowanvale/props/_2x/fishing_stake.png'),(*at(20.9,4.4,8),'rowanvale/props/_2x/fishing_stake.png')]
for (x,y,n) in [(21.3,3.2,'reeds_a'),(21.0,6.4,'reeds_b'),(22.0,8.0,'reeds_a'),(28.7,4.0,'reeds_b'),(29.1,6.2,'reeds_a'),(27.8,2.9,'reeds_b'),(23.4,2.4,'reeds_b'),(20.6,5.0,'reeds_a'),(26.0,2.5,'reeds_a'),(29.3,5.0,'reeds_b'),(28.3,7.3,'reeds_a'),(21.7,7.4,'reeds_b'),(24.6,2.3,'reeds_a')]:
    pr.append((*at(x,y,6),f'rowanvale/props/_2x/{n}.png'))
for (x,y,n) in [(22.3,5.4,'lily_pads_a'),(22.9,6.8,'lily_pads_b'),(27.3,3.8,'lily_pads_c'),(25.2,3.3,'lily_pads_b'),(28.0,5.6,'lily_pads_a')]:
    pr.insert(0,(*at(x,y,4),f'rowanvale/props/_2x/{n}.png'))
pr.append((*at(26.3,8.3,10),'rowanvale/props/_2x/jetty.png')); pr.append((*at(27.8,7.6,8),'rowanvale/props/_2x/rowboat.png'))
RB=build('rowanvale','lake_spots_rowanvale.png',O,20,30,2,9,sh,pr,'mock_rowanvale_lake_1280.png')
# ---- Windmere
O=np.array([842.5,268.5])
for nm in ['WD','WS','WM','GR']: globals()[nm]=globals()[nm]  # already scaled
sh=blob(24.8,4.9,4.4,2.75,.4)
def at(tx,ty,dy=0): p=centre(O,20,2,tx,ty); return (p[0],p[1]+dy)
bf=Image.open(R+'/windmere/anim/ice_bob_strip_2x.png'); bw=bf.width//12; bob=bf.crop((3*bw,0,4*bw,bf.height)); SC[id(bob)]=.8; ANIMIDS.add(id(bob))
SC['windmere/props/_2x/ice_hole.png']=1.7
pr=[]
for (x,y) in [(22,3),(25,4),(27,6)]:
    p=at(x,y,10); pr.insert(0,(p[0],p[1],'windmere/props/_2x/ice_hole.png'))
    pr.append((p[0]+0, p[1]-4+ (bf.height-120)*K*.8, bob))
SC['windmere/props/_2x/fishing_hut.png']=1.25; SC['windmere/props/_2x/sled.png']=1.1
pr.append((*at(20.6,7.5,10),'windmere/props/_2x/fishing_hut.png'))
for (x,y,n) in [(19.4,6.0,'pine_snow_mid_a'),(19.6,8.3,'pine_snow_small'),(23.0,8.6,'pine_snow_sapling'),(20.2,1.6,'pine_snow_mid_b'),(24.0,1.4,'pine_snow_small')]:
    pr.append((*at(x,y,8),'/workspace/stasium-pc-look/ship/map_polish/props/_2x/'+n+'.png'))
for (x,y,n) in [(21.6,8.4,'snow_rocks_b'),(19.8,7.0,'shore_boulder_a'),(23.6,1.8,'snow_rocks_a')]:
    pr.append((*at(x,y,6),f'windmere/props/_2x/{n}.png'))
pr.append((*at(22.4,7.9,8),'windmere/props/_2x/sled.png'))
for (x,y,n) in [(20.5,3.4,'shore_boulder_a'),(23.6,7.4,'shore_boulder_b'),(28.6,3.0,'shore_boulder_b'),(21.9,2.2,'snow_rocks_a'),(26.0,7.6,'snow_rocks_b'),(29.3,5.2,'snow_rocks_a'),(25.2,2.1,'shore_boulder_a')]:
    pr.append((*at(x,y,6),f'windmere/props/_2x/{n}.png'))
def trees(clean,rect):
    r,g,b=clean[...,0],clean[...,1],clean[...,2]; L=(r+g+b)/3
    m=(L>118)|((g>b-5)&(L<90)&(g>70))
    H,W=L.shape; yy,xx=np.mgrid[0:H,0:W]
    return m&(xx>880)&(yy>300)
WB=build('windmere','lake_spots_windmere.png',O,20,30,2,8,sh,pr,'mock_windmere_lake_1280.png',restore=trees)
# ---------- clips
import subprocess, shutil, os
fr_all={'row':[fr.crop((i*LJ['frame_w'],0,(i+1)*LJ['frame_w'],LJ['frame_h'])) for i in range(16)],'win':[bf.crop((i*bw,0,(i+1)*bw,bf.height)) for i in range(12)]}
def clip(base,zone,key,out,rings):
    tmp='/tmp/clip_'+zone; shutil.rmtree(tmp,ignore_errors=True); os.makedirs(tmp)
    for i in range(60):
        im=base.convert('RGBA').copy(); ov=Image.new('RGBA',im.size); dr=ImageDraw.Draw(ov)
        for (cx,cy) in rings:
            for k in range(3):
                ph=((i/30)+k/3)%1; rx=6+ph*22; a=int(110*(1-ph))
                dr.ellipse([cx-rx,cy-rx*.5,cx+rx,cy+rx*.5],outline=(220,232,236,a),width=1)
        im.alpha_composite(ov)
        for (z,px,py,spr) in ANIMPOS:
            if z!=zone: continue
            frames=fr_all[key]; idx=(i//1)%len(frames) if key=='row' else (i//1)%12
            if key=='row' and (i//16)%2==1: continue  # pause between jumps
            s=frames[idx]; sc=K*(.6 if key=='row' else .8)
            if key=='win':
                a_=np.array(s).astype(float); a_[...,:3]*=GRADE; s=Image.fromarray(np.clip(a_,0,255).astype(np.uint8))
            s=s.resize((max(1,round(s.width*sc)),max(1,round(s.height*sc))),Image.LANCZOS)
            im.alpha_composite(s,(int(px-s.width/2),int(py-s.height)))
        if i==20: im.convert('RGB').save(R+'/mock_'+zone+'_lake_1280.png')
        im.convert('RGB').save(f'{tmp}/{i:03d}.png')
    subprocess.run(['ffmpeg','-y','-loglevel','error','-framerate','12','-i',f'{tmp}/%03d.png','-c:v','libx264','-pix_fmt','yuv420p','-crf','18',R+'/'+out],check=True)
O=np.array([842.5,258.5]); ringsR=[tuple(centre(O,20,2,23,4.6)+[0,6]),tuple(centre(O,20,2,26.6,6.4)+[0,6])]
clip(RB,'rowanvale','row','clip_rowanvale_lake.mp4',ringsR)
O=np.array([842.5,268.5]); ringsW=[tuple(centre(O,20,2,x,y)+[0,10]) for x,y in [(22,3),(25,4),(27,6)]]
clip(WB,'windmere','win','clip_windmere_lake.mp4',[])
