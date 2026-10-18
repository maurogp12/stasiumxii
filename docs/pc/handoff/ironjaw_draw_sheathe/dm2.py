import os,sys
exec(open('/workspace/meshy_pilot/ironjaw_new/catalog_v1/_base.py').read())
from bpy_extras.object_utils import world_to_camera_view as w2c
KIND=os.environ.get('KIND','draw')
BK={'Right':bpy.data.objects['axe_R'],'Left':bpy.data.objects['axe_L']}
SOCK={'Right':BACK_REST_SOCK['Left'],'Left':BACK_REST_SOCK['Right']}
CH=0.13
def knob(side):
  M=e.matrix_world@SOCK[side];return M@Vector((0,0.14-CH/AS,0)),M
HLc={sd:sum([v.co for v in ob.data.vertices if v.co.y>0.16],Vector())/len([v for v in ob.data.vertices if v.co.y>0.16]) for sd,ob in BK.items()}
HOLDB={};REL={}
for side in ('Left','Right'):
  Gh,Rh=hold_ref(side)
  HOLDB.update({side+n:arm.pose.bones[side+n].matrix_basis.copy() for n in ('Arm','ForeArm','Hand')})
  setM(BK[side],Gh,Rh,AS,BK[side]['yg']);bpy.context.view_layer.update()
  REL[side]=(arm.matrix_world@arm.pose.bones[side+'Hand'].matrix).inverted()@BK[side].matrix_world
LEGB={'Hips','LeftUpLeg','LeftLeg','LeftFoot','LeftToeBase','RightUpLeg','RightLeg','RightFoot','RightToeBase'}
ARMS={s+n for s in ('Left','Right') for n in ('Arm','ForeArm','Hand')}
restore(0);ALL=[b.name for b in arm.pose.bones];IB={b:arm.pose.bones[b].matrix_basis.copy() for b in ALL}
b0=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath='/workspace/meshy_pilot/ironjaw_new/catalog_v1/a222.glb')
new=[o for o in bpy.data.objects if o not in b0];act=[o for o in new if o.type=='ARMATURE'][0].animation_data.action
for o in new:bpy.data.objects.remove(o)
arm.animation_data.action=act
FG=19;CB={};GR={};EL={}
for f in range(0,FG+1):
  sc.frame_set(f);bpy.context.view_layer.update()
  CB[f]={b:arm.pose.bones[b].matrix_basis.copy() for b in ALL}
  hp=arm.pose.bones['Hips'].matrix;GR[f]=hp.inverted()@Wi(gripG('Right'));EL[f]=hp.inverted()@arm.pose.bones['RightForeArm'].head
arm.animation_data.action=None
LEG0={b:CB[0][b] for b in LEGB}  # legs fixed = clip frame 0 stance (no pop, no crouch)
def LRS(l,r,s):return Matrix.Translation(l)@r.to_matrix().to_4x4()@Matrix.Diagonal((s.x,s.y,s.z,1))
def lerpM(A,B,u):
  la,ra,sa=A.decompose();lb,rb,sb=B.decompose();return LRS(la.lerp(lb,u),ra.slerp(rb,u),sa.lerp(sb,u))
def tgt(side,f):
  p=GR[f].copy();el=EL[f].copy()
  if side=='Left':p.x=-p.x;el.x=-el.x   # mirrored, NO lag: both arms in sync
  hp=arm.pose.bones['Hips'].matrix;return W(hp@p),W(hp@el)
def setpose(D):
  for b in ALL:arm.pose.bones[b].matrix_basis=D[b]
  bpy.context.view_layer.update()
def segd(p,a,b):
  d=b-a;t=max(0,min(1,(p-a).dot(d)/d.dot(d)));return (p-(a+d*t)).length
def body_dist(p):
  P=lambda n:W(arm.pose.bones[n].head)
  segs=[('Hips','neck'),('neck','Head'),('LeftShoulder','LeftArm'),('RightShoulder','RightArm'),('LeftUpLeg','LeftLeg'),('LeftLeg','LeftFoot'),('RightUpLeg','RightLeg'),('RightLeg','RightFoot'),('Hips','LeftUpLeg'),('Hips','RightUpLeg')]
  return min(segd(p,P(a),P(b)) for a,b in segs)
def spine_axis_dist(p):
  h=W(arm.pose.bones['Hips'].head);s=W(arm.pose.bones['neck'].head)
  d=s-h;t=max(0,min(1,(p-h).dot(d)/d.dot(d)));return (p-(h+d*t)).length
N=18;log=[];hist={'Left':[],'Right':[]};VW=[('S',0),('SE',315),('E',270),('NE',225),('N',180),('NW',135),('W',90),('SW',45)]
OUT=sys.argv[sys.argv.index('--')+1];os.makedirs(OUT,exist_ok=True);px={v[0]:[] for v in VW}
for k,t in ticks:t.location=(0,k*PER,0)
HOLDPOSE={b:(LEG0[b] if b in LEGB else HOLDB.get(b,IB[b])) for b in ALL}
IDLEPOSE={b:(LEG0[b] if b in LEGB else IB[b]) for b in ALL}
EV={'kind':KIND}
RE=7;GRABP=None;GREL={};SH={}
def frame(i):
  global GRABP
  if KIND=='draw':
    if i<=RE:
      f=round(FG*i/RE);wi=ease(i/3)
      setpose({b:(LEG0[b] if b in LEGB else lerpM(IB[b],CB[f][b],wi)) for b in ALL})
      for side in ('Left','Right'):
        G,El=tgt(side,f);kn,Mb=knob(side);G0,_=tgt(side,FG)
        Gt=G+(kn-G0)*ease(f/FG)
        if i==RE:Gt=kn
        if i<3:Gt=IDLEG[side].lerp(Gt,ease(i/3))
        sh=W(arm.pose.bones[side+'Arm'].head);ik_grip(side,Gt,El-(sh+Gt)/2)
      for side in ('Left','Right'):BK[side].matrix_world=knob(side)[1]
      if i==RE:
        GRABP={b:arm.pose.bones[b].matrix_basis.copy() for b in ALL}
        for side in ('Left','Right'):
          kn,Mb=knob(side);Hm=arm.matrix_world@arm.pose.bones[side+'Hand'].matrix
          GREL[side]=Hm.inverted()@Mb;EV.setdefault('grab_err_m',{})[side]=round((gripG(side)-kn).length,4)
      return 'back' if i<RE else 'hand'
    yk=0.14-CH/AS
    if not SH:
      setpose(HOLDPOSE)
      for side in ('Left','Right'):
        Hm=arm.matrix_world@arm.pose.bones[side+'Hand'].matrix;A=Hm@REL[side];H1=gripG(side);R1=A.to_3x3().normalized()
        SH[side]=dict(H1=H1,R1=R1.to_quaternion(),ya=(R1.inverted()@(H1-A.translation)).y/AS,HM={b:arm.pose.bones[b].matrix_basis.copy() for b in ARMS if b.startswith(side)})
      setpose(GRABP)
      for side in ('Left','Right'):
        kn,Mb=knob(side);sg=1 if side=='Left' else -1;sh=W(arm.pose.bones[side+'Arm'].head)
        SH[side].update(kn=kn,R0=Mb.to_3x3().normalized().to_quaternion(),W1=sh+Vector((sg*0.10,float(os.environ.get('WY','-0.16')),float(os.environ.get('WZ','0.06')))))
    t=min(1,(i-RE)/(15-RE))
    body={b:(lerpM(GRABP[b],HOLDPOSE[b],ease(t)) if b not in ARMS else GRABP[b]) for b in ALL}
    setpose(body)
    for side in ('Left','Right'):
      d=SH[side];sg=1 if side=='Left' else -1
      if t<0.4:G=d['kn'].lerp(d['W1'],ease(t/0.4))
      else:G=d['W1'].lerp(d['H1'],ease((t-0.4)/0.6))
      ik_grip(side,G,Vector((sg*1,0.4,-0.5)))
      if t>=0.75:
        v=ease((t-0.75)/0.25)
        for b,M in d['HM'].items():arm.pose.bones[b].matrix_basis=lerpM(arm.pose.bones[b].matrix_basis.copy(),M,v)
        bpy.context.view_layer.update()
      r=ease(min(1,t/0.8));R=d['R0'].slerp(d['R1'],r).to_matrix();yl=yk*(1-r)+d['ya']*r
      if t>=1:BK[side].matrix_world=(arm.matrix_world@arm.pose.bones[side+'Hand'].matrix)@REL[side]
      else:setM(BK[side],gripG(side),R,AS,yl)
    return 'hand'
  else:
    yk=0.14-CH/AS
    if i<=1:
      setpose(HOLDPOSE)
      for side in ('Left','Right'):
        BK[side].matrix_world=(arm.matrix_world@arm.pose.bones[side+'Hand'].matrix)@REL[side]
      return 'hand'
    if i<=9:
      setpose(HOLDPOSE)
      for side in ('Left','Right'):
        if side not in SH:
          Hm=arm.matrix_world@arm.pose.bones[side+'Hand'].matrix;A=Hm@REL[side]
          H0=gripG(side);R0=A.to_3x3().normalized();sg=1 if side=='Left' else -1
          sh=W(arm.pose.bones[side+'Arm'].head);kn,Mb=knob(side)
          W1=sh+Vector((sg*0.04,0.0,0.30))   # hand rises just above/over the shoulder
          ya=(R0.inverted()@(H0-A.translation)).y/AS
          SH[side]=dict(H0=H0,W1=W1,kn=kn,R0=R0.to_quaternion(),R1=Mb.to_3x3().normalized().to_quaternion(),ya=ya)
        d=SH[side];t=(i-1)/8
        if t<0.55:G=d['H0'].lerp(d['W1'],ease(t/0.55))
        else:G=d['W1'].lerp(d['kn'],ease((t-0.55)/0.45))
        sh=W(arm.pose.bones[side+'Arm'].head);sg=1 if side=='Left' else -1
        ik_grip(side,G,Vector((sg*1,0.3,-0.6)))
        r=ease(max(0,(t-0.2)/0.8));R=d['R0'].slerp(d['R1'],r).to_matrix();yl=d['ya']*(1-r)+yk*r
        g=G if i<9 else d['kn']
        setM(BK[side],g,R,AS,yl)
      if i==9:
        global LIFTP;LIFTP={b:arm.pose.bones[b].matrix_basis.copy() for b in ALL}
        for side in ('Left','Right'):EV.setdefault('socket_err_m',{})[side]=round((BK[side].matrix_world.translation-knob(side)[1].translation).length,4)
        return 'back'
      return 'hand'
    u=ease((i-9)/7) if i<=16 else 1
    setpose({b:lerpM(LIFTP[b],IDLEPOSE[b],u) for b in ALL})
    for side in ('Left','Right'):BK[side].matrix_world=knob(side)[1]
    return 'back'
for i in range(N):
  st=frame(i);bpy.context.view_layer.update()
  ent=dict(i=i,state=st)
  for side in ('Left','Right'):
    ob=BK[side];hw=ob.matrix_world@HLc[side];hist[side].append(hw.copy())
    ent[side]=dict(head=[round(x,3) for x in hw],head_spine_dist=round(spine_axis_dist(hw),3),head_skel_dist=round(body_dist(hw),3),scale=round((ob.matrix_world.to_3x3()@Vector((0,1,0))).length,4),grip=[round(x,3) for x in gripG(side)])
  def kn_(sd):
    a_=W(arm.pose.bones[sd+'UpLeg'].head);b_=W(arm.pose.bones[sd+'Leg'].head);c_=W(arm.pose.bones[sd+'Foot'].head);return round(180-math.degrees((b_-a_).angle(c_-b_)),1)
  ent['knee']=[kn_('Left'),kn_('Right')];ent['hips']=[round(x,3) for x in W(arm.pose.bones['Hips'].head)]
  ent['sync_grip_mirror_err']=round((gripG('Left')-Vector((-1,1,1))*0+Vector((-gripG('Right').x,gripG('Right').y,gripG('Right').z))-gripG('Left')*0-gripG('Left')).length if False else (Vector((-gripG('Right').x,gripG('Right').y,gripG('Right').z))-gripG('Left')).length,3)
  log.append(ent)
  if os.environ.get('NORENDER'):continue
  for name,az in VW:
    r=math.radians(az);el=math.radians(30);d=8
    cam.location=(d*math.sin(r)*math.cos(el),-d*math.cos(r)*math.cos(el),1.3+d*math.sin(el));cam.rotation_euler=(math.radians(90)-el,0,r);cam.data.ortho_scale=2.9
    bpy.context.view_layer.update()
    px[name].append({s:[round(w2c(sc,cam,hist[s][-1]).x*RES,1),round((1-w2c(sc,cam,hist[s][-1]).y)*RES,1)] for s in ('Left','Right')})
    sc.render.filepath=f'{OUT}/{name}_{i:02d}.png';bpy.ops.render.render(write_still=True)
DT=1/12
for i in range(N):
  for s in ('Left','Right'):
    a=hist[s][max(0,i-1)];b=hist[s][min(N-1,i+1)];log[i][s]['speed']=round(((b-a)/(DT*(min(N-1,i+1)-max(0,i-1)))).length,2)
print('EV',EV)
json.dump(log,open(f'{OUT}/check.json','w'),indent=1);json.dump(dict(px=px,res=RES,fps=12,frames=N,ev=EV,grab={'Right':RE,'Left':RE} if KIND=='draw' else {'Right':9,'Left':9}),open(f'{OUT}/px.json','w'))
