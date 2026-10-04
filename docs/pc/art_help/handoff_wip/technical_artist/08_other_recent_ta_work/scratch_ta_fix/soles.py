import sys, json, os
sys.path.insert(0, '/workspace/stasium-pc-look/tools/npc')
import build_npc as B
R = ['farmer','woodcutter','fisher','smith','hermit','coil_engineer','warden','guide','herald','banker','elder','trader','door_keeper','archivist','forge_master','ferry_captain','fen_guide','last_watcher','shard_seer']
for r in R:
    cfg = json.load(open(f'roles/{r}.json'))
    out = []
    for vn in cfg['views']:
        v = B.View(cfg, vn, f'_work/{r}/keyed', lambda s: None)
        dy = abs(v.sole['L'][1] - v.sole['R'][1]) * v.s
        dx = abs(v.sole['L'][0] - v.sole['R'][0]) * v.s
        H = (v.ground - v.head_top) * v.s
        out.append(f'{vn}: depth {dy:4.1f} dx {dx:4.1f} H {H:5.1f} s {v.s:.4f}')
    print(f'{r:14}', ' | '.join(out), flush=True)
