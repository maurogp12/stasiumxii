import sys, math, json, hashlib
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, '/workspace/art_src/blockout/ironjaw_walk/src')
import bpy
import rig, model
from mathutils import Matrix, Vector

BASE=Path('/workspace/art_src/blockout/ironjaw_walk')
OUT=BASE/'renders_512'
cam=json.loads((BASE/'camera.json').read_text())
meta=json.loads((BASE/'qa/model_meta.json').read_text())
XO,YO,SPX=meta['XO'],meta['YO'],meta['px_per_unit']
Rv=Vector(meta['Rv']); Uv=Vector(meta['Uv']); Bv=Vector(cam['toward_camera_world'])
P=model.parts()
PH_OFF={'S':0,'E':1}; FY={'S':-90.0,'E':0.0}; OFF={'S':(26,15),'E':(26,31)}

def root_for(F): return Matrix.Rotation(math.radians(FY[F]),4,'Z')
def wp(root, p): return root @ Vector(p)
def project_world(p,F):
    x=XO+SPX*Rv.dot(p); y=YO-SPX*Uv.dot(p); ox,oy=OFF[F]
    return [round(float(x+ox),3),round(float(y+oy),3)]
def world_mat(root,m): return root @ m
def point(root,m,v=(0,0,0)): return root @ (m @ Vector(v))
def meanv(vs):
    q=sum((Vector(v) for v in vs), Vector((0,0,0))) / len(vs); return q
# Stable top and axe centre local points.
headv=P['head'][0]; zmax=max(v.z for v in headv); head_top_local=meanv([v for v in headv if abs(v.z-zmax)<1e-6])
axe_local=[Vector((0,y,z)) for y,z in model.AXE_HEAD]; axe_centre_local=meanv(axe_local)

def build_pose(F, ph, idle=False):
    root=root_for(F); Mc=rig.pose(ph,idle=idle,cheat=rig.CHEAT[F])
    j={}
    j['pelvis']=root @ Mc['pelvis'].translation
    j['chest']=root @ Mc['chest'].translation
    j['neck']=root @ Mc['head'].translation
    j['head_top']=point(root,Mc['head'],head_top_local)
    for s,n in ((1,'R'),(-1,'L')):
        j[n+'_shoulder']=root @ Mc['shoulder_'+n].translation
        j[n+'_elbow']=point(root,Mc['upperarm_'+n],(0,0,-rig.UPPER))
        j[n+'_wrist']=root @ Mc['hand_'+n].translation
        j[n+'_axe_grip']=point(root,Mc['axe_'+n])
        j[n+'_axe_head_centre']=point(root,Mc['axe_'+n],axe_centre_local)
        j[n+'_hip']=root @ Mc['thigh_'+n].translation
        j[n+'_knee']=point(root,Mc['thigh_'+n],(0,0,-rig.THIGH))
        j[n+'_ankle']=root @ Mc['boot_'+n].translation
        j[n+'_toe']=point(root,Mc['boot_'+n],(0,42,-20))
        j[n+'_heel']=point(root,Mc['boot_'+n],(0,-25,-20))
    # part endpoints are the main axes in 3D.
    parts={
      'torso':(j['pelvis'],j['chest']), 'cape':(root @ Mc['cape_up'].translation,root @ Mc['cape_lo'].translation),
    }
    for n in 'RL':
      parts[n+'_upperarm']=(j[n+'_shoulder'],j[n+'_elbow']); parts[n+'_forearm']=(j[n+'_elbow'],j[n+'_wrist'])
      parts[n+'_axe']=(j[n+'_axe_grip'],j[n+'_axe_head_centre'])
      parts[n+'_thigh']=(j[n+'_hip'],j[n+'_knee']); parts[n+'_shin']=(j[n+'_knee'],j[n+'_ankle']); parts[n+'_boot']=(j[n+'_heel'],j[n+'_toe'])
    return root,Mc,j,parts

def axis_angle(a,b):
    # 0 = straight down, positive = clockwise on screen (screen x right, y down).
    dx=b[0]-a[0]; dy=b[1]-a[1]
    return round(math.degrees(math.atan2(dx,dy)),3)

def serialize(F, ph, idle=False, baselines=None):
    root,Mc,j,parts3=build_pose(F,ph,idle)
    jp={k:project_world(v,F) for k,v in j.items()}
    pp={}
    for name,(a,b) in parts3.items():
      aa=project_world(a,F); bb=project_world(b,F)
      plen=math.hypot(bb[0]-aa[0],bb[1]-aa[1])
      base=baselines[name]
      entry={'rotation_deg':axis_angle(aa,bb),'visible_length_scale':round(plen/base,6)}
      if name.endswith('_axe'):
        n= name[0]
        # Face normal is local +X for the extruded axe blade; report its screen angle.
        nn=(root.to_3x3() @ Mc['axe_'+n].to_3x3() @ Vector((1,0,0))).normalized()
        tip=project_world((root @ Mc['axe_'+n].translation)+nn,F)
        entry['blade_facing_angle_deg']=axis_angle(project_world(root @ Mc['axe_'+n].translation,F),tip)
      pp[name]=entry
    centers={name:(a+b)*0.5 for name,(a,b) in parts3.items()}
    order=['torso','cape','R_upperarm','R_forearm','R_axe','L_upperarm','L_forearm','L_axe','R_thigh','R_shin','R_boot','L_thigh','L_shin','L_boot']
    # nearest (larger toward-camera dot) first; tie-break by requested order.
    draw=sorted(order,key=lambda n:(-(Bv.dot(centers[n])),order.index(n)))
    return {'joints':jp,'draw_order':draw,'parts':pp}

# Build idle baselines per facing and part name.
allout={}
for F in 'SE':
    _,_,_,ip=build_pose(F,None,True)
    baselines={}
    for name,(a,b) in ip.items():
      aa=project_world(a,F); bb=project_world(b,F); baselines[name]=math.hypot(bb[0]-aa[0],bb[1]-aa[1])
    for mode in ('walk','idle'):
      key=mode+'_'+F
      if mode=='walk':
        allout[key]={}
        for f in range(rig.NF):
          ph=(f+PH_OFF[F])%rig.NF
          allout[key]['f%02d'%f]=serialize(F,ph,False,baselines)
      else:
        allout[key]=serialize(F,None,True,baselines)

obj={'meta':{
  'cell':[512,360], 'pivot':[256,329],
  'camera':{'type':cam['type'],'azimuth_deg':cam['azimuth_deg'],'elevation_deg_below_horizontal':cam['elevation_deg_below_horizontal'],'ortho_scale':cam['ortho_scale'],'world_origin_pixel':[XO+26,YO+15]},
  'offsets':{'x':26,'y_S':15,'y_E':31},
  'notes':'Joint coordinates are camera projections in the padded 512x360 cells. S/E use y offsets 15/31; draw_order is nearest-camera first. Part rotation: 0 = straight down, positive = clockwise on screen. visible_length_scale is projected 2D axis length divided by the corresponding idle-frame projected length for that facing. Axe blade facing angle is the screen angle of the blade flat-face normal.'
},'facings':allout}
outp=OUT/'joints_512.json'; outp.write_text(json.dumps(obj,indent=1)+'\n')

# overlay check: padded clay cells, with joints and labels.
try: FONT=ImageFont.load_default(size=10)
except TypeError: FONT=ImageFont.load_default()
checks=[('S','f00','walk_S','S f00'),('E','f05','walk_E','E f05')]
canvas=Image.new('RGBA',(1024,390),(238,236,230,255)); d=ImageDraw.Draw(canvas)
colors={'pelvis':(255,50,50,255),'chest':(255,150,30,255),'neck':(255,220,30,255),'head_top':(255,255,255,255),'L':(70,130,255,255),'R':(50,230,100,255)}
for col,(F,frame,key,label) in enumerate(checks):
  src=Image.open(OUT/'clay'/(('walk_'+F+'_'+frame+'.png'))).convert('RGBA')
  canvas.alpha_composite(src,(col*512,20))
  dd=ImageDraw.Draw(canvas); dd.text((col*512+8,3),label,fill=(0,0,0,255),font=FONT)
  dat=obj['facings'][key][frame]
  for name,xy in dat['joints'].items():
    x,y=xy[0]+col*512,xy[1]+20
    side=name[0] if name[0] in 'RL' else name
    c=colors.get(side,colors.get(name,(255,40,180,255)))
    r=3 if ('ankle' in name or 'toe' in name or 'heel' in name) else 4
    dd.ellipse((x-r,y-r,x+r,y+r),fill=c,outline=(0,0,0,255),width=1)
    if name in ('pelvis','chest','head_top','R_axe_head_centre','L_axe_head_centre'):
      dd.text((x+5,y-5),name,fill=(0,0,0,255),font=FONT)
canvas.convert('RGB').save(OUT/'joints_check.png',optimize=True)
# Update manifest sha map to include joint assets.
manp=OUT/'manifest_512.json'; man=json.loads(manp.read_text()); sh=man['sha256']
sh['joints_512.json']=hashlib.sha256(outp.read_bytes()).hexdigest()
sh['joints_check.png']=hashlib.sha256((OUT/'joints_check.png').read_bytes()).hexdigest()
# Preserve sorted deterministic sha map.
man['sha256']={k:sh[k] for k in sorted(sh)}
manp.write_text(json.dumps(man,indent=1)+'\n')
print('wrote',outp,'and',OUT/'joints_check.png')
print('keys',list(allout), 'sha entries',len(man['sha256']))
