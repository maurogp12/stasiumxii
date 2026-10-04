"""Kestrel actions v1 - cut the approved targets into the extra painted parts the actions need (target px, 1280x720).

The walk parts (../../v3_claude/parts: leg_F, legfar_F, back_F, front_F, rig_F.json) are read, never written.
Written to ../parts:
  body_F.png      the walk's back_F layer (target minus legs) with the moving arms and the bow taken out. Where an arm or the
                  bow covered the cloak or the body, the hole is filled from the surrounding cloth (Telea fill + the painted
                  grain of a nearby patch), so nothing shows when the arm lifts away; where it hung over background the
                  pixels just go (alpha). S: both arms + bow; E: the bow arm + bow (her left arm is behind the cloak).
  front_F.png     the walk's front_F mask (what hangs in front of the legs) on the same filled painting.
  wcape_F.png     cloak skin weights (R = upper panel, G = lower panel; the rest is the rigid torso), feathered, no cut.
  arm_R_F.png     ONE continuous painted arm, shoulder -> elbow -> bracer -> fist: the part of the upper arm hidden under the
  arm_L_S.png     cloak or pauldron is grown from the sleeve itself (mirrored, fading into shadow); cloak green, the bow
                  string and the bow limbs crossing it are painted out of the arm (the fist keeps its painted grip).
                  E's left (draw) arm is the E bow arm mirrored and 12 % darker (it is hidden behind the cloak in the target).
  cover_F_R/L.png the shoulder covers (S: pauldron / cloak drape, E: cloak over the shoulder) cut from the body with their
                  own alpha; they are drawn over the arm so the shoulder root never shows.
  bow_hang_F.png  the painted bow and string as held in the target (rigid with the bow forearm while it hangs).
  bow_aim_F.png   the bow limbs without the string (the grip under the fist filled from the wood), warped along the aimed bow curve; the string is drawn per frame.
  arig_F.json     joints in target px: shoulders, elbows, wrists, hands, pelvis / neck axis, the bow centre line and grip.
usage: acut.py [debug.png]"""
import os, sys, json, numpy as np, cv2
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
V3S = os.path.abspath(os.path.join(HERE, '../../v3_claude/scripts'))
sys.path.insert(0, V3S)
import kcut
from kcut import target, poly, band, green, grow_leg
V3P = os.path.abspath(os.path.join(HERE, '../../v3_claude/parts'))
OUT = os.environ.get('KAPARTS', os.path.join(HERE, '..', 'parts'))

BOW_S = [(397, 195), (415, 215), (427, 250), (438, 290), (450, 330), (467, 352), (482, 365), (495, 378), (508, 395), (522, 425),
         (545, 455), (575, 475), (605, 492), (628, 505)]
CFG = {
 'S': dict(
   arms={
    'R': dict(poly=[(512, 196), (558, 196), (550, 240), (543, 267), (538, 300), (527, 337), (519, 360), (519, 387), (510, 395),
                    (496, 392), (479, 375), (476, 356), (487, 333), (496, 300), (498, 262), (504, 225)],
              vis_top=[(500, 228), (560, 228)], fist=[(478, 356), (518, 356), (519, 395), (480, 380)],
              J=dict(shoulder=(536, 206), elbow=(519, 262), wrist=(505, 347), hand=(499, 372)),
              cover=[(470, 150), (552, 150), (556, 200), (548, 240), (528, 250), (508, 236), (488, 250), (470, 210)],
              fill_src=(-55, -30), fill_x=(0, 1280)),
    'L': dict(poly=[(698, 158), (738, 163), (746, 200), (753, 245), (761, 290), (771, 320), (777, 343), (771, 367), (761, 389),
                    (750, 390), (742, 363), (738, 337), (734, 322), (726, 292), (719, 262), (707, 250), (699, 215)],
              vis_top=[(690, 188), (760, 188)], fist=None,
              J=dict(shoulder=(716, 172), elbow=(735, 257), wrist=(752, 334), hand=(757, 360)),
              cover=[(668, 112), (730, 118), (752, 160), (758, 196), (760, 252), (744, 250), (730, 205), (700, 196), (668, 175)],
              fill_src=(-40, 0), fill_x=(0, 712))},
   bow=dict(line=BOW_S, w=13, grip=(495, 378), string=[(418, 218), (626, 505)]),
   pelvis=(596, 320), neck=(648, 140), fill_src=[(-55, -30), (-70, 10), (-45, 25)],
   core=[(560, 0), (710, 0), (722, 120), (760, 165), (780, 260), (800, 400), (720, 420), (690, 520), (600, 520), (560, 420),
         (545, 300), (545, 200), (530, 196), (470, 150), (470, 30), (560, 30)],          # incl. the quiver (rigid on the back)
   cape_hinge=dict(upper=(540, 175), lower_y=(330, 420)),
 ),
 'E': dict(
   arms={
    'R': dict(poly=[(680, 186), (726, 186), (731, 207), (733, 237), (741, 260), (751, 270), (761, 300), (771, 323), (784, 340),
                    (798, 350), (803, 360), (799, 377), (790, 384), (777, 378), (760, 351), (740, 331), (723, 304), (710, 294),
                    (700, 277), (693, 253), (687, 227), (682, 210)],
              vis_top=[(670, 212), (740, 212)], fist=[(778, 342), (804, 352), (800, 382), (778, 376)],
              J=dict(shoulder=(706, 202), elbow=(718, 283), wrist=(774, 350), hand=(789, 364)),
              cover=[(650, 120), (705, 128), (722, 160), (738, 196), (735, 214), (712, 206), (690, 212), (670, 206), (650, 180)],
              fill_src=(0, 0), fill_x=(0, 699))},
   bow=dict(line=[(826, 122), (816, 160), (815, 203), (819, 253), (815, 298), (804, 331), (794, 358), (784, 387), (776, 420),
                  (765, 454), (745, 492), (726, 523), (711, 554), (703, 575)], w=11, grip=(795, 365),
            string=[(818, 140), (703, 558)]),
   pelvis=(653, 389), neck=(640, 175), fill_xmax=700, fill_src=[(-30, 0), (-25, 30), (-40, -20)],
   core=[(600, 30), (700, 30), (730, 200), (740, 330), (730, 450), (680, 470), (645, 470), (632, 330), (605, 250), (578, 285),
         (545, 285), (498, 90), (520, 55), (600, 60)],                                                        # incl. the quiver
   cape_hinge=dict(upper=(640, 175), lower_y=(360, 450)),
 ),
}

def rgba(path):
    a = np.asarray(Image.open(path).convert('RGBA')); return a[..., :3].copy(), a[..., 3] > 127

def save(name, rgb, a):
    Image.fromarray(np.dstack([rgb, (a * 255).astype(np.uint8) if a.dtype != np.uint8 else a])).save(f'{OUT}/{name}.png')

def grain_fill(rgb, hole, known, src_off, radius=9, nograin=None):
    """Telea fill of `hole` from `known`, plus the high-pass grain of the painting shifted by src_off (and a second patch
    shifted the other way), so a filled cloak keeps its brush texture instead of a smooth smear."""
    src = rgb.copy(); src[~known] = 0
    f = cv2.inpaint(src, (~known).astype(np.uint8) * 255, radius, cv2.INPAINT_TELEA).astype(np.float32)
    rf = rgb.astype(np.float32); hp = rf - cv2.GaussianBlur(rf, (0, 0), 3)
    hp = np.clip(hp, -22, 22)                      # cloth grain only, never a copied highlight edge
    kn = (known & ~nograin if nograin is not None else known).astype(np.float32)[..., None]
    g = np.zeros_like(rf); wsum = np.zeros_like(kn)
    for dx, dy in src_off:
        M = np.float32([[1, 0, -dx], [0, 1, -dy]])
        g += cv2.warpAffine(hp * kn, M, (rgb.shape[1], rgb.shape[0])); wsum += cv2.warpAffine(kn[..., 0], M, (rgb.shape[1], rgb.shape[0]))[..., None]
    g = g / np.maximum(wsum, 1e-3)
    out = rgb.copy(); v = np.clip(f + 0.9 * g, 0, 255).astype(np.uint8); out[hole] = v[hole]
    return out

def cut(F, dbg=None):
    c = CFG[F]; os.makedirs(OUT, exist_ok=True)
    trgb, tal = target(F); sh = tal.shape
    if kcut.CFG[F].get('alpha_fix'):        # the approved E alpha drops pieces of the upper bow limb and string (as in kcut)
        bg = np.median(trgb[~tal], 0).astype(np.float32); dist = np.abs(trgb.astype(np.float32) - bg).max(-1)
        for b_ in kcut.CFG[F]['alpha_fix']: tal = tal | (band(b_['pts'], b_['w'], sh) & (dist > b_['d']))
        tal = tal | (band(c['bow']['line'], c['bow']['w'] + 2, sh) & (dist > 16))      # and along the limb we traced
        tal = tal | (band(c['bow']['string'], 3, sh) & (dist > 12))
    brgb, ba = rgba(f'{V3P}/back_{F}.png'); _, fa = rgba(f'{V3P}/front_{F}.png')
    gr = green(trgb)
    from skimage.color import rgb2lab
    lab = rgb2lab(trgb)
    # ---- bow (as painted): limbs band (wood colour) + the string band
    b = c['bow']; limb = band(b['line'], b['w'], sh) & tal & ~(gr & (lab[..., 0] < 45))
    strg = band(b['string'], 3, sh) & tal
    bowm = limb | strg
    # ---- arms
    arms = {}
    for sd, ac in c['arms'].items():
        m = poly(ac['poly'], sh) & (tal | ~kcut.below([(0, ac['vis_top'][0][1]), (1280, ac['vis_top'][0][1])], sh))
        vis = kcut.below(ac['vis_top'], sh) & tal & ~(gr & (lab[..., 1] < -6))
        arm = grow_leg(trgb, m, vis)
        # cloak green, the string and the bow limbs that cross the arm are painted out from the arm's own leather
        fist = poly(ac['fist'], sh) if ac.get('fist') else np.zeros(sh, bool)
        bad = m & vis & (((gr & (lab[..., 1] < -6))) | (bowm & ~fist))
        if bad.any():
            src = arm.copy(); src[~m] = 0
            f = cv2.inpaint(src, (bad | ~m).astype(np.uint8) * 255, 6, cv2.INPAINT_TELEA); arm[bad] = f[bad]
        a = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 0.8)
        save(f'arm_{sd}_{F}', arm, (a * 255).astype(np.uint8)); arms[sd] = m
        # the shoulder cover: body pixels in the cover polygon, with their own alpha (drawn over the arm root)
        # inside the arm outline only the cloak cloth (its own ragged edge) and, above the visible line, the pauldron leather
        cloth = gr | (lab[..., 1] < -4)
        leather = (lab[..., 0] > 22) & (lab[..., 2] > 8) & ~kcut.below(ac['vis_top'], sh)
        pc = poly(ac['cover'], sh) & tal
        cv_ = pc & (~m | (m & (cloth | leather)))
        cv_ = cv2.morphologyEx(cv_.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)).astype(bool)
        n_, lab_, st_, _ = cv2.connectedComponentsWithStats(cv_.astype(np.uint8), 8)
        for k in range(1, n_):
            if st_[k, cv2.CC_STAT_AREA] < 60: cv_[lab_ == k] = False
        cv_ &= ~bowm
        save(f'cover_{F}_{sd}', trgb, (cv2.GaussianBlur(cv_.astype(np.float32), (0, 0), 0.7) > 0.5))
    # E: the draw arm (left) is the bow arm mirrored about the shoulder column, a little darker (far side)
    rig = dict(arms={sd: {k: list(v) for k, v in ac['J'].items()} for sd, ac in c['arms'].items()})
    if F == 'E':
        A = np.asarray(Image.open(f'{OUT}/arm_R_E.png')).copy(); x0 = c['arms']['R']['J']['shoulder'][0]
        M = np.float32([[-1, 0, 2 * x0], [0, 1, 0]]); L = cv2.warpAffine(A, M, (1280, 720), flags=cv2.INTER_NEAREST)
        L[..., :3] = (L[..., :3] * 0.88).astype(np.uint8); Image.fromarray(L).save(f'{OUT}/arm_L_E.png')
        rig['arms']['L'] = {k: [2 * x0 - v[0], v[1]] for k, v in c['arms']['R']['J'].items()}
        Image.fromarray(np.zeros((720, 1280, 4), np.uint8)).save(f'{OUT}/cover_E_L.png')
    # ---- body without the arms and the bow
    # removal masks are wider than the parts (the painted dark outline of the limbs and the string's halo go too)
    bowrem = band(b['line'], b['w'] + 11, sh) & ~(gr & (lab[..., 1] < -6) & ~limb) | band(b['string'], 15, sh)
    rem = bowrem.copy(); xx = np.indices(sh)[1]; fillm = np.zeros(sh, bool)
    for sd, m in arms.items():
        rem |= m; fx = c['arms'][sd]['fill_x']; fillm |= m & (xx >= fx[0]) & (xx < fx[1])
    rem &= ba
    keep = ba & ~rem
    # removed pixels inside the body silhouette get filled; over background they simply go
    clo = cv2.morphologyEx(keep.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (45, 45))).astype(bool)
    hole = rem & ((clo & (xx < c.get('fill_xmax', 1280))) | fillm)
    # a bow / string pixel lying over cloth (most of its neighbourhood off the band is opaque) is filled too
    kf_ = keep.astype(np.float32); nb = cv2.blur(kf_, (31, 31)) / np.maximum(cv2.blur((~bowrem).astype(np.float32), (31, 31)), 1e-3)
    hole |= rem & bowrem & (nb > 0.7) & (xx < c.get('fill_xmax', 1280))
    rgb = brgb.copy()
    known = keep & ~cv2.dilate(rem.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    off = c['fill_src']
    rgb = grain_fill(rgb, hole, known, off, nograin=band(b['line'], b['w'] + 30, sh) | band(b['string'], 16, sh))
    rgb = grain_fill(rgb, hole & bowrem, known & ~bowrem, [(-20, -20), (20, 20), (-30, 10)])
    bodya = keep | hole
    bodya = cv2.morphologyEx(bodya.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)).astype(bool) | keep
    n_, lab_, st_, _ = cv2.connectedComponentsWithStats(bodya.astype(np.uint8), 8)     # slivers left beside a removed arm
    for k in range(1, n_):
        if st_[k, cv2.CC_STAT_AREA] < 400: bodya[lab_ == k] = False
    fronta = fa & bodya & ~(rem & ~hole)
    fronta &= ~bowrem
    save(f'body_{F}', rgb, bodya); save(f'front_{F}', rgb, fronta)
    # ---- cloak weights: cloth outside the torso core; the lower panel below the hinge band
    core = poly(c['core'], sh)
    capem = bodya & ~core
    capem = cv2.morphologyEx(capem.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)).astype(np.float32)
    wc = cv2.GaussianBlur(capem, (0, 0), 14)
    y0, y1 = c['cape_hinge']['lower_y']; yy = np.indices(sh)[0].astype(np.float32)
    t = np.clip((yy - y0) / (y1 - y0), 0, 1); t = t * t * (3 - 2 * t)
    wl = wc * t; wu = wc * (1 - t)
    Image.fromarray(np.dstack([(wu * 255).astype(np.uint8), (wl * 255).astype(np.uint8), np.zeros(sh, np.uint8)])).save(f'{OUT}/wcape_{F}.png')
    # ---- the bow as held, and (S) the aimable bow limbs
    save(f'bow_hang_{F}', trgb, cv2.GaussianBlur(bowm.astype(np.float32), (0, 0), 0.6) > 0.4)
    if True:      # the aimable bow limbs (no string), each facing from its own painting
        lm = band(b['line'], b['w'] + 2, sh) & tal & ~strg & ~(gr & (lab[..., 0] < 45))
        lr = trgb.copy()
        fist = poly(c['arms']['R']['fist'], sh) & lm
        src = lr.copy(); src[~(lm & ~fist)] = 0
        f = cv2.inpaint(src, (~(lm & ~fist)).astype(np.uint8) * 255, 5, cv2.INPAINT_TELEA); lr[fist] = f[fist]
        save(f'bow_aim_{F}', lr, cv2.GaussianBlur(lm.astype(np.float32), (0, 0), 0.6) > 0.4)
    rig.update(bow_line=[list(p) for p in b['line']], bow_w=b['w'], grip=list(b['grip']), string=[list(p) for p in b['string']],
               pelvis=list(c['pelvis']), neck=list(c['neck']), cape_upper=list(c['cape_hinge']['upper']),
               cape_lower_y=list(c['cape_hinge']['lower_y']))
    json.dump(rig, open(f'{OUT}/arig_{F}.json', 'w'), indent=1)
    if dbg is not None:
        o = np.full(sh + (3,), 200, np.uint8); o[bodya] = rgb[bodya]
        o2 = np.full(sh + (3,), 200, np.uint8)
        for sd in arms:
            A = np.asarray(Image.open(f'{OUT}/arm_{sd}_{F}.png')).astype(np.float32); aa = A[..., 3:] / 255
            o2 = (A[..., :3] * aa + o2 * (1 - aa)).astype(np.uint8)
        Bw = np.asarray(Image.open(f'{OUT}/bow_hang_{F}.png')).astype(np.float32); aa = Bw[..., 3:] / 255
        o2 = (Bw[..., :3] * aa + o2 * (1 - aa)).astype(np.uint8)
        o3 = (o * 0.5).astype(np.uint8); o3[..., 0] = np.maximum(o3[..., 0], (wu * 255).astype(np.uint8)); o3[..., 1] = np.maximum(o3[..., 1], (wl * 255).astype(np.uint8))
        dbg[F] = np.hstack([o[0:720, 260:880], o2[0:720, 260:880], o3[0:720, 260:880]])

if __name__ == '__main__':
    dbg = {}
    for F in 'SE': cut(F, dbg)
    if len(sys.argv) > 1: Image.fromarray(np.vstack([dbg['S'], dbg['E']])).save(sys.argv[1])
