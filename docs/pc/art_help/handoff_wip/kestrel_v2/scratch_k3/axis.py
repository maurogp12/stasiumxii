import sys,math
sys.path.insert(0,'/workspace/handoff/class_walk_blockouts/kestrel/v2/scripts')
import kbuild as K, numpy as np
for F in 'SE':
  if len(sys.argv)>1: K.KCFG[F]['hip_w']=float(sys.argv[1])
  K._LG.clear(); pl=K.plants(F)
  for i in range(12):
    r=[]
    for s in 'RL':
      g=K.leg_geo(F,i,s); v=g['an']-g['hip']; ax=math.degrees(math.atan2(v[0],v[1])); t=g['kn']-g['hip']; th=math.degrees(math.atan2(t[0],t[1]))
      ph='F' if pl[s]['heel'][i] and pl[s]['toe'][i] else ('H' if pl[s]['heel'][i] else ('T' if pl[s]['toe'][i] else 's'))
      r.append(f"{s}{ph} axis{ax:6.1f} thigh{th:6.1f} kd{g['kdepth']}")
    # knee distance
    kR,kL=K.leg_geo(F,i,'R')['kn'],K.leg_geo(F,i,'L')['kn']
    print(F,i,' | '.join(r),'kneeDist %.1f'%math.dist(kR,kL))
