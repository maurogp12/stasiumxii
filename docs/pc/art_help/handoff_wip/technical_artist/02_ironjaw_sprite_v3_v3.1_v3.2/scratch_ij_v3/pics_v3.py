#!/usr/bin/env python3
import io, json, numpy as np
from PIL import Image, ImageDraw, ImageFont
V2 = "/workspace/art/ironjaw_full/v2"; V3 = "/workspace/art/ironjaw_full/v3"; OUT = "/workspace/luca_pics/chars"
F = lambda s: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", s)
FB = lambda s: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", s)
TXT = (240, 236, 220); OUTSIDE = (34, 34, 38); CELL = (122, 104, 78)
P3 = json.load(open(f"{V3}/_cells_pivots.json"))
def piv(ver, st): return ((102 if st == "death" else 78), 133) if ver == "v2" else tuple(P3[st]["pivot"])
def fr(ver, st, fc, i): return Image.open(f"{V2 if ver=='v2' else V3}/{st}/ironjaw_{st}_{fc}_f{i:02d}.png").convert("RGBA")

def save_jpg(im, path, maxkb=245):
    q = 92
    while True:
        b = io.BytesIO(); im.convert("RGB").save(b, "JPEG", quality=q, optimize=True)
        if b.tell() <= maxkb*1024 or q <= 40: break
        q -= 4
    open(path, "wb").write(b.getvalue()); return b.tell()//1024, q

def crop_view(ver, st, fc, i, rx0, ry0, rx1, ry1, z, mark_pivot=False, sole=False):
    """region in pivot-relative coords; outside the cell = dark, inside = tan; zoom z (nearest)."""
    im = fr(ver, st, fc, i); px, py = piv(ver, st); w, h = im.size
    W, H = rx1 - rx0, ry1 - ry0
    c = Image.new("RGBA", (W, H), OUTSIDE + (255,))
    ox, oy = -rx0 - px, -ry0 - py                     # cell origin in canvas coords
    c.paste(Image.new("RGBA", (w, h), CELL + (255,)), (ox, oy))
    c.alpha_composite(im, (max(ox, 0), max(oy, 0)), (max(-ox, 0), max(-oy, 0)))
    c = c.resize((W*z, H*z), Image.NEAREST); d = ImageDraw.Draw(c)
    # cell edge
    d.rectangle([ox*z, oy*z, (ox + w)*z - 1, (oy + h)*z - 1], outline=(255, 70, 70), width=2)
    if mark_pivot:
        fx, fy = (-rx0)*z, (-ry0)*z
        d.line([(0, fy), (W*z, fy)], fill=(255, 70, 70), width=2)
        d.line([(fx, fy - 14), (fx, fy + 14)], fill=(255, 70, 70), width=3); d.line([(fx - 14, fy), (fx + 14, fy)], fill=(255, 70, 70), width=3)
    if sole:
        m = np.array(im)[..., 3] > 0; s = int(np.where(m.any(1))[0].max())
        ys = (oy + s + 1)*z                            # bottom edge of the lowest opaque row
        d.line([(0, ys), (W*z, ys)], fill=(255, 230, 0), width=2)
    return c

def labelled(img, title, sub=""):
    W = max(img.width, 400)
    c = Image.new("RGB", (W, img.height + 46), (24, 24, 26)); c.paste(img.convert("RGB"), (0, 46)); d = ImageDraw.Draw(c)
    d.text((6, 4), title, fill=TXT, font=FB(16)); d.text((6, 25), sub, fill=(210, 205, 185), font=F(13)); return c

def hrow(ims, gap=12, bg=(24, 24, 26)):
    W = sum(i.width for i in ims) + gap*(len(ims) - 1); H = max(i.height for i in ims)
    c = Image.new("RGB", (W, H), bg); x = 0
    for i in ims: c.paste(i, (x, 0)); x += i.width + gap
    return c
def vcol(ims, gap=12, bg=(24, 24, 26)):
    W = max(i.width for i in ims); H = sum(i.height for i in ims) + gap*(len(ims) - 1)
    c = Image.new("RGB", (W, H), bg); y = 0
    for i in ims: c.paste(i, (0, y)); y += i.height + gap
    return c

def before_after():
    z = 6
    a1 = labelled(crop_view("v2", "walk", "W", 11, -88, -52, -22, -12, z), "walk W f11  BEFORE (v2)", "axe tip on the cell's left edge (4 px in column 0)")
    a2 = labelled(crop_view("v3", "walk", "W", 11, -88, -52, -22, -12, z), "walk W f11  AFTER (v3)", "same pixels, cell +4 px each side -> 4 px margin")
    b1 = labelled(crop_view("v2", "attack", "W", 2, -88, -120, -22, -80, z), "attack W f02  BEFORE (v2)", "blade on the left edge (8 px in column 0)")
    b2 = labelled(crop_view("v3", "attack", "W", 2, -88, -120, -22, -80, z), "attack W f02  AFTER (v3)", "4 px margin; 0 px reconstructed (tip complete)")
    z2 = 4
    c1 = labelled(crop_view("v2", "idle", "S", 0, -60, -36, 40, 18, z2, mark_pivot=True, sole=True), "idle S f00  BEFORE (v2) pivot (78,133)", "red = pivot, yellow = sole bottom: feet 5-6 px below the pivot")
    c2 = labelled(crop_view("v3", "idle", "S", 0, -60, -36, 40, 18, z2, mark_pivot=True, sole=True), "idle S f00  AFTER (v3) pivot (82,140)", "sole on the pivot line (lowest row = pivot row)")
    top = hrow([vcol([a1, a2]), vcol([b1, b2])], gap=24)
    bot = hrow([c1, c2], gap=24)
    page = vcol([top, bot], gap=24)
    head = Image.new("RGB", (page.width, 36), (24, 24, 26)); ImageDraw.Draw(head).text((6, 8), "Ironjaw v3 vs v2. Red box = cell edge (dark = outside the cell). Pixels unchanged; nearest-neighbour zoom.", fill=TXT, font=F(15))
    return vcol([head, page], gap=0)

def sheet():
    z = 1; states = ["walk", "idle", "attack", "hit", "death"]
    L = max(P3[s]["pivot"][0] for s in states); R = max(P3[s]["cell"][0] - P3[s]["pivot"][0] for s in states)
    U = max(P3[s]["pivot"][1] for s in states); D = max(P3[s]["cell"][1] - P3[s]["pivot"][1] for s in states)
    sw, sh = L + R + 10, U + D + 26; lw = 80
    W, H = lw + 4*sw, 64 + len(states)*sh
    c = Image.new("RGB", (W, H), (60, 70, 56)); d = ImageDraw.Draw(c)
    d.text((8, 4), "Ironjaw v3: frame 0 per state x facing. Red line = pivot y (feet line), red tick = pivot x, yellow = lowest opaque row,", fill=TXT, font=F(14))
    d.text((8, 22), "grey box = cell (>= 4 px clear margin). S/W attack/hit/death start in the v1 stride: front toe +12, back foot above the line.", fill=TXT, font=F(14))
    for j, fc in enumerate("SWNE"): d.text((lw + j*sw + sw//2 - 6, 42), fc, fill=TXT, font=FB(15))
    for i, st in enumerate(states):
        oy = 64 + i*sh; px, py = P3[st]["pivot"]; w, h = P3[st]["cell"]
        d.text((6, oy + sh//2 - 8), st, fill=TXT, font=FB(14))
        for j, fc in enumerate("SWNE"):
            ox = lw + j*sw; fx, fy = ox + 5 + L, oy + 4 + U; x0, y0 = fx - px, fy - py
            d.rectangle([x0, y0, x0 + w - 1, y0 + h - 1], fill=(84, 98, 76), outline=(140, 140, 140))
            im = fr("v3", st, fc, 0); c.paste(im, (x0, y0), im); d = ImageDraw.Draw(c)
            d.line([(ox + 2, fy), (ox + sw - 4, fy)], fill=(255, 60, 60), width=1); d.line([(fx, fy - 6), (fx, fy + 6)], fill=(255, 60, 60), width=1)
            m = np.array(im)[..., 3] > 0; s = int(np.where(m.any(1))[0].max()); xs = np.where(m.any(0))[0]
            d.line([(x0 + xs.min(), y0 + s), (x0 + xs.max(), y0 + s)], fill=(255, 230, 0), width=1)
            d.text((x0 + 4, y0 + h + 2), f"sole {s - py:+d}" + (" (stride toe)" if s - py > 1 else ""), fill=(255, 230, 0) if abs(s - py) > 1 else TXT, font=F(12))
    return c

if __name__ == "__main__":
    for name, im in [("ironjaw_v3_before_after.jpg", before_after()), ("ironjaw_v3_sheet.jpg", sheet())]:
        if im.width > 1800: im = im.resize((1800, round(im.height*1800/im.width)), Image.LANCZOS)
        print(name, im.size, save_jpg(im, f"{OUT}/{name}"))
