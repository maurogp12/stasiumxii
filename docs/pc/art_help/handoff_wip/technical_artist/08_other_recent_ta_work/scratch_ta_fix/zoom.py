"""zoom.py strip.png out.png [x0 y0 x1 y1] [scale] [frames e.g. 0,2,3]: crops per frame with pivot lines."""
import sys
from PIL import Image, ImageDraw
im = Image.open(sys.argv[1]).convert('RGBA')
x0, y0, x1, y1 = map(int, sys.argv[3:7]) if len(sys.argv) > 6 else (60, 100, 200, 250)
sc = int(sys.argv[7]) if len(sys.argv) > 7 else 3
n = im.width // 256
fr = list(map(int, sys.argv[8].split(','))) if len(sys.argv) > 8 else range(n)
cw, ch = (x1 - x0) * sc, (y1 - y0) * sc
out = Image.new('RGB', (len(fr) * (cw + 4), ch), (30, 30, 30))
for j, k in enumerate(fr):
    bg = Image.new('RGBA', (256, 256), (150, 160, 140, 255)); bg.alpha_composite(im.crop((k*256, 0, k*256+256, 256)))
    c = bg.crop((x0, y0, x1, y1)).resize((cw, ch), Image.NEAREST)
    d = ImageDraw.Draw(c)
    d.line([0, (240 - y0) * sc, cw, (240 - y0) * sc], fill=(255, 0, 0)); d.line([0, (241 - y0) * sc, cw, (241 - y0) * sc], fill=(255, 0, 0))
    d.line([(128 - x0) * sc, 0, (128 - x0) * sc, ch], fill=(0, 0, 255))
    d.text((4, 4), str(k), fill=(255, 255, 255))
    out.paste(c.convert('RGB'), (j * (cw + 4), 0))
out.save(sys.argv[2])
