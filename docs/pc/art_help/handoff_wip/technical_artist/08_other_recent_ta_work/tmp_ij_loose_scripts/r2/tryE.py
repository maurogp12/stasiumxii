from lev import *
import sys, ast
R=eval(sys.argv[1]); L=eval(sys.argv[2])
setE(R,L)
J,M=joints('E',None,True)
for n in 'RL':
    sh=M['upperarm_'+n].translation; el=M['forearm_'+n].translation; wr=M['forearm_'+n]@Vector((0,0,-rig.FORE))
    print(n,'sh3',[round(v) for v in sh],'el3',[round(v) for v in el],'grip3',[round(v) for v in M['axe_'+n].translation],'bend %.0f'%(180-math.degrees((sh-el).angle(wr-el))),'UA down %.0f'%math.degrees(math.asin(max(-1,min(1,(sh.z-el.z)/rig.UPPER)))))
print('hips3',[round(v) for v in M['thigh_R'].translation],[round(v) for v in M['thigh_L'].translation])
report('E', coll=len(sys.argv)>3)
d,h=dys('E'); print('dys idle',d[0],'walk',d[1:]); print('Rhead',[round(a[0]) for a in h],'\nLhead',[round(a[1]) for a in h])
