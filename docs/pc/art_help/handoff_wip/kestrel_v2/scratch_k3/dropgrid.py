import sys,math
sys.path.insert(0,'/workspace/handoff/class_walk_blockouts/kestrel/v2/scripts')
import kbuild as K, numpy as np
F=sys.argv[1]; ds=[float(x) for x in sys.argv[2].split(',')]
pl=K.plants(F)
for d in ds:
  K.KCFG[F]['drop']=d; K._LG.clear(); out=[]
  worst_full=0; worst_any=0; bends={}
  for s in 'RL':
    for i in range(12):
      g=K.leg_geo(F,i,s); full=pl[s]['heel'][i] and pl[s]['toe'][i]; hs=pl[s]['heel'][i]; to=pl[s]['toe'][i]
      if full or hs: worst_full=max(worst_full,g['ratio'])
      worst_any=max(worst_any,g['ratio'])
      v1=g['kn']-g['hip'];v2=g['an']-g['kn']; b=math.degrees(math.acos(np.clip(v1@v2/np.hypot(*v1)/np.hypot(*v2),-1,1)))
      bends[(s,i)]=(b,'H' if hs and not to else ('F' if full else ('T' if to else 'S')))
  st=' '.join(f"{s}{i}{bends[(s,i)][1]}{bends[(s,i)][0]:.0f}" for s in 'RL' for i in range(12) if bends[(s,i)][1] in 'HF')
  print(F,d,'maxratio planted %.3f any %.3f'%(worst_full,worst_any),'| stance bends',st)
