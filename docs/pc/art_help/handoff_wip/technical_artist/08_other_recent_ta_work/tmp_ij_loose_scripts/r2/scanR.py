from lev import *
import itertools
L=dict(fist_x=92.0,reach=52.0,bend=100.0,haft=34.0,yaw=0.0,pole=(0.5,-1.0,-0.1),wf=-0.2)
for hf,yw,gz in itertools.product([0,5,10],[20,30,40],[-52,-47]):
    R=dict(grip=(105,15,gz),haft=float(hf),yaw=float(yw),pole=(0.7,-0.5,-1.0),wf=0.4)
    setS(R,L); d,h=dys('S')
    g=h[0][4]
    print(hf,yw,gz,'idle',d[0],'walk',min(d[1:]),max(d[1:]),'Rhead',round(h[0][2]),round(h[0][0]),'Rgrip',round(g[0]),round(g[1]))
