from genE import *
from gridL import legcol
from opt import nm, relu
import numpy as np, json, sys
WFMIN=float(sys.argv[1]); OUT=sys.argv[2]
best=[1e9,None]
def mk(a):
    LF=dict(grip=(a[10],a[11],a[12]),pole=(-26.0,-26.0,-64.0),haft=a[7],yaw=a[8],wf=a[9])
    return dict(R=dict(el=(a[0],a[1],-70.0),fa=(a[2],0.93,a[3]),haft=a[4],yaw=a[5],wf=a[6]),L=dict(direct=LF))
def evalx(x):
    a=[float(t) for t in x]
    P_,_=build('E',mk(a)); setE(P_['R'],P_['L'])
    hs=[]; elR=1e9; elL=1e9
    for f in [None]+list(range(12)):
        J,M=joints('E',None if f is None else (f+1)%12, f is None)
        hs.append((J['R_head'][1],J['L_head'][1])); elR=min(elR,J['R_el'][1]-J['chest'][1]); elL=min(elL,J['L_el'][1]-J['chest'][1])
        if f is None: Ji,Mi=J,M
    d=[p-q for p,q in hs]
    pen=10*relu(abs(d[0])-1.5)+1.5*max(abs(v) for v in d[1:])
    my=(hs[0][0]+hs[0][1])/2; pen+=3*relu(206-my)
    pen+=5*relu(4-elR)+8*relu(1-elL)+3*relu(303-Ji['R_el'][0])+3*relu(Ji['R_el'][0]-318)+3*relu(192-Ji['L_el'][0])+3*relu(Ji['L_el'][0]-206)
    pen+=3*relu(192-Ji['L_grip'][0])
    for w in (a[6],a[9]): pen+=300*relu(WFMIN-w)+300*relu(w-0.6)
    pen+=5*relu(35-a[4])+5*relu(a[4]-62)+5*relu(abs(a[5])-30)+5*relu(40-a[7])+5*relu(a[7]-62)+5*relu(abs(a[8])-30)
    for n in 'RL':
        sh=Mi['upperarm_'+n].translation; el=Mi['forearm_'+n].translation; wr=Mi['forearm_'+n]@Vector((0,0,-rig.FORE))
        bend=180-math.degrees((sh-el).angle(wr-el)); pen+=3*relu(80-bend)+3*relu(bend-125)
    pen+=20*relu(a[2]-0.6)
    h,pel,low=legcol('E','R'); h2,pel2,low2=legcol('E','L')
    pen+=15*len(h)+15*len(pel)+15*len(h2)+1.5*len(pel2)+8*relu(9-min(low,low2))
    if pen<best[0]:
        best[0]=pen; best[1]=a
        print('%.2f d0 %.1f walk %.1f..%.1f my %.0f elR %s elL %s elm R %.0f L %.0f leg %d pel %d/%d low %.1f'%(pen,d[0],min(d[1:]),max(d[1:]),my,f1(Ji['R_el']),f1(Ji['L_el']),elR,elL,len(h)+len(h2),len(pel),len(pel2),min(low,low2)),flush=True)
    return pen
x0=[21.6,-50.9,0.6,0.30,42,20,WFMIN, 54,15,WFMIN, 80,15,-80]
step=[4,8,0.2,0.1,6,8,0.3, 5,8,0.3, 5,8,6]
for r in range(4):
    x,v=nm(evalx,x0,step,iters=250); x0=list(x); print('restart',r,v,json.dumps([round(float(t),3) for t in x]),flush=True)
json.dump(best[1],open(OUT,'w'))
