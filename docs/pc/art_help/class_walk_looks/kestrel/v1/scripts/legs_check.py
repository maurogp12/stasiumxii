"""legs first: f00 and f06 legs beside the approved target, crop-zoomed. Visible leg length belt -> sole vs the target's,
with the target placed on the cell exactly like the f00 body layer (target px x s_up). The belt is measured at the leg's own
hip point (target belt-corner hip + the per-frame pelvis delta), because the belt slopes with the hips in iso.
Also: hip midpoint vs the target belt centre (+ pelvis delta), Mauro check 2.
usage: legs_check.py [out.png]"""
import sys, os, json, math, numpy as np, cv2
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kbuild as KB
from kcommon import *
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'legs_check.png')
res = {}; rows = []; H = 420
for F in 'SE':
    KB.load_layers(F); c = KB.KCFG[F]; s = c['s_up']; W = frames(F)
    trgb, ta = target(F); t_sole = int(np.nonzero(ta.any(1))[0].max())
    Mt0 = KB.trunk_M(F, W[0], W[0])
    # target on the cell (same map as the f00 body layer); may run past the cell bottom
    tgt = np.full((H, 512, 3), 128, np.uint8)
    w = cv2.warpAffine(np.dstack([trgb, ta * 255]).astype(np.uint8), Mt0.astype(np.float32), (512, H), flags=cv2.INTER_AREA)
    m = w[..., 3] > 127; tgt[m] = w[..., :3][m]
    t_hip = {sd: KB.apm(Mt0, c['hips'][sd]) for sd in 'RL'}
    t_len = {sd: float(Mt0[1, 1] * t_sole + Mt0[1, 2] - t_hip[sd][1]) for sd in 'RL'}       # hip row -> lowest target sole
    t_len_ref = max(t_len.values())
    res[F] = dict(s_up=round(s, 4), target_hip_to_sole_cell=round(t_len_ref, 1), target_sole_row_cell=round(float(Mt0[1, 1] * t_sole + Mt0[1, 2]), 1))
    panels = [(f'{F} target  hip->sole {t_len_ref:.1f} px', tgt, min(p[1] for p in t_hip.values()), Mt0[1, 1] * t_sole + Mt0[1, 2], list(t_hip.values()))]
    for i in (0, 6):
        acc, lay, owner, order, meta = KB.render(F, i); cell = KB.to_cell(acc, F)
        im = np.full((H, 512, 3), 128, np.uint8); mm = cell[..., 3] > 0; im[:360][mm] = cell[..., :3][mm]
        legs = np.zeros(owner.shape, bool)
        for nm in order:
            if nm[:2] in ('R_', 'L_'): legs |= owner == order.index(nm)
        per = {}
        for sd in 'RL':
            ft = owner == order.index(f'{sd}_foot'); so = int(np.nonzero(ft.any(1))[0].max()); hy = meta[sd]['hip'][1]
            per[sd] = dict(hip=meta[sd]['hip'], sole_row=so, len=round(so - hy, 1), pct=round(100 * (so - hy) / t_len_ref, 1),
                           clay_hip_ankle=round(float(np.hypot(*(jnt(W[i], sd + '_ankle') - jnt(W[i], sd + '_hip')))), 1),
                           visible_px=int(sum((owner == order.index(f'{sd}_{p}')).sum() for p in ('thigh', 'shin', 'foot'))))
        st = max('RL', key=lambda q: per[q]['clay_hip_ankle'])
        # Bastion v2 definition (same numbers Mauro saw for Bastion): belt row of THIS frame (target belt centre through the frame's
        # body map) + the blockout's hip offset of the lowest leg (iso: the hips sit at different heights), vs the target's
        # belt -> sole minus the f00 offset of the same (lowest) leg
        Mt = KB.trunk_M(F, W[i], W[0]); bcy = (c['belt'][0][1] + c['belt'][1][1]) / 2.0; belt = Mt[1, 1] * bcy + Mt[1, 2]
        low = max('RL', key=lambda q: per[q]['sole_row']); off = jnt(W[i], low + '_hip')[1] - jnt(W[i], 'pelvis')[1]
        if i == 0: t_off = off
        tl_b = (t_sole - bcy) * s - t_off; Lh = per[low]['sole_row'] - (belt + off)
        dp = jnt(W[i], 'pelvis') - jnt(W[0], 'pelvis')
        bc = KB.apm(Mt0, (np.array(c['belt'][0], float) + np.array(c['belt'][1], float)) / 2) + dp
        hm = (np.array(per['R']['hip']) + np.array(per['L']['hip'])) / 2
        res[F][f'f{i:02d}'] = dict(per_leg=per, straight_leg=st, pct_straight_leg=per[st]['pct'], legs_visible_px=int(legs.sum()),
                                   hip_mid=[round(float(v), 2) for v in hm], belt_centre=[round(float(v), 2) for v in bc],
                                   hip_mid_to_belt_centre_px=round(float(np.hypot(*(hm - bc))), 2),
                                   bastion_def=dict(belt_row=round(float(belt), 1), lowest_leg=low, hip_offset=round(float(off), 1),
                                                    len_from_own_hip_belt=round(float(Lh), 1), target_len_from_hip_belt=round(float(tl_b), 1),
                                                    pct_own_hip=round(float(100 * Lh / tl_b), 1)))
        panels.append((f'{F} f{i:02d}  {low} leg belt->sole {100 * Lh / tl_b:.1f}% (belt at hip) | from root: {st} {per[st]["pct"]:.1f}% | hips-belt {np.hypot(*(hm - bc)):.1f}px',
                       im, min(per[q]['hip'][1] for q in 'RL'), per[st]['sole_row'], [np.array(per[q]['hip']) for q in 'RL'], bc))
    y0 = int(min(p[2] for p in panels)) - 40; y1 = min(H, int(max(p[3] for p in panels)) + 12)
    row = []
    for p in panels:
        lab, im, b, so, hips = p[:5]
        cimg = Image.fromarray(im[y0:y1, 136:376]).resize((480, (y1 - y0) * 2), Image.LANCZOS); d = ImageDraw.Draw(cimg)
        for yy, col in ((b, (255, 220, 0)), (so, (0, 255, 255))): d.line([(0, (yy - y0) * 2), (480, (yy - y0) * 2)], fill=col)
        for hp in hips:
            x, y = (hp[0] - 136) * 2, (hp[1] - y0) * 2; d.ellipse([x - 4, y - 4, x + 4, y + 4], outline=(255, 0, 255), width=2)
        if len(p) > 5:
            x, y = (p[5][0] - 136) * 2, (p[5][1] - y0) * 2; d.line([(x - 6, y), (x + 6, y)], fill=(0, 255, 0), width=2); d.line([(x, y - 6), (x, y + 6)], fill=(0, 255, 0), width=2)
        d.text((6, 4), lab, fill=(255, 255, 255)); row.append(cimg)
    r = Image.new('RGB', (490 * 3, row[0].height), (40, 40, 40)); [r.paste(ci, (k * 490, 0)) for k, ci in enumerate(row)]; rows.append(r)
out = Image.new('RGB', (rows[0].width, sum(r.height for r in rows) + 10 + 30), (40, 40, 40)); y = 0
for r in rows: out.paste(r, (0, y)); y += r.height + 10
ImageDraw.Draw(out).text((6, y + 6), 'yellow = belt at the hip points, cyan = lowest sole of the straight leg, magenta = hip roots, green + = target belt centre (+ pelvis delta)', fill=(255, 255, 255))
out.save(OUT); json.dump(res, open(os.path.splitext(OUT)[0] + '.json', 'w'), indent=1)
for F in 'SE':
    print(F, {k: (res[F][k]['bastion_def'], res[F][k]['straight_leg'], res[F][k]['pct_straight_leg'], res[F][k]['hip_mid_to_belt_centre_px'], {q: res[F][k]['per_leg'][q]['pct'] for q in 'RL'}) for k in ('f00', 'f06')})
