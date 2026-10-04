"""Mender v1 (Claude) - cut the approved targets into the layers the leg rig needs (all in target px, 1280x720).

Layers per facing F (written to PARTS, default ../parts):
  leg_F.png        ONE continuous painted leg, hip -> knee -> wrapped boot -> sole, from the target's fully visible leg
                   (S: screen-right forward leg = blockout L, E: screen-right forward leg seen from behind = blockout R). The thigh top that the tunic hides in the painting is
                   grown upward from the leg's own legging pixels (it stays under the belt / hem layer in every frame).
                   Purple cloak tatters that cross the leg are painted out from the leg's own black leather.
  legfar_F.png     the same leg for the other side (the same painting; the rig darkens the far leg).
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
PARTS = os.environ.get('M1PARTS', os.path.join(HERE, '..', 'parts'))

CFG = {
 'S': dict(
   # the forward (screen-right) leg = blockout L: trouser in the robe's front slit, wrapped boot, sole. Above the slit top it
   # is hidden by the robe in the painting and is grown from the leg itself.
   leg=[(696, 318), (750, 318), (750, 400), (753, 430), (759, 470), (764, 510), (768, 545), (772, 565), (778, 600), (786, 625),
        (800, 640), (822, 644), (836, 650), (841, 660), (832, 673), (806, 687), (780, 697), (762, 699), (755, 690), (749, 670),
        (742, 650), (731, 625), (719, 600), (711, 572), (704, 552), (699, 520), (698, 470), (699, 420)],
   vis_top=[(680, 405), (780, 405)],
   H=(722, 330), K=(742, 535), A=(785, 642), heel=(765, 696), toe=(838, 662), boot_top=553,
   # removed from the body: the forward leg below the slit top, the slit itself (filled dark: the robe's inside), the back boot
   remove=[[(696, 405), (760, 405), (775, 560), (845, 640), (845, 705), (745, 705), (700, 590)],
           [(578, 575), (655, 575), (662, 600), (660, 630), (657, 650), (650, 662), (612, 662), (598, 642), (581, 624), (575, 600)]],
   slit=[(703, 392), (722, 392), (745, 400), (760, 405), (768, 480), (775, 560), (740, 568), (712, 576), (690, 586), (670, 591),
         (650, 593), (655, 560), (668, 530), (684, 495), (695, 460), (700, 425)],
   keep_light=(600, 60.0),          # robe tatters (L* > 60) above this row stay on the body
   staff=[dict(pts=[(520, 330), (530, 420), (540, 500), (548, 580), (556, 640), (565, 684)], w=18)],
   behind=[], fill_rag=6.0, dark=(38, 31, 24),
   head_x=(600, 800), hips=dict(near=(722, 330), far=(645, 330)), far_ankle=(612, 620),
   belt=((620, 290), (760, 300)), shoulder=((565, 195), (775, 205))),
 'E': dict(
   # the screen-right leg seen from behind (blockout R): the planted wrapped boot below the robe hem; the rest is grown
   leg=[(676, 318), (720, 318), (728, 400), (738, 480), (742, 528), (741, 560), (743, 600), (745, 618), (760, 622), (776, 625),
        (785, 632), (783, 642), (770, 650), (750, 667), (703, 667), (701, 650), (703, 627), (700, 600), (690, 570), (683, 537),
        (680, 480), (678, 400)],
   vis_top=[(660, 528), (760, 528)],
   H=(697, 330), K=(714, 478), A=(722, 628), heel=(705, 665), toe=(772, 650), boot_top=528,
   remove=[[(678, 516), (744, 516), (745, 618), (790, 628), (790, 672), (698, 672), (700, 600), (688, 560)],
           [(545, 505), (600, 505), (606, 530), (598, 560), (570, 592), (556, 615), (560, 640), (578, 670), (583, 690), (566, 698),
            (530, 698), (507, 686), (493, 658), (486, 635), (500, 614), (520, 590), (530, 560), (538, 530)]],
   slit=[],
   keep_light=(600, 60.0),
   staff=[dict(pts=[(838, 40), (830, 150), (812, 250), (797, 350), (783, 430), (772, 500), (762, 560), (755, 610), (748, 665)], w=16)],
   behind=[], fill_rag=6.0, dark=(38, 31, 24),
   head_x=(580, 740), hips=dict(near=(697, 330), far=(615, 330)), far_ankle=(530, 640),
   belt=((600, 270), (705, 275)), shoulder=((545, 190), (735, 200))),
}

def target(F):
    rgb = np.asarray(Image.open(f'{TGT}mender_rp_{F}_f00.jpg').convert('RGB'))
    a = Image.open(f'{TGT}mender_rp_{F}_f00_alpha.png')
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

def light(rgb, L):
    """Mender: ivory robe tatters (CIE L* > L) - kept on the body where they hang over a removed boot top."""
    from skimage.color import rgb2lab
    return rgb2lab(rgb)[..., 0] > L

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
    os.makedirs(PARTS, exist_ok=True)
    staff = np.zeros(sh, bool)
    for b in c['staff']: staff |= band(b['pts'], b['w'], sh)
    staff &= al
    yy = np.indices(sh)[0]
    # ---- the one source leg
    vt = c['vis_top'][-1][1]
    m = poly(c['leg'], sh) & (al | (yy < vt))
    vis = below(c['vis_top'], sh) & al & ~staff & m
    legrgb = grow_leg(rgb, m, vis, c['dark'])
    bad = m & staff & below(c['vis_top'], sh)
    if bad.any():
        src = legrgb.copy(); src[~m | bad] = 0
        f = cv2.inpaint(src, (bad | ~m).astype(np.uint8) * 255, 7, cv2.INPAINT_TELEA); legrgb[bad] = f[bad]
    a = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 0.8)
    Image.fromarray(np.dstack([legrgb, (a * 255).astype(np.uint8)])).save(f'{PARTS}/leg_{F}.png')
    Image.fromarray(np.dstack([legrgb, (a * 255).astype(np.uint8)])).save(f'{PARTS}/legfar_{F}.png')
    # ---- body without the legs
    zone = np.zeros(sh, bool)
    rt = ragged(sh, c.get('rag_top', 8), 4, 11)
    for p_ in c['remove']:
        z = poly(p_, sh); cols = z.any(0); ztop = np.where(cols, np.argmax(z, 0), 0)
        # ragged top: the robe hem above a removed boot ends in tatter tips, never on the polygon's straight edge
        zone |= z & (yy >= (ztop + rt)[None, :])
    zone = cv2.dilate(zone.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    slit = poly(c['slit'], sh) if c['slit'] else np.zeros(sh, bool)
    ky, kl = c['keep_light']; keep = light(rgb, kl) & (yy < ky) & ~slit
    rem = (zone | slit) & al & ~staff & ~keep
    body = al & ~rem
    n, lab, st, _ = cv2.connectedComponentsWithStats(body.astype(np.uint8), 8)
    zd = cv2.dilate((zone | slit).astype(np.uint8), np.ones((21, 21), np.uint8)).astype(bool)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] < 300 and (zd & (lab == i)).any() and not (staff & (lab == i)).any(): body[lab == i] = False
    rem = al & ~body
    # slit fill: the robe's dark inside, down to a ragged edge at the hem (no straight cut)
    rg = ragged(sh, c['fill_rag'], 4, 3)
    sy = np.nonzero(slit.any(1))[0]
    fillm = slit & al
    if len(sy):
        bot = sy.max(); fillm &= yy < (bot - rg[None, :])
    src = rgb.copy(); src[~body] = 0
    known = body & ~cv2.dilate(rem.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    f = cv2.inpaint(src, (~known).astype(np.uint8) * 255, 11, cv2.INPAINT_TELEA)
    dark = np.array(c['dark'], np.float32)
    fillc = (f.astype(np.float32) * 0.3 + dark * 0.7)
    back = rgb.copy(); back[fillm] = fillc[fillm].astype(np.uint8)
    backa = body | fillm
    k_ = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    speck = cv2.morphologyEx(backa.astype(np.uint8), cv2.MORPH_CLOSE, k_).astype(bool) & ~backa & al & (zone | slit) & (yy < (sy.max() if len(sy) else 0))
    back[speck] = fillc[speck].astype(np.uint8); backa = backa | speck
    frontm = body.copy()
    for p_ in c['behind']: frontm &= ~poly(p_, sh)
    frontm |= staff
    Image.fromarray(np.dstack([back, backa * 255]).astype(np.uint8)).save(f'{PARTS}/back_{F}.png')
    Image.fromarray(np.dstack([back, frontm * 255]).astype(np.uint8)).save(f'{PARTS}/front_{F}.png')
    rig = {k: list(c[k]) for k in ('H', 'K', 'A', 'heel', 'toe')}; rig['boot_top'] = c['boot_top']
    rig['hips'] = {k: list(v) for k, v in c['hips'].items()}
    for k in ('far_ankle', 'belt', 'shoulder'): rig[k] = c[k]
    ys_, xs_ = np.nonzero(al); rig['sole'] = int(ys_.max())
    hx0, hx1 = c['head_x']; rig['top'] = int(np.nonzero(al[:, hx0:hx1].any(1))[0].min())   # hood top (not the staff crook)
    json.dump(rig, open(f'{PARTS}/rig_{F}.json', 'w'), indent=1)
    if dbg is not None:
        o = np.full_like(rgb, 230); o[backa] = back[backa]
        o[fillm] = (o[fillm] * 0.5 + np.array([0, 0, 255]) * 0.5).astype(np.uint8)
        o[backa & ~frontm] = (o[backa & ~frontm] * 0.6 + np.array([255, 255, 0]) * 0.4).astype(np.uint8)
        L = np.asarray(Image.open(f'{PARTS}/leg_{F}.png')).astype(np.float32)
        o2 = np.full_like(rgb, 200); aa = L[..., 3:] / 255; o2 = (L[..., :3] * aa + o2 * (1 - aa)).astype(np.uint8)
        o2[vis & ~cv2.erode(vis.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)] = (0, 200, 0)
        for k in ('H', 'K', 'A', 'heel', 'toe'):
            cv2.circle(o2, tuple(int(v) for v in c[k]), 4, (255, 0, 255), -1)
        for k, v in c['hips'].items(): cv2.circle(o, tuple(int(t) for t in v), 4, (255, 0, 0), -1)
        dbg[F] = np.hstack([rgb[250:710, 440:860], o[250:710, 440:860], o2[250:710, 440:860]])
    return rig

if __name__ == '__main__':
    dbg = {}
    for F in 'SE': cut(F, dbg)
    if len(sys.argv) > 1: Image.fromarray(np.vstack([dbg['S'], dbg['E']])).save(sys.argv[1])
