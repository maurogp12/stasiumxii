"""Kestrel v3 (Claude) - cut the approved targets into the layers the leg rig needs (all in target px, 1280x720).

Layers per facing F (written to PARTS, default ../parts):
  leg_F.png        ONE continuous painted leg, hip -> knee -> laced boot -> sole, from the target's fully visible leg
                   (S: screen-right forward leg, E: screen-left near leg). The thigh top that the tunic hides in the painting is
                   grown upward from the leg's own legging pixels (it stays under the belt / hem layer in every frame).
                   Cloak green and the bow that cross the leg are painted out from the leg's own browns.
  legfar_F.png     the same leg for the far side: S has the thigh strap / buckle painted out (one strap per figure).
  back_F.png       the body behind the legs: target minus both legs; the area the legs covered is filled with the target's own
                   under-tunic / cape-interior colours down to a ragged crotch line (no grey boxes, no holes between the legs).
  front_F.png      what hangs in front of the legs: S belt, pouches, tunic hem flaps, bow limb + string;
                   E everything of the body (the cape and the bow hang in front of the legs when seen from behind).
  rig_F.json       source-leg joints H (hip), K (knee), A (ankle), heel, toe (sole points) + hip centre / belt in target px.
usage: kcut.py [debug.png]"""
import os, sys, json, numpy as np, cv2
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '../../../../../../..'))
TGT = os.path.join(REPO, 'docs/pc/art_help/class_walk_looks/targets/')
PARTS = os.environ.get('K3PARTS', os.path.join(HERE, '..', 'parts'))

CFG = {
 'S': dict(
   # the forward (screen-right) leg, fully visible hip -> sole
   leg=[(584, 286), (652, 286), (658, 345), (662, 400), (668, 450), (672, 505), (692, 518), (690, 560), (692, 600), (702, 628),
        (708, 646), (730, 653), (742, 668), (740, 682), (724, 690), (698, 699), (662, 699), (658, 670), (653, 640), (634, 598),
        (622, 532), (614, 512), (601, 450), (590, 390)],
   vis_top=[(584, 336), (620, 344), (662, 350)],          # thigh visible below this line; above it is grown from the leg itself
   H=(619, 318), K=(650, 515), A=(681, 646), heel=(664, 696), toe=(738, 678),
   strap=[dict(pts=[(586, 398), (618, 386), (656, 376)], w=17), dict(pts=[(593, 384), (597, 418)], w=14)],
   # region of both legs below the tunic (removed from the body), minus cloak green and the bow
   legs_zone=[(536, 330), (664, 330), (700, 470), (700, 520), (750, 650), (750, 710), (515, 710), (515, 600), (536, 520)],
   bow=[dict(pts=[(395, 190), (628, 505)], w=5),
        dict(pts=[(470, 390), (500, 425), (540, 452), (580, 474), (612, 494), (632, 509)], w=12)],
   # body pixels above this polyline (and inside x range) hang IN FRONT of the legs
   front_x=(515, 735), front_line=[(515, 470), (582, 470), (590, 362), (668, 362), (676, 560), (735, 560)],
   keep_line=[(515, 350), (562, 352), (578, 340), (590, 340), (598, 345), (662, 348), (672, 340), (680, 356), (735, 358)],   # target pixels above this stay with the body
   fill_line=[(515, 520), (560, 470), (600, 405), (630, 392), (660, 405), (700, 470), (735, 520)],   # back fill down to here
   hips=dict(near=(619, 318), far=(574, 322)), far_ankle=(562, 612),
   belt=((541, 282), (709, 272)), shoulder=((538, 165), (722, 150))),
 'E': dict(
   # the near (screen-left) leg, seen from behind: thigh + laced boot
   leg=[(600, 380), (660, 380), (656, 440), (654, 480), (655, 520), (645, 548), (636, 600), (628, 640), (626, 668), (624, 694),
        (590, 698), (558, 697), (532, 670), (533, 640), (557, 600), (566, 546), (572, 510), (584, 500), (598, 480), (608, 455), (606, 430)],
   vis_top=[(596, 432), (630, 430), (656, 436)],
   H=(630, 392), K=(606, 520), A=(572, 640), heel=(540, 676), toe=(622, 692),
   strap=[],
   legs_zone=[(588, 405), (704, 405), (706, 500), (746, 590), (746, 662), (700, 662), (640, 705), (522, 705), (522, 640), (556, 560), (576, 470)],
   bow=[dict(pts=[(818, 140), (703, 558)], w=5),
        dict(pts=[(786, 375), (782, 420), (772, 455), (755, 490), (735, 520), (715, 550), (702, 575), (698, 600)], w=10)],
   bow_light=(545, 36),   # below y=545 the bow tip crosses the far boot: keep only the lighter bow wood (L* > 36) there
   front_x=(0, 1280), front_line=[(0, 2000), (1280, 2000)],          # E: the whole body is in front of the legs
   keep_line=[(0, 440), (1280, 440)],
   # the approved E alpha drops pieces of the upper bow limb and string: re-add bow-coloured pixels inside these bands
   alpha_fix=[dict(pts=[(818, 115), (826, 170), (828, 225), (822, 275), (812, 320), (800, 365)], w=18, d=22),
              dict(pts=[(818, 140), (703, 558)], w=4, d=14)],
   fill_line=[(0, 452), (1280, 452)], fill_rag=10,
   hips=dict(near=(630, 392), far=(676, 386)), far_ankle=(700, 596),
   belt=((600, 330), (700, 322)), shoulder=((560, 170), (698, 175))),
}

def target(F):
    rgb = np.asarray(Image.open(f'{TGT}kestrel_rp_{F}_f00.jpg').convert('RGB'))
    a = Image.open(f'{TGT}kestrel_rp_{F}_f00_alpha.png')
    a = np.asarray(a)[..., 3] if a.mode == 'RGBA' else np.asarray(a.convert('L'))
    return rgb, a > 127

def poly(pts, sh):
    im = Image.new('L', (sh[1], sh[0]), 0); ImageDraw.Draw(im).polygon([tuple(map(float, p)) for p in pts], fill=1)
    return np.asarray(im) > 0

def band(pts, w, sh):
    im = Image.new('L', (sh[1], sh[0]), 0); ImageDraw.Draw(im).line([tuple(map(float, p)) for p in pts], fill=1, width=int(w), joint='curve')
    return np.asarray(im) > 0

def below(line, sh):
    """mask of pixels below a polyline y(x) (linear interp, flat beyond the ends)."""
    xs, ys = zip(*line); yl = np.interp(np.arange(sh[1]), xs, ys)
    return np.indices(sh)[0] >= yl[None, :]

def green(rgb):
    from skimage.color import rgb2lab
    lab = rgb2lab(rgb); return (lab[..., 1] < -2) & (lab[..., 2] > 1.5)

def ragged(sh, amp, period, seed):
    """irregular tatter tips: triangles of random width (0.6..1.8 x period) and random depth (0.25..1 x amp)."""
    rng = np.random.default_rng(seed); out = np.zeros(sh[1]); x = 0
    while x < sh[1]:
        w = int(rng.uniform(0.6, 1.8) * period * 2) + 2; d = rng.uniform(0.25, 1.0) * amp
        t = np.abs(np.linspace(-1, 1, w)); out[x:x + w] = (d * (1 - t))[:max(0, min(w, sh[1] - x))]; x += w
    return out

def grow_leg(rgb, m, vis):
    """legging pixels of the leg outline above its visible top (hidden by the tunic in the painting) are grown from the leg
    itself: the visible thigh mirrored upward about its top line (keeps the painted grain), Telea fill where that runs out,
    fading to the under-tunic shadow colour 30 px above the line (no flat thigh tops)."""
    src = rgb.copy(); hole = (m & ~vis)
    src[~(m & vis)] = 0
    f = cv2.inpaint(src, (hole | ~m).astype(np.uint8) * 255, 9, cv2.INPAINT_TELEA)
    # keep the painted grain: mirror the visible thigh rows upward about the visible top line where possible
    ys, xs = np.nonzero(hole)
    vm = vis & m
    vt = np.argmax(vm, axis=0)                       # first visible row per column
    yr = np.clip(2 * vt[xs] - ys + 2, 0, rgb.shape[0] - 1)
    ok = vm[yr, xs]
    f = f.copy(); f[ys[ok], xs[ok]] = rgb[yr[ok], xs[ok]]
    f = cv2.medianBlur(f, 3)
    out = rgb.copy()
    # the grown part is in the shadow of the tunic: darken toward the top (0.55 at 40 px above the visible line)
    d = cv2.distanceTransform((~vis).astype(np.uint8), cv2.DIST_L2, 5)
    t = np.clip(d / 30.0, 0, 1)[..., None] ** 0.8          # 0 at the visible line -> 1 thirty px above it
    sh_ = f.astype(np.float32) * (1 - t) + np.array([24, 23, 16], np.float32) * t
    out[hole] = sh_[hole].astype(np.uint8)
    return out

def cut(F, dbg=None):
    c = CFG[F]; rgb, al = target(F); sh = al.shape
    if c.get('alpha_fix'):
        bg = np.median(rgb[~al], 0).astype(np.float32); dist = np.abs(rgb.astype(np.float32) - bg).max(-1)
        for b in c['alpha_fix']: al = al | (band(b['pts'], b['w'], sh) & (dist > b['d']))
    os.makedirs(PARTS, exist_ok=True)
    bow = np.zeros(sh, bool)
    for b in c['bow']: bow |= band(b['pts'], b['w'], sh)
    bow &= al
    if c.get('bow_light'):
        from skimage.color import rgb2lab
        y_, l_ = c['bow_light']; bow &= (np.indices(sh)[0] < y_) | (rgb2lab(rgb)[..., 0] > l_)
    gr = green(rgb)
    zone = poly(c['legs_zone'], sh) & below(c['keep_line'], sh)
    gz = (gr & zone).astype(np.uint8); gz = cv2.morphologyEx(gz, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    n_, lab_, st_, _ = cv2.connectedComponentsWithStats((gz | (gr & ~zone)).astype(np.uint8), 8)
    big = np.zeros(n_, bool); big[1:] = st_[1:, cv2.CC_STAT_AREA] >= 300
    gr = (gr & ~zone) | (gz.astype(bool) & big[lab_])
    # ---- the one source leg
    m = poly(c['leg'], sh) & (al | ~below([(0, c['vis_top'][-1][1]), (1280, c['vis_top'][-1][1])], sh))
    vis = below(c['vis_top'], sh) & al & ~gr & ~bow
    legrgb = grow_leg(rgb, m, vis)
    # cloak green / bow inside the visible leg: paint out from the leg's own browns
    bad = m & (gr | bow) & below(c['vis_top'], sh)
    if bad.any():
        src = legrgb.copy(); src[~m] = 0
        f = cv2.inpaint(src, (bad | ~m).astype(np.uint8) * 255, 7, cv2.INPAINT_TELEA); legrgb[bad] = f[bad]
    a = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 0.8)
    Image.fromarray(np.dstack([legrgb, (a * 255).astype(np.uint8)])).save(f'{PARTS}/leg_{F}.png')
    far = legrgb.copy()
    if c['strap']:
        sm = np.zeros(sh, bool)
        for b in c['strap']: sm |= band(b['pts'], b['w'], sh)
        sm &= m; src = far.copy(); src[~m] = 0
        f = cv2.inpaint(src, (sm | ~m).astype(np.uint8) * 255, 11, cv2.INPAINT_TELEA)
        # keep some grain: add the high-pass of the leather from 26 px below
        hp = far.astype(np.float32) - cv2.GaussianBlur(far.astype(np.float32), (0, 0), 3)
        hp = np.roll(hp, 30, axis=0)
        far[sm] = np.clip(f[sm].astype(np.float32) + 0.8 * hp[sm], 0, 255).astype(np.uint8)
    Image.fromarray(np.dstack([far, (a * 255).astype(np.uint8)])).save(f'{PARTS}/legfar_{F}.png')
    # ---- body without the legs
    rem = poly(c['legs_zone'], sh) & al & ~gr & ~bow & below(c['keep_line'], sh)
    body = al & ~rem
    # drop tiny islands of cloth left between the legs
    n, lab, st, _ = cv2.connectedComponentsWithStats(body.astype(np.uint8), 8)
    zone = poly(c['legs_zone'], sh)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] < 400 and (zone & (lab == i)).any() and not (bow & (lab == i)).any(): body[lab == i] = False
    rem = al & ~body
    # back fill: the removed area above a ragged crotch / hem line, coloured from the surrounding dark cloth
    fl = below(c['fill_line'], sh); rg = ragged(sh, c.get('fill_rag', 22), 6, 3)
    yy = np.indices(sh)[0]; xs, ys = zip(*c['fill_line']); yl = np.interp(np.arange(sh[1]), xs, ys) - rg
    fillm = rem & (yy < yl[None, :])
    src = rgb.copy(); src[~body] = 0
    known = body & ~cv2.dilate(rem.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    f = cv2.inpaint(src, (~known).astype(np.uint8) * 255, 11, cv2.INPAINT_TELEA)
    dark = np.array([24, 23, 16], np.float32)
    fillc = (f.astype(np.float32) * 0.25 + dark * 0.75)
    back = rgb.copy(); back[fillm] = fillc[fillm].astype(np.uint8)
    backa = body | fillm
    # shadow band: the painted non-cloth pixels just above the keep line (thigh tops under the tunic in the painting) fade into
    # the fill colour over 22 px, so the fill / leg tops never meet the body along a straight edge
    xs_k, ys_k = zip(*c['keep_line']); kl = np.interp(np.arange(sh[1]), xs_k, ys_k)
    dd = kl[None, :] - yy                                      # px above the keep line
    sb = poly(c['legs_zone'], sh) & body & ~gr & ~bow & (dd > 0) & (dd < 22)
    t = np.clip(1 - dd / 22.0, 0, 1)[..., None]
    shade = back.astype(np.float32) * (1 - t) + dark * t
    back[sb] = shade[sb].astype(np.uint8)
    frontm = body & ~below(c['front_line'], sh)
    xx = np.indices(sh)[1]; frontm &= (xx >= c['front_x'][0]) & (xx <= c['front_x'][1])
    frontm |= bow
    Image.fromarray(np.dstack([back, backa * 255]).astype(np.uint8)).save(f'{PARTS}/back_{F}.png')
    Image.fromarray(np.dstack([back, frontm * 255]).astype(np.uint8)).save(f'{PARTS}/front_{F}.png')
    rig = {k: list(c[k]) for k in ('H', 'K', 'A', 'heel', 'toe')}
    rig['hips'] = {k: list(v) for k, v in c['hips'].items()}
    for k in ('far_ankle', 'belt', 'shoulder'): rig[k] = c[k]
    ys_, xs_ = np.nonzero(al); rig['top'] = int(ys_.min()); rig['sole'] = int(ys_.max())
    json.dump(rig, open(f'{PARTS}/rig_{F}.json', 'w'), indent=1)
    if dbg is not None:
        o = (rgb * 0.35 + 90).astype(np.uint8); o[~al] = 200
        o[backa] = back[backa]; o[fillm] = (o[fillm] * 0.5 + np.array([0, 0, 255]) * 0.5).astype(np.uint8)
        o[frontm] = (o[frontm] * 0.6 + np.array([255, 255, 0]) * 0.4).astype(np.uint8)
        L = np.asarray(Image.open(f'{PARTS}/leg_{F}.png')).astype(np.float32)
        o2 = np.full_like(rgb, 200); aa = L[..., 3:] / 255; o2 = (L[..., :3] * aa + o2 * (1 - aa)).astype(np.uint8)
        for k in ('H', 'K', 'A', 'heel', 'toe'):
            cv2.circle(o2, tuple(int(v) for v in c[k]), 4, (255, 0, 255), -1)
        for k, v in c['hips'].items(): cv2.circle(o, tuple(int(t) for t in v), 4, (255, 0, 0), -1)
        Fr = np.asarray(Image.open(f'{PARTS}/legfar_{F}.png')).astype(np.float32); af = Fr[..., 3:] / 255
        o3 = (Fr[..., :3] * af + 200 * (1 - af)).astype(np.uint8)
        dbg[F] = np.hstack([o[230:720, 480:800], o2[230:720, 480:800], o3[230:720, 480:800]])
    return rig

if __name__ == '__main__':
    dbg = {}
    for F in 'SE': cut(F, dbg)
    if len(sys.argv) > 1: Image.fromarray(np.vstack([dbg['S'], dbg['E']])).save(sys.argv[1])
