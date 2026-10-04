"""Bastion actions v1 - cut the approved targets (and, for the painted helm and S belt, the LOCKED walk f00 frame) into the
painted parts the action rig needs. Everything is written as full 1280x720 target-px RGBA canvases to ../parts.

The split follows the LOCKED walk (bastion/v3, build_hybrid.py + cut_target_layers*.py at 7f65035e) so idle f00 is the walk's
upper body:
  S  trunk / R pauldron / cape (+ cape_r) / shield / near arm are the walk's target polygons; the helm (3/4, facing down-right)
     and the belt + tassets + tabard are the walk's painted pieces, taken from walk_S_f00 and mapped back to target px by the
     walk's own trunk transform (s_up 0.4122, t (-32.8, 76.75)).
  E  cape / trunk / R pauldron / tassets (at the walk's 0.7 length) / shield / near arm are the walk's target cuts; the helm
     is the walk's painted back helm from walk_E_f00 (s_up 0.39399, t (-7.2, 69.75)).
Pieces (per facing F):
  body_F       everything rigid on the torso. Holes left by the arm, the mace and the shield are filled where the body
               closes around them, by copying real cloth / armour pixels from shifted patches of the same painting (no
               Telea), then a 2 px feather; over background they are just alpha.
  back_F       the part of body_F drawn further back: S the cape (behind the legs); E the trunk and tassets (behind
               the shield, the cape stays in front of it, as in the walk).
  wcape_F      cape skin weights (R upper panel, G lower panel), feathered.
  cover_F      the near pauldron, drawn again over the arm root (same transform as the body).
  uarm_R_F / fore_R_F / mace_F   the near (mace) arm as three rigid painted pieces: upper arm (grown under the couter
               so a bent elbow shows no gap), couter + vambrace + gauntlet fist (one piece, fist closed on the handle),
               and the mace (handle + head; the handle hidden under the fist is continued from its own painted section).
  uarm_L_F / fore_L_F            the shield arm: the near arm pieces mirrored and darkened (the target hides it).
  shield_F     the kite shield (target), strapped on the outside of the left forearm by the rig.
  leg pieces   thigh / kneecop / greave / sabaton, the walk v3 target-cut leg pieces (cut_target_legs.py polygons).
  bjoints_F.json  joints in target px.
usage: bcut.py [debug.png]"""
import os, sys, json, numpy as np, cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from skimage.color import rgb2lab
HERE = os.path.dirname(os.path.abspath(__file__))
LOOKS = os.path.abspath(os.path.join(HERE, '../../..'))
TGT = os.path.join(LOOKS, 'targets')
WALK = os.path.join(LOOKS, 'bastion/v3/frames')
OUT = os.environ.get('BAPARTS', os.path.join(HERE, '..', 'parts'))
WT = {'S': (0.4122, -32.8, 76.75), 'E': (0.39399, -7.2, 69.75)}      # walk f00 trunk map: cell = s * target + t
SH = (720, 1280)

def poly(pts, sh=SH, off=0):
    im = Image.new('L', (sh[1], sh[0]), 0); ImageDraw.Draw(im).polygon([(x + off, y) for x, y in pts], fill=1); return np.asarray(im) > 0

def band(pts, w, sh=SH):
    im = np.zeros(sh, np.uint8); cv2.polylines(im, [np.array(pts, np.int32).reshape(-1, 1, 2)], False, 1, int(2 * w)); return im > 0

def disk(c, r, sh=SH):
    yy, xx = np.indices(sh); return (xx - c[0]) ** 2 + (yy - c[1]) ** 2 <= r * r

def target(F):
    rgb = np.asarray(Image.open(f'{TGT}/bastion_rp_{F}_f00.jpg').convert('RGB')).copy()
    al = np.asarray(Image.open(f'{TGT}/bastion_rp_{F}_f00_alpha.png').convert('L')) > 127
    return rgb, al

def walk_back(F, cell_poly):
    """walk f00 pixels inside cell_poly, mapped back to target px (cubic), binary alpha."""
    s, tx, ty = WT[F]
    w = np.asarray(Image.open(f'{WALK}/bastion_walk_{F}_f00.png').convert('RGBA')).astype(np.float32)
    m = poly(cell_poly, (360, 512)) & (w[..., 3] > 127)
    a = m.astype(np.float32)
    pm = np.dstack([w[..., :3] * a[..., None], a])
    Minv = np.float32([[1 / s, 0, -tx / s], [0, 1 / s, -ty / s]])
    big = cv2.warpAffine(pm, Minv, (1280, 720), flags=cv2.INTER_CUBIC, borderValue=0)
    A = big[..., 3]; ok = A > 0.5
    rgb = np.clip(big[..., :3] / np.maximum(A[..., None], 1e-3), 0, 255).astype(np.uint8)
    return rgb, ok

def cloth_blue(lab): return (lab[..., 2] < -4) & (-lab[..., 2] > np.abs(lab[..., 1]) * 1.2)

def patch_fill(rgb, hole, src_ok, offsets, feather=2.0):
    """fill `hole` by copying real painted pixels from shifted patches (first offset whose source is valid wins), the
    remainder from the nearest valid pixel; a small feather blends the seam into the surrounding paint."""
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
        edge = hole & (d <= 2.5); out[edge] = 0.5 * out[edge] + 0.5 * bl[edge]
    return np.clip(out, 0, 255).astype(np.uint8)

def grow(rgb, m, region):
    """extend a piece's paint into `region` (nearest painted pixel of the piece) - for pieces hidden under a neighbour."""
    _, (iy, ix) = ndi.distance_transform_edt(~m, return_indices=True); out = rgb.copy(); g = region & ~m
    out[g] = rgb[iy[g], ix[g]]; return out, m | region

def capsule(a, b, r, sh=SH):
    yy, xx = np.indices(sh).astype(float); a = np.asarray(a, float); b = np.asarray(b, float); u = b - a; L = np.linalg.norm(u); u = u / L
    t = np.clip((xx - a[0]) * u[0] + (yy - a[1]) * u[1], 0, L); px, py = a[0] + t * u[0], a[1] + t * u[1]
    return (xx - px) ** 2 + (yy - py) ** 2 <= r * r

def upper_piece(rgb, arm, J, r, src_extra=None):
    """the upper arm as one sleeve, shoulder -> elbow: the painted visible part of it, grown (nearest painted pixel of
    the sleeve itself) over the part hidden under the pauldron and the couter."""
    cap = capsule(J['shoulder'], J['elbow'], r)
    vis = arm & cap & ndi.binary_dilation(arm & cap, iterations=0) if src_extra is None else (arm | src_extra) & cap
    vis = biggest(ndi.binary_opening(vis, iterations=2))
    # rows of the sleeve hidden under the pauldron: copies of the painted sleeve section just below them (tiled along the
    # bone), so the grown part keeps the scale-mail / plate texture instead of a smear
    a = np.asarray(J['shoulder'], float); b = np.asarray(J['elbow'], float); u = (b - a) / np.linalg.norm(b - a); n = np.array([-u[1], u[0]])
    yy, xx = np.indices(SH); t = (xx - a[0]) * u[0] + (yy - a[1]) * u[1]; o = (xx - a[0]) * n[0] + (yy - a[1]) * n[1]
    L = np.linalg.norm(b - a); cov = []
    for tt in np.arange(0, L, 2.0):
        sel = cap & (np.abs(t - tt) < 1.0); cov.append(vis[sel].mean() if sel.any() else 0)
    ok = [k for k, v in enumerate(cov) if v > 0.75]
    t0 = 2.0 * ok[0] if ok else L * 0.5
    span = max(10.0, min(28.0, L - t0 - 4))
    rgb2, m2 = handle_extend(rgb, vis, tuple(a), tuple(b), r - 1, (t0, t0 + span), (-r, t0))
    return grow(rgb2, m2, cap)

def biggest(m):
    l, n = ndi.label(m, np.ones((3, 3)))
    if n == 0: return m
    s = np.bincount(l.ravel()); s[0] = 0; return l == s.argmax()

def clean(m, k=40):
    l, n = ndi.label(m, np.ones((3, 3))); s = np.bincount(l.ravel()); s[0] = 0; return np.isin(l, np.nonzero(s >= k)[0])

def save(name, rgb, m):
    out = np.zeros(SH + (4,), np.uint8); out[..., :3] = np.where(m[..., None], rgb, 0); out[..., 3] = m * 255
    Image.fromarray(out).save(f'{OUT}/{name}.png')

def handle_extend(rgb, m, p0, p1, w, t_ref, t_ext):
    """continue a straight handle (axis p0->p1, half width w) from its painted section at axis length t_ref (a short
    range) back to t_ext (< 0 = beyond p0): every new row is a copy of the painted cross-section."""
    p0 = np.array(p0, float); u = np.subtract(p1, p0); L = np.linalg.norm(u); u = u / L; n = np.array([-u[1], u[0]])
    yy, xx = np.indices(SH); t = (xx - p0[0]) * u[0] + (yy - p0[1]) * u[1]; o = (xx - p0[0]) * n[0] + (yy - p0[1]) * n[1]
    reg = (t >= t_ext[0]) & (t < t_ext[1]) & (np.abs(o) <= w)
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
   walk_poly={   # LOCKED walk polygons (cut_target_layers.py)
    'trunk':   [(545, 0), (840, 0), (840, 198), (800, 205), (768, 212), (768, 302), (600, 302), (600, 205), (545, 205)],
    'R_pauld': [(536, 80), (642, 80), (642, 212), (600, 214), (536, 206)],
    'shield':  [(757, 214), (800, 203), (925, 185), (935, 330), (870, 470), (845, 470), (757, 360)],
    'cape':    [(230, 125), (560, 125), (600, 200), (606, 330), (595, 470), (565, 560), (230, 560)],
    'helm':    [(640, 0), (765, 0), (765, 88), (746, 96), (738, 128), (662, 128), (655, 96), (640, 88)],
    'cape_r':  [(768, 300), (818, 300), (822, 485), (768, 485)],
    'arm':     [(545, 195), (600, 205), (600, 300), (572, 332), (562, 398), (522, 412), (502, 470), (506, 525), (482, 610), (378, 610),
                (378, 488), (430, 468), (468, 428), (488, 380), (490, 300), (503, 240), (518, 200)]},
   helm_cell=[(230, 78), (280, 78), (280, 126), (270, 135), (242, 135), (230, 126)],
   belt_cell=[(227, 195), (284, 195), (283, 244), (270, 250), (256, 252), (242, 250), (229, 244)],
   # near (mace) arm, target px
   J=dict(shoulder=(578, 200), elbow=(530, 284), wrist=(519, 332), hand=(516, 360)),
   fore_poly=[(498, 246), (566, 238), (580, 300), (572, 336), (556, 392), (522, 398), (494, 392), (486, 330), (492, 280)],
   mace=dict(grip=(516, 362), head=(443, 541), axis=[(516, 362), (443, 541)], hw=9, head_r=82, ext=(0, 30), ext_ref=(36, 56),
             poly=[(470, 382), (532, 384), (524, 470), (520, 500), (522, 620), (356, 620), (356, 470), (452, 466), (478, 400)]),
   L_J=dict(shoulder=(792, 182), elbow=(806, 278), wrist=(820, 330), hand=(826, 356)),
   shield_c=(850, 315),
   pelvis=(702, 300), neck=(700, 135), crest=(692, 15),
   hips={'R': (650, 300), 'L': (754, 300)}, thigh_hip=(738, 300),
   legs={'thigh':   dict(poly=[(704, 330), (768, 330), (781, 446), (700, 446)], A=(738, 300), B=(741, 466)),
         'kneecop': dict(poly=[(703, 424), (745, 413), (787, 430), (790, 470), (771, 507), (745, 517), (713, 507), (702, 470)], C=(741, 466)),
         'greave':  dict(poly=[(697, 478), (769, 478), (769, 612), (697, 612)], A=(741, 466), B=(734, 612)),
         'sabaton': dict(poly=[(693, 579), (791, 579), (793, 689), (693, 689)], heel=(697.3, 654.1), toe=(765, 684))},
   cape_hinge=dict(upper=(565, 150), lower_y=(330, 430)),
   fill_off=[(-70, 0), (-90, -20), (-110, 10), (-60, 30), (-130, -10), (-50, -40), (-150, 20), (-40, 60), (-170, 0), (-30, 90)],
 ),
 'E': dict(
   X0=250,
   walk_poly={   # LOCKED walk polygons (cut_target_layers_E.py, crop x0 250)
    'R_pauld': [(372, 98), (440, 92), (500, 160), (500, 205), (432, 212), (378, 190)],
    'arm':     [(428, 168), (502, 160), (535, 232), (565, 288), (595, 335), (700, 425), (820, 430), (820, 570), (700, 570), (636, 474),
                (560, 405), (515, 395), (468, 352), (474, 318), (505, 318), (495, 268), (466, 228), (428, 214)],
    'shield':  [(80, 230), (195, 190), (200, 260), (185, 420), (130, 420), (80, 340)],
    'tasset':  [(398, 292), (472, 286), (490, 388), (408, 398)],
    'Rleg':    [(398, 386), (488, 380), (580, 470), (590, 720), (420, 720), (396, 470)],
    'helm':    [(320, 0), (415, 0), (415, 86), (406, 96), (400, 108), (332, 108), (328, 96), (320, 86)],
    'Lleg':    [(150, 540), (310, 540), (310, 720), (150, 720)]},
   helm_cell=[(214, 66), (256, 66), (256, 108), (249, 113), (250, 118), (220, 118), (214, 108)],
   tasset_k=0.7, tasset_pivot=(690, 292),
   J=dict(shoulder=(704, 176), elbow=(744, 264), wrist=(795, 343), hand=(812, 372)),
   fore_poly=[(712, 232), (764, 230), (800, 290), (846, 330), (850, 400), (806, 410), (782, 384), (742, 316), (716, 284)],
   fist_poly=[(786, 340), (842, 342), (850, 402), (806, 410), (780, 380)],
   mace=dict(grip=(812, 375), head=(1003, 497), axis=[(737, 330), (1003, 497)], hw=10, head_r=72, ext=None,
             poly=[(722, 312), (770, 318), (800, 345), (1080, 420), (1080, 580), (920, 580), (890, 480), (727, 360)]),
   L_J=dict(shoulder=(478, 180), elbow=(448, 268), wrist=(410, 330), hand=(398, 352)),
   shield_c=(392, 305),
   pelvis=(668, 305), neck=(616, 125), crest=(615, 6),
   hips={'R': (698, 305), 'L': (638, 305)}, thigh_hip=(698, 305),
   legs={'thigh':   dict(poly=[(650, 340), (750, 340), (754, 488), (660, 488)], A=(698, 345), B=(716, 472)),
         'kneecop': dict(poly=[(688, 428), (742, 400), (766, 410), (768, 500), (735, 506), (690, 500)], C=(716, 472)),
         'greave':  dict(poly=[(667, 462), (761, 462), (762, 580), (716, 596), (700, 606), (667, 606)], A=(716, 472), B=(728, 622)),
         'sabaton': dict(poly=[(699, 558), (815, 558), (815, 659), (699, 659)], heel=(731, 649), toe=(791, 622))},
   cape_hinge=dict(upper=(590, 125), lower_y=(330, 450)),
   fill_off=[(-40, 0), (40, 0), (-60, -20), (60, -20), (0, -50), (-80, 10), (80, 10), (0, 60), (-100, -30), (100, -30)],
 )}

def leg_parts(F, rgb, al, lab):
    c = CFG[F]; info = {}
    blue = (lab[..., 2] < -6) & (-lab[..., 2] > np.abs(lab[..., 1]) * 1.0); blue = ndi.binary_opening(blue, iterations=1)
    for nm, d in c['legs'].items():
        m = poly(d['poly']) & al & ~blue; m = ndi.binary_fill_holes(biggest(m))
        save(f'leg_{nm}_{F}', rgb, m); info[nm] = {k: list(map(float, v)) for k, v in d.items() if k != 'poly'}
    return info

def gold_lift(rgb, dl):
    """the walk's S gold-trim grade (build_hybrid.gold_lift: +4 L* on the cell) done here on the target pixels before the Lanczos
    downscale, where +6 L* gives the same gold value at the cell (bone dE 0.44 vs 3.07 unlifted); the walk pieces
    (helm, belt) already carry it."""
    lab = rgb2lab(rgb); g = (lab[..., 0] > 35) & (lab[..., 2] > 12) & ~((lab[..., 2] < -8) & (-lab[..., 2] > np.abs(lab[..., 1]) * 1.2))
    lab[..., 0][g] = np.clip(lab[..., 0][g] + dl, 0, 100)
    from skimage.color import lab2rgb
    out = rgb.copy(); out[g] = np.clip(lab2rgb(lab)[g] * 255 + .5, 0, 255).astype(np.uint8); return out

def cut_S(dbg):
    F = 'S'; c = CFG[F]; rgb, al = target(F); lab = rgb2lab(rgb); yy, xx = np.indices(SH)
    rgb = gold_lift(rgb, float(os.environ.get("BA_GOLD", "6.0")))
    M = {k: poly(v) & al for k, v in c['walk_poly'].items()}
    sh = M['shield']; rp = M['R_pauld'] & ~sh
    trunk = M['trunk'] & ~sh & ~rp & ~M['helm']
    arm = M['arm'] & ~trunk & ~rp
    cape0 = (M['cape'] | M['cape_r']) & ~trunk & ~rp & ~sh
    blue = cloth_blue(lab); blue_o = ndi.binary_opening(blue, iterations=1)
    # ---- the near arm: the walk's arm layer (blue slivers off, biggest piece, holes filled)
    arm_l = ndi.binary_opening(arm & ~sh & ~blue_o, iterations=1); arm_l = ndi.binary_fill_holes(biggest(arm_l)) & arm & ~sh
    mc = c['mace']; maceA = (band(mc['axis'], mc['hw']) | disk(mc['head'], mc['head_r'])) & poly(mc['poly']) & arm_l
    maceA = ndi.binary_opening(maceA, iterations=1); maceA = biggest(maceA)
    fore = biggest(ndi.binary_opening(poly(c['fore_poly']) & arm_l & ~maceA, iterations=2))
    upper = arm_l & ~fore & ~maceA & (yy < 330)
    # pieces with their own paint, grown under neighbours (upper under the couter, mace handle under the fist)
    J = c['J']
    urgb, um = upper_piece(rgb, arm_l & ~maceA & (yy > 196), J, 22)
    mrgb, mm = handle_extend(rgb, maceA, mc['axis'][0], mc['axis'][1], mc['hw'] - 1, mc['ext_ref'], (-12, mc['ext_ref'][0]))
    save('uarm_R_S', urgb, um); save('fore_R_S', rgb, fore); save('mace_S', mrgb, mm)
    # ---- shield
    save('shield_S', rgb, clean(sh))
    # ---- body: trunk + R pauldron + cape (+ fill where the arm / mace / shield covered it) + walk helm + walk belt
    armall = um | fore | maceA
    cape0 &= ~armall
    body = trunk | rp | cape0
    removed = (arm | sh | armall) & ~body
    clo = cv2.morphologyEx(body.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (101, 101))).astype(bool)
    hole = removed & clo & (yy < 470)
    src_cape = ndi.binary_erosion(cape0 & blue, iterations=2)
    src_body = ndi.binary_erosion(trunk, iterations=2)
    rgbf = rgb.copy()
    hc = hole & (xx < 640); hb = hole & (xx >= 640)
    rgbf = patch_fill(rgbf, hc, src_cape, c['fill_off'])
    rgbf = patch_fill(rgbf, hb, src_body, [(-60, 0), (-80, 10), (-50, -20), (-100, 0), (-70, 30)])
    body = body | hole
    capeM = (cape0 | hc) & ~trunk
    hrgb, hm = walk_back(F, c['helm_cell']); brgb, bm = walk_back(F, c['belt_cell'])
    rgbf[hm] = hrgb[hm]; rgbf[bm] = brgb[bm]; body = body | hm | bm; capeM &= ~(hm | bm)
    body = clean(body, 60)
    save('body_S', rgbf, body); save('back_S', rgbf, capeM & body); save('cover_S', rgb, clean(rp))
    walkpieces = hm | bm
    # ---- shield arm: the near arm mirrored about the body centre, darkened (hidden behind the shield in the target)
    mirror_arm(F, c, urgb, um, rgb, fore)
    cape_weights(F, c, capeM & body, body)
    legs = leg_parts(F, rgb, al, lab)
    write_joints(F, c, legs)
    if dbg is not None: debug(dbg, F, rgbf, body, capeM, [um, fore, mm, sh, walkpieces])

def mirror_arm(F, c, urgb, um, rgb, fore):
    J, LJ = c['J'], c['L_J']; x0 = (J['shoulder'][0] + LJ['shoulder'][0]) / 2.0
    Mm = np.float32([[-1, 0, 2 * x0], [0, 1, LJ['shoulder'][1] - J['shoulder'][1]]])
    for nm, im, m in (('uarm', urgb, um), ('fore', rgb, fore)):
        a = cv2.warpAffine(np.dstack([im, m.astype(np.uint8) * 255]), Mm, (1280, 720), flags=cv2.INTER_NEAREST)
        mm = a[..., 3] > 127; col = (a[..., :3].astype(np.float32) * 0.80).astype(np.uint8); save(f'{nm}_L_{F}', col, mm)
    c['L_mirror'] = dict(x0=x0, dy=float(LJ['shoulder'][1] - J['shoulder'][1]))

def cape_weights(F, c, capem, body):
    """cloth weights: full on the cloth and out past its ragged edge into the background (so the hem tatters move as one
    with the panel and never shear against the rigid torso weight), falling off only toward the armour it hangs from."""
    capem = cv2.morphologyEx(capem.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)).astype(bool)
    armour = ndi.binary_erosion(body & ~capem, iterations=6)
    grown = ndi.binary_dilation(capem, iterations=30) & ~armour
    wc = cv2.GaussianBlur(grown.astype(np.float32), (0, 0), 10)
    y0, y1 = c['cape_hinge']['lower_y']; yy = np.indices(SH)[0].astype(np.float32)
    t = np.clip((yy - y0) / (y1 - y0), 0, 1); t = t * t * (3 - 2 * t)
    wl = wc * t; wu = wc * (1 - t) * np.clip((yy - c['cape_hinge']['upper'][1]) / 60, 0, 1)
    Image.fromarray(np.dstack([(wu * 255).astype(np.uint8), (wl * 255).astype(np.uint8), np.zeros(SH, np.uint8)])).save(f'{OUT}/wcape_{F}.png')

def write_joints(F, c, legs):
    J = dict(arms={'R': {k: list(map(float, v)) for k, v in c['J'].items()}}, legs=legs)
    mx = c['L_mirror']; J['arms']['L'] = {k: [2 * mx['x0'] - v[0], v[1] + mx['dy']] for k, v in c['J'].items()}
    J['L_target'] = {k: list(map(float, v)) for k, v in c['L_J'].items()}
    mc = c['mace']; J['mace'] = dict(grip=list(map(float, mc['grip'])), head=list(map(float, mc['head'])))
    for k in ('shield_c', 'pelvis', 'neck', 'crest', 'thigh_hip'): J[k] = list(map(float, c[k]))
    J['hips'] = {k: list(map(float, v)) for k, v in c['hips'].items()}
    J['cape_upper'] = list(map(float, c['cape_hinge']['upper'])); J['cape_lower_y'] = list(c['cape_hinge']['lower_y'])
    J['walk_t'] = list(WT[F])
    json.dump(J, open(f'{OUT}/bjoints_{F}.json', 'w'), indent=1)

def cut_E(dbg):
    F = 'E'; c = CFG[F]; X0 = c['X0']; rgb, al = target(F); lab = rgb2lab(rgb); yy, xx = np.indices(SH)
    # cape, exactly as the walk (cut_target_layers_E.py)
    blue = (lab[..., 2] < -4) & (-lab[..., 2] > np.abs(lab[..., 1]) * 1.2) & al
    gold = (lab[..., 2] > 12) & (lab[..., 0] > 30) & al
    b2 = ndi.binary_opening(blue, iterations=2); cc = ndi.binary_fill_holes(ndi.binary_closing(biggest(b2), iterations=6)) & al
    near = ndi.binary_dilation(cc, iterations=10)
    cape = cc | (gold & near & (yy > 200)) | (ndi.binary_dilation(blue, iterations=1) & near & ~ndi.binary_opening(blue, iterations=2) & (yy > 200))
    cape = ndi.binary_fill_holes(ndi.binary_closing(cape, iterations=2)) & al
    dist = ndi.distance_transform_edt(~cape)
    lleg = poly([(160, 560), (300, 560), (300, 720), (160, 720)], off=X0)
    hem = al & (dist <= 75) & (yy > 430) & (xx < 652) & ~lleg
    clothy = ((lab[..., 2] < -2) & (-lab[..., 2] > np.abs(lab[..., 1]))) | gold
    c3 = ndi.binary_fill_holes(cape | hem) & al
    tips = ndi.binary_opening(lleg & al & clothy & (yy < 640), iterations=1)
    l2, _ = ndi.label(tips | c3); tips &= np.isin(l2, np.unique(l2[c3]))
    cape = ndi.binary_fill_holes(c3 | tips) & al
    cape &= ~((cape & ~ndi.binary_opening(cape, iterations=2)) & lleg)
    tooth = 560 - 12 * np.abs(((xx - X0 - 400) / 11.0) % 2 - 1) ** 1.5 - 3 * np.sin((xx - X0) * 0.37)
    cape &= ~((xx - X0 >= 410) & (xx - X0 <= 550) & (yy > tooth) & (yy <= 562))
    M = {k: poly(v, off=X0) & al for k, v in c['walk_poly'].items()}
    shield = M['shield'] & ~cape; rp = M['R_pauld'] & ~cape; arm = M['arm'] & ~cape & ~rp
    tas = M['tasset'] & ~cape & ~arm; legs = (M['Rleg'] | M['Lleg']) & ~cape & ~arm & ~tas
    trunk = al & ~cape & ~shield & ~rp & ~arm & ~tas & ~legs & ~M['helm']
    trunk = clean(trunk); shield = biggest(shield); rp = biggest(rp); arm = biggest(arm)
    # ---- near arm pieces
    mc = c['mace']; J = c['J']
    maceA = (band(mc['axis'], mc['hw']) | disk(mc['head'], mc['head_r'])) & poly(mc['poly']) & arm
    fist = poly(c['fist_poly']) & arm
    maceA = biggest(ndi.binary_opening(maceA & ~fist, iterations=1))
    blue_e = ndi.binary_opening(cloth_blue(lab), iterations=1)
    fore = biggest(ndi.binary_opening((poly(c['fore_poly']) & arm & ~maceA & ~blue_e) | fist, iterations=2))
    upper = arm & ~fore & ~maceA & (yy < 300)
    urgb, um = upper_piece(rgb, arm & ~maceA & ~fist, J, 25)
    # the handle under the fist: continue it from the painted handle beyond the fist (t 120..150 along the axis)
    mrgb, mm = handle_extend(rgb, maceA, mc['axis'][0], mc['axis'][1], mc['hw'] - 1, (128, 150), (60, 128))
    # the forearm where the handle band was cut out of it: own paint (nearest)
    frgb, fm = grow(rgb, fore, ndi.binary_fill_holes(fore) & ~fore)
    save('uarm_R_E', urgb, um); save('fore_R_E', frgb, fm); save('mace_E', mrgb, mm); save('shield_E', rgb, shield)
    # ---- tassets at the walk's 0.7 length (vertical scale about the belt pivot)
    k = c['tasset_k']; py = c['tasset_pivot'][1]
    Sy = np.float32([[1, 0, 0], [0, k, (1 - k) * py]])
    tw = cv2.warpAffine(np.dstack([rgb, tas.astype(np.uint8) * 255]), Sy, (1280, 720), flags=cv2.INTER_AREA)
    tasm = tw[..., 3] > 127
    # ---- body: everything rigid; holes where the arm / shield covered it are filled from the same painting
    body = trunk | rp | cape | tasm
    rgbf = rgb.copy(); rgbf[tasm] = tw[..., :3][tasm]
    removed = (arm | shield) & ~body
    clo = ndi.binary_closing(body, structure=np.ones((3, 3)), iterations=14)
    hole = removed & clo & (yy < 460)
    src = ndi.binary_erosion(trunk, iterations=2)
    rgbf = patch_fill(rgbf, hole & ~cape, src, c['fill_off'])
    body = body | hole
    hrgb, hm = walk_back(F, c['helm_cell']); rgbf[hm] = hrgb[hm]; body = body | hm
    body = clean(body, 60)
    back = body & ~cape & ~rp & ~hm
    save('body_E', rgbf, body); save('back_E', rgbf, back); save('cover_E', rgb, rp)
    mirror_arm(F, c, urgb, um, frgb, fm)
    cape_weights(F, c, cape & body, body)
    legs = leg_parts(F, rgb, al, lab)
    write_joints(F, c, legs)
    if dbg is not None: debug(dbg, F, rgbf, body, cape, [um, fm, mm, shield, hm])

def debug(dbg, F, rgbf, body, capem, pieces):
    o = np.full(SH + (3,), 200, np.uint8); o[body] = rgbf[body]
    o2 = (o * 0.6).astype(np.uint8); o2[capem] = (o2[capem] * 0.5 + np.array([0, 60, 160])).clip(0, 255).astype(np.uint8)
    cols = [(255, 80, 80), (255, 220, 0), (0, 220, 255), (0, 255, 0), (255, 0, 255)]
    for m, col in zip(pieces, cols): o2[m] = (o2[m] * 0.4 + np.array(col) * 0.6).astype(np.uint8)
    dbg[F] = np.hstack([o[:, 280:1080], o2[:, 280:1080]])

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True); dbg = {} if len(sys.argv) > 1 else None
    cut_S(dbg); cut_E(dbg)
    if dbg is not None: Image.fromarray(np.vstack([dbg['S'], dbg['E']])).save(sys.argv[1])
    print('ok')
