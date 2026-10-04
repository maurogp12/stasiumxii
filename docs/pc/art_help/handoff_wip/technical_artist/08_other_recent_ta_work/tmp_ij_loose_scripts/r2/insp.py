import sys; jf=sys.argv[1]; sys.argv=['x']
exec(open('optE.py').read().split("x0=[")[0])
from prev import *
import json, collections
x=json.load(open(jf)); sp=unpack(x); PP,_=build('E',sp); setE(PP['R'],PP['L']); print(sp); print(PP)
setS(dict(grip=(101,15,-49),haft=5.0,yaw=30.0,pole=(0.7,-0.5,-1.0),wf=0.2),dict(fist_x=92.0,reach=52.0,bend=100.0,haft=34.0,yaw=0.0,pole=(0.5,-1.0,-0.1),wf=-0.2))
hits,low=collide('E'); c=collections.defaultdict(list)
for ph,a,b in hits: c[(a,b)].append(ph)
print(dict(c), 'low', round(low,1))
report('E',coll=False)
J,M=joints('E',None,True)
for n in 'RL':
    sh=M['upperarm_'+n].translation; el=M['forearm_'+n].translation; wr=M['forearm_'+n]@Vector((0,0,-rig.FORE))
    print(n,'sh3',[round(v) for v in sh],'el3',[round(v) for v in el],'grip3',[round(v) for v in M['axe_'+n].translation],'bend %.0f'%(180-math.degrees((sh-el).angle(wr-el))))
d,h=dys('E'); print('dy',d)
big('big_E.png','E',[None,1,7])
