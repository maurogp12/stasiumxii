import sys; jf=sys.argv[1]
from genE import *
from gridL import legcol
from prev import *
import json
a=json.load(open(jf))
LF=dict(grip=(78.0,32.0,-72.0),pole=(-12.0,-25.0,-69.0),haft=a[7],yaw=a[8],wf=a[9])
sp=dict(R=dict(el=(a[0],a[1],-70.0),fa=(a[2],0.93,a[3]),haft=a[4],yaw=a[5],wf=a[6]),L=dict(direct=LF))
PP,_=build('E',sp); setE(PP['R'],PP['L']); print(json.dumps(PP))
setS(dict(grip=(101,15,-49),haft=5.0,yaw=30.0,pole=(0.7,-0.5,-1.0),wf=0.2),dict(fist_x=92.0,reach=52.0,bend=100.0,haft=34.0,yaw=0.0,pole=(0.5,-1.0,-0.1),wf=-0.2))
report('E',coll=True)
d,h=dys('E'); print('dy',d); print('Rhead',[round(t[0]) for t in h]); print('Lhead',[round(t[1]) for t in h])
J,M=joints('E',None,True)
for n in 'RL':
    sh=M['upperarm_'+n].translation; el=M['forearm_'+n].translation; wr=M['forearm_'+n]@Vector((0,0,-rig.FORE))
    print(n,'grip',f1(J[n+'_grip']),'el3',[round(v) for v in el],'grip3',[round(v) for v in M['axe_'+n].translation],'bend %.0f'%(180-math.degrees((sh-el).angle(wr-el))))
big(jf.replace('.json','_E.png'),'E',[None,1,7])
