"""peek.py strip.png out.png [scale] : strip on grey with pivot lines (y=240, x=128 per frame)."""
import sys
from PIL import Image, ImageDraw
im = Image.open(sys.argv[1]).convert('RGBA'); sc = float(sys.argv[3]) if len(sys.argv) > 3 else 1
n = im.width // 256
bg = Image.new('RGBA', im.size, (120, 130, 120, 255))
d = ImageDraw.Draw(bg)
for k in range(n):
    d.rectangle([k*256, 0, k*256+255, 255], outline=(90, 90, 90, 255))
bg.alpha_composite(im)
d = ImageDraw.Draw(bg)
for k in range(n):
    d.line([k*256, 240, k*256+255, 240], fill=(255, 0, 0, 160))
    d.line([k*256+128, 0, k*256+128, 255], fill=(0, 0, 255, 120))
    d.text((k*256+4, 4), str(k), fill=(255,255,255,255))
if sc != 1: bg = bg.resize((int(bg.width*sc), int(bg.height*sc)), Image.LANCZOS)
bg.convert('RGB').save(sys.argv[2])
