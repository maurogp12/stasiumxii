import bpy,json,mathutils,os
import sys;sys.path.insert(0,"/workspace/crosshaven_paint/work/3d_classes/ironjaw/3d")
from clips import CL
L=json.load(open('/workspace/lib.json'));key={a['action_id']:a['key'] for a in L}
want={key[i]:n for n,i in CL}
bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene;sc.render.fps=30
for f in ['anim_b0.glb','anim_b1.glb','anim_b2.glb']:
  before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=f)
  new=set(bpy.data.objects)-before
  if f!='anim_b0.glb':
    for o in new: bpy.data.objects.remove(o)
for o in list(bpy.data.objects):
  if o.type=='MESH' and o.name.startswith('Icosphere'): bpy.data.objects.remove(o)
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0];mesh=[o for o in bpy.data.objects if o.type=='MESH'][0]
arm.name='Ironjaw_Armature';mesh.name='chr_ironjaw_male'
BM={'Spine02':'Spine','Spine01':'Chest','Spine':'UpperChest','neck':'Neck','head_end':'HeadTop_End','headfront':'HeadFront',
'LeftArm':'LeftUpperArm','LeftForeArm':'LeftLowerArm','RightArm':'RightUpperArm','RightForeArm':'RightLowerArm',
'LeftUpLeg':'LeftUpperLeg','LeftLeg':'LeftLowerLeg','LeftToeBase':'LeftToes','RightUpLeg':'RightUpperLeg','RightLeg':'RightLowerLeg','RightToeBase':'RightToes'}
# rename via temp names to avoid collisions (Spine)
for b in arm.data.bones:
  if b.name in BM: b.name='TMP_'+BM[b.name]
for b in arm.data.bones:
  if b.name.startswith('TMP_'): b.name=b.name[4:]
for vg in mesh.vertex_groups:
  if vg.name.startswith('TMP_'): vg.name=vg.name[4:]
import re
acts={}
for ac in list(bpy.data.actions):
  base=ac.name.replace('_Armature','');base=re.sub(r'\.\d+$','',base)
  n=want.get(base)
  if not n or n in acts: bpy.data.actions.remove(ac);continue
  ac.name=n;acts[n]=ac
  for fc in ac.fcurves:
    m=re.match(r'pose\.bones\["(.+?)"\]',fc.data_path)
    if m and m.group(1) in BM: fc.data_path=fc.data_path.replace(f'["{m.group(1)}"]',f'["{BM[m.group(1)]}"]')
  # in place: flatten Hips horizontal (local X,Z) except climb
  for fc in ac.fcurves:
    if fc.data_path=='pose.bones["Hips"].location' and fc.array_index in (0,2) and n not in ('ironjaw_climb',):
      v=fc.keyframe_points[0].co[1]
      for k in fc.keyframe_points: k.co[1]=v;k.handle_left[1]=v;k.handle_right[1]=v
  # 24->30 fps retime
  for fc in ac.fcurves:
    for k in fc.keyframe_points:
      for p in (k.co,k.handle_left,k.handle_right): p[0]*=30/24
print('clips',sorted(acts),len(acts));missing=[n for n,_ in CL if n not in acts];print('missing',missing)
h=1.8;s=1.0
info={'height_m':round(h*s,3),'raw_height':h,'scale':s,'bbox_after':None}
for t in list(arm.animation_data.nla_tracks): arm.animation_data.nla_tracks.remove(t)
for n,_ in CL:
  if n in acts:
    t=arm.animation_data.nla_tracks.new();t.name=n;st=t.strips.new(n,0,acts[n]);acts[n].use_fake_user=True
json.dump({'clips':{n:[acts[n].frame_range[0],acts[n].frame_range[1]] for n in acts},'info':info,'tris':len(mesh.data.polygons)},open('build_info.json','w'),indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath('work_char.blend'))
