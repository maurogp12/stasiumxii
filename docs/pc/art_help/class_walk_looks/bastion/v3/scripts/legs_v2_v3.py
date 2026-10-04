"""legs crop sheet per facing (legs_check.png layout): approved target leg crop | v2 f00 | v2 f06 | v3 f00 | v3 f06 | ratio column.
Inputs: saved frames of both builds + the leg_ratio.py json of each build (run leg_ratio.py with each build's scripts).
Marks: yellow line = target belt bottom (after the pelvis delta), yellow cross = target belt centre, magenta dots = the hips the
legs are rooted at (v2: blockout hips; v3: target hips), cyan line = lowest sole row.
usage: legs_v2_v3.py V2_DIR V3_DIR RATIO_V2_JSON RATIO_V3_JSON OUT_DIR"""
import sys, json, numpy as np, cv2
from PIL import Image, ImageDraw
V2, V3, R2, R3, OUT = sys.argv[1:6]
R2, R3 = json.load(open(R2)), json.load(open(R3))
T = '/workspace/handoff/class_walk_blockouts/targets/'
sys.path.insert(0, V3 + '/scripts'); import build_hybrid as BH
BELT_Y = {'S': 300, 'E': 305}; X0, X1, H, Z = 136, 376, 420, 2
for F in 'SE':
    W = BH.frames(F); Mt0 = BH.trunk_M(F, W[0]); r3t = R3[F]['target']
    trgb = np.asarray(Image.open(f'{T}bastion_rp_{F}_f00.jpg').convert('RGB')); ta = np.asarray(Image.open(f'{T}bastion_rp_{F}_f00_alpha.png').convert('L')) > 127
    w = cv2.warpAffine(np.dstack([trgb, ta * 255]).astype(np.uint8), Mt0.astype(np.float32), (512, H), flags=cv2.INTER_AREA)
    tg = np.full((H, 512, 3), 128, np.uint8); m = w[..., 3] > 127; tg[m] = w[..., :3][m]
    belt0 = R3[F]['f00']['belt_centre']
    panels = [(f'{F} approved target (trunk scale)', tg, belt0, None, int(np.nonzero(m.any(1))[0].max()),
               [f'greave/shoulder {r3t["ratio"]:.4f}', f'thigh/shoulder {r3t["thigh_ratio"]:.4f}'])]
    for tag, d, R in (('v2', V2, R2), ('v3', V3, R3)):
        for i in (0, 6):
            a = np.asarray(Image.open(f'{d}/frames/bastion_walk_{F}_f{i:02d}.png')); im = np.full((H, 512, 3), 128, np.uint8)
            mm = a[..., 3] > 0; im[:360][mm] = a[..., :3][mm]; x = R[F][f'f{i:02d}']
            panels.append((f'{F} {tag} f{i:02d}', im, x['belt_centre'], x['hips'], int(np.nonzero(mm.any(1))[0].max()),
                           [f'greave/shoulder {x["ratio"]:.4f} ({x["ratio_vs_target_pct"]:+.1f}% vs target)',
                            f'thigh/shoulder vs target R {x["thigh_ratio_vs_target_pct"]["R"]:+.1f}% L {x["thigh_ratio_vs_target_pct"]["L"]:+.1f}%',
                            f'sabaton scale vs target {x["sabaton_linear_scale_vs_target"]["R"]:.3f}',
                            f'hip midpoint - belt centre {x["hip_mid_off_px"]:.1f} px']))
    y0 = int(min(p[2][1] for p in panels)) - 40; y1 = min(H, max(p[4] for p in panels) + 12)
    cells = []
    for lab, im, bc, hips, sole, txt in panels:
        c = Image.fromarray(im[y0:y1, X0:X1]).resize(((X1 - X0) * Z, (y1 - y0) * Z), Image.LANCZOS); dr = ImageDraw.Draw(c)
        P = lambda p: ((p[0] - X0) * Z, (p[1] - y0) * Z)
        by = (bc[1] - y0) * Z; dr.line([(0, by), (c.width, by)], fill=(255, 220, 0)); bx, byy = P(bc)
        dr.line([(bx - 8, byy), (bx + 8, byy)], fill=(255, 220, 0), width=2); dr.line([(bx, byy - 8), (bx, byy + 8)], fill=(255, 220, 0), width=2)
        if hips:
            for sd, hp in hips.items():
                hx, hy = P(hp); dr.ellipse([hx - 5, hy - 5, hx + 5, hy + 5], outline=(255, 0, 255), width=2); dr.text((hx + 7, hy - 6), sd, fill=(255, 0, 255))
        sy = (sole - y0) * Z; dr.line([(0, sy), (c.width, sy)], fill=(0, 255, 255))
        dr.rectangle([0, 0, c.width, 14 * (len(txt) + 1) + 4], fill=(0, 0, 0))
        dr.text((6, 3), lab, fill=(255, 255, 255))
        for k, t_ in enumerate(txt): dr.text((6, 17 + 14 * k), t_, fill=(255, 255, 160))
        cells.append(c)
    # ratio column
    col = Image.new('RGB', (440, cells[0].height), (30, 30, 30)); dr = ImageDraw.Draw(col); y = 8
    lines = [f'{F}: leg size and rooting', '', f'target greave/shoulder  {r3t["ratio"]:.4f}', f'  greave {r3t["greave_w"]:.1f} / shoulder {r3t["shoulder_w"]:.1f} target px', '']
    for tag, R in (('v2', R2), ('v3', R3)):
        for i in ('f00', 'f06'):
            x = R[F][i]
            lines += [f'{tag} {i}: greave/shoulder {x["ratio"]:.4f}  ({x["ratio_vs_target_pct"]:+.1f}%)',
                      f'   greave R {x["greave_w"]["R"]:.1f} L {x["greave_w"]["L"]:.1f} / shoulder {x["shoulder_w"]:.0f} px',
                      f'   thigh vs target R {x["thigh_ratio_vs_target_pct"]["R"]:+.1f}%  L {x["thigh_ratio_vs_target_pct"]["L"]:+.1f}%',
                      f'   sabaton scale R {x["sabaton_linear_scale_vs_target"]["R"]:.3f} L {x["sabaton_linear_scale_vs_target"]["L"]:.3f}',
                      f'   hip mid - belt centre {x["hip_mid_off_px"]:.2f} px  (dx {x["hip_mid_off_xy"][0]:+.1f}, dy {x["hip_mid_off_xy"][1]:+.1f})', '']
    lines += ['limits: greave/shoulder within 8% of target,', 'hip midpoint within 4 px of belt centre', '',
              'yellow line/cross: target belt (bottom row, centre)', 'magenta: hips the legs are rooted at', 'cyan: lowest sole row']
    for ln in lines: dr.text((10, y), ln, fill=(235, 235, 235)); y += 15
    sheet = Image.new('RGB', (sum(c.width for c in cells) + 10 * len(cells) + col.width, cells[0].height), (40, 40, 40)); x = 0
    for c in cells + [col]: sheet.paste(c, (x, 0)); x += c.width + 10
    sheet.save(f'{OUT}/legs_v2_v3_{F}.png'); print('ok', F, sheet.size)
