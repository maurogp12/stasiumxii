from genE import *
import itertools
L0=dict(el=(0,-30,-69),fa=(-0.2,0.92,0.2),haft=50,yaw=0)
for lat,up,hf,yw in itertools.product([0.3,0.5,0.7],[0.0,0.15],[50,58],[0,20]):
    spec=dict(R=dict(el=(6,-15,-71),fa=(lat,0.93,up),haft=hf,yaw=yw),L=L0)
    P,_=build('E',spec); setE(P['R'],P['L'])
    J,M=joints('E',None,True)
    sh=M['upperarm_R'].translation; el=M['forearm_R'].translation; wr=M['forearm_R']@Vector((0,0,-rig.FORE))
    print(lat,up,hf,yw,'gripR',f1(J['R_grip']),'headR',f1(J['R_head']),'elR',f1(J['R_el']),'grip3',[round(v) for v in M['axe_R'].translation],'bend %.0f'%(180-math.degrees((sh-el).angle(wr-el))))
