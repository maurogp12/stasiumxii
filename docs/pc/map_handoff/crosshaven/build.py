import numpy as np,cv2,json,pickle,math,random,os
from PIL import Image,ImageDraw,ImageFilter
Image.MAX_IMAGE_PIXELS=None
random.seed(7)
PC='/workspace/stasium-pc-look/ship/crosshaven_full_v1/pieces/_2x/'
HS='/workspace/stasium-pc-look/ship/housing_v1/pieces/'
CH='/workspace/stasium-pc-look/ship/crosshaven_housing_v1/pieces/'
F=5; W,H=1024*F,576*F
def R(p):return (p[0]*F,p[1]*F)
cache={}
def spr(name,k,flip=False,src=PC):
  key=(name,k,flip,src)
  if key not in cache:
    im=Image.open(src+name+'.png').convert('RGBA')
    bb=im.getbbox();im=im.crop(bb)
    s=k*(0.5 if src==PC else 1)
    im=im.resize((max(1,int(im.width*s)),max(1,int(im.height*s))),Image.LANCZOS)
    if flip:im=im.transpose(Image.FLIP_LEFT_RIGHT)
    cache[key]=im
  return cache[key]
# ---------- ground textures (tile the iso diamonds into a seamless field)
def field(tile,w,h):
  t=Image.open(PC+tile+'.png').convert('RGBA');tw,th=t.size
  out=Image.new('RGBA',(w+tw,h+th))
  for j in range(-1,(h//(th//2))+2):
    for i in range(-1,w//tw+2):
      out.alpha_composite(t,(i*tw+(tw//2 if j%2 else 0),j*th//2)) if i*tw>=0 and j*th//2>=0 else out.paste(t,(i*tw+(tw//2 if j%2 else 0),j*th//2),t)
  return out.crop((0,0,w,h))
grass=field('tile_grass',W,H);cob=field('tile_cobble',W,H);water=field('tile_river_water',W,H);plaza=field('tile_plaza',W,H)
noise=cv2.resize(np.random.default_rng(1).random((H//160,W//160)).astype('float32'),(W,H),interpolation=cv2.INTER_CUBIC)
ga=np.array(grass.convert('RGB')).astype('float32');ga=ga*np.array([0.78,0.8,0.7])*(0.88+0.24*noise[...,None]);grass=Image.fromarray(np.clip(ga,0,255).astype('uint8')).convert('RGBA')
G=grass.copy()
# ---------- layout (reference 1024x576 coords)
WALL=[(40,240),(290,38),(700,38),(990,235),(800,462),(530,540),(300,425),(132,352)]
RIVER=[(1024,40),(905,75),(840,112),(745,160),(690,205),(688,262),(640,318),(600,345),(530,375),(470,400),(400,428),(330,455),(296,478),(250,515),(170,560),(120,580)]
RW=22
ROADS=[ [(288,584),(450,500),(482,484),(505,463)],[(505,463),(610,442),(632,390),(552,350),(548,322),(560,300),(485,250)],
        [(485,250),(490,118)],
        [(485,250),(380,272),(250,282),(110,300),(0,320)],
        [(485,250),(600,175)],
        [(690,75),(712,96),(872,176),(905,330),(1024,350)],   # crossing 1 moved to the straight NE river stretch: road runs along iso X, bridge perpendicular to the water
        [(380,272),(410,345),(448,379),(508,409),(515,458)],
        [(450,470),(830,400)],
        [(380,272),(330,160),(300,95)],[(250,282),(200,180)],[(250,282),(240,400)],
        [(600,175),(640,95),(690,75)],[(410,345),(300,380)],
        [(632,390),(740,330),(820,300)] ]
RING=((485,250),118,72)
DIST={'1 Residencial (NPC)':[[(150,240),(215,140),(300,70),(420,70),(420,200),(330,175),(250,235)],[(640,70),(700,55),(960,235),(900,300),(830,280),(760,240),(730,180),(700,110)],[(150,350),(240,330),(300,345),(390,370),(440,400),(380,430),(330,425),(200,380)]],
 '2 Mercado Global':[[(320,240),(420,240),(430,305),(320,305)]],
 '3 Civico/Banco':[[(560,140),(690,140),(700,215),(570,215)]],
 '4 Talleres/Forja':[[(80,250),(150,230),(310,215),(320,330),(150,340)]],
 '5 Catedral + parques':[[(420,180),(560,180),(580,240),(680,230),(700,300),(840,260),(860,330),(640,330),(560,330),(420,320)]],
 '6 Casas de jugadores':[[(440,415),(560,395),(700,370),(830,365),(800,460),(530,540),(450,500)]],
 '7 Castillo':[[(400,40),(590,40),(590,140),(400,140)]]}
def in_poly(p,poly):
  x,y=p;c=False
  for (x1,y1),(x2,y2) in zip(poly,poly[1:]+poly[:1]):
    if (y1>y)!=(y2>y) and x<(x2-x1)*(y-y1)/(y2-y1)+x1:c=not c
  return c
def district(p):
  for k,v in DIST.items():
    if any(in_poly(p,q) for q in v):return k
  return None
def poly_mask(draw_fn):
  m=Image.new('L',(W,H),0);d=ImageDraw.Draw(m);draw_fn(d);return np.array(m)>0
def drawline(d,pts,w):
  P=[R(p) for p in pts];d.line(P,fill=255,width=int(w*F),joint='curve')
  for p in P:d.ellipse([p[0]-w*F/2,p[1]-w*F/2,p[0]+w*F/2,p[1]+w*F/2],fill=255)
inside=poly_mask(lambda d:d.polygon([R(p) for p in WALL],fill=255))
riverM=poly_mask(lambda d:drawline(d,RIVER,RW))

# ---------- bridge pre-pass: bridge sprite ends define where the cobble road meets the deck
def _inter(p1,p2,p3,p4):
  (x1,y1),(x2,y2),(x3,y3),(x4,y4)=p1,p2,p3,p4;d=(x1-x2)*(y3-y4)-(y1-y2)*(x3-x4)
  if abs(d)<1e-9:return None
  t=((x1-x3)*(y3-y4)-(y1-y3)*(x3-x4))/d;u=-((x1-x2)*(y1-y3)-(y1-y2)*(x1-x3))/d
  return (x1+t*(x2-x1),y1+t*(y2-y1)) if 0<=t<=1 and 0<=u<=1 else None
BV2=os.environ.get('BRIDGE_V2','1')=='1';BV2D=os.environ.get('BRIDGE_V2_DIR','/workspace/meshy_pilot/bridge_v4');BV2M=json.load(open(BV2D+'/r2/bridge_v2_meta.json')) if BV2 else None
BMIRROR=os.environ.get('BRIDGE_MIRROR','1')=='1'
BV2LOG=[]
BRIDGE_K=float(os.environ.get('BRK','2.0'));BS=BRIDGE_K*0.5;RDW=13.4   # road width = deck width (67 px)
# measured on cropped+mirrored cw3_arch_bridge (2x px): inner deck edge points at each end, outward direction, deck centre-line
BEND=dict(nw=dict(P1=(14,44),P2=(78,14),d=(-1,-0.35)),se=dict(P1=(305,282),P2=(365,250),d=(0.55,0.83)))
BMID=[(50,31),(130,50),(200,105),(270,185),(335,266)]
BRIDGES=[];APPROACH=[];LAP=165
_newroads=[]
def _inrun(p,E,dv):
  P_=R(p);t=(P_[0]-E[0])*dv[0]+(P_[1]-E[1])*dv[1]
  if t<LAP+60:return True                      # behind/inside the straight run -> drop (prevents hairpins)
  O_=(E[0]+dv[0]*LAP,E[1]+dv[1]*LAP);v=(P_[0]-O_[0],P_[1]-O_[1]);n=math.hypot(*v)+1e-9
  return (v[0]*dv[0]+v[1]*dv[1])/n<-0.2           # vertex that would make the road turn back sharply
for r in ROADS:
  cur=[r[0]];skip=None
  for a,b in zip(r,r[1:]):
    q=None
    for c,d_ in zip(RIVER,RIVER[1:]):
      q=_inter(a,b,c,d_)
      if q and inside[int(q[1]*F),int(q[0]*F)] and all(math.dist(q,z['q'])>12 for z in BRIDGES):break
      q=None
    if not q:
      if skip and _inrun(b,*skip):continue
      skip=None;cur.append(b);continue
    if BV2:   # Meshy bridge v2: symmetric GLB render, identical stairs both ends; all geometry from projected 3D points
      mir=(b[0]-a[0])*(b[1]-a[1])>0;rot=0 if mir else 90;M2=BV2M[str(rot)];pp={k:(v[0]/2,v[1]/2) for k,v in M2['points_2x'].items()}
      im=Image.open(f'{BV2D}/r2/bridge_v2_r{rot:03d}_painted_1x.png').convert('RGBA')
      kn,ks=('b','a') if rot==0 else ('a','b')
      g0=((pp['a_out'][0]+pp['b_out'][0])/2,(pp['a_out'][1]+pp['b_out'][1])/2);qx,qy=R(q)
      ax_=(pp['a_out'][0]-pp['b_out'][0],pp['a_out'][1]-pp['b_out'][1]);an_=math.hypot(*ax_);ax_=(ax_[0]/an_,ax_[1]/an_)   # deck axis on the ground
      wet=lambda t:riverM[int(qy+ax_[1]*t),int(qx+ax_[0]*t)] if 0<=int(qy+ax_[1]*t)<H and 0<=int(qx+ax_[0]*t)<W else False
      lo_=0;hi_=0
      while wet(lo_-1):lo_-=1
      while wet(hi_+1):hi_+=1
      cmid=(lo_+hi_)/2;qx,qy=qx+ax_[0]*cmid,qy+ax_[1]*cmid      # ground centre of the bridge = centre of the water span
      X=qx-g0[0];Y=qy-g0[1]
      half=math.dist(pp['a_bot1'],pp['b_bot1'])/2;BV2LOG.append(dict(q=q,water_span=hi_-lo_,shift=cmid,stair_bottom_from_water_edge=round(half-(hi_-lo_)/2,1)))
      W_=lambda p:(X+p[0],Y+p[1])
      ends={};PPUp=M2.get('px_per_unit_plate',260);SZ=dict(top=round(M2.get('top_z',0.18)*math.cos(math.radians(30))*PPUp,1))
      for k,e in (('nw',kn),('se',ks)):
        P1,P2=W_(pp[e+'_bot1']),W_(pp[e+'_bot2']);E=((P1[0]+P2[0])/2,(P1[1]+P2[1])/2);o_=W_(pp[e+'_out'])
        dv=(o_[0]-E[0],o_[1]-E[1]);n_=math.hypot(*dv);dv=(dv[0]/n_,dv[1]/n_)
        ends[k]=dict(P1=P1,P2=P2,E=E,d=dv,O=(E[0]+dv[0]*LAP,E[1]+dv[1]*LAP),under=None,
                     stairs=[W_(pp[e+'_top1']),W_(pp[e+'_top2']),P2,P1],top=W_(((pp[e+'_top1'][0]+pp[e+'_top2'][0])/2,(pp[e+'_top1'][1]+pp[e+'_top2'][1])/2)))
      A_=R(a);ka='nw' if math.dist(ends['nw']['E'],A_)<math.dist(ends['se']['E'],A_) else 'se';kb='se' if ka=='nw' else 'nw'
      for k in(ka,kb):
        e=ends[k];dx,dy=e['d'];b0=-6
        APPROACH.append([(e['P1'][0]+dx*b0,e['P1'][1]+dy*b0),(e['P2'][0]+dx*b0,e['P2'][1]+dy*b0),(e['P2'][0]+dx*LAP,e['P2'][1]+dy*LAP),(e['P1'][0]+dx*LAP,e['P1'][1]+dy*LAP)])
      rr=lambda p:(p[0]/F,p[1]/F)
      while len(cur)>1 and _inrun(cur[-1],ends[ka]['E'],ends[ka]['d']):cur.pop()
      if len(cur)==1 and _inrun(cur[0],ends[ka]['E'],ends[ka]['d']):cur=[]
      cur.append(rr(ends[ka]['O']));_newroads.append(cur);skip=(ends[kb]['E'],ends[kb]['d'])
      cur=[rr(ends[kb]['O'])]+([] if _inrun(b,*skip) else [b])
      CHZ=M2.get('chz',[0,0.18,0.245,0.28,0.26,0.28,0.245,0.18,0])
      chi=list(range(9)) if ks=='a' else list(range(8,-1,-1))
      se_,nw_=ends['se'],ends['nw']
      CH=[(se_['E'][0]+se_['d'][0]*120,se_['E'][1]+se_['d'][1]*120)]+[W_(pp[f'ch{i}']) for i in chi]+[(nw_['E'][0]+nw_['d'][0]*120,nw_['E'][1]+nw_['d'][1]*120)]
      CZ=[0]+[round(CHZ[i]*math.cos(math.radians(30))*PPUp,1) for i in chi]+[0]
      CH[1]=se_['E'];CH[-2]=nw_['E']
      BRIDGES.append(dict(chain=CH,chain_z=CZ,se_stairs=se_['stairs'],nw_stairs=nw_['stairs'],stair_top_z=SZ['top'],steps=[],ramps=[],q=q,a=a,b=b,im=im,X=X,Y=Y,ends=ends,mid=[W_(pp['ch4'])],mir=mir,v2=dict(rot=rot)))
      continue
    im=spr('cw3_arch_bridge',BRIDGE_K,flip=False).transpose(Image.FLIP_LEFT_RIGHT);w_=im.width
    mir=(b[0]-a[0])*(b[1]-a[1])>0
    if not mir:im=im.transpose(Image.FLIP_LEFT_RIGHT)
    fx=(lambda p:(p[0]*BS,p[1]*BS)) if mir else (lambda p:(w_-1-p[0]*BS,p[1]*BS))
    fd=(lambda v:v) if mir else (lambda v:(-v[0],v[1]))
    mid=fx(BMID[2]);qx,qy=R(q);X=qx-mid[0];Y=qy-mid[1]
    W_=lambda p:(X+fx(p)[0],Y+fx(p)[1])
    ends={};RAMPS_=[];STEPS_=[]
    for k,e in BEND.items():
      P1,P2=W_(e['P1']),W_(e['P2'])
      dv=fd(e['d']);n_=math.hypot(*dv);dv=(dv[0]/n_,dv[1]/n_);UNDER=None
      if k=='nw':   # raised far abutment -> stone steps cut from the SE flight, warped to the NW direction, down to road level
        hgt=55*BS;FL=150*BS
        if BMIRROR:   # exact iso mirror of the SE flight: SE run 30 px along +X with 31 px drop -> NW run along -X, same ratio, down to ground
          dv=fd((-1,-0.5));n_=math.hypot(*dv);dv=(dv[0]/n_,dv[1]/n_);FL=30*(55/31)*1.118*BS
        Po1,Po2=W_((3,40)),W_((77,8))
        T1=(Po1[0]+dv[0]*FL,Po1[1]+dv[1]*FL+hgt);T2=(Po2[0]+dv[0]*FL,Po2[1]+dv[1]*FL+hgt)
        src=[fx((266,250)),fx((350,200)),fx((380,246)),fx((296,296))]     # SE flight: top-front, top-back, bottom-back, bottom-front
        dst=[Po1,Po2,T2,T1]
        G1,G2=T1,T2   # road meets the drawn bottom step exactly
        if BMIRROR:   # same outer width/orientation as the SE flight (across-deck vector is unchanged by the mirror), centred on the deck end
          m_=((Po1[0]+Po2[0])/2,(Po1[1]+Po2[1])/2);v_=(84*BS*(1 if mir else -1),-50*BS)
          Po1=(m_[0]-v_[0]/2,m_[1]-v_[1]/2);Po2=(m_[0]+v_[0]/2,m_[1]+v_[1]/2)
          T1=(Po1[0]+dv[0]*FL,Po1[1]+dv[1]*FL+hgt);T2=(Po2[0]+dv[0]*FL,Po2[1]+dv[1]*FL+hgt);dst=[Po1,Po2,T2,T1]
          lerp=lambda t:(T1[0]+(T2[0]-T1[0])*t,T1[1]+(T2[1]-T1[1])*t);G1,G2=lerp(0.107),lerp(0.82)   # inner tread edge = 68 px, like the SE join
        STEPS_.append(dict(Po1=Po1,Po2=Po2,d=dv,FL=FL,h=hgt,src=src,dst=dst,walk=[P1,P2,G2,G1],side=[Po1,T1,(Po1[0],Po1[1]+hgt)],under=[(P1[0],P1[1]+hgt),(P2[0],P2[1]+hgt),G2,G1]))
        UNDER=[(P1[0],P1[1]+hgt),(P2[0],P2[1]+hgt),G2,G1];P1,P2=G1,G2
      E=((P1[0]+P2[0])/2,(P1[1]+P2[1])/2)
      ends[k]=dict(P1=P1,P2=P2,E=E,d=dv,O=(E[0]+dv[0]*LAP,E[1]+dv[1]*LAP),under=UNDER)
    # which end faces a?
    A_=R(a);ka='nw' if math.dist(ends['nw']['E'],A_)<math.dist(ends['se']['E'],A_) else 'se';kb='se' if ka=='nw' else 'nw'
    for k in(ka,kb):
      e=ends[k];dx,dy=e['d'];b0=-14   # start slightly under the deck end / steps so no grass shows
      APPROACH.append([(e['P1'][0]+dx*b0,e['P1'][1]+dy*b0),(e['P2'][0]+dx*b0,e['P2'][1]+dy*b0),(e['P2'][0]+dx*LAP,e['P2'][1]+dy*LAP),(e['P1'][0]+dx*LAP,e['P1'][1]+dy*LAP)])  # straight, deck-wide
      if e['under']:APPROACH.append(e['under'])
    rr=lambda p:(p[0]/F,p[1]/F)
    while len(cur)>1 and _inrun(cur[-1],ends[ka]['E'],ends[ka]['d']):cur.pop()
    if len(cur)==1 and _inrun(cur[0],ends[ka]['E'],ends[ka]['d']):cur=[]
    cur.append(rr(ends[ka]['O']));_newroads.append(cur);skip=(ends[kb]['E'],ends[kb]['d'])
    cur=[rr(ends[kb]['O'])]+([] if _inrun(b,*skip) else [b])
    se_,nw_=ends['se'],ends['nw']
    CH=[(se_['E'][0]+se_['d'][0]*120,se_['E'][1]+se_['d'][1]*120),se_['E'],W_((308,226)),W_(BMID[2]),W_((46,28)),nw_['E'],(nw_['E'][0]+nw_['d'][0]*120,nw_['E'][1]+nw_['d'][1]*120)]
    CZ=[0,0,40,62,55,0,0]   # approximate elevation (px above ground) at each chain point
    BRIDGES.append(dict(chain=CH,chain_z=CZ,se_stairs=[W_(p) for p in [(266,250),(350,200),(380,246),(296,296)]],steps=STEPS_,ramps=RAMPS_,q=q,a=a,b=b,im=im,X=X,Y=Y,ends=ends,mid=[W_(p) for p in BMID],mir=mir))
  _newroads.append(cur)
ROADS=_newroads
def roads_draw(d):
  for r in ROADS:drawline(d,r,RDW)
  for qd in APPROACH:d.polygon(qd,fill=255)
  for B in BRIDGES:
    for e in B['ends'].values():
      ex,ey=e['P2'][0]-e['P1'][0],e['P2'][1]-e['P1'][1];Ln=math.hypot(ex,ey);ex,ey=ex/Ln,ey/Ln;dx,dy=e['d']
      A1=(e['P1'][0]-ex*25,e['P1'][1]-ey*25);A2=(e['P2'][0]+ex*25,e['P2'][1]+ey*25)
      d.polygon([A1,A2,(A2[0]+dx*40,A2[1]+dy*40),(A1[0]+dx*40,A1[1]+dy*40)],fill=0)
      d.polygon([e['P1'],e['P2'],(e['P2'][0]+dx*LAP,e['P2'][1]+dy*LAP),(e['P1'][0]+dx*LAP,e['P1'][1]+dy*LAP)],fill=255)
      if e['under']:d.polygon(e['under'],fill=255)
    for st in B['steps']:   # cobble under the whole NW landing + flight (no grass gap anywhere at the joint)
      hp=cv2.convexHull(np.array(st['walk'][:2]+st['dst'],np.float32)).reshape(-1,2);c_=hp.mean(0)
      d.polygon([tuple(c_+(p-c_)*1.12) for p in hp],fill=255)
  c,rx,ry=RING;d.ellipse([R((c[0]-rx-8,c[1]-ry-8)),R((c[0]+rx+8,c[1]+ry+8))],fill=255)
  d.ellipse([R((c[0]-rx+8,c[1]-ry+8)),R((c[0]+rx-8,c[1]+ry-8))],fill=0)
  # plaza around cathedral front + fountain park ring
  d.ellipse([R((440,250)),R((540,300))],fill=255)
  d.ellipse([R((585,255)),R((665,305))],fill=255);d.ellipse([R((600,265)),R((650,295))],fill=0)
  d.ellipse([R((745,272)),R((825,318))],fill=255)
  d.ellipse([R((330,250)),R((420,300))],fill=255)   # market square
  d.ellipse([R((585,165)),R((665,205))],fill=255)   # civic plaza
  d.ellipse([R((395,488)),R((470,520))],fill=255)   # gate apron
roadM=poly_mask(roads_draw)
# compose ground
def paste_mask(dst,tex,mask,feather=3):
  a=Image.fromarray((mask*255).astype('uint8')).filter(ImageFilter.GaussianBlur(feather))
  dst.paste(tex,(0,0),a)
paste_mask(G,cob,roadM&~riverM)
park=poly_mask(lambda d:(d.ellipse([R((604,268)),R((646,292))],fill=255)))
paste_mask(G,plaza,park)
# shore: dark wet band then water
shore=cv2.dilate(riverM.astype('uint8'),np.ones((25,25),np.uint8))>0
sh=Image.new('RGBA',(W,H),(104,112,92,255));paste_mask(G,sh,shore&~riverM,2)
# painted teal river (river_style.py); foam spots at bends, bridge piers and water gates
import river_style
_FP=[]
for i in range(1,len(RIVER)-1):
  a_,b_,c_=RIVER[i-1],RIVER[i],RIVER[i+1];t1=math.atan2(b_[1]-a_[1],b_[0]-a_[0]);t2=math.atan2(c_[1]-b_[1],c_[0]-b_[0])
  if abs((t2-t1+math.pi)%(2*math.pi)-math.pi)>math.radians(22):_FP.append((*R(b_),40))
FOAM_PTS=_FP
RIVSTYLE=None
def river_paint():
  global RIVSTYLE
  for a_,b_ in zip(WALL,WALL[1:]+[WALL[0]]):
    for c_,d_ in zip(RIVER,RIVER[1:]):
      q_=inter(a_,b_,c_,d_)
      if q_:FOAM_PTS.append((*R(q_),70))
  RIVSTYLE=river_style.River(riverM,FOAM_PTS)
  wv=Image.fromarray(RIVSTYLE.frame(0).astype('uint8')).convert('RGBA');paste_mask(G,wv,riverM,2)
# ---------- objects ; anchor = bottom-center
OBJ=[];FOOT=Image.new('L',(W,H),0);fd=ImageDraw.Draw(FOOT)
LOG=dict(rejected_on_road=0)
# reserve: wall band + clearance (no houses/plots touching the wall)
fd.line([R(p) for p in WALL+[WALL[0]]],fill=64,width=int(26*F))
PAVE=roadM|riverM
def occupied(x,y,w,h):
  a=np.array(FOOT.crop((int(x-w/2),int(y-h),int(x+w/2),int(y))))
  return a.size==0 or a.max()>0
def on_pave(x,y,fwid,fh,pad):
  a=PAVE[int(max(0,y-fh-pad)):int(min(H,y+pad)),int(max(0,x-fwid/2-pad)):int(min(W,x+fwid/2+pad))]
  return a.size and a.any()
def place(name,p,k,flip=False,src=PC,foot=0.32,fw=0.86,block=True,ref=True,force=False,tag=None,edge_ok=False):
  x,y=R(p) if ref else p;im=spr(name,k,flip,src)
  fh=max(8,im.height*foot);fwid=im.width*fw
  if not force:
    pad=38 if name in HOUSESET else 16
    if occupied(x,y+pad/3,fwid+pad,fh+pad*0.6):return False
    if on_pave(x,y,fwid,fh,0 if edge_ok else 14):LOG['rejected_on_road']+=1;return False
    if not inside[min(H-1,int(y)),min(W-1,int(x))]:return False
  fd.ellipse([x-fwid/2,y-fh,x+fwid/2,y],fill=255)
  OBJ.append(dict(n=name,im=im,x=x-im.width/2,y=y-im.height,ay=y,block=block,fp=(x,y,fwid,fh),tag=tag));return True
REUSED=set();NEW=set()
HOUSES=['cx_house_a','cx_house_b','cx_house_c','cx_cottage_restyle_a','cx_cottage_restyle_b','cx_cottage_restyle_c','cx_cottage_restyle_d','ex_cottage_a','ex_cottage_c','cx_cottage_thatch_a','cx_cottage_slate_a']
HOUSESET=set(HOUSES)
# ---------- landmarks by district
LM=[('cx_palace',(495,118),1.75,'castle'),('cx_cathedral',(487,244),1.65,'cathedral'),
    ('cx_town_hall',(600,165),1.45,'townhall'),('cx_convent',tuple(map(float,os.environ.get('CONVENT','660,188').split(','))),1.05,'bank'),
    ('cx_workshop_smith',(205,270),1.45,'forge'),('cx_workshop_potter',(160,318),1.4,'potter'),('cx_workshop_weaver',(270,318),1.4,'weaver'),
    ('cw5_craft_blacksmith',(240,225),1.25,'smithy2'),('cw5_craft_carpenter',(140,272),1.25,'carpenter'),('cw5_craft_tailor',(300,262),1.2,'tailor'),
    ('cx_water_mill',tuple(map(float,os.environ.get('MILL','735,330').split(','))),1.2,'mill')]
LMPOS={}
for n,p,k,t in LM:place(n,p,k,force=True,foot=0.3,tag=t);REUSED.add(n);LMPOS[t]=p
# fountain park: fountain on paving ring centre, beds on the grass outside the ring
place('cx_fountain_big',(625,284),1.2,force=True,foot=0.35,tag='fountain');REUSED.add('cx_fountain_big')
for a in range(0,360,30):
  x=625+52*math.cos(math.radians(a));y=280+31*math.sin(math.radians(a))
  place(random.choice(['ww_wild_rose','tn_wildflowers']),(x,y),1.1,block=False,tag='prop')
# gazebo park (no gazebo sprite: well + flower ring on grass)
place('cx_well',(785,298),1.3,force=True,tag='well');REUSED.add('cx_well')
for a in range(0,360,30):
  x=785+60*math.cos(math.radians(a));y=295+36*math.sin(math.radians(a))
  place(random.choice(['tn_wildflowers','ww_wild_rose']),(x,y),1.1,block=False,tag='prop')
REUSED|={'tn_wildflowers','ww_wild_rose'}
# Global Market: stalls ringing the market square (on paving edge, facing in)
STALLS=['cx_market_stall_a','cx_market_stall_b','cx_market_stall_spice','cx_stall_restyle_blue_a','cx_stall_restyle_red','cx_stall_restyle_blue_b']
MK=[]
for i,a in enumerate(range(200,520,55)):
  x=375+38*math.cos(math.radians(a));y=275+21*math.sin(math.radians(a))
  if place(STALLS[i%6],(x,y),1.3,force=True,foot=0.4,tag='stall'):MK.append((x,y))
REUSED|=set(STALLS)
# ---------- player housing (tier plots)
TIERS=json.load(open('housing_tiers/tiers.json'))
PLANTS=['tn_bush','tn_wildflowers','ww_wild_rose','cx_planter_a']
def place_plot(p,tier,gtier):
  x,y=R(p);hs=Image.open(f'housing_tiers/house_{tier}.png')
  OBJ.append(dict(n='house_'+tier,im=hs,x=x-hs.width/2,y=y-hs.height,ay=y,block=True,fp=(x,y,hs.width*0.85,hs.height*0.33),tag='house'))
  fd.ellipse([x-hs.width*0.45,y-hs.height*0.36,x+hs.width*0.45,y+6],fill=255)
  n=4 if tier=='normal' else 6 if tier=='rare' else 9
  for k_ in range(n):
    a=math.radians(200+k_*(300/n));r=hs.width*0.55/F
    nm=random.choice(PLANTS+(['tn_oak'] if tier=='legendary' and k_%4==0 else []));q=(p[0]+r*math.cos(a),p[1]+0.55*r*math.sin(a)+4)
    im_=spr(nm,0.9);qx,qy=R(q)
    if not on_pave(qx,qy,im_.width*0.8,im_.height*0.3,10):place(nm,q,0.9,block=False,tag='prop',force=True)
  return (x,y)
st=lambda x:470-0.184*(x-450)
PLOTS=[((555,st(555)-10),'normal','normal'),((668,st(668)-10),'rare','rare'),((752,st(752)-10),'legendary','legendary'),
       ((530,st(530)+50),'rare','normal'),((612,st(612)+50),'normal','rare'),((700,st(700)+48),'normal','normal')]
plot_ok=[];PLOTHOUSE=[]
for p,t,g in PLOTS:
  x,y=R(p);bw=Image.open(f'housing_tiers/house_{t}.png').size;bw=(bw[0],int(bw[1]*0.4))
  a=PAVE[int(y-bw[1]):int(y),int(x-bw[0]/2):int(x+bw[0]/2)];wl=np.array(FOOT)[int(y-bw[1]):int(y),int(x-bw[0]/2):int(x+bw[0]/2)]
  print("plot",p,t,'pave',round(float(a.mean()),3),'wall/occ',round(float((wl>0).mean()),3))
  if a.mean()<0.06 and (wl>0).mean()<0.03:PLOTHOUSE.append(place_plot(p,t,g));plot_ok.append((p,t,g))
print('plots',plot_ok)
# ---------- residential houses only in district 1
cand=[(x,y) for y in range(60,460,24) for x in range(60,1000,28)]
random.shuffle(cand);nh=0;HOUSEPOS=[]
for (x,y) in cand:
  x+=random.uniform(-5,5);y+=random.uniform(-3,3)
  if district((x,y))!='1 Residencial (NPC)':continue
  if place(random.choice(HOUSES),(x,y),1.12,flip=random.random()<0.5,foot=0.33,tag='house'):
    nh+=1;HOUSEPOS.append(R((x,y)))
    for dx,dy in [(-16,10),(16,10),(0,14)]:
      place(random.choice(['tn_bush','cx_planter_a','tn_wildflowers']),(x+dx,y+dy),1.0,block=False,tag='prop')
TREES=['cx_tree_plane','tn_oak','cx_tree_cypress','ww_poplar']
for (x,y) in cand:
  dd_=district((x,y))
  if dd_ in('1 Residencial (NPC)','5 Catedral + parques','7 Castillo') or (dd_ is None and inside[int(y*F),int(x*F)]):
    if random.random()<(0.5 if dd_ else 0.8):
      place(random.choice(TREES),(x+random.uniform(-10,10),y),random.uniform(1.0,1.25),foot=0.12,fw=0.3,tag='tree')
REUSED|=set(HOUSES)|set(TREES)|{'tn_bush','cx_planter_a'}
# few benches + lamps at the outer edge of the ring (on grass, touching edge allowed)
for a in (200,340):
  c,rx,ry=RING;x=c[0]+(rx+16)*math.cos(math.radians(a));y=c[1]+(ry+12)*math.sin(math.radians(a))
  place('tn_bench',(x,y),1.0,foot=0.5,tag='prop',edge_ok=True)
for a in range(0,360,60):
  c,rx,ry=RING;x=c[0]+(rx+12)*math.cos(math.radians(a));y=c[1]+(ry+10)*math.sin(math.radians(a))
  place('cx_lamp_post',(x,y),0.9,foot=0.08,fw=0.5,tag='lamp',edge_ok=True)
REUSED|={'tn_bench','cx_lamp_post'}
# ---------- walls (procedural continuous runs), towers, gate, water gates
def inter(p1,p2,p3,p4):
  (x1,y1),(x2,y2),(x3,y3),(x4,y4)=p1,p2,p3,p4;d=(x1-x2)*(y3-y4)-(y1-y2)*(x3-x4)
  if abs(d)<1e-9:return None
  t=((x1-x3)*(y3-y4)-(y1-y3)*(x3-x4))/d;u=-((x1-x2)*(y1-y3)-(y1-y2)*(x1-x3))/d
  return (x1+t*(x2-x1),y1+t*(y2-y1)) if 0<=t<=1 and 0<=u<=1 else None
stone=Image.open(PC+'tile_plaza.png').convert('RGB')
ST=np.array(field('tile_plaza',600,400).convert('RGB')).astype('float32')
ST=ST*0.35+np.array([200,186,160])*0.65
WH=92;WT=22   # wall height, top thickness (px)
_G2=Image.open(PC+'cw4_gate_open.png').convert('RGB');_bb=Image.open(PC+'cw4_gate_open.png').getbbox();_G2=_G2.crop(_bb)
_GS=0.575   # gatehouse game scale (k=1.15 on the 2x sprite) -> wall stones match its block size
def _patch(box):p=_G2.crop(box);return np.array(p.resize((max(1,round(p.width*_GS)),max(1,round(p.height*_GS))),Image.LANCZOS)).astype('float32')
FACE_T=_patch((250,295,277,385));TOP_T=_patch((185,200,250,225))
def _tiled(T,w,h,shear=0.0,seed=0):
  th,tw=T.shape[:2];yy,xx=np.mgrid[0:h,0:w];ys=(yy-np.round(shear*xx)).astype(int)
  row=ys//th;xo=(xx+row*7+seed)%(2*tw);xm=np.where(xo<tw,xo,2*tw-1-xo)   # mirror-tiled, rows offset like coursed masonry
  return T[ys%th,xm]
def wall_chunk(a,b):
  """a,b in px on the base line. Raised masonry wall in the gatehouse's own stone: plinth, vertical shaded face,
  top walkway band (iso depth), crenellations front+back, contact shadow on the grass."""
  s_=(b[1]-a[1])/((b[0]-a[0]) or 1e-6)
  back=(30.0,-15.0) if s_>=0 else (-30.0,-15.0)
  xs=[a[0],b[0],a[0]+back[0],b[0]+back[0]];ys=[a[1],b[1]]
  x0=int(min(xs))-6;y0=int(min(ys))-WH-30;x1=int(max(xs))+8;y1=int(max(ys))+16
  w,h=x1-x0,y1-y0;A=(a[0]-x0,a[1]-y0);B=(b[0]-x0,b[1]-y0)
  out=np.zeros((h,w,4),np.float32)
  def poly(pts):m=Image.new('L',(w,h),0);ImageDraw.Draw(m).polygon(pts,fill=255);return np.array(m)>0
  # contact shadow on the grass in front of the base
  yy,xx=np.mgrid[0:h,0:w];base_y=A[1]+s_*(xx-A[0]);dy=yy-base_y
  inx=(xx>=min(A[0],B[0]))&(xx<=max(A[0],B[0]))
  sh=inx&(dy>0)&(dy<14);out[sh,3]=np.clip(110*(1-dy[sh]/14),0,255);out[sh,:3]=(28,30,18)
  # vertical front face
  face=poly([A,B,(B[0],B[1]-WH),(A[0],A[1]-WH)])
  # coursed ashlar in WORLD coords (seamless across chunks), block size + colours sampled from the gatehouse face
  gx_=xx+x0;gy_=np.round(yy+y0-s_*(xx+x0)).astype(int)   # courses follow the wall slope
  BHt=5;row=np.floor_divide(gy_,BHt);rh=(row*2654435761)%997
  bw_=9+(rh%5);xo=gx_+(rh%11)*3;col_i=np.floor_divide(xo,bw_)
  hsh=((row*73856093)^(col_i*19349663))%1000/1000.0
  pal=FACE_T.reshape(-1,3);lum=pal.mean(1);pal=pal[(lum>np.percentile(lum,35))&(lum<np.percentile(lum,97))]
  T=pal[(hsh*(len(pal)-1)).astype(int)]*(0.92+0.16*((hsh*7)%1))[...,None]
  mort=((gy_%BHt)==0)|((xo%bw_)==0);T[mort]=T[mort]*0.62
  hfrac=np.clip(-dy/WH,0,1)[...,None]
  col=T*(0.80+0.22*hfrac)                       # darker toward the ground, lit toward the top
  col=col*np.where((-dy<11)[...,None],0.66,1.0)  # plinth / base course
  pl=face&(np.abs(-dy-11)<1.3);col[pl]=col[pl]*0.55
  out[face,:3]=col[face];out[face,3]=255
  # top walkway band (iso depth toward the wall's back)
  At=(A[0],A[1]-WH);Bt=(B[0],B[1]-WH)
  top=poly([At,Bt,(Bt[0]+back[0],Bt[1]+back[1]),(At[0]+back[0],At[1]+back[1])])
  TT=_tiled(TOP_T,w,h,seed=3);out[top,:3]=TT[top]*0.86;out[top,3]=255
  im=Image.fromarray(np.clip(out,0,255).astype('uint8'),'RGBA');d=ImageDraw.Draw(im)
  d.line([At,Bt],fill=(232,222,198,255),width=2)                        # lit coping edge
  d.line([A,B],fill=(70,62,50,255),width=2)
  # crenellations: back row (smaller, darker) then front row
  L=math.dist(A,B);n=max(1,int(L/17))
  def merlon(p,q_,hh,c1,c2):
    d.polygon([p,q_,(q_[0],q_[1]-hh),(p[0],p[1]-hh)],fill=c1)
    d.polygon([(p[0],p[1]-hh),(q_[0],q_[1]-hh),(q_[0]+back[0]*0.35,q_[1]-hh+back[1]*0.35),(p[0]+back[0]*0.35,p[1]-hh+back[1]*0.35)],fill=c2)
    d.line([(p[0],p[1]-hh),(q_[0],q_[1]-hh)],fill=(238,230,208,255),width=1)
  for row,(off,hh,c1,c2) in enumerate([(back,8,(170,156,132,255),(214,202,176,255)),((0,0),9,(196,182,156,255),(226,216,192,255))]):
    for k_ in range(n):
      t0=(k_+0.12)/n;t1=(k_+0.62)/n
      p=(At[0]+(Bt[0]-At[0])*t0+off[0],At[1]+(Bt[1]-At[1])*t0+off[1]);q_=(At[0]+(Bt[0]-At[0])*t1+off[0],At[1]+(Bt[1]-At[1])*t1+off[1])
      merlon(p,q_,hh,c1,c2)
  return im,(x0,y0)
wallM=Image.new('L',(W,H),0);wd=ImageDraw.Draw(wallM)
GATE=(450,500)
gate_im=spr('cw4_gate_open',1.15)
GAX,GAY=0.43,0.95       # arch ground point inside the gatehouse sprite
WG=[]
for a,b in zip(WALL,WALL[1:]+[WALL[0]]):
  for c,d in zip(RIVER,RIVER[1:]):
    q=inter(a,b,c,d)
    if q:WG.append((q,a,b))
GSPEC={'cw4_gate_open':dict(k=1.15,L=(45,345),R=(320,450),ax=190),
       'cw2_water_gate':dict(k=1.19,L=(22,162),R=(338,188),ax=180)}
def wg_finish(im,Y,slope,WLs):
  """Water gate: re-tone the stone to the wall ashlar palette and add the wall's merlon rows along its top."""
  from skimage import color as _c
  P=28;a=np.array(im).astype(np.float32);h,w=a.shape[:2]
  a=np.concatenate([np.zeros((P,w,4),np.float32),a],0)
  rgb=a[...,:3]/255;lab=_c.rgb2lab(rgb);al=a[...,3]>40
  stone=al&(lab[...,0]>38)&(lab[...,2]>4)&(np.abs(lab[...,1])<12)   # warm stone only; water, foam and arch shadow untouched
  ref=_c.rgb2lab((FACE_T.reshape(-1,3)/255)[None])[0]
  m=lab[stone].mean(0);sd=lab[stone].std(0)+1e-6;rm=ref.mean(0);rs=ref.std(0)
  lab[stone,0]=lab[stone,0]+(rm[0]-m[0])*0.5          # keep painted value contrast and mortar
  for ch in (1,2):lab[stone,ch]=(lab[stone,ch]-m[ch])*min(1.5,rs[ch]/sd[ch])+rm[ch]
  a[...,:3]=np.where(stone[...,None],np.clip(_c.lab2rgb(lab)*255,0,255),a[...,:3])
  # re-tone the painted arch water to the river palette (a/b + half the lightness shift) for a seamless join
  lab2=_c.rgb2lab(a[...,:3]/255);wat=al&(lab2[...,2]<-3)
  if wat.any():
    tgt=_c.rgb2lab(np.array([[[54,136,144]]])/255)[0,0]
    for ch,kk in ((0,0.5),(1,1.0),(2,1.0)):lab2[wat,ch]+= (tgt[ch]-np.median(lab2[wat,ch]))*kk
    a[...,:3]=np.where(wat[...,None],np.clip(_c.lab2rgb(lab2)*255,0,255),a[...,:3])
  # tone down the bright lit edge strips where the gate meets the wall (outer 7 px of each side)
  opm=a[...,3]>40;cl=np.where(opm.any(0))[0]
  for xs_ in (range(cl.min(),cl.min()+7),range(cl.max()-6,cl.max()+1)):
    for x_ in xs_:
      col_=a[:,x_,:3];br=col_.mean(1)>170;col_[br]=col_[br]*0.80
  out=Image.fromarray(a.astype('uint8'),'RGBA');d=ImageDraw.Draw(out)
  op=np.array(out)[...,3]>40;cols=np.where(op.any(0))[0]
  raw=np.array([np.argmax(op[:,x]) if op[:,x].any() else 10**6 for x in range(w)],float)
  from scipy.ndimage import median_filter,minimum_filter
  topy=median_filter(minimum_filter(raw,5),11)
  # straight coping line at the wall's slope (fit to the gate's inner top) so the wall-walk runs on continuously
  c0=float(WLs[1]+P-WH-slope*WLs[0])            # same coping height as the wall top at the join
  def T(x):return c0+slope*x
  A_=np.array(out).astype(np.float32);hh_=A_.shape[0];yy_=np.arange(hh_)[:,None];xx_=np.arange(w)[None,:]
  ln=c0+slope*xx_
  A_[(yy_<ln+3)[...,None].repeat(4,2)&(np.arange(4)==3)]=0
  # fill any gap between the coping line and the gate's stone with coursed wall ashlar
  pal=FACE_T.reshape(-1,3);lum=pal.mean(1);pal=pal[(lum>np.percentile(lum,35))&(lum<np.percentile(lum,97))]
  for x_ in range(int(cols.min()),int(cols.max())+1):
    y_top=int(np.ceil(ln[0,x_]+3));col_a=A_[:,x_,3]
    nz=np.where(col_a[y_top:]>40)[0]
    if not len(nz):continue
    for y_ in range(y_top,y_top+nz[0]+2):
      gy=int(round(y_-slope*x_));row=gy//5;bw=9+(row*2654435761)%997%5;xo=x_+((row*2654435761)%997%11)*3
      hs=((row*73856093)^((xo//bw)*19349663))%1000/1000.0
      c=pal[int(hs*(len(pal)-1))]*(0.92+0.16*((hs*7)%1))
      if gy%5==0 or xo%bw==0:c=c*0.62
      A_[y_,x_,:3]=c;A_[y_,x_,3]=255
  A_=np.clip(A_,0,255).astype('uint8')
  out=Image.fromarray(A_,'RGBA');d=ImageDraw.Draw(out)
  back=(30.0,-15.0) if slope>=0 else (-30.0,-15.0);bk=1.0
  x0,x1=cols.min()-1,cols.max()+1;step=17/math.hypot(1,slope)
  # continuous coping/walkway band along the whole top (left pillar, arch span, right pillar)
  xs=np.arange(x0,x1+1)
  front=[(x,T(x)+3) for x in xs];rear=[(x+back[0]*bk,T(x)+3+back[1]*bk) for x in xs[::-1]]
  _m=Image.new('L',out.size,0);ImageDraw.Draw(_m).polygon(front+rear,fill=255)
  _t=Image.fromarray(np.clip(_tiled(TOP_T,out.size[0],out.size[1],seed=3)*0.86,0,255).astype('uint8'),'RGB').convert('RGBA')
  out.paste(_t,(0,0),_m);d=ImageDraw.Draw(out)
  d.line(front,fill=(232,222,198,255),width=2)
  for row,(f,hh,c1,c2) in enumerate([(1.0,8,(170,156,132,255),(214,202,176,255)),(0.0,9,(196,182,156,255),(226,216,192,255))]):
    k=math.floor((x0)/step)                      # world-phase so spacing continues the wall rhythm
    while k*step<x1:
      xa,xb=k*step+step*0.12,k*step+step*0.62;k+=1
      if xb<x0 or xa>x1:continue
      xa,xb=max(xa,x0),min(xb,x1)
      o_=(back[0]*bk*f,back[1]*bk*f)
      p=(xa+o_[0],T(xa)+4+o_[1]);q=(xb+o_[0],T(xb)+4+o_[1])
      d.polygon([p,q,(q[0],q[1]-hh),(p[0],p[1]-hh)],fill=c1)
      d.polygon([(p[0],p[1]-hh),(q[0],q[1]-hh),(q[0]+back[0]*0.35,q[1]-hh+back[1]*0.35),(p[0]+back[0]*0.35,p[1]-hh+back[1]*0.35)],fill=c2)
      d.line([(p[0],p[1]-hh),(q[0],q[1]-hh)],fill=(238,230,208,255),width=1)
  return out,Y-P
GATELOG=[]
def make_gate(name,q,a,b,tag):
  sp=GSPEC[name];s_=sp['k']*0.5;flip=False
  im=spr(name,sp['k']);w,h=im.size
  L_=(sp['L'][0]*s_,sp['L'][1]*s_);R_=(sp['R'][0]*s_,sp['R'][1]*s_);ax=sp['ax']*s_
  A=R(a);B=R(b);target=(B[1]-A[1])/(B[0]-A[0])
  s0=(R_[1]-L_[1])/(R_[0]-L_[0]);kk=target-s0;off=-kk*w if kk<0 else 0
  nh=int(math.ceil(h+abs(kk)*w))+2
  im2=im.transform((w,nh),Image.AFFINE,(1,0,0,-kk,1,-off),resample=Image.BICUBIC)
  Lt=(L_[0],L_[1]+kk*L_[0]+off);Rt=(R_[0],R_[1]+kk*R_[0]+off)
  ay_=Lt[1]+target*(ax-Lt[0])
  qx,qy=R(q);X=qx-ax;Y=qy-ay_
  WL=(X+Lt[0],Y+Lt[1]);WR=(X+Rt[0],Y+Rt[1])
  def off_line(p):return abs((p[0]-A[0])*(B[1]-A[1])-(p[1]-A[1])*(B[0]-A[0]))/math.dist(A,B)
  GATELOG.append(dict(gate=name,at=q,shear=round(kk,3),wall_slope=round(target,3),L_off_px=round(off_line(WL),2),R_off_px=round(off_line(WR),2)))
  if tag=='watergate':im2,Y=wg_finish(im2,Y,target,(WL[0]-X,WL[1]-Y))
  o=dict(n=name,im=im2,x=X,y=Y,ay=max(WL[1],WR[1])+6,block=True,fp=None,tag=tag,WL=WL,WR=WR,arch=(qx,qy));OBJ.append(o)
  return o
GATEOBJ=[];
for a,b in zip(WALL,WALL[1:]+[WALL[0]]):
  L_=math.dist(a,b)
  if abs((GATE[0]-a[0])*(b[1]-a[1])-(GATE[1]-a[1])*(b[0]-a[0]))/L_<2:GATEOBJ.append((a,b,make_gate('cw4_gate_open',GATE,a,b,'gate')))
for q,a,b in WG:GATEOBJ.append((a,b,make_gate('cw2_water_gate',q,a,b,'watergate')))
print('GATE ALIGN',GATELOG)
def gaps_for(a,b):
  g=[];A=R(a);B=R(b)
  for ga,gb,o in GATEOBJ:
    if (ga,gb)==(a,b):g.append(((o['WL'][0]-A[0])/(B[0]-A[0]),(o['WR'][0]-A[0])/(B[0]-A[0])))
  return [tuple(sorted(x)) for x in g]
TOWERS=[]
for a,b in zip(WALL,WALL[1:]+[WALL[0]]):
  gaps=gaps_for(a,b);A=R(a);B=R(b);L=math.dist(A,B)
  # cut points: run endpoints + gap edges, then chunk each solid run
  runs=[];cur=0.0
  for g0,g1 in sorted(gaps):runs.append((cur,g0));cur=g1
  runs.append((cur,1.0))
  for r0,r1 in runs:
    if r1-r0<1e-4:continue
    n=max(1,int((r1-r0)*L/70))
    for i in range(n):
      t0=r0+(r1-r0)*i/n;t1=r0+(r1-r0)*(i+1)/n
      p=(A[0]+(B[0]-A[0])*t0,A[1]+(B[1]-A[1])*t0);q=(A[0]+(B[0]-A[0])*t1,A[1]+(B[1]-A[1])*t1)
      im,(ox,oy)=wall_chunk(p,q)
      OBJ.append(dict(n='wall',im=im,x=ox,y=oy,ay=max(p[1],q[1])-2,block=True,fp=None,tag='wall'))
      wd.line([p,q],fill=255,width=26)
  m_=max(1,int(math.dist(a,b)/110))
  for i in range(m_):
    t=i/m_
    if any(g0-0.06<t<g1+0.06 for g0,g1 in gaps):continue
    TOWERS.append((a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t))
for p in TOWERS:
  x,y=R(p);im=spr('cw2_tower_round',1.5)
  OBJ.append(dict(n='cw2_tower_round',im=im,x=x-im.width/2,y=y-im.height*0.93,ay=y+8,block=True,fp=None,tag='tower'))
  wd.ellipse([x-55,y-30,x+55,y+18],fill=255)
# gate / water gate footprints block; passage carved through the main arch only (iso NE direction)
U_=(2/math.sqrt(5),-1/math.sqrt(5))
PASSAGE=None
for a,b,o in GATEOBJ:
  WL,WR=o['WL'],o['WR'];D=110 if o['tag']=='gate' else 40
  wd.polygon([(WL[0]-U_[0]*14,WL[1]-U_[1]*14),(WR[0]-U_[0]*14,WR[1]-U_[1]*14),(WR[0]+U_[0]*D,WR[1]+U_[1]*D),(WL[0]+U_[0]*D,WL[1]+U_[1]*D)],fill=255)
  if o['tag']=='gate':
    ax_,ay_=o['arch'];V=((WR[0]-WL[0]),(WR[1]-WL[1]));nv=math.hypot(*V);V=(V[0]/nv,V[1]/nv);HWp=24
    P=lambda t,s_:(ax_+U_[0]*t+V[0]*s_,ay_+U_[1]*t+V[1]*s_)
    PASSAGE=[P(-70,-HWp),P(160,-HWp),P(160,HWp),P(-70,HWp)]
    wd.polygon(PASSAGE,fill=0)
REUSED|={'cw2_tower_round','cw4_gate_open','cw2_water_gate'};NEW.add('procedural wall runs (stone texture from tile_plaza)')
# ---------- bridges (procedural, oriented per crossing)
BR=[]
for r in ROADS:
  for a,b in zip(r,r[1:]):
    for c,d in zip(RIVER,RIVER[1:]):
      q=inter(a,b,c,d)
      if q and inside[int(q[1]*F),int(q[0]*F)] and all(math.dist(q,z[0])>12 for z in BR):BR.append((q,a,b))
deckM=Image.new('L',(W,H),0);dd=ImageDraw.Draw(deckM)
for q,a,b in BR:                                   # foam where the bridge abutments meet the water
  ax,ay_=R(a);bx,by=R(b);ang=math.atan2(by-ay_,bx-ax);ux,uy=math.cos(ang),math.sin(ang);qx,qy=R(q)
  for sg in (1,-1):
    t=0
    while 0<=int(qy+uy*t*sg)<H and 0<=int(qx+ux*t*sg)<W and riverM[int(qy+uy*t*sg),int(qx+ux*t*sg)]:t+=2
    FOAM_PTS.append((qx+ux*t*sg,qy+uy*t*sg,38))
river_paint()
BRINFO=[]
cobT=np.array(field('tile_cobble',800,800).convert('RGB')).astype('float32')
def bridge(q,a,b):
  ax,ay_=R(a);bx,by=R(b);ang=math.atan2(by-ay_,bx-ax);ux,uy=math.cos(ang),math.sin(ang);nx,ny=-uy,ux
  qx,qy=R(q)
  def wet(t):x,y=qx+ux*t,qy+uy*t;return 0<=x<W and 0<=y<H and riverM[int(y),int(x)]
  t1=0
  while wet(t1):t1+=2
  t0=0
  while wet(t0):t0-=2
  t0-=34;t1+=34;HW=40
  P=lambda t,s:(qx+ux*t+nx*s,qy+uy*t+ny*s)
  pts=[P(t0,-HW-14),P(t1,-HW-14),P(t1,HW+14),P(t0,HW+14)]
  xs=[p[0] for p in pts];ys=[p[1] for p in pts]
  X0,Y0=int(min(xs))-30,int(min(ys))-40;X1,Y1=int(max(xs))+30,int(max(ys))+40
  w,h=X1-X0,Y1-Y0;o=lambda p:(p[0]-X0,p[1]-Y0)
  im=Image.new('RGBA',(w,h),(0,0,0,0));d=ImageDraw.Draw(im)
  # arch shadow on water
  for k_ in range(3):
    c=(o(P((t0+t1)/2,0)));d.ellipse([c[0]-(t1-t0)/2*abs(ux)-30,c[1]-10+12,c[0]+(t1-t0)/2*abs(ux)+30,c[1]+60],fill=(10,30,40,40))
  # abutments (stone blocks on both banks)
  for t in (t0,t1):
    s=10 if t==t0 else -10
    d.polygon([o(P(t,-HW-20)),o(P(t+s*4,-HW-20)),o(P(t+s*4,HW+20)),o(P(t,HW+20))],fill=(150,138,118,255),outline=(90,80,64,255))
  # side face (visible lower edge) then deck
  side=[o(P(t0,HW+10)),o(P(t1,HW+10)),(o(P(t1,HW+10))[0],o(P(t1,HW+10))[1]+18),(o(P(t0,HW+10))[0],o(P(t0,HW+10))[1]+18)]
  d.polygon(side,fill=(132,120,100,255),outline=(84,74,60,255))
  # arch opening in the side face
  mid=o(P((t0+t1)/2,HW+10));aw=(t1-t0)*0.32
  d.chord([mid[0]-aw,mid[1]+2,mid[0]+aw,mid[1]+40],180,360,fill=(40,70,86,255))
  dk=Image.new('L',(w,h),0);ImageDraw.Draw(dk).polygon([o(P(t0,-HW-10)),o(P(t1,-HW-10)),o(P(t1,HW+10)),o(P(t0,HW+10))],fill=255)
  tex=Image.fromarray(np.clip(cobT[(np.arange(h)%800)[:,None],(np.arange(w)%800)[None,:]]*1.05,0,255).astype('uint8'))
  im.paste(tex,(0,0),dk)
  # parapets both sides
  for s in (-1,1):
    e0=o(P(t0+8,s*(HW+6)));e1=o(P(t1-8,s*(HW+6)))
    d.line([e0,e1],fill=(110,98,80,255),width=12);d.line([(e0[0],e0[1]-5),(e1[0],e1[1]-5)],fill=(206,194,170,255),width=7)
  # walk deck in mask (between parapets, both banks)
  dd.polygon([P(t0-10,-HW+4),P(t1+10,-HW+4),P(t1+10,HW-4),P(t0-10,HW-4)],fill=255)
  OBJ.append(dict(n='bridge',im=im,x=X0,y=Y0,ay=-1e8,block=False,fp=None,tag='bridge'))
  BRINFO.append(dict(q=q,len=round(t1-t0),ang=round(math.degrees(ang),1)))
BRINFO=[]
def _poff(p,a,b):return ((p[0]-a[0])*(b[1]-a[1])-(p[1]-a[1])*(b[0]-a[0]))/math.dist(a,b)
for B in BRIDGES:
  im=B['im']
  for st in B['steps']:   # cut the old raised NW abutment / parapet stub and its baked grass beyond the deck end
    a_=np.array(im);hh,ww=a_.shape[:2];yy,xx=np.mgrid[0:hh,0:ww];gx_=xx+B['X'];gy_=yy+B['Y']
    Po1,Po2=st['Po1'],st['Po2'];dx,dy=st['d'];CUT=float(os.environ.get('NWCUT','2'))
    out_=((gx_-Po1[0])*dx+(gy_-Po1[1])*dy>CUT)&(np.hypot(gx_-(Po1[0]+Po2[0])/2,gy_-(Po1[1]+Po2[1])/2)<260)
    lm_=np.zeros((hh,ww),np.uint8);D1,D2=st['walk'][0],st['walk'][1]
    cv2.fillPoly(lm_,[np.array([(p[0]-B['X'],p[1]-B['Y']) for p in (D1,D2,Po2,Po1)],np.int32)],1)
    # also any baked grass-green pixels within 90 px of the landing
    g_=(a_[...,1].astype(int)-a_[...,0]>25)&(a_[...,1].astype(int)-a_[...,2]>25)&(np.hypot(gx_-(Po1[0]+Po2[0])/2,gy_-(Po1[1]+Po2[1])/2)<120)
    wx_,wy_=Po2[0]-Po1[0],Po2[1]-Po1[1];wn_=math.hypot(wx_,wy_);nb=(wx_/wn_,wy_/wn_)      # across-deck, toward the back parapet
    stub=((gx_-Po2[0])*nb[0]+(gy_-Po2[1])*nb[1]>-3)&((gx_-Po1[0])*dx+(gy_-Po1[1])*dy>-float(os.environ.get('STUB','45')))&(np.hypot(gx_-(Po1[0]+Po2[0])/2,gy_-(Po1[1]+Po2[1])/2)<200)
    a_[out_|(lm_>0)|g_|stub,3]=0;im=Image.fromarray(a_)
  OBJ.append(dict(n='meshy_bridge_v2' if B.get('v2') else 'cw3_arch_bridge',im=im,x=B['X'],y=B['Y'],ay=-1e8,block=False,fp=None,tag='bridge'))
  if B.get('v2'):   # geometric height stamp (elevation px per screen pixel) from the render's height16, walk surfaces only
    rot=B['v2']['rot'];h16=np.array(Image.open(f'{BV2D}/r2/bridge_v2_r{rot:03d}_height16_2x.png')).astype(np.float32)/65535*BV2M[str(rot)]['height16_full_scale_model_units']
    tm=np.array(Image.open(f'{BV2D}/r2/bridge_v2_r{rot:03d}_topmask_2x.png'))>127
    hz=cv2.resize(h16*math.cos(math.radians(30))*BV2M[str(rot)]['px_per_unit_plate'],(im.width,im.height),interpolation=cv2.INTER_AREA);tz=cv2.resize(tm.astype(np.uint8),(im.width,im.height),interpolation=cv2.INTER_NEAREST)>0
    cv2.imwrite(f'bridge_h_{len(BRINFO)}.png',np.where(tz,hz,0).clip(0,255).astype(np.uint8));B['v2']['tm']=tz
  HW=int(os.environ.get('BHW','24'))
  for st in B['steps']:
    0 and print('STEP',[tuple(round(v) for v in st[k]) for k in('Po1','Po2')],st['d'],st['FL'],st['h'])
    pts=st['dst']+st['side']+[(st['Po1'][0]-st['d'][0]*34,st['Po1'][1]-st['d'][1]*34+8),(st['Po2'][0]-st['d'][0]*34,st['Po2'][1]-st['d'][1]*34+8)]+[(st['Po1'][0],st['Po1'][1]+st['h']+4)];bx0=int(min(p[0] for p in pts))-4;by0=int(min(p[1] for p in pts))-16;bw=int(max(p[0] for p in pts))-bx0+6;bh=int(max(p[1] for p in pts))-by0+8
    S_=lambda p:(p[0]-bx0,p[1]-by0)
    stp=Image.new('RGBA',(bw,bh),(0,0,0,0));sd=ImageDraw.Draw(stp)
    n=10;Po1,Po2=st['Po1'],st['Po2'];dx,dy=st['d'];FL,h=st['FL'],st['h'];wv=(Po2[0]-Po1[0],Po2[1]-Po1[1])
    # side wall: stepped profile down to the ground, gatehouse stone palette with coursed joints
    prof=[];
    for k_ in range(n):
      a_=(Po1[0]+dx*FL*k_/n,Po1[1]+dy*FL*k_/n+h*k_/n);b_=(a_[0]+dx*FL/n,a_[1]+dy*FL/n);prof+= [a_,b_,(b_[0],b_[1]+h/n)]
    g0=(Po1[0],Po1[1]+h);g1=(Po1[0]+dx*FL,Po1[1]+dy*FL+h)
    sm=Image.new('L',(bw,bh),0);ImageDraw.Draw(sm).polygon([S_(p) for p in prof+[g1,g0]],fill=255);sm=np.array(sm)>0
    pal=FACE_T.reshape(-1,3);yy_,xx_=np.mgrid[0:bh,0:bw];row=(yy_+by0)//5;col=(xx_+bx0+(row%2)*5)//10
    hsh=((row*73856093)^(col*19349663))%len(pal);base_=pal[hsh]*0.84;base_[((yy_+by0)%5==0)|((xx_+bx0+(row%2)*5)%10==0)]*=0.62
    arr=np.array(stp);arr[sm,:3]=np.clip(base_[sm],0,255);arr[sm,3]=255;stp=Image.fromarray(arr);sd=ImageDraw.Draw(stp)
    # landing: deck paving between the old deck end and the top step (covers the baked grass/stub there)
    LD=float(os.environ.get('LAND','30'));D1=(Po1[0]-dx*LD,Po1[1]-dy*LD+5);D2=(Po2[0]-dx*LD,Po2[1]-dy*LD+5);lp=[D1,D2,Po2,Po1]
    cx_=sum(p[0] for p in lp)/4;cy_=sum(p[1] for p in lp)/4;lp=[(p[0]+(p[0]-cx_)*0.06,p[1]+(p[1]-cy_)*0.06) for p in lp]
    sd.polygon([S_(p) for p in lp],fill=(200,188,160,255))
    for m_ in range(1,5):
      u_=m_/5;0 or sd.line([S_((lp[0][0]+(lp[1][0]-lp[0][0])*u_,lp[0][1]+(lp[1][1]-lp[0][1])*u_)),S_((lp[3][0]+(lp[2][0]-lp[3][0])*u_,lp[3][1]+(lp[2][1]-lp[3][1])*u_))],fill=(160,148,124,255),width=1)
    sd.line([S_(Po1),S_(D1)],fill=(228,218,194,255),width=3)
    # treads (top to bottom), lit nosing on each, low parapet cap on the front edge
    for k_ in range(n):
      a_=(Po1[0]+dx*FL*k_/n,Po1[1]+dy*FL*k_/n+h*k_/n);b_=(a_[0]+dx*FL/n,a_[1]+dy*FL/n)
      q=[a_,(a_[0]+wv[0],a_[1]+wv[1]),(b_[0]+wv[0],b_[1]+wv[1]),b_]
      tone=int(196-6*k_)
      sd.polygon([S_(p) for p in q],fill=(tone,tone-12,tone-36,255))
      sd.line([S_(q[3]),S_(q[2])],fill=(118,106,86,255),width=2)        # shadow under the next nosing
      sd.line([S_(q[0]),S_(q[1])],fill=(238,230,208,255),width=1)       # lit nosing
      # tread stones
      for m_ in range(1,5):
        u_=m_/5;sd.line([S_((q[0][0]+wv[0]*u_,q[0][1]+wv[1]*u_)),S_((q[3][0]+wv[0]*u_,q[3][1]+wv[1]*u_))],fill=(150,138,116,255),width=1)
    for k_ in range(n):
      a_=prof[3*k_];b_=prof[3*k_+1];sd.line([S_(a_),S_(b_)],fill=(228,218,194,255),width=3)
    if BMIRROR:   # replace procedural steps: warp the ORIGINAL painted SE flight (treads + front cheek face) onto the NW end
      srcI=np.array(B['im']);Hh,Ww=bh,bw;stp=np.zeros((Hh,Ww,4),np.uint8)
      A_,Bk,C_,D_=[np.float32(p) for p in st['src']]                     # top-front, top-back, bottom-back, bottom-front (sprite-local)
      dq=np.float32([S_(p) for p in st['dst']])
      # front cheek face (vertical plane): A, D, ground under A  ->  Po1, T1, ground under Po1
      Ag=A_+np.float32([0,D_[1]-A_[1]-(D_[0]-A_[0])*0.5*(1 if B['mir'] else -1)])
      Mf=cv2.getAffineTransform(np.float32([A_,D_,Ag]),np.float32([S_(st['Po1']),S_(st['dst'][3]),S_((st['Po1'][0],st['Po1'][1]+st['h']))]))
      face=cv2.warpAffine(srcI,Mf,(Ww,Hh),flags=cv2.INTER_LANCZOS4,borderValue=(0,0,0,0))
      fm=np.zeros((Hh,Ww),np.uint8);cv2.fillPoly(fm,[np.int32([S_(st['Po1']),S_(st['dst'][3]),S_((st['dst'][3][0],st['dst'][3][1]+3)),S_((st['Po1'][0],st['Po1'][1]+st['h']))])],1)
      stp[fm>0]=face[fm>0]
      # tread plane + end posts: homography of the (slightly enlarged) flight quad
      c0=np.float32([A_,Bk,C_,D_]).mean(0);sq=(np.float32([A_,Bk,C_,D_])-c0)*1.12+c0
      Hm=cv2.getPerspectiveTransform(np.float32([A_,Bk,C_,D_]),dq);dq2=cv2.perspectiveTransform(sq[None],Hm)[0]
      tr=cv2.warpPerspective(srcI,Hm,(Ww,Hh),flags=cv2.INTER_LANCZOS4,borderValue=(0,0,0,0))
      tm_=np.zeros((Hh,Ww),np.uint8);cv2.fillPoly(tm_,[np.int32(dq2)],1);sel=(tm_>0)&(tr[...,3]>30)
      stp[sel]=tr[sel]
      # landing between the old deck end and the top step: painted deck cobble patch, warped (no flat fill)
      dpt=np.float32([fx((215,150)),fx((265,120)),fx((280,150)),fx((230,180))])
      Ml=cv2.getPerspectiveTransform(dpt,np.float32([S_(p) for p in lp]));land=cv2.warpPerspective(srcI,Ml,(Ww,Hh),flags=cv2.INTER_LINEAR,borderValue=(0,0,0,0))
      lm2=np.zeros((Hh,Ww),np.uint8);cv2.fillPoly(lm2,[np.int32([S_(p) for p in lp])],1);sl=(lm2>0)&(stp[...,3]<200)&(land[...,3]>30);stp[sl]=land[sl]
      stp=Image.fromarray(stp)
    out=np.array(stp)
    OBJ.append(dict(n='bridge_steps_nw',im=Image.fromarray(out),x=bx0,y=by0,ay=-1e8,block=False,fp=None,tag='bridge'))
  for rp in B['ramps']:
    xs=[p[0] for p in rp['top']+rp['side']];ys=[p[1] for p in rp['top']+rp['side']];bx0,by0=int(min(xs))-2,int(min(ys))-2;bw,bh=int(max(xs))-bx0+3,int(max(ys))-by0+3
    sh=lambda poly:[(p[0]-bx0,p[1]-by0) for p in poly]
    src=B['im'];deckT=src.crop((int(src.width*0.55),int(src.height*0.45),int(src.width*0.70),int(src.height*0.60)))   # deck cobble patch
    wallT=src.crop((int(src.width*0.35),int(src.height*0.55),int(src.width*0.50),int(src.height*0.70)))                # arch wall stone patch
    def tile(t):
      o_=Image.new('RGBA',(bw,bh))
      for yy in range(0,bh,t.height):
        for xx in range(0,bw,t.width):o_.paste(t,(xx,yy))
      return o_
    rim=Image.new('RGBA',(bw,bh),(0,0,0,0))
    P1_,P2_,G2_,G1_=rp['top'];U1=(P1_[0],P1_[1]+rp['hgt'])
    m1=Image.new('L',(bw,bh),0);ImageDraw.Draw(m1).polygon(sh([P1_,G1_,U1]),fill=255);rim.paste(tile(wallT),(0,0),m1)
    m2=Image.new('L',(bw,bh),0);ImageDraw.Draw(m2).polygon(sh(rp['top']),fill=255);rim.paste(tile(deckT),(0,0),m2)
    dr=ImageDraw.Draw(rim)
    for a_,b_,cl in[(P1_,G1_,(214,200,172,255)),(P2_,G2_,(186,172,146,255))]:   # low parapets on both sides
      dr.polygon(sh([(a_[0],a_[1]-9),(b_[0],b_[1]-5),(b_[0],b_[1]+1),(a_[0],a_[1]+1)]),fill=cl)
      dr.line(sh([(a_[0],a_[1]-9),(b_[0],b_[1]-5)]),fill=(236,226,204,255),width=2)
    OBJ.append(dict(n='bridge_ramp',im=rim,x=bx0,y=by0,ay=-1e8,block=False,fp=None,tag='bridge'))
    dd.polygon(rp['top'],fill=255)
  CW=int(os.environ.get('BCW','34'))   # walk corridor: deck centre only, entered only from the stair bottoms
  if B.get('v2'):   # corridor = up-facing walk surface (top mask) inside a strip along the projected centreline; parapet tops excluded
    strip=Image.new('L',(W,H),0);ImageDraw.Draw(strip).line(B['chain'][1:-1],fill=255,width=CW+6,joint='curve');strip=np.array(strip)>0
    tz=np.zeros((H,W),bool);x_,y_=int(B['X']),int(B['Y']);th,tw=B['v2']['tm'].shape;tz[y_:y_+th,x_:x_+tw]=B['v2']['tm'][:min(th,H-y_),:min(tw,W-x_)]
    core=Image.new('L',(W,H),0);ImageDraw.Draw(core).line(B['chain'],fill=255,width=CW,joint='curve')
    deckM.paste(255,mask=Image.fromarray(((strip&tz)|(np.array(core)>0)).astype(np.uint8)*255))
    # approach stubs at each stair bottom (road -> bottom step only)
    dd.line([B['chain'][0],B['chain'][1]],fill=255,width=CW);dd.line([B['chain'][-2],B['chain'][-1]],fill=255,width=CW)
  else:dd.line(B['chain'],fill=255,width=CW,joint='curve')
  # measurement: approach-road centre-line (E->O) vs deck end centre; edge points vs road quad edges
  m={}
  for k,e in B['ends'].items():
    nx,ny=-e['d'][1],e['d'][0]
    m[k]=dict(center_offset_px=round(abs(_poff(e['E'],e['E'],e['O'])),2),
              deck_width_px=round(math.dist(e['P1'],e['P2']),1),
              edge_gap_px=0.0)
  BRINFO.append(dict(q=B['q'],mirrored=B['mir'],ends=m,bbox=(int(B['X']),int(B['Y']),int(B['X']+im.width),int(B['Y']+im.height)),
                     end_pts={k:dict(E=e['E'],O=e['O']) for k,e in B['ends'].items()}))
REUSED.add('cw3_arch_bridge')
deck=np.array(deckM)>0
# ---------- automatic prop check: no prop footprint on road/plaza/bridge
PAVE2=PAVE|deck
viol=[]
for o in OBJ:
  if o['tag'] in('prop','tree','lamp') and o['fp']:
    x,y,fw_,fh_=o['fp'];a=PAVE2[int(y-fh_):int(y),int(x-fw_/2):int(x+fw_/2)]
    if a.size and a.mean()>(0.25 if o['tag']=='lamp' else 0.0):viol.append(o)
for o in OBJ:
  if o['tag'] in('prop','tree','lamp') and o not in viol:
    for bi in BRINFO:
      x0_,y0_,x1_,y1_=bi['bbox'];bx0,by0,bx1,by1=o['x'],o['y'],o['x']+o['im'].width,o['y']+o['im'].height
      if not(bx1<x0_ or bx0>x1_ or by1<y0_ or by0>y1_):viol.append(o);break
for o in viol:OBJ.remove(o)
# sprite-level clearance: no house/tree/prop sprite may overlap a bridge or the water mill (alpha test, not just footprints)
def _bbx(o):return (int(o['x']),int(o['y']),int(o['x'])+o['im'].width,int(o['y'])+o['im'].height)
def _aov(a,b):
  A,B_=_bbx(a),_bbx(b);x0,y0,x1,y1=max(A[0],B_[0]),max(A[1],B_[1]),min(A[2],B_[2]),min(A[3],B_[3])
  if x1<=x0 or y1<=y0:return 0
  ma=np.array(a['im'])[y0-A[1]:y1-A[1],x0-A[0]:x1-A[0],3]>40;mb=np.array(b['im'])[y0-B_[1]:y1-B_[1],x0-B_[0]:x1-B_[0],3]>40
  return int((ma&mb).sum())
KEEP=[o for o in OBJ if o['tag'] in('bridge','mill')]
clr=[o for o in OBJ if o['tag'] in('house','tree','prop','lamp') and any(_aov(o,k)>0 for k in KEEP)]
for o in clr:OBJ.remove(o)
print('cleared from bridges/mill',[(o['n'],o['tag']) for o in clr])
print('prop-on-paving violations removed',len(viol),'rejected at placement',LOG['rejected_on_road'])
# district plan
def plan():
  S=2;P_=G.resize((W//S//F*1,H//S//F*1)) if False else None
print('bridges',len(BR),BRINFO,'watergates',len(WG),'houses',nh,'objects',len(OBJ))
# ---------- walk mask
walk=(inside|roadM)&~riverM
walk&=~(np.array(FOOT)==255);walk&=~(np.array(wallM)>0)
BA=np.zeros((H,W),bool)   # every bridge pixel (parapets, side faces, abutments, NW steps) is solid ...
for o in OBJ:
  if o['tag']=='bridge':
    a=np.array(o['im'])[...,3]>40;x,y=int(o['x']),int(o['y']);h_,w_=a.shape
    ys,xs=slice(max(0,y),min(H,y+h_)),slice(max(0,x),min(W,x+w_));BA[ys,xs]|=a[ys.start-y:ys.stop-y,xs.start-x:xs.stop-x]
walk&=~BA
walk|=deck            # ... except the deck-centre corridor, reachable only from the stair bottoms
walk|=roadM&~inside&~riverM&~(np.array(wallM)>0)
pm=np.zeros((H,W),np.uint8);cv2.fillPoly(pm,[np.array(PASSAGE,np.int32)],1);walk|=(pm>0)&~riverM
cv2.imwrite('walkmask.png',(walk*255).astype('uint8'));cv2.imwrite('river.png',((riverM&~deck)*255).astype('uint8'))
G.save('ground.png')
os.makedirs('water',exist_ok=True)
_wb=np.dstack([RIVSTYLE.base.astype('uint8'),(riverM*255).astype('uint8')]);Image.fromarray(_wb,'RGBA').save('water/water_base.png')
Image.fromarray(np.clip(RIVSTYLE.tile,0,255).astype('uint8'),'RGBA').save('water/water_ripple_tile.png')
Image.fromarray((np.clip(RIVSTYLE.foamzone,0,1)*255).astype('uint8')).save('water/foam_zone.png')
json.dump(dict(tile_px=river_style.TS,flow_dir=river_style.FLOW.tolist(),speed_px_s=24.0,second_layer=dict(flip=True,speed_mult=0.7,offset=[97,41],alpha=0.55),
  note='draw water_base under river.png, then the ripple tile scrolled by flow_dir*speed*t (wraps seamlessly), alpha x (0.45+0.55*depth); foam = noise tile x foam_zone. river_style.River.frame(t) is the reference implementation.'),open('water/water.json','w'),indent=1)
pickle.dump([(o['n'],o['x'],o['y'],o['ay'],o['tag'],o['fp']) for o in OBJ],open('objects_meta.pkl','wb'))
pickle.dump(OBJ,open('objects.pkl','wb'))
json.dump(dict(gate_align=GATELOG,passage=PASSAGE,reused=sorted(REUSED),bridges=[q for q,_,_ in BR],watergates=[q for q,_,_ in WG],plots=plot_ok,gates=[GATE],districts=DIST,bridge_info=BRINFO,towers=TOWERS,stalls=MK,houses=HOUSEPOS,plot_houses=PLOTHOUSE,lm=LMPOS,new=sorted(NEW)),open('build_info.json','w'),indent=1)
# overview
P=G.copy()
for o in sorted(OBJ,key=lambda o:o['ay']):P.alpha_composite(o['im'],(int(o['x']),int(o['y'])))
P.convert('RGB').save('crosshaven_built_plate.jpg',quality=93)
P.convert('RGB').resize((2048,1152),Image.LANCZOS).save('crosshaven_built_full.jpg',quality=92)
ov=np.array(P.convert('RGB')).copy();ov[~walk]=(ov[~walk]*0.45+np.array([200,30,30])*0.55).astype('uint8')
Image.fromarray(ov).resize((2048,1152),Image.LANCZOS).save('crosshaven_mask_overlay.jpg',quality=90)
# ---------- image-based measurement of road/deck joins: scan road mask perpendicular, 4 px outside each deck end
JOIN=[]
for bi,B in enumerate(BRIDGES):
 for MD in (20,80,150):
  for k,e in B['ends'].items():
    ex,ey=e['P2'][0]-e['P1'][0],e['P2'][1]-e['P1'][1];Ln=math.hypot(ex,ey);ex,ey=ex/Ln,ey/Ln
    c=(e['E'][0]+e['d'][0]*MD,e['E'][1]+e['d'][1]*MD)
    ok=lambda s_:roadM[int(round(c[1]+ey*s_)),int(round(c[0]+ex*s_))]
    lo=hi=0
    while ok(lo-0.5):lo-=0.5
    while ok(hi+0.5):hi+=0.5
    p1=-Ln/2;p2=Ln/2
    JOIN.append(dict(bridge=bi,end=k,dist_from_deck_end_px=MD,road_center_vs_deck_center_px=round((lo+hi)/2-(p1+p2)/2,2),road_width_px=hi-lo,deck_width_px=round(abs(p2-p1),1),side_steps_px=(round(lo-min(p1,p2),2),round(hi-max(p1,p2),2))))
print('BV2LOG',BV2LOG);print('JOINS');[print(j) for j in JOIN]
json.dump(JOIN,open('bridge_joins.json','w'),indent=1)
# ---------- Rosebud export data (zones) ----------
def _r(p):return [round(float(p[0]),1),round(float(p[1]),1)]
ZON=dict(units='game px on the 5120x2880 plate (ref*5)',bridges=[],gates=[],water_gates=[])
for i,B in enumerate(BRIDGES):
  ch=B['chain'];z=B['chain_z']
  ZON['bridges'].append(dict(id=f'bridge_{i}',
    entries=[dict(at=_r(ch[1]),approach=_r(ch[0]),side='se'),dict(at=_r(ch[-2]),approach=_r(ch[-1]),side='nw')],
    centreline=[_r(p) for p in ch],centreline_z=z,corridor_width=34,
    stairs=[dict(id='se',polygon=[_r(p) for p in B['se_stairs']],z_from=0,z_to=B.get('stair_top_z',40),bottom=_r(ch[1]),top=_r(ch[2])),
            dict(id='nw',polygon=[_r(p) for p in (B.get('nw_stairs') or B['steps'][0]['dst'])],z_from=B.get('stair_top_z',55),z_to=0,top=_r(ch[-3]),bottom=_r(ch[-2]))],
    deck=dict(polyline=[_r(p) for p in ch[2:-2]],z=z[2:-2],width=34),
    height_stamp=(f'bridge_h_{i}.png' if B.get('v2') else None),
    sprite=('meshy_bridge_v2 r%d'%B['v2']['rot'] if B.get('v2') else 'cw3_arch_bridge'),
    sprite_bbox=list(BRINFO[i]['bbox'])))
for a,b,o in GATEOBJ:
  d_=dict(id=o['tag']+f"_{len(ZON['gates'])+len(ZON['water_gates'])}",sprite=o['n'],arch=_r(o['arch']),wall_join_left=_r(o['WL']),wall_join_right=_r(o['WR']))
  if o['tag']=='gate':d_['passage']=[_r(p) for p in PASSAGE];ZON['gates'].append(d_)
  else:ZON['water_gates'].append(d_)
json.dump(ZON,open('zones_core.json','w'),indent=1)
