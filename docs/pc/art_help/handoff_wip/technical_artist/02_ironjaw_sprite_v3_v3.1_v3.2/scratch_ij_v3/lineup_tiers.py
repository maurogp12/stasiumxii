#!/usr/bin/env python3
"""Class size tiers: all five fighters at their per-class draw_scale on the 64x32 combat board (shown x2)."""
import sys, json, numpy as np
sys.path.insert(0, "/workspace/stasium-pc-look/tools"); sys.argv = ["x"]
from chars_pics import iso_grid, paste_scaled, save_jpg, F, FB, BG, GRID, TXT
from check_chars import CLAIM, mask, bbox
from PIL import Image, ImageDraw
J = "/workspace/stasium-pc-look/ship/characters_pc/json"; Z = 2
chars = ["ironjaw", "bastion", "kestrel", "gloam", "mender"]
items = []
for n in chars:
    j = json.load(open(f"{J}/{n}.json"))
    im = Image.open(f"/workspace/art/{CLAIM[n]['dir']}/idle/{n}_idle_S_f00.png").convert("RGBA")
    items.append(dict(name=n, im=im, piv=tuple(j["states"]["idle"]["facings"]["S"]["pivot"]), s=j["draw_scale"],
                      tier=j["size_tier"], hp=j["head_hp_y"]))
pawn = Image.open("/workspace/stasium-repo/art/characters/ironjaw/ironjaw_e.png").convert("RGBA")
items.append(dict(name="today's pawn ironjaw_e", im=pawn, piv=(72, 152), s=0.5, tier="ref", hp=-76))
W, H = 1700, 500
c = Image.new("RGBA", (W, H), BG + (255,)); d = ImageDraw.Draw(c)
tw, th = 64*Z, 32*Z; base_y = 360; x0 = 150
iso_grid(d, W, H, x0, base_y, tw, th)
d.text((14, 10), "Class size tiers: idle S f0 at the per-class draw_scale on the 64x32 combat board (shown x2, tile 128x64). Feet on tile centres.", fill=TXT, font=F(19))
d.text((14, 36), "Big = Ironjaw, Bastion (target 78 board px). Small = Kestrel, Gloam, Mender (target 66). Blue tick = per-class HEAD_HP_Y. Engine-scaled, art not resampled.", fill=TXT, font=F(15))
for k, it in enumerate(items):
    fx = x0 + k*2.1*tw; fy = base_y
    d.polygon([(fx, fy - th/2), (fx + tw/2, fy), (fx, fy + th/2), (fx - tw/2, fy)], fill=(110, 132, 92), outline=(200, 210, 170))
    paste_scaled(c, it["im"], it["piv"], (fx, fy), it["s"]*Z); d = ImageDraw.Draw(c)
    b = bbox(mask(np.array(it["im"]))); hpx = b[3] - b[1] + 1
    d.line([(fx - 6, fy), (fx + 6, fy)], fill=(255, 60, 60), width=2); d.line([(fx, fy - 6), (fx, fy + 6)], fill=(255, 60, 60), width=2)
    top = fy - (it["piv"][1] - b[1])*it["s"]*Z
    d.line([(fx + tw*0.62, top), (fx + tw*0.62, fy)], fill=(255, 230, 120), width=1)
    d.line([(fx + tw*0.62 - 4, top), (fx + tw*0.62 + 4, top)], fill=(255, 230, 120), width=1)
    hy = fy + it["hp"]*Z
    d.line([(fx - 22, hy), (fx + 22, hy)], fill=(90, 170, 255), width=3)
    ref = it["tier"] == "ref"
    d.text((fx - tw*0.85, fy + th*0.7), it["name"] if not ref else "today's pawn", fill=TXT, font=FB(17))
    d.text((fx - tw*0.85, fy + th*0.7 + 22), f"{hpx*it['s']:.0f} px on board" + (f" ({it['tier']})" if not ref else " (ironjaw_e @0.5)"), fill=TXT, font=F(14))
    d.text((fx - tw*0.85, fy + th*0.7 + 40), f"scale {it['s']}  HP_Y {it['hp']}" if not ref else "scale 0.5  HP_Y -76", fill=(210, 205, 185), font=F(13))
for y, lab in [(78, "78"), (66, "66")]:
    yy = base_y - y*Z; d.line([(20, yy), (W - 20, yy)], fill=(255, 230, 120, 255) if y == 78 else (200, 200, 255), width=1)
    d.text((22, yy - 16), f"{lab} px", fill=TXT, font=F(13))
print(save_jpg(c, "/workspace/luca_pics/chars/lineup_tiers.jpg", maxkb=245))
