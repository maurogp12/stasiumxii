from genE import *
from gridL import legcol
from lev import dys
import sys, json
L=dict(rig.ARM[('E','L')]); L.update({k:(tuple(v) if isinstance(v,list) else v) for k,v in json.loads(sys.argv[1]).items()}); rig.ARM[('E','L')]=L
J,M=joints('E',None,True); h,pel,low=legcol('E','L'); d,hh=dys('E')
els=[joints('E',f,False)[0] for f in range(12)]; elm=min(w['L_el'][1]-w['chest'][1] for w in els)
print(sys.argv[1],'headL',f1(J['L_head']),'elL',f1(J['L_el']),'d0 %.1f walk %.1f..%.1f'%(d[0],min(d[1:]),max(d[1:])),'leg',len(h),'pel',len(pel),'low %.1f elm %.0f'%(low,elm))
