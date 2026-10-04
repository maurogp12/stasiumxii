import sys
sys.path.insert(0,'/workspace/art_src/blockout/ironjaw_walk/src')
import bpy
from mathutils.bvhtree import BVHTree
import rig, model
P=model.parts()
def tree(M,k):
    v,f=P[k]; return BVHTree.FromPolygons([M[k]@x for x in v], f)
from collections import Counter
c=Counter()
for F in 'SE':
    for ph in list(range(12))+[None]:
        M=rig.pose(ph, idle=ph is None, cheat=rig.CHEAT[F])
        for n in 'RL':
            for k in ('axe','hand','forearm','upperarm'):
                t=tree(M,k+'_'+n)
                for o in ('pelvis','chest','cape_up','cape_lo','head'):
                    if t.overlap(tree(M,o)): c[(F,k+'_'+n,o)]+=1
for k,v in sorted(c.items()): print(k,v,'frames')
