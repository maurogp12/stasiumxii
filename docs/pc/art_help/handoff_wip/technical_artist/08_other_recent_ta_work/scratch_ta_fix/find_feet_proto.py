import sys, os, json, numpy as np
HERE = '/workspace/stasium-pc-look/tools/npc'; sys.path.insert(0, HERE)
from PIL import Image, ImageDraw
import build_npc as B

def runs(mask):
    d = np.diff(np.concatenate([[0], mask.astype(np.int8), [0]]))
    return list(zip(np.where(d == 1)[0], np.where(d == -1)[0] - 1))

def find_feet(al, top, log=print):
    op = al > 0.5
    H, W = op.shape
    rows = np.where(op.sum(1) >= 3)[0]; g = int(rows.max()); h = g - top
    R0 = g - int(0.32 * h)
    sub = op[R0:g + 1]
    has = sub.any(0)
    b = np.where(has, R0 + (sub.shape[0] - 1 - np.argmax(sub[::-1], 0)), -1)
    tol = 0.06 * h; wmin = 0.04 * h; dz = int(0.025 * h)
    def run_at(y, x):
        for a, c in runs(op[y]):
            if a <= x <= c: return a, c
        return None
    feet = []
    used = np.zeros(W, bool)
    order = np.argsort(-b)
    for x in order:
        if b[x] < 0 or used[x] : continue
        y = int(b[x])
        if y < g - 0.30 * h: break
        # foot run around x on the bottom profile
        x0 = x; x1 = x
        while x0 - 1 >= 0 and b[x0 - 1] >= y - tol and not used[x0 - 1]: x0 -= 1
        while x1 + 1 < W and b[x1 + 1] >= y - tol and not used[x1 + 1]: x1 += 1
        r = run_at(y - dz, x)
        wd = (r[1] - r[0] + 1) if r else 0
        if wd < wmin:
            used[max(0, x - 3):x + 4] = True   # thin spike (tassel / fringe tip): skip just this spike
            continue
        r3 = run_at(y - 3 * dz, x)
        w3 = (r3[1] - r3[0] + 1) if r3 else 0
        if w3 > 1.7 * wd and wd < 0.06 * h:      # tapers to a point: tassel / fringe tip, not a boot
            used[max(0, x - 3):x + 4] = True
            continue
        feet.append({'x': int(x), 'y': y, 'run': (int(x0), int(x1)), 'w': int(wd), 'w3': int(w3)})
        m = int(0.02 * h)
        used[max(0, x0 - m):x1 + m + 1] = True
    return feet, g, h

R = sys.argv[1:] or ['herald']
for role in R:
    cfg = json.load(open(f'{HERE}/roles/{role}.json'))
    tiles = []
    for vn in cfg['views']:
        v = B.View(cfg, vn, f'{HERE}/_work/{role}/keyed', lambda s: None)
        st = v.stand; al = st.body[..., 3]
        feet, g, h = find_feet(al, st.A['head_top'])
        print(role, vn, 'g', g, 'h', h, feet)
        rgb = B.unpremul(st.body); img = rgb[..., :3] * rgb[..., 3:4] + 0.88 * (1 - rgb[..., 3:4])
        im = Image.fromarray((img * 255).astype(np.uint8)); d = ImageDraw.Draw(im)
        for f in feet:
            d.ellipse([f['x'] - 6, f['y'] - 6, f['x'] + 6, f['y'] + 6], outline=(255, 0, 255), width=3)
            d.line([f['run'][0], f['y'] + 4, f['run'][1], f['y'] + 4], fill=(0, 200, 255), width=3)
        tiles.append(im.crop((300, int(g - 0.4 * h), 1000, g + 15)))
    o = Image.new('RGB', (sum(t.width for t in tiles), max(t.height for t in tiles)), 'white'); x = 0
    for t in tiles: o.paste(t, (x, 0)); x += t.width
    o.resize((o.width // 2, o.height // 2)).save(f'/workspace/scratch/ta_fix/legs/{role}.png')
