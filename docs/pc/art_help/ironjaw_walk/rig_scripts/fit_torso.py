import numpy as np, json
from PIL import Image
import cv2
res = {}
for fac, band in (('S', (60, 140)), ('E', (60, 140))):
    ref = np.asarray(Image.open(f'/workspace/art/ironjaw_full/v4_hd/_norim/idle/ironjaw_idle_{fac}_f00.png'))
    ra = (ref[..., 3] > 0).astype(np.float32)
    rgray = cv2.cvtColor(ref[..., :3], cv2.COLOR_RGB2GRAY).astype(np.float32)
    kit = np.asarray(Image.open(f'parts/{fac}_torso.png'))
    best = None
    for mir in (False, True):
        k = kit[:, ::-1] if mir else kit
        for s in np.arange(0.38, 0.60, 0.005):
            w, h = int(round(k.shape[1] * s)), int(round(k.shape[0] * s))
            ka = cv2.resize((k[..., 3] > 0).astype(np.float32), (w, h), interpolation=cv2.INTER_AREA) > 0.5
            # top of kit (horn) aligned to ref top row 64 +- search
            for ty in range(52, 80, 1):
                for tx in range(256 - w // 2 - 20, 256 - w // 2 + 21, 1):
                    b0, b1 = band
                    A = np.zeros((b1 - b0, 512), bool)
                    kp = np.pad(ka, ((40, 0), (0, 0))); A[:, tx:tx + w] = kp[b0 - ty + 40:b1 - ty + 40]
                    B = ra[b0:b1] > 0
                    iou = (A & B).sum() / max((A | B).sum(), 1)
                    if best is None or iou > best[0]:
                        best = (iou, mir, round(float(s), 3), tx, ty, w, h)
    res[fac] = best
    print(fac, best)
json.dump({k: [float(v[0]), bool(v[1]), v[2], int(v[3]), int(v[4]), int(v[5]), int(v[6])] for k, v in res.items()}, open('torso_fit.json', 'w'))
