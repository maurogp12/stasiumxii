import bpy,os,sys,json,math,mathutils
D='/workspace/crosshaven_paint/work/3d_classes/ironjaw/3d/'
bpy.ops.wm.open_mainfile(filepath=D+'work_char.blend')
arm=bpy.data.objects['Ironjaw_Armature'];mesh=bpy.data.objects['chr_ironjaw_male']
print('imgs',[(i.name,i.size[:]) for i in bpy.data.images])
def sel(objs):
  bpy.ops.object.select_all(action='DESELECT')
  for o in objs:o.select_set(True)
  bpy.context.view_layer.objects.active=objs[0]
def tex(sz):
  for i in bpy.data.images:
    if i.size[0]>sz: i.scale(sz,sz)
def exp(fn,anim):
  sel([arm,mesh])
  bpy.ops.export_scene.gltf(filepath=D+fn,use_selection=True,export_format='GLB',export_animations=anim,export_animation_mode='NLA_TRACKS' if anim else 'ACTIONS',export_image_format='WEBP',export_image_quality=80,export_yup=True,export_apply=False,export_skins=True,export_force_sampling=True)
tex(2048);exp('chr_ironjaw_male_LOD0.glb',True)
tris={}
tris['LOD0']=sum(len(p.vertices)-2 for p in mesh.data.polygons)
for lod,r,sz in [('LOD1',0.5,1024),('LOD2',0.2,512)]:
  m=mesh.modifiers.get('Dec') or mesh.modifiers.new('Dec','DECIMATE');m.ratio=r
  # keep armature modifier last
  bpy.context.view_layer.objects.active=mesh
  while mesh.modifiers[0].name!='Dec': bpy.ops.object.modifier_move_up(modifier='Dec')
  tex(sz)
  dg=bpy.context.evaluated_depsgraph_get();tris[lod]=len(mesh.evaluated_get(dg).data.loop_triangles) if False else None
  bpy.ops.object.modifier_apply(modifier='Dec') if False else None
  sel([arm,mesh]);bpy.ops.export_scene.gltf(filepath=D+f'chr_ironjaw_male_{lod}.glb',use_selection=True,export_format='GLB',export_animations=False,export_image_format='WEBP',export_image_quality=80,export_apply=True,export_skins=True)
  m.ratio=1;mesh.modifiers.remove(m)
json.dump(tris,open(D+'tris.json','w'))
