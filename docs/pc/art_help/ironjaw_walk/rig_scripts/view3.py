import sys; from PIL import Image, ImageDraw
d, fac, frames, out = sys.argv[1], sys.argv[2], [int(x) for x in sys.argv[3].split(',')], sys.argv[4]
sc = float(sys.argv[5]) if len(sys.argv) > 5 else 1.5
box = (60, 50, 450, 345)
cells = []
for i in frames:
    im = Image.open(f'{d}/ironjaw_walk_{fac}_f{i:02d}.png').convert('RGBA')
    bg = Image.new('RGBA', im.size, (107, 104, 96, 255)); bg.alpha_composite(im)
    c = bg.crop(box).convert('RGB'); c = c.resize((int(c.width * sc), int(c.height * sc)), Image.LANCZOS)
    ImageDraw.Draw(c).text((4, 4), f'{fac} f{i:02d}', fill=(255, 255, 255)); cells.append(c)
M = Image.new('RGB', (sum(c.width for c in cells), cells[0].height))
x = 0
for c in cells: M.paste(c, (x, 0)); x += c.width
M.save(out)
