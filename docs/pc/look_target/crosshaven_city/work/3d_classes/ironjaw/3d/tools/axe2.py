import bpy,numpy as np
from mathutils import Vector
D='/workspace/crosshaven_paint/work/3d_classes/ironjaw/3d/'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/workspace/ironjaw_grip/before/itm_ironjaw_axe_R_CONCEPTO_.glb')
o=[o for o in bpy.data.objects if o.type=='MESH'][0]
P=np.array([tuple(v.co) for v in o.data.vertices]);zb,zt=P[:,2].min(),P[:,2].max();zg=zb+0.25*(zt-zb)
s=P[abs(P[:,2]-zg)<0.02];c=Vector(((s[:,0].min()+s[:,0].max())/2,(s[:,1].min()+s[:,1].max())/2,zg))
for v in o.data.vertices: v.co-=c
print('GRIP shift',tuple(c),'haft r',round((s[:,0].max()-s[:,0].min())/2,4))
for side in 'RL':
  o.name=f'itm_ironjaw_axe_{side}';bpy.ops.export_scene.gltf(filepath=D+f'itm_ironjaw_axe_{side}_CONCEPTO_.glb',export_format='GLB',export_image_format='WEBP',export_image_quality=80)
