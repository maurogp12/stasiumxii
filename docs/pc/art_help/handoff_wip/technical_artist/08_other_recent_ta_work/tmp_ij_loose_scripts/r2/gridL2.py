from gridL import legcol
from genE import *
import itertools
R=dict(grip=(92.68,42.84,-44.46),haft=30.9,yaw=20.0,pole=(39.86,-25.93,-56.7),wf=-1.0)
for gx,gy,gz,hf,yw,wf in itertools.product([80,88],[10,25,40],[-110,-100,-90],[40,50,60],[10,25],[0.0,-0.6]):
    L=dict(grip=(gx,gy,gz),pole=(-26.0,-26.0,-64.0),haft=hf,yaw=yw,wf=wf)
    setE(R,L); J,M=joints('E',None,True); h,pel,low=legcol('E','L')
    if h: continue
    ws=[joints('E',f,False)[0] for f in range(12)]
    ys=[w['L_head'][1] for w in ws]; els=[w['L_el'][1]-w['chest'][1] for w in ws]
    sh=M['upperarm_L'].translation; el=M['forearm_L'].translation; wr=M['forearm_L']@Vector((0,0,-rig.FORE))
    bend=180-math.degrees((sh-el).angle(wr-el))
    print(gx,gy,gz,hf,yw,wf,'grip',f1(J['L_grip']),'head',f1(J['L_head']),'walk %.0f..%.0f'%(min(ys),max(ys)),'el',f1(J['L_el']),'elwalk %.0f..%.0f'%(min(els),max(els)),'bend %.0f'%bend,'pel',len(pel),'low %.0f'%low,flush=True)
