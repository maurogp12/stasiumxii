from genE import *
from opt import nm, relu
import numpy as np, json, sys
def unpack(x):
    a=x[:7]; b=x[7:]
    return dict(R=dict(el=(a[0],a[1],-70.0),fa=(a[2],0.93,a[3]),haft=a[4],yaw=a[5],wf=a[6]),
                L=dict(direct=dict(grip=(b[0],b[1],b[2]),pole=(-12.0,-25.0,-69.0),haft=b[3],yaw=b[4],wf=b[5])))
best=[1e9,None]
def evalx(x, verbose=False):
    sp=unpack([float(t) for t in x])
    try: P,_=build('E',sp)
    except Exception as e:
        import traceback; traceback.print_exc(); return 1e6
    setE(P['R'],P['L'])
    pen=0.0
    hs=[]; elm={'R':1e9,'L':1e9}; 
    for f in [None]+list(range(12)):
        J,M=joints('E',None if f is None else (f+1)%12, f is None)
        hs.append((J['R_head'][1],J['L_head'][1]))
        for n in 'RL': elm[n]=min(elm[n],J[n+'_el'][1]-J['chest'][1])
        if f is None:
            Ji=J; Mi=M
    d=[a-b for a,b in hs]
    pen+=10*relu(abs(d[0])-2)+1.0*max(abs(v) for v in d[1:])
    my=(hs[0][0]+hs[0][1])/2; pen+=2*relu(232-my)+2*relu(my-252)
    pen+=5*relu(4-elm['L'])+5*relu(3-elm['R'])
    pen+=3*relu(193-Ji['L_el'][0])+3*relu(Ji['L_el'][0]-207)+3*relu(303-Ji['R_el'][0])+3*relu(Ji['R_el'][0]-320)
    for n in 'RL':
        p=sp[n] if n=='R' else sp['L']['direct']; pen+=20*relu(-0.6-p['wf'])+20*relu(p['wf']-0.6)+5*relu(25-p['haft'])+5*relu(p['haft']-62)+5*relu(abs(p['yaw'])-30)
        sh=Mi['upperarm_'+n].translation; el=Mi['forearm_'+n].translation; wr=Mi['forearm_'+n]@Vector((0,0,-rig.FORE))
        bend=180-math.degrees((sh-el).angle(wr-el)); pen+=3*relu(85-bend)+3*relu(bend-125)
        pen+=2*relu(138-Mi['axe_'+n].translation.z)
    pen+=4*relu(203-Ji['L_grip'][0])+20*relu(sp['R']['fa'][0]-0.6)
    hits,low=collide('E')
    pen+=15*len(hits)+5*relu(9-low)
    if pen<best[0]:
        best[0]=pen; best[1]=list(map(float,x))
        if verbose or True: print('%.2f'%pen,'d0 %.1f walk %.1f..%.1f my %.0f elm L %.0f R %.0f hits %d low %.1f'%(d[0],min(d[1:]),max(d[1:]),my,elm['L'],elm['R'],len(hits),low),flush=True)
    return pen
x0=[10,-38,0.55,0.12,48,27,-0.6, 68,23,-79,55,0,-0.4]
if len(sys.argv)>1 and sys.argv[1]!='-': x0=json.load(open(sys.argv[1]))
step=[4,8,0.2,0.1,6,8,0.3, 4,8,6,6,8,0.3]
if __name__!="__main__": pass
else:
 for r in range(3):
    x,v=nm(evalx,x0,step,iters=250); x0=list(x); print('restart',r,v,json.dumps([round(float(t),3) for t in x]),flush=True)
 json.dump(best[1],open(sys.argv[2] if len(sys.argv)>2 else 'bestE2.json','w'))
