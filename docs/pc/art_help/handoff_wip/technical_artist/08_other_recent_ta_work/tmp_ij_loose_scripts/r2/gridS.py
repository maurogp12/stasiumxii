from opt import *
import itertools
F='S'
res=[]
def setR(fx,rc,bd,hf,yw,pole=(0.5,-1.0,-0.1)):
    rig.ARM[('S','R')]=dict(fist_x=fx,reach=rc,bend=bd,haft=hf,yaw=yw,pole=pole)
for lh in (28,32,36):
    rig.ARM[('S','L')]=dict(fist_x=92.0,reach=52.0,bend=100.0,haft=float(lh),yaw=0.0,pole=(0.5,-1.0,-0.1))
    JL,_=joints(F,None,True); Lh=JL['L_head']
    for fx,rc,bd,hf,yw in itertools.product((96,104,112,120),(25,32,39,46),(90,100,110),(5,12,19,26),(0,10,20,30)):
        setR(fx,rc,bd,hf,yw); J,M=joints(F,None,True)
        z=M['axe_R'].translation.z; shz=M['upperarm_R'].translation.z; elz=M['forearm_R'].translation.z
        if z>180 or elz>shz-45: continue
        c=(J['R_grip'][0]-178)**2 + 2*relu(J['R_head'][0]-194)**2 + 4*(J['R_head'][1]-Lh[1])**2 + 0.5*(J['R_head'][1]-232)**2 + 0.3*yw**2 + 2*(lh-28)**2 + 0.5*(bd-100)**2
        res.append((c,lh,fx,rc,bd,hf,yw,[round(v) for v in J['R_grip']],[round(v) for v in J['R_head']],[round(v) for v in Lh],round(z),[round(v) for v in J['R_el']]))
res.sort()
for r in res[:15]: print(r)
