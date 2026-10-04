#!/usr/bin/env python3
"""Contact sheets for Ironjaw v3: 1x and game 0.5x (combat draw scale). Rows = state x facing, columns = frames."""
import json
from PIL import Image, ImageDraw, ImageFont
V3 = "/workspace/art/ironjaw_full/v3"
P = json.load(open(f"{V3}/_cells_pivots.json"))
STATES = {"walk": 12, "idle": 4, "attack": 6, "hit": 4, "death": 6}
F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 12)
BG = (28, 26, 22); CELL = (122, 104, 78); TXT = (225, 220, 205)
def sheet(scale, tag):
    gap = 4; lab = 70; head = 22
    cw = max(P[s]["cell"][0] for s in STATES); ch_ = {s: P[s]["cell"][1] for s in STATES}
    colw = round(cw*scale) + gap
    rows = [(s, f) for s in STATES for f in "SWNE"]
    H = head + sum(round(ch_[s]*scale) + gap for s, f in rows); W = lab + 12*colw
    c = Image.new("RGBA", (W, H), BG + (255,)); d = ImageDraw.Draw(c)
    d.text((4, 4), f"IRONJAW full set v3 (v3.1: idle S/W stance = walk S f00 stride) | {tag} | walk/idle/attack/hit cell 165x157 pivot (82,140); death 209x183 pivot (104,140) | red tick = pivot (feet)", fill=TXT, font=F)
    y = head
    for s, fc in rows:
        w, h = P[s]["cell"]; px, py = P[s]["pivot"]; sw, sh = round(w*scale), round(h*scale)
        d.text((4, y + sh//2 - 6), f"{s} {fc}", fill=TXT, font=F)
        for i in range(STATES[s]):
            im = Image.open(f"{V3}/{s}/ironjaw_{s}_{fc}_f{i:02d}.png").convert("RGBA")
            t = Image.new("RGBA", (w, h), CELL + (255,)); t.alpha_composite(im)
            if scale != 1: t = t.resize((sw, sh), Image.LANCZOS)
            x = lab + i*colw + (colw - gap - sw)//2
            c.alpha_composite(t, (x, y)); d = ImageDraw.Draw(c)
            fx, fy = x + round(px*scale), y + round(py*scale)
            d.line([(fx - 4, fy), (fx + 4, fy)], fill=(230, 40, 40)); d.line([(fx, fy - 4), (fx, fy + 2)], fill=(230, 40, 40))
        y += sh + gap
    return c
for scale, tag, fn in [(1.0, "1x", "ironjaw_full_v3_contact_sheet_1x.png"), (0.5, "game 0.5x (combat draw scale; v2 sheets said 0.6x)", "ironjaw_full_v3_contact_sheet_game0.5x.png")]:
    im = sheet(scale, tag); im.convert("RGB").save(f"{V3}/{fn}", optimize=True); print(fn, im.size)
