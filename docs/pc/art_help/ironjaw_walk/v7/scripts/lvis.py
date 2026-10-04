import pickle, numpy as np, sys
from PIL import Image
pk = sys.argv[1]; frames = [int(x) for x in sys.argv[2].split(',')]; out = sys.argv[3] if len(sys.argv) > 3 else None
DD = pickle.load(open(pk, 'rb'))['DATA']['E']; ims = []
for i in frames:
    D = DD[i]; ll = D['leg_layers']; Lm = np.zeros((360, 512), bool)
    for k in ('L_thigh', 'L_shin', 'L_boot'):
        v = ll[k]; Lm |= (v[..., 3] > 127 if v.ndim == 3 else v > 0)
    o = D['order']; own = D['owner']
    vis = np.isin(own, [o.index(k) for k in ('L_thigh', 'L_shin', 'L_boot')])
    occ = {nm: int(((own == o.index(nm)) & Lm).sum()) for nm in o if not nm.startswith('L_')}
    print(i, 'planted', D['planted'], 'L total', int(Lm.sum()), 'visible', int(vis.sum()), 'hidden by', {k: v for k, v in occ.items() if v})
    if out:
        img = D['norim'][..., :3].copy(); bg = np.full_like(img, 106); a = D['norim'][..., 3] > 0; bg[a] = img[a]
        ov = bg.copy(); ov[Lm & ~vis] = (ov[Lm & ~vis] * 0.4 + np.array([0, 0, 255]) * 0.6).astype(np.uint8); ov[vis] = (255, 255, 0)
        ims.append(ov[150:345, 150:370])
if out:
    im = Image.fromarray(np.hstack(ims)); im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(out)
