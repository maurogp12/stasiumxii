"""Bastion v2: leg parts cut from the approved targets at target scale (thigh, knee cop, greave, sabaton per facing).
Polygon (target px) & target alpha & not cape/tabard cloth -> largest blob, holes filled. Writes parts/T{F}L_<part>.png
(cropped) and parts/target_legs.json with the crop origin and anchors moved into crop px.
S: the near leg is the only one the target shows from thigh to sole (the far leg is behind the tabard/cape down to
the shin), so both legs use the near-leg pieces. E: the far (R) leg shows thigh..sabaton; the near leg only shows
its sabaton under the cape, so both legs use the far-leg pieces."""
import os, json, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from skimage.color import rgb2lab
T = '/workspace/handoff/class_walk_blockouts/targets/'; OUT = '/workspace/scratch/b2/parts/'
LEGS = {
 'S': {
  'thigh':   dict(poly=[(704, 330), (768, 330), (781, 446), (700, 446)], A=(738, 300), B=(741, 466)),
  'kneecop': dict(poly=[(703, 424), (745, 413), (787, 430), (790, 470), (771, 507), (745, 517), (713, 507), (702, 470)], C=(741, 466)),
  'greave':  dict(poly=[(697, 478), (769, 478), (769, 612), (697, 612)], A=(741, 466), B=(734, 612)),
  'sabaton': dict(poly=[(693, 579), (791, 579), (793, 689), (693, 689)], heel=(697.3, 654.1), toe=(765, 684)),
 },
 'E': {
  'thigh':   dict(poly=[(650, 340), (750, 340), (754, 488), (660, 488)], A=(698, 345), B=(716, 472)),
  'kneecop': dict(poly=[(688, 428), (742, 400), (766, 410), (768, 500), (735, 506), (690, 500)], C=(716, 472)),
  'greave':  dict(poly=[(667, 462), (761, 462), (762, 580), (716, 596), (700, 606), (667, 606)], A=(716, 472), B=(728, 622)),
  'sabaton': dict(poly=[(699, 558), (815, 558), (815, 659), (699, 659)], heel=(731, 649), toe=(791, 622)),
 }}
def cloth(rgb):
    lab = rgb2lab(rgb); b, a = lab[..., 2], lab[..., 1]
    blue = (b < -6) & (-b > np.abs(a) * 1.0)
    return ndi.binary_opening(blue, iterations=1)
info = {}
for F, parts in LEGS.items():
    rgb = np.asarray(Image.open(f'{T}bastion_rp_{F}_f00.jpg').convert('RGB')); al = np.asarray(Image.open(f'{T}bastion_rp_{F}_f00_alpha.png').convert('L')) > 127
    cl = cloth(rgb)
    for nm, d in parts.items():
        pm = Image.new('L', (rgb.shape[1], rgb.shape[0]), 0); ImageDraw.Draw(pm).polygon(d['poly'], fill=255); m = (np.asarray(pm) > 0) & al & ~cl
        lab, n = ndi.label(m); m = lab == (np.argmax(np.bincount(lab.ravel())[1:]) + 1) if n else m
        m = ndi.binary_fill_holes(m)
        ys, xs = np.nonzero(m); x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        out = np.zeros((y1 - y0, x1 - x0, 4), np.uint8); sub = m[y0:y1, x0:x1]
        out[..., :3] = rgb[y0:y1, x0:x1] * sub[..., None]; out[..., 3] = sub * 255
        Image.fromarray(out).save(f'{OUT}T{F}L_{nm}.png')
        e = {k: [float(v[0] - x0), float(v[1] - y0)] for k, v in d.items() if k != 'poly'}
        info[f'{F}_{nm}'] = dict(file=f'T{F}L_{nm}', origin=[int(x0), int(y0)], **e, px=int(m.sum()))
json.dump(info, open(OUT + 'target_legs.json', 'w'), indent=1)
for k, v in info.items(): print(k, v)
