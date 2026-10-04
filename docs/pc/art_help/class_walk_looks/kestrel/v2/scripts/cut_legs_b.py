"""legs_sheet_b cut (Luca's notes on the v2 legs sheet): ONE continuous painted leg per facing, hip to sole, as a single layer
(no knee / boot-top seams: the target's own legging flows into its own boot), plus the pelvis / hip mass layer.
  T{F}_leg.png   S: the near (screen-right) leg; E: the near (screen-left) leg (thigh + laced boot + foot seen from behind),
                 cut by a smooth polygon (never by cape tatters); cloak green inside the leg is inpainted from the leg itself;
                 alpha feathered (gaussian sigma 1.2 target px) so the silhouette is anti-aliased, not stair-stepped
  pelvis_{F}.png belt + pouches + hip / crotch + tunic hem flaps (ragged hem from the painting), drawn over the thigh tops
  leg_b.json     anchors (target px): H hip root, K knee, A ankle, heel, toe
usage: cut_legs_b.py [debug.png]"""
import sys, json, numpy as np, cv2
from PIL import Image
from kcommon import *
from cut_target import green
CFG = {
 'S': dict(leg=[(588, 318), (656, 318), (660, 380), (668, 440), (672, 505), (692, 518), (690, 560), (692, 600), (702, 628), (708, 646),
                (730, 653), (742, 672), (724, 688), (698, 699), (662, 699), (658, 670), (653, 640), (634, 598), (622, 530), (614, 512),
                (601, 450), (590, 390)],
           H=(650, 280), K=(648, 515), A=(677, 648), heel=(667, 696), toe=(737, 675),
           pelvis=[(535, 258), (712, 252), (722, 300), (724, 405), (578, 405), (530, 300)], pelvis_solid_y=384, leg_excl_y=336),
 'E': dict(leg=[(598, 398), (650, 398), (652, 480), (655, 520), (645, 548), (636, 600), (628, 640), (626, 694), (558, 697), (532, 670),
                (533, 640), (557, 600), (566, 546), (572, 506), (591, 498)],
           H=(625, 330), K=(605, 520), A=(568, 640), heel=(548, 680), toe=(622, 688),
           pelvis=[(640, 297), (716, 291), (734, 318), (744, 372), (752, 440), (598, 440), (606, 380), (622, 330)], pelvis_solid_y=424, leg_excl_y=999),
}

def cut(F, dbg=None):
    c = CFG[F]; rgb, al = target(F); sh = al.shape
    m = poly_mask(c['leg'], sh) & al
    gr = green(rgb) & m
    # cloak / tunic green inside the leg outline = cloth seen through gaps: inpaint it from the leg's own browns
    src = rgb.copy(); src[~al] = 0
    fill = cv2.inpaint(src, (gr | ~m).astype(np.uint8) * 255, 7, cv2.INPAINT_TELEA)   # sources: the leg's own browns only
    legrgb = np.where(gr[..., None], fill, rgb)
    a = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 1.2)
    a = np.clip((a - 0.5) * 1.6 + 0.5, 0, 1)                       # keep the edge position, ~2 target px soft ramp
    # thigh top: no hard horizontal cut line (Luca notes 1/2) - the leg fades in over top_fade target px under the pelvis / hem
    yy_ = np.indices(sh)[0]; y0_ = min(p_[1] for p_ in c['leg'])
    t_ = np.clip((yy_ - y0_) / c.get('top_fade', 34.0), 0, 1); a = a * (t_ * t_ * (3 - 2 * t_))
    Image.fromarray(np.dstack([legrgb, (a * 255).astype(np.uint8)]).astype(np.uint8)).save(f'{PARTS}T{F}_leg.png')
    yy = np.indices(sh)[0]
    # soft pelvis: no hard polygon / solid-line edges (Luca note 5). Solid content fades out over 12 px below pelvis_solid_y, only
    # the tunic's own ragged green hem continues; the polygon border fades over 8 px; the near leg's own pixels below leg_excl_y
    # stay with the leg (no static thigh copy); specks < 150 px dropped
    poly = poly_mask(c['pelvis'], sh)
    a_sol = np.clip((c['pelvis_solid_y'] + 6 - yy) / 12.0, 0, 1)
    a = np.maximum(a_sol, green(rgb).astype(np.float32)) * (poly & al)
    a = a * ~(m & (yy > c['leg_excl_y']))
    n_, lab, st, _ = cv2.connectedComponentsWithStats((a > 0.3).astype(np.uint8), 8)
    keep = np.zeros(n_, bool); keep[1:] = st[1:, cv2.CC_STAT_AREA] >= 150; a = a * keep[lab]
    din = cv2.distanceTransform(poly.astype(np.uint8), cv2.DIST_L2, 5)
    pa = cv2.GaussianBlur(a.astype(np.float32), (0, 0), 0.9) * np.clip(din / 8.0, 0, 1); pm = pa > 0.5
    Image.fromarray(np.dstack([rgb, (pa * 255).astype(np.uint8)]).astype(np.uint8)).save(f'{PARTS}pelvis_{F}.png')
    if dbg is not None:
        o = (rgb * 0.45 + 70).astype(np.uint8); o[~al] = 40
        o[m] = legrgb[m]; o[pm] = (o[pm] * 0.5 + np.array([255, 200, 0]) * 0.5).astype(np.uint8)
        for k in ('H', 'K', 'A', 'heel', 'toe'): cv2.circle(o, tuple(int(v) for v in c[k]), 4, (255, 0, 255), -1)
        dbg[F] = o
    return {k: list(c[k]) for k in ('H', 'K', 'A', 'heel', 'toe')}

if __name__ == '__main__':
    dbg = {}; info = {F: cut(F, dbg) for F in 'SE'}
    json.dump(info, open(f'{PARTS}leg_b.json', 'w'), indent=1); print(info)
    if len(sys.argv) > 1: Image.fromarray(np.hstack([dbg['S'][230:720, 480:800], dbg['E'][230:720, 480:800]])).save(sys.argv[1])
