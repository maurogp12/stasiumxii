import bpy,mathutils,json
D='/workspace/crosshaven_paint/work/3d_classes/ironjaw/3d/'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=D+'axe_tex.glb')
ms=[o for o in bpy.data.objects if o.type=='MESH'];o=ms[0]
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=o
if len(ms)>1: bpy.ops.object.join()
for p in [x for x in bpy.data.objects if x.type!='MESH']: bpy.data.objects.remove(p)
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
vs=[v.co for v in o.data.vertices];mn=[min(v[i] for v in vs) for i in range(3)];mx=[max(v[i] for v in vs) for i in range(3)]
print('dims',[mx[i]-mn[i] for i in range(3)])
s=0.65/(mx[2]-mn[2])
gz=mn[2]+0.22*(mx[2]-mn[2])  # grip 22% up the haft
for v in o.data.vertices: v.co=mathutils.Vector(((v.co.x-(mn[0]+mx[0])/2)*s,(v.co.y-(mn[1]+mx[1])/2)*s,(v.co.z-gz)*s))
o.name='itm_ironjaw_axe';tris=sum(len(p.vertices)-2 for p in o.data.polygons)
dec=o.modifiers.new('d','DECIMATE');dec.ratio=min(1,3000/tris)
for i in bpy.data.images:
  if i.size[0]>1024:i.scale(1024,1024)
print('imgs',[(i.name,i.size[:]) for i in bpy.data.images],'tris',tris)
for side in ['R','L']:
  o.name=f'itm_ironjaw_axe_{side}'
  bpy.ops.export_scene.gltf(filepath=D+f'itm_ironjaw_axe_{side}_CONCEPTO_.glb',export_format='GLB',export_image_format='WEBP',export_image_quality=80,export_apply=True)
json.dump({'src_tris':tris,'export_tris':int(min(tris,3000)),'length_m':0.65},open(D+'axe_info.json','w'))
