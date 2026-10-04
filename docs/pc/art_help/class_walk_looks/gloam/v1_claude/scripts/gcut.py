"""Gloam v1 (Claude) - cut the approved targets into the layers the leg rig needs (all in target px, 1280x720).

Layers per facing F (written to PARTS, default ../parts):
  leg_F.png        ONE continuous painted leg, hip -> knee -> wrapped boot -> sole, from the target's fully visible leg
                   (S: screen-right forward leg = blockout L, E: screen-right forward leg seen from behind = blockout R). The thigh top that the tunic hides in the painting is
                   grown upward from the leg's own legging pixels (it stays under the belt / hem layer in every frame).
                   Purple cloak tatters that cross the leg are painted out from the leg's own black leather.
  legfar_F.png     the same leg for the other side (Gloam has no strap to remove, so it is the same painting; the rig darkens the far leg).
  back_F.png       the body behind the legs: target minus both legs; the area the legs covered is filled with the target's own
                   under-tunic / cape-interior colours down to a ragged crotch line (no grey boxes, no holes between the legs).
  front_F.png      what hangs in front of the legs: S belt and tunic flaps;
                   E everything of the body (the coat and cloak hang in front of the legs when seen from behind).
  rig_F.json       source-leg joints H (hip), K (knee), A (ankle), heel, toe (sole points) + hip centre / belt in target px.
usage: gcut.py [debug.png]"""
import os, sys, json, numpy as np, cv2
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '../../../../../../..'))
TGT = os.path.join(REPO, 'docs/pc/art_help/class_walk_looks/targets/')
PARTS = os.environ.get('G1PARTS', os.path.join(HERE, '..', 'parts'))

CFG = {
 'S': dict(
   # the forward (screen-right) leg, fully visible hip -> sole (blockout L)
   leg=[(598, 322), (668, 322), (682, 345), (692, 380), (702, 405), (714, 425), (722, 445), (728, 480), (735, 520), (738, 560),
        (744, 590), (760, 618), (790, 634), (814, 644), (822, 660), (804, 678), (762, 690), (726, 702), (710, 698), (703, 645),
        (697, 612), (688, 592), (674, 568), (660, 556), (653, 520), (654, 490), (657, 465), (648, 452), (625, 425), (604, 398), (600, 370)],
   vis_top=[(598, 362), (615, 352), (640, 347), (670, 351), (688, 362)],   # thigh visible below this line; above it is grown from the leg itself
   H=(648, 336), K=(690, 455), A=(733, 628), heel=(722, 692), toe=(814, 660), boot_top=488,
   strap=[],
   # region of both legs below the tunic (removed from the body), minus the purple cloak
   legs_zone=[(560, 340), (690, 340), (702, 400), (722, 440), (735, 520), (760, 605), (832, 640), (832, 708), (440, 708), (440, 560),
              (500, 500), (545, 440), (560, 400)],
   bow=[],
   # body pixels above this polyline (and inside x range) hang IN FRONT of the legs: belt, tunic flaps, cloak over the far hip
   front_x=(556, 760), front_line=[(556, 400), (585, 385), (598, 372), (610, 358), (640, 351), (690, 354), (700, 340), (760, 340)],
   keep_line=[(440, 520), (520, 470), (560, 420), (590, 365), (605, 352), (640, 347), (680, 350), (700, 360), (730, 420)],
   fill_line=[(440, 470), (540, 455), (585, 435), (612, 418), (632, 410), (650, 420), (672, 450), (720, 520)],   # back fill down to here
   fill_rag=2.0, dark=(19, 17, 20),
   hips=dict(near=(648, 336), far=(600, 342)), far_ankle=(505, 590),
   belt=((560, 284), (720, 302)), shoulder=((522, 188), (765, 192))),
 'E': dict(
   # the screen-right leg seen from behind (blockout R): trouser thigh + wrapped boot
   leg=[(625, 330), (700, 330), (710, 380), (722, 420), (731, 450), (738, 490), (745, 530), (748, 575), (768, 594), (798, 588),
        (818, 604), (812, 630), (782, 652), (745, 668), (722, 668), (716, 640), (706, 610), (692, 580), (680, 550), (675, 505),
        (672, 472), (652, 452), (636, 432), (622, 400)],
   vis_top=[(620, 392), (662, 388), (706, 394)],
   H=(668, 345), K=(706, 492), A=(738, 605), heel=(730, 660), toe=(810, 606), boot_top=500,
   strap=[],
   legs_zone=[(618, 384), (708, 384), (735, 450), (750, 570), (826, 592), (826, 682), (700, 682), (520, 702), (398, 702), (398, 600),
              (440, 520), (520, 470), (600, 450)],
   bow=[],
   front_x=(0, 1280), front_line=[(0, 2000), (1280, 2000)],          # E: the whole body (coat, cloak) is in front of the legs
   keep_line=[(398, 470), (600, 470), (618, 392), (708, 392), (740, 470), (826, 470)],
   fill_line=[(398, 540), (560, 522), (620, 494), (660, 478), (700, 482), (760, 512), (826, 540)], fill_rag=14, dark=(19, 17, 20),
   hips=dict(near=(668, 345), far=(625, 342)), far_ankle=(470, 610),
   belt=((612, 290), (700, 284)), shoulder=((525, 140), (695, 165))),
}

def target(F):
    rgb = np.asarray(Image.open(f'{TGT}gloam_rp_{F}_f00.jpg').convert('RGB'))
    a = Image.open(f'{TGT}gloam_rp_{F}_f00_alpha.png')
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
    """Gloam: the purple cloak (a* > 2.5, b* < -3.5); the black leather and trousers are near neutral."""
    from skimage.color import rgb2lab
    lab = rgb2lab(rgb); return (lab[..., 1] > 2.5) & (lab[..., 2] < -3.5)

def ragged(sh, amp, period, seed):
    """irregular tatter tips: triangles of random width (0.6..1.8 x period) and random depth (0.25..1 x amp)."""
    rng = np.random.default_rng(seed); out = np.zeros(sh[1]); x = 0
    while x < sh[1]:
        w = int(rng.uniform(0.6, 1.8) * period * 2) + 2; d = rng.uniform(0.25, 1.0) * amp
        t = np.abs(np.linspace(-1, 1, w)); out[x:x + w] = (d * (1 - t))[:max(0, min(w, sh[1] - x))]; x += w
    return out

def grow_leg(rgb, m, vis, dark=(24, 23, 16)):
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
    sh_ = f.astype(np.float32) * (1 - t) + np.array(dark, np.float32) * t
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
    legrgb = grow_leg(rgb, m, vis, c.get('dark', (24, 23, 16)))
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
    dark = np.array(c.get('dark', (24, 23, 16)), np.float32)
    fillc = (f.astype(np.float32) * 0.25 + dark * 0.75)
    back = rgb.copy(); back[fillm] = fillc[fillm].astype(np.uint8)
    backa = body | fillm
    # specks: small see-through holes left between cloak strands where the removed leg was (opaque in the target) are
    # closed with the same dark fill, so the back layer never shows background dots between the tatters
    k_ = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (c.get('speck_close', 9),) * 2)
    speck = cv2.morphologyEx(backa.astype(np.uint8), cv2.MORPH_CLOSE, k_).astype(bool) & ~backa & al & poly(c['legs_zone'], sh)
    back[speck] = fillc[speck].astype(np.uint8); backa = backa | speck
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
    rig = {k: list(c[k]) for k in ('H', 'K', 'A', 'heel', 'toe')}; rig['boot_top'] = c.get('boot_top', c['K'][1] + 4)
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
        dbg[F] = np.hstack([o[230:720, 390:840], o2[230:720, 390:840], o3[230:720, 390:840]])
    return rig

if __name__ == '__main__':
    dbg = {}
    for F in 'SE': cut(F, dbg)
    if len(sys.argv) > 1: Image.fromarray(np.vstack([dbg['S'], dbg['E']])).save(sys.argv[1])
