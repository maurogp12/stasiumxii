import numpy as np, sys
sys.path.insert(0,'.')
from rig_core import *
for fac in 'SE':
  for side in 'RL':
    nm=f'{side}_forearm'; d=PARTS[fac][nm]; im=load_part(fac,nm); m=im[...,3]>0
    G=np.array(d['G'],float); H=np.array(d['H'],float); E=np.array(d['E'],float)
    u=(H-G)/np.linalg.norm(H-G); n=np.array([-u[1],u[0]])
    yy,xx=np.nonzero(m); t=(xx-G[0])*u[0]+(yy-G[1])*u[1]; p=(xx-G[0])*n[0]+(yy-G[1])*n[1]
    TH=np.linalg.norm(H-G)
    prof=[]
    for t0 in range(-260,400,20):
      s=(t>=t0)&(t<t0+20)
      prof.append((t0, int(p[s].min()) if s.any() else None, int(p[s].max()) if s.any() else None))
    print(fac,side,'TH',round(TH),'E->G',round(np.linalg.norm(G-E)),'angle E->G vs G->H', round(np.degrees(np.arccos(np.dot((G-E)/np.linalg.norm(G-E),u))),1))
    print('  ',' '.join(f'{a}:{b}..{c}' for a,b,c in prof if b is not None))
