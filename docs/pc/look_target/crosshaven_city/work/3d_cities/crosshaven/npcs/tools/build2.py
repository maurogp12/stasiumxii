import bpy,json,re,os,sys,math,numpy as np
from mathutils import Matrix,Vector,Quaternion
n=sys.argv[-1]; D='/workspace/crosshaven_paint/work/3d_cities/crosshaven/npcs/'
CN=['idle','walk','interact','sit','talk']
ids=json.load(open(D+'tools/clips.json'))[n]
L=json.load(open('/workspace/lib.json'));key={a['action_id']:a['key'] for a in L}
want={key[i]:c for i,c in zip(ids,CN)}
bpy.ops.wm.read_factory_settings(use_empty=True); sc=bpy.context.scene; sc.render.fps=30
def imp(f):
  b=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=f); return [o for o in bpy.data.objects if o not in b]
main=imp(D+f'raw/meshy/{n}_anim.glb')
for o in main:
  if o.name.startswith('Icosphere'): bpy.data.objects.remove(o)
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]; mesh=[o for o in bpy.data.objects if o.type=='MESH'][0]
# 1. full PBR material from the rigged glb (same mesh/UVs)
rg=imp(D+f'raw/meshy/{n}_rigged.glb')
rm=[o for o in rg if o.type=='MESH' and len(o.data.polygons)>1000][0]
assert len(rm.data.vertices)==len(mesh.data.vertices)
mesh.data.materials.clear(); mesh.data.materials.append(rm.data.materials[0])
for o in rg: bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
  if a.users==0 and not any(k in a.name for k in want): pass
if n=='guard': x=imp(D+'raw/meshy/guard_anim_x.glb'); [bpy.data.objects.remove(o) for o in x]
arm.name=f'{n}_Armature'; mesh.name=f'chr_{n}'
BM={'Spine02':'Spine','Spine01':'Chest','Spine':'UpperChest','neck':'Neck','head_end':'HeadTop_End','headfront':'HeadFront','LeftArm':'LeftUpperArm','LeftForeArm':'LeftLowerArm','RightArm':'RightUpperArm','RightForeArm':'RightLowerArm','LeftUpLeg':'LeftUpperLeg','LeftLeg':'LeftLowerLeg','LeftToeBase':'LeftToes','RightUpLeg':'RightUpperLeg','RightLeg':'RightLowerLeg','RightToeBase':'RightToes'}
for b in arm.data.bones:
  if b.name in BM: b.name='TMP_'+BM[b.name]
for b in arm.data.bones:
  if b.name.startswith('TMP_'): b.name=b.name[4:]
for vg in mesh.vertex_groups:
  if vg.name.startswith('TMP_'): vg.name=vg.name[4:]
acts={}
for ac in list(bpy.data.actions):
  base=re.sub(r'\.\d+$','',ac.name.replace('_Armature',''))
  c='walk_spear' if 'Spear_Walk' in ac.name else want.get(base)
  if not c or c in acts: bpy.data.actions.remove(ac); continue
  ac.name=c; acts[c]=ac
  for fc in ac.fcurves:
    m=re.match(r'pose\.bones\["(.+?)"\]',fc.data_path)
    if m and m.group(1) in BM: fc.data_path=fc.data_path.replace(f'["{m.group(1)}"]',f'["{BM[m.group(1)]}"]')
    if fc.data_path=='pose.bones["Hips"].location' and fc.array_index in (0,2):
      v=fc.keyframe_points[0].co[1]
      for k in fc.keyframe_points: k.co[1]=v;k.handle_left[1]=v;k.handle_right[1]=v
    for k in fc.keyframe_points:
      for p in (k.co,k.handle_left,k.handle_right): p[0]*=30/24
if 'walk_spear' in acts:  # starts at 0.8*1.25: shift to 0
  for fc in acts['walk_spear'].fcurves:
    s=acts['walk_spear'].frame_range[0]
  s=min(k.co[0] for fc in acts['walk_spear'].fcurves for k in fc.keyframe_points)
  for fc in acts['walk_spear'].fcurves:
    for k in fc.keyframe_points:
      for p in (k.co,k.handle_left,k.handle_right): p[0]-=s
def qscale(ac,bones,f):
  for b in bones:
    fcs=[ac.fcurves.find(f'pose.bones["{b}"].rotation_quaternion',index=i) for i in range(4)]
    if None in fcs: continue
    Q=[Quaternion([fcs[i].keyframe_points[k].co[1] for i in range(4)]) for k in range(len(fcs[0].keyframe_points))]
    A=np.array([list(q) for q in Q]);A[(A@A[0])<0]*=-1;mv=A.mean(0);mv/=np.linalg.norm(mv);qm=Quaternion(mv.tolist())
    for k,q in enumerate(Q):
      if sum(a*b for a,b in zip(q,qm))<0: q=Quaternion([-x for x in q])
      d=qm.inverted()@q
      if d.w<0: d=Quaternion([-x for x in d])
      ax,an=d.to_axis_angle(); q2=qm@Quaternion(ax,an*f)
      for i in range(4): kp=fcs[i].keyframe_points[k];kp.co[1]=q2[i];kp.handle_left[1]=q2[i];kp.handle_right[1]=q2[i]
def tscale(ac,f):
  for fc in ac.fcurves:
    for k in fc.keyframe_points:
      for p in (k.co,k.handle_left,k.handle_right): p[0]*=f
info={}
# 3. child: shorter stride + quicker cadence (walk), quicker idle
if n=='child':
  qscale(acts['walk'],['LeftUpperLeg','RightUpperLeg','LeftLowerLeg','RightLowerLeg','LeftFoot','RightFoot'],float(os.environ.get('LEGF','0.8')))
  qscale(acts['walk'],['LeftUpperArm','RightUpperArm','LeftLowerArm','RightLowerArm'],0.85)
  fc=acts['walk'].fcurves.find('pose.bones["Hips"].location',index=1)
  if fc:
    vals=[k.co[1] for k in fc.keyframe_points];mu=sum(vals)/len(vals)
    for k in fc.keyframe_points: k.co[1]=mu+(k.co[1]-mu)*0.8;k.handle_left[1]=k.co[1];k.handle_right[1]=k.co[1]
  tscale(acts['walk'],1/1.15); tscale(acts['idle'],1/1.15)
  info['child_edit']='walk: leg swing x0.8, arm swing x0.85, hip bob x0.8, cadence x1.15; idle cadence x1.15'
if not arm.animation_data: arm.animation_data_create()
for t in list(arm.animation_data.nla_tracks): arm.animation_data.nla_tracks.remove(t)
arm.animation_data.action=None
def setact(a):
  arm.animation_data.action=a
# 2. guard: fist + idle_spear
if n=='guard':
  exec(open(D+'tools/guard_spear.py').read())
# walk speed (planted foot)
def speed(ac):
  setact(ac);s,e=ac.frame_range;P={'LeftFoot':[],'RightFoot':[]}
  for f in range(int(s),int(e)+1):
    sc.frame_set(f)
    for b in P: P[b].append(arm.matrix_world@arm.pose.bones[b].head)
  v=[]
  for b,ps in P.items():
    z=np.array([p.z for p in ps]);zm=z.min()
    for i in range(1,len(ps)):
      if z[i]<zm+0.015 and z[i-1]<zm+0.015: v.append((ps[i]-ps[i-1]).xy.length*30)
  return round(float(np.median(v)),3) if v else None
info['walk_speed_mps']={c:speed(acts[c]) for c in acts if c.startswith('walk')}
arm.animation_data.action=None
ORDER=CN+[c for c in acts if c not in CN]
for c in ORDER:
  if c in acts: t=arm.animation_data.nla_tracks.new(); t.name=c; t.strips.new(c,0,acts[c]); acts[c].use_fake_user=True
info['clips']={c:[0,round(acts[c].frame_range[1],1)] for c in ORDER if c in acts}
if mesh.data.shape_keys:
  FC={'idle_spear','walk_spear'};skd=mesh.data.shape_keys;skd.animation_data_create();info['fist_clips']=sorted(FC)
  for c in ORDER:
    if c not in acts: continue
    a=bpy.data.actions.new(c+'_hand');val=1.0 if c in FC else 0.0;e=acts[c].frame_range[1]
    skd.animation_data.action=a;kb=skd.key_blocks['fist'];kb.value=val;kb.keyframe_insert('value',frame=0);kb.keyframe_insert('value',frame=e)
    skd.animation_data.action=None;t=skd.animation_data.nla_tracks.new();t.name=c;t.strips.new(c,0,a);a.use_fake_user=True
def sel():
  bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); mesh.select_set(True); bpy.context.view_layer.objects.active=mesh
def tex(sz):
  for i in bpy.data.images:
    if i.size[0]>sz: i.scale(sz,sz)
O=D+'3d/'
info['tris']={'LOD0':sum(len(p.vertices)-2 for p in mesh.data.polygons)}
info['images']=[i.name for i in bpy.data.images]
tex(2048); bpy.ops.wm.save_as_mainfile(filepath=D+f'raw/meshy/{n}_work2.blend'); sel()
bpy.ops.export_scene.gltf(filepath=O+f'chr_{n}_LOD0.glb',use_selection=True,export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_image_format='WEBP',export_image_quality=80,export_skins=True,export_force_sampling=True)
if mesh.data.shape_keys:
  mesh.data.shape_keys.animation_data_clear();mesh.data.shape_keys.key_blocks['fist'].value=1.0
  bpy.context.view_layer.objects.active=mesh;bpy.ops.object.shape_key_remove(all=True,apply_mix=True)
for lod,r,sz in [('LOD1',0.5,1024),('LOD2',0.2,512)]:
  m=mesh.modifiers.new('Dec','DECIMATE'); m.ratio=r
  bpy.context.view_layer.objects.active=mesh
  while mesh.modifiers[0].name!='Dec': bpy.ops.object.modifier_move_up(modifier='Dec')
  dg=bpy.context.evaluated_depsgraph_get(); ev=mesh.evaluated_get(dg); ev.data.calc_loop_triangles(); info['tris'][lod]=len(ev.data.loop_triangles)
  tex(sz); sel()
  bpy.ops.export_scene.gltf(filepath=O+f'chr_{n}_{lod}.glb',use_selection=True,export_format='GLB',export_animations=False,export_image_format='WEBP',export_image_quality=80,export_apply=True,export_skins=True)
  mesh.modifiers.remove(m)
json.dump(info,open(D+f'raw/meshy/{n}_build2.json','w'),indent=1)
print('DONE',n,info['walk_speed_mps'],info['tris'])
