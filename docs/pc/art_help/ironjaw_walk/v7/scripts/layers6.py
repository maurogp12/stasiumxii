"""Upper-body layer cut for the v4 walk (extends claude_proto.layers):
cape = crimson (Lab a*>th, a*>1.2 b*) closed 9x9 + interior holes + dark strand tips below cape_y + loose dark cape bits
(body pieces not connected to the torso); loincloth (crimson inside loin_poly) stays with the body, squashed to loin_len;
arms = ANN polygons minus crimson; body = rest minus the repaint legs below the leg cut line.
Hidden zones that the swing / sway / new legs can uncover are inpainted: cape behind arms, legs and loincloth;
(E) body behind the cape."""
import sys, json, numpy as np, cv2
from scipy import ndimage as ndi
sys.path.insert(0, '/workspace/handoff/ironjaw_walk_claude/claude_reply/scripts')
from cut import cut_target
sys.path.insert(0, '/workspace/scratch/ij_walk/v4c')
import claude_proto as CP
sys.path.insert(0, '/workspace/scratch/ij_walk/v7')
from pockets import find_pockets
OLD_T = '/workspace/scratch/ij_walk/repaint/rp_{F}_f00_t1.jpg'

def poly(shape, pts):
    m = np.zeros(shape, np.uint8); cv2.fillPoly(m, [np.int32(pts)], 1); return m > 0

def inpaint_fill(rgb, have, want, r=6, scale=0.5):
    """fill `want` px from `have` px colours (Telea at half res + a little texture from the source)."""
    h, w = have.shape
    small = cv2.resize(rgb, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    hs = cv2.resize(have.astype(np.uint8), small.shape[1::-1], interpolation=cv2.INTER_NEAREST) > 0
    src = small.copy(); src[~hs] = 0
    filled = cv2.inpaint(src, (~hs).astype(np.uint8), r, cv2.INPAINT_TELEA)
    up = cv2.resize(filled, (w, h), interpolation=cv2.INTER_CUBIC)
    # texture: vertical-fibre noise at the source's high-pass level (cloth grain instead of a flat smear)
    hp = rgb.astype(np.float32) - cv2.GaussianBlur(rgb.astype(np.float32), (0, 0), 3)
    sd = float(hp[have].std()) if have.any() else 6.0
    rng = np.random.default_rng(7); nz = rng.normal(0, 1, (h, w)).astype(np.float32)
    nz = cv2.GaussianBlur(nz, (0, 0), sigmaX=0.8, sigmaY=4.0); nz *= sd * 0.8 / max(nz.std(), 1e-3)
    tex = np.repeat(nz[..., None], 3, -1)
    out = rgb.copy().astype(np.float32); out[want] = np.clip(up.astype(np.float32)[want] + tex[want], 0, 255)
    return out.astype(np.uint8)

def leg_mask(H, C):
    if C.get('leg_polys'):
        m = np.zeros(H, bool)
        for p in C['leg_polys']: m |= poly(H, p)
        return m
    return poly(H, C['leg_poly'])

def red_mask(rgb, al, C):
    H = rgb.shape[:2]; yy = np.mgrid[0:H[0], 0:H[1]][0]
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(int); a_, b_ = lab[..., 1] - 128, lab[..., 2] - 128
    red = (a_ > C['red_th']) & (a_ > b_ * 1.2) & (yy > C['red_ymin'])
    return red & al

def target_leg_pixels(F, C):
    rgb, al, _ = cut_target(C.get('target') or OLD_T.format(F=F)); H = rgb.shape[:2]
    m = leg_mask(H, C) & al & ~ndi.binary_dilation(red_mask(rgb, al, C), iterations=2)
    return rgb, ndi.binary_erosion(m, iterations=2)

def layers(F, C):
    A = C.get('ann') or CP.ANN[F]
    rgb, al, bgc = cut_target(C.get('target') or OLD_T.format(F=F))
    if C.get('clear_pockets', True):      # enclosed backdrop pockets (axe crescent, arm/torso slit) are open air in the repaint
        pk_, _ = find_pockets(rgb, al, bgc); al = al & ~pk_
    H = rgb.shape[:2]; yy, xx = np.mgrid[0:H[0], 0:H[1]]
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(int); a_, b_ = lab[..., 1] - 128, lab[..., 2] - 128
    red = (a_ > C['red_th']) & (a_ > b_ * 1.2) & (yy > C['red_ymin'])
    red = cv2.morphologyEx(red.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8)) > 0
    red &= al
    red = ndi.binary_fill_holes(red) & al
    legs = leg_mask(H, C)
    loin = poly(H, C['loin_poly']) & red if C.get('loin_poly') else np.zeros(H, bool)
    low = al & (yy > A['cape_y']) & ~legs
    taken = np.zeros(H, bool); M = {}
    for arm in A['arms']:
        m = poly(H, arm['poly']) & al & ~(red & ~loin) & ~taken
        if C.get('arm_keep_low', True): pass
        taken |= m; M[arm['name']] = m
    TL = C.get('tas_list') or ([dict(poly=C['tas_poly'], side=C.get('tas_side', 'R'))] if C.get('tas_poly') else [])
    tasm = [poly(H, t_['poly']) & al & ~red & ~taken for t_ in TL]        # v7: tasset plates hang from the belt (BODY, own swing)
    tas = np.zeros(H, bool)
    for m_ in tasm: tas |= m_
    legs &= ~tas; low &= ~tas
    cape = ((red & ~loin) if not A['cape_front'] else (red & (yy > 120))) | (low & ~loin)
    cape &= ~taken
    body = al & ~taken & ~cape & ~(legs & ~red)
    if C.get('body_to_cape_poly'):       # v7: dark shadow between cape strands at the far hip -> cape (behind the legs), no flat body cut
        bc_ = body & poly(H, C['body_to_cape_poly']); body &= ~bc_; cape |= bc_
    # loose body pieces (dark cape folds etc.) not connected to the torso -> cape
    lb, n = ndi.label(body, np.ones((3, 3)))
    if n > 1:
        sz = np.bincount(lb.ravel()); sz[0] = 0; main = sz.argmax()
        ly = ndi.mean(yy, lb, index=np.arange(n + 1))       # only low pieces are cape folds; the helm / flank plates stay body
        lowc = np.nonzero(np.asarray(ly) > C.get('loose_ymin', 0))[0]
        loose = body & (lb != main) & np.isin(lb, lowc); cape |= loose; body &= ~loose
    # ---- hidden-zone fills
    capef = cape.copy()
    ys, xs = np.nonzero(cape)
    if C.get('fill_cape', True):
        # cape span per row and hem profile per column
        top = A['cape']['top']
        colbot = np.full(H[1], -1); cb = np.where(cape.any(0))[0]
        for x in cb: colbot[x] = np.nonzero(cape[:, x])[0].max()
        good = colbot >= 0
        hem = np.interp(np.arange(H[1]), np.nonzero(good)[0], colbot[good])
        hem = ndi.minimum_filter1d(hem, 9)
        xl = np.full(H[0], 10 ** 6); xr = np.full(H[0], -1)
        for y in np.unique(ys): r = xs[ys == y]; xl[y], xr[y] = r.min(), r.max()
        span = (xx >= xl[:, None]) & (xx <= xr[:, None])
        occl = np.zeros(H, bool)
        for arm in A['arms']: occl |= poly(H, arm['poly'])
        if not A['cape_front']: occl |= legs | loin
        if not A['cape_front']: occl |= body & (yy > C.get('cape_fill_body_y', 10 ** 6))
        want = occl & ~cape & span & (yy >= top) & (yy <= hem[None, :])
        rgbc = inpaint_fill(rgb, cape, want)
        capef = cape | want
    else:
        rgbc = rgb
    bodyf = body.copy(); rgbb = rgb
    if A['cape_front'] and C.get('fill_body_behind_cape', True):
        # E: body (back plate / belt) behind the cape, so a lifted / swayed cape never shows background
        torso = poly(H, C['torso_poly'])
        want = torso & cape & ~body & ~taken
        rgbb = inpaint_fill(rgb, body & torso, want); bodyf = body | want
    def rgba(c, m): return np.where(m[..., None], np.dstack([c, np.full(H, 255, np.uint8)]), 0).astype(np.uint8)
    L = {k: rgba(rgb, m) for k, m in M.items()}
    L['cape'] = rgba(rgbc, capef); L['body'] = rgba(rgbb, bodyf & ~loin & ~tas)
    for k_, m_ in enumerate(tasm):
        if m_.any(): L[f'tas{k_}'] = rgba(rgb, m_)
    if loin.any():
        lo_ = loin.copy()
        for d_ in range(1, C.get('loin_overlap', 0) + 1): lo_[:-d_] |= loin[d_:]          # loin overlaps 1-3 px upward so a lifted cape never opens a seam
        L['loin'] = rgba(rgb, lo_ & al & ~taken)
    L['_masks'] = dict(cape=cape, capef=capef, body=body, loin=loin, legs=legs, tas=tas, **M)
    return L
