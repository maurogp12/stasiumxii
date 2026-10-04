from genE import *
from gridL import legcol
from lev import dys
import itertools
base=dict(rig.ARM[('E','L')])
for yw,hf in itertools.product([7.7,-5,-15,-25,-35],[50,54.7,60]):
    L=dict(base); L.update(yaw=float(yw),haft=float(hf)); rig.ARM[('E','L')]=L
    J,M=joints('E',None,True); h,pel,low=legcol('E','L'); d,hh=dys('E')
    print(yw,hf,'headL',f1(J['L_head']),'dy idle %.1f walk %.1f..%.1f'%(d[0],min(d[1:]),max(d[1:])),'leg',len(h),'low %.1f'%low)
rig.ARM[('E','L')]=base
