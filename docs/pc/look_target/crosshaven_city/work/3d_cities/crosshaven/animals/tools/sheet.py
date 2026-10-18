import bpy,sys,math,json
n=sys.argv[-1];D='/workspace/crosshaven_paint/work/3d_cities/crosshaven/animals/'
bpy.ops.wm.open_mainfile(filepath=D+f'raw/{n}_work.blend')
info=json.load(open(D+f'raw/{n}_build.json'))
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=10;sc.cycles.device='CPU';sc.render.resolution_x=300;sc.render.resolution_y=240
w=bpy.data.worlds.new('w');sc.world=w;w.use_nodes=True;w.node_tree.nodes['Background'].inputs[1].default_value=1.0
L=bpy.data.objects.new('L',bpy.data.lights.new('L','SUN'));L.data.energy=4;L.rotation_euler=(0.9,0,-0.4);sc.collection.objects.link(L)
c=bpy.data.objects.new('c',bpy.data.cameras.new('c'));sc.collection.objects.link(c);sc.camera=c;c.data.type='ORTHO'
H,Ln=info['H'],info['L'];c.data.ortho_scale=max(H*1.6,Ln)*1.25
th=math.radians(70);dv=(-math.sin(th),math.cos(th),0);tz=H*0.55 if n!='ani_pigeon' else H*0.9;c.location=(-dv[0]*8,-dv[1]*8,tz);c.rotation_euler=(math.radians(90),0,th)
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
for t in arm.animation_data.nla_tracks: t.mute=True
for clip,fr in info['clips'].items():
  arm.animation_data.action=bpy.data.actions[clip]
  for k,ph in enumerate((0.15,0.6)):
    sc.frame_set(int(fr*ph));sc.render.filepath=D+f'raw/sheet/{n}_{clip}_{k}.png';bpy.ops.render.render(write_still=True)
