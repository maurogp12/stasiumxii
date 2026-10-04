from genE import *
import itertools
for wr,wl in itertools.product([0.4,0.0,-0.4,-0.8],[0.4,0.0,-0.4,-0.8]):
    spec=dict(R=dict(el=(6,-15,-71),fa=(0.5,0.93,0.1),haft=60,yaw=20,wf=wr),L=dict(el=(-4,-36,-66),fa=(-0.3,0.9,-0.1),haft=60,yaw=-15,wf=wl))
    P,_=build('E',spec); setE(P['R'],P['L'])
    d,h=dys('E')
    print(wr,wl,'idle',d[0],'walk',min(d[1:]),max(d[1:]),'R',round(min(a[0] for a in h[1:])),round(max(a[0] for a in h[1:])),'L',round(min(a[1] for a in h[1:])),round(max(a[1] for a in h[1:])))
