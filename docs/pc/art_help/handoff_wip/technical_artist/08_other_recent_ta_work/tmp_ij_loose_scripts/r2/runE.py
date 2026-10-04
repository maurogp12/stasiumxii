from genE import *
import sys
spec=eval(sys.argv[1]); P,(e1,e2)=build('E',spec); print('e1',e1,'e2',e2); print(P)
setE(P['R'],P['L'])
J,M=joints('E',None,True)
for n in 'RL':
    sh=M['upperarm_'+n].translation; el=M['forearm_'+n].translation; wr=M['forearm_'+n]@Vector((0,0,-rig.FORE))
    print(n,'sh3',[round(v) for v in sh],'el3',[round(v) for v in el],'grip3',[round(v) for v in M['axe_'+n].translation],'bend %.0f'%(180-math.degrees((sh-el).angle(wr-el))))
report('E', coll=len(sys.argv)>2)
d,h=dys('E'); print('Rhead',[round(a[0]) for a in h],'\nLhead',[round(a[1]) for a in h]); print('Rheadx',round(h[0][2]),'Lheadx',round(h[0][3]),'gripR',[round(v) for v in h[0][4]],'gripL',[round(v) for v in h[0][5]])
