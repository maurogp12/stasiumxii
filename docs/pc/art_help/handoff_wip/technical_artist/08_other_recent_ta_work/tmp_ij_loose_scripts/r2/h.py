import sys, math, json
sys.path.insert(0,'/workspace/art_src/blockout/ironjaw_walk/src')
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
import rig, model
B='/workspace/art_src/blockout/ironjaw_walk'
meta=json.load(open(B+'/qa/model_meta.json')); XO,YO,SPX=meta['XO'],meta['YO'],meta['px_per_unit']; Rv=Vector(meta['Rv']); Uv=Vector(meta['Uv'])
OFF={'S':(26,15),'E':(26,31)}; FY={'S':-90.0,'E':0.0}; PH={'S':0,'E':1}
P=model.parts()
hc=sum((Vector((0,y,z)) for y,z in model.AXE_HEAD),Vector())/len(model.AXE_HEAD)
def pj(p,F): return (XO+SPX*Rv.dot(p)+OFF[F][0], YO-SPX*Uv.dot(p)+OFF[F][1])
def joints(F,ph,idle):
    root=Matrix.Rotation(math.radians(FY[F]),4,'Z'); M=rig.pose(ph,idle=idle,cheat=rig.CHEAT[F],facing=F)
    J={'chest':pj(root@M['chest'].translation,F),'pelvis':pj(root@M['pelvis'].translation,F)}
    for n in 'RL':
        J[n+'_sh']=pj(root@M['upperarm_'+n].translation,F); J[n+'_el']=pj(root@M['forearm_'+n].translation,F)
        J[n+'_wr']=pj(root@(M['forearm_'+n]@Vector((0,0,-rig.FORE))),F); J[n+'_grip']=pj(root@M['axe_'+n].translation,F)
        J[n+'_head']=pj(root@(M['axe_'+n]@hc),F); J[n+'_hip']=pj(root@M['thigh_'+n].translation,F); J[n+'_knee']=pj(root@(M['thigh_'+n]@Vector((0,0,-rig.THIGH))),F)
    return J,M
def collide(F):
    hits=set(); low=1e9
    for ph in list(range(12))+[None]:
        M=rig.pose(ph,idle=ph is None,cheat=rig.CHEAT[F],facing=F)
        tr={k:BVHTree.FromPolygons([M[k]@v for v in P[k][0]],P[k][1]) for k in P}
        for n in 'RL':
            for k in ('axe_','hand_','forearm_','upperarm_'):
                for o in 'RL':
                    for lk in ('thigh_','shin_','boot_'):
                        if tr[k+n].overlap(tr[lk+o]): hits.add((ph,k+n,lk+o))
                for o in ('pelvis','cape_lo','cape_up') if k!='upperarm_' else ():
                    if tr[k+n].overlap(tr[o]): hits.add((ph,k+n,o))
            low=min(low,min((M['axe_'+n]@v).z for v in P['axe_'+n][0]))
    return sorted(hits,key=str), low
def f1(p): return '(%.0f,%.0f)'%p
def report(F, walk=True, coll=True):
    J,_=joints(F,None,True)
    print('== %s idle  chest %s  shR %s elR %s gripR %s headR %s | shL %s elL %s gripL %s headL %s | hipR %s kneeR %s hipL %s kneeL %s'%(F,f1(J['chest']),f1(J['R_sh']),f1(J['R_el']),f1(J['R_grip']),f1(J['R_head']),f1(J['L_sh']),f1(J['L_el']),f1(J['L_grip']),f1(J['L_head']),f1(J['R_hip']),f1(J['R_knee']),f1(J['L_hip']),f1(J['L_knee'])))
    print('   head dy R-L = %.1f'%(J['R_head'][1]-J['L_head'][1]))
    if walk:
        ds=[];els=[]
        for f in range(12):
            Jw,_=joints(F,(f+PH[F])%12,False); ds.append(round(Jw['R_head'][1]-Jw['L_head'][1],1))
            els.append((round(Jw['L_el'][1]-Jw['chest'][1]),round(Jw['R_el'][1]-Jw['chest'][1])))
        print('   walk head dy R-L:',ds)
        print('   walk elbow y - chest y (L,R):',els)
    if coll:
        h,low=collide(F); print('   collisions:',h[:8],len(h),' lowest axe z %.1f'%low)
    return J
if __name__=='__main__':
    for F in 'SE': report(F)
