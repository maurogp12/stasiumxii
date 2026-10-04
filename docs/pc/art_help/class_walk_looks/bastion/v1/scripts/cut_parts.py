"""Bastion v1: cut the painted part sheets (flat grey ~128) to RGBA parts.
Grey key = flood fill of near-background colour from the sheet border (tol 10), so steel highlights inside a part are
never keyed. Enclosed background pockets (> MIN_POCKET px, bg colour, low texture) are reported and keyed too.
Then: pick component by bbox hint, decontaminate a 2 px edge band from the interior, erode the 1 px fringe,
binary alpha, RGB=0 under alpha 0, edge_fix (process_sheet, from the Ironjaw rig)."""
import sys, os, json, numpy as np, cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import process_sheet as ps
SRC = '/workspace/handoff/class_walk_blockouts/bastion/parts_src/'
OUT = os.environ.get('BASTION_PARTS', '/workspace/scratch/bastion/parts/')
os.makedirs(OUT, exist_ok=True)
N8 = np.ones((3, 3), bool)
# name -> point inside the part's bbox (sheet px, 1280x720); the largest component whose bbox holds it is taken
SPEC = {
 'legs_S': {'S_thigh_fwd': (117, 330), 'S_thigh_down': (304, 340), 'S_thigh_back': (493, 340), 'S_kneecop': (650, 350),
            'S_greave': (808, 350), 'S_sabaton_a': (990, 400), 'S_sabaton_b': (1165, 400)},
 'arms_S': {'S_pauld_a': (307, 118), 'S_pauld_b': (625, 120), 'S_upper_a': (881, 123), 'S_upper_b': (304, 337),
            'S_elbowcop': (518, 350), 'S_mace': (739, 453), 'S_fist': (350, 560), 'S_shield': (980, 525)},
 'body_S': {'S_torso': (389, 295), 'S_belt': (648, 395), 'S_cape_u': (904, 342), 'S_cape_l': (1143, 390)},
 'helms_S_E': {'S_helm': (330, 340), 'E_helm': (948, 325)},
 'body_legs_E': {'E_torso': (177, 153), 'E_belt': (451, 198), 'E_cape_a': (763, 202), 'E_cape_b': (1094, 206),
                 'E_thigh_fwd': (165, 517), 'E_thigh_down': (425, 501), 'E_thigh_back': (688, 523), 'E_greave': (922, 529),
                 'E_sabaton': (1135, 531)},
 'arms_E': {'E_pauld_a': (307, 119), 'E_pauld_b': (626, 120), 'E_upper_a': (883, 122), 'E_upper_b': (301, 339),
            'E_elbowcop': (517, 353), 'E_mace': (740, 454), 'E_fist': (352, 559), 'E_shield_back': (983, 522)},
}
MIN_POCKET = 120
def fg_mask(rgb, tol=10):
    b = np.concatenate([rgb[:6].reshape(-1, 3), rgb[-6:].reshape(-1, 3), rgb[:, :6].reshape(-1, 3), rgb[:, -6:].reshape(-1, 3)])
    bg = np.median(b, 0); d = np.abs(rgb.astype(int) - bg).max(2)
    near = (d <= tol).astype(np.uint8)
    n, lab = cv2.connectedComponents(near, connectivity=4)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgm = np.isin(lab, list(border)) & (near > 0)
    # enclosed pockets of flat background colour (low local std) -> background too
    g = rgb.astype(np.float32).mean(2); sd = np.sqrt(np.maximum(cv2.blur(g * g, (5, 5)) - cv2.blur(g, (5, 5)) ** 2, 0))
    pockets = (near > 0) & ~bgm & (sd < 2.5)
    pl, pn = ndi.label(pockets); ps_ = np.bincount(pl.ravel()); keep = [i for i in range(1, pn + 1) if ps_[i] >= MIN_POCKET]
    pk = np.isin(pl, keep)
    fg = ~bgm & ~pk
    fg = ndi.binary_opening(fg, N8, iterations=1)
    return fg, bg, pk
info = {}
for sheet, parts in SPEC.items():
    rgb = np.asarray(Image.open(SRC + sheet + '.jpg').convert('RGB'))
    fg, bg, pk = fg_mask(rgb)
    lab, n = ndi.label(fg, N8); sz = np.bincount(lab.ravel()); sz[0] = 0
    objs = ndi.find_objects(lab)
    for name, (hx, hy) in parts.items():
        cand = [k for k in range(1, n + 1) if sz[k] > 2000 and objs[k - 1][1].start <= hx < objs[k - 1][1].stop and objs[k - 1][0].start <= hy < objs[k - 1][0].stop]
        k = max(cand, key=lambda k: sz[k]); c = lab == k
        near = ndi.binary_dilation(c, N8, iterations=4)            # ragged hem tatters / loose specks
        for j in np.unique(lab[near & (lab != k) & (lab > 0)]):
            if sz[j] < 2000: c |= lab == j
        c = ndi.binary_fill_holes(c) & ~pk if True else c          # fill pin-holes; true bg pockets stay out
        ys, xs = np.nonzero(c); x0, x1, y0, y1 = max(xs.min() - 4, 0), xs.max() + 5, max(ys.min() - 4, 0), ys.max() + 5
        sub = rgb[y0:y1, x0:x1].astype(np.float32); cm = c[y0:y1, x0:x1]
        clean = ps.decontaminate_src(sub, cm, 2)
        cm2 = ndi.binary_erosion(cm, N8, iterations=1)
        out = np.zeros(cm.shape + (4,), np.uint8)
        out[..., :3] = np.where(cm2[..., None], np.round(clean), 0).astype(np.uint8); out[..., 3] = cm2 * 255
        out, nfix = ps.edge_fix(out)
        Image.fromarray(out).save(OUT + name + '.png')
        info[name] = dict(sheet=sheet, origin=[int(x0), int(y0)], size=[int(out.shape[1]), int(out.shape[0])], px=int(cm2.sum()),
                          pockets_keyed=int((pk[y0:y1, x0:x1] & ndi.binary_fill_holes(cm)).sum()), edge_fix=int(nfix))
        g = Image.new('RGB', (out.shape[1], out.shape[0]), (255, 0, 255)); g.paste(Image.fromarray(out[..., :3]), mask=Image.fromarray(out[..., 3]))
        d = ImageDraw.Draw(g)
        for x in range(0, out.shape[1], 20):
            d.line([(x, 0), (x, 3 if x % 100 else 8)], fill=(255, 255, 0))
        for y in range(0, out.shape[0], 20):
            d.line([(0, y), (3 if y % 100 else 8, y)], fill=(255, 255, 0))
        g.save(OUT + 'grid_' + name + '.png')
json.dump(info, open(OUT + 'cut_info.json', 'w'), indent=1)
for k, v in info.items(): print(k, v)
