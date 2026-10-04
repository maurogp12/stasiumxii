from opt import *
F='S'
base=dict(rig.ARM[('S','R')])
def setp(x):
    fx,rc,bd,hf,yw,lh,lr=x
    rig.ARM[('S','R')]=dict(fist_x=fx,reach=rc,bend=bd,haft=hf,yaw=yw,pole=(0.5,-1.0,-0.1))
    rig.ARM[('S','L')]=dict(fist_x=92.0,reach=lr,bend=100.0,haft=lh,yaw=0.0,pole=(0.5,-1.0,-0.1))
def obj(x):
    setp(x); J,M=joints(F,None,True)
    fx,rc,bd,hf,yw,lh,lr=x
    c=0
    c+= (J['R_grip'][0]-183.6)**2
    c+= 4*relu(J['R_head'][0]-200)**2
    c+= 4*(J['R_head'][1]-J['L_head'][1])**2
    c+= 0.5*(J['R_head'][1]-232)**2 + 0.5*(J['L_head'][1]-232)**2
    c+= 2*relu(J['L_head'][1]-240)**2 + 2*relu(212-J['L_head'][1])**2
    c+= 0.3*(lh-28)**2 + 0.3*(lr-52)**2
    c+= 0.05*yw**2 + 5*relu(hf-45)**2 + 5*relu(12-hf)**2
    c+= 5*relu(bd-120)**2 + 5*relu(80-bd)**2 + 5*relu(fx-125)**2
    z=M['axe_R'].translation.z; c+= 2*relu(z-166)**2       # fist no higher than ~belt+
    shz=M['upperarm_R'].translation.z; elz=M['forearm_R'].translation.z; c+= 3*relu(elz-(shz-55))**2
    lo=1e9
    for f in (0,1,6,7):
        Mw=rig.pose(f,cheat=rig.CHEAT[F],facing=F)
        for n in 'RL': lo=min(lo,min((Mw['axe_'+n]@v).z for v in P['axe_'+n][0][::3]))
    c+= 5*relu(12-lo)**2
    ds=[]
    for f in (0,3,6,9):
        Jw,_=joints(F,f,False); ds.append(Jw['R_head'][1]-Jw['L_head'][1])
    c+= 0.5*np.mean(np.square(ds))
    return c
x0=[92,52,100,28,0,28,52]
x,v=nm(obj,x0,[10,8,8,6,10,5,5],900)
setp(x); print('x',np.round(x,2),'cost',round(v,2))
J,M=joints(F,None,True); print('R fist z %.1f  L fist z %.1f'%(M['axe_R'].translation.z,M['axe_L'].translation.z))
report('S')
