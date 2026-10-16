import json,math,sys,heapq,os,pickle
import numpy as np,cv2
from PIL import Image,ImageDraw,ImageFilter
Image.MAX_IMAGE_PIXELS=None
F=5;FPS=24
G=Image.open('ground.png').convert('RGBA');W,H=G.size
OBJ=pickle.load(open('objects.pkl','rb'))
GOB=[o for o in OBJ if o['tag']=='gate'][0];GX_=GOB['arch'][0] if 'arch' in GOB else GOB['x']+GOB['im'].width*0.43;GY_=(GOB['arch'][1] if 'arch' in GOB else GOB['ay'])-10
gi=np.array(GOB['im']);w_,h_=GOB['im'].width,GOB['im'].height
# front layer = the gatehouse's front face band (arch lintel + front-right tower), from the arch rightwards
WLx,WLy=GOB['WL'][0]-GOB['x'],GOB['WL'][1]-GOB['y'];WRx,WRy=GOB['WR'][0]-GOB['x'],GOB['WR'][1]-GOB['y'];sl=(WRy-WLy)/(WRx-WLx)
yy,xx=np.mgrid[0:h_,0:w_];fl=WLy+sl*(xx-WLx)
sel=(xx>GX_-GOB['x']-26)&(yy<=fl+4)&(yy>=fl-int(0.62*h_))
fr=np.zeros_like(gi);fr[sel]=gi[sel];bk=gi.copy();bk[sel]=0;GOB['im']=Image.fromarray(bk)
OBJ.append(dict(n='gate_front_lintel',im=Image.fromarray(fr),x=GOB['x'],y=GOB['y'],ay=GOB['ay']+400,block=False,fp=None,tag='lintel'))
GOB['ay']=GY_-160;GOB['tag']='gate_back'
for o in OBJ:
  if o['tag'] in('wall','tower') and math.dist((o['x']+o['im'].width/2,o['ay']),(GX_,GY_))<330:o['ay']=min(o['ay'],GY_-40);o['tag']+='_g'
for o in OBJ:o['bb']=(o['x'],o['y'],o['x']+o['im'].width,o['y']+o['im'].height)
m=cv2.imread('walkmask.png',0)>127
dist=cv2.distanceTransform(m.astype('uint8'),cv2.DIST_L2,5)
k=dist>12
def astar(a,b):
  g={a:0};prev={};pq=[(0,0,a)];S=4
  while pq:
    _,c,u=heapq.heappop(pq)
    if u==b:break
    if c>g[u]:continue
    for dx in(-S,0,S):
      for dy in(-S,0,S):
        v=(u[0]+dx,u[1]+dy)
        if (dx or dy) and 0<=v[0]<W and 0<=v[1]<H and k[v[1],v[0]]:
          nc=c+math.hypot(dx,dy)*(1+40/(1+dist[v[1],v[0]]))+0.0
          if nc<g.get(v,1e18):g[v]=nc;prev[v]=u;heapq.heappush(pq,(nc+math.dist(v,b),nc,v))
  if b not in prev:sys.exit(f'no path {a}->{b}')
  p=[b]
  while p[-1]!=a:p.append(prev[p[-1]])
  return p[::-1]
ys,xs=np.nonzero(k[::4,::4]);ys=ys*4;xs=xs*4
def snap(t):i=np.argmin((xs-t[0]*F)**2+(ys-t[1]*F)**2);return(int(xs[i]),int(ys[i]))
WP=json.loads(os.environ.get('WP','[[405,522],[420,515],[450,500],[466,492],[482,484],[505,463],[478,398],[430,360],[408,330],[376,280],[330,282],[300,282],[376,276],[430,262],[455,300],[530,305],[590,300],[650,262],[625,225],[600,198],[622,186]]'))
T=[snap(t) for t in WP]
full=[]
for a,b in zip(T,T[1:]):full+=astar(a,b)[:-1]
full.append(T[-1])
P=np.array(full,float)
for _ in range(8):P[1:-1]=(P[:-2]+P[1:-1]*2+P[2:])/4
path=[tuple(p) for p in P[::4]]+[tuple(P[-1])]
json.dump(path,open('route.json','w'))
cd=[0.0]
for a,b in zip(path,path[1:]):cd.append(cd[-1]+math.hypot(b[0]-a[0],b[1]-a[1]))
L=cd[-1];SPEED=95.0
def pos(d):
  d=max(0,min(L,d));i=int(np.searchsorted(cd,d));i=max(1,min(i,len(cd)-1))
  s=cd[i]-cd[i-1];t=0 if s<1e-6 else (d-cd[i-1])/s;a,b=path[i-1],path[i]
  return a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,b[0]-a[0],b[1]-a[1]
walk_dur=L/SPEED;DUR=walk_dur+1.5;N=int(DUR*FPS)
samp=[pos(d) for d in np.arange(0,L,1)]
bad=sum(1 for x,y,_,_ in samp if not m[int(round(y)),int(round(x))])
mind=min(dist[int(round(y)),int(round(x))] for x,y,_,_ in samp)
# water margin
riv=None
print('path px',round(L),'walk s',round(walk_dur,1),'frames',N,'HERO bad',bad,'min edge',round(float(mind),1))
if bad:sys.exit('hero mask fail')
HERO_H=56;HB='/workspace/art/bastion_full/v4/walk'
hero={}
for f in 'SENW':
  ims=[Image.open(f'{HB}/bastion_walk_{f}_f{i:02d}.png').convert('RGBA') for i in range(12)]
  bb=[np.nonzero(np.array(im)[...,3]>20) for im in ims]
  top=min(b[0].min() for b in bb);bot=max(b[0].max() for b in bb);cx=np.mean([(b[1].min()+b[1].max())/2 for b in bb])
  s=HERO_H/(bot-top);hero[f]=([im.resize((int(im.width*s),int(im.height*s)),Image.LANCZOS) for im in ims],(cx*s,(bot-2)*s))
def facing(dx,dy):
  # v4 iso dirs: S=down-right, W=down-left, N=up-left, E=up-right
  return {(1,1):'S',(-1,1):'W',(-1,-1):'N',(1,-1):'E'}[(1 if dx>=0 else -1,1 if dy>=0 else -1)]
NB='/workspace/stasium-pc-look/ship/npc_sprites';NPC_H=50;cache={}
def strip(name,anim,d):
  key=(name,anim,d)
  if key in cache:return cache[key]
  src='s' if d in 'SW' else 'n'
  fn=f'{NB}/{name}/_2x/{anim}_{src}.png'
  if not os.path.exists(fn):fn=f'{NB}/{name}/_2x/idle_{src}.png'
  im=Image.open(fn).convert('RGBA');n=im.width//256;s=NPC_H/136
  lst=[im.crop((i*256,0,i*256+256,256)).resize((int(256*s),int(256*s)),Image.LANCZOS) for i in range(n)];piv=(128*s,240*s)
  if d in 'WE':lst=[f.transpose(Image.FLIP_LEFT_RIGHT) for f in lst];piv=(256*s-piv[0],piv[1])
  cache[key]=(lst,piv);return cache[key]
class Patrol:
  def __init__(self,name,a,b,speed,ea,ed,stride=80):
    self.n=name;self.a=np.array(a,float);self.b=np.array(b,float);self.v=speed;self.ea=ea;self.ed=ed;self.stride=stride
    self.tw=np.linalg.norm(self.b-self.a)/speed;self.cyc=2*(self.tw+ed)
  def state(self,t):
    t=t%self.cyc;half=self.tw+self.ed;fwd=t<half;tt=t if fwd else t-half
    A,B=(self.a,self.b) if fwd else (self.b,self.a);dx,dy=B-A
    if tt<self.tw:
      p=A+(B-A)*tt/self.tw;lst,piv=strip(self.n,'walk',facing(dx,dy));return p,lst[int(tt*self.v/(self.stride/len(lst)))%len(lst)],piv
    lst,piv=strip(self.n,self.ea,facing(dx,dy));return B,lst[int((tt-self.tw)*8)%len(lst)],piv
class Idle:
  def __init__(self,name,p,d,seq):self.n=name;self.p=np.array(p,float);self.d=d;self.seq=seq
  def state(self,t):
    tot=sum(s for _,s in self.seq);tt=t%tot
    for a,s in self.seq:
      if tt<s:break
      tt-=s
    lst,piv=strip(self.n,a,self.d);return self.p,lst[int(tt*8)%len(lst)],piv
BI=json.load(open('build_info.json'))
def snapw(p,mind=12):
  p=(p[0]*F,p[1]*F);ys_,xs_=np.nonzero(dist[::2,::2]>mind);ys_*=2;xs_*=2
  i=np.argmin((xs_-p[0])**2+(ys_-p[1])**2);return (float(xs_[i]),float(ys_[i]))
RP=np.array([(x,y) for x,y,_,_ in samp])
lm=BI['lm']
def far(cands,c=70):
  for p in cands:
    q=snapw(p)
    if np.min(np.hypot(RP[:,0]-q[0],RP[:,1]-q[1]))>c:return q
  return snapw(cands[0])
npcs=[]
npcs.append(Idle('smith',snapw((lm['forge'][0]+18,lm['forge'][1]+10)),'W',[('work',3.0),('idle',1.0)]))
npcs.append(Idle('forge_master',snapw((lm['smithy2'][0]+14,lm['smithy2'][1]+10)),'S',[('work',2.5),('talk',0.75),('idle',1.0)]))
for k_,(sx,sy) in enumerate(BI['stalls'][:4]):
  cx,cy=375,275;p=(sx+(cx-sx)*0.12,sy+(cy-sy)*0.12+5)
  npcs.append(Idle(['trader','herald','archivist','door_keeper'][k_],snapw(p),'S' if sy<cy else 'N',[('work',2.0),('talk',0.75),('idle',1.5)]))
npcs.append(Idle('banker',snapw((lm['bank'][0]-6,lm['bank'][1]+12)),'W',[('idle',2.5),('talk',0.75),('work',1.5)]))
g=BI['gates'][0]
def far(cands,c=70):
  for p in cands:
    q=snapw(p)
    if np.min(np.hypot(RP[:,0]-q[0],RP[:,1]-q[1]))>c:return q
  return snapw(cands[0])
wa=far([(g[0]+dx,g[1]+dy) for dx,dy in [(30,-30),(45,-30),(40,-22),(-30,-25),(55,-35),(60,-28)]])
wb=far([(wa[0]/F+dx,wa[1]/F+dy) for dx,dy in [(22,-6),(-22,6),(20,-10),(-20,10),(15,-8)]])
npcs.append(Patrol('warden',wa,wb,34,'patrol_look',1.6))
npcs.append(Idle('farmer',snapw((660,300)),'W',[('work',3.5),('idle',1.2)]))   # park gardener (farmer sprite)
# ambient walkers between districts (A* routes, ping-pong)
class Walker:
  def __init__(self,name,pts,speed,t0):
    self.n=name;T_=[snap(t) for t in pts];pp=[]
    for a,b in zip(T_,T_[1:]):pp+=astar(a,b)[:-1]
    pp.append(T_[-1]);Pp=np.array(pp,float)
    for _ in range(6):Pp[1:-1]=(Pp[:-2]+Pp[1:-1]*2+Pp[2:])/4
    self.P=Pp[::3];self.cd=np.concatenate([[0],np.cumsum(np.hypot(*np.diff(self.P,axis=0).T))]);self.v=speed;self.t0=t0
  def state(self,t):
    L_=self.cd[-1];d=((t+self.t0)*self.v)%(2*L_);fwd=d<L_;d=d if fwd else 2*L_-d
    i=max(1,min(len(self.cd)-1,int(np.searchsorted(self.cd,d))));a,b=self.P[i-1],self.P[i]
    s_=self.cd[i]-self.cd[i-1];tt=0 if s_<1e-6 else (d-self.cd[i-1])/s_;p=a+(b-a)*tt;dv=(b-a)*(1 if fwd else -1)
    lst,piv=strip(self.n,'walk',facing(dv[0],dv[1]));return p,lst[int(d/(80/len(lst)))%len(lst)],piv
npcs.append(Walker('elder',[[300,282],[250,282],[240,380]],26,0))
npcs.append(Walker('guide',[[760,330],[790,300],[860,320]],30,5))
npcs.append(Walker('fisher',[[700,250],[740,200],[800,180]],28,3))
npcs.append(Walker('woodcutter',[[440,215],[420,150],[350,120]],30,8))
for nn in npcs:
  if isinstance(nn,Idle) and np.min(np.hypot(RP[:,0]-nn.p[0],RP[:,1]-nn.p[1]))<55:
    o_=nn.p/F;c_=[(o_[0]+r*math.cos(a),o_[1]+0.6*r*math.sin(a)) for r in (8,12,16,20,26) for a in np.linspace(0,6.28,12,endpoint=False)]
    nn.p=np.array(far(c_,58))
print('npcs',len(npcs),[n.n for n in npcs])
# pets (no walk cycle exists: they trot with a hop bob along short paths)
HS='/workspace/stasium-pc-look/ship/housing_v1/pieces/animals/'
def pet(n,h):
  im=Image.open(HS+n+'.png').convert('RGBA');im=im.crop(im.getbbox());return im.resize((int(im.width*h/im.height),h),Image.LANCZOS)
PETS=[]
for n,h,a,b in [('pet_dog',30,(640,430),(600,433)),('pet_cat',24,(662,248),(690,232)),('pet_dog',30,(820,200),(860,215))]:
  A_=np.array(snapw(a,8));B_=np.array(snapw(b,8));im=pet(n,h);PETS.append(dict(n=n,a=A_,b=B_,im=im,fl=im.transpose(Image.FLIP_LEFT_RIGHT)))
def pet_state(pt,t):
  L_=np.linalg.norm(pt['b']-pt['a']);cyc=2*L_/40+3;tt=t%cyc
  if tt<L_/40:p=pt['a']+(pt['b']-pt['a'])*tt*40/L_;dx=(pt['b']-pt['a'])[0];hop=abs(math.sin(tt*14))*3
  elif tt<L_/40+1.5:p=pt['b'];dx=(pt['a']-pt['b'])[0];hop=0
  elif tt<2*L_/40+1.5:u=(tt-L_/40-1.5)*40/L_;p=pt['b']+(pt['a']-pt['b'])*u;dx=(pt['a']-pt['b'])[0];hop=abs(math.sin(tt*14))*3
  else:p=pt['a'];dx=(pt['b']-pt['a'])[0];hop=0
  im=pt['fl'] if dx<0 else pt['im'];return p,im,(im.width/2,im.height-2+hop)
# checks
sep=1e9
for t in np.arange(0,DUR,1/FPS):
  hx,hy,_,_=pos(min(L,t*SPEED))
  for nn in npcs:
    p,_,_=nn.state(t)
    if not m[int(p[1]),int(p[0])]:sys.exit(f'NPC {nn.n} off mask at {p/F}')
    sep=min(sep,math.dist(p,(hx,hy)))
per={}
for t in np.arange(0,DUR,1/FPS):
  hx,hy,_,_=pos(min(L,t*SPEED))
  for nn in npcs:
    p,_,_=nn.state(t);dd_=math.dist(p,(hx,hy))
    if dd_<per.get(nn.n,(1e9,))[0]:per[nn.n]=(round(dd_,1),round(t,1))
print('NPC mask ok; per-NPC min sep',per)
RIVd=cv2.distanceTransform((cv2.imread('river.png',0)<128).astype('uint8'),cv2.DIST_L2,5)
print('hero min dist to open water px',round(float(min(RIVd[int(y),int(x)] for x,y,_,_ in samp)),1))
os.makedirs(os.environ.get('OUT','frames'),exist_ok=True)
VW,VH=960,540;x,y,_,_=pos(0);cam=[GX_+200,GY_-60];hold='E';left=0
ONLY=[int(v) for v in os.environ.get('ONLY','').split(',') if v]
fade_log=0
RIV=cv2.imread('river.png',0)>127
rng=np.random.default_rng(5)
spark=np.zeros((1024,1024),np.float32)
for _ in range(2600):
  x_,y_=rng.integers(0,1024,2);cv2.ellipse(spark,(int(x_),int(y_)),(int(rng.integers(4,11)),2),0,0,360,float(rng.uniform(0.4,1)),-1)
spark=cv2.GaussianBlur(spark,(0,0),1.2)
FOUNT=[o for o in OBJ if o['tag']=='fountain'][0]
CHIM=[o for o in OBJ if o['tag'] in('house','forge','smithy2','potter')][::2]
BFC=[(255,150,40),(250,90,160),(120,170,255),(255,230,60),(190,120,255),(255,255,255)]
BF=[dict(c=np.array(c)*F,ph=rng.uniform(0,6),col=BFC[i%len(BFC)],r=rng.uniform(25,50)) for i,c in enumerate([(615,300),(640,262),(660,290),(785,320),(760,280),(810,300),(540,438),(700,455),(500,300),(450,300),(600,200),(470,470)])]
BIRDS=[dict(y=rng.uniform(0,1),sp=rng.uniform(90,140),ph=rng.uniform(0,40)) for _ in range(6)]
FA={}
def draw_life(base,t,x0,y0):
  # river shimmer (flows along a fixed diagonal)
  sub=RIV[y0:y0+VH,x0:x0+VW]
  if sub.any():
    ox_=int(t*22)%1024;oy_=int(t*11)%1024
    sp=np.roll(np.roll(spark,ox_,1),oy_,0);sp=np.tile(sp,(2,2))[:VH,:VW]
    a=(sp*sub*0.55*(0.75+0.25*math.sin(t*2.1)))
    arr=np.array(base).astype(np.float32);arr[...,:3]=arr[...,:3]*(1-a[...,None])+np.array([235,248,255])*a[...,None]
    base=Image.fromarray(arr.astype(np.uint8))
  d=ImageDraw.Draw(base)
  # fountain spray
  fx=FOUNT['x']+FOUNT['im'].width/2-x0;fy=FOUNT['y']+FOUNT['im'].height*0.12-y0
  if -100<fx<VW+100 and -100<fy<VH+100:
    for k_ in range(40):
      ph=(t*1.3+k_/40)%1;ang=k_*2.4;r=ph*34
      px_=fx+math.cos(ang)*r;py_=fy-ph*(1-ph)*80+ph*30
      d.ellipse([px_-2,py_-2,px_+2,py_+2],fill=(225,240,255,int(220*(1-ph))))
  return base
def draw_air(base,t,x0,y0):
  d=ImageDraw.Draw(base,'RGBA')
  # chimney/forge smoke
  for o in CHIM:
    cx_=o['x']+o['im'].width*0.68-x0;cy_=o['y']+o['im'].height*0.08-y0
    if not(-60<cx_<VW+60 and -150<cy_<VH+60):continue
    big=o['tag']!='house'
    for k_ in range(7 if big else 4):
      ph=(t*0.35+k_/(7 if big else 4)+hash(o['n'])%7*0.1)%1
      r=4+ph*(18 if big else 11);sx_=cx_+math.sin(ph*5+k_)*6+ph*14;sy_=cy_-ph*(90 if big else 60)
      g_=110 if big else 170
      d.ellipse([sx_-r,sy_-r,sx_+r,sy_+r],fill=(g_,g_,g_,int((150 if big else 95)*(1-ph))))
  # butterflies: 2-wing flapping shapes, 10-12px, bright
  for b in BF:
    c=b['c'];ph=t*0.7+b['ph'];x_=c[0]+math.sin(ph)*b['r']-x0;y_=c[1]+math.sin(ph*1.7)*b['r']*0.5-20-y0
    if not(0<x_<VW and 0<y_<VH):continue
    f=abs(math.sin(t*12+b['ph']))*10+3
    c2=tuple(int(v*0.7) for v in b['col'])
    for sg in(-1,1):
      d.polygon([(x_,y_-2),(x_+sg*f,y_-11),(x_+sg*(f+2),y_-3),(x_+sg*1,y_)],fill=b['col']+(255,),outline=(30,20,15,255))
      d.polygon([(x_,y_),(x_+sg*f*0.8,y_+2),(x_+sg*f*0.6,y_+8),(x_,y_+2)],fill=c2+(255,),outline=(30,20,15,255))
    d.line([x_,y_-5,x_,y_+5],fill=(25,18,10,255),width=3)
  # small birds crossing the sky
  for b in BIRDS:
    x_=((t+b['ph'])*b['sp'])%(VW+200)-100;y_=40+b['y']*220+math.sin(t*2+b['ph'])*8
    w_=6+abs(math.sin(t*9+b['ph']))*3
    d.line([x_-w_,y_-3,x_,y_,x_+w_,y_-3],fill=(40,36,40,255),width=2)
  return base
def cover(o,c):
  if 'A' not in o:o['A']=np.array(o['im'])[...,3]>40
  A=o['A'];x0_=int(c[0]-o['x']);y0_=int(c[1]-o['y']);x1_=int(c[2]-o['x']);y1_=int(c[3]-o['y'])
  sub=A[max(0,y0_):max(0,y1_),max(0,x0_):max(0,x1_)]
  return sub.sum()/max(1,(x1_-x0_)*(y1_-y0_)*0.45)
def _paste(base,im,x,y):
  x=int(x);y=int(y);l=Image.new('RGBA',base.size,(0,0,0,0))
  cx0,cy0=max(0,-x),max(0,-y)
  if cx0>=im.width or cy0>=im.height or x>=base.width or y>=base.height:return
  sub=im.crop((cx0,cy0,im.width,im.height))
  if sub.width<=0 or sub.height<=0:return
  base.alpha_composite(sub,(x+cx0,y+cy0)) if x+cx0<base.width and y+cy0<base.height else None
for fi in range(N):
  t=fi/FPS;d=min(L,t*SPEED);moving=t<walk_dur;px,py,dx,dy=pos(d)
  if moving:
    rf=facing(dx,dy)
    if rf!=hold:
      if left<=0:hold=rf;left=5
      else:left-=1
    else:left=5
  cam[0]+=(px-cam[0])*0.08;cam[1]+=(py-20-cam[1])*0.08
  x0=int(np.clip(cam[0]-VW/2,0,W-VW));y0=int(np.clip(cam[1]-VH/2,0,H-VH))
  if ONLY and fi not in ONLY:continue
  base=draw_life(G.crop((x0,y0,x0+VW,y0+VH)),t,x0,y0).convert('RGBA')
  lst,piv=hero[hold];ch=lst[int(d/(115/12))%12] if moving else lst[0]
  chars=[(py,ch,piv,(px,py))]
  for nn in npcs:p,im,pv=nn.state(t);chars.append((p[1],im,pv,tuple(p)))
  for pt in PETS:p,im,pv=pet_state(pt,t);chars.append((p[1],im,pv,tuple(p)))
  cbb=[(sx-pv[0],sy-pv[1],sx-pv[0]+im.width,sy-pv[1]+im.height,sy) for _,im,pv,(sx,sy) in chars]
  sh=Image.new('RGBA',base.size,(0,0,0,0));dr=ImageDraw.Draw(sh)
  for _,im,pv,(sx,sy) in chars:dr.ellipse([sx-x0-11,sy-y0-4,sx-x0+11,sy-y0+4],fill=(20,15,8,110))
  base=Image.alpha_composite(base,sh.filter(ImageFilter.GaussianBlur(1.5)))
  items=[]
  for o in OBJ:
    b=o['bb']
    if b[2]<x0 or b[0]>x0+VW or b[3]<y0 or b[1]>y0+VH:continue
    al=1.0;key=id(o)
    if o['tag'] not in('lot','garden','bridge','gate_back','wall_g','tower_g','gate','watergate') :
      for c in cbb:
        if o['ay']>c[4]+2 and not(b[2]<c[0] or b[0]>c[2] or b[3]<c[1] or b[1]>c[3]) and cover(o,c)>0.15:
          # only fade if sprite pixels actually cover the character
          al=0.4 if o['tag']=='lintel' else 0.45;o['_cov']=c;break
    cur=FA.get(key,1.0);cur+= (al-cur)*0.25;FA[key]=cur;al=cur if abs(cur-1)>0.02 else 1.0
    items.append((o['ay'] if o['tag'] not in('lot','bridge') else (-1e9 if o['tag']=='lot' else -1e8),0,o,al))
  for i,c in enumerate(chars):items.append((c[0],1,c,1))
  if os.environ.get("DBG"):print(fi,[(c[3],round(c[0])) for c in chars][:1],[(o["tag"],round(o["ay"])) for o in OBJ if o["tag"] in("gate_back","lintel")])
  items.sort(key=lambda s:(s[0],s[1]))
  for ay,kind,o,al in items:
    if kind==0:
      im=o['im']
      if o['tag']=='tree':
        sw=math.sin(t*1.6+o['x']*0.013)*0.035
        im=im.transform(im.size,Image.AFFINE,(1,sw,-sw*im.height,0,1,0),resample=Image.BILINEAR)
      if al<1 and o['tag']=='lintel' and o.get('_cov'):   # local see-through window around the character only
        c=o['_cov'];a=np.array(im).astype(np.float32);yy,xx=np.mgrid[0:a.shape[0],0:a.shape[1]]
        cx=(c[0]+c[2])/2-o['x'];cy=(c[1]+c[3])/2-o['y'];rx=(c[2]-c[0])/2+14;ry=(c[3]-c[1])/2+14
        d_=np.sqrt(((xx-cx)/rx)**2+((yy-cy)/ry)**2);f=np.clip((d_-0.75)/0.35,0,1);fac=al+(1-al)*f
        a[...,3]*=fac;im=Image.fromarray(a.astype(np.uint8));fade_log+=1
      elif al<1:a=np.array(im);a[...,3]=(a[...,3]*al).astype(np.uint8);im=Image.fromarray(a);fade_log+=1
      _paste(base,im,o['x']-x0,o['y']-y0)
    else:
      _,im,pv,(sx,sy)=o;_paste(base,im,sx-x0-pv[0],sy-y0-pv[1])
  # never-disappear pass: characters overlapped by any later-drawn object get a 45% ghost on top
  seen=False;drawn_after={}
  for ay,kind,o,al in items:
    if kind==1:drawn_after[id(o)]=[]
    else:
      for k in drawn_after:drawn_after[k].append(o)
  for ay,kind,o,al in items:
    if kind!=1:continue
    _,im,pv,(sx,sy)=o;cb=(sx-pv[0],sy-pv[1],sx-pv[0]+im.width,sy-pv[1]+im.height)
    if any(not(q['bb'][2]<cb[0] or q['bb'][0]>cb[2] or q['bb'][3]<cb[1] or q['bb'][1]>cb[3]) and q['tag'] not in('lot','bridge') for q in drawn_after[id(o)]):
      a=np.array(im);a[...,3]=(a[...,3]*0.45).astype(np.uint8);_paste(base,Image.fromarray(a),sx-x0-pv[0],sy-y0-pv[1])
  base=draw_air(base,t,x0,y0)
  base.convert('RGB').save(f"{os.environ.get('OUT','frames')}/f{fi:04d}.png")
print('done',N,'fades',fade_log)
