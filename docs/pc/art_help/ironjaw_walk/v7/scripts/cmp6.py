import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
# cmp6.py out.png frame label1:dir1 label2:dir2 ...   (S facing, norim frames, crops full figure, 2x) + target
sys.path.insert(0, '/workspace/handoff/ironjaw_walk_claude/claude_reply/scripts'); from cut import cut_target
out, fi = sys.argv[1], int(sys.argv[2]); fac = sys.argv[3]; items = sys.argv[4:]
FNT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13); BG = (120, 120, 120)
tiles = []
tp = {'S': '/workspace/scratch/ij_walk/repaint_E2/rp_S_turn_t1.jpg', 'E': '/workspace/scratch/ij_walk/repaint_E2/rp_E_stride_t2.jpg'}[fac]
r, a, _ = cut_target(tp); im = Image.fromarray(np.dstack([r, a.astype(np.uint8) * 255]), 'RGBA'); tiles.append(('target', im.crop(im.getbbox())))
for it in items:
    lab, d = it.split(':', 1); im = Image.open(f'{d}/ironjaw_walk_{fac}_f{fi:02d}.png').convert('RGBA'); tiles.append((lab, im.crop(im.getbbox())))
H = 560; tiles = [(l, i.resize((round(i.width * H / i.height), H), Image.LANCZOS)) for l, i in tiles]
M = Image.new('RGB', (sum(i.width + 12 for _, i in tiles), H + 22), BG); d = ImageDraw.Draw(M); x = 0
for l, i in tiles:
    t = Image.new('RGBA', i.size, BG + (255,)); t.alpha_composite(i); M.paste(t.convert('RGB'), (x, 22)); d.text((x + 4, 3), l, fill=(255, 255, 255), font=FNT); x += i.width + 12
M.save(out)
