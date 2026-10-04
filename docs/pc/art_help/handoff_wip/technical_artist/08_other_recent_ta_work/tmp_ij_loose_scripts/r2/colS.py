from lev import *
import collections
R=dict(grip=(101,15,-49),haft=5.0,yaw=30.0,pole=(0.7,-0.5,-1.0),wf=0.2)
L=dict(fist_x=92.0,reach=52.0,bend=100.0,haft=34.0,yaw=0.0,pole=(0.5,-1.0,-0.1),wf=-0.2)
setS(R,L)
hits,low=collide('S'); c=collections.defaultdict(list)
for ph,a,b in hits: c[(a,b)].append(ph)
for k,v in sorted(c.items()): print(k,v)
print('low',round(low,1)); d,h=dys('S'); print('dy',d)
report('S',coll=False)
