from lev import *
import itertools
R=dict(grip=(105,15,-52),haft=10.0,yaw=30.0,pole=(0.7,-0.5,-1.0),wf=0.4)
for lh,wl in itertools.product([34,36,38,40,42],[0.0,-0.2,-0.4]):
    L=dict(fist_x=92.0,reach=52.0,bend=100.0,haft=float(lh),yaw=0.0,pole=(0.5,-1.0,-0.1),wf=wl)
    setS(R,L); d,h=dys('S')
    print(lh,wl,'idle',d[0],'walk',min(d[1:]),max(d[1:]),'maxabs',max(abs(x) for x in d),'Lhead idle',round(h[0][3]),round(h[0][1]))
