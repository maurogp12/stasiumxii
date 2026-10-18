import bpy,sys,math,json,numpy as np
from mathutils import Vector,Matrix,Euler
n=sys.argv[-1];D='/workspace/crosshaven_paint/work/3d_cities/crosshaven/animals/'
QUAD=n in('ani_cat','ani_dog','ani_horse')
bpy.ops.wm.read_factory_settings(use_empty=True);sc=bpy.context.scene;sc.render.fps=30
bpy.ops.import_scene.gltf(filepath=D+f'raw/norm/{n}.glb')
me=[o for o in bpy.data.objects if o.type=='MESH'][0];me.name=n
V=np.array([list(v.co) for v in me.data.vertices]);mn=V.min(0);mx=V.max(0);H=mx[2];L=mx[1]-mn[1];W=mx[0]-mn[0]
yF,yB=mn[1],mx[1]
def slab(y,dy):
  return V[np.abs(V[:,1]-y)<dy]
J={}
if QUAD:
  low=V[V[:,2]<0.22*H]
  # split low verts by y: front/back via 2-means
  ys=low[:,1];c1,c2=np.percentile(ys,20),np.percentile(ys,80)
  for _ in range(20):
    m=np.abs(ys-c1)<np.abs(ys-c2);c1,c2=ys[m].mean(),ys[~m].mean()
  yfl,ybl=min(c1,c2),max(c1,c2)
  legs={}
  for tag,yc in (('Front',yfl),('Hind',ybl)):
    g=low[np.abs(low[:,1]-yc)<0.12*L]
    for side,sgn in (('L',1),('R',-1)):
      s=g[g[:,0]*sgn>0]
      if len(s)<5: s=g
      legs[tag+side]=np.array([np.median(s[:,0]),np.median(s[:,1]),0.0])
  back={}
  for tag,yc in (('Front',yfl),('Hind',ybl)):
    sl=slab(yc,0.05*L);sl=sl[np.abs(sl[:,0])<0.25*W];back[tag]=sl[:,2].max();
  zf=back['Front'];zh=back['Hind']
  J['hips']=Vector((0,ybl,0.78*zh));J['chest']=Vector((0,yfl,0.78*zf));J['spine']=(J['hips']+J['chest'])/2
  # head: highest point near front
  fr=V[V[:,1]<yfl];top=fr[fr[:,2].argmax()]
  nose=V[V[:,1]<yF+0.03*L];J['nose']=Vector((0,yF,float(np.median(nose[:,2]))))
  J['head']=Vector((0,top[1]+0.25*(J['nose'].y-top[1])*0,top[2]-0.18*(top[2]-J['nose'].z)-0.06*H))
  J['neck']=Vector((0,yfl-0.06*L,0.9*zf))
  # tail: rear verts behind hind legs
  rear=V[V[:,1]>ybl+0.10*L]
  tb=Vector((0,ybl+0.08*L,0.85*zh));J['tail0']=tb
  if len(rear)>10:
    ts=np.linspace(ybl+0.10*L,yB,4)[1:];pts=[]
    for y in ts:
      s=V[np.abs(V[:,1]-y)<0.03*L];s=s if len(s) else rear
      pts.append(Vector((0,float(y),float(np.median(s[:,2])))))
    J['tail1'],J['tail2'],J['tailend']=pts
  for k,p in legs.items():
    top_z=0.72*(zf if k.startswith('Front') else zh);x=p[0]*0.75;y=p[1]
    fwd=-0.04*L
    J[k+'_top']=Vector((x,y,top_z));J[k+'_knee']=Vector((p[0],y+(0.015*L if k.startswith('Front') else -0.03*L),0.45*top_z))
    J[k+'_ankle']=Vector((p[0],y+(0 if k.startswith('Front') else 0.03*L),0.12*top_z));J[k+'_toe']=Vector((p[0],y+fwd,0.0))
  BONES=[('root',Vector((0,(yfl+ybl)/2,0)),Vector((0,(yfl+ybl)/2-0.1*L,0)),None),
   ('hips',J['hips'],J['spine'],'root'),('spine',J['spine'],J['chest'],'hips'),('chest',J['chest'],J['neck'],'spine'),
   ('neck',J['neck'],J['head'],'chest'),('head',J['head'],J['nose'],'neck')]
  if 'tail1' in J: BONES+=[('tail_1',J['tail0'],J['tail1'],'hips'),('tail_2',J['tail1'],J['tail2'],'tail_1'),('tail_3',J['tail2'],J['tailend'],'tail_2')]
  for k in legs:
    side=k[-1];kind='front_leg' if k.startswith('Front') else 'hind_leg';par='chest' if k.startswith('Front') else 'hips';b=f'{kind}_{"l" if side=="L" else "r"}'
    BONES+=[(b+'_upper',J[k+'_top'],J[k+'_knee'],par),(b+'_lower',J[k+'_knee'],J[k+'_ankle'],b+'_upper'),(b+'_foot',J[k+'_ankle'],J[k+'_toe'],b+'_lower')]
else:
  low=V[V[:,2]<0.18*H];legs={}
  for side,sgn in (('l',1),('r',-1)):
    s=low[low[:,0]*sgn>0];s=s if len(s)>3 else low
    legs[side]=np.array([np.median(s[:,0]),np.median(s[:,1]),0.0])
  body=V[(V[:,2]>0.2*H)&(V[:,2]<0.7*H)];bc=body.mean(0)
  top=V[V[:,2].argmax()];beak=V[V[:,1]<yF+0.03*L]
  J['hips']=Vector((0,bc[1]+0.08*L,bc[2]));J['chest']=Vector((0,bc[1]-0.12*L,bc[2]+0.05*H))
  J['neck']=Vector((0,top[1]+0.06*L,0.5*(top[2]+bc[2])+0.05*H));J['head']=Vector((0,top[1]+0.02*L,top[2]-0.08*H));J['beak']=Vector((0,yF,float(np.median(beak[:,2]))))
  J['tail0']=Vector((0,bc[1]+0.22*L,bc[2]+0.02*H));rear=V[V[:,1]>yB-0.08*L];J['tailend']=Vector((0,yB,float(np.median(rear[:,2]))))
  hw=float(np.percentile(np.abs(body[:,0]),95))
  BONES=[('root',Vector((0,legs['l'][1],0)),Vector((0,legs['l'][1]-0.15*L,0)),None),('hips',J['hips'],J['chest'],'root'),('chest',J['chest'],J['neck'],'hips'),
   ('neck',J['neck'],J['head'],'chest'),('head',J['head'],J['beak'],'neck'),('tail',J['tail0'],J['tailend'],'hips')]
  for side,sgn in (('l',1),('r',-1)):
    p=legs[side];BONES+=[(f'leg_{side}_upper',Vector((p[0]*0.8,p[1]+0.02*L,0.40*H)),Vector((p[0],p[1]+0.01*L,0.17*H)),'hips'),
      (f'leg_{side}_lower',Vector((p[0],p[1]+0.01*L,0.17*H)),Vector((p[0],p[1],0.03*H)),f'leg_{side}_upper'),
      (f'leg_{side}_foot',Vector((p[0],p[1],0.03*H)),Vector((p[0],p[1]-0.09*L,0.0)),f'leg_{side}_lower'),
      (f'wing_{side}',Vector((sgn*hw*0.8,J['chest'].y,J['chest'].z+0.08*H)),Vector((sgn*hw*0.9,J['tail0'].y,J['tail0'].z+0.04*H)),'chest')]
# armature
ad=bpy.data.armatures.new(n+'_rig');arm=bpy.data.objects.new(n+'_Armature',ad);sc.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm;bpy.ops.object.mode_set(mode='EDIT')
for nm,h,t,p in BONES:
  b=ad.edit_bones.new(nm);b.head=h;b.tail=t if (t-h).length>1e-4 else h+Vector((0,0,0.01))
  d=(b.tail-b.head).normalized();z=Vector((1,0,0)).cross(d)
  if z.length<0.1: z=Vector((0,0,1))
  b.align_roll(z.normalized())
  if p: b.parent=ad.edit_bones[p];b.use_connect=False
bpy.ops.object.mode_set(mode='OBJECT')
# weights: bone heat, fallback distance
me.parent=arm
for o in bpy.data.objects:o.select_set(False)
me.select_set(True);arm.select_set(True);bpy.context.view_layer.objects.active=arm
try: bpy.ops.object.parent_set(type='ARMATURE_AUTO')
except Exception as e: print('heat failed',e)
if not me.modifiers.get('Armature'):
  m=me.modifiers.new('Armature','ARMATURE');m.object=arm
segs={nm:(np.array(h),np.array(t if (t-h).length>1e-4 else h)) for nm,h,t,p in BONES if nm!='root'}
for nm in segs:
  if nm not in me.vertex_groups: me.vertex_groups.new(name=nm)
unw=0
for v in me.data.vertices:
  tot=sum(g.weight for g in v.groups)
  if tot>1e-3: continue
  unw+=1;p=np.array(v.co);ds=[]
  for nm,(a,b) in segs.items():
    ab=b-a;t=np.clip(np.dot(p-a,ab)/max(np.dot(ab,ab),1e-9),0,1);d=np.linalg.norm(p-(a+t*ab))
    if ('_l_' in nm or nm.endswith('_l')) and p[0]<-0.02*W: d*=3
    if ('_r_' in nm or nm.endswith('_r')) and p[0]>0.02*W: d*=3
    ds.append((d,nm))
  ds.sort();w=[1/(d+1e-4)**4 for d,_ in ds[:2]];s=sum(w)
  for (d,nm),wi in zip(ds[:2],w): me.vertex_groups[nm].add([v.index],wi/s,'REPLACE')
print('UNWEIGHTED_FILLED',unw,len(me.data.vertices))
if 'root' in me.vertex_groups: me.vertex_groups.remove(me.vertex_groups['root'])
# ---- procedural clips ----
for pb in arm.pose.bones: pb.rotation_mode='XYZ'
CL={}
def mk(name,frames,fn):
  ac=bpy.data.actions.new(name);arm.animation_data_create();arm.animation_data.action=ac
  for f in range(0,frames+1,2):
    t=(f%frames)/frames
    for pb in arm.pose.bones: pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
    fn(t)
    for pb in arm.pose.bones:
      pb.keyframe_insert('rotation_euler',frame=f)
      if pb.name in('root','hips'): pb.keyframe_insert('location',frame=f)
  CL[name]=(ac,frames)
R=math.radians;S=lambda t,ph=0,k=1:math.sin(2*math.pi*(k*t+ph))
P=lambda b:arm.pose.bones.get(b)
def rot(b,x=0,y=0,z=0):
  pb=P(b)
  if pb: pb.rotation_euler=(pb.rotation_euler[0]+R(x),pb.rotation_euler[1]+R(y),pb.rotation_euler[2]+R(z))
def bob(dz):
  pb=P('root')
  if pb: pb.location=(0,0,0);pb.location[1]=dz   # root bone local Y? apply via world z below
def lift(dz):
  pb=P('root');pb.location=(0,0,0)
  # root bone points -Y (horizontal); its local Z = up (align_roll with X x d) -> local Z
  pb.location=(0,0,dz) if False else pb.location
  arm.pose.bones['root'].location=Matrix(arm.data.bones['root'].matrix_local.to_3x3()).inverted()@Vector((0,0,dz))
def tail(t,amp=15,ph=0,k=1):
  for i,b in enumerate(['tail_1','tail_2','tail_3','tail']): rot(b,z=amp*S(t,ph-0.12*i,k))
if QUAD:
  SP={'ani_cat':(40,14,0.30),'ani_dog':(30,14,0.32),'ani_horse':(44,22,0.24)}[n]   # walk frames, run frames, (unused)
  def legs(t,ph,A,K,run=False):
    for leg,off in ph.items():
      s=S(t,off);sw=max(0,S(t,off+0.25))   # swing lift when moving forward
      front=leg.startswith('front')
      rot(leg+'_upper',x=-A*s)
      rot(leg+'_lower',x=(K*sw) if front else (-K*0.7*sw))
      rot(leg+'_foot',x=(0.6*K*sw) if front else (0.5*K*sw))
  def idle(t):
    rot('chest',x=1.2*S(t,0,3));rot('neck',z=18*S(t,0,1),x=4*S(t,0.2,2));rot('head',z=8*S(t,0.1,1),x=-3*S(t,0.3,2));tail(t,10 if n!='ani_horse' else 6,0,2)
  def walk(t):
    legs(t,{'hind_leg_l':0,'front_leg_l':0.25,'hind_leg_r':0.5,'front_leg_r':0.75},22,30);lift(0.012*H*S(t,0,2))
    rot('neck',x=3*S(t,0.1,2));rot('head',x=-2*S(t,0.1,2));rot('hips',z=3*S(t,0,1));rot('chest',z=-3*S(t,0,1));tail(t,10,0,1)
  def run(t):
    legs(t,{'hind_leg_l':0,'hind_leg_r':0.08,'front_leg_l':0.5,'front_leg_r':0.58},38,55,True)
    rot('hips',x=8*S(t,0.0));rot('chest',x=-6*S(t,0.0));lift(0.05*H*max(0,S(t,0.25)));rot('neck',x=6*S(t,0.3));tail(t,8,0,1);rot('tail_1',x=-20)
  mk('idle',120,idle);mk('walk',SP[0],walk);mk('run',SP[1],run)
  if n in('ani_cat','ani_dog'):
    hh=J['hips'].z;drop=0.55*hh;dd=(J['chest']-J['hips']).length;TH=math.degrees(math.asin(min(0.9,drop/dd)))
    def sit(t):
      rot('hips',x=-TH);rot('neck',x=10+2*S(t,0,2),z=12*S(t,0,1));rot('head',x=TH*0.5,z=6*S(t,0.1,1))
      for s_ in 'lr':
        rot(f'front_leg_{s_}_upper',x=TH);rot(f'hind_leg_{s_}_upper',x=TH-75);rot(f'hind_leg_{s_}_lower',x=120);rot(f'hind_leg_{s_}_foot',x=-55)
      lift(-drop);rot('tail_1',x=TH*1.6);tail(t,14 if n=='ani_dog' else 5,0,3 if n=='ani_dog' else 1)
    mk('sit',120,sit)
  else:
    def graze(t):
      rot('neck',x=62+3*S(t,0,4));rot('head',x=18+4*S(t,0,4),z=5*S(t,0,1));rot('chest',x=4)
      rot('front_leg_l_upper',x=-4);rot('front_leg_r_upper',x=4);tail(t,10,0,2)
    mk('graze',120,graze)
else:
  SP={'ani_chicken':(20,10),'ani_duck':(24,12),'ani_pigeon':(16,8)}[n]
  def blegs(t,A,K):
    for s_,off in (('l',0),('r',0.5)):
      s=S(t,off);sw=max(0,S(t,off+0.25));rot(f'leg_{s_}_upper',x=-A*s-K*0.5*sw);rot(f'leg_{s_}_lower',x=K*sw);rot(f'leg_{s_}_foot',x=-0.8*K*sw)
  waddle=8 if n=='ani_duck' else 3
  def idle(t):
    rot('neck',z=20*S(t,0,1),x=5*S(t,0.3,3));rot('head',z=15*S(t,0.05,2));rot('hips',x=1.5*S(t,0,4));rot('tail',z=4*S(t,0,2))
  def walk(t):
    blegs(t,24,40);rot('hips',y=waddle*S(t,0,1),z=waddle*0.6*S(t,0,1));lift(0.015*H*S(t,0,2))
    rot('neck',x=14*S(t,0,2));rot('head',x=-14*S(t,0,2))
  def run(t):
    blegs(t,36,60);rot('hips',x=10,y=waddle*1.4*S(t,0,1));lift(0.03*H*max(0,S(t,0,2)));rot('neck',x=-18)
    for s_ in 'lr': rot(f'wing_{s_}',y=(1 if s_=='l' else -1)*(-18-10*S(t,0,2)))
  def peck(t):
    k=min(1,max(0,math.sin(math.pi*min(1,t*2.2))))
    d=k if n!='ani_duck' else 0.7*k
    rot('hips',x=25*d);rot('chest',x=15*d);rot('neck',x=40*d+6*S(t,0,6)*d);rot('head',x=20*d,z=10*S(t,0,1)*(1-d));rot('tail',x=-15*d)
  mk('idle',90,idle);mk('walk',SP[0],walk);mk('run',SP[1],run);mk('peck',48,peck)
  if n=='ani_pigeon':
    def fly(t):
      for s_ in 'lr': rot(f'wing_{s_}',y=(1 if s_=='l' else -1)*(-50-45*S(t,0)));
      rot('hips',x=-8);lift(0.6*H+0.04*H*S(t,0.25));rot('tail',x=-10)
      for s_ in 'lr': rot(f'leg_{s_}_upper',x=40);rot(f'leg_{s_}_lower',x=-60)
    mk('fly',12,fly)
arm.animation_data.action=None
for pb in arm.pose.bones: pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
for nm,(ac,fr) in CL.items():
  t=arm.animation_data.nla_tracks.new();t.name=nm;st=t.strips.new(nm,0,ac);ac.use_fake_user=True
# walk speed: planted foot
def speed(nm):
  ac,fr=CL[nm];arm.animation_data.action=ac;feet=[b.name for b in arm.pose.bones if b.name.endswith('_foot')];P_={f:[] for f in feet}
  for t in arm.animation_data.nla_tracks: t.mute=True
  for f in range(0,fr+1):
    sc.frame_set(f)
    for b in feet: P_[b].append(arm.matrix_world@arm.pose.bones[b].tail)
  v=[]
  for b,ps in P_.items():
    z=np.array([p.z for p in ps]);zm=z.min()
    for i in range(1,len(ps)):
      if z[i]<zm+0.02*H and z[i-1]<zm+0.02*H: v.append(abs(ps[i].y-ps[i-1].y)*30)
  for t in arm.animation_data.nla_tracks: t.mute=False
  arm.animation_data.action=None
  return round(float(np.median(v)),3) if v else None
info={'H':float(H),'L':float(L),'bones':[b[0] for b in BONES],'clips':{k:v[1] for k,v in CL.items()},'speed_mps':{k:speed(k) for k in CL if k in('walk','run')},'tris':{'LOD0':sum(len(p.vertices)-2 for p in me.data.polygons)}}
bpy.ops.wm.save_as_mainfile(filepath=D+f'raw/{n}_work.blend')
def sel():
  bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);me.select_set(True);bpy.context.view_layer.objects.active=me
def tex(sz):
  for i in bpy.data.images:
    if i.size[0]>sz: i.scale(sz,sz)
O=D+'3d/';nm=n.replace('ani_','')
tex(1024);sel()
bpy.ops.export_scene.gltf(filepath=O+f'ani_{nm}_LOD0.glb',use_selection=True,export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_image_format='WEBP',export_image_quality=80,export_skins=True,export_force_sampling=True)
for lod,r,sz in [('LOD1',0.5,512),('LOD2',0.2,256)]:
  m=me.modifiers.new('Dec','DECIMATE');m.ratio=r;bpy.context.view_layer.objects.active=me
  while me.modifiers[0].name!='Dec': bpy.ops.object.modifier_move_up(modifier='Dec')
  dg=bpy.context.evaluated_depsgraph_get();ev=me.evaluated_get(dg);ev.data.calc_loop_triangles();info['tris'][lod]=len(ev.data.loop_triangles)
  tex(sz);sel()
  bpy.ops.export_scene.gltf(filepath=O+f'ani_{nm}_{lod}.glb',use_selection=True,export_format='GLB',export_animations=False,export_image_format='WEBP',export_image_quality=80,export_apply=True,export_skins=True)
  me.modifiers.remove(m)
json.dump(info,open(D+f'raw/{n}_build.json','w'),indent=1)
print('DONE',n,info['clips'],info['speed_mps'],info['tris'])
