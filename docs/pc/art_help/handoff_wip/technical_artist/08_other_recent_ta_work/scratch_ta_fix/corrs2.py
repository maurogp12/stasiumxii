import sys, json, numpy as np
sys.path.insert(0, '/workspace/stasium-pc-look/tools/npc')
import build_npc as B
R = ['woodcutter','fisher','smith','hermit','coil_engineer','warden','guide','herald','banker','elder','trader','door_keeper','archivist','forge_master','ferry_captain','fen_guide','last_watcher']
for r in R:
    cfg = json.load(open(f'roles/{r}.json'))
    for vn in cfg['views']:
        v = B.View(cfg, vn, f'_work/{r}/keyed', lambda s: None)
        wc = cfg['walk']; S = v.sole; dv = v.dir_raw
        lat = np.array([-dv[0], dv[1]], np.float32)
        Minv = np.linalg.inv(np.array([[dv[0], lat[0]], [dv[1], lat[1]]], np.float64))
        gc = {s: Minv @ S[s].astype(np.float64) for s in 'LR'}
        proj = {s: float(gc[s][0]) for s in 'LR'}; mid = (proj['L'] + proj['R']) / 2
        klat = wc.get('lateral_k', 0.6); amid = (gc['L'][1] + gc['R'][1]) / 2
        latd = {s: float((amid + (gc[s][1] - amid) * klat) - gc[s][1]) for s in 'LR'}
        F = max('LR', key=lambda s: proj[s]); Bf = 'R' if F == 'L' else 'L'
        half = v.px(wc.get('step_2x', 24) / 2)
        posF = [1, .5, 0, -.5, -1, -.6, 0, .6]; posB = [-1, -.6, 0, .6, 1, .5, 0, -.5]
        liftF = [0, 0, 0, 0, 0, 1.5, 5, 3]; liftB = [0, 1.5, 5, 3, 0, 0, 0, 0]; lk = wc.get('lift_2x', 5) / 5
        corr = []; xs = []
        for i in range(8):
            ys = []; xx = {}
            for s, pos, lf in ((F, posF[i], liftF[i]), (Bf, posB[i], liftB[i])):
                d = (mid + pos * half - proj[s]) * dv + latd[s] * lat
                ys.append(S[s][1] + d[1] - v.px(lf * lk)); xx[s] = (S[s][0] + d[0] - v.piv_raw[0]) * v.s
            corr.append(round(float((v.ground - max(ys)) * v.s), 1)); xs.append(round(xx[F] - xx[Bf], 0))
        print(f'{r:13} {vn:5} corr {corr} range {max(corr)-min(corr):.1f}  xF-xB {xs}', flush=True)
