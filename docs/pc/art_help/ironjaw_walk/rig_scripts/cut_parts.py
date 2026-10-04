"""Cut painted parts (white bg) to RGBA: key, median, drop specks, fill tiny holes,
decontaminate 2 px edge band from interior, erode 1 px fringe, alpha 0/255, RGB=0 under alpha 0."""
import sys, json, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
sys.path.insert(0, '/workspace/scratch/ij_walk/rig/lib')
import process_sheet as ps
P = '/workspace/scratch/ij_walk/parts/'
OUT = '/workspace/scratch/ij_walk/rig/parts/'
N8 = np.ones((3, 3), bool)
# name -> (sheet, bbox-centre hint)  (component chosen = largest comp whose bbox contains the hint)
SPEC = {
 'S': {'sheet': 'parts_S_try1.jpg', 'parts': {
    'torso': (280, 250), 'cape': (580, 200), 'thigh_a': (200, 580), 'thigh_b': (356, 580),
    'shin_a': (511, 570), 'shin_b': (631, 570), 'boot_a': (828, 620), 'boot_b': (1020, 620)}},
 'E': {'sheet': 'parts_E_try1.jpg', 'parts': {
    'torso': (256, 250), 'cape': (605, 200), 'thigh_a': (193, 590), 'thigh_b': (334, 590),
    'shin_a': (517, 596), 'shin_b': (644, 594), 'boot_a': (850, 590), 'boot_b': (1055, 595)}},
 'Sarm': {'sheet': 'arms_axe_S.jpg', 'parts': {
    'upper_a': (166, 330), 'upper_b': (416, 320), 'fore_a': (560, 120), 'fore_b': (760, 80)}},
 'fix': {'sheet': 'parts_fix1.jpg', 'parts': {
    'upper_A': (128, 207), 'upper_B': (293, 208), 'upper_C': (518, 207), 'upper_D': (689, 208),
    'boot_E': (343, 560), 'boot_F': (573, 548), 'cape': (1049, 371)}},
 'Earm': {'sheet': 'arms_axe_E.jpg', 'parts': {
    'upper_a': (162, 330), 'upper_b': (423, 320), 'fore_a': (580, 120), 'fore_b': (790, 80)}},
}
def keymask(rgb, thr=40):
    m = (765 - rgb.astype(np.int32).sum(2)) > thr
    return ndi.median_filter(m.astype(np.uint8), 3) > 0
def cut(sheet):
    rgb = np.asarray(Image.open(P + sheet).convert('RGB'))
    m = keymask(rgb)
    lab, n = ndi.label(m, N8)
    return rgb, m, lab
info = {}
for fac, sp in SPEC.items():
    rgb, m, lab = cut(sp['sheet'])
    sz = np.bincount(lab.ravel()); sz[0] = 0
    for name, (hx, hy) in sp['parts'].items():
        # component containing hint, else nearest big component
        k = lab[hy, hx]
        if k == 0 or sz[k] < 2000:
            d, (iy, ix) = ndi.distance_transform_edt(lab == 0, return_indices=True)
            k = lab[iy[hy, hx], ix[hy, hx]]
        c = lab == k
        # attach small nearby specks (<2000 px within 6 px) e.g. cape tatters
        near = ndi.binary_dilation(c, N8, iterations=6)
        for j in np.unique(lab[near & (lab != k) & (lab > 0)]):
            if sz[j] < 2000: c |= lab == j
        # fill tiny holes (< 25 px) only
        holes = ndi.binary_fill_holes(c) & ~c
        hl, hn = ndi.label(holes)
        hs = np.bincount(hl.ravel()); small = np.isin(hl, [i for i in range(1, hn + 1) if hs[i] < 25])
        c0 = c.copy(); c |= small
        ys, xs = np.nonzero(c); x0, x1, y0, y1 = xs.min() - 4, xs.max() + 5, ys.min() - 4, ys.max() + 5
        x0, y0 = max(x0, 0), max(y0, 0)
        sub = rgb[y0:y1, x0:x1].astype(np.float32); cm = c[y0:y1, x0:x1]
        clean = ps.decontaminate_src(sub, cm, 2)
        hole = small[y0:y1, x0:x1]
        if hole.any():   # filled pin-holes: recolour from the nearest real (non-hole) painted px, never keep the white
            core = c0[y0:y1, x0:x1] & ~ndi.binary_dilation(hole, N8, iterations=1)
            iy, ix = ps.nearest_index(core)
            clean[hole] = clean[iy[hole], ix[hole]]
        # pale specks inside crimson cloth = JPEG-white pin-holes that survived the key: recolour from the cloth around
        sys.path.insert(0, '/workspace/scratch/ij_walk/rig/lib'); import lab34 as LB
        Lm = 0.299 * clean[..., 0] + 0.587 * clean[..., 1] + 0.114 * clean[..., 2]
        sat = clean.max(-1) - clean.min(-1)
        pale = cm & (Lm > 120) & (sat < 45)
        if name not in ('cape', 'torso'): pale[:] = False
        if name == 'torso': pale[:int(0.62 * pale.shape[0])] = False   # skirt cloth only
        bl, bn = ndi.label(pale, N8); labc = LB.rgb2lab(np.clip(clean, 0, 255).astype(np.uint8))
        chroma = np.hypot(labc[..., 1], labc[..., 2]); hue = np.degrees(np.arctan2(labc[..., 2], labc[..., 1]))
        speck = np.zeros_like(cm)
        for j, sl in enumerate(ndi.find_objects(bl), 1):
            b = bl == j
            if b.sum() > 120: continue
            ring = ndi.binary_dilation(b, N8, iterations=2) & cm & ~pale
            if ring.sum() < 4: continue
            if name == 'cape' or (np.median(chroma[ring]) > 13 and -10 < np.median(hue[ring]) < 45):
                speck |= ndi.binary_dilation(b, N8, iterations=2 if name == 'cape' else 1) & cm
        if speck.any():
            src = cm & ~speck & ~pale
            iy, ix = ps.nearest_index(src); clean[speck] = clean[iy[speck], ix[speck]]
        nspeck = int(speck.sum())
        cm2 = ndi.binary_erosion(cm, N8, iterations=1)      # erode 1 px fringe
        out = np.zeros(cm.shape + (4,), np.uint8)
        out[..., :3] = np.where(cm2[..., None], np.round(clean), 0).astype(np.uint8)
        out[..., 3] = cm2 * 255
        out, nfix = ps.edge_fix(out)
        key = f'{fac}_{name}'
        Image.fromarray(out).save(OUT + key + '.png')
        info[key] = dict(sheet=sp['sheet'], origin=[int(x0), int(y0)], size=[int(out.shape[1]), int(out.shape[0])],
                         px=int(cm2.sum()), edge_fix=nfix, pinholes_filled=int(small.sum()), cloth_specks_recoloured=nspeck)
        # grid preview
        g = Image.new('RGB', (out.shape[1], out.shape[0]), (255, 255, 255)); g.paste(Image.fromarray(out[..., :3]), mask=Image.fromarray(out[..., 3]))
        sc = 2 if max(out.shape[:2]) < 300 else 1
        g = g.resize((g.width * sc, g.height * sc), Image.NEAREST); d = ImageDraw.Draw(g)
        for x in range(0, out.shape[1], 20):
            d.line([(x * sc, 0), (x * sc, g.height)], fill=(0, 160, 255) if x % 100 else (255, 0, 0), width=1)
            if x % 100 == 0: d.text((x * sc + 2, 2), str(x), fill=(255, 0, 0))
        for y in range(0, out.shape[0], 20):
            d.line([(0, y * sc), (g.width, y * sc)], fill=(0, 160, 255) if y % 100 else (255, 0, 0), width=1)
            if y % 100 == 0: d.text((2, y * sc + 2), str(y), fill=(255, 0, 0))
        g.save(OUT + 'grid_' + key + '.png')
json.dump(info, open(OUT + 'cut_info.json', 'w'), indent=1)
print(json.dumps(info, indent=0))
