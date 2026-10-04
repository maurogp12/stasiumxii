"""E target layers (Ironjaw v7 method, see cut_target_layers.py for S): cut Mauro's approved E look target into
cape / trunk / R_pauld / arm (R arm + mace, lbs+IK rigged) / shield / tasset; the target legs are dropped (painted
legs on the blockout joints replace them). Cape = the blue cloth region + its gold/ragged hem (colour + distance band),
hem over the far leg carved ragged (removal only, no new paint). Writes TE_*.png and merges into target_layers.json."""
import json, os, sys, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lab34 as LB
T = '/workspace/handoff/class_walk_blockouts/targets/'
OUT = os.environ.get('BASTION_PARTS', '/workspace/scratch/bastion/parts/')
X0 = 250   # polygons below are written in crop px (target x - 250)
POLY = {
 'R_pauld': [(372, 98), (440, 92), (500, 160), (500, 205), (432, 212), (378, 190)],
 'arm':     [(428, 168), (502, 160), (535, 232), (565, 288), (595, 335), (700, 425), (820, 430), (820, 570), (700, 570), (636, 474),
             (560, 405), (515, 395), (468, 352), (474, 318), (505, 318), (495, 268), (466, 228), (428, 214)],
 'shield':  [(80, 230), (195, 190), (200, 260), (185, 420), (130, 420), (80, 340)],
 'tasset':  [(398, 292), (472, 286), (490, 388), (408, 398)],
 'Rleg':    [(398, 386), (488, 380), (580, 470), (590, 720), (420, 720), (396, 470)],
 'helm':    [(320, 0), (415, 0), (415, 86), (406, 96), (400, 108), (332, 108), (328, 96), (320, 86)],   # removed: painted back helm, mirrored to face up-right
 'Lleg':    [(150, 540), (310, 540), (310, 720), (150, 720)],
}
rgb = np.asarray(Image.open(T + 'bastion_rp_E_f00.jpg').convert('RGB')); al = np.asarray(Image.open(T + 'bastion_rp_E_f00_alpha.png').convert('L')) > 127
H, W = al.shape; yy, xx = np.indices(al.shape)
def pm(poly):
    im = Image.new('L', (W, H), 0); ImageDraw.Draw(im).polygon([(x + X0, y) for x, y in poly], fill=1); return np.asarray(im) > 0
lab = LB.rgb2lab(rgb)
blue = (lab[..., 2] < -4) & (-lab[..., 2] > np.abs(lab[..., 1]) * 1.2) & al
gold = (lab[..., 2] > 12) & (lab[..., 0] > 30) & al
b2 = ndi.binary_opening(blue, iterations=2); lb, _ = ndi.label(b2); sz = np.bincount(lb.ravel()); sz[0] = 0
c = ndi.binary_fill_holes(ndi.binary_closing(lb == sz.argmax(), iterations=6)) & al
near = ndi.binary_dilation(c, iterations=10)
cape = c | (gold & near & (yy > 200)) | (ndi.binary_dilation(blue, iterations=1) & near & ~ndi.binary_opening(blue, iterations=2) & (yy > 200))
cape = ndi.binary_fill_holes(ndi.binary_closing(cape, iterations=2)) & al
dist = ndi.distance_transform_edt(~cape)
lleg = pm([(160, 560), (300, 560), (300, 720), (160, 720)])
hem = al & (dist <= 75) & (yy > 430) & (xx < 652) & ~lleg
clothy = ((lab[..., 2] < -2) & (-lab[..., 2] > np.abs(lab[..., 1]))) | gold
c3 = ndi.binary_fill_holes(cape | hem) & al
tips = ndi.binary_opening(lleg & al & clothy & (yy < 640), iterations=1)
l2, _ = ndi.label(tips | c3); tips &= np.isin(l2, np.unique(l2[c3]))
cape = ndi.binary_fill_holes(c3 | tips) & al
cape &= ~((cape & ~ndi.binary_opening(cape, iterations=2)) & lleg)
tooth = 560 - 12 * np.abs(((xx - 400) / 11.0) % 2 - 1) ** 1.5 - 3 * np.sin(xx * 0.37)
cape &= ~((xx >= 410) & (xx <= 550) & (yy > tooth) & (yy <= 562))
M = {k: pm(v) & al for k, v in POLY.items()}
shield = M['shield'] & ~cape
rp = M['R_pauld'] & ~cape
arm = M['arm'] & ~cape & ~rp
tas = M['tasset'] & ~cape & ~arm
legs = (M['Rleg'] | M['Lleg']) & ~cape & ~arm & ~tas
trunk = al & ~cape & ~shield & ~rp & ~arm & ~tas & ~legs & ~M['helm']
def clean(m, keep_big=False):
    l, n = ndi.label(m, np.ones((3, 3))); s = np.bincount(l.ravel()); s[0] = 0
    return (l == s.argmax()) if keep_big else np.isin(l, np.nonzero(s >= 40)[0])
def save(name, m):
    ys, xs = np.nonzero(m); x0, y0 = int(xs.min()), int(ys.min()); x1, y1 = int(xs.max()) + 1, int(ys.max()) + 1
    out = np.zeros((y1 - y0, x1 - x0, 4), np.uint8); sub = m[y0:y1, x0:x1]
    out[..., :3] = np.where(sub[..., None], rgb[y0:y1, x0:x1], 0); out[..., 3] = sub * 255
    Image.fromarray(out).save(OUT + f'TE_{name}.png'); return [x0, y0]
info = {}
for name, m, kb in (('trunk', trunk, False), ('R_pauld', rp, True), ('shield', shield, True), ('cape', cape, True), ('arm', arm, True), ('tasset', tas, True)):
    m = clean(m, kb); info[name] = dict(origin=save(name, m), px=int(m.sum()))
info['legs_dropped_px'] = int(legs.sum())
dbg = rgb.astype(float).copy()
for m, col in ((trunk, (255, 0, 0)), (rp, (255, 160, 0)), (shield, (0, 255, 0)), (cape, (0, 120, 255)), (arm, (255, 255, 0)), (tas, (255, 0, 255)), (legs, (0, 255, 255))):
    dbg[m] = dbg[m] * .5 + np.array(col) * .5
Image.fromarray(dbg.astype(np.uint8)).save('/workspace/scratch/bastion/tlayers_E.png')
jp = OUT + 'target_layers.json'; J = json.load(open(jp)); J['info']['E'] = info; J['polygons']['E'] = dict(crop_x0=X0, **POLY)
json.dump(J, open(jp, 'w'), indent=1); print(json.dumps(info))
