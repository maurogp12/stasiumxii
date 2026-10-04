"""Kestrel v3 (Claude) - legs sheet, side-by-side, cycle numbers and skate.

legs_sheet.png  per facing: target | f00 | f03 | f06 | f09, every tile scaled to the SAME figure height (hood top -> lowest sole),
                lower body from just above the belt to the sole. Solid lines = this tile's belt (blue) / knee = boot top (orange) /
                sole (green); dashed = the target's lines at the same % of height. Numbers under each tile.
side_by_side_f00_f06.png  target | f00 | f06, full figure, same height, S row and E row.
legs_sheet.json every number, for all 12 frames, plus per-frame skate of planted heel / toe points.
Definitions (identical on the target and on the walk):
  H            hood top -> lowest boot sole (alpha)
  belt         the target belt centre line (moved with the body)
  knee line    the boot top of the leg with the lowest sole; the boot is one piece knee -> sole, its top is the knee joint
  thigh/sh     run across the thigh at mid hip->knee (perpendicular to it) / shoulder width (target outer shoulder points)
  boot/sh      run across the boot shaft at mid knee->ankle / shoulder width
  belt->sole   (sole - belt) / H
  hip offset   leg root vs the rule's hip (target belt hips = painted hip centre +- half the blockout hip vector), px
  leg axis     hip -> ankle angle from vertical (+ = toward screen right), compared with the target leg of the same role
               (fwd = the leg whose ankle is further along the walk direction, back = the other)
  stance       the planted leg with the lowest ankle: knee bend (deg between thigh and shin) and along-bone k
  skate        |planted point displacement - ground displacement| between consecutive frames where it is planted in both
usage: sheets.py [out_dir]"""
import os, sys, json, math, numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import krig
from krig import unit, jnt, frames, RIG, CFG
from kcut import target
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(krig.HERE, '..')
RS = 3; KEYS = [0, 3, 6, 9]; TH = 520
WD = {'S': unit([2.0, 1.0]), 'E': unit([2.0, -1.0])}
def font(sz):
    for p in ('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', '/usr/share/fonts/dejavu/DejaVuSans.ttf'):
        if os.path.exists(p): return ImageFont.truetype(p, sz)
    return ImageFont.load_default()
FT, FB = font(13), font(15)

def run_len(alpha, c, u, rmax=200, step=0.25):
    ts = np.arange(-rmax, rmax, step); xs = np.round(c[0] + ts * u[0]).astype(int); ys = np.round(c[1] + ts * u[1]).astype(int)
    ok = (xs >= 0) & (ys >= 0) & (xs < alpha.shape[1]) & (ys < alpha.shape[0])
    on = np.zeros(len(ts), bool); on[ok] = alpha[ys[ok], xs[ok]] > 0.5
    best = cur = 0
    for v in on:
        cur = cur + 1 if v else 0; best = max(best, cur)
    return best * step

def ang(a, b): v = np.subtract(b, a); return math.degrees(math.atan2(v[0], v[1]))
def bend(h, k, a):
    v1, v2 = np.subtract(k, h), np.subtract(a, k); return abs(math.degrees(math.atan2(v1[0] * v2[1] - v1[1] * v2[0], v1 @ v2)))
def nrm(u): return np.array([-u[1], u[0]])

def target_meas(F):
    R = RIG[F]; rgb, al = target(F); ys = np.nonzero(al.any(1))[0]; top, sole = int(ys.min()), int(ys.max()); H = sole - top
    belt = (R['belt'][0][1] + R['belt'][1][1]) / 2; sh = math.dist(*R['shoulder'])
    leg = np.asarray(Image.open(f'{krig.PARTS}/leg_{F}.png'))[..., 3] / 255.
    Hh, K, A = (np.array(R[k], float) for k in ('H', 'K', 'A'))
    tw = run_len(leg, (Hh + K) / 2, nrm(unit(K - Hh))); bw = run_len(leg, (K + A) / 2, nrm(unit(A - K)))
    near_ax = ang(R['hips']['near'], R['A']); far_ax = ang(R['hips']['far'], R['far_ankle'])
    # role of the painted legs: S near leg is the forward one, E near leg is the back one
    roles = {'fwd': near_ax, 'back': far_ax} if F == 'S' else {'fwd': far_ax, 'back': near_ax}
    return dict(top=top, sole=sole, H=H, belt=belt, knee=float(K[1]), thigh_sh=tw / sh, boot_sh=bw / sh, shoulder=sh,
                belt_pct=100 * (sole - belt) / H, knee_pct=100 * (K[1] - top) / H, axis=roles, stance_bend=bend(Hh, K, A),
                thigh_w=tw, boot_w=bw)

def walk_meas(F, i, T):
    img, meta = krig.render(F, i, RS); al = img[..., 3]
    dy = krig.get_dy(F); BT = krig.body_T(F, i, dy); s = BT[0]; pl = krig.plants(F)
    top = int(np.nonzero((al > 0.5).any(1))[0].min()) / RS
    legs = {}; soles = {}
    for sd in 'RL':
        P = krig.leg_pose(F, i, sd, dy, pl)
        La = krig.skin(F, f'leg_{F}' if sd == 'L' else f'legfar_{F}', P, RS)[..., 3]
        soles[sd] = np.nonzero((La > 0.5).any(1))[0].max() / RS
        hip, kn, an = P['hip'], P['knee'], P['ankle']
        tw = run_len(La, (hip + kn) / 2 * RS, nrm(unit(kn - hip))) / RS
        bw = run_len(La, (kn + an) / 2 * RS, nrm(unit(an - kn))) / RS
        ax = ang(hip, an)
        legs[sd] = dict(thigh_sh=tw / (s * T['shoulder']), boot_sh=bw / (s * T['shoulder']), axis_deg=round(ax, 1), bend=round(bend(hip, kn, an), 1), k=round(P['k'], 3),
                        planted=P['planted'], heel=bool(P['heel_pl']), toe=bool(P['toe_pl']), hip=hip.tolist(), knee=kn.tolist(), ankle=an.tolist(),
                        hip_offset_px=0.0)
    # role: the leg whose ankle is further along the walk direction is the forward leg
    fw = max('RL', key=lambda sd: np.array(legs[sd]['ankle']) @ WD[F])
    for sd in 'RL':
        legs[sd]['role'] = 'fwd' if sd == fw else 'back'; legs[sd]['axis_dev'] = round(legs[sd]['axis_deg'] - T['axis'][legs[sd]['role']], 1)
    sole = max(soles.values()); low = max(soles, key=soles.get)
    belt = s * T['belt'] + BT[2]; H = sole - top
    pl_legs = [sd for sd in 'RL' if legs[sd]['planted']]
    st = max(pl_legs, key=lambda sd: legs[sd]['ankle'][1]) if pl_legs else low
    # hip vs the painted hips (information: how far the rule's hips sit from where the painting has them)
    ph = {sd: np.array(krig.tpt(BT, RIG[F]['hips']['near' if sd == 'L' else 'far'])) for sd in 'RL'}
    for sd in 'RL': legs[sd]['hip_vs_painted_px'] = round(float(np.linalg.norm(np.array(legs[sd]['hip']) - ph[sd])), 1)
    return img, dict(top=top, sole=sole, H=H, belt=belt, belt_pct=100 * (sole - belt) / H, knee_leg=low,
                     knee_pct=100 * (legs[low]['knee'][1] - top) / H, stance=st, legs=legs, near=meta['near'])

def skate(F):
    pl = krig.plants(F); dy = krig.get_dy(F); out = []
    for sd in 'RL':
        for i in range(12):
            j = (i + 1) % 12
            for k in ('heel', 'toe'):
                if pl[sd][k][i] and pl[sd][k][j]:
                    a = krig.leg_pose(F, i, sd, dy, pl)[k]; b = krig.leg_pose(F, j, sd, dy, pl)[k]
                    out.append(dict(leg=sd, point=k, frames=f'f{i:02d}->f{j:02d}', skate_px=round(float(np.linalg.norm(b - a - krig.EXP[F])), 2)))
    return out

def tile(rgbA, top, sole, belt, knee, T, scale_px, w=300, bg=(255, 255, 255), dashed=True, full=False):
    """crop rgbA (premult float or uint8 RGBA) so the figure height (top->sole) is TH px; lower body (or full) shown."""
    H = sole - top; k = TH / H
    y0 = top + (0 if full else (belt - top) - 0.14 * H); y1 = sole + 0.03 * H
    a = rgbA.astype(np.float32)
    if a.max() > 1.5: a = a / 255.; a = np.dstack([a[..., :3] * a[..., 3:], a[..., 3:]])
    c = a[..., :3] + np.array(bg, np.float32) / 255 * (1 - a[..., 3:])
    ys = np.nonzero(a[..., 3].max(0) > 0.5)[0]
    xs_ = np.nonzero((a[int(y0 * scale_px):int(y1 * scale_px), :, 3] > 0.5).any(0))[0]
    cx = (xs_.min() + xs_.max()) / 2 / scale_px
    hw = w / 2 / k
    x0 = cx - hw; M = np.float32([[k / scale_px, 0, -x0 * k], [0, k / scale_px, -y0 * k]])
    hh = int((y1 - y0) * k)
    im = cv2.warpAffine((c * 255).astype(np.uint8), M, (w, hh), flags=cv2.INTER_AREA, borderValue=bg)
    pim = Image.fromarray(im); d = ImageDraw.Draw(pim)
    def yl(v): return (v - y0) * k
    for v, col in ((belt, (40, 90, 230)), (knee, (240, 140, 0)), (sole, (0, 160, 60))):
        d.line([(0, yl(v)), (w, yl(v))], fill=col, width=2)
    if dashed:
        for pct, col in ((T['belt'] - T['top']) / T['H'], (40, 90, 230)), ((T['knee'] - T['top']) / T['H'], (240, 140, 0)):
            y = yl(top + pct * H)
            for x in range(0, w, 12): d.line([(x, y), (x + 6, y)], fill=col, width=1)
    return pim

def main():
    os.makedirs(OUT, exist_ok=True); res = {}; rows = []; sbs = []
    for F in 'SE':
        T = target_meas(F); rgb, al = target(F)
        trgba = np.dstack([rgb, al * 255]).astype(np.uint8)
        res[F] = dict(target={k: (round(v, 4) if isinstance(v, float) else v) for k, v in T.items()}, frames={}, skate=skate(F))
        tiles = [(tile(trgba, T['top'], T['sole'], T['belt'], T['knee'], T, 1.0),
                  [f'{F} TARGET (same height)', f"thigh/shoulder {T['thigh_sh']:.3f}", f"boot/shoulder  {T['boot_sh']:.3f}",
                   f"belt->sole {T['belt_pct']:.1f}% of H", f"knee line {T['knee_pct']:.1f}% of H",
                   f"leg axis fwd {T['axis']['fwd']:+.1f}  back {T['axis']['back']:+.1f} deg", f"painted stance bend {T['stance_bend']:.0f} deg"])]
        sb = [tile(trgba, T['top'], T['sole'], T['belt'], T['knee'], T, 1.0, w=470, full=True, dashed=False)]
        if F == 'S': strip = [('S approved target', tile(trgba, T['top'], T['sole'], T['belt'], T['knee'], T, 1.0, w=380, full=True, dashed=False))]
        for i in range(12):
            img, m = walk_meas(F, i, T); res[F]['frames'][f'f{i:02d}'] = m
            L = m['legs']; st = m['stance']
            m['belt_vs_target_pct'] = round(m['belt_pct'] - T['belt_pct'], 2); m['knee_vs_target_pts'] = round(m['knee_pct'] - T['knee_pct'], 2)
            for sd in 'RL':
                L[sd]['thigh_dev_pct'] = round(100 * (L[sd]['thigh_sh'] / T['thigh_sh'] - 1), 1); L[sd]['boot_dev_pct'] = round(100 * (L[sd]['boot_sh'] / T['boot_sh'] - 1), 1)
            if i in KEYS:
                knee = L[m['knee_leg']]['knee'][1]
                tl = tile(img, m['top'] * 1.0, m['sole'], m['belt'], knee, T, RS)
                txt = [f"{F} f{i:02d}  stance {st}  R:{L['R']['role']} L:{L['L']['role']}",
                       f"thigh/sh R {L['R']['thigh_sh']:.3f} ({L['R']['thigh_dev_pct']:+.1f}%) L {L['L']['thigh_sh']:.3f} ({L['L']['thigh_dev_pct']:+.1f}%)",
                       f"boot/sh  R {L['R']['boot_sh']:.3f} ({L['R']['boot_dev_pct']:+.1f}%) L {L['L']['boot_sh']:.3f} ({L['L']['boot_dev_pct']:+.1f}%)",
                       f"belt->sole {m['belt_pct']:.1f}% ({m['belt_vs_target_pct']:+.1f} pts vs tgt)",
                       f"knee line {m['knee_pct']:.1f}% ({m['knee_vs_target_pts']:+.1f} pts) [{m['knee_leg']}]",
                       f"stance {st}: bend {L[st]['bend']:.0f} deg, k {L[st]['k']:.2f}",
                       f"hip offset 0 px (rule); vs painted R {L['R']['hip_vs_painted_px']:.0f} L {L['L']['hip_vs_painted_px']:.0f} px",
                       f"axis R {L['R']['axis_deg']:+.1f} ({L['R']['role']} {L['R']['axis_dev']:+.1f})  L {L['L']['axis_deg']:+.1f} ({L['L']['role']} {L['L']['axis_dev']:+.1f})"]
                tiles.append((tl, txt))
                if i in (0, 6): sb.append(tile(img, m['top'] * 1.0, m['sole'], m['belt'], knee, T, RS, w=470, full=True, dashed=False))
                if F == 'S': strip.append((f'S walk f{i:02d}', tile(img, m['top'] * 1.0, m['sole'], m['belt'], knee, T, RS, w=380, full=True, dashed=False)))
        rows.append(tiles); sbs.append(sb)
        sk = [d['skate_px'] for d in res[F]['skate']]
        print(F, 'target', {k: round(T[k], 3) for k in ('thigh_sh', 'boot_sh', 'belt_pct', 'knee_pct')}, T['axis'], 'max skate', max(sk))
        for i in range(12):
            m = res[F]['frames'][f'f{i:02d}']; L = m['legs']; st = m['stance']
            print(f" f{i:02d} st {st} belt {m['belt_vs_target_pct']:+.1f} knee {m['knee_vs_target_pts']:+.1f} thigh {L['R']['thigh_dev_pct']:+.1f}/{L['L']['thigh_dev_pct']:+.1f}"
                  f" boot {L['R']['boot_dev_pct']:+.1f}/{L['L']['boot_dev_pct']:+.1f} bend {L[st]['bend']:.0f} k {L[st]['k']:.2f}"
                  f" axis R {L['R']['axis_deg']:+.1f}({L['R']['role']} {L['R']['axis_dev']:+.1f}) L {L['L']['axis_deg']:+.1f}({L['L']['role']} {L['L']['axis_dev']:+.1f})")
    # legs sheet
    tw = 300; th = max(t.height for r in rows for t, _ in r); txt_h = 8 * 18 + 10
    W = 5 * (tw + 10) + 10; Hs = 40 + len(rows) * (th + txt_h + 20)
    sheet = Image.new('RGB', (W, Hs), (255, 255, 255)); d = ImageDraw.Draw(sheet)
    d.text((10, 10), 'Kestrel v3 (Claude) legs on blockout v3.2 (S) / v3.1 (E): one continuous painted leg (hip -> sole) per side, mesh-skinned on 3 bones. '
           'Solid = this tile belt / knee (boot top) / sole; dashed = target lines at the same % of height.', fill='black', font=FT)
    y = 40
    for r in rows:
        x = 10
        for t, tx in r:
            sheet.paste(t, (x, y)); d.rectangle([x, y, x + t.width - 1, y + t.height - 1], outline=(190, 190, 190))
            for j, line in enumerate(tx): d.text((x, y + th + 6 + j * 18), line, fill='black', font=FB if j == 0 else FT)
            x += tw + 10
        y += th + txt_h + 20
    sheet.save(os.path.join(OUT, 'legs_sheet.png'))
    # side by side
    sw = 470; sh_ = max(t.height for r in sbs for t in r)
    S2 = Image.new('RGB', (3 * (sw + 10) + 10, 40 + 2 * (sh_ + 40)), (255, 255, 255)); d = ImageDraw.Draw(S2)
    d.text((10, 10), 'Kestrel v3 (Claude): approved target | walk f00 | walk f06, same figure height (hood -> sole).', fill='black', font=FT)
    for r, (F, row) in enumerate(zip('SE', sbs)):
        for c, (t, lab) in enumerate(zip(row, ('TARGET', 'walk f00', 'walk f06'))):
            x = 10 + c * (sw + 10); yy = 40 + r * (sh_ + 40)
            d.text((x, yy), f'{F} {lab}', fill='black', font=FB); S2.paste(t, (x, yy + 22))
    S2.save(os.path.join(OUT, 'side_by_side_f00_f06.png'))
    # S strip: the approved target beside walk f00 / f03 / f06 / f09, full figure, same height
    sw = 380; sh_ = max(t.height for _, t in strip)
    S3 = Image.new('RGB', (len(strip) * (sw + 10) + 10, 40 + sh_ + 32), (255, 255, 255)); d = ImageDraw.Draw(S3)
    d.text((10, 10), 'Kestrel S (blockout v3.2): approved target | walk f00 | f03 | f06 | f09, same figure height (hood -> sole).', fill='black', font=FT)
    for c, (lab, t) in enumerate(strip):
        x = 10 + c * (sw + 10); d.text((x, 40), lab, fill='black', font=FB); S3.paste(t, (x, 62))
    S3.save(os.path.join(OUT, 'strip_S_target_f00_f03_f06_f09.png'))
    json.dump(res, open(os.path.join(OUT, 'legs_sheet.json'), 'w'), indent=1, default=float)

if __name__ == '__main__':
    main()
