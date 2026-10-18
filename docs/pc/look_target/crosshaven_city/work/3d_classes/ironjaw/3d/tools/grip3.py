import bpy,numpy as np,math,json,sys,os
from mathutils import Matrix,Vector,Quaternion
sys.path.insert(0,'/workspace/crosshaven_paint/work/3d_classes/ironjaw/3d/tools');from clips import CL
D='/workspace/crosshaven_paint/work/3d_classes/ironjaw/3d/';G='/workspace/ironjaw_grip/'
MODE=sys.argv[-1]
P=json.loads(os.environ.get('GP','{}'))
BETA=math.radians(P.get('beta',30));YK=P.get('yk',12.0);R_HAFT=3.1;MAXA=math.radians(270)
GAM=math.radians(P.get('gam',80));GS=P.get('gsign',1);WRIST=P.get('wrist',1)
CARRY=['idle','walk','run','turn_r','hit','dodge','ironjaw_jump','downed','death']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=G+'before/chr_ironjaw_male_LOD0.glb')
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0];me=[o for o in bpy.data.objects if o.type=='MESH' and len(o.data.vertices)>1000][0]
for o in list(bpy.data.objects):
  if o.name.startswith('Icosphere'): bpy.data.objects.remove(o)
def rot(v,axis,a): return Matrix.Rotation(a,3,axis)@v
info={}
n=Vector((0,0,-1));y=Vector((0,1,0));t0=n.cross(y)
for hb,sg in [('RightHand',-1),('LeftHand',1)]:
  h=(t0*sg*math.cos(BETA)+y*math.sin(BETA)).normalized()     # head direction (thumb side, tilted to fingers)
  yp=(-sg*n.cross(h)).normalized()                              # tilted finger axis
  gi=me.vertex_groups[hb].index;b=arm.data.bones[hb]
  M=(arm.matrix_world@b.matrix_local).inverted()@me.matrix_world;Mi=M.inverted()
  vs=[];ws=[]
  for v in me.data.vertices:
    w=max([g.weight for g in v.groups if g.group==gi],default=0)
    if w>0.3: vs.append(v);ws.append(w)
  Pts=[M@v.co for v in vs]
  dn=np.array([p.dot(n) for p in Pts]);yy=np.array([p.y for p in Pts]);tt=np.array([p.dot(t0) for p in Pts])
  YK=P.get('yk_'+hb[0],P.get('yk',12.0))
  d_palm=np.percentile(dn[(yy>YK-5)&(yy<YK)],85);Cn=d_palm+R_HAFT*0.6;tc=(tt.min()+tt.max())/2;hw=(tt.max()-tt.min())/2
  C=n*Cn+y*YK+t0*tc
  for v,w,p,d in zip(vs,ws,Pts,dn):
    r=p-C;s=r.dot(yp);a_h=r.dot(h)
    thumb=(sg*(p.dot(t0)-tc)>(0.4 if hb=='RightHand' else 0.62)*hw) and (6<p.y<19) and s<=1.0
    if s>0 and not thumb:
      rho=max(R_HAFT,Cn-d);phi=min(MAXA,s/rho)
      tgt=C+h*a_h+yp*(rho*math.sin(phi))-n*(rho*math.cos(phi))
    elif thumb:
      ramp=min(1,max(0,(p.y-6)/13));g=GS*GAM*ramp
      rr=r-h*a_h; rr=Matrix.Rotation(g,3,h)@rr
      # keep thumb outside haft radius
      if rr.length<R_HAFT+0.8: rr=rr.normalized()*(R_HAFT+0.8)
      tgt=C+h*a_h+rr
    else: continue
    v.co=Mi@(p.lerp(tgt,min(1.0,w)))
  # axe: axeZ(head)->h, axeX(blades)->yp, axeY->h x yp ... ensure right-handed: X=yp,Z=h,Y=Z x X
  X=yp;Z=h;Y=Z.cross(X)
  Rm=Matrix((X,Y,Z)).transposed()
  T=Matrix.Translation(C)@Rm.to_4x4()@Matrix.Scale(1/arm.scale.x,4)
  info[hb]={'bone_local_T':[list(r) for r in T],'centre_cm':list(C),'head_dir':list(h)}
# wrist cock for carry clips: solve omega from idle so head points down
sc=bpy.context.scene;arm.animation_data_create()
for tr in arm.animation_data.nla_tracks: tr.mute=True
def act(nm): return [x for x in bpy.data.actions if x.name==nm or x.name.startswith(nm+'_')][0]
om={}
ac=act('idle');arm.animation_data.action=ac;s0,e0=ac.frame_range
for hb in ['RightHand','LeftHand']:
  h=Vector(info[hb]['head_dir']);acc=Vector((0,0,0))
  for f in np.linspace(s0,e0,8):
    sc.frame_set(int(f));R=(arm.matrix_world@arm.pose.bones[hb].matrix).to_3x3().normalized();acc+=R.inverted()@Vector((0,0,-1))
  dd=acc.normalized();dp=dd-n*dd.dot(n);dp.normalize()
  ang=math.atan2(h.cross(dp).dot(n),h.dot(dp));om[hb]=ang*WRIST
print('OMEGA',{k:round(math.degrees(v),1) for k,v in om.items()})
for nm in CARRY:
  ac=act(nm)
  for hb in ['RightHand','LeftHand']:
    q_off=Quaternion(n,om[hb])
    fcs=[ac.fcurves.find(f'pose.bones["{hb}"].rotation_quaternion',index=i) for i in range(4)]
    if None in fcs: print('nofc',nm,hb);continue
    for k in range(len(fcs[0].keyframe_points)):
      q=Quaternion([fcs[i].keyframe_points[k].co[1] for i in range(4)]);q2=q@q_off
      for i in range(4):
        kp=fcs[i].keyframe_points[k];kp.co[1]=q2[i];kp.handle_left[1]=q2[i];kp.handle_right[1]=q2[i]
info['omega_deg']={k:math.degrees(v) for k,v in om.items()};info['carry_clips']=CARRY
json.dump(info,open(G+'grip_info.json','w'))
arm.animation_data.action=None
def sel():
  bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);me.select_set(True);bpy.context.view_layer.objects.active=arm
if MODE=='export':
  sel();bpy.ops.export_scene.gltf(filepath=D+'chr_ironjaw_male_LOD0.glb',use_selection=True,export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_image_format='WEBP',export_image_quality=80,export_skins=True,export_force_sampling=True)
  for lod,r,sz in [('LOD1',0.5,1024),('LOD2',0.2,512)]:
    for i in bpy.data.images:
      if i.size[0]>sz:i.scale(sz,sz)
    m=me.modifiers.new('Dec','DECIMATE');m.ratio=r;bpy.context.view_layer.objects.active=me
    while me.modifiers[0].name!='Dec': bpy.ops.object.modifier_move_up(modifier='Dec')
    sel();bpy.ops.export_scene.gltf(filepath=D+f'chr_ironjaw_male_{lod}.glb',use_selection=True,export_format='GLB',export_animations=False,export_image_format='WEBP',export_image_quality=80,export_apply=True,export_skins=True)
    me.modifiers.remove(m)
else:
  sel();bpy.ops.export_scene.gltf(filepath=G+'test_LOD0.glb',use_selection=True,export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_image_format='WEBP',export_skins=True)
