"""Post: grid overlay pass, strips, QA measured from the renders, preview GIF, contact sheet, manifest, checksums.
Run: .venv/bin/python src/post.py   (after src/render.py)
"""
import os, sys, json, math, hashlib, glob
import numpy as np
from PIL import Image, ImageDraw, ImageFont

BASE = '/workspace/art_src/blockout/ironjaw_walk'
RND = BASE + '/renders'
QA = BASE + '/qa'
PICS = '/workspace/luca_pics/chars'
REF = '/workspace/art/ironjaw_full'
W, H = 460, 360
PIV = (230, 329)
NF = 12
FPS = 17.144
DRAW = 0.30                      # final in-game draw_scale (about)
TILE_BOARD = (64, 32)            # board tile, board px
cam = json.load(open(BASE + '/camera.json'))
meta = json.load(open(QA + '/model_meta.json'))
FR = meta['frames']
SPX = meta['px_per_unit']
Rv = np.array(meta['Rv']) * SPX; Uv = np.array(meta['Uv']) * SPX
XO, YO = meta['XO'], meta['YO']
V = meta['V_world_per_frame']
PH_OFF = {'S': 0, 'E': 1}
NAMES = ['walk_%s_f%02d' % (F, f) for F in 'SE' for f in range(NF)] + ['idle_S', 'idle_E']


def proj(p):
    p = np.asarray(p, float)
    return XO + p @ Rv, YO - p @ Uv


def load(pas, n):
    return np.array(Image.open('%s/%s/%s.png' % (RND, pas, n)).convert('RGBA'))


# ------------------------------------------------------------------ grid overlay pass
TILE_W = (TILE_BOARD[0] / 2 / DRAW) / abs(Rv[0])   # tile edge along world X: screen dx = 32/0.30 px
try:
    FONT = ImageFont.load_default(size=11)
except TypeError:
    FONT = ImageFont.load_default()


def grid_layer():
    g = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    d.fontmode = '1'
    R = 6
    for k4 in range(-R * 4, R * 4 + 1):
        t = (k4 / 4.0 + 0.5) * TILE_W          # tile centred on the body ground point
        major = (k4 % 4 == 0)
        col = (40, 110, 190, 255) if major else (150, 185, 225, 255)
        for axis in (0, 1):
            a = np.zeros(3); b = np.zeros(3)
            a[axis] = b[axis] = t
            a[1 - axis] = -R * TILE_W; b[1 - axis] = R * TILE_W
            pa, pb = proj(a), proj(b)
            if major:
                d.line([pa, pb], fill=col, width=1)
            else:   # dashed
                n = 120
                for i in range(0, n, 2):
                    q0 = (pa[0] + (pb[0] - pa[0]) * i / n, pa[1] + (pb[1] - pa[1]) * i / n)
                    q1 = (pa[0] + (pb[0] - pa[0]) * (i + 1) / n, pa[1] + (pb[1] - pa[1]) * (i + 1) / n)
                    d.line([q0, q1], fill=col, width=1)
    return g


def ruler_layer(top_row):
    g = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    d.fontmode = '1'
    x0 = 6
    d.line([(x0 + 14, PIV[1] - 290), (x0 + 14, PIV[1])], fill=(0, 0, 0, 255))
    for h in range(0, 291, 10):
        y = PIV[1] - h
        L = 10 if h % 50 == 0 else 5
        d.line([(x0 + 14 - L, y), (x0 + 14, y)], fill=(0, 0, 0, 255))
        if h % 50 == 0 and h:
            d.text((x0 + 17, y - 6), '%d' % h, fill=(0, 0, 0, 255), font=FONT)
    # guide lines
    d.line([(0, PIV[1]), (W - 1, PIV[1])], fill=(220, 30, 30, 255))                 # pivot row / lowest planted sole
    yo = int(math.floor(YO))
    for x in range(0, W, 6):
        d.line([(x, yo), (x + 2, yo)], fill=(240, 140, 0, 255))                       # body ground point row
    d.line([(PIV[0] - 6, PIV[1]), (PIV[0] + 6, PIV[1])], fill=(220, 30, 30, 255))
    d.line([(PIV[0], PIV[1] - 6), (PIV[0], PIV[1] + 6)], fill=(220, 30, 30, 255))
    d.line([(PIV[0] - 4, yo), (PIV[0] + 4, yo)], fill=(240, 140, 0, 255))
    d.line([(PIV[0], yo - 4), (PIV[0], yo + 4)], fill=(240, 140, 0, 255))
    for x in range(0, W, 4):
        d.point((x, top_row), fill=(30, 140, 60, 255))                                # idle helm top
    d.text((W - 150, PIV[1] + 4), 'pivot row 329 (lowest sole)', fill=(220, 30, 30, 255), font=FONT)
    d.text((W - 150, yo - 14), 'body ground pt y=%.1f' % YO, fill=(240, 140, 0, 255), font=FONT)
    d.text((W - 150, top_row - 13), 'idle top (horn/spike)', fill=(30, 140, 60, 255), font=FONT)
    d.text((x0, H - 14), 'px above row 329 (cell px; x%.2f = board px). grid = 64x32 board tile @ %.2f' % (DRAW, DRAW),
           fill=(0, 0, 0, 255), font=FONT)
    return g


def top_row(a):
    rows = np.where((a[:, :, 3] > 0).any(1))[0]
    return int(rows[0]), int(rows[-1])


idle_top = min(top_row(load('sil', 'idle_S'))[0], top_row(load('sil', 'idle_E'))[0])
GL = grid_layer(); RL = ruler_layer(idle_top)
os.makedirs(RND + '/grid', exist_ok=True)
for n in NAMES:
    im = GL.copy()
    im.alpha_composite(Image.open('%s/clay/%s.png' % (RND, n)).convert('RGBA'))
    im.alpha_composite(RL)
    im.save('%s/grid/%s.png' % (RND, n), optimize=True)

# ------------------------------------------------------------------ strips
for pas in ('clay', 'sides', 'sil', 'grid'):
    for F in 'SE':
        s = Image.new('RGBA', (W * NF, H), (0, 0, 0, 0))
        for f in range(NF):
            s.paste(Image.open('%s/%s/walk_%s_f%02d.png' % (RND, pas, F, f)), (f * W, 0))
        s.save('%s/%s/walk_%s_strip.png' % (RND, pas, F), optimize=True)

# ------------------------------------------------------------------ QA measured from renders
ID = {k: tuple(v) for k, v in meta['id_colors'].items()}


def bootmask(n, side):
    a = np.array(Image.open('%s/idpass/bootonly_%s/%s.png' % (QA, side, n)).convert('RGBA'))
    return a[:, :, 3] > 0


def idmask(n, part):
    a = np.array(Image.open('%s/idpass/id/%s.png' % (QA, n)).convert('RGBA'))
    c = ID[part]
    return (a[:, :, 3] > 0) & (a[:, :, 0] == c[0]) & (a[:, :, 1] == c[1]) & (a[:, :, 2] == c[2])


def best_shift(m0, m1, exp, rad=3):
    """integer shift s maximising IoU(shift(m0, s), m1), searched around the expected shift."""
    best = None
    ys0, xs0 = np.nonzero(m0)
    for dy in range(int(round(exp[1])) - rad, int(round(exp[1])) + rad + 1):
        for dx in range(int(round(exp[0])) - rad, int(round(exp[0])) + rad + 1):
            ys, xs = ys0 + dy, xs0 + dx
            ok = (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W)
            sh = np.zeros_like(m0); sh[ys[ok], xs[ok]] = True
            inter = (sh & m1).sum(); uni = (sh | m1).sum()
            iou = inter / uni if uni else 0
            if best is None or iou > best[2]:
                best = (dx, dy, iou)
    return best


qa = {'facings': {}, 'summary': {}}
all_drift = []; all_world = []; contact_rows = []
for F in 'SE':
    fq = {'frames': [], 'planted_intervals': []}
    # bob: helm top row (sil), head-part centroid (id), pelvis projection (model)
    tops, heads, pel = [], [], []
    for f in range(NF):
        n = 'walk_%s_f%02d' % (F, f)
        t, b = top_row(load('sil', n))
        hm = idmask(n, 'head'); ys, xs = np.nonzero(hm)
        tops.append(t); heads.append(float(ys.mean())); pel.append(FR[n]['pelvis_proj'][1])
        row = {'frame': n, 'phase_frame': FR[n]['phase_frame'], 'helm_top_row': t, 'lowest_row': b,
               'head_centroid_y': round(float(ys.mean()), 2), 'pelvis_proj_y': round(FR[n]['pelvis_proj'][1], 2)}
        for side in 'RL':
            bm = FR[n]['boot_' + side]
            mk = bootmask(n, side)
            yy = np.nonzero(mk)[0]
            row['boot_' + side] = {'planted': bm['planted'], 'sole_min_z_world': round(bm['min_z'], 6),
                                   'ik_ankle_error': bm['ik_ankle_error'],
                                   'lowest_row_render': int(yy.max()) if len(yy) else None,
                                   'lowest_row_model': int(math.floor(bm['proj_lowest_y'] - 1e-9))}
        fq['frames'].append(row)

    def stats(v):
        v = np.array(v, float); d = np.diff(np.r_[v, v[0]])
        return {'values': [round(x, 2) for x in v], 'range_cell_px': round(float(v.max() - v.min()), 2),
                'max_step_cell_px': round(float(np.abs(d).max()), 2),
                'range_final_px': round(float(v.max() - v.min()) * DRAW, 2),
                'max_step_final_px': round(float(np.abs(d).max()) * DRAW, 2)}
    fq['bob_helm_top_row'] = stats(tops)
    fq['bob_head_centroid'] = stats(heads)
    fq['bob_pelvis_model'] = stats(pel)
    # planted intervals in render-frame numbering
    for side, cphase in (('R', 0), ('L', 6)):
        c = (cphase - PH_OFF[F]) % NF
        frames = [(c + k) % NF for k in range(7)]
        names = ['walk_%s_f%02d' % (F, f) for f in frames]
        assert all(FR[x]['boot_' + side]['planted'] for x in names), (F, side, frames)
        # world-space drift from the model (in-place verts + root travel)
        w0 = np.array(FR[names[0]]['boot_' + side]['verts_world'])
        # wrap: frames after f11 belong to the next loop -> add one cycle of travel
        fwd = np.array([1.0, 0, 0]) if F == 'S' else np.array([0, 1.0, 0])
        wd = []
        for k, x in enumerate(names):
            wv = np.array(FR[x]['boot_' + side]['verts_world'])
            if frames[k] < frames[0]:
                wv = wv + fwd * V * NF
            wd.append(float(np.abs(wv - w0).max()))
        # screen drift measured from the id renders
        m0 = bootmask(names[0], side)
        a0 = np.array(FR[names[0]]['boot_' + side]['proj_ankle'])
        sd = []
        for k, x in enumerate(names[1:], 1):
            a1 = np.array(FR[x]['boot_' + side]['proj_ankle'])
            exp = a1 - a0
            m1 = bootmask(x, side)
            dx, dy, iou = best_shift(m0, m1, exp)
            sd.append({'frame': x, 'expected_shift_px': [round(float(e), 3) for e in exp], 'measured_shift_px': [dx, dy],
                       'drift_px': [round(dx - float(exp[0]), 3), round(dy - float(exp[1]), 3)], 'mask_iou': round(iou, 4)})
            all_drift.append(max(abs(dx - exp[0]), abs(dy - exp[1])))
        all_world += wd
        cont = names[0]
        crow = fq['frames'][frames[0]]['boot_' + side]['lowest_row_render']
        contact_rows.append((F, side, cont, crow))
        fq['planted_intervals'].append({'boot': side, 'near_far': 'near' if side == 'R' else 'far',
                                        'contact_frame': cont, 'planted_frames': names,
                                        'world_drift_max_units': max(wd), 'screen': sd,
                                        'contact_lowest_row_render': crow,
                                        'contact_sole_min_z_world': FR[cont]['boot_' + side]['min_z']})
    qa['facings'][F] = fq

# margins + alpha over every render
marg = {}; alphas = set(); minm = 1e9; worst = None
for pas in ('clay', 'sides', 'sil'):
    for n in NAMES:
        a = load(pas, n)
        alphas |= set(np.unique(a[:, :, 3]).tolist())
        ys, xs = np.nonzero(a[:, :, 3])
        m = int(min(xs.min(), ys.min(), W - 1 - xs.max(), H - 1 - ys.max()))
        marg['%s/%s' % (pas, n)] = {'bbox': [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())], 'margin': m}
        if m < minm:
            minm, worst = m, '%s/%s' % (pas, n)
qa['margins'] = marg
travel_cycle = math.hypot(12 * NF, 6 * NF)
tile_cell = math.hypot(TILE_BOARD[0] / 2, TILE_BOARD[1] / 2) / DRAW
qa['summary'] = {
    'min_margin_px': minm, 'min_margin_at': worst,
    'alpha_values': sorted(alphas),
    'planted_world_drift_max_units': max(all_world),
    'planted_screen_drift_max_px': round(float(max(all_drift)), 3),
    'contact_lowest_rows': contact_rows,
    'travel_per_frame_cell_px': [12, 6], 'travel_per_frame_diag_cell_px': round(math.hypot(12, 6), 4),
    'travel_per_cycle_diag_cell_px': round(travel_cycle, 3),
    'travel_per_cycle_diag_final_px': round(travel_cycle * DRAW, 3),
    'travel_per_cycle_final_px_xy': [round(12 * NF * DRAW, 2), round(6 * NF * DRAW, 2)],
    'tile_diag_cell_px_at_draw_scale': round(tile_cell, 3),
    'frames_per_cell': round(tile_cell / math.hypot(12, 6), 4),
    'cells_per_cycle': round(travel_cycle / tile_cell, 4),
    'tile_sec_at_17.144fps': round(tile_cell / math.hypot(12, 6) / FPS, 4),
    'board_speed_px_per_s_at_17.144fps': round(math.hypot(12, 6) * DRAW * FPS, 3),
    'idle_helm_top_row': {F: top_row(load('sil', 'idle_' + F))[0] for F in 'SE'},
    'idle_lowest_row': {F: top_row(load('sil', 'idle_' + F))[1] for F in 'SE'},
    'body_ground_point_px': [XO, YO],
}
json.dump(qa, open(BASE + '/qa.json', 'w'), indent=1)

# ------------------------------------------------------------------ preview GIF (S | E, clay over grid / sides), 1:1 pixels
# cropped to the union of the figure over every walk frame (+10 px) inside the cell; never downscaled.
os.makedirs(PICS, exist_ok=True)
ub = [W, H, 0, 0]
for F in 'SE':
    for f in range(NF):
        a = load('sil', 'walk_%s_f%02d' % (F, f)); ys, xs = np.nonzero(a[:, :, 3])
        ub = [min(ub[0], xs.min()), min(ub[1], ys.min()), max(ub[2], xs.max()), max(ub[3], ys.max())]
CROP = (max(0, int(ub[0]) - 10), max(0, int(ub[1]) - 10), min(W, int(ub[2]) + 11), min(H, max(int(ub[3]), PIV[1]) + 11))
gw, gh = CROP[2] - CROP[0], CROP[3] - CROP[1]
frames = []
for f in range(NF):
    canvas = Image.new('RGB', (gw * 2 + 6, gh * 2 + 18 + 4), (236, 234, 228))
    d = ImageDraw.Draw(canvas); d.fontmode = '1'
    for c, F in enumerate('SE'):
        for r, pas in enumerate(('clay', 'sides')):
            g = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            if pas == 'clay':
                g.alpha_composite(GL)
            g.alpha_composite(Image.open('%s/%s/walk_%s_f%02d.png' % (RND, pas, F, f)))
            dd = ImageDraw.Draw(g); dd.line([(0, PIV[1]), (W, PIV[1])], fill=(220, 30, 30, 255))
            g = g.crop(CROP)
            canvas.paste(g, (c * (gw + 6), 18 + r * (gh + 4)), g)
        d.text((c * (gw + 6) + 6, 3), 'walk %s  f%02d   (%s)  1:1 cell px' % (F, f, '3/4 front' if F == 'S' else '3/4 back'), fill=(0, 0, 0), font=FONT)
    frames.append(canvas)
pal = frames[0].quantize(colors=48, method=Image.Quantize.MEDIANCUT)
q = [fr.quantize(palette=pal, dither=Image.Dither.NONE) for fr in frames]
dur = [60, 60, 50, 60, 60, 60, 60, 60, 50, 60, 60, 60]       # 700 ms per 12 frames = 17.14 fps
gif = PICS + '/ironjaw_walk_underlay.gif'
q[0].save(gif, save_all=True, append_images=q[1:], duration=dur, loop=0, optimize=True, disposal=1)

# ------------------------------------------------------------------ contact sheet JPG
def bbox(a):
    ys, xs = np.nonzero(a[:, :, 3] > 0); return xs.min(), ys.min(), xs.max(), ys.max()


def fig_h(path):
    a = np.array(Image.open(path).convert('RGBA')); x0, y0, x1, y1 = bbox(a); return y1 - y0 + 1, a


sheet_rows = []
LUCA_REF = BASE + '/ref/luca_hold_reference.png'      # Luca's arm/axe-hold target picture (opaque; figure = rows 0..459)
for F, hd, v32 in (('S', '/v4_hd/idle/ironjaw_idle_S_f00.png', '/v3.2/idle/ironjaw_idle_S_f00.png'),
                   ('E', '/v4_hd/idle/ironjaw_idle_E_f00.png', '/v3.2/idle/ironjaw_idle_E_f00.png')):
    myh, _ = fig_h('%s/clay/idle_%s.png' % (RND, F))
    cells = []
    if F == 'S':
        im = Image.open(LUCA_REF).convert('RGBA').crop((0, 0, 440, 460)); s = myh / 460
        cells.append(('Luca hold ref (x%.2f)' % s, im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)))
    for label, path in (('HD idle ' + F, REF + hd), ('v3.2 idle ' + F, REF + v32)):
        h, a = fig_h(path); s = myh / h
        im = Image.fromarray(a); x0, y0, x1, y1 = bbox(a)
        im = im.crop((x0, y0, x1 + 1, y1 + 1)); im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        cells.append((label + ' (x%.2f)' % s, im))
    for label, pas, n in (('idle clay', 'clay', 'idle_' + F), ('idle sides', 'sides', 'idle_' + F),
                          ('walk f00 clay', 'clay', 'walk_%s_f00' % F), ('walk f00 sides', 'sides', 'walk_%s_f00' % F),
                          ('walk f04 clay', 'clay', 'walk_%s_f04' % F), ('walk f04 sides', 'sides', 'walk_%s_f04' % F)):
        a = load(pas, n); x0, y0, x1, y1 = bbox(a)
        cells.append((label, Image.fromarray(a).crop((x0, y0, x1 + 1, y1 + 1))))
    sheet_rows.append(cells)
pad = 10
rowh = [max(c[1].height for c in r) + 20 for r in sheet_rows]
sw = max(sum(c[1].width + pad for c in r) for r in sheet_rows) + pad
sheet = Image.new('RGB', (sw, sum(rowh) + 26), (238, 236, 230))
d = ImageDraw.Draw(sheet)
d.text((pad, 6), 'Ironjaw HD walk underlay (blockout, paint-over guide only). All figures scaled to the same helm-to-sole height as the render.',
       fill=(0, 0, 0), font=FONT)
y = 26
for r, hh in zip(sheet_rows, rowh):
    x = pad
    for label, im in r:
        sheet.paste(im, (x, y + 16 + (hh - 20 - im.height)), im)
        d.text((x, y + 2), label, fill=(0, 0, 0), font=FONT)
        x += im.width + pad
    y += hh
jpg = PICS + '/ironjaw_walk_underlay.jpg'
for qv in (88, 82, 76, 70, 60):
    sheet.save(jpg, quality=qv, optimize=True)
    if os.path.getsize(jpg) < 300 * 1024:
        break
qa['summary']['gif_bytes'] = os.path.getsize(gif); qa['summary']['jpg_bytes'] = os.path.getsize(jpg)
qa['summary']['jpg_quality'] = qv
json.dump(qa, open(BASE + '/qa.json', 'w'), indent=1)

# ------------------------------------------------------------------ manifest + checksums
def sha(p):
    h = hashlib.sha256(); h.update(open(p, 'rb').read()); return h.hexdigest()


files = sorted(glob.glob(RND + '/*/*.png')) + [BASE + '/camera.json', BASE + '/qa.json', BASE + '/ironjaw_blockout.blend'] + \
    sorted(glob.glob(BASE + '/src/*.py')) + [BASE + '/README.md'] * os.path.exists(BASE + '/README.md')
contacts = {F: {'R_near': 'walk_%s_f%02d' % (F, (0 - PH_OFF[F]) % NF), 'L_far': 'walk_%s_f%02d' % (F, (6 - PH_OFF[F]) % NF)} for F in 'SE'}
man = {
    'what': 'Ironjaw HD repaint walk underlay: 3D blockout reference renders. Paint-over guide only; never shipped, never imported into Godot.',
    'cell': [W, H], 'pivot': list(PIV), 'frames': NF, 'fps': FPS, 'loop': True,
    'facings_rendered': ['S', 'E'], 'facings_by_flip': {'W': 'flip of S', 'N': 'flip of E'},
    'phase': {'S': 'f00 = right(near) boot contact, f06 = left(far) contact (same as v3.2 S)',
              'E': 'f00 = 1 frame after the right(near) boot contact; contacts on f05 (left/far) and f11 (right/near), same phase as v3.2 walk E',
              'contacts': contacts, 'planted_frames_per_boot': 7, 'swing_frames_per_boot': 5},
    'travel': {k: qa['summary'][k] for k in ('travel_per_frame_cell_px', 'travel_per_frame_diag_cell_px', 'travel_per_cycle_diag_cell_px',
                                             'travel_per_cycle_diag_final_px', 'frames_per_cell', 'cells_per_cycle', 'tile_sec_at_17.144fps',
                                             'board_speed_px_per_s_at_17.144fps')},
    'draw_scale_assumed': DRAW,
    'body_ground_point_px': [XO, YO],
    'passes': {'clay': 'per-face flat grey, key light screen upper-left (camera-fixed)',
               'sides': 'flat: near(his right)=orange family, far(his left)=blue family, torso greys, cape dark red, right-hand axe green, left-hand axe magenta',
               'sil': 'flat black', 'grid': 'clay over the iso ground grid (64x32 board tile at draw 0.30, quarter-tile dashes) + height ruler'},
    'camera': {k: cam[k] for k in ('type', 'elevation_deg_below_horizontal', 'azimuth_deg', 'ortho_scale', 'blender_rotation_euler_xyz_deg', 'world_origin_pixel')},
    'previews': [gif, jpg],
    'files': [{'path': os.path.relpath(p, BASE), 'bytes': os.path.getsize(p), 'sha256': sha(p)} for p in files],
}
json.dump(man, open(BASE + '/manifest.json', 'w'), indent=1)
with open(BASE + '/SHA256SUMS', 'w') as fh:
    for p in files + [BASE + '/manifest.json', gif, jpg]:
        fh.write('%s  %s\n' % (sha(p), os.path.relpath(p, BASE) if p.startswith(BASE) else p))
print(json.dumps(qa['summary'], indent=1))
