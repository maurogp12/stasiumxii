import sys, numpy as np
sys.path.insert(0, 'tools'); import check_assets as ca
from PIL import Image
p = sys.argv[1]; im = np.asarray(Image.open(p).convert('RGBA'))
n = im.shape[1] // 256
for k in range(n):
    fr = im[:, k*256:(k+1)*256]
    r = ca._npc_ao(fr, (128, 240))
    if r and r['peak'] > 0.3:
        m = r['mask'] & (fr[..., 3] > 0.3 * 255)
        ys, xs = np.nonzero(m)
        print(k, f"peak {r['peak']:.2f}", 'px>0.3:', len(ys), 'at', list(zip(xs[:6], ys[:6])), 'rgb', [tuple(fr[y, x]) for y, x in list(zip(ys, xs))[:3]])
