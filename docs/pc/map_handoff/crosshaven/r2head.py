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
