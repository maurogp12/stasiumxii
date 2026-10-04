"""Kestrel v2 LEGS-ONLY sheet (Claude's leg priority, PR #252 issuecomment-5981171032), on the v3 blockout joints.
Per facing: target legs | f00 | f03 | f06 | f09, every tile scaled to the SAME figure height (hood top -> sole) and aligned at
the top, so the % lines line up. Solid lines = this tile's belt / knee / sole; dashed = the target's (same % of height).
Printed per walk tile: thigh / shoulder and boot / shoulder (both legs, % vs the target's), belt->sole % of height (and vs
target), knee line % of height (boot top; vs target), the stance leg's straight length % of target, knee bend, hip offset.
Definitions (identical on the target and on the walk):
  height      = top of the figure (hood) -> lowest boot sole
  belt line   = the target belt centre (moved with the body); hips hang +- half the blockout hip vector from it
  knee line   = the boot top (the boot is ONE piece, knee -> sole; its top is the knee)
  thigh width = run across the thigh at mid-thigh (perpendicular to hip->knee); boot width = run across the shaft at mid-shaft
  shoulder    = outer shoulder edges of the body (fixed target points, moved with the body)
  straight %  = hip -> heel-sole contact distance of the stance leg / (target thigh + target boot knee->heel-sole laid out straight)
                (100 = the full target leg, straight; > 100 only with the <= 1.10 along-bone stretch)
usage: legs_sheet.py [out_dir] [frames_dir_for_json]"""
import sys, os, json, math, numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kbuild as KB
from kcommon import *
OUT = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else os.path.join(HERE, '..', 'legs_sheet')
SHOULDER = {'S': ((538, 165), (722, 150)), 'E': ((560, 170), (698, 175))}
FR = [0, 3, 6, 9]; TH = 560            # tile figure height in sheet px
MAURO = dict(belt=43, knee=70)         # Claude's nominal lines (his measurement on the GIF), drawn as thin grey ticks

def run_len(alpha, c, u, rmax=60, step=0.25):
    """longest contiguous alpha>0.5 run on the line through c along u (|t| <= rmax)"""
    H, W = alpha.shape; ts = np.arange(-rmax, rmax, step); best = cur = 0
    for t in ts:
        x, y = int(round(c[0] + t * u[0])), int(round(c[1] + t * u[1]))
        on = 0 <= x < W and 0 <= y < H and alpha[y, x] > 0.5
        cur = cur + 1 if on else 0; best = max(best, cur)
    return best * step

def target_meas(F):
    c = KB.KCFG[F]; A = KB.anchors(F); rgb, al = target(F); ys = np.nonzero(al.any(1))[0]; top, sole = int(ys.min()), int(ys.max())
    belt = (c['belt'][0][1] + c['belt'][1][1]) / 2.0
    th = np.asarray(Image.open(f'{PARTS}T{F}_thigh.png').convert('RGBA'))[..., 3] / 255.
    bo = np.asarray(Image.open(f'{PARTS}T{F}_boot.png').convert('RGBA'))[..., 3] / 255.
    if c.get('leg_one'):   # sheet B: measure the SAME painted leg the rig uses (T{F}_leg.png at its own H/K/A anchors)
        th = bo = np.asarray(Image.open(f'{PARTS}T{F}_leg.png').convert('RGBA'))[..., 3] / 255.
    H_, K_ = np.array(A['H'], float), np.array(A['K'], float); u = unit(K_ - H_); n = np.array([-u[1], u[0]])
    bK, bA = np.array(A['bK'], float), np.array(A['bA'], float); ub = unit(bA - bK); nb = np.array([-ub[1], ub[0]])
    sh = math.dist(*SHOULDER[F]); tw = run_len(th, (H_ + K_) / 2, n, 200); bw = run_len(bo, (bK + bA) / 2, nb, 200)
    hb = np.array(KB.contact_pts(F)['HB'], float)
    # target straight length: hip -> heel contact of the painted leg, with the painted leg's own heel (anchors heel/toe frame)
    hipsole = math.dist(H_, K_) + math.dist(bK, np.array(TLEG_HB(F), float))   # the painted thigh + boot laid out straight
    return dict(top=top, sole=sole, belt=belt, knee=float(K_[1] if F == 'S' else bK[1]), H=top and sole - top, thigh_sh=tw / sh, boot_sh=bw / sh,
                thigh_w=tw, boot_w=bw, shoulder=sh, belt_pct=100 * (sole - belt) / (sole - top), knee_pct=100 * ((K_[1] if F == 'S' else bK[1]) - top) / (sole - top),
                hipsole=hipsole)

def TLEG_HB(F):
    """heel-bottom contact point of the source boot as painted on the target (S: same leg as the thigh; E: the near boot)"""
    A = KB.anchors(F); return KB.contact_pts(F)['HB']

def walk_meas(F, i, acc, lay, meta, T):
    c = KB.KCFG[F]; s = c['s_up']; W = frames(F); fr = W[i]; Mt = KB.trunk_M(F, fr, W[0]); pl = plants(F)
    al = acc[..., 3]; top = int(np.nonzero((al > 0.5).any(1))[0].min())
    boots = {sd: lay[sd + '_boot'][..., 3] > 0.5 for sd in 'RL'}
    sole = int(max(np.nonzero(boots[sd].any(1))[0].max() for sd in 'RL'))
    Mt0 = KB.trunk_M(F, W[0], W[0]); dp = jnt(fr, 'pelvis') - jnt(W[0], 'pelvis')
    belt = float((Mt0[:, :2] @ ((np.array(c['belt'][0], float) + np.array(c['belt'][1], float)) / 2) + Mt0[:, 2] + dp)[1])
    bc = Mt0[:, :2] @ ((np.array(c['belt'][0], float) + np.array(c['belt'][1], float)) / 2) + Mt0[:, 2] + dp
    sh = math.dist(*[KB.apm(Mt, p) for p in SHOULDER[F]]); h = sole - top
    legs = {}
    for sd in 'RL':
        g = KB.leg_geo(F, i, sd); hip, kn, an = g['hip'], g['kn'], g['an']
        u = unit(kn - hip); n = np.array([-u[1], u[0]]); ub = unit(an - kn); nb = np.array([-ub[1], ub[0]])
        tw = run_len(lay[sd + '_thigh'][..., 3], (hip + kn) / 2, n); bw = run_len(lay[sd + '_boot'][..., 3], (kn + an) / 2, nb)
        hb = KB.apm(g['Mf'], KB.contact_pts(F)['HB'])
        planted = pl[sd]['heel'][i] or pl[sd]['toe'][i]
        legs[sd] = dict(thigh_sh=tw / sh, boot_sh=bw / sh, thigh_dev=100 * (tw / sh / T['thigh_sh'] - 1), boot_dev=100 * (bw / sh / T['boot_sh'] - 1),
                        knee_pct=100 * (kn[1] - top) / h, straight_pct=100 * math.dist(hip, hb) / (T['hipsole'] * s), bend=meta[sd]['knee_bend_deg'],
                        stretch=g['st'], key=meta[sd]['key'], thigh_deg=meta[sd]['thigh_deg'], planted=bool(planted), heel=bool(pl[sd]['heel'][i]),
                        hip=hip.tolist(), knee=kn.tolist(), ankle=an.tolist())
    # stance leg: heel planted (contact / stance); if both or none, the lower ankle
    cand = [sd for sd in 'RL' if pl[sd]['heel'][i]] or [sd for sd in 'RL' if legs[sd]['planted']] or list('RL')
    st = max(cand, key=lambda q: legs[q]['ankle'][1])
    # knee line as on the target: the boot top of the leg whose sole is the lowest (target: the boot that sets the sole line)
    low = max('RL', key=lambda q: np.nonzero(boots[q].any(1))[0].max())
    hm = (np.array(legs['R']['hip']) + np.array(legs['L']['hip'])) / 2
    return dict(top=top, sole=sole, belt=belt, h=h, shoulder=sh, belt_pct=100 * (sole - belt) / h, knee_line_pct=legs[low]['knee_pct'], knee_leg=low, stance=st,
                belt_vs_target_pct=100 * ((sole - belt) / h / (T['belt_pct'] / 100) - 1), knee_vs_target_pts=legs[low]['knee_pct'] - T['knee_pct'],
                hip_offset_px=float(np.hypot(*(hm - bc))), legs=legs)

def dashed(d, y, x0, x1, col, w=2, dash=10):
    for x in range(int(x0), int(x1), 2 * dash): d.line([(x, y), (min(x + dash, x1), y)], fill=col, width=w)

def tile_img(rgba, top, sole, belt_y, kn_y, T, lines, txt, crop_frac=(0.30, 1.03), wpx=300, bg=(255, 255, 255, 255)):
    """scale so (sole - top) = TH, crop rows crop_frac of the height, centred on the legs"""
    h = sole - top; z = TH / h; im = Image.fromarray(rgba).convert('RGBA')
    im = im.resize((round(im.width * z), round(im.height * z)), Image.LANCZOS)
    y0 = round((top + crop_frac[0] * h) * z); y1 = round((top + crop_frac[1] * h) * z)
    al = np.asarray(im)[..., 3]; cols = np.nonzero((al[y0:y1] > 127).any(0))[0]; cx = (cols.min() + cols.max()) / 2 if len(cols) else im.width / 2
    x0 = int(cx - wpx / 2); t = Image.new('RGBA', (wpx, y1 - y0), bg); t.alpha_composite(im.crop((x0, y0, x0 + wpx, y1)))
    d = ImageDraw.Draw(t); Y = lambda yy: (yy - top) * z - (y0 - top * z)
    # target lines (dashed) at the target % of height
    for frac, col in ((1 - T['belt_pct'] / 100, (40, 90, 230)), (T['knee_pct'] / 100, (240, 140, 0)), (1.0, (0, 160, 60))):
        if lines: dashed(d, Y(top + frac * h), 0, wpx, col, 1)
    for nm, frac in (MAURO.items() if lines else []):
        yy = Y(top + frac / 100 * h); d.line([(0, yy), (14, yy)], fill=(120, 120, 120), width=2); d.line([(wpx - 14, yy), (wpx, yy)], fill=(120, 120, 120), width=2)
    for yy, col in lines: d.line([(0, Y(yy)), (wpx, Y(yy))], fill=col, width=2)
    return t

def main():
    os.makedirs(OUT, exist_ok=True); allm = {}; rows = []
    try: font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13); fb = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 15)
    except Exception: font = fb = ImageFont.load_default()
    VARS = [('S', 'S', {}), ('E', 'E', {})] + ([('E_alt_k0.90', 'E', {'min_k': 0.90})] if '--alt' in sys.argv else [])
    for VN, F, ov in VARS:
        KB.KCFG[F].update(ov); KB._LG.clear()
        if (F, 'body') not in KB.TEX: KB.load_layers(F)
        T = target_meas(F); allm[VN] = dict(target=T, frames={}, overrides=ov)
        rgb, al = target(F); trgba = np.dstack([rgb, al * 255]).astype(np.uint8)
        tiles = [(tile_img(trgba, T['top'], T['sole'], T['belt'], T['knee'], T, [(T['belt'], (40, 90, 230)), (T['knee'], (240, 140, 0)), (T['sole'], (0, 160, 60))], ''),
                  [f'{VN} TARGET (legs, same height)' if not ov else 'E-ALT: k>=0.90 (not the rule)', f"thigh/shoulder {T['thigh_sh']:.3f}", f"boot/shoulder  {T['boot_sh']:.3f}",
                   f"belt->sole {T['belt_pct']:.1f}% of H", f"knee line {T['knee_pct']:.1f}% of H", '(boot top = knee line)'])]
        for i in FR:
            acc, lay, owner, order, meta = KB.render(F, i)
            m = walk_meas(F, i, acc, lay, meta, T); allm[VN]['frames'][f'f{i:02d}'] = m
            lg = np.zeros((CH, CW, 4), np.float32)
            for nm in order:
                if nm.endswith('_thigh') or nm.endswith('_boot'): L = lay[nm]; lg = L + lg * (1 - L[..., 3:])
            a = lg[..., 3]; rgbw = np.where(a[..., None] > 1e-3, lg[..., :3] / np.maximum(a[..., None], 1e-3), 0)
            # faint body silhouette for the hip context (legs-only sheet: the upper body is NOT shown)
            out = np.zeros((CH, CW, 4), np.uint8); out[..., :3] = np.clip(rgbw * 255, 0, 255).astype(np.uint8); out[..., 3] = (np.clip(a, 0, 1) * 255).astype(np.uint8)
            hipm = np.array(m['legs']['R']['hip']) / 2 + np.array(m['legs']['L']['hip']) / 2
            st = m['stance']; L_ = m['legs']
            kn_y = L_[m['knee_leg']]['knee'][1]
            t = tile_img(out, m['top'], m['sole'], m['belt'], kn_y, T, [(m['belt'], (40, 90, 230)), (kn_y, (240, 140, 0)), (m['sole'], (0, 160, 60))], '')
            # hips / knees / ankles markers
            h = m['sole'] - m['top']; z = TH / h; y0 = round((m['top'] + 0.30 * h) * z)
            lab = [f'{VN[:1] if not ov else "E-alt"} f{i:02d}  stance {st}  ' + ' '.join(f"{sd}:{L_[sd]['key']}" for sd in 'RL'),
                   'thigh/sh  ' + '  '.join(f"{sd} {L_[sd]['thigh_sh']:.3f} ({L_[sd]['thigh_dev']:+.1f}%)" for sd in 'RL'),
                   'boot/sh   ' + '  '.join(f"{sd} {L_[sd]['boot_sh']:.3f} ({L_[sd]['boot_dev']:+.1f}%)" for sd in 'RL'),
                   f"belt->sole {m['belt_pct']:.1f}% ({m['belt_vs_target_pct']:+.1f}% vs tgt)",
                   f"knee line {m['knee_line_pct']:.1f}% ({m['knee_vs_target_pts']:+.1f} pts vs tgt) [{m['knee_leg']}]",
                   f"stance straight {L_[st]['straight_pct']:.1f}% of tgt, bend {L_[st]['bend']:.0f}deg",
                   f"hip offset {m['hip_offset_px']:.1f}px  stretch {L_['R']['stretch']:.2f}/{L_['L']['stretch']:.2f}"]
            tiles.append((t, lab))
        rows.append(tiles)
        for k_ in ov: KB.KCFG[F].pop(k_, None)
        KB._LG.clear()
    tw = 300; th_ = rows[0][0][0].height; txt_h = 7 * 17 + 8
    sheet = Image.new('RGB', (tw * 5 + 6 * 8, 40 + len(rows) * (th_ + txt_h + 16)), 'white'); d = ImageDraw.Draw(sheet)
    d.text((10, 8), 'Kestrel v2 LEGS ONLY on blockout v3 (ffbfe3a) - same figure height per tile. Solid: this tile belt (blue) / knee = boot top (orange) / sole (green); dashed: target lines; grey ticks: Claude nominal 43% / 70%', fill='black', font=font)
    for r, tiles in enumerate(rows):
        y = 40 + r * (th_ + txt_h + 16)
        for k, (t, lab) in enumerate(tiles):
            x = 8 + k * (tw + 8); sheet.paste(t.convert('RGB'), (x, y)); d.rectangle([x, y, x + tw - 1, y + t.height - 1], outline=(180, 180, 180))
            for j, ln in enumerate(lab): d.text((x + 2, y + t.height + 4 + 17 * j), ln, fill='black', font=fb if j == 0 else font)
    sheet.save(os.path.join(OUT, 'kestrel_v2_legs_sheet.png'))
    json.dump(allm, open(os.path.join(OUT, 'legs_sheet.json'), 'w'), indent=1, default=float)
    for F in allm:
        T = allm[F]['target']; print(F, 'target thigh/sh %.3f boot/sh %.3f belt %.1f knee %.1f' % (T['thigh_sh'], T['boot_sh'], T['belt_pct'], T['knee_pct']))
        for k, m in allm[F]['frames'].items():
            st = m['stance']; L_ = m['legs']
            print(' ', k, 'stance', st, 'belt %.1f (%+.1f%%) knee %.1f (%+.1f) straight %.1f bend %.0f hip %.1f' % (m['belt_pct'], m['belt_vs_target_pct'], m['knee_line_pct'], m['knee_vs_target_pts'], L_[st]['straight_pct'], L_[st]['bend'], m['hip_offset_px']),
                  ' '.join(f"{sd}:th{L_[sd]['thigh_dev']:+.1f} bo{L_[sd]['boot_dev']:+.1f} {L_[sd]['key']} b{L_[sd]['bend']:.0f}" for sd in 'RL'))

def cycle_strip():
    """all 12 frames per facing, legs only, same height, compact labels (key R/L, stance-leg bend, knee line %, belt->sole %)"""
    try: font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 11)
    except Exception: font = ImageFont.load_default()
    rows = []; js = {}
    for F in 'SE':
        if (F, 'body') not in KB.TEX: KB.load_layers(F)
        T = target_meas(F); tiles = []
        for i in range(12):
            acc, lay, owner, order, meta = KB.render(F, i); m = walk_meas(F, i, acc, lay, meta, T); js[f'{F}_f{i:02d}'] = m
            lg = np.zeros((CH, CW, 4), np.float32)
            for nm in order:
                if nm.endswith('_thigh') or nm.endswith('_boot'): L = lay[nm]; lg = L + lg * (1 - L[..., 3:])
            a = lg[..., 3]; rgbw = np.where(a[..., None] > 1e-3, lg[..., :3] / np.maximum(a[..., None], 1e-3), 0)
            out = np.zeros((CH, CW, 4), np.uint8); out[..., :3] = np.clip(rgbw * 255, 0, 255).astype(np.uint8); out[..., 3] = (np.clip(a, 0, 1) * 255).astype(np.uint8)
            L_ = m['legs']; st = m['stance']
            t = tile_img(out, m['top'], m['sole'], m['belt'], 0, T, [(m['belt'], (40, 90, 230)), (L_[m['knee_leg']]['knee'][1], (240, 140, 0)), (m['sole'], (0, 160, 60))], '', wpx=170)
            t = t.resize((t.width * 2 // 3, t.height * 2 // 3), Image.LANCZOS); d = ImageDraw.Draw(t)
            d.text((2, 2), f'{F} f{i:02d}', fill='black', font=font)
            d.text((2, 14), f"R {L_['R']['key']} {L_['R']['bend']:.0f}d", fill='black', font=font); d.text((2, 26), f"L {L_['L']['key']} {L_['L']['bend']:.0f}d", fill='black', font=font)
            d.text((2, t.height - 26), f"knee {m['knee_line_pct']:.1f}% belt {m['belt_pct']:.1f}%", fill='black', font=font)
            d.text((2, t.height - 13), f"stance {st} {L_[st]['straight_pct']:.0f}% hip {m['hip_offset_px']:.1f}", fill='black', font=font)
            tiles.append(t)
        rows.append(tiles)
    tw, th = rows[0][0].size
    W = Image.new('RGB', (12 * (tw + 4) + 4, 2 * (th + 4) + 4), (230, 230, 230))
    for r, ts in enumerate(rows):
        for c, t in enumerate(ts): W.paste(t.convert('RGB'), (4 + c * (tw + 4), 4 + r * (th + 4)))
    W.save(os.path.join(OUT, 'kestrel_v2_legs_cycle.png')); json.dump(js, open(os.path.join(OUT, 'legs_cycle.json'), 'w'), indent=1, default=float)

if __name__ == '__main__':
    main()
    if '--cycle' in sys.argv: cycle_strip()
