from genE import *
from gridL import legcol
from lev import dys
import itertools, json
base=dict(rig.ARM[('E','L')]); out=[]
for gx,gy,gz,hf,yw in itertools.product([66,72,78],[15.7,28,40],[-75,-68,-60],[50,56,62,68],[0,7.7,15]):
    L=dict(base); L.update(grip=(float(gx),float(gy),float(gz)),haft=float(hf),yaw=float(yw)); rig.ARM[('E','L')]=L
    J,M=joints('E',None,True)
    d,hh=dys('E')
    if not (194<=J["L_head"][1]<=214) or (max(d[1:])-min(d[1:]))>8: continue
    els=[joints('E',f,False)[0] for f in range(12)]; elm=min(w['L_el'][1]-w['chest'][1] for w in els)
    if elm<-1: continue
    h,pel,low=legcol('E','L')
    if h or low<9: continue
    out.append(dict(L=L,headL=J['L_head'],gripL=J['L_grip'],d0=d[0],walk=(min(d[1:]),max(d[1:])),elm=elm,low=low,pel=len(pel)))
    print(gx,gy,gz,hf,yw,'head',f1(J['L_head']),'grip',f1(J['L_grip']),'d0 %.1f'%d[0],'walk %.1f..%.1f'%(min(d[1:]),max(d[1:])),'elm %.0f low %.1f pel %d'%(elm,low,len(pel)),flush=True)
json.dump(out,open('candL.json','w'))
