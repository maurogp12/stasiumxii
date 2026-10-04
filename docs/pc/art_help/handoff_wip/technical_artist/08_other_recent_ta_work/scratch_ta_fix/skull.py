import sys, json
sys.path.insert(0, '/workspace/stasium-pc-look/tools/npc')
import numpy as np, build_npc as b
cfg = json.load(open('/workspace/stasium-pc-look/tools/npc/roles/forge_master.json'))
K = {'front_stand': ('front_stand.png', (560, 680), False), 'front_work_up': ('front_work_up.jpg', (505, 562), False, 105),
     'front_work_strike': ('front_work_strike.jpg', (530, 650), False), 'back_stand': ('back_stand.png', (600, 700), False),
     'back_work_up': ('back_work_up.jpg', (598, 668), False, 150), 'back_work_strike': ('back_work_strike.jpg', (660, 745), True)}
for name, v in K.items():
    fn, (xa, xb), mir = v[:3]; y0 = v[3] if len(v) > 3 else 0
    c = dict(cfg); c['keys'] = dict(cfg['keys']); c['keys'][name] = fn
    a = b.load_key(c, name, '/workspace/stasium-pc-look/tools/npc/_work/forge_master/keyed')
    if mir: a = a[:, ::-1]
    al = a[..., 3]
    pts = []
    for x in range(xa, xb):
        ys = np.nonzero(al[y0:260, x] > 0.5)[0] + y0
        if len(ys): pts.append((x, ys[0]))
    pts = np.array(pts, float)
    top = pts[:, 1].min()
    for depth in (20, 30):
        p = pts[pts[:, 1] < top + depth]
        A = np.c_[2 * p[:, 0], 2 * p[:, 1], np.ones(len(p))]; bb = (p ** 2).sum(1)
        cx, cy, c0 = np.linalg.lstsq(A, bb, rcond=None)[0]; r = np.sqrt(c0 + cx ** 2 + cy ** 2)
        print(f'{name:18s} depth {depth}: top {top:.0f} n {len(p)} x {p[:,0].min():.0f}-{p[:,0].max():.0f} circle r {r:.1f} centre ({cx:.0f},{cy:.0f})')
