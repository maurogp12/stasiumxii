import bpy,numpy as np,math,json,sys,os
from mathutils import Matrix,Vector
D='/workspace/crosshaven_paint/work/3d_classes/ironjaw/3d/';G='/workspace/ironjaw_grip/'
MODE=sys.argv[-1]
CFG=json.loads(os.environ.get('GCFG','{"RightHand":[0,0,-1],"LeftHand":[0,0,-1]}'))
YK=float(os.environ.get('YK','12'));R_HAFT=3.1;MAXA=math.radians(260)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=G+'before/chr_ironjaw_male_LOD0.glb')
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0];me=[o for o in bpy.data.objects if o.type=='MESH' and len(o.data.vertices)>1000][0]
for o in list(bpy.data.objects):
  if o.name.startswith('Icosphere'): bpy.data.objects.remove(o)
info={}
for hb,nv in CFG.items():
  nvec=Vector(nv);yv=Vector((0,1,0));tvec=nvec.cross(yv)   # haft axis
  gi=me.vertex_groups[hb].index;b=arm.data.bones[hb]
  M=(arm.matrix_world@b.matrix_local).inverted()@me.matrix_world;Mi=M.inverted()
  vs=[];ws=[]
  for v in me.data.vertices:
    w=max([g.weight for g in v.groups if g.group==gi],default=0)
    if w>0.3: vs.append(v);ws.append(w)
  P=[M@v.co for v in vs]
  dn=np.array([p.dot(nvec) for p in P]);yy=np.array([p.y for p in P]);tt=np.array([p.dot(tvec) for p in P])
  palm=dn[(yy>YK-5)&(yy<YK)];d_palm=np.percentile(palm,85)
  Cn=d_palm+R_HAFT*0.6;tc=(tt.min()+tt.max())/2
  # cross-axis (the third coordinate) stays
  mx=0
  for v,w,p,d in zip(vs,ws,P,dn):
    if p.y<=YK: continue
    s=p.y-YK;rho=max(R_HAFT,Cn-d);phi=min(MAXA,s/rho);mx=max(mx,phi)
    t=p.dot(tvec)
    ny=YK+rho*math.sin(phi);nn=Cn-rho*math.cos(phi)
    tgt=nvec*nn+yv*ny+tvec*t
    v.co=Mi@(p.lerp(tgt,min(1.0,w)))
  centre=nvec*Cn+yv*(YK)+tvec*tc
  # axe: haft(axeZ)->tvec, blades(axeX)->yv, axeY-> tvec x yv
  FL={'RightHand':-1.0,'LeftHand':1.0}[hb];Rm=Matrix((yv*FL,tvec.cross(yv),tvec*FL)).transposed()
  T=Matrix.Translation(centre)@Rm.to_4x4()@Matrix.Scale(1/arm.scale.x,4)
  info[hb]={'bone_local_T':[list(r) for r in T],'centre_cm':list(centre),'nvec':nv}
  print('ST',hb,'d_palm',round(d_palm,2),'phi max',round(mx,2))
json.dump(info,open(G+'grip_info.json','w'))
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
