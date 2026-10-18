import bpy,sys,math,json,os
from mathutils import Matrix,Vector
from bpy_extras.object_utils import world_to_camera_view
D='/workspace/crosshaven_paint/work/3d_classes/ironjaw/3d/';G='/workspace/ironjaw_grip/'
a=sys.argv[sys.argv.index('--')+1:];VER=a[0];OUT=a[1];shots=[s.split(':') for s in a[2].split(',')];HOL=a[3] if len(a)>3 else ''
src=G+'before/' if VER=='before' else D
CHR=G+'test_LOD0.glb' if VER=='test' else src+'chr_ironjaw_male_LOD0.glb'
if VER=='test': src=D
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=CHR)
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
for o in bpy.data.objects:
  if o.name.startswith('Icosphere'): o.hide_render=True
arm.animation_data_create()
for t in arm.animation_data.nla_tracks: t.mute=True
def rest():
  arm.animation_data.action=None
  for pb in arm.pose.bones: pb.matrix_basis.identity()
  bpy.context.view_layer.update()
rest()
GI=json.load(open(G+'grip_info.json'))
axes={}
for side,bone in [('R','RightHand'),('L','LeftHand')]:
  b0=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=src+f'itm_ironjaw_axe_{side}_CONCEPTO_.glb')
  ax=[o for o in set(bpy.data.objects)-b0 if o.type=='MESH'][0];ax.rotation_mode='XYZ';axes[bone]=ax
  c=ax.constraints.new('CHILD_OF');c.target=arm;c.subtarget=bone
  if VER=='before':
    c.use_scale_x=c.use_scale_y=c.use_scale_z=False;c.inverse_matrix.identity();ax.location=(0,0.08,0);ax.rotation_euler=(math.radians(-90),0,0)
  else:
    bm=arm.matrix_world@arm.data.bones[bone].matrix_local
    if HOL:
      bm=arm.matrix_world@arm.data.bones['UpperChest'].matrix_local;c.subtarget='UpperChest'
      sx=-1 if side=='R' else 1
      W=Matrix.Translation((sx*0.11,0.2,1.32))@Matrix.Rotation(math.radians(sx*-35),4,'Y')@Matrix.Rotation(math.radians(180),4,'X')
    else:
      W=bm@Matrix(GI[bone]['bone_local_T'])
    c.inverse_matrix=bm.inverted();ax.matrix_basis=W
bpy.context.view_layer.update()
json.dump({b:[list(r) for r in axes[b].matrix_world] for b in axes},open(G+f'axeworld_{VER}{HOL}.json','w'))
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=16;sc.cycles.use_denoising=False
l=bpy.data.objects.new('sun',bpy.data.lights.new('sun','SUN'));l.data.energy=4;l.rotation_euler=(0.8,0.2,0.4);sc.collection.objects.link(l)
sc.render.resolution_x=sc.render.resolution_y=500
w=bpy.data.worlds.new('w');sc.world=w;w.use_nodes=True;w.node_tree.nodes['Background'].inputs[0].default_value=(0.6,0.6,0.6,1)
cam=bpy.data.objects.new('cam',bpy.data.cameras.new('cam'));sc.collection.objects.link(cam);sc.camera=cam
cam.data.type='ORTHO';cam.data.ortho_scale=2.4
CLOSE=len(a)>4 and a[4]=='close'
crops={}
SINGLE=['attack_melee_1','ironjaw_axe_stance','ironjaw_ground_slam','cast','victory','turn_l','ironjaw_axe_spin']
HOLS=['sit','interact','ironjaw_climb']
def place(ax,bone,side,hol,off=None):
  c=ax.constraints[0]
  if hol:
    bm=arm.matrix_world@arm.data.bones['UpperChest'].matrix_local;c.subtarget='UpperChest';sx=-1 if side=='R' else 1
    W=Matrix.Translation((sx*0.11,0.2,1.32))@Matrix.Rotation(math.radians(sx*-35),4,'Y')@Matrix.Rotation(math.radians(180),4,'X')
    if off: W=W@off
  else:
    bm=arm.matrix_world@arm.data.bones[bone].matrix_local;c.subtarget=bone;W=bm@Matrix(GI[bone]['bone_local_T'])
  c.inverse_matrix=bm.inverted();ax.matrix_basis=W
for name,clip,frac,ang in shots:
  if VER!='before':
    rest()
    OFFS=json.loads(os.environ.get('HOFF','{}')).get(clip)
    def om(sx):
      if not OFFS: return None
      p,rd=OFFS;return Matrix.Translation(p)@Matrix.Rotation(math.radians(rd[1]*sx),4,'Y')@Matrix.Rotation(math.radians(rd[0]),4,'X')
    place(axes['RightHand'],'RightHand','R',clip in HOLS,om(-1))
    place(axes['LeftHand'],'LeftHand','L',clip in HOLS or clip in SINGLE,om(1))
  if clip=='rest': rest();f=1
  else:
    ac=[x for x in bpy.data.actions if x.name==clip or x.name.startswith(clip+'_')][0];arm.animation_data.action=ac
    s,e=ac.frame_range;f=int(s+(e-s)*float(frac));sc.frame_set(f)
  bpy.context.view_layer.update()
  for bone in (['RightHand','LeftHand'] if CLOSE else ['X']):
    A=math.radians(float(ang));d=Vector((math.sin(A),-math.cos(A),0))
    if CLOSE:
      p=arm.matrix_world@arm.pose.bones[bone].matrix@Vector(GI[bone]['centre_cm'])
      cam.data.ortho_scale=0.45;cam.location=p+d*3;cam.rotation_euler=(math.radians(90),0,A);sc.render.resolution_x=sc.render.resolution_y=500
      sc.render.filepath=OUT+f'/{name}_{bone}.png'
    else:
      cam.location=(6*math.sin(A),-6*math.cos(A),1.1);cam.rotation_euler=(math.radians(90),0,A);sc.render.filepath=OUT+f'/{name}.png'
    bpy.ops.render.render(write_still=True)
