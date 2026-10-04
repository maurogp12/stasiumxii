"""Ironjaw v7 method, upper body: cut the APPROVED look target into layers (Mauro approved 4 Oct) with polygons
(target px) intersected with the approved binary alpha. Articulated parts (arms, belt/tassets/tabard, legs) come from
the painted part sheets instead and are rigged on the blockout joints; their target pixels are removed here.
Under the removed near arm the cape is filled (cv2 inpaint) so the cape reads continuous behind the rigged arm.
Writes <out>/T{F}_{layer}.png (RGBA, cropped) + target_layers.json (crop origin, polygons)."""
import json, os, sys, numpy as np, cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
T = '/workspace/handoff/class_walk_blockouts/targets/'
OUT = os.environ.get('BASTION_PARTS', '/workspace/scratch/b2/parts/')
POLY = {
 'S': {
  'trunk':   [(545, 0), (840, 0), (840, 198), (800, 205), (768, 212), (768, 302), (600, 302), (600, 205), (545, 205)],
  'R_pauld': [(536, 80), (642, 80), (642, 212), (600, 214), (536, 206)],
  'shield':  [(757, 214), (800, 203), (925, 185), (935, 330), (870, 470), (845, 470), (757, 360)],
  'cape':    [(230, 125), (560, 125), (600, 200), (606, 330), (595, 470), (565, 560), (230, 560)],
  'helm':    [(640, 0), (765, 0), (765, 88), (746, 96), (738, 128), (662, 128), (655, 96), (640, 88)],   # removed: painted 3/4 helm replaces it (head faces travel)
  'cape_r':  [(768, 300), (818, 300), (822, 485), (768, 485)],
  'arm':     [(545, 195), (600, 205), (600, 300), (572, 332), (562, 398), (522, 412), (502, 470), (506, 525), (482, 610), (378, 610), (378, 488), (430, 468), (468, 428), (488, 380), (490, 300), (503, 240), (518, 200)],
 }}
FILL_MAX_Y = {'S': 478}; FILL_FULL_Y = {'S': 400}
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
def ps_nearest(src, reg):
    _, (iy, ix) = ndi.distance_transform_edt(~src, return_indices=True); return reg[iy, ix]     # cape continues behind the removed arm down to here (the mace head below is not cape)
def pmask(shape, poly):
    im = Image.new('L', (shape[1], shape[0]), 0); ImageDraw.Draw(im).polygon([tuple(p) for p in poly], fill=1); return np.asarray(im) > 0
def save(name, rgb, m):
    ys, xs = np.nonzero(m); x0, y0 = int(xs.min()), int(ys.min()); x1, y1 = int(xs.max()) + 1, int(ys.max()) + 1
    out = np.zeros((y1 - y0, x1 - x0, 4), np.uint8); sub = m[y0:y1, x0:x1]
    out[..., :3] = np.where(sub[..., None], rgb[y0:y1, x0:x1], 0); out[..., 3] = sub * 255
    Image.fromarray(out).save(OUT + name + '.png'); return [x0, y0]
info = {}
for F, PP in POLY.items():
    rgb = np.asarray(Image.open(T + f'bastion_rp_{F}_f00.jpg').convert('RGB')).copy()
    al = np.asarray(Image.open(T + f'bastion_rp_{F}_f00_alpha.png').convert('L')) > 127
    M = {k: pmask(al.shape, v) & al for k, v in PP.items()}
    sh = M['shield']; rp = M['R_pauld'] & ~sh
    trunk = M['trunk'] & ~sh & ~rp & ~M['helm']
    arm = M['arm'] & ~trunk & ~rp
    cape = M['cape'] & ~trunk & ~rp & ~sh
    yy = np.indices(al.shape)[0]
    cape0 = cape & ~arm
    # cape behind the removed arm: only where the cape closes around it (no stalk where the mace handle crossed a gap)
    closed = ndi.binary_closing(cape0, structure=np.ones((3, 3)), iterations=30) | (yy < FILL_FULL_Y[F])
    fill = arm & closed & (yy < FILL_MAX_Y[F])
    fill = fill | (ndi.binary_closing(fill, structure=np.ones((3, 3)), iterations=4) & arm & (yy < FILL_MAX_Y[F]))
    cape = cape0 | fill
    crgb = rgb.copy().astype(np.float32)
    # fill texture = the painted cape panel (body_S cape upper), Lab mean/std matched to the ring of target cape around the hole
    import lab34 as LB
    tile = np.asarray(Image.open(OUT + 'S_cape_u.png').convert('RGBA')); ta_ = tile[..., 3] > 0
    ring = ndi.binary_dilation(fill, iterations=25) & cape0
    ys, xs = np.nonzero(fill); y0, x0 = ys.min(), xs.min(); h, w = ys.max() - y0 + 1, xs.max() - x0 + 1
    sc = max(h / (tile.shape[0] * 0.8), w / (tile.shape[1] * 0.6))
    tl = cv2.resize(tile, None, fx=sc, fy=sc, interpolation=cv2.INTER_AREA)
    oy, ox = int(tl.shape[0] * 0.1), int(tl.shape[1] * 0.2)
    patch = tl[oy:oy + h, ox:ox + w].copy()
    _pm = patch[..., 3] > 0
    patch[..., :3] = ps_nearest(_pm, patch[..., :3]); patch[..., 3] = 255   # tile holes (ragged hem) -> nearest cloth
    lab_p = LB.rgb2lab(patch[..., :3]); lab_r = LB.rgb2lab(rgb)[ring]; pm = patch[..., 3] > 0
    for c in range(3):
        mu, sd = lab_p[..., c][pm].mean(), lab_p[..., c][pm].std() + 1e-3
        lab_p[..., c] = (lab_p[..., c] - mu) / sd * lab_r[:, c].std() + lab_r[:, c].mean()
    prgb = LB.lab2rgb(lab_p).astype(np.float32)
    sub = fill[y0:y0 + h, x0:x0 + w]
    # feather the seam: blend 6 px into the target cape around the hole
    dist = ndi.distance_transform_edt(sub)
    wgt = np.clip(dist / 6.0, 0, 1)[..., None]
    reg = crgb[y0:y0 + h, x0:x0 + w]
    near = ps_nearest(cape0[y0:y0 + h, x0:x0 + w], reg)
    reg[sub] = (prgb * wgt + near * (1 - wgt))[sub]
    crgb = np.clip(crgb, 0, 255).astype(np.uint8)
    # cut-edge clean: drop specks < 40 px per layer
    def clean(m):
        lab, n = ndi.label(m, np.ones((3, 3))); sz = np.bincount(lab.ravel()); sz[0] = 0
        return np.isin(lab, np.nonzero(sz >= 40)[0])
    info[F] = {}
    # near arm layer (rigged by lbs swing in build_hybrid): drop the blue cape slivers behind the arm (the cape layer
    # carries the filled cloth there), keep the biggest piece
    import lab34 as LB2
    labT = LB2.rgb2lab(rgb); blue = (labT[..., 2] < -4) & (-labT[..., 2] > np.abs(labT[..., 1]) * 1.2)
    blue = ndi.binary_opening(blue, iterations=1)
    arm_l = arm & ~sh & ~blue
    arm_l = ndi.binary_opening(arm_l, iterations=1)
    lab_, n_ = ndi.label(arm_l); sz_ = np.bincount(lab_.ravel()); sz_[0] = 0; arm_l = lab_ == sz_.argmax()
    arm_l = ndi.binary_fill_holes(arm_l) & arm & ~sh
    for name, m, src in (('trunk', trunk, rgb), ('R_pauld', rp, rgb), ('shield', sh, rgb), ('cape', cape, crgb), ('arm', arm_l, rgb)):
        m = clean(m); info[F][name] = dict(origin=save(f'T{F}_{name}', src, m), px=int(m.sum()))
    info[F]['fill_px'] = int(fill.sum())
    # debug overlay
    dbg = rgb.copy().astype(float)
    for m, c in ((trunk, (255, 0, 0)), (rp, (255, 160, 0)), (sh, (0, 255, 0)), (cape & ~fill, (0, 120, 255)), (fill, (255, 0, 255)), (arm & ~fill, (255, 255, 0))):
        dbg[m] = dbg[m] * 0.5 + np.array(c) * 0.5
    Image.fromarray(dbg.astype(np.uint8)).save(f'/workspace/scratch/b2/tlayers_{F}.png')
json.dump(dict(info=info, polygons=POLY), open(OUT + 'target_layers.json', 'w'), indent=1)
print(json.dumps(info))
