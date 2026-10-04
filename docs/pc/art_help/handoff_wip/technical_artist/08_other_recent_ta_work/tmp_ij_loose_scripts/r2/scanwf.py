from lev import *
import itertools
R=dict(grip=(105,15,-52),haft=10.0,yaw=30.0,pole=(0.7,-0.5,-1.0))
L=dict(fist_x=92.0,reach=52.0,bend=100.0,haft=28.0,yaw=0.0,pole=(0.5,-1.0,-0.1))
for wr,wl in itertools.product([0.4,0,-0.4,-0.8],[0.4,0,-0.4,-0.8]):
    R['wf']=wr; L['wf']=wl; setS(R,L); d,h=dys('S')
    print(wr,wl,'idle',d[0],'walk',min(d[1:]),max(d[1:]),'Ry',round(min(a[0] for a in h[1:])),round(max(a[0] for a in h[1:])),'Ly',round(min(a[1] for a in h[1:])),round(max(a[1] for a in h[1:])))
