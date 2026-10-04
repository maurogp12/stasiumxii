import sys
from PIL import Image
d, out = sys.argv[1], sys.argv[2]; fr = [int(x) for x in (sys.argv[3] if len(sys.argv) > 3 else '0,3,6,9').split(',')]
ghost = len(sys.argv) <= 4 or sys.argv[4] != 'noghost'; box = (150, 85, 370, 362); z = 1.6
w, h = int((box[2] - box[0]) * z), int((box[3] - box[1]) * z)
W = Image.new('RGB', (w * len(fr), h * 2), 'white')
for r, F in enumerate('SE'):
    for k, i in enumerate(fr):
        im = Image.open(f'{d}/kestrel_walk_{F}_f{i:02d}.png').convert('RGBA')
        bg = Image.new('RGBA', im.size, (200, 200, 200, 255))
        if ghost:
            cl = Image.open(f'/workspace/handoff/class_walk_blockouts/kestrel/blockout_v3/clay/kestrel_walk_{F}_f{i:02d}.png').convert('RGBA')
            cl.putalpha(Image.eval(cl.getchannel('A'), lambda v: v // 3)); bg.alpha_composite(cl)
        bg.alpha_composite(im); W.paste(bg.convert('RGB').crop(box).resize((w, h), Image.LANCZOS), (k * w, r * h))
W.save(out)
