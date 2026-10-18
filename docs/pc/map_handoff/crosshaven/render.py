import json,math,sys,heapq,os,pickle
import numpy as np,cv2
from PIL import Image,ImageDraw,ImageFilter
Image.MAX_IMAGE_PIXELS=None
F=5;FPS=24
G=Image.open('ground.png').convert('RGBA');W,H=G.size
OBJ=pickle.load(open('objects.pkl','rb'))
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
WP=json.loads(os.environ.get('WP','[[664,574],[660,520],[655,480],[640,456],[610,385],[600,345],[580,315],[540,290],[500,272],[560,268],[590,262],[625,262]]'))
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
# auto-place NPCs beside the route, >=55 px clearance from hero line, on mask with margin
RP=np.array([(x,y) for x,y,_,_ in samp])
def clear(p):return np.min(np.hypot(RP[:,0]-p[0],RP[:,1]-p[1]))
names=['warden','banker','herald','elder','trader','farmer','guide','smith','woodcutter','fisher']
npcs=[];used=[]
for i,d in enumerate(np.linspace(L*0.08,L*0.95,len(names))):
  x,y,dx,dy=pos(d);n=np.hypot(dx,dy)+1e-6;nx,ny=-dy/n,dx/n
  for off in (70,-70,90,-90,110,-110,130,-130):
    p=(x+nx*off,y+ny*off)
    if 0<p[0]<W and 0<p[1]<H and dist[int(p[1]),int(p[0])]>14 and clear(p)>58 and all(math.dist(p,u)>70 for u in used):
      nm=names[i]
      if nm in('warden','elder','guide','woodcutter'):
        q=(p[0]+dx/n*60,p[1]+dy/n*60)
        if dist[int(q[1]),int(q[0])]>14 and clear(q)>58 and all(math.dist(q,u)>70 for u in used):
          npcs.append(Patrol(nm,p,q,32,'patrol_look' if nm=='warden' else 'idle',1.5));used+= [p,q];break
      else:
        npcs.append(Idle(nm,p,'S' if off>0 else 'W',[('idle',2.5),('talk',0.75),('work',2.0)]));used.append(p);break
print('npcs',len(npcs),[n.n for n in npcs])
# checks
sep=1e9
for t in np.arange(0,DUR,1/FPS):
  hx,hy,_,_=pos(min(L,t*SPEED))
  for nn in npcs:
    p,_,_=nn.state(t)
    if not m[int(p[1]),int(p[0])]:sys.exit(f'NPC {nn.n} off mask')
    sep=min(sep,math.dist(p,(hx,hy)))
print('NPC mask ok; min hero-NPC sep px',round(sep,1))
os.makedirs(os.environ.get('OUT','frames'),exist_ok=True)
VW,VH=960,540;x,y,_,_=pos(0);cam=[x,y-20];hold='E';left=0
ONLY=[int(v) for v in os.environ.get('ONLY','').split(',') if v]
fade_log=0
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
  base=G.crop((x0,y0,x0+VW,y0+VH))
  lst,piv=hero[hold];ch=lst[int(d/(115/12))%12] if moving else lst[0]
  chars=[(py,ch,piv,(px,py))]
  for nn in npcs:p,im,pv=nn.state(t);chars.append((p[1],im,pv,tuple(p)))
  cbb=[(sx-pv[0],sy-pv[1],sx-pv[0]+im.width,sy-pv[1]+im.height,sy) for _,im,pv,(sx,sy) in chars]
  sh=Image.new('RGBA',base.size,(0,0,0,0));dr=ImageDraw.Draw(sh)
  for _,im,pv,(sx,sy) in chars:dr.ellipse([sx-x0-11,sy-y0-4,sx-x0+11,sy-y0+4],fill=(20,15,8,110))
  base=Image.alpha_composite(base,sh.filter(ImageFilter.GaussianBlur(1.5)))
  items=[]
  for o in OBJ:
    b=o['bb']
    if b[2]<x0 or b[0]>x0+VW or b[3]<y0 or b[1]>y0+VH:continue
    al=1.0
    if o['tag'] not in('lot','garden','bridge') :
      for c in cbb:
        if o['ay']>c[4]+2 and not(b[2]<c[0] or b[0]>c[2] or b[3]<c[1] or b[1]>c[3]) and cover(o,c)>0.15:
          # only fade if sprite pixels actually cover the character
          al=0.45;break
    items.append((o['ay'] if o['tag'] not in('lot','bridge') else (-1e9 if o['tag']=='lot' else -1e8),0,o,al))
  for i,c in enumerate(chars):items.append((c[0],1,c,1))
  items.sort(key=lambda s:(s[0],s[1]))
  for ay,kind,o,al in items:
    if kind==0:
      im=o['im']
      if al<1:a=np.array(im);a[...,3]=(a[...,3]*al).astype(np.uint8);im=Image.fromarray(a);fade_log+=1
      _paste(base,im,o['x']-x0,o['y']-y0)
    else:
      _,im,pv,(sx,sy)=o;_paste(base,im,sx-x0-pv[0],sy-y0-pv[1])
  base.convert('RGB').save(f"{os.environ.get('OUT','frames')}/f{fi:04d}.png")
print('done',N,'fades',fade_log)
