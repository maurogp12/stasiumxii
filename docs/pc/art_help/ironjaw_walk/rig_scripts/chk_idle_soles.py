import sys; sys.path.insert(0, '/workspace/scratch/ij_walk/rig')
from build import *
prepare()
for fac in 'SE':
    idle = J['idle_' + fac]
    rgb, al, layers, *_ = render(fac, idle, idle, 0.0)
    for s in 'RL':
        ys = np.nonzero(layers[f'{s}_boot'].any(1))[0]; print(fac, s, 'boot bottom', ys.max(), 'TA heel/toe y', round(idle['joints'][f'{s}_heel'][1], 1), round(idle['joints'][f'{s}_toe'][1], 1))
    W = J['walk_' + fac]
    for f in ('f00', 'f05', 'f06', 'f11'):
        rgb, al, layers, *_ = render(fac, W[f], idle, 0.0)
        print('  ', f, {s: int(np.nonzero(layers[f'{s}_boot'].any(1))[0].max()) for s in 'RL'}, {s: (round(W[f]['joints'][f'{s}_heel'][1]), round(W[f]['joints'][f'{s}_toe'][1])) for s in 'RL'})
