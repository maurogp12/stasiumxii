from lev import *
import itertools
for lh,wl,wr,gz in itertools.product([28,34],[-0.2,-0.4],[0.4,0.2],[-52,-50,-48]):
    L=dict(fist_x=92.0,reach=52.0,bend=100.0,haft=float(lh),yaw=0.0,pole=(0.5,-1.0,-0.1),wf=wl)
    R=dict(grip=(101,15,gz),haft=5.0,yaw=30.0,pole=(0.7,-0.5,-1.0),wf=wr)
    setS(R,L); d,h=dys('S')
    print(lh,wl,wr,gz,'idle',d[0],'walk',min(d[1:]),max(d[1:]),'maxabs',max(abs(x) for x in d),'Rhead',round(h[0][2]),round(h[0][0]),'Rgrip',round(h[0][4][0]),round(h[0][4][1]))
