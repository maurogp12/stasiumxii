"""Mender actions v1 - cut the approved targets (repaint 3250c2ba) into the painted parts the action rig needs, starting from
the LOCKED walk's own layers (mender/v1_claude/parts at the lock commit 08ea869b, read-only: back_F, front_F, leg_F,
legfar_F, rig_F.json). Everything is written as full 1280x720 target-px RGBA canvases to ../parts.

Pieces per facing F (S front, E back):
  back_F, front_F   the walk's body layers (legs already removed, S slit filled) minus both arms, the staff and the lantern.
                    Where those covered the robe, mantle or cloak, the hole is filled by copying REAL robe pixels from shifted
                    patches of the same painting (patch_fill; no smooth fill, no Telea). Over background they are just alpha.
  wbody_F           body skin weights: R head (hood + face, about the neck), G upper body (twist), B robe skirt (lag).
  uarm_R_F, fore_R_F   the staff arm: robe sleeve (shoulder -> elbow), forearm + fist (closed on the staff). The sleeve part
                    hidden under the mantle is grown from the sleeve's own painted section (handle_extend) so a moved arm
                    never shows a gap at the shoulder.
  drape_R_E         E only: the hanging bell of the right sleeve, hinged on the forearm (it hangs toward gravity).
  uarm_L_F, fore_L_F   the free arm: sleeve, bracer + open hand (S); sleeve and bell opening (E, the hand is inside it).
  staff_F           the crook staff, one rigid piece: shaft + crook, the part under the fist continued from its own wood.
  lantern_F         the caged green lantern with its chain (and the S vines), one rigid piece hung from the crook tip.
  mjoints_F.json    joints in target px.
usage: mcut_act.py [debug.png]"""
import os, sys, json, subprocess, numpy as np, cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from skimage.color import rgb2lab
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '../../../../../../..'))
LOOKS = os.path.abspath(os.path.join(HERE, '../../..'))
TGT = os.path.join(LOOKS, 'targets')
OUT = os.environ.get('MAPARTS', os.path.join(HERE, '..', 'parts'))
WALK_COMMIT = '08ea869b'          # "Lock Mender walk v1 (S/E/W/N) at d83d9bb" on claude/mender-legs
WALK_DIR = os.environ.get('MWALK', '/tmp/mender_walk_lock')
SH = (720, 1280)

def walk_parts():
    d = os.path.join(WALK_DIR, 'docs/pc/art_help/class_walk_looks/mender/v1_claude')
    if not os.path.exists(d + '/parts/rig_S.json'):
        os.makedirs(WALK_DIR, exist_ok=True)
        subprocess.run(f'git -C "{REPO}" archive {WALK_COMMIT} docs/pc/art_help/class_walk_looks/mender/v1_claude | tar -x -C "{WALK_DIR}"',
                       shell=True, check=True)
    return d

def poly(pts, sh=SH):
    im = Image.new('L', (sh[1], sh[0]), 0); ImageDraw.Draw(im).polygon([tuple(map(float, p)) for p in pts], fill=1); return np.asarray(im) > 0

def band(pts, w, sh=SH):
    im = Image.new('L', (sh[1], sh[0]), 0); ImageDraw.Draw(im).line([tuple(map(float, p)) for p in pts], fill=1, width=int(w), joint='curve')
    return np.asarray(im) > 0

def biggest(m):
    l, n = ndi.label(m, np.ones((3, 3)))
    if n == 0: return m
    s = np.bincount(l.ravel()); s[0] = 0; return l == s.argmax()

def clean(m, k=40):
    l, n = ndi.label(m, np.ones((3, 3))); s = np.bincount(l.ravel()); s[0] = 0; return np.isin(l, np.nonzero(s >= k)[0])

def rgba(path):
    a = np.asarray(Image.open(path).convert('RGBA')); return a[..., :3].copy(), a[..., 3] > 127

def save(name, rgb, m):
    out = np.zeros(SH + (4,), np.uint8); out[..., :3] = np.where(m[..., None], rgb, 0); out[..., 3] = m * 255
    Image.fromarray(out).save(f'{OUT}/{name}.png')

def patch_fill(rgb, hole, src_ok, offsets, feather=1.5):
    """fill `hole` by copying real painted pixels from shifted patches (the first offset whose source is valid wins); what is
    left takes the nearest valid painted pixel (a copy, not a blend); a 1.5 px feather only on the seam."""
    out = rgb.astype(np.float32).copy(); rem = hole.copy(); H, W = hole.shape
    yy, xx = np.indices(hole.shape)
    for dx, dy in offsets:
        sy, sx = np.clip(yy + dy, 0, H - 1), np.clip(xx + dx, 0, W - 1)
        ok = rem & src_ok[sy, sx] & (yy + dy >= 0) & (yy + dy < H) & (xx + dx >= 0) & (xx + dx < W)
        out[ok] = rgb[sy[ok], sx[ok]]; rem &= ~ok
        if not rem.any(): break
    if rem.any():
        _, (iy, ix) = ndi.distance_transform_edt(~(src_ok & ~hole), return_indices=True); out[rem] = rgb[iy[rem], ix[rem]]
    if feather:
        bl = cv2.GaussianBlur(out, (0, 0), feather); d = ndi.distance_transform_edt(hole)
        edge = hole & (d <= 2.0); out[edge] = 0.5 * out[edge] + 0.5 * bl[edge]
    return np.clip(out, 0, 255).astype(np.uint8)

def axis_extend(rgb, m, p0, p1, w, t_ref, t_ext):
    """continue a piece along the axis p0->p1 (half width w): every new row in t_ext is a copy of the painted cross-section
    in t_ref (tiled), so the grown part keeps the painted grain (sleeve folds, wood)."""
    p0 = np.array(p0, float); u = np.subtract(p1, p0); L = np.linalg.norm(u); u = u / L; n = np.array([-u[1], u[0]])
    yy, xx = np.indices(SH); t = (xx - p0[0]) * u[0] + (yy - p0[1]) * u[1]; o = (xx - p0[0]) * n[0] + (yy - p0[1]) * n[1]
    reg = (t >= t_ext[0]) & (t < t_ext[1]) & (np.abs(o) <= w) & ~m
    ref_t = t_ref[0] + np.mod(t[reg] - t_ext[0], t_ref[1] - t_ref[0])
    sx = p0[0] + ref_t * u[0] + o[reg] * n[0]; sy = p0[1] + ref_t * u[1] + o[reg] * n[1]
    src = cv2.remap(rgb.astype(np.float32), sx.astype(np.float32).reshape(-1, 1), sy.astype(np.float32).reshape(-1, 1), cv2.INTER_LINEAR)[:, 0]
    sm = cv2.remap(m.astype(np.float32), sx.astype(np.float32).reshape(-1, 1), sy.astype(np.float32).reshape(-1, 1), cv2.INTER_LINEAR)[:, 0] > 0.5
    out = rgb.copy(); mm = m.copy(); ys, xs = np.nonzero(reg)
    out[ys[sm], xs[sm]] = np.clip(src[sm], 0, 255).astype(np.uint8); mm[ys[sm], xs[sm]] = True
    return out, mm

# ------------------------------------------------------------------------------------------------ facing configs
CFG = {
 'S': dict(
   # staff: the gnarled shaft as a polyline band, the crook hook as a polygon; wood only (the robe behind it is not wood)
   # over the background (crook, shaft above the fist, below the hem) the piece is the band's alpha; over the robe (y 290-590)
   # it is the walk's narrow staff band (mcut.py, w 18)
   staff_line=[(497, 58), (494, 100), (491, 140), (494, 180), (499, 220), (505, 255), (512, 290), (520, 330), (530, 420),
               (540, 500), (548, 580), (556, 640), (565, 690)], staff_w=30,
   staff_robe=dict(y=(286, 596), pts=[(511, 280), (520, 330), (530, 420), (540, 500), (548, 580), (551, 600)], w=18),
   crook=[(424, 70), (427, 40), (450, 18), (486, 16), (507, 32), (514, 62), (510, 96), (490, 96), (480, 64), (470, 53), (459, 53),
          (454, 62), (455, 80), (451, 91), (438, 94)],
   lantern=[(436, 88), (458, 88), (462, 138), (482, 160), (496, 190), (496, 300), (474, 332), (456, 348), (432, 340), (400, 348),
            (376, 334), (374, 200), (398, 166), (434, 138)],
   hook=(447, 86), lantern_c=(447, 235),
   staff_grip=(507, 258), staff_top=(492, 60), staff_butt=(565, 688),
   # staff arm (screen left = his right): sleeve, then the brown under-sleeve and the fist on the staff
   R=dict(J=dict(shoulder=(608, 200), elbow=(560, 244), wrist=(530, 256), hand=(507, 258)),
          upper=[(552, 206), (566, 190), (598, 178), (622, 186), (632, 210), (622, 236), (596, 254), (566, 260), (550, 248)],
          fore=[(560, 220), (570, 240), (568, 262), (552, 280), (532, 284), (516, 292), (490, 288), (482, 262), (487, 237),
                (508, 230), (532, 226)],
          upper_r=24),
   # free arm (screen right): sleeve, bracer and open hand
   L=dict(J=dict(shoulder=(776, 216), elbow=(797, 280), wrist=(834, 330), hand=(842, 362)),
          upper=[(756, 236), (790, 228), (808, 256), (810, 284), (792, 296), (770, 290), (758, 266)],
          fore=[(786, 268), (806, 260), (830, 290), (850, 318), (862, 345), (862, 384), (842, 394), (822, 378), (814, 344),
                (798, 316), (786, 294)],
          upper_r=20),
   head=dict(c=(690, 100), r=(92, 80), feather=16), neck=(700, 172), belt_y=(300, 400), shoulder_y=205,
   fill=dict(Rarm=[(0, 45), (8, 60), (-10, 70), (15, 85), (0, 100), (25, 50)], staff=[(-30, 0), (30, 0), (-45, 5), (45, -5), (-60, 0), (60, 0)],
             Larm=[(-40, 0), (-55, 10), (-35, -15), (-70, 0), (-50, 25)]),
   close=41, clear=[(370, 0), (520, 0), (520, 232), (486, 232), (480, 350), (370, 350)],     # only staff / lantern / background here
 ),
 'E': dict(
   staff_line=[(838, 40), (836, 80), (831, 150), (823, 215), (812, 250), (797, 350), (783, 430), (772, 500), (762, 560),
               (755, 610), (748, 668)], staff_w=30,
   staff_robe=dict(y=(612, 700), pts=[(757, 600), (752, 640), (748, 668)], w=12),     # the planted boot's toe is beside it
   crook=[(822, 22), (836, 2), (864, -2), (888, 12), (890, 40), (880, 57), (864, 59), (862, 42), (866, 30), (858, 21), (849, 23),
          (845, 40), (846, 70), (826, 70)],
   lantern=[(858, 57), (880, 57), (882, 95), (900, 118), (904, 180), (890, 216), (866, 220), (844, 202), (836, 130), (854, 96)],
   hook=(868, 57), lantern_c=(868, 152),
   staff_grip=(821, 218), staff_top=(838, 30), staff_butt=(748, 666),
   R=dict(J=dict(shoulder=(712, 182), elbow=(752, 232), wrist=(796, 226), hand=(820, 218)),
          upper=[(688, 176), (726, 168), (748, 196), (766, 228), (758, 248), (735, 246), (712, 238), (696, 220)],
          fore=[(746, 214), (770, 206), (792, 202), (806, 194), (836, 194), (842, 214), (836, 240), (806, 246), (790, 252),
                (762, 252), (744, 240)],
          drape=[(708, 236), (744, 240), (768, 252), (792, 250), (804, 272), (800, 320), (782, 346), (766, 360), (752, 344),
                 (734, 304), (716, 270)],
          upper_r=24),
   L=dict(J=dict(shoulder=(582, 192), elbow=(548, 248), wrist=(515, 300), hand=(506, 312)),
          upper=[(548, 182), (602, 184), (608, 214), (594, 244), (566, 258), (538, 246), (542, 212)],
          fore=[(530, 232), (566, 252), (594, 244), (590, 278), (566, 306), (534, 324), (504, 322), (490, 304), (506, 276)],
          upper_r=24),
   head=dict(c=(664, 82), r=(70, 72), feather=14), neck=(664, 150), belt_y=(285, 385), shoulder_y=195,
   fill=dict(Rarm=[(-40, 0), (-55, 10), (-35, 20), (-70, 0), (-50, -10)], staff=[(-30, 0), (-45, 0), (-60, 5)],
             Larm=[(45, 0), (60, 10), (40, -10), (75, 0), (55, 20)]),
   close=41, clear=[(800, 0), (920, 0), (920, 230), (800, 190)],
   clear2=[(746, 560), (820, 560), (820, 720), (742, 720)],     # the staff foot beside the planted boot (the walk kept it on the body)
 )}

def cut(F, dbg):
    c = CFG[F]; wd = walk_parts()
    rgb_t = np.asarray(Image.open(f'{TGT}/mender_rp_{F}_f00.jpg').convert('RGB')).copy()
    al = np.asarray(Image.open(f'{TGT}/mender_rp_{F}_f00_alpha.png'))[..., 3] > 127
    back_rgb, back_m = rgba(f'{wd}/parts/back_{F}.png'); front_rgb, front_m = rgba(f'{wd}/parts/front_{F}.png')
    lab = rgb2lab(rgb_t); L_ = lab[..., 0]; yy, xx = np.indices(SH)
    # ---- staff: band (over the background the band is cut by the target alpha) + crook; over the robe the narrow band
    fists = poly(c['R']['fore'])
    lant_p = poly(c['lantern'])
    wood_band = band(c['staff_line'], c['staff_w']) & al & ~lant_p
    sr = c.get('staff_robe')
    if sr:
        rows = (yy >= sr['y'][0]) & (yy < sr['y'][1]); wood_band = (wood_band & ~rows) | (band(sr['pts'], sr['w']) & rows & al)
    staff = (wood_band | (poly(c['crook']) & al)) & ~fists
    staff = clean(ndi.binary_opening(staff, iterations=1), 150)
    # ---- lantern (+ chain, + S vines): everything of the target inside its polygon that is not the staff
    lant = lant_p & al & ~staff & ~poly(c['crook']); lant = clean(lant, 30)
    # ---- arms
    pieces = {}
    for sd in 'RL':
        a = c[sd]; up = poly(a['upper']) & al & ~staff & ~lant; fo = poly(a['fore']) & al & ~lant & ~up
        up = biggest(ndi.binary_opening(up, iterations=1)); fo = biggest(ndi.binary_opening(fo, iterations=1))
        pieces[sd] = dict(upper=up, fore=fo)
        if 'drape' in a:
            dr = poly(a['drape']) & al & ~staff & ~lant & ~up & ~fo; pieces[sd]['drape'] = biggest(ndi.binary_opening(dr, iterations=1))
    # the staff under the fist: continue the shaft from its painted wood just above the fist
    g = np.array(c['staff_grip'], float); tp = np.array(c['staff_top'], float); u = (g - tp) / np.linalg.norm(g - tp)
    srgb, sm = axis_extend(rgb_t, staff, tuple(g - u * 60), tuple(g), 8, (0, 30), (34, 92))
    staff2 = sm & (band(c['staff_line'], c['staff_w']) | poly(c['crook']))
    save(f'staff_{F}', srgb, staff2); save(f'lantern_{F}', rgb_t, lant)
    # arm pieces: the upper sleeve continued up its own axis under the mantle (for the shoulder joint)
    for sd in 'RL':
        a = c[sd]; J = a['J']; P = pieces[sd]
        sh = np.array(J['shoulder'], float); el = np.array(J['elbow'], float); L = np.linalg.norm(el - sh)
        urgb, um = axis_extend(rgb_t, P['upper'], tuple(sh), tuple(el), a['upper_r'] - 4, (L * 0.35, L * 0.75), (-14, L * 0.35))
        um = um & ~P['fore']
        save(f'uarm_{sd}_{F}', urgb, um); save(f'fore_{sd}_{F}', rgb_t, P['fore'])
        if 'drape' in P: save(f'drape_{sd}_{F}', rgb_t, P['drape'])
    # ---- body layers without the arms, staff and lantern; holes inside the robe filled with real robe paint
    out = {}
    removed_all = staff | lant
    for sd in 'RL':
        for m in pieces[sd].values(): removed_all |= m
    removed_all = ndi.binary_dilation(removed_all, iterations=1) | poly(c['clear'])
    if c.get('clear2'): removed_all |= poly(c['clear2'])
    for nm, (rgb_l, m_l) in (('back', (back_rgb, back_m)), ('front', (front_rgb, front_m))):
        body = m_l & ~removed_all
        body = clean(body, 60)
        k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (c['close'], c['close']))
        clo = cv2.morphologyEx(body.astype(np.uint8), cv2.MORPH_CLOSE, k).astype(bool) & ndi.binary_fill_holes(body | (m_l & removed_all))
        hole = m_l & removed_all & clo & ~body
        src_ok = ndi.binary_erosion(body & ~removed_all, iterations=2)
        rgbf = rgb_l.copy()
        for key, region in (('Rarm', sum_masks(pieces['R'])), ('Larm', sum_masks(pieces['L'])), ('staff', staff | lant)):
            h = hole & ndi.binary_dilation(region, iterations=2)
            if h.any(): rgbf = patch_fill(rgbf, h, src_ok, c['fill'][key])
        out[nm] = (rgbf, body | hole, hole)
    save(f'back_{F}', *out['back'][:2]); save(f'front_{F}', *out['front'][:2])
    # ---- body skin weights (target px): head about the neck, upper body (twist), robe skirt (lag)
    hd = c['head']; ex = ((xx - hd['c'][0]) / hd['r'][0]) ** 2 + ((yy - hd['c'][1]) / hd['r'][1]) ** 2
    dist = (np.sqrt(ex) - 1) * min(hd['r']); wh = np.clip(0.5 - dist / hd['feather'], 0, 1); wh = wh * wh * (3 - 2 * wh)
    ys, ye = c['shoulder_y'], c['belt_y'][0]; wu = np.clip((ye - yy) / (ye - ys), 0, 1); wu = wu * wu * (3 - 2 * wu)
    b0, b1 = c['belt_y']; wk = np.clip((yy - b0) / (b1 - b0), 0, 1); wk = wk * wk * (3 - 2 * wk)
    Image.fromarray(np.dstack([(wh * 255).astype(np.uint8), (wu * 255).astype(np.uint8), (wk * 255).astype(np.uint8)])).save(f'{OUT}/wbody_{F}.png')
    # ---- joints
    rig = json.load(open(f'{wd}/parts/rig_{F}.json'))
    J = dict(walk_rig=rig, arms={sd: {k: list(map(float, v)) for k, v in c[sd]['J'].items()} for sd in 'RL'},
             staff=dict(grip=list(c['staff_grip']), top=list(c['staff_top']), butt=list(c['staff_butt']), hook=list(c['hook'])),
             lantern=dict(hook=list(c['hook']), c=list(c['lantern_c'])), neck=list(c['neck']), head_c=list(c['head']['c']),
             belt_y=list(c['belt_y']), shoulder_y=c['shoulder_y'])
    json.dump(J, open(f'{OUT}/mjoints_{F}.json', 'w'), indent=1)
    if dbg is not None:
        o = np.full(SH + (3,), 200, np.uint8); bm = out['back'][1]; o[bm] = out['back'][0][bm]; fm = out['front'][1]; o[fm] = out['front'][0][fm]
        o2 = (o * 0.55).astype(np.uint8)
        cols = [(255, 80, 80), (255, 220, 0), (0, 220, 255), (0, 255, 0), (255, 0, 255), (255, 140, 0), (120, 120, 255)]
        ms = [staff2, lant, pieces['R']['upper'], pieces['R']['fore'], pieces['L']['upper'], pieces['L']['fore']] + ([pieces['R']['drape']] if 'drape' in pieces['R'] else [])
        for m, col in zip(ms, cols): o2[m] = (rgb_t[m] * 0.45 + np.array(col) * 0.55).astype(np.uint8)
        hl = out['back'][2] | out['front'][2]; o3 = o.copy(); o3[hl] = (o3[hl] * 0.6 + np.array([255, 0, 255]) * 0.4).astype(np.uint8)
        dbg[F] = np.hstack([rgb_t[:, 360:920], o2[:, 360:920], o[:, 360:920], o3[:, 360:920]])

def sum_masks(d):
    m = np.zeros(SH, bool)
    for v in d.values(): m |= v
    return m

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True); dbg = {} if len(sys.argv) > 1 else None
    for F in 'SE': cut(F, dbg)
    if dbg is not None: Image.fromarray(np.vstack([dbg['S'], dbg['E']])).save(sys.argv[1])
    print('ok')
