"""f00 quick look: candidate | metric-fitted target | clay, x2, plus look components (same functions as bastion_metric)."""
import sys, os, json, numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import bastion_metric as MM
T = '/workspace/handoff/class_walk_blockouts/targets/'; B = '/workspace/handoff/class_walk_blockouts/bastion/'
d = sys.argv[1]; fr = int(sys.argv[2]) if len(sys.argv) > 2 else 0; out = sys.argv[3] if len(sys.argv) > 3 else '/workspace/scratch/bastion/ql.png'
J = json.load(open(B + 'joints_512.json'))['facings']
rows = []
for F in 'SE':
    py = int(round(J[f'walk_{F}']['f00']['joints']['pelvis'][1]))
    cr, cm = MM.load(d, F, 0)
    trgb = np.asarray(Image.open(T + f'bastion_rp_{F}_f00.jpg').convert('RGB')); ta = np.asarray(Image.open(T + f'bastion_rp_{F}_f00_alpha.png').convert('L')) > 127
    iou_up, s, tx, ty = MM.fit(trgb, ta, cm, py); tr, tm = MM.place(trgb, ta, s, tx, ty)
    C, Tt = MM.comp(cr, cm), MM.comp(tr, tm); U = cm | tm; up = np.zeros_like(U); up[:py] = True
    su, sl = MM.mssim(C, Tt, U & up), MM.mssim(C, Tt, U & ~up); iou = (cm & tm).sum() / U.sum()
    pd, pal = MM.palette(cr, cm, tr, tm)
    print(F, f'fit s={s:.3f} tx={tx:.0f} ty={ty:.0f} iou_up={iou_up:.3f} | ssim_up={su:.3f} ssim_lo={sl:.3f} iou={iou:.3f} pal={pal:.3f}',
          {k: (v['dE'], v['share_cand'], v['share_tgt']) if v else None for k, v in pd.items()},
          'approx_look(no legprop)=%.1f' % (100 * (.35 * su + .15 * sl + .2 * iou + .2 * pal)))
    if fr != 0: cr, cm = MM.load(d, F, fr)
    cl = np.asarray(Image.open(B + f'clay/bastion_walk_{F}_f{fr:02d}.png').convert('RGBA')); clc = MM.comp(cl[..., :3], cl[..., 3] > 127)
    ov = MM.comp(cr, cm).copy(); e = tm & ~np.asarray(Image.fromarray(tm.astype(np.uint8) * 255).filter(__import__('PIL.ImageFilter').ImageFilter.MinFilter(3))) .astype(bool)
    ov[e] = (255, 255, 0)
    rows.append(np.hstack([ov[40:360, 120:420], Tt[40:360, 120:420], clc[40:360, 120:420]]))
im = Image.fromarray(np.vstack(rows)); im.resize((im.width * 2 // 1, im.height * 2 // 1), Image.NEAREST).save(out)
