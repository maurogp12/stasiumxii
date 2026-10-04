import sys, math, json, os
sys.path.insert(0,'/workspace/art_src/blockout/ironjaw_walk/src')
import bpy
from mathutils import Matrix, Vector
import rig, model
cam=json.load(open('/workspace/art_src/blockout/ironjaw_walk/camera.json'))
Rv=Vector(cam['screen_right_world']); Uv=Vector(cam['screen_up_world']); XO,YO=cam['world_origin_pixel']; S=0.93
FY={'S':-90.0,'E':0.0}
def pj(p): return (XO+S*Rv.dot(p), YO-S*Uv.dot(p))
for F in sys.argv[1].split(','):
    root=Matrix.Rotation(math.radians(FY[F]),4,'Z')
    M=rig.pose(None,idle=True,cheat=rig.CHEAT[F])
    top=None
    out={}
    for s,n in ((1,'R'),(-1,'L')):
        A=rig.arm_chain((M['chest']@Vector((s*58,0,78))), s, 0.0)
        g=root@M['axe_'+n].translation; eye=root@(M['axe_'+n]@Vector((0,model.EYE_Y,0)))
        lo=max(pj(root@(M['axe_'+n]@Vector((0,y,z))))[1] for y,z in model.AXE_HEAD)
        knee=root@(M['thigh_'+n]@Vector((0,0,-rig.THIGH)))
        out[n]=dict(grip=[round(x) for x in pj(g)], eye=[round(x) for x in pj(eye)], head_low=round(lo), knee=[round(x) for x in pj(knee)],
                    grip3=[round(x) for x in M['axe_'+n].translation], elbow_ang=round(math.degrees((A['_elbow']-(M['chest']@Vector((s*58,0,78)))).angle(A['_wrist']-A['_elbow'])),1))
    print(F, out)
