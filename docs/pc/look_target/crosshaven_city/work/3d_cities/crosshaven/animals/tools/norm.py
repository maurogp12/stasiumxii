import bpy,sys,mathutils,math,numpy as np
H={'ani_cat':0.32,'ani_dog':0.62,'ani_chicken':0.42,'ani_duck':0.40,'ani_horse':2.05,'ani_pigeon':0.26}
src,n=sys.argv[-2],sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=src)
ms=[o for o in bpy.context.scene.objects if o.type=='MESH']
for o in bpy.context.scene.objects:o.select_set(o in ms)
bpy.context.view_layer.objects.active=ms[0]
if len(ms)>1: bpy.ops.object.join()
o=bpy.context.active_object;o.parent=None
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
V=np.array([list(v.co) for v in o.data.vertices])
ext=V.max(0)-V.min(0)
ax=0 if ext[0]>ext[1] else 1
# head end = side of the highest vertex
top=V[V[:,2].argmax()];mid=(V[:,ax].max()+V[:,ax].min())/2
headpos=top[ax]>mid
# want head at -Y
if ax==0: ang=math.pi/2 if headpos else -math.pi/2   # +X head -> rotate +90 => -Y? check
else: ang=math.pi if headpos else 0
o.data.transform(mathutils.Matrix.Rotation(ang,4,'Z'));o.data.update()
V=np.array([list(v.co) for v in o.data.vertices]);top=V[V[:,2].argmax()]
if top[1]>(V[:,1].max()+V[:,1].min())/2: o.data.transform(mathutils.Matrix.Rotation(math.pi,4,'Z'));o.data.update();V=np.array([list(v.co) for v in o.data.vertices])
mn=V.min(0);mx=V.max(0);s=H[n]/(mx[2]-mn[2])
o.data.transform(mathutils.Matrix.Scale(s,4)@mathutils.Matrix.Translation((-(mn[0]+mx[0])/2,-(mn[1]+mx[1])/2,-mn[2])));o.data.update()
V=np.array([list(v.co) for v in o.data.vertices]);print('DIMS',n,(V.max(0)-V.min(0)).round(3),'tris',sum(len(p.vertices)-2 for p in o.data.polygons))
o.name=n
bpy.ops.export_scene.gltf(filepath=f'raw/norm/{n}.glb',export_format='GLB',export_image_format='WEBP',export_image_quality=85)
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=12;sc.cycles.device='CPU';sc.render.resolution_x=400;sc.render.resolution_y=300
w=bpy.data.worlds.new('w');sc.world=w;w.use_nodes=True;w.node_tree.nodes['Background'].inputs[1].default_value=1.0
c=bpy.data.objects.new('c',bpy.data.cameras.new('c'));sc.collection.objects.link(c);sc.camera=c;c.data.type='ORTHO';h=H[n];L=(V.max(0)-V.min(0))[1];c.data.ortho_scale=max(L,h)*1.2
c.location=(5,0,h/2);c.rotation_euler=(math.pi/2,0,math.pi/2);sc.render.filepath=f'raw/norm/{n}_side.png';bpy.ops.render.render(write_still=True)
