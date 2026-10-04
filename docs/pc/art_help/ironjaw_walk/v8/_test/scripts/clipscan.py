"""straight visible layer-edge detector: for each layer, its visible boundary against layers drawn BEHIND it (or empty),
Hough line segments >= MINL px. Writes overlay sheets + json."""
import sys, json, numpy as np, cv2
from PIL import Image
root, F = sys.argv[1], sys.argv[2]; MINL = int(sys.argv[3]) if len(sys.argv) > 3 else 9
out = {}; tiles = []
PAL = np.array([[60,60,60],[255,0,0],[0,255,0],[0,0,255],[255,255,0],[255,0,255],[0,255,255],[255,128,0],[128,0,255],[0,128,0],[128,128,255],[255,128,128],[128,255,128],[200,200,200],[90,40,0],[0,90,90],[150,0,60],[60,150,0]])
for i in range(12):
    ow = np.asarray(Image.open(f'{root}/_dbg/owner_{F}_{i:02d}.png')).astype(int)
    stack = json.load(open(f'{root}/_dbg/stack_{F}_{i:02d}.json'))
    # owner index from colour
    idx = np.full(ow.shape[:2], -1)
    for k in range(len(stack)): idx[(ow == PAL[min(k, len(PAL)-1)]).all(-1)] = k
    fr = np.asarray(Image.open(f'{root}/walk/ironjaw_walk_{F}_f{i:02d}.png').convert('RGBA'))
    segs = []
    for k, nm in enumerate(stack):
        V = idx == k
        if not V.any(): continue
        behind = (idx < k)
        nb = np.zeros_like(V)
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
            nb |= np.roll(np.roll(behind, dy, 0), dx, 1)
        b = (V & nb).astype(np.uint8) * 255
        L = cv2.HoughLinesP(b, 1, np.pi / 180, threshold=MINL - 1, minLineLength=MINL, maxLineGap=1)
        if L is None: continue
        for x0, y0, x1, y1 in L.reshape(-1, 4):
            # fraction of the segment really on boundary px
            n = max(abs(x1-x0), abs(y1-y0)) + 1; xs = np.linspace(x0, x1, n).round().astype(int); ys = np.linspace(y0, y1, n).round().astype(int)
            if b[ys, xs].mean() < 0.9 * 255: continue
            segs.append(dict(layer=nm, seg=[int(x0), int(y0), int(x1), int(y1)], len=int(n), ang=round(float(np.degrees(np.arctan2(y1-y0, x1-x0))) % 180, 1)))
    out[i] = segs
    bg = np.full(fr.shape[:2] + (3,), (107, 104, 96), np.float32); a = fr[..., 3:4] / 255.0
    im = (fr[..., :3] * a + bg * (1 - a)).astype(np.uint8)
    im = cv2.resize(im, None, fx=2, fy=2, interpolation=cv2.INTER_NEAREST)
    for s in segs:
        x0, y0, x1, y1 = s['seg']; cv2.line(im, (2*x0, 2*y0), (2*x1, 2*y1), (0, 255, 255) if s['layer'] in ('near','far','left','right') else (255, 0, 255) if '_' in s['layer'] else (0, 255, 0), 1)
    cv2.putText(im, f'{F} f{i:02d}', (6, 20), 0, 0.6, (255, 255, 0), 1)
    tiles.append(im[100:700, 160:880])
json.dump(out, open(f'{root}/_dbg/clips_{F}.json', 'w'), indent=0)
rows = [np.concatenate(tiles[r*4:(r+1)*4], 1) for r in range(3)]
Image.fromarray(np.concatenate(rows, 0)).save(f'{root}/_dbg/clips_{F}.png')
from collections import Counter
print(F, {i: Counter(s['layer'] for s in v) for i, v in out.items()})
