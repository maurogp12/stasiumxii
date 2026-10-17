import bpy,sys,math,mathutils,json
D='/workspace/crosshaven_paint/work/3d_classes/ironjaw/3d/'
args=sys.argv[sys.argv.index('--')+1:];ROT=[float(x) for x in args[0].split(',')];clips=args[1].split(',');nf=int(args[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=D+'chr_ironjaw_male_LOD0.glb')
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
for o in bpy.data.objects:
  if o.type=='MESH':print('MB',[tuple(round(c,2) for c in o.matrix_world@__import__('mathutils').Vector(b)) for b in o.bound_box][::6])
for side,bone in [('R','RightHand'),('L','LeftHand')]:
  b=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=D+f'itm_ironjaw_axe_{side}_CONCEPTO_.glb')
  ax=[o for o in set(bpy.data.objects)-b if o.type=='MESH'][0]
  c=ax.constraints.new('CHILD_OF');c.target=arm;c.subtarget=bone;c.use_scale_x=c.use_scale_y=c.use_scale_z=False;c.set_inverse_pending=False;c.inverse_matrix.identity()
  OFF=[float(x) for x in args[4].split(',')] if len(args)>4 else [0,0.08,0]
  ax.rotation_mode='XYZ';ax.location=OFF;ax.rotation_euler=[math.radians(r) for r in ROT]
for o in bpy.data.objects:
  if o.name.startswith('Icosphere'): o.hide_render=True
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=12;sc.cycles.use_denoising=False
l=bpy.data.objects.new('sun',bpy.data.lights.new('sun','SUN'));l.data.energy=4;l.rotation_euler=(0.8,0.2,0.4);sc.collection.objects.link(l)
sc.render.resolution_x=sc.render.resolution_y=320;sc.render.film_transparent=False
w=bpy.data.worlds.new('w');sc.world=w;w.use_nodes=True;w.node_tree.nodes['Background'].inputs[0].default_value=(0.6,0.6,0.6,1);w.node_tree.nodes['Background'].inputs[1].default_value=1.2
cam=bpy.data.objects.new('cam',bpy.data.cameras.new('cam'));sc.collection.objects.link(cam);sc.camera=cam
cam.data.type='ORTHO';cam.data.ortho_scale=2.6
ang=float(args[3]) if len(args)>3 else 25
r=6;a=math.radians(ang);cam.location=(r*math.sin(a),-r*math.cos(a),1.1);cam.rotation_euler=(math.radians(90),0,a)
exec(open(D+"dbg3.py").read())
def act(n): return [x for x in bpy.data.actions if x.name==n or x.name.startswith(n+'_')][0]
if arm.animation_data:
  for t in arm.animation_data.nla_tracks: t.mute=True
else: arm.animation_data_create()
for n in clips:
  if n=='rest':
    arm.animation_data.action=None
    for pb in arm.pose.bones: pb.matrix_basis.identity()
    fr=[1]
  else:
    ac=act(n);arm.animation_data.action=ac;s,e=ac.frame_range
    fr=[s+(e-s)*i/(nf-1) for i in range(nf)] if nf>1 else [s]
  for i,f in enumerate(fr):
    sc.frame_set(int(f));sc.render.filepath=D+f'previews/_f/{n}_{i}.png';bpy.ops.render.render(write_still=True)
