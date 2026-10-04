"""Far-boot visibility per frame (cell px): far boot = the far leg's boot from the boot top down to the toe, rendered alone;
visible = not covered by the near leg or by the front layer (belt / bow). Also the min gap between the two boots' silhouettes
(0 = they touch / overlap) and the overlap edge contrast (mean luminance step near -> far across the shared edge).
usage: boot_vis.py [F] [out.png]   (out.png = zoomed feet sheet of all 12 frames with the % per frame)"""
import os, sys, json, numpy as np, cv2
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import krig
RS = 3

def boot_tex(F, name):
    key = name + '_boot'
    if key not in krig.TEX:
        t = krig.tex(name).copy(); R = krig.RIG[F]
        yy = np.indices(t.shape[:2])[0]; top = R['K'][1] + 4          # boot top fold sits just below the knee joint
        t[yy < top] = 0; krig.TEX[key] = t
        krig._MESH[(F, key)] = krig.mesh(F, name)
    return key

def measure(F, i):
    dy = krig.get_dy(F); fr = krig.frames(F)[i]; nr = krig.near_side(fr); far = 'R' if nr == 'L' else 'L'; pl = krig.plants(F)
    P = {sd: krig.leg_pose(F, i, sd, dy, pl) for sd in 'RL'}
    nm = {sd: f'leg_{F}' if sd == 'L' else f'legfar_{F}' for sd in 'RL'}
    near_a = krig.skin(F, nm[nr], P[nr], RS)[..., 3]
    fb = krig.skin(F, boot_tex(F, nm[far]), P[far], RS)[..., 3]
    nb = krig.skin(F, boot_tex(F, nm[nr]), P[nr], RS)[..., 3]
    front = krig.place(F, f'front_{F}', krig.body_T(F, i, dy), RS)[..., 3]
    small = lambda a: cv2.resize(a, (krig.CW, krig.CH), interpolation=cv2.INTER_AREA) > 0.5
    fbm, occ, nbm = small(fb), small(near_a) | small(front), small(nb)
    vis = float((fbm & ~occ).sum() / max(fbm.sum(), 1))
    # gap between the visible far boot and the near boot
    d = cv2.distanceTransform((~nbm).astype(np.uint8), cv2.DIST_L2, 5)
    fv = fbm & ~occ
    gap = float(d[fv].min()) if fv.any() else -1.0
    return dict(near=nr, far=far, far_boot_px=int(fbm.sum()), visible_pct=round(100 * vis, 1), gap_px=round(max(gap - 1, 0), 1),
                touching=bool(gap <= 1.5))

if __name__ == '__main__':
    F = sys.argv[1] if len(sys.argv) > 1 else 'S'
    res = {f'f{i:02d}': measure(F, i) for i in range(12)}
    for k, v in res.items(): print(k, v)
    if len(sys.argv) > 2:
        from PIL import ImageFont
        fp = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'; ft = ImageFont.truetype(fp, 17) if os.path.exists(fp) else None
        D = os.path.join(krig.HERE, '..', 'frames'); tiles = []
        for i in range(12):
            a = Image.open(f'{D}/kestrel_walk_{F}_f{i:02d}.png'); b = Image.new('RGBA', a.size, (172, 172, 172, 255)); b.alpha_composite(a)
            t = Image.new('RGB', (420, 415), (255, 255, 255))
            t.paste(b.convert('RGB').crop((190, 240, 330, 360)).resize((420, 360), Image.NEAREST), (0, 55)); dr = ImageDraw.Draw(t)
            v = res[f'f{i:02d}']
            dr.text((6, 4), f"{F} f{i:02d}  far boot ({v['far']}) {v['visible_pct']:.0f}% visible", fill=(0, 0, 0), font=ft)
            dr.text((6, 28), (f"boot gap {v['gap_px']:.0f} px" if not v['touching'] else 'boots overlap: far boot 10% darker'), fill=(0, 0, 0), font=ft)
            tiles.append(np.asarray(t))
        Image.fromarray(np.vstack([np.hstack(tiles[:6]), np.hstack(tiles[6:])])).save(sys.argv[2])
        json.dump(res, open(os.path.splitext(sys.argv[2])[0] + '.json', 'w'), indent=1)
