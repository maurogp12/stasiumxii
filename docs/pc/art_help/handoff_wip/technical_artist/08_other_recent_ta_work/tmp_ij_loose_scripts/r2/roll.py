from h import *
cam=json.load(open(B+'/camera.json')); BV=Vector(cam['toward_camera_world'])
from lev import dys
import itertools
base=dict(rig.ARM[('S','R')])
def face(F,n):
    root=Matrix.Rotation(math.radians(FY[F]),4,'Z'); M=rig.pose(None,idle=True,cheat=rig.CHEAT[F],facing=F)
    nn=(root.to_3x3()@M['axe_'+n].to_3x3()@Vector((1,0,0))).normalized(); return abs(nn.dot(BV))
rig.ARM[('S','R')]=dict(fist_x=92.0,reach=52.0,bend=100.0,haft=28.0,yaw=0.0,pole=(0.5,-1.0,-0.1))
print('approved S R face |cos| %.2f'%face('S','R'))
rig.ARM[('S','R')]=base
print('current S R %.2f  S L %.2f  E R %.2f'%(face('S','R'),face('S','L'),face('E','R')))
for yw,rl in itertools.product([10,20,30],[-60,-45,-30,-15,0,15,30,45,60]):
    d=dict(base); d.update(yaw=float(yw),roll=float(rl)); rig.ARM[('S','R')]=d
    J,_=joints('S',None,True); dd,_=dys('S')
    print(yw,rl,'face %.2f'%face('S','R'),'head',f1(J['R_head']),'dy %.1f'%dd[0])
