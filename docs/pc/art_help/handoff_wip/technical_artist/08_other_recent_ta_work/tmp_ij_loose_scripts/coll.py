import sys, math
sys.path.insert(0,'/workspace/art_src/blockout/ironjaw_walk/src')
import bpy
from mathutils import Vector
import rig, model
P=model.parts()
worst=1e9
for F in 'SE':
    for ph in list(range(12))+[None]:
        M=rig.pose(ph, idle=ph is None, cheat=rig.CHEAT[F])
        for s,n in ((1,'R'),(-1,'L')):
            leg=[M[k+'_'+n]@v for k in ('thigh','shin','boot') for v in P[k+'_'+n][0]]
            legall=[M[k+'_'+o]@v for o in 'RL' for k in ('thigh','shin','boot') for v in P[k+'_'+o][0]]
            arm=[M[k+'_'+n]@v for k in ('axe','hand') for v in P[k+'_'+n][0]]
            fore=[M['forearm_'+n]@v for v in P['forearm_'+n][0]]
            legmax=max(s*v.x for v in legall); armmin=min(s*v.x for v in arm); foremin=min(s*v.x for v in fore)
            # also z overlap: lowest axe point vs ground
            zmin=min(v.z for v in arm)
            gap=armmin-legmax; worst=min(worst,gap)
            if ph in (0,6,None) or gap<5: print(F,ph,n,'leg max |x| %.1f  axe+fist min |x| %.1f  gap %.1f  forearm min|x| %.1f  axe lowest z %.1f'%(legmax,armmin,gap,foremin,zmin))
print('worst lateral gap legs->axe/fist', round(worst,1))
