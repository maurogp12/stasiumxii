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
WALL=[(40,240),(290,38),(700,38),(990,235),(985,275),(800,462),(530,545),(272,455),(132,352)]
RIVER=[(1024,40),(905,75),(840,112),(745,160),(690,205),(688,262),(640,318),(600,345),(530,375),(470,400),(400,428),(330,455),(296,478),(250,515),(170,560),(120,580)]
RW=22
ROADS=[ [(665,600),(660,505),(640,460),(600,345),(560,300),(485,250)],
        [(485,250),(490,118)],
        [(485,250),(380,272),(250,282),(110,300),(0,320)],
        [(485,250),(600,175),(690,225),(790,290),(905,330),(1024,350)],
        [(380,272),(410,345),(480,398),(560,450)],
        [(450,470),(830,400)],
        [(380,272),(330,160),(300,95)],[(250,282),(200,180)],[(250,282),(240,400)],
        [(600,175),(640,95),(690,75)],[(410,345),(300,380)],
        [(600,345),(740,330),(820,300)] ]
RING=((485,250),118,72)
def poly_mask(draw_fn):
  m=Image.new('L',(W,H),0);d=ImageDraw.Draw(m);draw_fn(d);return np.array(m)>0
def drawline(d,pts,w):
  P=[R(p) for p in pts];d.line(P,fill=255,width=int(w*F),joint='curve')
  for p in P:d.ellipse([p[0]-w*F/2,p[1]-w*F/2,p[0]+w*F/2,p[1]+w*F/2],fill=255)
inside=poly_mask(lambda d:d.polygon([R(p) for p in WALL],fill=255))
riverM=poly_mask(lambda d:drawline(d,RIVER,RW))
def roads_draw(d):
  for r in ROADS:drawline(d,r,15)
  c,rx,ry=RING;d.ellipse([R((c[0]-rx-8,c[1]-ry-8)),R((c[0]+rx+8,c[1]+ry+8))],fill=255)
  d.ellipse([R((c[0]-rx+8,c[1]-ry+8)),R((c[0]+rx-8,c[1]+ry-8))],fill=0)
  # plaza around cathedral front + fountain park ring
  d.ellipse([R((440,250)),R((540,300))],fill=255)
  d.ellipse([R((585,255)),R((665,305))],fill=255);d.ellipse([R((600,265)),R((650,295))],fill=0)
  d.ellipse([R((745,272)),R((825,318))],fill=255)
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
sh=Image.new('RGBA',(W,H),(92,84,62,255));paste_mask(G,sh,shore&~riverM,2)
wv=water.copy();wv=Image.blend(wv.convert('RGB'),Image.new('RGB',(W,H),(70,150,190)),0.25).convert('RGBA')
paste_mask(G,wv,riverM,2)
# ---------- objects: (sorty, image, x, y, footprint) ; anchor = bottom-center
OBJ=[];FOOT=Image.new('L',(W,H),0);fd=ImageDraw.Draw(FOOT)
def occupied(x,y,w,h):
  a=np.array(FOOT.crop((int(x-w/2),int(y-h),int(x+w/2),int(y))))
  return a.size==0 or a.max()>0
def place(name,p,k,flip=False,src=PC,foot=0.32,fw=0.86,block=True,ref=True,force=False,tag=None):
  x,y=R(p) if ref else p;im=spr(name,k,flip,src)
  fh=im.height*foot;fwid=im.width*fw
  if not force and block:
    pad=60 if name in HOUSESET else 16
    if occupied(x,y+pad/3,fwid+pad,fh+pad*0.6):return False
    a=(roadM|riverM)[int(max(0,y-fh)):int(y),int(max(0,x-fwid/2)):int(x+fwid/2)]
    if a.size and a.mean()>0.02:return False
    if not inside[min(H-1,int(y)),min(W-1,int(x))] and tag!='out':return False
  if block:fd.ellipse([x-fwid/2,y-fh,x+fwid/2,y],fill=255)
  OBJ.append(dict(n=name,im=im,x=x-im.width/2,y=y-im.height,ay=y,block=block,fp=(x,y,fwid,fh),tag=tag));return True
REUSED=set();NEW=set()
HOUSESET={'cx_house_a','cx_house_b','cx_house_c','cx_cottage_restyle_a','cx_cottage_restyle_b','cx_cottage_restyle_c','cx_cottage_restyle_d','ex_cottage_a','ex_cottage_c','cx_cottage_thatch_a','cx_cottage_slate_a'}
# landmarks
LM=[('cx_palace',(490,112),1.75),('cx_cathedral',(487,244),1.65),('cx_town_hall',(600,160),1.45),
    ('cx_convent',(400,330),1.15),   # bank stand-in
    ('cx_workshop_smith',(200,262),1.45),('cx_workshop_potter',(170,320),1.4),('cx_workshop_weaver',(275,322),1.4),
    ('cw5_craft_blacksmith',(232,215),1.25),('cw5_craft_carpenter',(150,268),1.25),('cw5_craft_tailor',(300,250),1.2),
    ('cx_water_mill',(718,288),1.25)]
for n,p,k in LM:place(n,p,k,force=True,foot=0.3);REUSED.add(n)
# fountain + park
place('cx_fountain_big',(625,284),1.2,force=True,foot=0.35);REUSED.add('cx_fountain_big')
for a in range(0,360,45):
  x=625+30*math.cos(math.radians(a));y=280+18*math.sin(math.radians(a))
  place('tn_flower_bed',(x,y+4),1.1,block=False,force=True);REUSED.add('tn_flower_bed')
# gazebo park (no gazebo sprite: well + flower ring)
place('cx_well',(785,298),1.3,force=True);REUSED.add('cx_well')
for a in range(0,360,40):
  x=785+44*math.cos(math.radians(a));y=295+26*math.sin(math.radians(a))
  place(random.choice(['tn_flower_bed','tn_wildflowers','ww_wild_rose']),(x,y),1.1,block=False,force=False)
REUSED|={'tn_wildflowers','ww_wild_rose'}
# Global Market (stall cluster on west plaza edge)
mk=[(352,290),(375,300),(398,288),(340,262),(420,262)]
for i,p in enumerate(mk):place(['cx_market_stall_a','cx_market_stall_b','cx_market_stall_spice','cx_stall_restyle_blue_a','cx_stall_restyle_red'][i],p,1.3,force=True,foot=0.4)
REUSED|={'cx_market_stall_a','cx_market_stall_b','cx_market_stall_spice','cx_stall_restyle_blue_a','cx_stall_restyle_red'}
# ---------- player housing SE: modular tier plots
TIERS=json.load(open('housing_tiers/tiers.json'))
def place_plot(p,tier,gtier):
  x,y=R(p)
  base=Image.open(f'housing_tiers/lot_{"large" if tier=="legendary" else "std"}.png')
  hs=Image.open(f'housing_tiers/house_{tier}.png');gs=Image.open(f'housing_tiers/garden_{gtier}.png')
  # lot (ground decal)
  OBJ.append(dict(n='lot',im=base,x=x-base.width/2,y=y-base.height,ay=y-base.height+2,block=False,fp=None,tag='lot'))
  an=TIERS['anchors'];hx,hy=an['house']; gx,gy=an['garden_large' if tier=='legendary' else 'garden']
  sc=TIERS['lot_scale']['large' if tier=='legendary' else 'std']
  X,Y=x-base.width/2+hx*sc,y-base.height+hy*sc
  OBJ.append(dict(n='house_'+tier,im=hs,x=X-hs.width/2,y=Y-hs.height,ay=Y,block=True,fp=(X,Y,hs.width*0.85,hs.height*0.33),tag='house'))
  fd.ellipse([X-hs.width*0.43,Y-hs.height*0.33,X+hs.width*0.43,Y],fill=255)
  GX,GY=x-base.width/2+gx*sc,y-base.height+gy*sc
  OBJ.append(dict(n='garden_'+gtier,im=gs,x=GX-gs.width/2,y=GY-gs.height,ay=GY,block=False,fp=None,tag='garden'))
  fd.rectangle([x-base.width/2,y-base.height,x+base.width/2,y],fill=255)
st=lambda x:470-0.184*(x-450)
PLOTS=[((492,st(492)-9),'normal','normal'),((572,st(572)-9),'legendary','legendary'),((712,st(712)-9),'rare','rare'),((782,st(782)-9),'normal','rare'),
       ((520,st(520)+48),'rare','normal'),((592,st(592)+48),'normal','rare'),((700,st(700)+44),'normal','legendary')]
plot_ok=[]
for p,t,g in PLOTS:
  x,y=R(p);bw=Image.open(f'housing_tiers/lot_{"large" if t=="legendary" else "std"}.png').size
  a=(roadM|riverM)[int(y-bw[1]):int(y),int(x-bw[0]/2):int(x+bw[0]/2)]
  print("plot",p,t,round(float(a.mean()),3));place_plot(p,t,g);plot_ok.append((p,t,g))
print('plots',plot_ok)
# ---------- houses with gardens fill
HOUSES=['cx_house_a','cx_house_b','cx_house_c','cx_cottage_restyle_a','cx_cottage_restyle_b','cx_cottage_restyle_c','cx_cottage_restyle_d','ex_cottage_a','ex_cottage_c','cx_cottage_thatch_a','cx_cottage_slate_a']
TREES=['cx_tree_plane','tn_oak','cx_tree_cypress','ww_poplar']
cand=[(x,y) for y in range(70,540,26) for x in range(60,1000,30)]
random.shuffle(cand)
nh=0
for (x,y) in cand:
  x+=random.uniform(-6,6);y+=random.uniform(-4,4)
  if x>440 and y>st(x)-50 and y>380:continue  # player housing district reserved
  if 590<x<670 and 255<y<310:continue
  if place(random.choice(HOUSES),(x,y),1.12,flip=random.random()<0.5,foot=0.33):
    nh+=1
    for dx,dy in [(-14,10),(14,10)]:
      place(random.choice(['tn_flower_bed','tn_bush','cx_planter_a','tn_wildflowers']),(x+dx,y+dy),1.0,block=False)
for (x,y) in cand:
  place(random.choice(TREES),(x+random.uniform(-10,10),y),random.uniform(1.0,1.25),foot=0.12,fw=0.3)
REUSED|=set(HOUSES)|set(TREES)|{'tn_bush','cx_planter_a'}
# few benches + lamps along ring (edge only)
for a in (200,340):
  c,rx,ry=RING;x=c[0]+(rx+14)*math.cos(math.radians(a));y=c[1]+(ry+10)*math.sin(math.radians(a))
  place('tn_bench',(x,y),1.0,force=False,foot=0.5)
for a in range(0,360,60):
  c,rx,ry=RING;x=c[0]+(rx+11)*math.cos(math.radians(a));y=c[1]+(ry+9)*math.sin(math.radians(a))
  place('cx_lamp_post',(x,y),0.9,foot=0.08,fw=0.5)
REUSED|={'tn_bench','cx_lamp_post'}
# ---------- walls, towers, gates, bridges
def seg_pts(a,b,step):
  L=math.dist(a,b);n=max(1,int(L/step));return [(a[0]+(b[0]-a[0])*i/n,a[1]+(b[1]-a[1])*i/n) for i in range(n+1)]
wallM=Image.new('L',(W,H),0);wd=ImageDraw.Draw(wallM)
wd.line([R(p) for p in WALL+[WALL[0]]],fill=255,width=int(9*F))
GATES=[(660,503)]   # main S land gate
def near_gate(p,r=24):return any(math.dist(p,g)<r for g in GATES)
# river/wall crossings -> water gate
def inter(p1,p2,p3,p4):
  (x1,y1),(x2,y2),(x3,y3),(x4,y4)=p1,p2,p3,p4;d=(x1-x2)*(y3-y4)-(y1-y2)*(x3-x4)
  if abs(d)<1e-9:return None
  t=((x1-x3)*(y3-y4)-(y1-y3)*(x3-x4))/d;u=-((x1-x2)*(y1-y3)-(y1-y2)*(x1-x3))/d
  return (x1+t*(x2-x1),y1+t*(y2-y1)) if 0<=t<=1 and 0<=u<=1 else None
WG=[]
for a,b in zip(WALL,WALL[1:]+[WALL[0]]):
  for c,d in zip(RIVER,RIVER[1:]):
    q=inter(a,b,c,d)
    if q:WG.append((q,a,b))
for a,b in zip(WALL,WALL[1:]+[WALL[0]]):
  nesw=(b[0]-a[0])*(b[1]-a[1])<0   # going up-right
  for p in seg_pts(a,b,30)[:-1]:
    if near_gate(p,26) or any(math.dist(p,q)<26 for q,_,_ in WG):continue
    place('cw2_wall_nesw',p,1.25,flip=not nesw,force=True,foot=0.35,fw=0.9,block=False,tag='out')
  for p in seg_pts(a,b,90):
    if near_gate(p,30) or any(math.dist(p,q)<30 for q,_,_ in WG):continue
    place('cw2_tower_round',p,1.3,force=True,foot=0.2,fw=0.5,block=False,tag='out')
for g in GATES:
  place('cw3_gatehouse_big',g,1.0,force=True,block=False,tag='out')
  wd.ellipse([R((g[0]-16,g[1]-10)),R((g[0]+16,g[1]+10))],fill=0)
for q,a,b in WG:
  nesw=(b[0]-a[0])*(b[1]-a[1])<0
  place('cw2_water_gate',(q[0],q[1]+10),1.3,flip=not nesw,force=True,block=False,tag='out')
REUSED|={'cw2_wall_nesw','cw2_tower_round','cw3_gatehouse_big','cw2_water_gate'}
# bridges at road x river
BR=[]
for r in ROADS:
  for a,b in zip(r,r[1:]):
    for c,d in zip(RIVER,RIVER[1:]):
      q=inter(a,b,c,d)
      if q and inside[int(q[1]*F),int(q[0]*F)]:BR.append((q,a,b))
deckM=Image.new('L',(W,H),0);dd=ImageDraw.Draw(deckM)
for q,a,b in BR:
  ang=math.atan2(b[1]-a[1],b[0]-a[0]);ux,uy=math.cos(ang),math.sin(ang)
  L=RW*0.5+14;p1=(q[0]-ux*L,q[1]-uy*L);p2=(q[0]+ux*L,q[1]+uy*L)
  dd.line([R(p1),R(p2)],fill=255,width=int(18*F))
  # deck strip painted with cobble, then arch sprite rails
  flip=(b[0]-a[0])*(b[1]-a[1])>0
  place('cw3_arch_bridge',(q[0],q[1]+16),1.1,flip=flip,force=True,block=False,tag='bridge')
REUSED.add('cw3_arch_bridge')
deck=np.array(deckM)>0
paste_mask(G,cob,deck&riverM,1)
print('bridges',len(BR),'watergates',len(WG),'houses',nh,'objects',len(OBJ))
# ---------- walk mask
walk=(inside|roadM)&~riverM
walk&=~(np.array(FOOT)>0);walk&=~(np.array(wallM)>0)
walk|=deck
for g in GATES:
  gm=poly_mask(lambda d:drawline(d,[(g[0],g[1]-14),(g[0],g[1]+20)],14));walk|=gm&~riverM
walk|=roadM&~inside&~riverM   # roads outside
cv2.imwrite('walkmask.png',(walk*255).astype('uint8'))
G.save('ground.png')
pickle.dump([(o['n'],o['x'],o['y'],o['ay'],o['tag'],o['fp']) for o in OBJ],open('objects_meta.pkl','wb'))
pickle.dump(OBJ,open('objects.pkl','wb'))
json.dump(dict(reused=sorted(REUSED),bridges=[q for q,_,_ in BR],watergates=[q for q,_,_ in WG],plots=plot_ok,gates=GATES),open('build_info.json','w'),indent=1)
# overview
P=G.copy()
for o in sorted(OBJ,key=lambda o:o['ay']):P.alpha_composite(o['im'],(int(o['x']),int(o['y'])))
P.convert('RGB').save('crosshaven_built_plate.jpg',quality=93)
P.convert('RGB').resize((2048,1152),Image.LANCZOS).save('crosshaven_built_full.jpg',quality=92)
ov=np.array(P.convert('RGB')).copy();ov[~walk]=(ov[~walk]*0.45+np.array([200,30,30])*0.55).astype('uint8')
Image.fromarray(ov).resize((2048,1152),Image.LANCZOS).save('crosshaven_mask_overlay.jpg',quality=90)
