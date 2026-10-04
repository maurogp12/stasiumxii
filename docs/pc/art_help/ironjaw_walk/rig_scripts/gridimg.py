import sys; from PIL import Image, ImageDraw
src, dst, sc = sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 2
crop = [int(v) for v in sys.argv[4].split(',')] if len(sys.argv) > 4 else None
im = Image.open(src).convert('RGBA')
if crop: im = im.crop(crop)
ox, oy = (crop[0], crop[1]) if crop else (0, 0)
bg = Image.new('RGBA', im.size, (235, 235, 235, 255)); bg.alpha_composite(im); im = bg.convert('RGB')
im = im.resize((im.width * sc, im.height * sc), Image.NEAREST); d = ImageDraw.Draw(im)
step = 10
for x in range((ox // step) * step, ox + im.width // sc + 1, step):
    if x < ox: continue
    d.line([((x - ox) * sc, 0), ((x - ox) * sc, im.height)], fill=(255, 0, 0) if x % 50 == 0 else (120, 190, 255))
    if x % 50 == 0: d.text(((x - ox) * sc + 2, 2), str(x), fill=(200, 0, 0))
for y in range((oy // step) * step, oy + im.height // sc + 1, step):
    if y < oy: continue
    d.line([(0, (y - oy) * sc), (im.width, (y - oy) * sc)], fill=(255, 0, 0) if y % 50 == 0 else (120, 190, 255))
    if y % 50 == 0: d.text((2, (y - oy) * sc + 2), str(y), fill=(200, 0, 0))
im.save(dst)
