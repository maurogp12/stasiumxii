import sys,json,math
sys.path.insert(0,'/workspace/handoff/class_walk_blockouts/kestrel/v2/scripts')
import kbuild as K
for F in sys.argv[1] if len(sys.argv)>1 else 'SE':
  print(F,'drop',K.KCFG[F]['drop'])
  for i in range(12):
    r=[]
    for s in 'RL':
      g=K.leg_geo(F,i,s); k,d=K.rkey(F,i,s)
      b=math.degrees(math.acos(max(-1,min(1,float((g['kn']-g['hip'])@(g['an']-g['kn'])/(math.dist(g['kn'],g['hip'])*math.dist(g['an'],g['kn'])))))))
      r.append(f"{s} {k:4s}{d:6.1f} bend{b:5.1f} r{g['ratio']:.3f} st{g['st']:.3f}")
    print(i,' | '.join(r))
