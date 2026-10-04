#!/usr/bin/env python3
"""Pictures for the PC character import check (lineup, per-character sheets, issue pictures).
Read-only on /workspace/art. Output: /workspace/luca_pics/chars/*.jpg (<300 KB each)."""
import os, sys, io
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_chars import CLAIM, FACINGS, load, mask, sole_row, bbox
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ART = "/workspace/art"; OUT = "/workspace/luca_pics/chars"
REF = "/workspace/stasium-pc-look/refs/ironjaw_tall/ironjaw_tall_idle_s.png"
F = lambda s: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", s)
FB = lambda s: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", s)
BG = (92, 112, 78); GRID = (128, 150, 108); TXT = (245, 240, 220)
os.makedirs(OUT, exist_ok=True)

def frame(name, st, fc, i=0):
    return Image.open(f"{ART}/{CLAIM[name]['dir']}/{st}/{name}_{st}_{fc}_f{i:02d}.png").convert("RGBA")

def piv(name, st, fc): return CLAIM[name]["states"][st][3][fc]

def save_jpg(im, path, maxkb=290):
    q = 90
    while True:
        b = io.BytesIO(); im.convert("RGB").save(b, "JPEG", quality=q, optimize=True)
        if b.tell() <= maxkb*1024 or q <= 40: break
        q -= 5
    open(path, "wb").write(b.getvalue()); return b.tell()//1024, q

def iso_grid(d, w, h, ox, oy, tw, th, color=GRID):
    # diamonds centred on (ox + (i-j)*tw/2, oy + (i+j)*th/2)
    for i in range(-40, 40):
        for j in range(-40, 40):
            cx = ox + (i - j)*tw/2; cy = oy + (i + j)*th/2
            if -tw < cx < w + tw and -th < cy < h + th:
                d.polygon([(cx, cy - th/2), (cx + tw/2, cy), (cx, cy + th/2), (cx - tw/2, cy)], outline=color)

def paste_scaled(canvas, im, pivot, feet_xy, s):
    w, h = im.size
    im2 = im.resize((max(1, round(w*s)), max(1, round(h*s))), Image.LANCZOS)
    x = round(feet_xy[0] - pivot[0]*s); y = round(feet_xy[1] - pivot[1]*s)
    canvas.alpha_composite(im2, (x, y)); return (x, y, x + im2.width, y + im2.height)

def lineup(scale=0.5, Z=2):
    """Z = output magnification (2 -> tiles drawn 128x64, sprites at scale*2)."""
    chars = ["ironjaw", "kestrel", "gloam", "bastion", "mender"]
    W, H = 1820, 440
    c = Image.new("RGBA", (W, H), BG + (255,)); d = ImageDraw.Draw(c)
    tw, th = 64*Z, 32*Z; base_y = 330; x0 = 140
    iso_grid(d, W, H, x0, base_y, tw, th)
    d.text((14, 10), f"New fighter cells, idle S frame 0, one draw scale {scale} on the 64x32 combat board (shown x{Z}: tile 128x64). Feet on tile centres.", fill=TXT, font=F(19))
    d.text((14, 36), "Refs: ironjaw_tall at 0.33 (world walker, ~62 px) and today's shipped combat pawn (repo art/characters/ironjaw_e.png at 0.5).", fill=TXT, font=F(16))
    items = []
    for n in chars:
        items.append((n, frame(n, "idle", "S"), piv(n, "idle", "S"), scale))
    ref = Image.open(REF).convert("RGBA"); items.append(("ironjaw_tall @0.33 (world)", ref, (96, 216), 0.33))
    pawn = Image.open("/tmp/repoart/ironjaw_e.png").convert("RGBA") if os.path.exists("/tmp/repoart/ironjaw_e.png") else None
    if pawn is not None: items.append(("today's pawn ironjaw_e @0.5", pawn, (72, 151), 0.5))
    step = 2  # tiles apart along screen-x
    for k, (n, im, p, s) in enumerate(items):
        fx = x0 + k*step*tw; fy = base_y
        # tile highlight
        d.polygon([(fx, fy - th/2), (fx + tw/2, fy), (fx, fy + th/2), (fx - tw/2, fy)], fill=(110, 132, 92), outline=(200, 210, 170))
        bb = paste_scaled(c, im, p, (fx, fy), s*Z)
        m = mask(np.array(im)); b = bbox(m); hpx = (b[3] - b[1] + 1)
        d = ImageDraw.Draw(c)
        d.line([(fx - 6, fy), (fx + 6, fy)], fill=(255, 60, 60), width=2); d.line([(fx, fy - 6), (fx, fy + 6)], fill=(255, 60, 60), width=2)
        top = fy - (p[1] - b[1])*s*Z
        d.line([(fx + tw*0.62, top), (fx + tw*0.62, fy)], fill=(255, 230, 120), width=1)
        lab = n.split(" ")[0] if k < 5 else n
        d.text((fx - tw*0.9, fy + th*0.75), lab, fill=TXT, font=FB(17 if k < 5 else 13))
        d.text((fx - tw*0.9, fy + th*0.75 + 22), f"{hpx} px cell -> {hpx*s:.0f} px board", fill=TXT, font=F(14))
    # 10 px height step reference
    sx = 40
    d.line([(sx, base_y), (sx, base_y - 10*Z)], fill=(255, 230, 120), width=4); d.text((sx - 30, base_y + 6), "10 px\nheight step", fill=TXT, font=F(13))
    return c

def sheet(name, z=1.0):
    cfg = CLAIM[name]; states = list(cfg["states"])
    # uniform slot: max extents around the pivot
    L = R = U = D = 0
    for st in states:
        for fc in FACINGS:
            w, h = cfg["states"][st][2]; px, py = cfg["states"][st][3][fc]
            L, R, U, D = max(L, px), max(R, w - px), max(U, py), max(D, h - py)
    sw, sh = int((L + R)*z) + 8, int((U + D)*z) + 22
    lw = 92
    W, H = lw + 4*sw, 40 + len(states)*sh
    c = Image.new("RGBA", (W, H), (70, 82, 64, 255)); d = ImageDraw.Draw(c)
    d.text((8, 8), f"{name}: frame 0 per state x facing. Red = claimed pivot / feet line; yellow = lowest opaque row; grey box = cell", fill=TXT, font=F(15))
    for j, fc in enumerate(FACINGS): d.text((lw + j*sw + sw//2 - 6, 24), fc, fill=TXT, font=FB(14))
    for i, st in enumerate(states):
        oy = 40 + i*sh
        d.text((6, oy + sh//2 - 8), st, fill=TXT, font=FB(14))
        for j, fc in enumerate(FACINGS):
            ox = lw + j*sw
            px, py = cfg["states"][st][3][fc]
            im = frame(name, st, fc)
            fx, fy = ox + 4 + L*z, oy + 4 + U*z
            x0, y0 = round(fx - px*z), round(fy - py*z)
            d.rectangle([x0, y0, x0 + im.width*z - 1, y0 + im.height*z - 1], fill=(84, 98, 76), outline=(120, 120, 120))
            im2 = im if z == 1 else im.resize((round(im.width*z), round(im.height*z)), Image.LANCZOS)
            c.alpha_composite(im2, (x0, y0)); d = ImageDraw.Draw(c)
            d.line([(ox + 2, fy), (ox + sw - 2, fy)], fill=(255, 60, 60), width=1)
            d.line([(fx, fy - 5), (fx, fy + 5)], fill=(255, 60, 60), width=1)
            mm = mask(np.array(im)); s = sole_row(mm); bx = bbox(mm)
            ys = y0 + s*z
            d.line([(x0 + bx[0]*z, ys), (x0 + bx[2]*z, ys)], fill=(255, 230, 0), width=1)
            d.text((ox + 4, oy + sh - 18), f"sole {s - py:+d}", fill=(255, 230, 0) if abs(s - py) > 3 else TXT, font=F(12))
    return c

def run():
    out = {}
    out["lineup.jpg"] = save_jpg(lineup(), f"{OUT}/lineup.jpg")
    for n in CLAIM:
        z = 1.0 if n != "kestrel" else 0.85
        im = sheet(n, z)
        if im.width > 1800: im = im.resize((1800, round(im.height*1800/im.width)), Image.LANCZOS)
        out[f"{n}_sheet.jpg"] = save_jpg(im, f"{OUT}/{n}_sheet.jpg")
    for k, v in out.items(): print(k, v)

if __name__ == "__main__":
    run()

# ---------------- issue pictures ----------------
def tint(im, rgb, a=0.55):
    arr = np.array(im).astype(float); m = arr[..., 3] > 127
    arr[..., :3][m] = arr[..., :3][m]*(1 - a) + np.array(rgb)*a
    return Image.fromarray(arr.astype(np.uint8))

def overlay_pair(n1, s1, f1, i1, n2, s2, f2, i2, z=2, label=""):
    a = frame(n1, s1, f1, i1); b = frame(n2, s2, f2, i2)
    pa, pb = piv(n1, s1, f1), piv(n2, s2, f2)
    L = max(pa[0], pb[0]); R = max(a.width - pa[0], b.width - pb[0]); U = max(pa[1], pb[1]); D = max(a.height - pa[1], b.height - pb[1])
    W, H = (L + R)*z + 20, (U + D)*z + 50
    c = Image.new("RGBA", (W, H), (70, 82, 64, 255)); d = ImageDraw.Draw(c)
    fx, fy = 10 + L*z, 36 + U*z
    for im, p, col in [(a, pa, (255, 80, 80)), (b, pb, (80, 220, 255))]:
        t = tint(im, col, 0.45).resize((im.width*z, im.height*z), Image.NEAREST)
        t.putalpha(Image.fromarray((np.array(t)[..., 3] > 0).astype(np.uint8)*150))
        c.alpha_composite(t, (fx - p[0]*z, fy - p[1]*z))
    d = ImageDraw.Draw(c)
    d.line([(0, fy), (W, fy)], fill=(255, 255, 0), width=1); d.line([(fx, fy - 8), (fx, fy + 8)], fill=(255, 255, 0), width=2)
    d.text((6, 4), label, fill=TXT, font=F(14))
    d.text((6, 20), f"red {s1} {f1} f{i1} / cyan {s2} {f2} f{i2}", fill=TXT, font=F(12))
    return c

def row(ims, gap=8, bg=(50, 58, 46)):
    W = sum(i.width for i in ims) + gap*(len(ims) - 1); H = max(i.height for i in ims)
    c = Image.new("RGBA", (W, H), bg + (255,)); x = 0
    for i in ims: c.alpha_composite(i.convert("RGBA"), (x, 0)); x += i.width + gap
    return c

def col(ims, gap=8, bg=(50, 58, 46)):
    W = max(i.width for i in ims); H = sum(i.height for i in ims) + gap*(len(ims) - 1)
    c = Image.new("RGBA", (W, H), bg + (255,)); y = 0
    for i in ims: c.alpha_composite(i.convert("RGBA"), (0, y)); y += i.height + gap
    return c

def facing_turn(name, z=1.5):
    """4 facings of idle f0 drawn on one feet point (claimed pivot)."""
    ims = []
    for fc in FACINGS:
        im = frame(name, "idle", fc); p = piv(name, "idle", fc)
        m = mask(np.array(im)); b = bbox(m); s = b[3]
        W, H = int(180*z), int(200*z)
        c = Image.new("RGBA", (W, H), (70, 82, 64, 255)); d = ImageDraw.Draw(c)
        fx, fy = W//2, int(170*z)
        im2 = im.resize((round(im.width*z), round(im.height*z)), Image.LANCZOS)
        c.alpha_composite(im2, (round(fx - p[0]*z), round(fy - p[1]*z))); d = ImageDraw.Draw(c)
        d.line([(0, fy), (W, fy)], fill=(255, 60, 60), width=1)
        ys = round(fy + (s - p[1])*z); d.line([(fx - 40*z, ys), (fx + 40*z, ys)], fill=(255, 230, 0), width=1)
        yt = round(fy - (p[1] - b[1])*z); d.line([(fx - 40*z, yt), (fx + 40*z, yt)], fill=(255, 230, 0), width=1)
        d.text((4, 4), f"{name} idle {fc}", fill=TXT, font=FB(13))
        d.text((4, H - 18), f"sole {s - p[1]:+d}  h {b[3] - b[1] + 1}", fill=(255, 230, 0), font=F(13))
        ims.append(c)
    return row(ims, 4)

def labelbar(text, w, size=15):
    c = Image.new("RGBA", (w, size + 12), (30, 34, 28, 255)); ImageDraw.Draw(c).text((6, 4), text, fill=TXT, font=FB(size)); return c

def clamp_w(im, w=1800):
    return im if im.width <= w else im.resize((w, round(im.height*w/im.width)), Image.LANCZOS)

def issues():
    out = {}
    # 1. turning in place: feet jump / size change
    rows = [facing_turn(n) for n in ["gloam", "bastion", "mender", "ironjaw", "kestrel"]]
    w = max(r.width for r in rows)
    pic = col([labelbar("Turning in place: idle f0, all 4 facings drawn on one feet point with the claimed pivots.", w, 14),
               labelbar("Red = pivot line, yellow = sole/head. Jumps: Gloam 8 px, Bastion 11-14 px, Mender 6 px (+11% taller backs). Ironjaw, Kestrel hold.", w, 13)] + rows, 4)
    out["issue_facing_turn_feet.jpg"] = save_jpg(clamp_w(pic), f"{OUT}/issue_facing_turn_feet.jpg")
    # 2. Mender hand swap (W = flip S, N = flip E)
    def pair(n, st, fa, fb, z=2):
        A = frame(n, st, fa); B = frame(n, st, fb)
        ims = []
        for im, fc in [(A, fa), (B, fb)]:
            c = Image.new("RGBA", (im.width*z, im.height*z + 24), (70, 82, 64, 255))
            c.alpha_composite(im.resize((im.width*z, im.height*z), Image.LANCZOS), (0, 24))
            ImageDraw.Draw(c).text((4, 4), f"{n} {st} {fc}", fill=TXT, font=FB(13)); ims.append(c)
        return row(ims, 4)
    pic = col([labelbar("Mender: W is a pixel flip of S and N is a flip of E, so the staff changes hands (right hand in S/E, left hand in W/N).", 1060, 14),
               row([pair("mender", "idle", "S", "W"), pair("mender", "idle", "E", "N")], 20)], 4)
    out["issue_mender_staff_hand_swap.jpg"] = save_jpg(clamp_w(pic), f"{OUT}/issue_mender_staff_hand_swap.jpg")
    # 3. Bastion death
    def death_row(fc, frames, z=1.5, crop_y=50):
        ims = []
        for i in frames:
            im = frame("bastion", "death", fc, i); p = piv("bastion", "death", fc)
            m = mask(np.array(im)); s = sole_row(m)
            c = Image.new("RGBA", im.size, (70, 82, 64, 255)); c.alpha_composite(im); c = c.crop((20, crop_y, im.width - 10, im.height))
            c = c.resize((round(c.width*z), round(c.height*z)), Image.LANCZOS); d = ImageDraw.Draw(c)
            d.line([(0, (p[1] - crop_y)*z), (c.width, (p[1] - crop_y)*z)], fill=(255, 60, 60), width=1)
            d.line([(0, (s - crop_y)*z), (c.width, (s - crop_y)*z)], fill=(255, 230, 0), width=1)
            d.text((4, 4), f"death {fc} f{i:02d}  lowest row {s} (pivot y {p[1]})", fill=(255, 230, 0) if abs(s - p[1]) > 2 else TXT, font=F(13))
            ims.append(c)
        return row(ims, 4)
    r1 = death_row("S", [2, 3, 4, 5]); r2 = death_row("E", [2, 3, 4]); r3 = death_row("W", [2, 3, 4])
    w = max(r1.width, r2.width, r3.width)
    pic = col([labelbar("Bastion death. S f03 cape 7 px under the floor (172 vs 165/166) and S f04-f05 body reads as floating above the dropped shield.", w, 14), r1,
               labelbar("W/N/E f03 sits on row 164-165 while f02 and f04 sit on 177-183: a 12-18 px vertical pop for one frame (W/N/E bodies also stand 10-15 px below the pivot).", w, 14), r2, r3], 4)
    out["issue_bastion_death.jpg"] = save_jpg(clamp_w(pic), f"{OUT}/issue_bastion_death.jpg")
    # 4. clipping at the cell edge
    def edge_crop(n, st, fc, i, box, z=4, txt=""):
        im = frame(n, st, fc, i); c = Image.new("RGBA", im.size, (70, 82, 64, 255)); c.alpha_composite(im)
        c = c.crop(box).resize(((box[2] - box[0])*z, (box[3] - box[1])*z), Image.NEAREST); d = ImageDraw.Draw(c)
        w, h = im.size
        # draw the cell edge(s) that fall in the crop
        if box[1] == 0: d.line([(0, 0), (c.width, 0)], fill=(255, 0, 0), width=3)
        if box[3] == h: d.line([(0, c.height - 2), (c.width, c.height - 2)], fill=(255, 0, 0), width=3)
        if box[2] == w: d.line([(c.width - 2, 0), (c.width - 2, c.height)], fill=(255, 0, 0), width=3)
        if box[0] == 0: d.line([(0, 0), (0, c.height)], fill=(255, 0, 0), width=3)
        lines = (txt or f"{n} {st} {fc} f{i:02d}").split("|")
        top = Image.new("RGBA", (max(c.width, 230), 18*len(lines) + 4), (30, 34, 28, 255))
        for k, ln in enumerate(lines): ImageDraw.Draw(top).text((4, 3 + 18*k), ln, fill=TXT, font=F(13))
        return col([top, c], 0)
    a = edge_crop("kestrel", "idle", "S", 1, (30, 0, 100, 26), 5, "kestrel idle S f01: hood flattened by the top edge")
    b = edge_crop("kestrel", "idle", "W", 0, (76, 40, 116, 140), 4, "kestrel idle W f00:|cape cut at right edge")
    c_ = edge_crop("mender", "death", "E", 5, (40, 140, 230, 179), 3, "mender death E f05: body cut by bottom edge (100 px on last row)")
    dd = edge_crop("ironjaw", "attack", "W", 2, (0, 30, 50, 110), 4, "ironjaw attack W f02:|axe on left edge (8 px)")
    pic = col([labelbar("Opaque pixels on the cell edge (red line = cell border). Kestrel 112/176 frames, Mender 10, Ironjaw 2.", 1300, 14), row([a, b, dd], 12), c_], 6)
    out["issue_edge_clipping.jpg"] = save_jpg(clamp_w(pic), f"{OUT}/issue_edge_clipping.jpg")
    # 5. idle -> walk pop (Kestrel S) and Mender idle vs walk (S)
    p1 = overlay_pair("kestrel", "idle", "S", 0, "kestrel", "walk", "S", 0, 2, "Kestrel S: walk f0 torso 10 px lower")
    p3 = overlay_pair("gloam", "idle", "S", 0, "gloam", "idle", "N", 0, 2, "Gloam: S feet 8 px under N")
    ims = []
    for st, fc in [("idle", "S"), ("walk", "S"), ("walk", "N"), ("idle", "N")]:
        im = frame("mender", st, fc); z = 2
        c = Image.new("RGBA", (130*z, 186*z), (70, 82, 64, 255)); c.alpha_composite(im.resize((im.width*z, im.height*z), Image.LANCZOS), (0, 0))
        d = ImageDraw.Draw(c); d.line([(0, 175*z), (c.width, 175*z)], fill=(255, 230, 0))
        d.text((4, 4), f"mender {st} {fc}", fill=TXT, font=FB(13)); ims.append(c)
    p2 = col([labelbar("Mender: S/W idle feet 7 px above pivot (yellow); back views ~11% taller", 4*260 + 12, 13), row(ims, 4)], 0)
    top = row([p1, p3], 10)
    pic = col([labelbar("Red = first frame, cyan = second, both placed on their pivots (yellow cross).", max(top.width, p2.width), 13), top, p2], 6)
    out["issue_idle_walk_pivot.jpg"] = save_jpg(clamp_w(pic), f"{OUT}/issue_idle_walk_pivot.jpg")
    for k, v in out.items(): print(k, v)

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "issues":
    issues()
