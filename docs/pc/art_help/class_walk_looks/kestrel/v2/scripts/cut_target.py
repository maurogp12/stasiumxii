"""cut the approved Kestrel targets into layers (target px, full frame RGBA):
  body_F   = target minus both legs below the hem (the bow kept where it crosses a leg); S: holes in the thigh zone inpainted
  front_F  = (S only) the part of the body drawn over the legs: belt, pouches, tunic hem, bow + bow hand
  leg parts from ONE fully visible target leg (S: near leg, E: screen-right leg), cut across the leg axis at knee and ankle:
  T{F}_thigh, T{F}_shin (boot shaft), T{F}_foot (boot foot) + anchors in target_legs.json.
usage: cut_target.py [debug.png]"""
import sys, json, math, numpy as np, cv2
from PIL import Image
from kcommon import *
CFG = {
 'S': dict(
   legs=[[(586, 333), (656, 333), (660, 380), (668, 440), (672, 505), (692, 518), (690, 560), (692, 600), (702, 628), (708, 646),
          (730, 653), (742, 672), (724, 688), (698, 699), (662, 699), (658, 670), (653, 640), (634, 598), (622, 530), (614, 512),
          (601, 450), (589, 390)],
         [(540, 333), (600, 333), (604, 400), (610, 470), (610, 522), (601, 556), (586, 598), (578, 632), (592, 648), (592, 662),
          (560, 663), (538, 657), (524, 637), (527, 600), (540, 560), (545, 520), (540, 450), (538, 380)]],
   keep=[dict(pts=[(395, 190), (628, 505)], w=4),                                   # bow string
         dict(pts=[(470, 390), (500, 425), (540, 452), (580, 474), (612, 494), (630, 507)], w=9)],   # bow lower limb
   green_clip_y=340, inner_x0=578, inpaint_above=420, inpaint_rag=30, inpaint_back=True, fill='dark',   # v2: dark inner-leg band under the hem only
   use=0, H=(621, 335), K=(648, 515), A=(677, 648), heel=(667, 696), toe=(737, 675),
   front=dict(above=345, polys=[[(430, 290), (510, 290), (515, 410), (430, 410)]])),
 'E': dict(
   legs=[[(638, 412), (702, 410), (703, 470), (701, 505), (706, 560), (704, 588), (716, 591), (737, 595), (742, 606), (729, 623),
          (706, 641), (700, 650), (674, 650), (672, 630), (670, 600), (661, 560), (653, 520), (644, 480), (632, 440)],
         [(585, 430), (640, 430), (646, 480), (652, 520), (641, 546), (634, 600), (628, 640), (626, 694), (558, 697), (532, 670),
          (533, 640), (557, 600), (568, 546), (578, 500)]],
   keep=[], inpaint_above=480, inpaint_rag=25, inpaint_back=True, fill='dark',   # E: dark under-cape fill drawn BEHIND the legs (no gaps at the hem)
   use=0, H=(668, 392), K=(677, 512), A=(689, 598), heel=(680, 649), toe=(737, 606), front=None,
   shin_from=dict(use=1, K=(605, 520), A=(568, 640)),
   boot_same_leg=False),   # True = the forward leg's own (foreshortened) boot: tested, its mid-stance reach goes to 1.22 (worse)   # E shin = the near (screen-left) boot shaft: the right one is foreshortened
}

def green(rgb):
    from skimage.color import rgb2lab
    lab = rgb2lab(rgb); return (lab[..., 1] < -4) & (lab[..., 2] > 4)

def cut(F, dbg=None):
    c = CFG[F]; rgb, al = target(F); sh = al.shape
    legm = [poly_mask(p, sh) & al for p in c['legs']]
    keep = np.zeros(sh, bool)
    for k in c['keep']: keep |= band_mask(k['pts'], k['w'], sh)
    gr = green(rgb)
    yy0 = np.indices(sh)[0]
    # v2 (brief point 2): below green_clip_y the cloak/tunic green inside the leg outlines is cloth seen between the target's
    # legs; once the legs move it floats as a green patch, so it is cut out with the legs (the body keeps only its own cloth)
    xx0 = np.indices(sh)[1]; tri0 = np.abs(((xx0 / 7.0) % 2.0) - 1.0)
    gkeep = gr & (yy0 < c.get('green_clip_y', 10 ** 6) + 22 * tri0)     # ragged clip line (tatters, not a straight cut)
    rem = (legm[0] | legm[1]) & ~keep & ~gkeep
    body = al & ~rem
    rgba = np.dstack([rgb, body * 255]).astype(np.uint8)
    if c['inpaint_above']:     # S: removed leg pixels in the thigh zone (behind them: tunic/cape) are inpainted, below left open
        yy, xx = np.indices(sh)
        # ragged lower edge like the cape tatters (a flat cut reads as a box between the legs once they part)
        rng = np.random.default_rng(7); ph = rng.uniform(0, 1, sh[1] // 9 + 2)
        tri = np.abs(((xx / 9.0) % 2.0) - 1.0); cut_y = c['inpaint_above'] - c.get('inpaint_rag', 60) * tri * (0.5 + ph[(xx // 18).clip(0, len(ph) - 1)])
        hole = rem & (yy < cut_y)
        # keep the fill around the kept bow limb / string so the bow tip never hangs detached below a tatter
        hole |= rem & (yy < c['inpaint_above']) & cv2.dilate(keep.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)
        src = rgb.copy(); src[~al] = 0            # the jpg is white outside the mask: never let that bleed into the fill
        unk = hole | ~cv2.erode(al.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool) | ~gr   # jpg edges whitish; fill only from cloak/tunic greens
        y0, y1 = 300, c['inpaint_above'] + 20                          # band only (speed)
        fb = cv2.inpaint(src[y0:y1], unk[y0:y1].astype(np.uint8) * 255, 5, cv2.INPAINT_TELEA)
        fill = rgb.copy(); fill[y0:y1] = fb
        if c.get('fill') == 'dark':
            # v2 (brief point 2): the gap between the thighs is the dark inner leg, never cloak green. Colour = the darkest 15 %
            # of the target leg pixels, with a little of the inpainted luminance as texture (no hue from the cloak)
            lp = rgb[(legm[0] | legm[1]) & al].astype(float); lum = lp.mean(1); dk = lp[lum <= np.percentile(lum, 15)].mean(0)
            fl = fill.astype(float).mean(2, keepdims=True); tex = (fl - fl[hole].mean()) * 0.25
            yy_ = np.indices(sh)[0][..., None].astype(float); shade = 1.0 - 0.25 * np.clip((yy_ - 330) / 120.0, 0, 1)
            dark = np.clip(dk[None, None, :] * shade + tex, 0, 255).astype(np.uint8)
            if c.get('inner_x0') is not None:   # outside the crotch (behind the far thigh's outer side) the cape continues: keep cloak fill
                inner = (np.indices(sh)[1] >= c['inner_x0'])[..., None]
                fill = np.where(inner, dark, fill)
            else:
                fill = dark
        if c.get('inpaint_back'):
            back = np.zeros_like(rgba); back[..., :3][hole] = fill[hole]; back[..., 3][hole] = 255
            Image.fromarray(back).save(f'{PARTS}back_{F}.png')
        else:
            rgba[..., :3][hole] = fill[hole]; rgba[..., 3][hole] = 255
    Image.fromarray(rgba).save(f'{PARTS}body_{F}.png')
    if c['front']:
        yy = np.indices(sh)[0]; fm = (yy < c['front']['above']) | keep
        for p in c['front']['polys']: fm |= poly_mask(p, sh)
        Image.fromarray(np.dstack([rgb, (rgba[..., 3] > 0) & fm & al] if False else [rgb, ((rgba[..., 3] > 0) & fm) * 255]).astype(np.uint8)).save(f'{PARTS}front_{F}.png')
    # leg parts from the chosen leg: split across the axis at knee and ankle (with overlap), foot = below the ankle line
    m = legm[c['use']] & ~keep & ~gr
    n, lab = cv2.connectedComponents(m.astype(np.uint8)); 
    if n > 2: m = lab == (1 + np.argmax([(lab == k).sum() for k in range(1, n)]))
    H, K, A = (np.array(c[k], float) for k in 'HKA'); yy, xx = np.indices(sh).astype(float); P = np.dstack([xx, yy])
    def side(p0, p1):   # signed distance along the segment p0->p1 axis from p1
        u = unit(p1 - p0); return (P - p1) @ u
    t_k = side(H, K); t_a = side(K, A)
    sf = c.get('shin_from')
    if sf:
        m2 = legm[sf['use']] & ~keep & ~gr; K2, A2 = np.array(sf['K'], float), np.array(sf['A'], float)
        u2 = unit(A2 - K2); t2k = (P - K2) @ u2; t2a = (P - A2) @ u2
    he, to = np.array(c['heel'], float), np.array(c['toe'], float)
    parts = {'thigh': m & (t_k <= 10), 'shin': m & (t_k >= -6) & (t_a <= 8), 'foot': m & (t_a >= -10)}
    if sf: parts['shin'] = m2 & (t2k >= -6) & (t2a <= 8)
    # v2 (leg priority 5981171032): the boot is ONE piece from the knee line to the sole (shaft + laces + foot), deformed
    # by a smooth 2-bone skin at the ankle in kbuild (no seam, the boot top stays on the knee line)
    boot_rgb = rgb.copy()
    if sf and not c.get('boot_same_leg'):   # E (option A): the near boot shaft (unforeshortened) + the screen-right boot foot moved rigidly onto the shaft's ankle
        u1 = unit(A - K); u2 = unit(A2 - K2); ang = math.atan2(u2[1], u2[0]) - math.atan2(u1[1], u1[0])
        R = np.array([[math.cos(ang), -math.sin(ang)], [math.sin(ang), math.cos(ang)]]); Mf = np.hstack([R, (A2 - R @ A)[:, None]])
        fm = (m & (t_a >= -10)).astype(np.uint8) * 255
        frgb = cv2.warpAffine(rgb, Mf, (sh[1], sh[0]), flags=cv2.INTER_LINEAR); fa = cv2.warpAffine(fm, Mf, (sh[1], sh[0]), flags=cv2.INTER_LINEAR) > 127
        shaft = m2 & (t2k >= -6) & (t2a <= 14)
        boot = shaft | fa; boot_rgb = np.where(shaft[..., None], rgb, np.where(fa[..., None], frgb, rgb))
        bhe, bto = (R @ he + Mf[:, 2]), (R @ to + Mf[:, 2]); bK, bA = K2, A2
    else:
        boot = m & (t_k >= -6); bhe, bto, bK, bA = he, to, K, A
    parts['boot'] = boot
    info = {}
    for nm, pm in parts.items():
        pm = cv2.morphologyEx(pm.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)) > 0
        Image.fromarray(np.dstack([boot_rgb if nm == 'boot' else rgb, pm * 255]).astype(np.uint8)).save(f'{PARTS}T{F}_{nm}.png')
        ys, xs = np.nonzero(pm); info[nm] = dict(bbox=[int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())], px=int(pm.sum()))
    info['anchors'] = dict(H=c['H'], K=c['K'], A=c['A'], heel=c['heel'], toe=c['toe'])
    if sf: info['anchors'].update(Ks=sf['K'], As=sf['A'])
    info['boot_anchors'] = dict(K=[round(float(v), 2) for v in bK], A=[round(float(v), 2) for v in bA], heel=[round(float(v), 2) for v in bhe], toe=[round(float(v), 2) for v in bto])
    if dbg is not None:
        o = (rgb * 0.5 + 64).astype(np.uint8); o[~al] = 30
        for col, mm in ((0, parts['thigh']), (1, parts['shin']), (2, parts['foot'])): o[..., col][mm] = 255
        o[rem & ~legm[c['use']]] = (255, 0, 255); o[keep & al] = (255, 255, 0)
        for p in (H, K, A, he, to): cv2.circle(o, tuple(int(v) for v in p), 4, (255, 255, 255), -1)
        dbg[F] = o
    return info

if __name__ == '__main__':
    dbg = {}; info = {F: cut(F, dbg) for F in 'SE'}
    json.dump(info, open(f'{PARTS}target_legs.json', 'w'), indent=1); print(json.dumps(info))
    if len(sys.argv) > 1:
        Image.fromarray(np.hstack([dbg['S'][:, 260:800], dbg['E'][:, 340:880]])).save(sys.argv[1])
