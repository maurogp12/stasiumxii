"""legs first: f00 and f06 legs beside the approved target, crop-zoomed; visible leg length belt -> sole vs the target's
(target px x s_up, i.e. the target placed on the cell exactly like the trunk layer of f00).
usage: legs_check.py [out.png] [frames_dir]   (frames_dir: read saved frames instead of rendering)"""
import sys, os, json, numpy as np
sys.argv, ARGS = sys.argv[:1], sys.argv[1:]
from PIL import Image, ImageDraw
import build_hybrid as BH
HERE = os.path.dirname(os.path.abspath(__file__)); OUT = ARGS[0] if ARGS else os.path.join(HERE, '..', 'legs_check.png')
T = '/workspace/handoff/class_walk_blockouts/targets/'
BELT = {'S': 300, 'E': 305}            # target px: bottom edge of the belt (S gold belt; E belt line above the tassets)
LEGP = ('R_thigh', 'L_thigh', 'R_greave', 'L_greave', 'R_boot', 'L_boot', 'R_kneecop', 'L_kneecop')
res = {}; rows = []
for F in 'SE':
    BH.prepare_h(F); keys, _ = BH.thigh_keys(F)
    ta = np.asarray(Image.open(f'{T}bastion_rp_{F}_f00_alpha.png').convert('L')) > 127; trgb = np.asarray(Image.open(f'{T}bastion_rp_{F}_f00.jpg').convert('RGB'))
    t_sole = int(np.nonzero(ta.any(1))[0].max())
    Mt0 = BH.trunk_M(F, BH.frames(F)[0]); s = Mt0[0, 0]
    t_len = (t_sole - BELT[F]) * s
    # target on the cell (same map as the f00 trunk layer), may run past the cell bottom
    H = 420; tgt = np.full((H, 512, 3), 128, np.uint8)
    import cv2
    Minv = cv2.invertAffineTransform(Mt0.astype(np.float32))
    w = cv2.warpAffine(np.dstack([trgb, ta * 255]).astype(np.uint8), Mt0.astype(np.float32), (512, H), flags=cv2.INTER_AREA)
    m = w[..., 3] > 127; tgt[m] = w[..., :3][m]
    panels = [None]   # filled after f00 (needs the f00 hip offset)
    res[F] = dict(target_len_cell=round(t_len, 1))
    for i in (0, 6):
        rgb, al, layers, owner, Ms, meta, order = BH.render_h(F, i, keys)
        cell, _ = BH.clean_cell(BH.compose_cell(rgb, al)); cell = BH.gold_lift(cell, BH.TCFG[F].get("gold_lift", 0.0)); im = np.full((H, 512, 3), 128, np.uint8); mm = cell[..., 3] > 0; im[:360][mm] = cell[..., :3][mm]
        legs = np.zeros_like(al)
        for nm in LEGP:
            if nm in order: legs |= owner == order.index(nm)
        Mt = BH.trunk_M(F, BH.frames(F)[i]); belt = Mt[1, 1] * BELT[F] + Mt[1, 2]; sole = int(np.nonzero(legs.any(1))[0].max())
        # the lowest sole's leg; the belt slopes with the hips in iso, so measure from the belt at that leg's hip
        side = max('RL', key=lambda sd: np.nonzero((owner == order.index(f'{sd}_boot')).any(1))[0].max())
        jj = {k: list(v) for k, v in BH.frames(F)[i]['joints'].items()}
        if 'legs_v3' in meta:   # v3: the hips are the target-rooted ones, not the blockout's
            for sd in 'RL': jj[f'{sd}_hip'] = meta['legs_v3'][sd]['hip']; jj[f'{sd}_ankle'] = meta['legs_v3'][sd]['goal']
        off = jj[f'{side}_hip'][1] - jj['pelvis'][1]
        if i == 0: j0 = jj; t_off = off; t_side = side          # the target is painted on the f00 pose: same lowest leg
        L = sole - belt; Lh = sole - (belt + off); tL = t_len - t_off
        res[F][f'f{i:02d}'] = dict(belt_row=round(float(belt), 1), sole_row=sole, len=round(float(L), 1), pct=round(100 * L / t_len, 1),
                                   lowest_leg=side, hip_offset=round(off, 1), len_from_own_hip_belt=round(float(Lh), 1),
                                   target_len_from_hip_belt=round(float(tL), 1), pct_own_hip=round(100 * Lh / tL, 1), leg_visible_px=int(legs.sum()))
        per = {}
        for sd in 'RL':   # both legs: belt at that leg's hip -> that boot's lowest visible row; 'straight' = longer clay hip->ankle
            so_ = int(np.nonzero((owner == order.index(f'{sd}_boot')).any(1))[0].max()); of_ = jj[f'{sd}_hip'][1] - jj['pelvis'][1]
            per[sd] = dict(sole_row=so_, len=round(float(so_ - belt - of_), 1), pct=round(float(100 * (so_ - belt - of_) / tL), 1),
                           clay_hip_ankle=round(float(np.hypot(*(np.array(jj[f'{sd}_ankle']) - np.array(jj[f'{sd}_hip'])))), 1))
        st = max('RL', key=lambda sd: per[sd]['clay_hip_ankle'])
        res[F][f'f{i:02d}'].update(per_leg=per, straight_leg=st, pct_straight_leg=per[st]['pct'])
        panels.append((f'{F} f{i:02d}  {side} leg {Lh:.1f} px = {100 * Lh / tL:.1f}% (belt at hip); straight {st} leg {per[st]['pct']:.1f}%', im, belt + off, sole))
    panels[0] = (f'{F} target  {t_side} leg {t_len - t_off:.1f} px (belt at hip)', tgt, Mt0[1, 1] * BELT[F] + Mt0[1, 2] + t_off, Mt0[1, 1] * t_sole + Mt0[1, 2])
    # crop on the legs and zoom x2
    y0 = int(min(p[2] for p in panels)) - 30; y1 = min(H, int(max(p[3] for p in panels)) + 12)
    row = []
    for lab, im, b, so in panels:
        c = Image.fromarray(im[y0:y1, 136:376]).resize((480, (y1 - y0) * 2), Image.LANCZOS); d = ImageDraw.Draw(c)
        for yy, col in ((b, (255, 220, 0)), (so, (0, 255, 255))): d.line([(0, (yy - y0) * 2), (480, (yy - y0) * 2)], fill=col)
        d.text((6, 4), lab, fill=(255, 255, 255)); row.append(c)
    r = Image.new('RGB', (480 * 3 + 20, row[0].height), (40, 40, 40)); [r.paste(c, (k * 490, 0)) for k, c in enumerate(row)]; rows.append(r)
out = Image.new('RGB', (rows[0].width, sum(r.height for r in rows) + 10), (40, 40, 40)); y = 0
for r in rows: out.paste(r, (0, y)); y += r.height + 10
out.save(OUT); json.dump(res, open(os.path.splitext(OUT)[0] + '.json', 'w'), indent=1); print(json.dumps(res))
