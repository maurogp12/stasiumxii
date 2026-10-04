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
sys.path.insert(0, '/workspace/scratch/ij_walk/v8')
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

def snap_cuts(rgb, al, red, A, C, cape, body, loin, tas, tasm, M, legs, H):
    """v8 (Claude #252: no box clips). Every hand polygon edge (arms, tassets, loincloth, body->cape, leg cut) is a straight
    line through the paint. In a band of +-R px round those edges the owner is re-decided by a marker watershed on the
    repaint colours, so the cut follows the painted silhouette (axe blade vs leg, gauntlet vs torso) instead of the box.
    Crimson stays cape (arms never take red), background stays background."""
    R = C.get('snap_r', 8)
    edges = np.zeros(H, np.uint8)
    for arm in A['arms']: cv2.polylines(edges, [np.int32(arm['poly'])], True, 1, 1)
    for t_ in (C.get('tas_list') or ([dict(poly=C['tas_poly'])] if C.get('tas_poly') else [])): cv2.polylines(edges, [np.int32(t_['poly'])], True, 1, 1)
    # (loin / body->cape / leg-cut polys are NOT snapped: they sit under the approved upper body / tassets and never move apart)
    band = (cv2.dilate(edges, np.ones((2 * R + 1, 2 * R + 1), np.uint8)) > 0) & al
    names = [a['name'] for a in A['arms']]
    labs = {}; mk = np.zeros(H, np.int32); M0 = {n_: M[n_].copy() for n_ in names}
    order = [(n_, M[n_]) for n_ in names] + [(f'tas{k}', m_) for k, m_ in enumerate(tasm)] + [('loin', loin), ('cape', cape), ('body', body), ('legs', al & legs & ~cape & ~body & ~loin & ~tas & ~np.any([M[n_] for n_ in names], 0))]
    for j, (n_, m_) in enumerate(order, 1):
        labs[n_] = j; mm_ = m_ & ~band
        if mm_.sum() < 0.3 * max(1, m_.sum()): mm_ = ndi.binary_erosion(m_, iterations=2)      # small parts (tassets): own core as marker
        mk[mm_ & (mk == 0)] = j
    mk[~al] = len(order) + 1
    ws = cv2.watershed(np.ascontiguousarray(rgb[..., :3].astype(np.uint8)), mk.copy())
    ws_fill = ws.copy(); b_ = ws_fill < 1
    if b_.any():      # watershed ridge px (-1) -> nearest label
        _, (iy, ix) = ndi.distance_transform_edt(b_, return_indices=True); ws_fill = ws_fill[iy, ix]
    new = {n_: (ws_fill == j) & al for n_, j in labs.items()}
    redc = red & ~loin
    for n_ in names:
        mm = new[n_] & ~redc
        # keep only the part connected to the arm's core (no stray islands across the band)
        lb, n = ndi.label(mm, np.ones((3, 3)))
        if n > 1:
            core = M[n_] & ~band; ids = np.unique(lb[core & mm]); ids = ids[ids > 0]; mm = np.isin(lb, ids)
        op_ = ndi.binary_opening(mm, np.ones((3, 3)), iterations=C.get('snap_open', 2))
        mm = mm & ~(band & ~op_ & ~M[n_]) & ~(band & ~op_ & mm & ~ndi.binary_erosion(M[n_] | ~band, iterations=1))   # no thin spikes / slivers grown into the band
        M[n_] = mm
    taken = np.any([M[n_] for n_ in names], 0)
    tasm = [new[f'tas{k}'] & ~red & ~taken for k in range(len(tasm))]
    tas = np.any(tasm, 0) if tasm else np.zeros(H, bool)
    loin = new['loin'] & red & ~taken if loin.any() else loin
    cape = cape | (band & (new['cape'] | (new['body'] & redc & ~loin)) & ~taken & ~tas & ~loin)      # cape never shrinks (approved)
    cape |= band & redc & ~taken & ~loin
    gain = band & new['body'] & ~redc & ~legs & ~body & ~taken & ~tas & ~loin & ~cape
    gain = ndi.binary_opening(gain, np.ones((3, 3)), iterations=2)       # no thin body slivers left behind where an arm swings away
    lb, n = ndi.label(gain); sz = ndi.sum(gain, lb, np.arange(1, n + 1)); gain = np.isin(lb, 1 + np.nonzero(np.asarray(sz) >= 40)[0])
    body = (body | gain) & ~taken & ~tas & ~loin & ~cape      # body only loses px to arms / tassets
    legs = (legs & ~band) | (band & (new['legs'] | legs) & ~taken & ~tas & ~loin & ~cape & ~body)
    orphan = al & ~(np.any([M[n_] for n_ in names], 0) | tas | loin | cape | body | legs)      # px nobody owns after the snap go back to their v7 arm
    for n_ in names: M[n_] = M[n_] | (orphan & M0[n_])
    return cape, body, loin, tas, tasm, M, legs

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
    if C.get('snap_cuts'):        # v8: polygon cut lines snap to the paint's own edges (watershed in a band round every poly edge)
        cape, body, loin, tas, tasm, M, legs = snap_cuts(rgb, al, red, A, C, cape, body, loin, tas, tasm, M, legs, H)
    if C.get('snap_legcut'):      # v8: the body's underside (straight leg-poly cut) snaps to the painted plate edge (body vs leg watershed)
        R2 = C['snap_legcut']; bl = body & al; ll = legs & al & ~cape & ~loin & ~tas
        edge = bl & ndi.binary_dilation(ll) | ll & ndi.binary_dilation(bl)
        lband = ndi.binary_dilation(edge, iterations=R2) & (bl | ll)
        mk2 = np.zeros(H, np.int32); mk2[bl & ~lband] = 1; mk2[ll & ~lband] = 2; mk2[~(bl | ll)] = 3
        ws2 = cv2.watershed(np.ascontiguousarray(rgb[..., :3].astype(np.uint8)), mk2)
        _, (iy, ix) = ndi.distance_transform_edt(ws2 < 1, return_indices=True); ws2 = ws2[iy, ix]
        nb = (bl & ~lband) | (lband & (ws2 == 1))
        lb_, n_ = ndi.label(nb); keep = np.unique(lb_[bl & ~lband]); nb = np.isin(lb_, keep[keep > 0])     # no detached body islands
        body = (body & ~lband) | (nb & lband); legs = (legs & ~lband) | (lband & ~body)
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
        if C.get('snap_cuts'):      # v8: smooth hem profile (the stepped per-column hem left vertical cut edges in the fill)
            hem = ndi.gaussian_filter1d(ndi.maximum_filter1d(hem, C.get('hem_win', 41)).astype(np.float64), 8)
        xl = np.full(H[0], 10 ** 6); xr = np.full(H[0], -1)
        for y in np.unique(ys): r = xs[ys == y]; xl[y], xr[y] = r.min(), r.max()
        span = (xx >= xl[:, None]) & (xx <= xr[:, None])
        occl = np.zeros(H, bool)
        if C.get('snap_cuts'):      # v8: cape fill behind each arm follows the arm's own silhouette (round dilation), not its box poly
            r_ = C.get('cape_fill_r', 14); ker = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r_ + 1, 2 * r_ + 1))
            for arm in A['arms']: occl |= cv2.dilate(M[arm['name']].astype(np.uint8), ker) > 0
        else:
            for arm in A['arms']: occl |= poly(H, arm['poly'])
        if not A['cape_front']: occl |= legs | loin
        if not A['cape_front']: occl |= body & (yy > C.get('cape_fill_body_y', 10 ** 6))
        if C.get('snap_cuts'):      # v8: no per-row span (it left horizontal slits and a vertical edge under the swinging arm)
            reach = ndi.distance_transform_edt(~cape) <= C.get('cape_fill_reach', 16)   # v8: never paint cape out into the axe blades
            occp = np.zeros(H, bool)
            for arm in A['arms']: occp |= poly(H, arm['poly'])
            want = occl & ~cape & (al | (span & occp)) & reach & (yy >= top) & (yy <= hem[None, :])     # open-air pockets stay open (as v7)
        else:
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
    FE = C.get('feather_px', 0)
    FEL = C.get('feather_layers')       # v8: which layers get the soft under-lap ring (None = all)
    def rgba(c, m, fi=0, into=None, nm=None):
        o = np.where(m[..., None], np.dstack([c, np.full(H, 255, np.uint8)]), 0).astype(np.uint8)
        if fi:       # v8: inner feather at CUT edges only (where the paint continues into another layer): alpha ramps 1 -> 0.3
            cut = m & ndi.binary_dilation(al & ~m if into is None else into) ; d_ = ndi.distance_transform_edt(~cut)
            ramp = np.clip(0.3 + 0.7 * d_ / fi, 0, 1); o[..., 3] = np.round(o[..., 3] * np.where(m, ramp, 1)).astype(np.uint8)
        if FE and (FEL is None or nm in FEL):       # v8: soft under-lap ring (real paint, alpha <= 0.45) past every cut edge: blends over the layer behind, never adds silhouette
            d_ = ndi.distance_transform_edt(~m); ring = (d_ > 0) & (d_ <= FE) & al
            o[ring, :3] = c[ring]; o[ring, 3] = np.round(115 * (1 - (d_[ring] - 1) / FE)).astype(np.uint8)
        return o
    L = {k: rgba(rgb, m, nm=k) for k, m in M.items()}
    L['cape'] = rgba(rgbc, capef); L['body'] = rgba(rgbb, bodyf & ~loin & ~tas, C.get('inner_feather', {}).get('body_legcut', 0), al & legs & ~bodyf)      # v8: soft body underside where it was cut from the source legs
    for k_, m_ in enumerate(tasm):
        if m_.any(): L[f'tas{k_}'] = rgba(rgb, m_, C.get('inner_feather', {}).get('tas', 0))
    if loin.any():
        lo_ = loin.copy()
        for d_ in range(1, C.get('loin_overlap', 0) + 1): lo_[:-d_] |= loin[d_:]          # loin overlaps 1-3 px upward so a lifted cape never opens a seam
        L['loin'] = rgba(rgb, lo_ & al & ~taken, C.get('inner_feather', {}).get('loin', 0))
    L['_masks'] = dict(cape=cape, capef=capef, body=body, loin=loin, legs=legs, tas=tas, **M)
    return L
