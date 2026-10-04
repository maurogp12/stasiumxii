import sys, math
sys.path.insert(0,'/workspace/art_src/blockout/ironjaw_walk/src')
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import rig, model
P=model.parts()
def tree(M,k):
    v,f=P[k]; return BVHTree.FromPolygons([M[k]@x for x in v], f)
hits=[]; low=1e9; lowat=None
for F in 'SE':
    for ph in list(range(12))+[None]:
        M=rig.pose(ph, idle=ph is None, cheat=rig.CHEAT[F])
        legs={k+'_'+o:tree(M,k+'_'+o) for o in 'RL' for k in ('thigh','shin','boot')}
        for n in 'RL':
            for k in ('axe','hand','forearm','upperarm'):
                t=tree(M,k+'_'+n)
                for lk,lt in legs.items():
                    if t.overlap(lt): hits.append((F,ph,k+'_'+n,lk))
            z=min((M['axe_'+n]@v).z for v in P['axe_'+n][0])
            if z<low: low,lowat=z,(F,ph,n)
print('intersections arm/axe vs legs:', hits if hits else 'none')
print('lowest axe point z = %.1f at'%low, lowat)
