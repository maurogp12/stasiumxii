"""WP10a joins: graded region->Crosshaven blend autotiles, road-crossing pieces and (Rowanvale) dirt_road-on-meadow set.

Level model (min rule, Crosshaven autotile convention):
  every join cell gets a level L in {1,2,3}; region interior = 3, Crosshaven = 0 (L differs by <=1 between 8-neighbours).
  A cell's vertex is LOW (value L-1) when any of the 3 other cells sharing it has a lower level, else HIGH (value L).
  Region coverage c = (L - B) / 3, B = max of the low-feature ramps (side s lower: 1 - d_s; corner c low: (1-d_a)(1-d_b)),
  so c is bilinear-exact along every side and continuous across all neighbours.
  Material mask m = smoothstep(n - theta(c)) with n = one cell-periodic organic noise field shared by every piece.
  Composite is done at 2x and 1x on the REAL kit tiles (Crosshaven golden_plains_a, region base tiles), so the 0% side is
  pixel-identical to Crosshaven grass and the 100% side to the region tile.
Pieces (per join prefix P = meadow_join | snow_grass_join):
  P_l{L}_a/b/c          uniform L/3 coverage (L = 1, 2; L3 interior = the region tile itself)
  P_l{L}_edge_<sides>   15 per level: listed sides touch a LOWER level (toward Crosshaven)
  P_l{L}_corner_<c>     4 per level: decal (Crosshaven grass + alpha), draw after the floor
  P_road_l{L}_<low>_<part>  road-crossing: band lower side <low>; part = mid | edge_<grass sides> (road runs across the band)
  dirt_road_meadow_*    (Rowanvale only) Crosshaven dirt_road autotile set with meadow instead of grass, for the road
                        continuing into Rowanvale past the band.
"""
from __future__ import annotations
import json, sys, hashlib
from pathlib import Path
import numpy as np, cv2
from scipy.ndimage import map_coordinates
sys.path.insert(0, str(Path(__file__).parent))
import wp10a_tiles as T
from wp10a_common import SS, load_rgba, save_rgba, smoothstep, down_box

CH = Path('/workspace/stasium-repo/art/world/crosshaven/tiles')
PC = Path('/workspace/stasium-pc-look/ship')
SIDES = ('nw', 'ne', 'se', 'sw')
CORNERS = {'n': ('nw', 'ne'), 'e': ('ne', 'se'), 's': ('se', 'sw'), 'w': ('nw', 'sw')}
AXIS_OF_LOW = {'nw': 'x', 'se': 'x', 'ne': 'y', 'sw': 'y'}           # road runs across the band, along this world axis
ROAD_SIDES = {'x': ('ne', 'sw'), 'y': ('nw', 'se')}                   # sides of an x / y road that touch ground
SOFT = 0.045                                                           # mask edge softness (noise units)

JOINS = {
    'stoneford_rowanvale': dict(prefix='meadow_join', region='rowanvale', reg_tiles=['meadow_a', 'meadow_b', 'meadow_c'],
                                road_to=None, noise=dict(seed=11, beta=1.8, lo=3, detail=0.3), road_set='dirt_road_meadow'),
    'northgate_windmere': dict(prefix='snow_grass_join', region='windmere', reg_tiles=['snow_grass_a', 'snow_grass_b', 'snow_grass_c'],
                               road_to='white_flagstone', noise=dict(seed=23, beta=2.6, lo=2, detail=0.08), road_set=None),
}


# ------------------------------------------------------------------ noise
def periodic_noise(seed, beta=1.8, lo=1, hi=24, n=256, detail=0.4):
    """Cell-periodic (torus) noise, histogram-equalised to U(0,1). beta = spectral slope (higher = clumpier)."""
    rng = np.random.default_rng(seed)
    f = np.fft.fftfreq(n) * n
    fx, fy = np.meshgrid(f, f)
    r = np.hypot(fx, fy)
    amp = np.where((r >= lo) & (r <= hi), (np.maximum(r, 1) ** -beta), 0)
    amp += detail * np.where((r > hi * 0.6) & (r <= hi * 2.2), 1.0 / np.maximum(r, 1), 0) * (lo ** -beta) * lo * 0.25
    ph = rng.standard_normal((n, n)) + 1j * rng.standard_normal((n, n))
    z = np.real(np.fft.ifft2(amp * ph)).astype(np.float32)
    flat = np.sort(z.ravel())
    u = np.searchsorted(flat, z).astype(np.float32) / flat.size
    return u


def sample_noise(nz, xw, yw):
    p = nz.shape[0]
    return map_coordinates(nz, [yw * p - 0.5, xw * p - 0.5], order=1, mode='grid-wrap').astype(np.float32)


# ------------------------------------------------------------------ flagstone stones (torus labels)
def stone_labels(square_png, fix=False):
    """Label the stones of a cell-periodic flagstone swatch (joints = bluish/dark), wrap-aware. Returns (labels[v,u], cu, cv)."""
    tex, _ = T.prep_swatch(square_png, 0, fix)
    p = tex.shape[0]
    r, g, b = tex[..., 0], tex[..., 1], tex[..., 2]
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    joint = ((b - r) > 0.055) | (lum < np.percentile(lum, 8))
    stone = ~joint
    big = np.pad(stone, p // 8, mode='wrap').astype(np.uint8)
    big = cv2.morphologyEx(big, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
    big = cv2.erode(big, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)))
    core = big[p // 8:-p // 8, p // 8:-p // 8]
    n, lab = cv2.connectedComponents(core, connectivity=4)
    par = list(range(n))
    def f(a):
        while par[a] != a:
            par[a] = par[par[a]]; a = par[a]
        return a
    for a1, a2 in ((lab[:, 0], lab[:, -1]), (lab[0], lab[-1])):
        for i, j in zip(a1, a2):
            if i and j: par[f(i)] = f(j)
    lab = np.vectorize(lambda v: f(v) if v else 0)(lab) if n < 4000 else lab
    # drop specks, then give every pixel (joints too) the nearest stone label, wrap-aware
    ids, cnt = np.unique(lab[lab > 0], return_counts=True)
    small = ids[cnt < (p * p) * 0.002]
    lab[np.isin(lab, small)] = 0
    big = np.pad(lab, p // 8, mode='wrap')
    d, idx = cv2.distanceTransformWithLabels((big == 0).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
    ys, xs = np.nonzero(big == 0) if False else (None, None)
    nz = big > 0
    seeds = big[nz]
    lut = np.zeros(idx.max() + 1, np.int32)
    # label index -> seed pixel label (pixel labels enumerate zero pixels of the input = stone pixels, in raster order)
    lut[1:len(seeds) + 1] = seeds
    full = lut[idx][p // 8:-p // 8, p // 8:-p // 8]
    uids = np.unique(full)
    cu, cv_ = {}, {}
    vv, uu = np.indices(full.shape)
    for i in uids:
        m = full == i
        au = np.angle(np.exp(2j * np.pi * (uu[m] + 0.5) / p).mean()) / (2 * np.pi) % 1
        av = np.angle(np.exp(2j * np.pi * (vv[m] + 0.5) / p).mean()) / (2 * np.pi) % 1
        cu[int(i)], cv_[int(i)] = float(au), float(av)
    return full, cu, cv_


def flag_mask(labs, L, low, xw, yw, seed=5):
    """Whole-stone selection: stone shows when its random value beats theta(c at the stone centroid) (world-consistent)."""
    full, cu, cv_ = labs
    p = full.shape[0]
    rng = np.random.default_rng(seed)
    ids = np.array(sorted(cu)); rv = dict(zip(ids.tolist(), rng.random(len(ids)).tolist()))
    lab = full[(np.floor(yw * p).astype(int)) % p, (np.floor(xw * p).astype(int)) % p]
    CU = np.vectorize(cu.get)(lab); CV = np.vectorize(cv_.get)(lab); R = np.vectorize(rv.get)(lab)
    ur = CU + np.round(xw - CU); vr = CV + np.round(yw - CV)
    B = 1 - side_dist(low, ur, vr)                      # unclipped ramp: the linear field continues across cells
    c = np.clip((L - B) / 3.0, 0, 1)
    return (R > (1 - c) * 1.02 - 0.01).astype(np.float32)


# ------------------------------------------------------------------ coverage field
def side_dist(s, xw, yw):
    return {'nw': xw, 'ne': yw, 'se': 1 - xw, 'sw': 1 - yw}[s]


def low_B(xw, yw, sides=(), corners=()):
    B = np.zeros_like(xw)
    for s in sides:
        B = np.maximum(B, 1 - side_dist(s, xw, yw))
    for c in corners:
        a, b = CORNERS[c]
        B = np.maximum(B, (1 - side_dist(a, xw, yw)) * (1 - side_dist(b, xw, yw)))
    return np.clip(B, 0, 1)


def coverage(L, B):
    return np.clip((L - B) / 3.0, 0, 1)


def mask_from(c, n):
    th = (1 - c) * (1 + 2 * SOFT) - SOFT
    return smoothstep(-SOFT, SOFT, n - th)


def down_mask(m_ss):
    """SS mask -> (2x, 1x) by exact box average."""
    h, w = m_ss.shape
    m2 = m_ss.reshape(h // SS, SS, w // SS, SS).mean((1, 3))
    m1 = m_ss.reshape(h // (2 * SS), 2 * SS, w // (2 * SS), 2 * SS).mean((1, 3))
    return m2, m1


# ------------------------------------------------------------------ plate grade (Crosshaven plate samples, modest offsets)
PLATE = json.loads((Path(__file__).parent / 'src' / 'plate_samples.json').read_text())
def hexlab(hx):
    from wp10a_common import hex2rgb, to_lab
    return to_lab(hex2rgb(hx)[None, None])[0, 0]
def mixhex(*hs):
    from wp10a_common import hex2rgb
    return '#%02x%02x%02x' % tuple(np.round(np.mean([hex2rgb(h) for h in hs], 0) * 255).astype(int))
T_AB, T_L = 0.30, 0.15         # max fraction of the (target - layer mean) Lab offset applied (a/b, L)
GRASS_T = mixhex(PLATE['grass_yellow_green']['hex'], PLATE['grass_hay_gold']['hex'])
ROAD_T = PLATE['road_pale_cream']['hex']
SNOW_T = PLATE['stone_cliff_white']['hex']


_REF = {}
def ref_mean(name):
    """Fixed Lab mean of a reference kit tile (so every variant / piece gets the SAME offset and shared edges stay identical)."""
    from wp10a_common import to_lab
    if name not in _REF:
        root, tid = name.split(':')
        t = tile((CH if root == 'ch' else PC / root / 'tiles') / '_2x' / f'{tid}.png')
        a = t[..., 3] > 0.5
        _REF[name] = to_lab(t[..., :3])[a].mean(0)
    return _REF[name]


def grade(img, target_hex, strength, ref=None):
    """Offset the layer's Lab toward the target (texture kept): Lab += s * T * (target - mean(layer)). strength: HxW in [0,1]."""
    from wp10a_common import to_lab
    if np.max(strength) <= 0:
        return img
    out = img.copy()
    a = img[..., 3] > 0.5
    lab = to_lab(img[..., :3])
    mean = ref_mean(ref) if ref else (lab[a].mean(0) if a.any() else lab.reshape(-1, 3).mean(0))
    d = hexlab(target_hex) - mean
    off = np.array([T_L * d[0], T_AB * d[1], T_AB * d[2]], np.float32)
    lab2 = lab + strength[..., None] * off
    out[..., :3] = np.clip(cv2.cvtColor(lab2.astype(np.float32), cv2.COLOR_Lab2RGB), 0, 1)
    return out


def graded_pair(pair, target_hex, s2, s1, ref=None):
    return grade(pair[0], target_hex, s2, ref), grade(pair[1], target_hex, s1, ref)


# ------------------------------------------------------------------ tile IO
_TC = {}
def tile(path):
    if path not in _TC:
        _TC[path] = load_rgba(path)
    return _TC[path]


def kit_pair(root, name):
    return tile(Path(root) / '_2x' / f'{name}.png'), tile(Path(root) / f'{name}.png')


def lerp(a, b, m):
    return a * (1 - m[..., None]) + b * m[..., None]


def put(out, name, t2, t1):
    save_rgba(out / 'tiles' / '_2x' / f'{name}.png', t2)
    save_rgba(out / 'tiles' / f'{name}.png', t1)


def compose(base, top, m2, m1):
    """rgb lerp at 2x / 1x, alpha from the base (floor alpha)."""
    (b2, b1), (t2, t1) = base, top
    o2 = b2.copy(); o1 = b1.copy()
    o2[..., :3] = lerp(b2[..., :3], t2[..., :3], m2); o1[..., :3] = lerp(b1[..., :3], t1[..., :3], m1)
    return o2, o1


def edge_sets():
    return [[s for i, s in enumerate(SIDES) if m >> i & 1] for m in range(1, 16)]


# ------------------------------------------------------------------ road edge decomposition (Crosshaven pieces)
def grass_fit(E, G, R):
    """Per-pixel road fraction m_r on the line grass G -> road R (2x or 1x arrays), lightly smoothed."""
    d = R[..., :3] - G[..., :3]
    m = np.clip(((E[..., :3] - G[..., :3]) * d).sum(-1) / ((d * d).sum(-1) + 1e-6), 0, 1).astype(np.float32)
    k = 1.2 if E.shape[1] == 128 else 0.6
    return cv2.GaussianBlur(m, (0, 0), k)


FIT_G = {'nw': 'd', 'ne': 'b', 'nw_ne': 'd', 'se': 'f', 'nw_se': 'd', 'ne_se': 'b', 'nw_ne_se': 'd', 'sw': 'd', 'nw_sw': 'd',
         'ne_sw': 'd', 'nw_ne_sw': 'd', 'se_sw': 'd', 'nw_se_sw': 'd', 'ne_se_sw': 'd', 'nw_ne_se_sw': 'd'}


def lum(rgb):
    return rgb[..., :3] @ np.array([0.3, 0.59, 0.11], np.float32)


def regrass(E, G, REGt, w):
    """Replace the grass part of a Crosshaven road piece by region ground: lerp toward the region tile, carrying the painted
    lip shading over as a luminance ratio only (no hue leak from dirt pixels)."""
    k = np.clip(lum(E) / np.maximum(lum(G), 1e-3), 0.65, 1.2)[..., None]
    out = E.copy()
    out[..., :3] = lerp(E[..., :3], np.clip(REGt[..., :3] * k, 0, 1), w)
    return out


def road_edge_pair(sides_name):
    """Crosshaven dirt_road_edge_<sides>: (E2, E1), grass-fraction (g2, g1), fitted grass (G2, G1)."""
    E = kit_pair(CH, f'dirt_road_edge_{sides_name}')
    G = kit_pair(CH, f'golden_plains_{FIT_G[sides_name]}')
    R = kit_pair(CH, 'dirt_road_a')
    g = tuple(smoothstep(0.3, 0.85, 1 - grass_fit(e, gg, r)) for e, gg, r in zip(E, G, R))
    return E, g, G


# ------------------------------------------------------------------ build one join
def build_join(jid, out, log):
    J = JOINS[jid]; P = J['prefix']; out = Path(out)
    regdir = PC / f"wp10a_{J['region']}" / 'tiles'
    xw, yw = T.world_grid()
    nz = periodic_noise(J['noise']['seed'], J['noise']['beta'], J['noise']['lo'], detail=J['noise']['detail'])
    n0 = sample_noise(nz, xw, yw)
    win = T.edge_window(xw, yw, 0.08, 0.26)
    nvar = [n0] + [n0 * (1 - win) + sample_noise(periodic_noise(J['noise']['seed'] + 100 * k, J['noise']['beta'], J['noise']['lo'],
                                                                 detail=J['noise']['detail']), xw, yw) * win for k in (1, 2)]
    CHg = kit_pair(CH, 'golden_plains_a')
    REG = [kit_pair(regdir, t) for t in J['reg_tiles']]
    REG_T = SNOW_T if J['region'] == 'windmere' else GRASS_T
    GR, DR = 'ch:golden_plains_a', 'ch:dirt_road_a'
    RR = f"wp10a_{J['region']}:{J['reg_tiles'][0]}"
    FR = f"wp10a_{J['region']}:{J['road_to']}_a" if J['road_to'] else None
    pieces = []

    def rec(name, kind, **kw):
        pieces.append(dict(id=name, kind=kind, **kw))

    def blend(c, noise, k=0):
        c2, c1 = down_mask(c)
        chg = graded_pair(CHg, GRASS_T, c2, c1, GR)               # Crosshaven grass drifts toward the plate grass across the band
        rg = graded_pair(REG[k], REG_T, 1 - c2, 1 - c1, RR)         # region clumps near Crosshaven pulled toward the plate (0 at 100%)
        m2, m1 = down_mask(mask_from(c, noise))
        return compose(chg, rg, m2, m1)

    def road_base(pair, gfrac, c2, c1):
        """Crosshaven road piece graded: road part toward plate cream, grass part toward plate grass, both by c."""
        out = []
        for e, g, cc in zip(pair, gfrac, (c2, c1)):
            x = grade(e, ROAD_T, cc * (1 - g), DR)
            x = grade(x, GRASS_T, cc * g, GR) if np.any(g > 0) else x
            out.append(x)
        return out

    zero = np.zeros_like(xw)
    # ---- uniform interiors (L1, L2)
    for L in (1, 2):
        for k, v in enumerate('abc'):
            put(out, f'{P}_l{L}_{v}', *blend(coverage(L, zero), nvar[k], k))
            rec(f'{P}_l{L}_{v}', 'floor', level=L, coverage_pct=round(100 * L / 3), variant=v)
    # ---- edges + corners per level
    for L in (1, 2, 3):
        for sides in edge_sets():
            c = coverage(L, low_B(xw, yw, sides))
            nm = f"{P}_l{L}_edge_{'_'.join(sides)}"
            put(out, nm, *blend(c, n0)); rec(nm, 'floor', level=L, sides=sides, variant='a')
            if len(sides) == 1:          # straight band runs: 2 more edge-pinned variants so the run does not repeat every cell
                for k, v in ((1, 'b'), (2, 'c')):
                    put(out, f'{nm}_{v}', *blend(c, nvar[k], k))
                    rec(f'{nm}_{v}', 'floor', level=L, sides=sides, variant=v, variant_of=nm)
        for cn in CORNERS:
            ce = coverage(L, low_B(xw, yw, (), (cn,)))
            ML = mask_from(coverage(L, zero), n0)
            Mc = mask_from(ce, n0)
            w = np.clip((ML - Mc) / np.maximum(ML, 1e-3), 0, 1)
            w2, w1 = down_mask(w); c2, c1 = down_mask(ce)
            t2, t1 = graded_pair(CHg, GRASS_T, c2, c1, GR)
            t2 = t2.copy(); t1 = t1.copy(); t2[..., 3] *= w2; t1[..., 3] *= w1
            nm = f'{P}_l{L}_corner_{cn}'
            put(out, nm, t2, t1); rec(nm, 'decal', level=L, corner=cn)
    # ---- road-crossing pieces
    if J['road_to']:
        labs = stone_labels(str(Path(__file__).parent / 'src' / f"{J['road_to']}_square.png"))
        log.setdefault(jid + '_stones', len(labs[1]))
    for L in (1, 2, 3):
        for low in SIDES:
            ax = AXIS_OF_LOW[low]; a, b = ROAD_SIDES[ax]
            c = coverage(L, low_B(xw, yw, (low,)))
            c2, c1 = down_mask(c)
            m2, m1 = down_mask(mask_from(c, n0))
            rg = graded_pair(REG[0], REG_T, 1 - c2, 1 - c1, RR)
            for part, rs in (('mid', None), (f'edge_{a}', a), (f'edge_{b}', b), (f'edge_{a}_{b}', f'{a}_{b}')):
                if rs is None:
                    o2, o1 = road_base(kit_pair(CH, 'dirt_road_' + 'bcd'[L - 1]), (np.zeros((64, 128), np.float32), np.zeros((32, 64), np.float32)), c2, c1)
                else:
                    E, (g2, g1), (G2, G1) = road_edge_pair(rs)
                    E2, E1 = road_base(E, (g2, g1), c2, c1)
                    G2, G1 = graded_pair((G2, G1), GRASS_T, c2, c1, GR)
                    o2 = regrass(E2, G2, rg[0], g2 * m2); o1 = regrass(E1, G1, rg[1], g1 * m1)
                if J['road_to']:
                    F = kit_pair(regdir, f"{J['road_to']}_a" if rs is None else f"{J['road_to']}_edge_{rs}")
                    F = graded_pair(F, SNOW_T, 1 - c2, 1 - c1, FR)
                    f2, f1 = down_mask(flag_mask(labs, L, low, xw, yw))
                    o2, o1 = compose((o2, o1), F, f2, f1)
                nm = f'{P}_road_l{L}_{low}_{part}'
                put(out, nm, o2, o1)
                rec(nm, 'floor', level=L, band_low_side=low, road_axis=ax, road_part=part,
                    road_ground_sides=([] if rs is None else rs.split('_')))
    # ---- Rowanvale: Crosshaven dirt_road autotile set over meadow (road continues past the band; graded like c = 1)
    if J['road_set']:
        one2, one1 = np.ones((64, 128), np.float32), np.ones((32, 64), np.float32)
        for sides in edge_sets():
            sn = '_'.join(sides)
            E, (g2, g1), (G2, G1) = road_edge_pair(sn)
            E2, E1 = road_base(E, (g2, g1), one2, one1)
            G2, G1 = graded_pair((G2, G1), GRASS_T, one2, one1, GR)
            o2 = regrass(E2, G2, REG[0][0], g2); o1 = regrass(E1, G1, REG[0][1], g1)
            nm = f"{J['road_set']}_edge_{sn}"; put(out, nm, o2, o1); rec(nm, 'floor', sides=sides, road_set=True)
        for cc in CORNERS:
            D = kit_pair(CH, f'dirt_road_corner_{cc}')
            G = kit_pair(CH, 'golden_plains_a')
            o = []
            for d, gg, rgt in zip(D, G, REG[0]):
                o.append(regrass(d, gg, rgt, np.ones(d.shape[:2], np.float32)))
            nm = f"{J['road_set']}_corner_{cc}"; put(out, nm, *o); rec(nm, 'decal', corner=cc, road_set=True)
        # road interior past the band: Crosshaven dirt_road graded to c = 1 (pale)
        for v in 'abcd':
            o = [grade(t, ROAD_T, np.ones(t.shape[:2], np.float32), DR) for t in kit_pair(CH, f'dirt_road_{v}')]
            nm = f"{J['road_set']}_{v}"; put(out, nm, *o); rec(nm, 'floor', road_set=True, variant=v)
    log[jid] = dict(pieces=len(pieces))
    return pieces


if __name__ == '__main__':
    out_root = Path(sys.argv[1] if len(sys.argv) > 1 else '/workspace/stasium-pc-look/ship/wp10a_joins')
    only = sys.argv[2].split(',') if len(sys.argv) > 2 else list(JOINS)
    log = {}
    allp = {}
    for j in only:
        allp[j] = build_join(j, out_root / j, log)
        print(j, len(allp[j]), 'tiles')
    (Path(__file__).parent / 'tiles_index.json').write_text(json.dumps(allp, indent=1))
