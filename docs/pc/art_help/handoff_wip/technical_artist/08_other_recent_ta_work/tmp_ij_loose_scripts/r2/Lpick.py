from gridL import legcol
from genE import *
import itertools
R=dict(grip=(87.86,39.12,-49.53),haft=49.3,yaw=22.6,pole=(38.585,-28.074,-56.56),wf=-0.6)
for gy,gz,hf,yw,wf in itertools.product([25,32],[-76,-72],[56,60],[10,20],[-0.6,-0.3]):
    L=dict(grip=(78.0,gy,gz),pole=(-12.0,-25.0,-69.0),haft=hf,yaw=yw,wf=wf)
    setE(R,L); J,M=joints('E',None,True); h,pel,low=legcol('E','L')
    ys=[joints('E',f,False)[0]['L_head'][1] for f in range(12)]
    print(gy,gz,hf,yw,wf,'grip',f1(J['L_grip']),'head',f1(J['L_head']),'walk headL %.0f..%.0f'%(min(ys),max(ys)),'el',f1(J['L_el']),'leg',len(h),'pel',len(pel),'low %.0f'%low)
