import sys;sys.argv=['x'];exec(open('/workspace/cx_built/r2head.py').read())
import shutil,glob
R='/workspace/cx_built/rosebud';shutil.rmtree(R,ignore_errors=True)
for d in ['layers','bastion_v4']:os.makedirs(f'{R}/{d}',exist_ok=True)
shutil.copy('crosshaven_built_plate.jpg',f'{R}/plate.jpg');G.convert('RGB').save(f'{R}/ground.jpg',quality=92)
# walkmask: drop tiny unreachable islands
M=(cv2.imread('walkmask.png',0)>127).astype(np.uint8);n_,lab=cv2.connectedComponents(M);big=np.argmax(np.bincount(lab.ravel())[1:])+1
cv2.imwrite(f'{R}/walkmask.png',((lab==big)*255).astype('uint8'))
Z=json.load(open('zones_core.json'))
# height map (0 ground, elevation px on stairs/deck), 8-bit, value = z px
HM=np.zeros((H,W),np.uint8)
for b in Z['bridges']:
  c=b['centreline'];z=b['centreline_z']
  for (p,q),(za,zb) in zip(zip(c,c[1:]),zip(z,z[1:])):
    for t in np.linspace(0,1,60):
      x_,y_=p[0]+(q[0]-p[0])*t,p[1]+(q[1]-p[1])*t;cv2.circle(HM,(int(x_),int(y_)),18,int(za+(zb-za)*t),-1)
for i,b in enumerate(Z['bridges']):   # geometric heights from the Meshy render (height16), walk surfaces only, inside the walk corridor
  if b.get('height_stamp') and os.path.exists(b['height_stamp']):
    hs=cv2.imread(b['height_stamp'],0);x0,y0=b['sprite_bbox'][:2];h_,w_=hs.shape
    corr=np.zeros((H,W),np.uint8);[cv2.line(corr,tuple(map(int,p)),tuple(map(int,q)),1,40) for p,q in zip(b['centreline'][1:-2],b['centreline'][2:-1])]
    sub=HM[y0:y0+h_,x0:x0+w_];c_=corr[y0:y0+h_,x0:x0+w_]>0;hs=hs[:sub.shape[0],:sub.shape[1]]
    hs=np.minimum(hs,int(max(b['centreline_z'])+2));sel=c_&(hs>0);sub[sel]=hs[sel]
cv2.imwrite(f'{R}/heightmap.png',HM)
for f in glob.glob('bridge_h_*.png'):shutil.copy(f,f'{R}/{f}')
riv=cv2.imread('river.png',0)>127;cs,_=cv2.findContours(riv.astype(np.uint8),cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
Z['water']=dict(walkable=False,mask='river.png',polygons=[c.reshape(-1,2).tolist() for c in cs if cv2.contourArea(c)>500])
shutil.copy('river.png',f'{R}/river.png');shutil.copytree('water',f'{R}/water',dirs_exist_ok=True)
ys_,xs_=np.nonzero(lab[H-40:H]==big)
gx=Z['gates'][0]['arch'][0];i=np.argmin(abs(xs_-gx));SP=(float(xs_[i]),float(ys_[i]+H-40))
Z['spawn']=dict(hero=[SP[0],SP[1]],facing='N',note='south map edge, on the road to the main gate')
Z['plate_size']=[W,H];Z['heightmap']='heightmap.png (grey value = elevation px; 0 = ground)'
json.dump(Z,open(f'{R}/zones.json','w'),indent=1)
# layers: ground + every sprite, sorted by ay (y-sort key); gate split into back + front lintel
LY=[]
for i,o in enumerate(OBJ):
  fn=f"layers/{i:03d}_{o['n'].replace('/','_')}.png";o['im'].save(f'{R}/{fn}')
  LY.append(dict(id=i,file=fn,tag=o['tag'],x=int(o['x']),y=int(o['y']),sort_y=None if o['ay']<-1e7 else round(float(o['ay']),1),
    under_everything=o['ay']<-1e7,fade=('occluding_only' if o['tag'] in('lintel','house','tree','tower','castle','cathedral','townhall','bank') else 'never'),
    fade_min_alpha=0.4 if o['tag']=='lintel' else 0.45))
json.dump(dict(ground='ground.jpg',layers=LY),open(f'{R}/layers.json','w'))
# routes
spn=snap((SP[0]/F,SP[1]/F-6));T_=[spn]+T;hero=[]
for a,b in zip(T_,T_[1:]):hero+=astar(a,b)[:-1]
hero.append(T_[-1])
def sm(pp,k=6):
  P_=np.array(pp,float)
  for _ in range(k):P_[1:-1]=(P_[:-2]+P_[1:-1]*2+P_[2:])/4
  return [[round(x,1),round(y,1)] for x,y in P_[::4]]
RT=dict(units='plate px',hero_tour=sm(hero),
  bridge_crossings=[dict(bridge=b['id'],path=b['centreline'],z=b['centreline_z']) for b in Z['bridges']],
  npcs=[],pets=[])
for nn in npcs:
  if isinstance(nn,Idle):RT['npcs'].append(dict(name=nn.n,type='idle',at=[float(v) for v in nn.p],facing=nn.d,loop=[list(s) for s in nn.seq]))
  elif isinstance(nn,Walker):RT['npcs'].append(dict(name=nn.n,type='walker_pingpong',speed=nn.v,path=[[round(float(x),1),round(float(y),1)] for x,y in nn.P]))
  else:RT['npcs'].append(dict(name=nn.n,type='patrol',**{k:(v.tolist() if hasattr(v,'tolist') else v) for k,v in vars(nn).items() if isinstance(v,(int,float,str,list,tuple,np.ndarray))}))
for p in PETS:
  p['im'].save(f"{R}/layers/{p['n']}.png");RT['pets'].append(dict(name=p['n'],sprite=f"layers/{p['n']}.png",a=p['a'].tolist(),b=p['b'].tolist(),speed=40,pause=1.5,hop_px=3))
json.dump(RT,open(f'{R}/routes.json','w'),indent=1)
shutil.copy('/workspace/cx_built/rosebud_README.md',f'{R}/README.md')
shutil.copytree('/workspace/art/bastion_full/v4',f'{R}/bastion_v4',dirs_exist_ok=True,ignore=shutil.ignore_patterns('work','backup*'))
print('spawn',SP,'layers',len(LY),'npcs',len(RT['npcs']),'pets',len(RT['pets']),'hero pts',len(RT['hero_tour']))
