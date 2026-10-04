from genE import *
import itertools
L0=dict(el=(0,-30,-69),fa=(-0.2,0.92,0.2),haft=50,yaw=0)
for up,hf,yw in itertools.product([0.0,0.15,0.3],[45,52,60],[0,15]):
    spec=dict(R=dict(el=(6,-15,-71),fa=(0.0,0.93,up),haft=hf,yaw=yw),L=L0)
    P,_=build('E',spec); setE(P['R'],P['L'])
    J,M=joints('E',None,True)
    print(up,hf,yw,'gripR',f1(J['R_grip']),'headR',f1(J['R_head']),'elR',f1(J['R_el']),'| gripL',f1(J['L_grip']),'headL',f1(J['L_head']),'elL',f1(J['L_el']),'grip z %.0f'%M['axe_R'].translation.z)
