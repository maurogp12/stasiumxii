"""Find each painted part in the approved target (scale, rotation, mirror, position) by masked template matching
on grey at half resolution. Gives per-part size relative to the target, used to set rig scales."""
import json, sys, os, math, numpy as np, cv2
from PIL import Image
P = os.environ.get('BASTION_PARTS', '/workspace/scratch/b2/parts/')
T = '/workspace/handoff/class_walk_blockouts/targets/'
OUT = sys.argv[1] if len(sys.argv) > 1 else '/workspace/scratch/b2/part_match.json'
F = sys.argv[2] if len(sys.argv) > 2 else 'SE'
SETS = {'S': ['S_torso', 'S_belt', 'S_helm', 'S_pauld_a', 'S_pauld_b', 'S_upper_a', 'S_upper_b', 'S_elbowcop', 'S_mace', 'S_fist',
              'S_shield', 'S_cape_u', 'S_cape_l', 'S_thigh_fwd', 'S_thigh_down', 'S_thigh_back', 'S_kneecop', 'S_greave', 'S_sabaton_a', 'S_sabaton_b'],
        'E': ['E_torso', 'E_belt', 'E_helm', 'E_pauld_a', 'E_pauld_b', 'E_upper_a', 'E_upper_b', 'E_elbowcop', 'E_mace', 'E_fist', 'S_shield',
              'E_cape_a', 'E_cape_b', 'E_thigh_fwd', 'E_thigh_down', 'E_thigh_back', 'E_greave', 'E_sabaton', 'S_kneecop']}
H = 0.5
res = json.load(open(OUT)) if os.path.exists(OUT) else {}
for fac in F:
    tg = cv2.cvtColor(np.asarray(Image.open(T + f'bastion_rp_{fac}_f00.jpg').convert('RGB')), cv2.COLOR_RGB2GRAY)
    tg = cv2.resize(tg, None, fx=H, fy=H, interpolation=cv2.INTER_AREA).astype(np.float32)
    for name in SETS[fac]:
        im = np.asarray(Image.open(P + name + '.png').convert('RGBA'))
        g0 = cv2.cvtColor(im[..., :3], cv2.COLOR_RGB2GRAY).astype(np.float32); a0 = (im[..., 3] > 0).astype(np.float32)
        best = None
        for mir in (False, True):
            g1 = g0[:, ::-1] if mir else g0; a1 = a0[:, ::-1] if mir else a0
            for s in np.geomspace(0.12, 0.75, 26):
                ss = s * H
                for th in range(-60, 61, 10):
                    h, w = g1.shape; c = (w / 2, h / 2)
                    M = cv2.getRotationMatrix2D(c, th, ss)
                    cs, sn = abs(M[0, 0]), abs(M[0, 1]); nw, nh = int(w * cs + h * sn) + 2, int(h * cs + w * sn) + 2
                    M[0, 2] += nw / 2 - c[0]; M[1, 2] += nh / 2 - c[1]
                    if nw < 8 or nh < 8 or nw >= tg.shape[1] or nh >= tg.shape[0]: continue
                    gt = cv2.warpAffine(g1, M, (nw, nh), flags=cv2.INTER_AREA); at = cv2.warpAffine(a1, M, (nw, nh)) > 0.5
                    if at.sum() < 40: continue
                    r = cv2.matchTemplate(tg, gt, cv2.TM_CCOEFF_NORMED, mask=at.astype(np.float32))
                    r[~np.isfinite(r)] = -1
                    _, mv, _, ml = cv2.minMaxLoc(r)
                    if best is None or mv > best[0]:
                        best = (float(mv), float(s), th, mir, (ml[0] + nw / 2) / H, (ml[1] + nh / 2) / H)
        res[f'{fac}:{name}'] = dict(ncc=round(best[0], 3), scale=round(best[1], 4), rot=best[2], mirror=best[3], cx=round(best[4], 1), cy=round(best[5], 1))
        print(fac, name, res[f'{fac}:{name}'], flush=True)
        json.dump(res, open(OUT, 'w'), indent=1)
