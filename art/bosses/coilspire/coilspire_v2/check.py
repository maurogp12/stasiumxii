import numpy as np, json
from anim import *
res={}
for dn in 'nesw':
    side,mir=MAP[dn]; R=RIG[side]; dv=np.array(DV[dn],float); dv/=np.linalg.norm(dv)
    slips=[]; cnt=[]; prev=None; bodies=[]
    for n in range(0,144):
        t=n/FPS; st=[]; o,tips,bob=sprite(side,t,st); cnt.append(sum(1 for c in st if c>=1))
        bp=np.array([480,330])+dv*(P0+(P1-P0)*t/DUR); bodies.append(bp)
        scr=[]
        for (x,y,l) in tips:
            if mir: x=R['W']-x
            scr.append(np.array([bp[0]-R['W']/2*K+x*K,bp[1]-R['gy']*K+y*K]))
        if prev is not None:
            for i,(lp,lc) in enumerate(zip(prev[1],tips)):
                if lp[2]==0 and lc[2]==0 and ((t/T+RIG[side]['legs'][i]['g']*.5)%1)<0.5 and (((t-1/FPS)/T+RIG[side]['legs'][i]['g']*.5)%1)<0.5: slips.append(float(np.linalg.norm(scr[i]-prev[0][i])))
        prev=(scr,tips)
    tv=(bodies[-1]-bodies[0]); tv/=np.linalg.norm(tv)
    res[dn]=dict(travel=[round(float(tv[0]),3),round(float(tv[1]),3)],facing=[round(float(dv[0]),3),round(float(dv[1]),3)],planted_slip_max_px=round(max(slips),3),legs_min=min(cnt),legs_max=max(cnt))
    print(dn,res[dn])
json.dump(res,open('check.json','w'),indent=1)
