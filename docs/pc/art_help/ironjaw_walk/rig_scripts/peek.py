import sys; from PIL import Image, ImageDraw
d, fac, frames, out = sys.argv[1], sys.argv[2], [int(x) for x in sys.argv[3].split(',')], sys.argv[4]
x0, x1 = 50, 470
M = Image.new('RGB', ((x1 - x0) * len(frames), 360), (107, 104, 96))
for j, i in enumerate(frames):
    im = Image.open(f'{d}/ironjaw_walk_{fac}_f{i:02d}.png').convert('RGBA')
    bg = Image.new('RGBA', im.size, (107, 104, 96, 255)); bg.alpha_composite(im)
    dr = ImageDraw.Draw(bg); dr.line([(0, 329), (512, 329)], fill=(150, 60, 60)); dr.text((x0 + 4, 4), f'{fac} f{i:02d}', fill=(255, 255, 255))
    M.paste(bg.crop((x0, 0, x1, 360)).convert('RGB'), (j * (x1 - x0), 0))
M.save(out)
