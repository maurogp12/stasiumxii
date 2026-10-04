from genE import *
import itertools
R0=dict(el=(6,-15,-71),fa=(0.5,0.93,0.1),haft=60,yaw=20)
for lel,lfa,lh,ly in itertools.product([(0,-30,-69),(-4,-36,-66)],[(-0.2,0.92,0.1),(0.0,0.92,0.0),(-0.3,0.9,-0.1)],[50,60],[0,-15]):
    spec=dict(R=R0,L=dict(el=lel,fa=lfa,haft=lh,yaw=ly))
    P,_=build('E',spec); setE(P['R'],P['L'])
    d,h=dys('E')
    J,M=joints('E',None,True)
    els=[round(joints('E',(f+1)%12,False)[0]['L_el'][1]-joints('E',(f+1)%12,False)[0]['chest'][1]) for f in range(12)]
    print(lel,lfa,lh,ly,'idle dy',d[0],'headR',f1(J['R_head']),'headL',f1(J['L_head']),'gripL',f1(J['L_grip']),'elL',f1(J['L_el']),'Lel-chest walk',min(els),max(els),'grip3L',[round(v) for v in M['axe_L'].translation])
