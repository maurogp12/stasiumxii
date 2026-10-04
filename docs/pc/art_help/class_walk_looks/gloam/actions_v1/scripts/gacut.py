"""Gloam actions v1 - cut the extra pieces the action rig needs from the approved targets (target px, 1280x720 canvases).

The walk's own layers (back_F, front_F, leg_F, legfar_F, rig_F.json from the LOCKED walk, see gwalk.py) are the base; this
script only takes the arms out of them and adds what moves on its own:
  uarm_{R,L}_F   upper sleeve, shoulder -> elbow (+ a 5 px overlap past the elbow). The root hidden under the hood cloak is
                 continued from the sleeve's own painted rows (reflected about the shoulder line), so a raised arm shows
                 no gap; it stays under cover_F.
  fore_{R,L}_F   bracer + fist + curved dagger as ONE piece (the fist closed on the grip), elbow -> fist -> blade tip.
                 S: both arms are painted (screen-left = blockout R, screen-right = blockout L). E: the target hides the left
                 arm under the cloak, so L is the painted right arm mirrored and 18 % darker.
  body_F         the walk's back_F minus both arms and daggers. Where an arm covered the body, the hole is filled with
                 the painting's own cloak / leather pixels copied from shifted patches beside the arm (no smooth fill, no
                 Telea), with a 2 px feather; where the arm hung over background the hole stays background.
  front_F        the walk's front_F minus the arms (S: belt and tunic flaps; E: the whole coat and cloak).
  cover_F        the hood-cloak over each shoulder root (the body's own purple pixels), drawn again over the arm root.
  wcape_F        skin weights: R = upper cloak panel, G = lower cloak panel, B = head (the hood with the face and eyes, for
                 the hit head snap); the rest is the rigid torso. Feathered, so there is no cut anywhere.
  gjoints_F.json arm joints, dagger grip / tip, shoulders, cloak hinges, head pivot, in target px.
usage: gacut.py [debug.png]"""
import os, sys, json, numpy as np, cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from skimage.color import rgb2lab
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import gwalk
LOOKS = os.path.abspath(os.path.join(HERE, '../../..'))
TGT = os.path.join(LOOKS, 'targets')
OUT = os.environ.get('GAPARTS', os.path.join(HERE, '..', 'parts'))
SH = (720, 1280)

CFG = {
 'S': dict(
   arms={
     # screen-left arm (blockout R): sleeve, bracer, fist and the reverse-held dagger over the cloak
     'R': dict(poly=[(513, 193), (527, 183), (540, 177), (553, 183), (560, 200), (553, 217), (540, 233), (527, 250), (522, 270),
                     (513, 290), (500, 307), (490, 323), (487, 343), (480, 363), (472, 380), (468, 388), (468, 403), (450, 417),
                     (443, 443), (427, 477), (397, 517), (353, 545), (370, 512), (395, 470), (414, 433), (421, 410), (423, 392),
                     (423, 363), (425, 350), (432, 337), (443, 313), (452, 290), (458, 260), (463, 247), (480, 230), (500, 207)],
              J=dict(shoulder=(546, 192), elbow=(489, 262), hand=(456, 368), grip=(446, 396), tip=(353, 543))),
     # screen-right arm (blockout L): straight out to the right, dagger edge down
     'L': dict(poly=[(754, 168), (800, 158), (1055, 405), (1055, 452), (895, 452), (790, 276), (756, 248)],
               J=dict(shoulder=(770, 196), elbow=(812, 238), hand=(880, 322), grip=(905, 333), tip=(1033, 427)))},
   painted='RL', cape_upper=(655, 150), cape_lower_y=(300, 390), neck=(700, 150), hood_c=(712, 92), hood_r=(52, 90)),
 'E': dict(
   arms={
     'R': dict(poly=[(672, 158), (700, 148), (770, 150), (985, 330), (985, 425), (760, 425), (727, 282), (712, 264), (698, 246),
                     (686, 226), (676, 200)],
               J=dict(shoulder=(684, 178), elbow=(733, 236), hand=(800, 328), grip=(833, 353), tip=(948, 385)))},
   painted='R', L_shoulder=(578, 152), cape_upper=(610, 120), cape_lower_y=(300, 390), neck=(640, 112), hood_c=(640, 58), hood_r=(46, 80)),
}

def poly(pts, sh=SH):
    im = Image.new('L', (sh[1], sh[0]), 0); ImageDraw.Draw(im).polygon([tuple(map(float, p)) for p in pts], fill=1); return np.asarray(im) > 0

def unit(v): v = np.asarray(v, float); return v / max(float(np.hypot(*v)), 1e-9)

def target(F):
    rgb = np.asarray(Image.open(f'{TGT}/gloam_rp_{F}_f00.jpg').convert('RGB'))
    a = Image.open(f'{TGT}/gloam_rp_{F}_f00_alpha.png'); a = np.asarray(a)[..., 3] if a.mode == 'RGBA' else np.asarray(a.convert('L'))
    return rgb, a > 127

def purple(lab): return (lab[..., 1] > 2.5) & (lab[..., 2] < -3.5)

def walk_layer(name):
    a = np.asarray(Image.open(f'{gwalk.PARTS}/{name}.png').convert('RGBA')); return a[..., :3].copy(), a[..., 3] > 127

def save(name, rgb, m):
    rgb = rgb.copy(); rgb[~m] = 0
    Image.fromarray(np.dstack([rgb, m.astype(np.uint8) * 255])).save(f'{OUT}/{name}.png')

def patch_fill(rgb, hole, src_ok, offsets, feather=2.0):
    """fill `hole` by copying real painted pixels from shifted patches (the first offset whose source is valid wins), the
    rest from the nearest valid pixel; a 2 px feather blends the seam (same as Bastion's bcut.patch_fill)."""
    out = rgb.astype(np.float32).copy(); rem = hole.copy(); H, W = hole.shape; yy, xx = np.indices(hole.shape)
    def src(dx, dy):
        sy, sx = yy + dy, xx + dx; inb = (sy >= 0) & (sy < H) & (sx >= 0) & (sx < W)
        sy, sx = np.clip(sy, 0, H - 1), np.clip(sx, 0, W - 1); return inb & src_ok[sy, sx], sy, sx
    # greedy: the offset that fills the most of what is left goes first, so the fill comes in a few large coherent
    # patches of real cloth instead of thin interleaved strips
    left = list(offsets)
    while rem.any() and left:
        cov = [int((rem & src(dx, dy)[0]).sum()) for dx, dy in left]; k = int(np.argmax(cov))
        if cov[k] == 0: break
        dx, dy = left.pop(k); okm, sy, sx = src(dx, dy); ok = rem & okm
        out[ok] = rgb[sy[ok], sx[ok]]; rem &= ~ok
    if rem.any():
        _, (iy, ix) = ndi.distance_transform_edt(~src_ok, return_indices=True); out[rem] = rgb[iy[rem], ix[rem]]
    if feather:
        bl = cv2.GaussianBlur(out, (0, 0), feather); d = ndi.distance_transform_edt(hole); e = hole & (d <= 2.5)
        out[e] = 0.5 * out[e] + 0.5 * bl[e]
    return np.clip(out, 0, 255).astype(np.uint8)

def biggest(m, keep=0.04):
    """the main connected piece (plus any piece at least `keep` of its size)."""
    n, lab, st, _ = cv2.connectedComponentsWithStats(m.astype(np.uint8), 8)
    if n <= 2: return m
    a = st[1:, cv2.CC_STAT_AREA]; ok = np.zeros(n, bool); ok[1:] = a >= a.max() * keep; return ok[lab]

def split_arm(m, J):
    """upper sleeve / forearm piece split by the line through the elbow, normal = the mean of the two bone directions."""
    sh_, el, hd = (np.array(J[k], float) for k in ('shoulder', 'elbow', 'hand'))
    nrm = unit(unit(el - sh_) + unit(hd - el)); yy, xx = np.indices(SH)
    d = (xx - el[0]) * nrm[0] + (yy - el[1]) * nrm[1]
    return m & (d <= 5), m & (d > 0)

def grow_root(rgb, um, J, length=26):
    """continue the sleeve past the shoulder (hidden under the hood cloak in the painting) by reflecting its own rows about
    the shoulder line, inside a capsule of the sleeve's width."""
    sh_, el = np.array(J['shoulder'], float), np.array(J['elbow'], float); u = unit(el - sh_); n = np.array([-u[1], u[0]])
    yy, xx = np.indices(SH); P = np.stack([xx - sh_[0], yy - sh_[1]], -1).astype(float)
    t = P @ u; o = P @ n
    sel = um & (t > 0) & (t < 30); w = np.percentile(np.abs(o[sel]), 90) if sel.any() else 18.0
    reg = (t < 0) & (t > -length) & (np.abs(o) <= w) & ~um
    sx = np.clip(np.round(sh_[0] + u[0] * (-t) + n[0] * o).astype(int), 0, SH[1] - 1)
    sy = np.clip(np.round(sh_[1] + u[1] * (-t) + n[1] * o).astype(int), 0, SH[0] - 1)
    ok = reg & um[sy, sx]; out = rgb.copy(); out[ok] = rgb[sy[ok], sx[ok]]
    # under-cloak shading: the grown root darkens toward its end
    k = np.clip(1 + t / length, 0.55, 1.0)[..., None]; out[ok] = (out[ok].astype(np.float32) * k[ok]).astype(np.uint8)
    return out, um | ok

def cut(F, dbg=None):
    c = CFG[F]; rgb, al = target(F); lab = rgb2lab(rgb); pur = purple(lab)
    brgb, ba = walk_layer(f'back_{F}'); frgb, fa = walk_layer(f'front_{F}')
    os.makedirs(OUT, exist_ok=True); J = {'arms': {}}
    arm_all = np.zeros(SH, bool)
    for sd in c['painted']:
        A = c['arms'][sd]; m = poly(A['poly']) & al
        # the purple cloak that lies over the arm in the painting stays on the body (it is the cover)
        m &= ~(pur & (np.hypot(*(np.indices(SH)[::-1] - np.array(A['J']['shoulder'], float)[:, None, None])) < 70))
        arm_all |= poly(A['poly']) & al
        um, fm = split_arm(m, A['J'])
        um, fm = biggest(um), biggest(fm)          # no loose specks of cloth fly with a raised arm
        urgb, um = grow_root(rgb, um, A['J'])
        save(f'uarm_{sd}_{F}', urgb, um); save(f'fore_{sd}_{F}', rgb, fm)
        J['arms'][sd] = {k: list(map(float, v)) for k, v in A['J'].items()}
    if F == 'E':      # the left arm is hidden under the cloak: the painted right arm mirrored, 18 % darker
        JR = c['arms']['R']['J']; x0 = (JR['shoulder'][0] + c['L_shoulder'][0]) / 2.0; dy = c['L_shoulder'][1] - JR['shoulder'][1]
        Mm = np.float32([[-1, 0, 2 * x0], [0, 1, dy]])
        for nm in ('uarm', 'fore'):
            a = np.asarray(Image.open(f'{OUT}/{nm}_R_{F}.png')); w = cv2.warpAffine(a, Mm, (1280, 720), flags=cv2.INTER_NEAREST)
            mm = w[..., 3] > 127; save(f'{nm}_L_{F}', (w[..., :3].astype(np.float32) * 0.82).astype(np.uint8), mm)
        J['arms']['L'] = {k: [2 * x0 - v[0], v[1] + dy] for k, v in JR.items()}
        J['L_mirror'] = dict(x0=x0, dy=dy)
    # ---- body: the walk's back layer minus the arms; holes behind an arm get the painting's own cloak / leather
    rem = arm_all & ba
    keep = ba & ~rem
    # which removed pixels had body behind them: inside the closing of what is left (a hole between cloak and torso), not
    # the parts of the arm that stuck out over background
    closed = cv2.morphologyEx(keep.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (91, 91))).astype(bool)
    closed = ndi.binary_fill_holes(closed) & ndi.binary_fill_holes(keep | rem)
    hole = rem & closed
    offs = []
    for sd in c['painted']:
        Jd = c['arms'][sd]['J']; u = unit(np.subtract(Jd['hand'], Jd['shoulder'])); n = np.array([-u[1], u[0]])
        for r in (30, 45, 60, 75, 90, 110):
            for sg in (1, -1): offs.append(tuple(np.round(n * r * sg + u * (r * 0.3)).astype(int)))
    src_ok = keep & ~ndi.binary_dilation(rem, iterations=3)
    # the arm hangs over the cloak: copy cloth only (loose purple, which takes in the cloak's dark folds), never the leather
    # torso beside it, so no ghost of a sleeve appears in the hole
    blab = rgb2lab(brgb); src_ok &= (blab[..., 1] > 1.0) & (blab[..., 2] < -1.0)
    body_rgb = patch_fill(brgb, hole, src_ok, offs)
    bodya = keep | hole
    n_, lab_, st_, _ = cv2.connectedComponentsWithStats(bodya.astype(np.uint8), 8)       # slivers left beside a removed arm
    for k in range(1, n_):
        if st_[k, cv2.CC_STAT_AREA] < 1500: bodya[lab_ == k] = False
    save(f'body_{F}', body_rgb, bodya)
    fronta = fa & bodya & ~(rem & ~hole)
    frgb2 = frgb.copy(); frgb2[hole] = body_rgb[hole]
    save(f'front_{F}', frgb2, fronta)
    # ---- shoulder covers: the hood-cloak's own purple pixels around each shoulder root (drawn again over the arm root)
    yy, xx = np.indices(SH); cov = np.zeros(SH, bool)
    for sd, Jd in J['arms'].items():
        s0 = np.array(Jd['shoulder']); r = np.hypot(xx - s0[0], yy - s0[1])
        cov |= (r < 46) & (yy < s0[1] + 18)
    covm = cov & bodya & purple(rgb2lab(body_rgb))
    covm = ndi.binary_opening(covm, iterations=1)
    save(f'cover_{F}', body_rgb, covm)
    # ---- skin weights: R upper cloak, G lower cloak, B head
    capem = bodya & purple(rgb2lab(body_rgb))
    capem = cv2.morphologyEx(capem.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)).astype(bool)
    core = ndi.binary_erosion(bodya & ~capem, iterations=6)
    grown = ndi.binary_dilation(capem, iterations=30) & ~core
    wc = cv2.GaussianBlur(grown.astype(np.float32), (0, 0), 10)
    y0, y1 = c['cape_lower_y']; t = np.clip((yy - y0) / (y1 - y0), 0, 1).astype(np.float32); t = t * t * (3 - 2 * t)
    wl = wc * t; wu = wc * (1 - t) * np.clip((yy - c['cape_upper'][1]) / 60.0, 0, 1)
    hc = np.array(c['hood_c'], float); r0, r1 = c['hood_r']; d = np.hypot(xx - hc[0], (yy - hc[1]) * 0.85)
    wh = np.clip((r1 - d) / (r1 - r0), 0, 1); wh = (wh * wh * (3 - 2 * wh)) * (yy < c['neck'][1] + 10)
    wh = cv2.GaussianBlur(wh.astype(np.float32), (0, 0), 4)
    wu = wu * (1 - wh); wl = wl * (1 - wh)
    Image.fromarray(np.dstack([(wu * 255).astype(np.uint8), (wl * 255).astype(np.uint8), (wh * 255).astype(np.uint8)])).save(f'{OUT}/wcape_{F}.png')
    for k in ('cape_upper', 'cape_lower_y', 'neck', 'hood_c'): J[k] = list(map(float, c[k]))
    json.dump(J, open(f'{OUT}/gjoints_{F}.json', 'w'), indent=1)
    if dbg is not None:
        o = np.full(SH + (3,), 200, np.uint8); o[bodya] = body_rgb[bodya]
        o[hole] = (o[hole] * 0.7 + np.array([0, 255, 0]) * 0.3).astype(np.uint8)
        for sd in J['arms']:
            for nm in ('uarm', 'fore'):
                a = np.asarray(Image.open(f'{OUT}/{nm}_{sd}_{F}.png')); m = a[..., 3] > 0
                o2 = o.copy(); o2[m] = a[m, :3]; o = o2
            for k, v in J['arms'][sd].items(): cv2.circle(o, tuple(int(x) for x in v), 4, (255, 0, 255), -1)
        dbg[F] = o
    return J

if __name__ == '__main__':
    dbg = {}
    for F in 'SE': cut(F, dbg)
    if len(sys.argv) > 1:
        Image.fromarray(np.vstack([dbg['S'][0:720, 300:1100], dbg['E'][0:720, 300:1100]])).save(sys.argv[1])
