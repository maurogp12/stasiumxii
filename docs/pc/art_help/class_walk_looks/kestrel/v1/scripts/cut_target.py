"""cut the approved Kestrel targets into layers (target px, full frame RGBA):
  body_F   = target minus both legs below the hem (the bow kept where it crosses a leg); S: holes in the thigh zone inpainted
  front_F  = (S only) the part of the body drawn over the legs: belt, pouches, tunic hem, bow + bow hand
  leg parts from ONE fully visible target leg (S: near leg, E: screen-right leg), cut across the leg axis at knee and ankle:
  T{F}_thigh, T{F}_shin (boot shaft), T{F}_foot (boot foot) + anchors in target_legs.json.
usage: cut_target.py [debug.png]"""
import sys, json, numpy as np, cv2
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
   inpaint_above=522,
   use=0, H=(621, 335), K=(648, 515), A=(677, 648), heel=(667, 696), toe=(737, 675),
   front=dict(above=345, polys=[[(430, 290), (510, 290), (515, 410), (430, 410)]])),
 'E': dict(
   legs=[[(638, 412), (702, 410), (703, 470), (701, 505), (706, 560), (704, 588), (716, 591), (737, 595), (742, 606), (729, 623),
          (706, 641), (700, 650), (674, 650), (672, 630), (670, 600), (661, 560), (653, 520), (644, 480), (632, 440)],
         [(585, 430), (640, 430), (646, 480), (652, 520), (641, 546), (634, 600), (628, 640), (626, 694), (558, 697), (532, 670),
          (533, 640), (557, 600), (568, 546), (578, 500)]],
   keep=[], inpaint_above=480, inpaint_rag=25, inpaint_back=True,   # E: dark under-cape fill drawn BEHIND the legs (no gaps at the hem)
   use=0, H=(668, 392), K=(677, 512), A=(689, 598), heel=(680, 649), toe=(737, 606), front=None,
   shin_from=dict(use=1, K=(605, 520), A=(568, 640))),   # E shin = the near (screen-left) boot shaft: the right one is foreshortened
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
    rem = (legm[0] | legm[1]) & ~keep & ~gr
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
    info = {}
    for nm, pm in parts.items():
        pm = cv2.morphologyEx(pm.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)) > 0
        Image.fromarray(np.dstack([rgb, pm * 255]).astype(np.uint8)).save(f'{PARTS}T{F}_{nm}.png')
        ys, xs = np.nonzero(pm); info[nm] = dict(bbox=[int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())], px=int(pm.sum()))
    info['anchors'] = dict(H=c['H'], K=c['K'], A=c['A'], heel=c['heel'], toe=c['toe'])
    if sf: info['anchors'].update(Ks=sf['K'], As=sf['A'])
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
