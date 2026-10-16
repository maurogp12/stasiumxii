# ---------- objects ; anchor = bottom-center
OBJ=[];FOOT=Image.new('L',(W,H),0);fd=ImageDraw.Draw(FOOT)
LOG=dict(rejected_on_road=0)
# reserve: wall band + clearance (no houses/plots touching the wall)
fd.line([R(p) for p in WALL+[WALL[0]]],fill=255,width=int(26*F))
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
    pad=60 if name in HOUSESET else 16
    if occupied(x,y+pad/3,fwid+pad,fh+pad*0.6):return False
    if on_pave(x,y,fwid,fh,0 if edge_ok else 14):LOG['rejected_on_road']+=1;return False
    if not inside[min(H-1,int(y)),min(W-1,int(x))]:return False
  fd.ellipse([x-fwid/2,y-fh,x+fwid/2,y],fill=255 if block else 128)
  OBJ.append(dict(n=name,im=im,x=x-im.width/2,y=y-im.height,ay=y,block=block,fp=(x,y,fwid,fh),tag=tag));return True
REUSED=set();NEW=set()
HOUSES=['cx_house_a','cx_house_b','cx_house_c','cx_cottage_restyle_a','cx_cottage_restyle_b','cx_cottage_restyle_c','cx_cottage_restyle_d','ex_cottage_a','ex_cottage_c','cx_cottage_thatch_a','cx_cottage_slate_a']
HOUSESET=set(HOUSES)
# ---------- landmarks by district
LM=[('cx_palace',(495,118),1.75,'castle'),('cx_cathedral',(487,244),1.65,'cathedral'),
    ('cx_town_hall',(600,165),1.45,'townhall'),('cx_convent',(668,200),1.05,'bank'),
    ('cx_workshop_smith',(205,270),1.45,'forge'),('cx_workshop_potter',(160,318),1.4,'potter'),('cx_workshop_weaver',(270,318),1.4,'weaver'),
    ('cw5_craft_blacksmith',(240,225),1.25,'smithy2'),('cw5_craft_carpenter',(140,272),1.25,'carpenter'),('cw5_craft_tailor',(300,262),1.2,'tailor'),
    ('cx_water_mill',(712,292),1.2,'mill')]
LMPOS={}
for n,p,k,t in LM:place(n,p,k,force=True,foot=0.3,tag=t);REUSED.add(n);LMPOS[t]=p
# fountain park: fountain on paving ring centre, beds on the grass outside the ring
place('cx_fountain_big',(625,284),1.2,force=True,foot=0.35,tag='fountain');REUSED.add('cx_fountain_big')
for a in range(0,360,30):
  x=625+52*math.cos(math.radians(a));y=280+31*math.sin(math.radians(a))
  place(random.choice(['tn_flower_bed','ww_wild_rose','tn_wildflowers']),(x,y),1.1,block=False,tag='prop')
# gazebo park (no gazebo sprite: well + flower ring on grass)
place('cx_well',(785,298),1.3,force=True,tag='well');REUSED.add('cx_well')
for a in range(0,360,30):
  x=785+60*math.cos(math.radians(a));y=295+36*math.sin(math.radians(a))
  place(random.choice(['tn_flower_bed','tn_wildflowers','ww_wild_rose']),(x,y),1.1,block=False,tag='prop')
REUSED|={'tn_flower_bed','tn_wildflowers','ww_wild_rose'}
# Global Market: stalls ringing the market square (on paving edge, facing in)
STALLS=['cx_market_stall_a','cx_market_stall_b','cx_market_stall_spice','cx_stall_restyle_blue_a','cx_stall_restyle_red','cx_stall_restyle_blue_b']
MK=[]
for i,a in enumerate(range(200,520,55)):
  x=375+38*math.cos(math.radians(a));y=275+21*math.sin(math.radians(a))
  if place(STALLS[i%6],(x,y),1.3,force=True,foot=0.4,tag='stall'):MK.append((x,y))
REUSED|=set(STALLS)
# ---------- player housing (tier plots)
TIERS=json.load(open('housing_tiers/tiers.json'))
def place_plot(p,tier,gtier):
  x,y=R(p)
  base=Image.open(f'housing_tiers/lot_{"large" if tier=="legendary" else "std"}.png')
  hs=Image.open(f'housing_tiers/house_{tier}.png');gs=Image.open(f'housing_tiers/garden_{gtier}.png')
  OBJ.append(dict(n='lot',im=base,x=x-base.width/2,y=y-base.height,ay=y-base.height+2,block=False,fp=None,tag='lot'))
  an=TIERS['anchors'];hx,hy=an['house']; gx,gy=an['garden_large' if tier=='legendary' else 'garden']
  sc=TIERS['lot_scale']['large' if tier=='legendary' else 'std']
  X,Y=x-base.width/2+hx*sc,y-base.height+hy*sc
  OBJ.append(dict(n='house_'+tier,im=hs,x=X-hs.width/2,y=Y-hs.height,ay=Y,block=True,fp=(X,Y,hs.width*0.85,hs.height*0.33),tag='house'))
  GX,GY=x-base.width/2+gx*sc,y-base.height+gy*sc
  OBJ.append(dict(n='garden_'+gtier,im=gs,x=GX-gs.width/2,y=GY-gs.height,ay=GY,block=False,fp=None,tag='garden'))
  fd.rectangle([x-base.width/2,y-base.height,x+base.width/2,y],fill=255)
  return (X,Y)
st=lambda x:470-0.184*(x-450)
PLOTS=[((560,st(560)-9),'normal','normal'),((640,st(640)-9),'legendary','legendary'),((725,st(725)-9),'rare','rare'),
       ((560,st(560)+46),'rare','normal'),((640,st(640)+44),'normal','rare'),((705,st(705)+40),'normal','legendary')]
plot_ok=[];PLOTHOUSE=[]
for p,t,g in PLOTS:
  x,y=R(p);bw=Image.open(f'housing_tiers/lot_{"large" if t=="legendary" else "std"}.png').size
  a=PAVE[int(y-bw[1]):int(y),int(x-bw[0]/2):int(x+bw[0]/2)];wl=np.array(FOOT)[int(y-bw[1]):int(y),int(x-bw[0]/2):int(x+bw[0]/2)]
  print("plot",p,t,'pave',round(float(a.mean()),3),'wall/occ',round(float((wl>0).mean()),3))
  if a.mean()<0.04 and (wl>0).mean()<0.02:PLOTHOUSE.append(place_plot(p,t,g));plot_ok.append((p,t,g))
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
      place(random.choice(['tn_flower_bed','tn_bush','cx_planter_a','tn_wildflowers']),(x+dx,y+dy),1.0,block=False,tag='prop')
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
def wall_chunk(a,b):
  """a,b in px on the base line; returns RGBA sprite + offset. front face + top walk + merlons."""
  xs=[a[0],b[0]];ys=[a[1],b[1]]
  x0=int(min(xs))-4;y0=int(min(ys))-WH-WT-14;x1=int(max(xs))+4;y1=int(max(ys))+4
  w,h=x1-x0,y1-y0;tex=Image.fromarray(np.clip(ST[(np.arange(h)%400)[:,None],(np.arange(w)%600)[None,:]],0,255).astype('uint8'))
  A=(a[0]-x0,a[1]-y0);B=(b[0]-x0,b[1]-y0)
  face=Image.new('L',(w,h),0);fdw=ImageDraw.Draw(face);fdw.polygon([A,B,(B[0],B[1]-WH),(A[0],A[1]-WH)],fill=255)
  top=Image.new('L',(w,h),0);tdw=ImageDraw.Draw(top);tdw.polygon([(A[0],A[1]-WH),(B[0],B[1]-WH),(B[0],B[1]-WH-WT*0.55),(A[0],A[1]-WH-WT*0.55)],fill=255)
  out=Image.new('RGBA',(w,h),(0,0,0,0))
  f=np.array(tex).astype('float32')
  # mortar courses on face
  yy=np.arange(h)[:,None]-np.interp(np.arange(w),[min(A[0],B[0]),max(A[0],B[0])],[A[1],B[1]] if A[0]<B[0] else [B[1],A[1]])[None,:]
  mortar=((-yy)%14<1.6)
  fc=f*0.86;fc[mortar]*=0.72
  shade=0.80+0.2*np.clip(-yy/WH,0,1)[...,None];fc=fc*shade
  out.paste(Image.fromarray(np.clip(fc,0,255).astype('uint8')),(0,0),face)
  out.paste(Image.fromarray(np.clip(f*1.08,0,255).astype('uint8')),(0,0),top)
  # merlons
  L=math.dist(A,B);n=max(1,int(L/20))
  md=ImageDraw.Draw(out)
  for i in range(n):
    t0=(i+0.15)/n;t1=(i+0.6)/n
    p0=(A[0]+(B[0]-A[0])*t0,A[1]+(B[1]-A[1])*t0-WH-WT*0.55);p1=(A[0]+(B[0]-A[0])*t1,A[1]+(B[1]-A[1])*t1-WH-WT*0.55)
    md.polygon([p0,p1,(p1[0],p1[1]-12),(p0[0],p0[1]-12)],fill=(196,182,156,255),outline=(120,108,90,255))
  md.line([A,B],fill=(90,80,64,255),width=3)
  md.line([(A[0],A[1]-WH),(B[0],B[1]-WH)],fill=(150,138,116,255),width=2)
  return out,(x0,y0)
wallM=Image.new('L',(W,H),0);wd=ImageDraw.Draw(wallM)
GATE=(450,500)
gate_im=spr('cw4_gate_open',1.15)
GAX,GAY=0.43,0.95       # arch ground point inside the gatehouse sprite
WG=[]
for a,b in zip(WALL,WALL[1:]+[WALL[0]]):
  for c,d in zip(RIVER,RIVER[1:]):
    q=inter(a,b,c,d)
    if q:WG.append((q,a,b))
wg_im=spr('cw2_water_gate',1.4)
def gaps_for(a,b):
  """list of (t0,t1) parameter gaps along edge a-b (ref coords)"""
  g=[];L=math.dist(a,b)
  def tp(p):return ((p[0]-a[0])*(b[0]-a[0])+(p[1]-a[1])*(b[1]-a[1]))/L**2
  if abs((GATE[0]-a[0])*(b[1]-a[1])-(GATE[1]-a[1])*(b[0]-a[0]))/L<2:
    t=tp(GATE);hl=gate_im.width*0.40/F/L;g.append((t-hl,t+hl))
  for q,qa,qb in WG:
    if (qa,qb)==(a,b):t=tp(q);hl=wg_im.width*0.36/F/L;g.append((t-hl,t+hl))
  return g
TOWERS=[]
for a,b in zip(WALL,WALL[1:]+[WALL[0]]):
  gaps=gaps_for(a,b);A=R(a);B=R(b);L=math.dist(A,B)
  n=max(1,int(L/70))
  for i in range(n):
    t0=i/n;t1=(i+1)/n
    for g0,g1 in gaps:
      if t1>g0 and t0<g1:
        if t0<g0:t1=g0
        elif t1>g1:t0=g1
        else:t0=t1=None
        break
    if t0 is None or t1-t0<1e-4:continue
    p=(A[0]+(B[0]-A[0])*t0,A[1]+(B[1]-A[1])*t0);q=(A[0]+(B[0]-A[0])*t1,A[1]+(B[1]-A[1])*t1)
    im,(ox,oy)=wall_chunk(p,q)
    OBJ.append(dict(n='wall',im=im,x=ox,y=oy,ay=max(p[1],q[1])-2,block=True,fp=None,tag='wall'))
    wd.line([p,q],fill=255,width=26)
  # towers at each vertex and every ~110 ref along the run, never inside a gap
  m_=max(1,int(math.dist(a,b)/110))
  for i in range(m_):
    t=i/m_
    if any(g0-0.02<t<g1+0.02 for g0,g1 in gaps):continue
    TOWERS.append((a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t))
  for g0,g1 in gaps:   # towers flanking water gates
    pass
for p in TOWERS:
  x,y=R(p);im=spr('cw2_tower_round',1.25)
  OBJ.append(dict(n='cw2_tower_round',im=im,x=x-im.width/2,y=y-im.height*0.93,ay=y+8,block=True,fp=None,tag='tower'))
  wd.ellipse([x-55,y-30,x+55,y+18],fill=255)
# gatehouse: arch ground point on the wall line at GATE, road runs straight through
gx,gy=R(GATE)
OBJ.append(dict(n='cw4_gate_open',im=gate_im,x=gx-gate_im.width*GAX,y=gy-gate_im.height*GAY+6,ay=gy+10,block=True,fp=None,tag='gate'))
gm=Image.new('L',(W,H),0);gmd=ImageDraw.Draw(gm)
gmd.polygon([(gx-gate_im.width*GAX+8,gy-60),(gx+gate_im.width*(1-GAX)-8,gy-60),(gx+gate_im.width*(1-GAX)-8,gy+20),(gx-gate_im.width*GAX+8,gy+20)],fill=255)
wd.bitmap((0,0),gm,fill=255)
# passage through the arch (along road direction, down-left/up-right)
PASS=[(GATE[0]-14,GATE[1]+7),(GATE[0]+14,GATE[1]-7)]
for q,a,b in WG:
  x,y=R(q);flip=(b[0]-a[0])*(b[1]-a[1])>0
  im=spr('cw2_water_gate',1.4,flip=flip)
  OBJ.append(dict(n='cw2_water_gate',im=im,x=x-im.width/2,y=y-im.height*0.8,ay=y+20,block=True,fp=None,tag='watergate'))
  wd.ellipse([x-im.width/2,y-50,x+im.width/2,y+30],fill=255)
REUSED|={'cw2_tower_round','cw4_gate_open','cw2_water_gate'};NEW.add('procedural wall runs (stone texture from tile_plaza)')
# ---------- bridges (procedural, oriented per crossing)
BR=[]
for r in ROADS:
  for a,b in zip(r,r[1:]):
    for c,d in zip(RIVER,RIVER[1:]):
      q=inter(a,b,c,d)
      if q and inside[int(q[1]*F),int(q[0]*F)]:BR.append((q,a,b))
deckM=Image.new('L',(W,H),0);dd=ImageDraw.Draw(deckM)
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
for q,a,b in BR:bridge(q,a,b)
NEW.add('procedural stone bridges oriented per crossing')
deck=np.array(deckM)>0
# ---------- automatic prop check: no prop footprint on road/plaza/bridge
PAVE2=PAVE|deck
viol=[]
for o in OBJ:
  if o['tag'] in('prop','tree','lamp') and o['fp']:
    x,y,fw_,fh_=o['fp'];a=PAVE2[int(y-fh_):int(y),int(x-fw_/2):int(x+fw_/2)]
    if a.size and a.mean()>(0.25 if o['tag']=='lamp' else 0.0):viol.append(o)
for o in viol:OBJ.remove(o)
print('prop-on-paving violations removed',len(viol),'rejected at placement',LOG['rejected_on_road'])
# district plan
def plan():
  S=2;P_=G.resize((W//S//F*1,H//S//F*1)) if False else None
