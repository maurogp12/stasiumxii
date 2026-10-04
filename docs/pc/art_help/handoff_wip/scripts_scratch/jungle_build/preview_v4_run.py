from preview_v4 import *
import json, sys
BM4 = '/workspace/scratch/v4/bm/back_mid_v4@2x.png'
which = sys.argv[1] if len(sys.argv) > 1 else 'test'
res = {}
for tag, ov in (('v3', {'back_mid@2x.png': ARCH3 + 'back_mid@2x.png'}), ('v4', {'back_mid@2x.png': BM4})):
    for p in PANS:
        fr, cov, gm = compose4(SHIP, p, ov); res['%s %s' % (tag, p)] = gm
        print(tag, p, {k: round(v, 1) for k, v in gm.items()}, flush=True)
        if p == (0, 0): fr.convert('RGB').save('/workspace/scratch/v4/test_%s.png' % tag)
json.dump(res, open('/workspace/scratch/v4/ground_metrics.json', 'w'), indent=1)
