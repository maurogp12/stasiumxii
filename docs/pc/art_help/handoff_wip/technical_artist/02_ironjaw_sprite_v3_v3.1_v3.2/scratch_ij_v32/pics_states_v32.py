#!/usr/bin/env python3
"""ironjaw_v32_states.jpg: first frames before (v3.1) / after (v3.2) per facing, red = feet line (pivot y140),
cyan = idle f0 boot outline (rows 124+) laid over each frame, numbers = pivot-aligned jump from idle f0."""
import io, json, sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, "/workspace/scratch/ij_v32"); from m32 import load
V31 = "/workspace/art/ironjaw_full/v3"; V32 = "/workspace/art/ironjaw_full/v3.2"; OUT = "/workspace/luca_pics/chars"
F = lambda s: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", s)
FB = lambda s: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", s)
T1 = json.load(open("trans_v31.json")); T2 = json.load(open("trans_v32.json"))
TXH = 38; BG = (120, 110, 88); DARK = (38, 40, 34); TXT = (240, 236, 220); Z = 1.5
def panel(root, st, fc, T, idle_o):
    a = load(root, st, fc, 0); im = Image.new("RGBA", (165, 157), BG + (255,)); im.alpha_composite(Image.fromarray(a))
    big = im.resize((int(165*Z), int(157*Z)), Image.NEAREST); A = np.array(big)
    A[idle_o] = (0, 255, 255, 255); big = Image.fromarray(A); d = ImageDraw.Draw(big)
    d.line([(0, 140*Z), (165*Z, 140*Z)], fill=(230, 40, 40), width=2)
    d.line([(82*Z, 128*Z), (82*Z, 150*Z)], fill=(230, 40, 40), width=2)
    out = Image.new("RGBA", (big.width, big.height + TXH), (30, 30, 26, 255)); out.paste(big, (0, 0)); d = ImageDraw.Draw(out)
    if st != "idle":
        t = T[f"{fc} idle->{st}_f00"]
        bad = abs(t["sole"]) > 2 or abs(t["fx"]) > 2; bootbad = max(abs(t["foot"][0]), abs(t["foot"][1])) > 2
        d.text((4, big.height + 2), f"low row {t['sole']:+d}  feet-c {t['fx']:+.0f}", fill=(255, 130, 110) if bad else (170, 240, 160), font=F(13))
        d.text((4, big.height + 19), f"boot ({t['foot'][0]:+d},{t['foot'][1]:+d})", fill=(255, 130, 110) if bootbad else (170, 240, 160), font=F(13))
        d.text((112, big.height + 19), f"head ({t['head'][0]:+d},{t['head'][1]:+d})", fill=(220, 220, 205), font=F(13))
    else:
        d.text((4, big.height + 2), "reference (unchanged)", fill=(220, 220, 205), font=F(13))
    return out
def outline(root, fc):
    a = load(root, "idle", fc, 0); m = a[..., 3] > 127; m[:124] = False; m[:, :28] = False; m[:, 137:] = False
    e = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
    ys, xs = np.where(e); o = np.zeros((int(157*Z), int(165*Z)), bool)
    for y, x in zip(ys, xs): o[int(y*Z):int((y+1)*Z), int(x*Z):int((x+1)*Z)] = True
    return o
rows = [("E", V31, T1, "E  BEFORE (v3.1)"), ("E", V32, T2, "E  AFTER (v3.2)"), ("N", V31, T1, "N  BEFORE (v3.1)"), ("N", V32, T2, "N  AFTER (v3.2)"),
        ("S", V32, T2, "S  (v3.1 = v3.2)"), ("W", V32, T2, "W  (v3.1 = v3.2)")]
STS = ["idle", "walk", "attack", "hit", "death"]; pw, ph = int(165*Z), int(157*Z) + TXH; lab = 150; gap = 6; head = 74; colh = 22
W = lab + len(STS)*(pw+gap) + gap; H = head + colh + len(rows)*(ph+gap) + 30
c = Image.new("RGB", (W, H), (50, 54, 46)); d = ImageDraw.Draw(c)
d.text((10, 6), "IRONJAW v3.2 movement fix: first frame of each state, pivot-aligned. Red = feet line (pivot y140). Cyan = idle f0 boot outline.", fill=TXT, font=FB(16))
d.text((10, 30), "N/E fix: walk starts on old f03, whose planted boot sits on the idle boot (boot 0-1 px, low row 0). The other boot lifts for the", fill=TXT, font=F(14))
d.text((10, 49), "first step, so the 6-row feet-centre metric reads 17. Before: walk f00 put the support boot 16 px left / 5 px down (feet-c 31).", fill=TXT, font=F(14))
for j, st in enumerate(STS): d.text((lab + gap + j*(pw+gap) + 6, head + 2), st + " f00", fill=TXT, font=FB(14))
for i, (fc, root, T, name) in enumerate(rows):
    y = head + colh + i*(ph+gap); o = outline(root, fc)
    d.text((8, y + ph//2 - 10), name, fill=(255, 220, 120) if "AFTER" in name else TXT, font=FB(14))
    for j, st in enumerate(STS):
        c.paste(panel(root, st, fc, T, o).convert("RGB"), (lab + gap + j*(pw+gap), y))
d.text((10, H - 24), "boot = move of the best-matching idle boot; head = head/torso offset vs idle. hit/death 7-10 px and S/W attack 5 px = painted lean (boots identical, feet stay put): not moved.", fill=(210, 210, 195), font=F(13))
q = 90
while True:
    b = io.BytesIO(); c.save(b, "JPEG", quality=q, optimize=True)
    if b.tell() <= 290*1024 or q <= 40: break
    q -= 5
open(f"{OUT}/ironjaw_v32_states.jpg", "wb").write(b.getvalue()); print(c.size, q, b.tell()//1024, "KB")
