import sys, json
sys.path.insert(0, '/workspace/stasium-pc-look/tools/npc')
import numpy as np
from PIL import Image, ImageDraw
import build_npc as b
cfg = json.load(open('/workspace/stasium-pc-look/tools/npc/roles/forge_master.json'))
name, fn = sys.argv[1], sys.argv[2]
mirror = '--mirror' in sys.argv
x0, y0, x1, y1 = map(int, sys.argv[3].split(',')) if len(sys.argv) > 3 and ',' in sys.argv[3] else (0, 0, 1280, 720)
sc = float(sys.argv[4]) if len(sys.argv) > 4 and not sys.argv[4].startswith('--') else 0.75
step = int(sys.argv[5]) if len(sys.argv) > 5 and not sys.argv[5].startswith('--') else 50
c = dict(cfg); c['keys'] = dict(cfg['keys']); c['keys'][name] = fn
rgba = b.load_key(c, name, '/workspace/stasium-pc-look/tools/npc/_work/forge_master/keyed')
if mirror: rgba = rgba[:, ::-1].copy()
u = (np.clip(rgba, 0, 1) * 255).astype(np.uint8)
im = Image.fromarray(u, 'RGBA'); bg = Image.new('RGBA', im.size, (150, 160, 140, 255)); bg.alpha_composite(im)
bg = bg.convert('RGB').crop((x0, y0, x1, y1)); bg = bg.resize((int(bg.width * sc), int(bg.height * sc)), Image.LANCZOS)
d = ImageDraw.Draw(bg)
for x in range((x0 // step + 1) * step, x1, step):
    X = (x - x0) * sc; d.line([(X, 0), (X, bg.height)], fill=(255, 0, 0) if x % (step * 2) == 0 else (255, 160, 160)); d.text((X + 2, 2), str(x), fill=(255, 255, 0))
for y in range((y0 // step + 1) * step, y1, step):
    Y = (y - y0) * sc; d.line([(0, Y), (bg.width, Y)], fill=(0, 0, 255) if y % (step * 2) == 0 else (160, 160, 255)); d.text((2, Y + 2), str(y), fill=(255, 255, 0))
bg.save(f'pk/kg_{name}{"_m" if mirror else ""}.png'); print(rgba.shape, 'alpha>0.5 bbox', np.argwhere(rgba[..., 3] > 0.5).min(0), np.argwhere(rgba[..., 3] > 0.5).max(0))
