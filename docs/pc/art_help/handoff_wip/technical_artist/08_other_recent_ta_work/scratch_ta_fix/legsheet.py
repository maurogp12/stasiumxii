import sys
from PIL import Image, ImageDraw
root, strip, out = sys.argv[1], sys.argv[2], sys.argv[3]
roles = sys.argv[4].split(',')
y0, y1, x0, x1 = 130, 250, 48, 208
W, H = x1 - x0, y1 - y0
sheet = Image.new('RGB', (W * 8 + 90, H * len(roles)), (150, 160, 140))
d = ImageDraw.Draw(sheet)
for r_, role in enumerate(roles):
    im = Image.open(f'{root}/{role}/_2x/{strip}.png').convert('RGBA')
    n = im.width // 256
    d.text((2, r_ * H + 4), role[:12], fill=(0, 0, 0))
    for k in range(min(n, 8)):
        fr = im.crop((k * 256 + x0, y0, k * 256 + x1, y1))
        bg = Image.new('RGBA', fr.size, (150, 160, 140, 255)); bg.alpha_composite(fr)
        sheet.paste(bg.convert('RGB'), (90 + k * W, r_ * H))
        d.line([(90 + k * W, r_ * H + 240 - y0), (90 + (k + 1) * W, r_ * H + 240 - y0)], fill=(200, 0, 0))
        d.line([(90 + k * W + 128 - x0, r_ * H), (90 + k * W + 128 - x0, (r_ + 1) * H)], fill=(0, 0, 200))
sheet.save(out)
