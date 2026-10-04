from genE import *
import sys, collections
spec=eval(sys.argv[1])
P,_=build('E',spec); setE(P['R'],P['L']); print(P)
hits,low=collide('E')
c=collections.defaultdict(list)
for ph,a,b in hits: c[(a,b)].append(ph)
for k,v in sorted(c.items()): print(k,v)
print('low',round(low,1))
