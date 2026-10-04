from genE import *
from gridL import legcol
from opt import nm, relu
import numpy as np, json, sys
LFIX=dict(grip=(78.0,32.0,-72.0),pole=(-12.0,-25.0,-69.0),haft=56.0,yaw=20.0,wf=-0.6)
best=[1e9,None]
WFMIN=float(sys.argv[1])
def evalx(x):
    a=[float(t) for t in x]
    sp=dict(R=dict(el=(a[0],a[1],-70.0),fa=(a[2],0.93,a[3]),haft=a[4],yaw=a[5],wf=a[6]),L=dict(direct=LFIX))
    P_,_=build('E',sp); setE(P_['R'],P_['L'])
    hs=[]; elm=1e9
    for f in [None]+list(range(12)):
        J,M=joints('E',None if f is None else (f+1)%12, f is None)
        hs.append((J['R_head'][1],J['L_head'][1])); elm=min(elm,J['R_el'][1]-J['chest'][1])
        if f is None: Ji,Mi=J,M
    d=[p-q for p,q in hs]
    pen=10*relu(abs(d[0])-1.5)+2*max(abs(v) for v in d[1:])
    pen+=5*relu(4-elm)+3*relu(303-Ji['R_el'][0])+3*relu(Ji['R_el'][0]-318)
    pen+=300*relu(WFMIN-a[6])+300*relu(a[6]-0.6)+5*relu(30-a[4])+5*relu(a[4]-62)+5*relu(abs(a[5])-30)
    sh=Mi['upperarm_R'].translation; el=Mi['forearm_R'].translation; wr=Mi['forearm_R']@Vector((0,0,-rig.FORE))
    bend=180-math.degrees((sh-el).angle(wr-el)); pen+=3*relu(85-bend)+3*relu(bend-125)
    pen+=20*relu(a[2]-0.6)
    h,pel,low=legcol('E','R'); pen+=15*len(h)+15*len(pel)+5*relu(9-low)
    if pen<best[0]:
        best[0]=pen; best[1]=a
        print('%.2f d0 %.1f walk %.1f..%.1f headR %.0f elR %s elm %.0f bend %.0f leg %d pel %d low %.1f'%(pen,d[0],min(d[1:]),max(d[1:]),hs[0][0],f1(Ji['R_el']),elm,bend,len(h),len(pel),low),flush=True)
    return pen
x0=[21.6,-50.9,0.6,0.39,34,22.7,WFMIN]
step=[4,8,0.2,0.1,6,8,0.3]
for r in range(3):
    x,v=nm(evalx,x0,step,iters=200); x0=list(x); print('restart',r,v,json.dumps([round(float(t),3) for t in x]),flush=True)
json.dump(best[1],open('bestRE_%s.json'%sys.argv[1],'w'))
