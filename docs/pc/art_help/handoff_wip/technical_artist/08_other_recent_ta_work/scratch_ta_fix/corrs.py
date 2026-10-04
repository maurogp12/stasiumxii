import sys, json, numpy as np
sys.path.insert(0, '/workspace/stasium-pc-look/tools/npc')
import build_npc as B, npc_v2
R = sys.argv[1].split(',') if len(sys.argv) > 1 else ['woodcutter','smith','herald','trader','last_watcher','guide']
for r in R:
    cfg = json.load(open(f'roles/{r}.json'))
    for vn in cfg['views']:
        v = B.View(cfg, vn, f'_work/{r}/keyed', lambda s: None)
        if cfg['views'][vn].get('walk') != 'synth': continue
        for klat in (0.4, 1.0, 0.0):
            c = dict(cfg); c['walk'] = dict(cfg['walk'], lateral_k=klat)
            specs, info = npc_v2.walk_specs_synth(v, c)
            # variant B: lowest of all feet
            cb = []
            for sp in specs:
                ys = [v.sole[s][1] + sp['feet'][s][0][1] - sp['feet'][s][1] for s in 'LR']
                cb.append(round(float((v.ground - max(ys)) * v.s), 1))
            print(f'{r:12} {vn:5} klat {klat}: A(grounded pinned) {info["support_pin_corr_2x"]}  B(after A, lowest-any) {cb}')
