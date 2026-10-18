import bpy,math
from mathutils import Vector
D='/workspace/crosshaven_paint/work/3d_cities/crosshaven/npcs/'
bpy.ops.wm.read_factory_settings(use_empty=True);sc=bpy.context.scene
bpy.ops.import_scene.gltf(filepath=D+'3d/chr_guard_LOD0.glb')
for o in list(bpy.data.objects):
  if o.name.startswith('Icosphere'): bpy.data.objects.remove(o)
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0];me=[o for o in bpy.data.objects if o.type=='MESH'][0]
for t in arm.animation_data.nla_tracks: t.mute=True
if me.data.shape_keys.animation_data:
  for t in me.data.shape_keys.animation_data.nla_tracks: t.mute=True
  me.data.shape_keys.animation_data.action=None
sc.render.engine='CYCLES';sc.cycles.samples=16;sc.cycles.device='CPU';sc.render.resolution_x=360;sc.render.resolution_y=360
w=bpy.data.worlds.new('w');sc.world=w;w.use_nodes=True;w.node_tree.nodes['Background'].inputs[1].default_value=1.0
L=bpy.data.objects.new('L',bpy.data.lights.new('L','SUN'));L.data.energy=4;L.rotation_euler=(0.9,0,-0.4);sc.collection.objects.link(L)
c=bpy.data.objects.new('c',bpy.data.cameras.new('c'));sc.collection.objects.link(c);sc.camera=c;c.data.type='ORTHO';c.data.ortho_scale=0.4
for i,(clip,f,val) in enumerate([('talk',60,0.0),('interact',90,0.0),('idle_spear',60,1.0)]):
  arm.animation_data.action=[a for a in bpy.data.actions if a.name.startswith(clip+'_')][0];sc.frame_set(f)
  me.data.shape_keys.key_blocks['fist'].value=val;bpy.context.view_layer.update()
  hp=arm.matrix_world@arm.pose.bones['RightHand'].head;th=math.radians(-40);dv=Vector((-math.sin(th),math.cos(th),0))
  c.location=hp-dv*3;c.rotation_euler=(math.radians(90),0,th)
  sc.render.filepath=D+f'raw/check/hc_{i}_{clip}.png';bpy.ops.render.render(write_still=True)
