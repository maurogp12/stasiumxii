"""Kestrel v2 legs sheet B (Luca's notes on sheet A): one continuous skinned leg per side (cut_legs_b.py + kbuild leg_one),
pelvis / hip mass layer, volume shading (far leg 12 % darker), anti-aliased silhouette with a subtle dark outline, rim gap
between overlapping legs. Same layout as sheet A: target legs | f00 | f03 | f06 | f09 for S and E at the same figure height.
Measurements at cell scale (RS=1, same definitions as legs_sheet.py); images rendered from the same rig at RS=4.
Also: side_by_side_{S,E}.png (target legs vs walk f00 / f06, large), knee gap on S (min distance between the two leg
silhouettes in the knee band), legs_sheet_b.json.  usage: legs_sheet_b.py [out_dir]"""
import sys, os, json, math, numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kbuild as KB
from kcommon import *
import legs_sheet as LS
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'legs_sheet_b')
FR = [0, 3, 6, 9]; HI = 4
try:
    FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13); FB = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 15)
except Exception: FONT = FB = ImageFont.load_default()

def legs_only(lay, order):
    """legs (far -> near) + pelvis, premultiplied"""
    acc = None
    for nm in [n for n in order if n.endswith('_leg')] + ['pelvis']:
        if nm not in lay: continue
        L = lay[nm]; acc = L.copy() if acc is None else L + acc * (1 - L[..., 3:])
    return acc

def measure(F, i, T):
    acc, lay, owner, order, meta = KB.render(F, i)
    lay2 = dict(lay); lay2.update({f'{sd}_thigh': lay[f'{sd}_leg'] for sd in 'RL'}); lay2.update({f'{sd}_boot': lay[f'{sd}_leg'] for sd in 'RL'})
    m = LS.walk_meas(F, i, acc, lay2, meta, T)
    # knee gap: min distance between the two leg silhouettes in the band around the knees
    a = {sd: lay[f'{sd}_leg'][..., 3] > 0.5 for sd in 'RL'}; ky = [meta[sd]['knee'][1] for sd in 'RL']
    y0, y1 = int(min(ky) - 8), int(max(ky) + 8); band = np.zeros_like(a['R']); band[y0:y1] = True
    dt = cv2.distanceTransform((~a['L']).astype(np.uint8), cv2.DIST_L2, 5)
    gap = float(dt[a['R'] & band].min()) if (a['R'] & band).any() else -1.0
    m['knee_gap_px'] = round(gap - 1.0 if gap > 0 else 0.0, 1)       # free pixels between the outlines
    m['feet'] = {sd: meta[sd]['ankle'] for sd in 'RL'}; m['fixups'] = {sd: KB.leg_geo(F, i, sd)['fixup'] for sd in 'RL'}
    return m

def tile(img, top, sole, T, lines, th, wpx, crop=(0.30, 1.03), cx=None):
    return LS.tile_img(img, top, sole, None, None, T, lines, '', crop_frac=crop, wpx=wpx) if th is None else None

def scaled_tile(rgba, top, sole, T, lines, TH, wpx, crop=(0.30, 1.03), bg=(255, 255, 255, 255)):
    old = LS.TH; LS.TH = TH
    try: return LS.tile_img(rgba, top, sole, None, None, T, lines, '', crop_frac=crop, wpx=wpx, bg=bg)
    finally: LS.TH = old

def main():
    os.makedirs(OUT, exist_ok=True); res = {}; imgs = {}
    # 1) measurements at cell scale
    KB.RS = 1
    for F in 'SE':
        KB.load_layers(F); T = LS.target_meas(F); res[F] = dict(target=T, frames={})
        for i in range(12): res[F]['frames'][f'f{i:02d}'] = measure(F, i, T)
    # 2) hi-res images from the same rig
    KB.RS = HI; KB.TEX.clear()
    for F in 'SE':
        KB.load_layers(F)
        for i in FR + [k for k in (0, 6) if k not in FR]:
            acc, lay, owner, order, meta = KB.render(F, i)
            imgs[(F, i, 'legs')] = KB.to_rgba_aa(legs_only(lay, order)); imgs[(F, i, 'full')] = KB.to_rgba_aa(acc)
    json.dump(res, open(os.path.join(OUT, 'legs_sheet_b.json'), 'w'), indent=1, default=float)
    # 3) sheet: same layout as sheet A
    TH = 600; wpx = 320; rows = []
    for F in 'SE':
        T = res[F]['target']; rgb, al = target(F); trgba = np.dstack([rgb, al * 255]).astype(np.uint8)
        tl = [(scaled_tile(trgba, T['top'], T['sole'], T, [(T['belt'], (40, 90, 230)), (T['knee'], (240, 140, 0)), (T['sole'], (0, 160, 60))], TH, wpx),
               [f'{F} TARGET (same height)', f"thigh/shoulder {T['thigh_sh']:.3f}", f"boot/shoulder  {T['boot_sh']:.3f}", f"belt->sole {T['belt_pct']:.1f}% of H",
                f"knee line {T['knee_pct']:.1f}% of H", ''])]
        for i in FR:
            m = res[F]['frames'][f'f{i:02d}']; L_ = m['legs']; st = m['stance']; im = imgs[(F, i, 'legs')]
            sc = lambda y: y * HI
            t = scaled_tile(im, sc(m['top']), sc(m['sole']), T, [(sc(m['belt']), (40, 90, 230)), (sc(L_[m['knee_leg']]['knee'][1]), (240, 140, 0)), (sc(m['sole']), (0, 160, 60))], TH, wpx)
            lab = [f'{F} f{i:02d}  stance {st}  R:{L_["R"]["key"]} L:{L_["L"]["key"]}',
                   'thigh/sh ' + '  '.join(f"{sd} {L_[sd]['thigh_sh']:.3f} ({L_[sd]['thigh_dev']:+.1f}%)" for sd in 'RL'),
                   'boot/sh  ' + '  '.join(f"{sd} {L_[sd]['boot_sh']:.3f} ({L_[sd]['boot_dev']:+.1f}%)" for sd in 'RL'),
                   f"belt->sole {m['belt_pct']:.1f}% ({m['belt_vs_target_pct']:+.1f}% vs tgt)  knee {m['knee_line_pct']:.1f}% ({m['knee_vs_target_pts']:+.1f})",
                   f"stance straight {L_[st]['straight_pct']:.1f}%, bend {L_[st]['bend']:.0f}deg  knee gap {m['knee_gap_px']:.1f}px",
                   f"hip offset {m['hip_offset_px']:.1f}px  stretch {L_['R']['stretch']:.2f}/{L_['L']['stretch']:.2f}"]
            tl.append((t, lab))
        rows.append(tl)
    th_ = rows[0][0][0].height; txt = 6 * 17 + 10
    S_ = Image.new('RGB', (5 * (wpx + 8) + 8, 40 + 2 * (th_ + txt + 14)), 'white'); d = ImageDraw.Draw(S_)
    d.text((10, 10), 'Kestrel v2 legs sheet B (blockout v3): one continuous skinned leg + pelvis, volume shading, AA outline. Solid = this tile belt/knee(boot top)/sole; dashed = target; grey ticks = 43%/70%', fill='black', font=FONT)
    for r, tl in enumerate(rows):
        y = 40 + r * (th_ + txt + 14)
        for k, (t, lab) in enumerate(tl):
            x = 8 + k * (wpx + 8); S_.paste(t.convert('RGB'), (x, y)); d.rectangle([x, y, x + wpx - 1, y + th_ - 1], outline=(180, 180, 180))
            for j, ln in enumerate(lab): d.text((x + 2, y + th_ + 4 + 17 * j), ln, fill='black', font=FB if j == 0 else FONT)
    S_.save(os.path.join(OUT, 'kestrel_v2_legs_sheet_b.png'))
    # 4) side by side, large: target legs | f00 | f06 (legs only, grey 172), same height
    for F in 'SE':
        T = res[F]['target']; rgb, al = target(F); trgba = np.dstack([rgb, al * 255]).astype(np.uint8); TH2 = 1500; w2 = 560
        ts = [scaled_tile(trgba, T['top'], T['sole'], T, [], TH2, w2, crop=(0.36, 1.02), bg=(172, 172, 172, 255))]
        for i in (0, 6):
            m = res[F]['frames'][f'f{i:02d}']
            ts.append(scaled_tile(imgs[(F, i, 'legs')], m['top'] * HI, m['sole'] * HI, T, [], TH2, w2, crop=(0.36, 1.02), bg=(172, 172, 172, 255)))
        Wd = Image.new('RGB', (3 * w2 + 40, ts[0].height + 40), (172, 172, 172)); dd = ImageDraw.Draw(Wd)
        for k, (t, nm) in enumerate(zip(ts, ['TARGET', 'walk f00', 'walk f06'])):
            tt = t
            Wd.paste(tt.convert('RGB'), (10 + k * (w2 + 10), 30)); dd.text((14 + k * (w2 + 10), 8), f'{F} {nm} (same figure height)', fill='black', font=FB)
        Wd.save(os.path.join(OUT, f'side_by_side_{F}.png'))
    # 5) composites kept for the paint guides
    np.savez_compressed('/tmp/legs_b_imgs.npz', **{f'{F}_{i}_{k}': v for (F, i, k), v in imgs.items()})
    for F in 'SE':
        print(F, 'target thigh/sh %.3f boot/sh %.3f belt %.1f knee %.1f' % (res[F]['target']['thigh_sh'], res[F]['target']['boot_sh'], res[F]['target']['belt_pct'], res[F]['target']['knee_pct']))
        for k, m in res[F]['frames'].items():
            st = m['stance']; L_ = m['legs']
            print(' ', k, 'st', st, 'belt %+.1f%% knee %+.1f straight %.0f bend %.0f gap %.1f hip %.1f' % (m['belt_vs_target_pct'], m['knee_vs_target_pts'], L_[st]['straight_pct'], L_[st]['bend'], m['knee_gap_px'], m['hip_offset_px']),
                  ' '.join(f"{sd}:th{L_[sd]['thigh_dev']:+.1f} bo{L_[sd]['boot_dev']:+.1f} {L_[sd]['key']}" for sd in 'RL'), m['fixups'])

if __name__ == '__main__': main()
