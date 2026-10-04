from genE import *
import itertools, collections
def legcol(F, side):
    hits=set(); pel=set(); low=1e9
    for ph in list(range(12))+[None]:
        M=rig.pose(ph,idle=ph is None,cheat=rig.CHEAT[F],facing=F)
        tr={k:BVHTree.FromPolygons([M[k]@v for v in P[k][0]],P[k][1]) for k in P}
        n=side
        for k in ('axe_','hand_','forearm_','upperarm_'):
            for o in 'RL':
                for lk in ('thigh_','shin_','boot_'):
                    if tr[k+n].overlap(tr[lk+o]): hits.add((ph,k+n,lk+o))
            if k!='upperarm_' and tr[k+n].overlap(tr['pelvis']): pel.add((ph,k+n))
        low=min(low,min((M['axe_'+n]@v).z for v in P['axe_'+n][0]))
    return hits,pel,low
if __name__=="__main__":
    R=dict(grip=(87.86,39.12,-49.53),haft=49.3,yaw=22.6,pole=(38.585,-28.074,-56.56),wf=-0.6)
    res=[]
    for gx,gy,gz,hf,yw in itertools.product([66,72,78],[25,40,55],[-80,-70,-60],[55,65],[0,30]):
        L=dict(grip=(gx,gy,gz),pole=(-12.0,-25.0,-69.0),haft=hf,yaw=yw,wf=-0.6)
        setE(R,L); J,M=joints('E',None,True)
        h,pel,low=legcol('E','L')
        sh=M['upperarm_L'].translation; el=M['forearm_L'].translation; wr=M['forearm_L']@Vector((0,0,-rig.FORE))
        bend=180-math.degrees((sh-el).angle(wr-el))
        print(gx,gy,gz,hf,yw,'grip',f1(J['L_grip']),'head',f1(J['L_head']),'el',f1(J['L_el']),'bend %.0f'%bend,'leg',len(h),'pel',len(pel),'low %.0f'%low)
    