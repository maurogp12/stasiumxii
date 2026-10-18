# exec'd from build2.py with arm, mesh, acts, sc, info, D
YK=12.0;R_HAFT=1.6;MAXA=math.radians(270);GAM=math.radians(80)
hb='RightHand';sg=-1
nrm=Vector((0,0,-1));yax=Vector((0,1,0));t0=nrm.cross(yax);h=(t0*sg).normalized();yp=(-sg*nrm.cross(h)).normalized()
gi=mesh.vertex_groups[hb].index;b=arm.data.bones[hb]
M=(arm.matrix_world@b.matrix_local).inverted()@mesh.matrix_world;Mi=M.inverted()
vs=[];ws=[]
for v in mesh.data.vertices:
  w=max([g.weight for g in v.groups if g.group==gi],default=0)
  if w>0.3: vs.append(v);ws.append(w)
ORIG=[v.co.copy() for v in mesh.data.vertices]
Pts=[M@v.co for v in vs]
dn=np.array([p.dot(nrm) for p in Pts]);yy=np.array([p.y for p in Pts]);tt=np.array([p.dot(t0) for p in Pts])
d_palm=np.percentile(dn[(yy>YK-5)&(yy<YK)],85);Cn=d_palm+R_HAFT*0.6;tc=(tt.min()+tt.max())/2;hw=(tt.max()-tt.min())/2
C=nrm*Cn+yax*YK+t0*tc
for v,w,p,d in zip(vs,ws,Pts,dn):
  r=p-C;s=r.dot(yp);a_h=r.dot(h)
  thumb=(sg*(p.dot(t0)-tc)>0.4*hw) and (6<p.y<19) and s<=1.0
  if s>0 and not thumb:
    rho=max(R_HAFT,R_HAFT+(Cn-d-R_HAFT)*0.55);phi=min(MAXA,s/rho);tgt=C+h*a_h+yp*(rho*math.sin(phi))-nrm*(rho*math.cos(phi))
  elif thumb:
    ramp=min(1,max(0,(p.y-6)/13));rr=r-h*a_h;rr=Matrix.Rotation(GAM*ramp,3,h)@rr
    if rr.length<R_HAFT+0.8: rr=rr.normalized()*(R_HAFT+0.8)
    tgt=C+h*a_h+rr
  else: continue
  v.co=Mi@(p.lerp(tgt,min(1.0,w)))
FIST=[v.co.copy() for v in mesh.data.vertices]
for v,c in zip(mesh.data.vertices,ORIG): v.co=c
mesh.shape_key_add(name='Basis',from_mix=False);kf=mesh.shape_key_add(name='fist',from_mix=False)
for i,c in enumerate(FIST): kf.data[i].co=c
info['fist']={'centre_cm_handlocal':[round(x,2) for x in C],'haft_dir_handlocal':list(h),'r_haft_cm':R_HAFT}
# spear-hold arm pose solved at rest, stored as local quats
arm.animation_data.action=None
for pb in arm.pose.bones: pb.rotation_mode='QUATERNION';pb.rotation_quaternion=(1,0,0,0);pb.location=(0,0,0)
bpy.context.view_layer.update()
Rw=arm.matrix_world.to_3x3().normalized()
def setdir(bn,d,up_local=None,up_world=None):
  pb=arm.pose.bones[bn];cur=(arm.matrix_world@pb.matrix).to_3x3().normalized()
  q=cur.col[1].rotation_difference(d.normalized());R=q.to_matrix()@cur
  if up_local is not None:
    a=R@up_local;a=(a-d.normalized()*a.dot(d.normalized())).normalized();u=(up_world-d.normalized()*up_world.dot(d.normalized())).normalized()
    ang=math.atan2(a.cross(u).dot(d.normalized()),a.dot(u));R=Matrix.Rotation(ang,3,d.normalized())@R
  head=pb.matrix.translation.copy()
  pb.matrix=Matrix.Translation(head)@(Rw.inverted()@R).to_4x4();bpy.context.view_layer.update()
setdir('RightUpperArm',Vector((-0.28,-0.02,-1)))
setdir('RightLowerArm',Vector((-0.10,-1,0.10)))
setdir('RightHand',Vector((0.0,-1,0.0)),up_local=-t0*sg*-1 if False else h,up_world=Vector((0,0,1)))
HQ={bn:arm.pose.bones[bn].rotation_quaternion.copy() for bn in ['RightUpperArm','RightLowerArm','RightHand']}
# idle_spear = idle with right arm fixed
isp=acts['idle'].copy();isp.name='idle_spear';acts['idle_spear']=isp
for bn,q in HQ.items():
  for fc in [f for f in isp.fcurves if f.data_path==f'pose.bones["{bn}"].rotation_quaternion']: isp.fcurves.remove(fc)
  s,e=acts['idle'].frame_range
  for i in range(4):
    fc=isp.fcurves.new(f'pose.bones["{bn}"].rotation_quaternion',index=i,action_group=bn)
    fc.keyframe_points.insert(s,q[i]);fc.keyframe_points.insert(e,q[i])
info['idle_spear']={'base':'idle (Long_Breathe_and_Look_Around) with RightUpperArm/LowerArm/Hand overridden: forearm forward, haft vertical','local_quats_wxyz':{k:[round(x,4) for x in v] for k,v in HQ.items()}}
# attach: spear objects
def spear(nm):
  ob=imp(D+'raw/norm/prp_spear_guard.glb');m=[o for o in ob if o.type=='MESH'][0];m.name=nm;return m
arm.animation_data.action=isp;sc.frame_set(0);bpy.context.view_layer.update()
Hw=arm.matrix_world@arm.pose.bones[hb].matrix
Cw=Hw@C;R3=Hw.to_3x3().normalized();hw_=(R3@h).normalized();ypw=(R3@yp).normalized()
g=Cw.z-0.01
Z=hw_;X=(ypw-Z*ypw.dot(Z)).normalized();Y=Z.cross(X)
sp=spear('SPEAR_HAND');sp.parent=arm;sp.parent_type='BONE';sp.parent_bone=hb
sp.matrix_world=Matrix.Translation(Cw-Z*g)@Matrix((X,Y,Z)).transposed().to_4x4()
info['spear_hand_world']={'grip_height_m':round(g,3),'haft_dir_world':[round(x,3) for x in Z],'grip_world':[round(x,3) for x in Cw]}
# back sling, rest pose
arm.animation_data.action=None
for pb in arm.pose.bones: pb.rotation_quaternion=(1,0,0,0);pb.location=(0,0,0)
bpy.context.view_layer.update()
ch=(arm.matrix_world@arm.pose.bones['UpperChest'].matrix).translation
d=Vector((-0.32,0.06,0.945)).normalized();Zb=d;Xb=Vector((1,0,0));Xb=(Xb-Zb*Xb.dot(Zb)).normalized();Yb=Zb.cross(Xb)
spb=spear('SPEAR_BACK');spb.parent=arm;spb.parent_type='BONE';spb.parent_bone='UpperChest'
spb.matrix_world=Matrix.Translation(ch+Vector((0,0.16,-0.05))-Zb*1.1)@Matrix((Xb,Yb,Zb)).transposed().to_4x4()
bpy.context.view_layer.update()
# glTF joint-space transforms: export a probe and read child node TRS
bpy.ops.object.select_all(action='DESELECT')
for o in (arm,mesh,sp,spb): o.select_set(True)
pf=D+'raw/meshy/guard_attach_probe.glb'
bpy.ops.export_scene.gltf(filepath=pf,use_selection=True,export_format='GLB',export_animations=False,export_skins=True,export_image_format='NONE')
import struct
bb=open(pf,'rb').read();jl=struct.unpack('<I',bb[12:16])[0];G=json.loads(bb[20:20+jl])
att={}
for i,nd in enumerate(G['nodes']):
  if nd.get('name') in ('SPEAR_HAND','SPEAR_BACK'):
    par=[p['name'] for p in G['nodes'] if i in p.get('children',[])]
    att[nd['name']]={'parent_joint':par[0] if par else None,'position_m':[round(x,4) for x in nd.get('translation',[0,0,0])],'rotation_quat_xyzw':[round(x,4) for x in nd.get('rotation',[0,0,0,1])],'scale':nd.get('scale',[1,1,1])}
info['attach']=att
# hide spears from final exports (separate glb)
sp.hide_render=False
bpy.data.objects.remove(sp);bpy.data.objects.remove(spb)
for pb in arm.pose.bones: pb.rotation_quaternion=(1,0,0,0)
arm.animation_data.action=None
