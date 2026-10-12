#!/usr/bin/env python
"""STASIUM XII  U0 v2 menu WINDOWS (opened state), built on the same kit as build_hud.py.

Each window is drawn natively at 1920x1080 design px (no scaling) into a transparent RGBA layer with Pillow + Nunito,
then composited (with a soft drop shadow) over a real game frame together with the normal HUD, with that window's
menu button shown active (gold trim).  Everything comes from build_hud.Kit (panel 9-slice, title_bar, slot, buttons,
checkbox, xp bar, pill) + THEMES palette + draw_text helpers.

  python build_panels.py --panel all                      # all windows x {dark,light}, win_*.png, contact_panels.png
  python build_panels.py --panel inventory_equipment --variant dark
  python build_panels.py --panel map --frame frames/real_crosshaven_frame.jpg --variant light
Windows: inventory_equipment (I, combined Inventory+Equipment), character_stats (O, same window, Stats tab),
         spells (P), quests (L), map (M), dungeons, koliseo, shop, settings (Esc)
Output: out/panels/panel_<name>_<variant>_1920x1080.png, out/panels/win_<name>_<variant>.png, out/panels/contact_panels.png
"""
import argparse, glob, math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import build_hud as B
from build_hud import hx, draw_text, tlen, nine, box_piece, fit, tint, glyph, GOLD, ACCENT_OK, ACCENT_MAIN, HP_RED, XP_TEAL

HERE = B.HERE
SS = 4
CLASS_ART = os.path.join(HERE, "..", "..", "charselect", "ship", "class_art_ironjaw_m.png")
# assets/items/*.png are scrambled (see README); map by what each file SHOWS
ITEM_FILE = {"potion_red": "potion_red", "potion_blue": "potion_blue", "bread": "bread", "rope": "herbs",
             "bandage": "pickaxe", "quest_scroll": "rope", "pickaxe": "scroll"}

def mix(a, b, t):
    a, b = np.array(hx(a), float), np.array(hx(b), float); c = a * (1 - t) + b * t
    return "#%02x%02x%02x" % tuple(int(round(v)) for v in c)

# ================================================================= tiny painter for drawn item / glyph icons
class P:
    """Draws flat-gradient icons on a 64-unit grid at 4x supersampling, dark outline, then downsamples."""
    def __init__(s):
        s.f = SS * 2; s.W = 64 * s.f; s.im = Image.new("RGBA", (s.W, s.W), (0, 0, 0, 0))
    def pts(s, p): return [(x * s.f, y * s.f) for x, y in p]
    def _fill(s, m, c1, c2):
        bb = m.getbbox()
        if not bb: return
        t = np.clip((np.arange(s.W) - bb[1]) / max(1, bb[3] - bb[1]), 0, 1)[:, None, None]
        a, b = np.array(hx(c1), float), np.array(hx(c2 or c1), float)
        rgb = np.broadcast_to(a * (1 - t) + b * t, (s.W, s.W, 3))
        layer = Image.fromarray(np.dstack([rgb, np.zeros((s.W, s.W))]).astype(np.uint8), "RGBA"); layer.putalpha(m)
        s.im.alpha_composite(layer)
    def poly(s, p, c1, c2=None, out="#1b1612", ow=1.4):
        m = Image.new("L", (s.W, s.W), 0); ImageDraw.Draw(m).polygon(s.pts(p), fill=255); s._fill(m, c1, c2)
        if out: ImageDraw.Draw(s.im).line(s.pts(list(p) + [p[0]]), fill=hx(out) + (255,), width=int(ow * s.f), joint="curve")
    def ell(s, box, c1, c2=None, out="#1b1612", ow=1.4):
        m = Image.new("L", (s.W, s.W), 0); ImageDraw.Draw(m).ellipse([v * s.f for v in box], fill=255); s._fill(m, c1, c2)
        if out: ImageDraw.Draw(s.im).ellipse([v * s.f for v in box], outline=hx(out) + (255,), width=int(ow * s.f))
    def line(s, p, col, w=1.5, a=255):
        ImageDraw.Draw(s.im).line(s.pts(p), fill=hx(col) + (a,), width=max(1, int(w * s.f)), joint="curve")
    def hole(s, box, out="#1b1612", ow=1.2):
        d = ImageDraw.Draw(s.im); d.ellipse([v * s.f for v in box], fill=(0, 0, 0, 0))
        if out: d.ellipse([v * s.f for v in box], outline=hx(out) + (255,), width=int(ow * s.f))
    def rot(s, deg): s.im = s.im.rotate(deg, resample=Image.BICUBIC)
    def paste(s, other, deg=0):
        o = other.im.rotate(deg, resample=Image.BICUBIC) if deg else other.im; s.im.alpha_composite(o)
    def done(s, n=96, crop=False):
        im = s.im
        if crop:
            bb = im.getbbox(); im = im.crop(bb); m = int(max(im.size) * 1.0); sq = Image.new("RGBA", (m, m), (0, 0, 0, 0))
            sq.alpha_composite(im, ((m - im.width) // 2, (m - im.height) // 2)); im = sq
            pad = int(m * 0.06); big = Image.new("RGBA", (m + 2 * pad, m + 2 * pad), (0, 0, 0, 0)); big.alpha_composite(im, (pad, pad)); im = big
        return im.resize((n, n), Image.LANCZOS)

def _axe():
    p = P()
    p.poly([(30, 8), (34, 8), (34, 61), (30, 61)], "#8a5a33", "#5a3820")
    p.poly([(34, 8), (54, 3), (59, 17), (54, 31), (34, 26)], "#cfd6db", "#8b979f")
    p.poly([(34, 8), (54, 3), (56, 9), (34, 14)], "#f4f8fa", "#cfd6db", out=None)
    p.poly([(30, 15), (21, 19), (30, 23)], "#aab4bb", "#7a868e")
    p.poly([(29, 52), (35, 52), (35, 56), (29, 56)], "#d9ae52", "#a77c2a", ow=1)
    return p

def sword(blade="#dfe6ea", guard="#d9ae52"):
    p = P()
    p.poly([(32, 2), (38, 10), (38, 41), (26, 41), (26, 10)], blade, mix(blade, "#000000", .32))
    p.line([(32, 8), (32, 38)], mix(blade, "#000000", .35), 1.2); p.line([(29.2, 12), (29.2, 38)], "#ffffff", .8, 160)
    p.poly([(17, 41), (47, 41), (47, 46), (17, 46)], guard, mix(guard, "#000000", .35))
    p.poly([(29, 46), (35, 46), (35, 57), (29, 57)], "#7a4a2a", "#4f2f18", ow=1)
    p.ell((28, 55, 36, 63), guard, mix(guard, "#000000", .35), ow=1)
    p.rot(-45); return p.done(crop=True)

def twin_axes():
    a = _axe(); p = P(); p.paste(a, 28); p.paste(a, -28)
    # mirror right axe so heads face outwards
    p2 = P(); l = a.im.rotate(-30, resample=Image.BICUBIC); r = a.im.transpose(Image.FLIP_LEFT_RIGHT).rotate(30, resample=Image.BICUBIC)
    p2.im.alpha_composite(l); p2.im.alpha_composite(r); return p2.done(crop=True)

def axe_single():
    p = _axe(); p.rot(-25); return p.done(crop=True)

def gem(base="#d04848"):
    p = P(); L, D, M = mix(base, "#ffffff", .5), mix(base, "#000000", .42), base
    p.poly([(32, 58), (7, 26), (18, 10), (46, 10), (57, 26)], M, D)
    p.poly([(7, 26), (18, 10), (46, 10), (57, 26)], L, M, out=None)
    p.poly([(7, 26), (32, 26), (32, 58)], M, D, out=None)
    p.poly([(57, 26), (32, 26), (32, 58)], mix(base, "#000000", .15), mix(base, "#000000", .55), out=None)
    for ln in ([(7, 26), (57, 26)], [(18, 10), (25, 26), (32, 10)], [(46, 10), (39, 26), (32, 10)], [(25, 26), (32, 58), (39, 26)]):
        p.line(ln, mix(base, "#ffffff", .65), .9, 150)
    p.poly([(14, 24), (20, 14), (25, 14), (20, 24)], "#ffffff", "#ffffff", out=None)
    return p.done()

def ore(spot="#c97a3c"):
    p = P()
    p.poly([(8, 46), (6, 30), (16, 16), (32, 10), (48, 14), (58, 30), (56, 46), (42, 56), (20, 56)], "#9aa3a6", "#59636a")
    p.poly([(16, 16), (32, 10), (40, 26), (24, 30)], "#c7cdd0", "#9aa3a6", out=None)
    p.poly([(40, 26), (48, 14), (58, 30), (50, 40)], "#7d878c", "#59636a", out=None)
    for (x, y, r) in [(22, 42, 5), (38, 44, 6), (46, 30, 4)]:
        p.poly([(x - r, y), (x, y - r), (x + r, y), (x, y + r)], mix(spot, "#ffffff", .35), spot, ow=1)
    return p.done()

def leaf(c="#58b04a"):
    p = P()
    p.poly([(10, 56), (14, 30), (28, 12), (50, 8), (54, 30), (40, 50)], mix(c, "#ffffff", .2), mix(c, "#000000", .38))
    p.line([(12, 54), (30, 32), (48, 12)], mix(c, "#ffffff", .6), 1.4, 200)
    for (a, b) in [((22, 40), (22, 28)), ((30, 31), (40, 34)), ((36, 23), (36, 14)), ((26, 36), (34, 44))]: p.line([a, b], mix(c, "#ffffff", .5), 1, 140)
    return p.done()

def log_():
    p = P()
    p.poly([(6, 20), (46, 16), (46, 50), (6, 46)], "#a7743f", "#6b4425")
    for y in (26, 33, 40): p.line([(10, y - 3), (44, y - 5)], "#5a3820", 1, 150)
    p.ell((38, 14, 58, 52), "#d9ae78", "#b78750")
    p.ell((43, 24, 53, 42), "#c4975d", "#c4975d", out="#7a5230", ow=1); p.ell((46, 30, 50, 36), "#8a5f36", "#8a5f36", out=None)
    return p.done()

def key_item():
    p = P()
    p.poly([(26, 28), (58, 28), (58, 34), (54, 34), (54, 40), (49, 40), (49, 34), (44, 34), (44, 41), (39, 41), (39, 34), (26, 34)], "#f0cf72", "#b88a2c")
    p.ell((4, 17, 30, 45), "#f0cf72", "#b88a2c"); p.hole((11, 25, 22, 37))
    p.rot(35); return p.done(crop=True)

def shield(c="#4a7fb0"):
    p = P()
    p.poly([(32, 60), (8, 42), (8, 10), (32, 5), (56, 10), (56, 42)], mix(c, "#ffffff", .25), mix(c, "#000000", .35))
    p.poly([(32, 54), (13, 40), (13, 14), (32, 10), (51, 14), (51, 40)], c, mix(c, "#000000", .25), out=None)
    p.line([(32, 11), (32, 52)], "#d9ae52", 3.2); p.line([(14, 26), (50, 26)], "#d9ae52", 3.2)
    p.ell((26, 20, 38, 32), "#f0cf72", "#b88a2c", ow=1)
    return p.done()

def helm(c="#aab4bb"):
    p = P()
    p.poly([(10, 36), (12, 18), (22, 8), (32, 5), (42, 8), (52, 18), (54, 36), (54, 54), (43, 54), (43, 44), (21, 44), (21, 54), (10, 54)], mix(c, "#ffffff", .3), mix(c, "#000000", .38))
    p.poly([(21, 30), (43, 30), (43, 38), (21, 38)], "#1b1612", "#2b2520", out=None)
    p.poly([(29, 5), (35, 5), (35, 30), (29, 30)], "#c04a3a", "#8a2a20", ow=1)
    return p.done()

def chest(c="#8a6a48"):
    p = P()
    p.poly([(13, 8), (24, 13), (40, 13), (51, 8), (60, 22), (51, 30), (51, 57), (13, 57), (13, 30), (4, 22)], mix(c, "#ffffff", .22), mix(c, "#000000", .38))
    p.line([(32, 14), (32, 56)], mix(c, "#000000", .5), 1.4); p.poly([(13, 42), (51, 42), (51, 48), (13, 48)], "#5a3820", "#3e2814", ow=1)
    p.ell((28, 41, 36, 49), "#f0cf72", "#b88a2c", ow=1)
    return p.done()

def boots(c="#8a5a33"):
    p = P()
    p.poly([(20, 6), (40, 6), (41, 36), (58, 44), (59, 56), (16, 56), (16, 40)], mix(c, "#ffffff", .22), mix(c, "#000000", .4))
    p.poly([(16, 52), (59, 52), (59, 58), (16, 58)], "#2b2520", "#1b1612", ow=1)
    p.line([(20, 16), (40, 16)], mix(c, "#000000", .55), 1.4); p.line([(20, 23), (40, 23)], mix(c, "#000000", .55), 1.4)
    return p.done()

def gloves(c="#8a6a48"):
    p = P()
    p.poly([(17, 58), (13, 32), (17, 14), (23, 28), (26, 8), (31, 26), (35, 6), (40, 26), (44, 12), (45, 32), (55, 40), (50, 58)], mix(c, "#ffffff", .25), mix(c, "#000000", .4))
    p.poly([(17, 50), (50, 50), (50, 58), (17, 58)], "#d9ae52", "#a77c2a", ow=1)
    return p.done()

def belt(c="#7a4a2a"):
    p = P()
    p.poly([(4, 24), (60, 24), (60, 40), (4, 40)], mix(c, "#ffffff", .2), mix(c, "#000000", .4))
    p.poly([(24, 19), (40, 19), (40, 45), (24, 45)], "#f0cf72", "#b88a2c"); p.poly([(29, 25), (35, 25), (35, 39), (29, 39)], "#5a3820", "#3e2814", out=None)
    return p.done()

def cape(c="#b8453a"):
    p = P()
    p.poly([(20, 5), (44, 5), (58, 58), (6, 58)], mix(c, "#ffffff", .2), mix(c, "#000000", .42))
    p.line([(26, 14), (20, 56)], mix(c, "#000000", .5), 1.2); p.line([(38, 14), (44, 56)], mix(c, "#000000", .5), 1.2); p.line([(32, 14), (32, 56)], mix(c, "#000000", .5), 1.2)
    p.poly([(18, 5), (46, 5), (44, 12), (20, 12)], "#d9ae52", "#a77c2a", ow=1)
    return p.done()

def ring(stone="#d04848"):
    p = P()
    p.ell((10, 18, 54, 62), "#f0cf72", "#b88a2c"); p.hole((19, 27, 45, 53))
    p.poly([(32, 4), (41, 13), (32, 22), (23, 13)], mix(stone, "#ffffff", .3), stone, ow=1.2)
    return p.done()

def amulet(stone="#3aa6a6"):
    p = P()
    p.line([(8, 6), (20, 30), (32, 40), (44, 30), (56, 6)], "#d9ae52", 2.2)
    p.ell((20, 36, 44, 60), "#f0cf72", "#b88a2c"); p.ell((25, 41, 39, 55), mix(stone, "#ffffff", .3), stone, ow=1)
    return p.done()

def trinket(c="#9a62e0"):
    p = P()
    p.ell((8, 8, 56, 56), "#d9ae52", "#a77c2a")
    cx, cy = 32, 32; st = []
    for i in range(10):
        r = 17 if i % 2 == 0 else 7.5; a = -math.pi / 2 + i * math.pi / 5; st.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    p.poly(st, mix(c, "#ffffff", .45), c, ow=1.1)
    return p.done()

def paw():
    p = P(); c1, c2 = "#e8e2d4", "#b6ae9a"
    p.ell((18, 34, 46, 58), c1, c2)
    for (x, y) in [(10, 28), (22, 14), (38, 14), (50, 28)]: p.ell((x - 6, y - 8, x + 6, y + 8), c1, c2)
    return p.done()

def horseshoe():
    p = P()
    p.ell((8, 6, 56, 58), "#cfd6db", "#8b979f"); p.hole((19, 6, 45, 44))
    for (x, y) in [(12, 36), (14, 22), (20, 12), (44, 12), (50, 22), (52, 36)]: p.ell((x - 1.6, y - 1.6, x + 1.6, y + 1.6), "#1b1612", "#1b1612", out=None)
    return p.done()

def coin(px=16):
    p = P()
    p.ell((3, 3, 61, 61), "#f4d878", "#c4902c", ow=2); p.ell((12, 12, 52, 52), "#d9ae52", "#e8c460", out="#8a6420", ow=1.6)
    p.line([(32, 20), (32, 44)], "#8a6420", 3.2); p.line([(26, 25), (38, 25)], "#8a6420", 2.6); p.line([(26, 39), (38, 39)], "#8a6420", 2.6)
    return p.done(px * 3).resize((px, px), Image.LANCZOS)

def hue_shift(img, deg, sat=1.0):
    r, g, b, a = img.convert("RGBA").split()
    h, s, v = Image.merge("RGB", (r, g, b)).convert("HSV").split()
    h = h.point(lambda x: (x + int(deg / 360 * 255)) % 256); s = s.point(lambda x: min(255, int(x * sat)))
    out = Image.merge("HSV", (h, s, v)).convert("RGB").convert("RGBA"); out.putalpha(a); return out

_items = {}
def item_img(key):
    """Returns a ~96px RGBA icon for an item key (painted asset, hue variant, or drawn)."""
    if key in _items: return _items[key]
    def painted(nm): return Image.open(os.path.join(HERE, "assets", "items", ITEM_FILE[nm] + ".png")).convert("RGBA")
    def pad(im): return fit(im, 96)
    D = {
      "potion_red": lambda: painted("potion_red"), "potion_blue": lambda: painted("potion_blue"),
      "potion_green": lambda: hue_shift(painted("potion_red"), 105), "potion_purple": lambda: hue_shift(painted("potion_blue"), 50),
      "potion_orange": lambda: hue_shift(painted("potion_red"), 22, .9), "potion_cyan": lambda: hue_shift(painted("potion_blue"), -22, .9),
      "bread": lambda: painted("bread"), "rope": lambda: painted("rope"), "bandage": lambda: painted("bandage"),
      "scroll": lambda: painted("quest_scroll"), "scroll_blue": lambda: hue_shift(painted("quest_scroll"), 150),
      "pickaxe": lambda: painted("pickaxe"),
      "gem_red": lambda: gem("#d04848"), "gem_green": lambda: gem("#3fae5a"), "gem_blue": lambda: gem("#4a8fe0"),
      "gem_yellow": lambda: gem("#e0b23a"), "gem_purple": lambda: gem("#9a62e0"), "gem_white": lambda: gem("#cfe0e6"), "gem_teal": lambda: gem("#3aa6a6"),
      "sword": lambda: sword(), "sword_gold": lambda: sword("#f0d887", "#8a5a33"), "sword_teal": lambda: sword("#9fe0dc", "#d9ae52"),
      "axe": axe_single, "axes": twin_axes, "shield": lambda: shield(), "shield_red": lambda: shield("#b8453a"),
      "ore": lambda: ore(), "ore_teal": lambda: ore("#3aa6a6"), "ore_gold": lambda: ore("#f0cf72"),
      "leaf": lambda: leaf(), "leaf_teal": lambda: leaf("#3aa6a6"), "leaf_gold": lambda: leaf("#d6a83e"), "log": log_, "key": key_item,
      "helm": lambda: helm(), "chest": lambda: chest(), "boots": lambda: boots(), "gloves": lambda: gloves(), "belt": lambda: belt(),
      "cape": lambda: cape(), "ring": lambda: ring(), "ring_blue": lambda: ring("#4a8fe0"), "amulet": lambda: amulet(), "trinket": lambda: trinket(),
      "paw": paw, "horseshoe": horseshoe,
    }
    im = D[key](); im = pad(im) if im.width != 96 else im; _items[key] = im; return im

# ================================================================= UI helper bound to one window layer
def g2(name, px, color, lw=1.8):
    """extra glyphs (x, star, lock, help, funnel, arrows) drawn at 4x then downsampled; px = output size"""
    W = px * SS; im = Image.new("RGBA", (W, W), hx(color) + (0,)); d = ImageDraw.Draw(im); c = hx(color) + (255,); u = W / 16; L = max(2, int(lw * SS * px / 16))
    if name == "x":
        d.line([(4 * u, 4 * u), (12 * u, 12 * u)], fill=c, width=L); d.line([(12 * u, 4 * u), (4 * u, 12 * u)], fill=c, width=L)
    elif name == "star":
        pts = []
        for i in range(10):
            r = 7.2 if i % 2 == 0 else 3.0; a = -math.pi / 2 + i * math.pi / 5; pts.append((8 * u + r * u * math.cos(a), 8.4 * u + r * u * math.sin(a)))
        d.polygon(pts, fill=c)
    elif name == "lock":
        d.rounded_rectangle((3.5 * u, 7 * u, 12.5 * u, 14 * u), radius=1.2 * u, fill=c)
        d.arc((5 * u, 2 * u, 11 * u, 10 * u), 180, 360, fill=c, width=L)
        d.line([(5 * u, 6 * u), (5 * u, 8 * u)], fill=c, width=L); d.line([(11 * u, 6 * u), (11 * u, 8 * u)], fill=c, width=L)
    elif name == "funnel":
        d.polygon([(2 * u, 3.5 * u), (14 * u, 3.5 * u), (9.2 * u, 9 * u), (9.2 * u, 13.5 * u), (6.8 * u, 12 * u), (6.8 * u, 9 * u)], fill=c)
    elif name == "arrow_l":
        d.polygon([(10.5 * u, 3 * u), (4 * u, 8 * u), (10.5 * u, 13 * u)], fill=c)
    elif name == "arrow_r":
        d.polygon([(5.5 * u, 3 * u), (12 * u, 8 * u), (5.5 * u, 13 * u)], fill=c)
    elif name == "arrow_exit":
        d.polygon([(8 * u, 1 * u), (14.5 * u, 9 * u), (10 * u, 9 * u), (10 * u, 15 * u), (6 * u, 15 * u), (6 * u, 9 * u), (1.5 * u, 9 * u)], fill=c)
    elif name == "eye":
        d.ellipse((1.5 * u, 4.5 * u, 14.5 * u, 11.5 * u), outline=c, width=L); d.ellipse((6 * u, 6 * u, 10 * u, 10 * u), fill=c)
    elif name == "tick":
        d.line([(3 * u, 8.5 * u), (6.5 * u, 12 * u), (13 * u, 4 * u)], fill=c, width=L + SS, joint="curve")
    return im.resize((px, px), Image.LANCZOS)

BTN_STROKE = {"green": "#1f6a33", "orange": "#7a4a10"}

class Ui:
    def __init__(s, variant, w, h):
        B.TEXT_K = 1
        s.v, s.dark = variant, variant == "dark"
        s.k = B.Kit(variant, 1.0); s.t = s.k.t; s.w, s.h = w, h
        s.L = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        s.text_c, s.dim = s.t["text"], s.t["dim"]
        s.good = "#5cd07a" if s.dark else "#23803c"; s.warn = "#f0a04b" if s.dark else "#b8650f"; s.bad = "#ef6b6b" if s.dark else "#b83a3a"
        s.teal = "#6fd0d0" if s.dark else "#1f6f70"
        s._pc = {}
    # ---- low level
    def put(s, img, x, y):
        x, y = int(x), int(y)
        cx, cy = max(0, -x), max(0, -y)
        if cx or cy: img = img.crop((cx, cy, img.width, img.height))
        s.L.alpha_composite(img, (x + cx, y + cy))
    def T(s, x, y, txt, px=13, wt=600, col=None, anchor="lm", **kw):
        draw_text(s.L, (x, y), txt, px, wt, col or s.text_c, anchor, **kw)
    def tl(s, txt, px=13, wt=600): return tlen(txt, px, wt)
    def wrap(s, txt, px, wt, maxw):
        lines, cur = [], ""
        for w_ in txt.split():
            t2 = (cur + " " + w_).strip()
            if tlen(t2, px, wt) <= maxw: cur = t2
            else: lines.append(cur); cur = w_
        if cur: lines.append(cur)
        return lines
    def nine(s, name, w, h): return nine_(s.k.pieces[name], s.k.meta[name]["nine_slice"], (int(w), int(h)))
    # ---- kit pieces
    def panel(s, x, y, w, h): s.put(s.nine("panel_9slice", w, h), x, y)
    def title(s, x, y, w, text, close="dark", help=False, h=30):
        s.put(s.nine("title_bar", w - 2, h), x + 1, y + 1)
        s.T(x + w // 2, y + 1 + h // 2, text, 16, 700, "#f1ece2", "mm")
        if close:
            s.btn(x + w - 8 - 22, y + 1 + (h - 22) // 2, 22, 22, None, "green" if close == "green" else "dark", glyph_img=g2("x", 14, "#ffffff" if close == "green" else s.t["icon"], 2.0))
        if help:
            s.btn(x + 8, y + 1 + (h - 22) // 2, 22, 22, "?", "dark", px=13)
    def btn(s, x, y, w, h, label=None, kind="dark", px=13, glyph_img=None, wt=800):
        piece = {"dark": "button_dark", "active": "button_dark_active", "green": "button_green", "orange": "button_orange"}[kind]
        s.put(s.nine(piece, w, h), x, y)
        if glyph_img is not None: s.put(glyph_img, x + (w - glyph_img.width) // 2, y + (h - glyph_img.height) // 2)
        if label:
            if kind in ("green", "orange"): s.T(x + w // 2, y + h // 2, label, px, wt, "#ffffff", "mm", stroke=BTN_STROKE[kind], sw=1)
            else: s.T(x + w // 2, y + h // 2, label, px, wt, s.text_c, "mm")
    def tab(s, x, y, w, h, label, active=False, px=13): s.btn(x, y, w, h, label, "active" if active else "dark", px)
    def cache(s, key, fn):
        if key not in s._pc: s._pc[key] = fn()
        return s._pc[key]
    def inset(s, x, y, w, h, r=5, a=None, border=None, bw=1):
        t = s.t
        p = s.cache(("inset", w, h, r, a, border, bw), lambda: box_piece(int(w), int(h), r, t["slot_fill"], t["slot_fill"], a if a is not None else t["slot_a"], border or t["slot_border"], bw, "#000000", 2, 0.35 if s.dark else 0.12))
        s.put(p, x, y)
    def sub(s, x, y, w, h, r=5, border=None, bw=1, a=0.38):
        t = s.t
        p = s.cache(("sub", w, h, r, border, bw, a), lambda: box_piece(int(w), int(h), r, t["slot_fill"], t["slot_fill"], a, border or t["slot_border"], bw))
        s.put(p, x, y)
    def slot(s, x, y, item=None, rar="normal", count=0, sel=False, size=44, ghost=None, ipx=None):
        t = s.t
        if sel: border, bw = GOLD, 2
        elif item and rar != "normal": border, bw = B.RARITY[rar], 2
        else: border, bw = t["slot_border"], 1
        p = s.cache(("slot", size, border, bw, sel), lambda: box_piece(size, size, 5, t["slot_fill"], t["slot_fill"], t["slot_a"], border, bw,
                                                                       GOLD if sel else "#000000", 2, 0.30 if sel else (0.35 if s.dark else 0.12)))
        s.put(p, x, y)
        ip = ipx or int(round(size * 0.78))
        if item:
            im = fit(item_img(item), ip); s.put(im, x + (size - im.width) // 2, y + (size - im.height) // 2)
        elif ghost:
            im = fit(item_img(ghost), ip); im = tint(im, t["dim"]); im.putalpha(im.split()[3].point(lambda v: int(v * 0.30)))
            s.put(im, x + (size - im.width) // 2, y + (size - im.height) // 2)
        if count > 1: s.T(x + 4, y + 7, str(count), 10, 800, s.text_c if s.dark else "#fffaf0", "lm", stroke="#14191b", sw=1)
    def field(s, x, y, w, h, txt, chevron=True, px=13, col=None, align="l"):
        s.inset(x, y, w, h, 5)
        if align == "l": s.T(x + 10, y + h // 2, txt, px, 600, col or s.text_c, "lm")
        else: s.T(x + w // 2, y + h // 2, txt, px, 700, col or s.text_c, "mm")
        if chevron: s.put(glyph("chev_down", 16, s.t["icon"], 1.8), x + w - 22, y + (h - 16) // 2)
    def bar(s, x, y, w, h, frac, fill="#e0b23a", fill2="#b88a2c"):
        s.put(nine_(s.k.pieces["xp_bar_track"], s.k.meta["xp_bar_track"]["nine_slice"], (w, h)) if h <= 6 else box_piece(w, h, h // 2, s.t["track"], s.t["track"], 0.92, s.t["slot_border"], 1), x, y)
        fw = max(h, int(round(w * frac)))
        s.put(box_piece(fw, h, h // 2, mix(fill, "#ffffff", .2), fill2, 1.0, mix(fill2, "#000000", .3), 1), x, y)
    def pill(s, x, y, w, h, txt, px=11, fill=None, col="#f6f1e4"):
        p = s.cache(("pill", w, h, fill), lambda: box_piece(w, h, h // 2, fill or s.t["pill"], fill or s.t["pill"], 1.0, mix(fill or s.t["pill"], "#000000", .3), 1))
        s.put(p, x, y); s.T(x + w // 2, y + h // 2, txt, px, 800, col, "mm")
    def cb(s, x, y, checked): s.put(s.k.pieces["checkbox_checked" if checked else "checkbox"], x, y)
    def sep(s, x, y, w, col=None):
        d = ImageDraw.Draw(s.L); d.line([(x, y), (x + w, y)], fill=hx(col or s.t["slot_border"]) + (110,), width=1)
    def header(s, x, y, w, txt, right=0):
        s.T(x, y, txt.upper(), 11, 800, s.dim, "lm"); tw = s.tl(txt.upper(), 11, 800)
        s.sep(x + tw + 8, y, w - tw - 8 - right)
    def scroll(s, x, y, h, thumb=0.4, pos=0.0, w=8):
        s.put(box_piece(w, h, w // 2, s.t["track"], s.t["track"], 0.9, s.t["slot_border"], 1), x, y)
        th = max(18, int(h * thumb)); ty = y + int((h - th) * pos)
        s.put(box_piece(w, th, w // 2, "#5a7a78", "#46615f", 1.0, "#2c3d3b", 1) if s.dark else box_piece(w, th, w // 2, "#8a7a5a", "#76684b", 1.0, "#5e5239", 1), x, ty)
    def coin(s, x, y, px=16): s.put(coin(px), x, y)

def nine_(img, m, size): return nine(img, m, size)

# ================================================================= 1+2  Inventory (I) + Character (O): one combined window 900x640
GRID_COLS, GRID_ROWS, PITCH = 8, 8, 50       # 44 px slots, 6 px gap (6 columns would leave the 460 px column half empty)
INV = """potion_red:normal:12 potion_blue:rare:5 potion_green:normal:8 potion_purple:rare:3 potion_orange:normal:6 potion_cyan:normal:4 bread:normal:20 bandage:normal:15
gem_red:rare:3 gem_green:normal:2 gem_blue:normal:5 gem_yellow:legendary:1 gem_purple:ultra:1 gem_white:normal:9 gem_teal:rare:4 rope:normal:6
ore:normal:48 ore_teal:rare:12 ore_gold:legendary:3 leaf:normal:67 leaf_teal:normal:21 leaf_gold:rare:9 log:normal:120 key:legendary:1
scroll:ultra:1 scroll_blue:rare:2 pickaxe:normal:1 sword:normal:1 sword_gold:rare:1 sword_teal:ultra:1 axe:normal:1 shield:rare:1
shield_red:normal:1 helm:rare:1 chest:normal:1 boots:normal:1 gloves:rare:1 belt:normal:1 cape:normal:1 ring:legendary:1
ring_blue:rare:1 amulet:normal:1 trinket:ultra:1 gem_red:normal:14 potion_red:normal:3 bread:normal:7 - -
potion_blue:normal:2 - gem_white:rare:6 - - - - -
- - - - - - - -"""
FIG_CACHE = {}
def figure(h):
    if h not in FIG_CACHE:
        a = Image.open(CLASS_ART).convert("RGBA"); a = a.crop(a.getbbox()); w = int(round(a.width * h / a.height))
        FIG_CACHE[h] = a.resize((w, h), Image.LANCZOS)
    return FIG_CACHE[h]

def radial_glow(w, h, color, a0):
    yy, xx = np.mgrid[0:h, 0:w]; d = np.hypot((xx - w / 2) / (w / 2), (yy - h * 0.55) / (h * 0.6))
    al = np.clip(1 - d, 0, 1) ** 1.6 * a0 * 255
    im = Image.new("RGBA", (w, h), hx(color) + (0,)); im.putalpha(Image.fromarray(al.astype(np.uint8))); return im

def win_inventory(variant, view="equipment"):
    u = Ui(variant, 900, 640); t = u.t
    LW, RX, RW = 434, 438, 462
    u.panel(0, 0, LW, 640); u.panel(RX, 0, RW, 640)
    u.title(0, 0, LW, "Character", close=None)
    # ---------------- left: tabs
    u.tab(10, 38, 104, 26, "Equipment", view == "equipment"); u.tab(118, 38, 76, 26, "Stats", view == "stats")
    u.T(LW - 12, 51, "Ironjaw · Level 23", 13, 700, u.text_c, "rm")
    if view == "equipment":
        # paper doll: slots in columns both sides of the figure
        LS = [("helm", "rare", "helm"), ("amulet", "normal", "amulet"), ("ring", "legendary", "ring"), (None, "normal", "ring_blue"), ("chest", "rare", "chest"), (None, "normal", "belt"), ("boots", "normal", "boots")]
        RS = [("axes", "ultra", "axe", True), (None, "normal", "shield"), ("cape", "normal", "cape"), (None, "normal", "gloves"), ("trinket", "rare", "trinket")]
        dy = 72
        for i, e in enumerate(LS): u.slot(12, dy + i * 46, e[0], e[1], ghost=e[2])
        for i, e in enumerate(RS): u.slot(LW - 12 - 44, dy + i * 46, e[0], e[1], ghost=e[2], sel=len(e) > 3)
        bx, bw_, bh = 62, LW - 124, 322
        u.inset(bx, dy, bw_, bh, 6, a=0.55); u.put(radial_glow(bw_ - 2, bh - 2, "#3aa6a6" if u.dark else "#ffffff", 0.30), bx + 1, dy + 1)
        sh = Image.new("RGBA", (180, 40), (0, 0, 0, 0)); ImageDraw.Draw(sh).ellipse((10, 10, 170, 32), fill=(0, 0, 0, 120)); sh = sh.filter(ImageFilter.GaussianBlur(5))
        fig = figure(300); cx = bx + bw_ // 2
        u.put(sh, cx - 90, dy + bh - 44); u.put(fig, cx - fig.width // 2, dy + bh - 12 - 300)
        u.T(bx + 8, dy + 12, "Ironjaw", 11, 700, u.dim, "lm"); u.put(fit(Image.open(os.path.join(HERE, "assets", "crest_ironjaw.png")).convert("RGBA"), 20), bx + bw_ - 28, dy + 4)
        # pets / mount / companions row (smaller slots)
        pr = [("paw", None), (None, "paw"), (None, "horseshoe"), (None, "paw"), (None, "paw"), (None, "paw")]
        pr = [("paw", "normal", None), (None, "normal", "horseshoe"), (None, "normal", "paw"), (None, "normal", "ring"), (None, "normal", "paw"), (None, "normal", "paw")]
        n = 6; sz = 36; gp = 6; x0 = (LW - (n * sz + (n - 1) * gp)) // 2
        for i, (it, r_, gh) in enumerate(pr): u.slot(x0 + i * (sz + gp), 400, it, r_, size=sz, ghost=gh, ipx=28)
        # ---- selected item detail panel
        dx, dyy, dw, dh = 8, 444, LW - 16, 188
        u.sub(dx, dyy, dw, dh, 6, a=0.45)
        u.put(u.nine("title_bar", dw - 2, 24), dx + 1, dyy + 1)
        u.T(dx + 12, dyy + 13, "Rustbrand Twin Axes", 13, 800, "#f1ece2", "lm"); u.T(dx + dw - 12, dyy + 13, "Lv. 22", 13, 800, "#f1ece2", "rm")
        px0, py0 = dx + 10, dyy + 34
        u.slot(px0, py0, "axes", "ultra", size=64, ipx=52)
        u.T(px0 + 32, py0 + 78, "Weight 10", 11, 700, u.dim, "mm")
        u.pill(px0 + 3, py0 + 94, 58, 18, "Ultra", 11, fill="#6f44b0")
        u.btn(px0, py0 + 118, 64, 24, "Unequip", "dark", 12)
        tx = px0 + 76; tabs = [("Effects", 78), ("Conditions", 92), ("Info", 56)]
        for i, (lb, w_) in enumerate(tabs):
            u.tab(tx + sum(a[1] + 4 for a in tabs[:i]), py0, w_, 22, lb, i == 0, 12)
        lx, ly, lw_, lh = tx, py0 + 28, dx + dw - 10 - tx, 118
        u.inset(lx, ly, lw_, lh, 5, a=0.6)
        lines = [("Damage 16 to 22 (neutral)", u.text_c), ("Damage 10 to 14 (fire)", u.text_c), ("+390 Vitality", u.good), ("+47 Strength", u.good), ("+12 Wisdom", u.good), ("+3% Critical", u.good), ("Two hands · Range 1", u.text_c), ("Cost 4 AP", u.text_c)]
        for i, (tx_, col) in enumerate(lines[:6]): u.T(lx + 10, ly + 14 + i * 18, tx_, 13, 600, col, "lm")
        u.scroll(lx + lw_ - 12, ly + 6, lh - 12, 0.72, 0.0, 6)
    else:
        win_stats_left(u, LW)
    # ---------------- right: inventory
    u.title(RX, 0, RW, "Inventory", close="green", help=True)
    cats = ["sword", "ore", "potion_red", "scroll", "key", "cape"]; tw = 69
    for i, c in enumerate(cats):
        x = RX + 14 + i * (tw + 4); u.tab(x, 38, tw, 36, None, i == 1)
        u.put(fit(item_img(c), 26), x + (tw - 26) // 2, 38 + (36 - 26) // 2)
    u.btn(RX + 14, 80, 32, 28, None, "dark", glyph_img=g2("funnel", 16, t["icon"]))
    u.field(RX + 52, 80, RW - 52 - 14, 28, "All categories")
    gx = RX + (RW - (GRID_COLS * PITCH - 6 + 8 + 8)) // 2; gy = 116
    rows = [r.split() for r in INV.split("\n")]
    for r in range(GRID_ROWS):
        for c in range(GRID_COLS):
            e = rows[r][c] if r < len(rows) else "-"
            if e == "-": u.slot(gx + c * PITCH, gy + r * PITCH)
            else:
                k_, rar, n_ = e.split(":"); u.slot(gx + c * PITCH, gy + r * PITCH, k_, rar, int(n_))
    u.scroll(gx + GRID_COLS * PITCH - 6 + 8, gy, GRID_ROWS * PITCH - 6, 0.12, 0.0, 8)
    py = gy + GRID_ROWS * PITCH - 6 + 8
    u.btn(RX + 14, py, 32, 28, None, "dark", glyph_img=g2("arrow_l", 14, t["icon"])); u.field(RX + 50, py, 74, 28, "1 / 18", False, 13, align="c")
    u.btn(RX + 128, py, 32, 28, None, "dark", glyph_img=g2("arrow_r", 14, t["icon"]))
    u.btn(RX + RW - 14 - 96, py, 96, 28, "Bank", "green", 14)
    cy = py + 28 + 14
    u.T(RX + 14, cy, "Coins", 13, 600, u.dim, "lm"); u.coin(RX + RW - 14 - 16, cy - 8, 16); u.T(RX + RW - 14 - 16 - 6, cy, "2,116,909", 14, 800, u.text_c, "rm")
    wy = cy + 20
    u.T(RX + 14, wy + 6, "Weight", 13, 600, u.text_c, "lm"); u.T(RX + RW - 14, wy + 6, "720 / 1,000", 11, 700, u.dim, "rm")
    u.bar(RX + 14, wy + 18, RW - 28, 12, 0.72)
    return u.L

def win_stats_left(u, LW):
    t = u.t
    u.sub(12, 72, LW - 24, 80, 6, a=0.45)
    u.inset(22, 80, 64, 64, 32, a=0.6); u.put(fit(Image.open(os.path.join(HERE, "assets", "crest_ironjaw.png")).convert("RGBA"), 50), 29, 87)
    u.T(100, 94, "Ironjaw", 16, 700); u.T(100, 114, "Level 23 · Warrior", 13, 600, u.dim)
    u.T(100, 130, "XP 14,820 / 21,000", 11, 600, u.dim); u.T(LW - 24, 130, "70%", 11, 700, u.teal, "rm")
    XW = LW - 24 - 88 - 10; u.put(nine(u.k.pieces["xp_bar_track"], u.k.meta["xp_bar_track"]["nine_slice"], (XW, 6)), 100, 138)
    u.put(nine(u.k.pieces["xp_bar_fill"], u.k.meta["xp_bar_fill"]["nine_slice"], (int(XW * .70), 6)), 100, 138)
    u.header(16, 168, LW - 32, "Vitals")
    cw = (LW - 24 - 16) // 3
    for i, (lb, v, col) in enumerate([("HP", "240", HP_RED), ("AP", "6", u.warn), ("MP", "3", u.teal)]):
        x = 12 + i * (cw + 8); u.sub(x, 180, cw, 48, 6, a=0.4)
        u.T(x + 12, 196, lb, 11, 800, u.dim); u.T(x + 12, 214, v, 16, 800, u.text_c)
        d = ImageDraw.Draw(u.L); d.rounded_rectangle((x + cw - 18, 196, x + cw - 10, 204), radius=2, fill=hx(col) + (255,))
    u.header(16, 242, LW - 32, "Attributes", right=int(u.tl("Points to spend: 3", 13, 800)) + 8); u.T(LW - 16, 242, "Points to spend: 3", 13, 800, u.warn, "rm")
    attrs = [("Strength", 47, "+12"), ("Vitality", 39, "+8"), ("Agility", 21, ""), ("Wisdom", 12, "+3"), ("Luck", 8, "")]
    for i, (n_, v, b_) in enumerate(attrs):
        y = 258 + i * 34
        if i % 2 == 0: u.sub(12, y, LW - 24, 32, 4, border=t["panel_bot"], a=0.28)
        u.T(24, y + 16, n_, 13, 700); u.T(196, y + 16, str(v), 14, 800, u.text_c, "rm")
        if b_: u.T(204, y + 16, "(" + b_ + ")", 11, 700, u.good, "lm")
        u.T(LW - 12 - 28 - 12, y + 16, "1 pt", 11, 600, u.dim, "rm")
        u.btn(LW - 12 - 28 - 4, y + 4, 28, 24, None, "green", glyph_img=glyph("plus", 16, "#ffffff", 2.0))
    u.header(16, 440, LW - 32, "Combat")
    cs = [("Damage", "16 – 22"), ("Critical", "4%"), ("Initiative", "215"), ("Dodge", "6%"), ("Resist (neutral)", "8%"), ("Range", "+1")]
    cw2 = (LW - 24 - 8) // 2
    for i, (n_, v) in enumerate(cs):
        c, r = i // 3, i % 3; x = 12 + c * (cw2 + 8); y = 452 + r * 30
        u.sub(x, y, cw2, 28, 4, border=t["panel_bot"], a=0.28 if (r % 2 == 0) else 0.12)
        u.T(x + 12, y + 14, n_, 13, 600, u.dim); u.T(x + cw2 - 12, y + 14, v, 13, 800, u.text_c, "rm")
    u.btn(LW - 12 - 120 - 8 - 100, 584, 100, 32, "Reset", "dark"); u.btn(LW - 12 - 120, 584, 120, 32, "Confirm", "green")
    u.T(24, 600, "Applied on confirm", 11, 600, u.dim, "lm")

# ================================================================= shared window chrome
def base(variant, w, h, title, close="dark"):
    u = Ui(variant, w, h); u.panel(0, 0, w, h); u.title(0, 0, w, title, close=close); return u

# ================================================================= 3  Spells (P)
def arc_pts(cx, cy, r, a0, a1, n=28): return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]

def spell_glyph(name):
    p = P(); cream, dk = "#fff3d6", "#1b1612"
    def L(pts, w): p.line(pts, dk, w + 2.4); p.line(pts, cream, w)
    if name == "Cleave":
        outer = arc_pts(34, 34, 26, 200, 330); inner = arc_pts(34, 34, 14, 330, 200)
        p.poly(outer + inner, cream, "#f0d9a0"); L([(10, 54), (30, 36)], 3)
    elif name == "Whirl":
        for a0 in (20, 200):
            pts = arc_pts(32, 32, 20, a0, a0 + 130); L(pts, 4)
            e = pts[-1]; a = math.radians(a0 + 130 + 90)
            tip = (e[0] + 9 * math.cos(a), e[1] + 9 * math.sin(a)); b1 = (e[0] + 7 * math.cos(a + 2.2), e[1] + 7 * math.sin(a + 2.2)); b2 = (e[0] + 7 * math.cos(a - 2.2), e[1] + 7 * math.sin(a - 2.2))
            p.poly([tip, b1, b2], cream, "#f0d9a0")
        p.ell((26, 26, 38, 38), cream, "#f0d9a0")
    elif name == "Ground Slam":
        p.poly([(32, 14), (37, 28), (50, 24), (42, 36), (56, 44), (40, 44), (32, 58), (26, 44), (8, 48), (22, 36), (12, 26), (27, 28)], cream, "#f0d9a0")
    elif name == "War Cry":
        p.poly([(8, 26), (28, 22), (46, 8), (46, 56), (28, 42), (8, 38)], cream, "#f0d9a0")
        p.poly([(8, 26), (8, 38), (2, 38), (2, 26)], "#c9a765", "#9a7d3c", ow=1)
        for r in (8, 15): p.line(arc_pts(46, 32, r, -60, 60), dk, 4.2); p.line(arc_pts(46, 32, r, -60, 60), cream, 2.2)
    elif name == "Hook Throw":
        path = [(30, 6), (30, 36)] + arc_pts(40, 36, 10, 180, 40)[:]
        L(path, 4.2)
        p.poly([(52, 24), (52, 38), (44, 30)], cream, "#f0d9a0")
        for i in range(5): p.ell((8 + i * 4.6, 54 - i * 8 - 2, 12 + i * 4.6, 54 - i * 8 + 2), cream, cream, ow=.8)
    elif name == "Iron Skin":
        p.poly([(32, 58), (9, 42), (9, 10), (32, 5), (55, 10), (55, 42)], cream, "#f0d9a0")
        p.poly([(32, 49), (16, 38), (16, 17), (32, 13), (48, 17), (48, 38)], "#8aa0b0", "#5a7080", out=None)
        p.line([(32, 14), (32, 48)], cream, 2.4); p.line([(17, 28), (47, 28)], cream, 2.4)
    return p.done(96)

SPELL_COL = {"Cleave": ("#d04848", "#8f2a2a"), "Whirl": ("#e0912f", "#a85f14"), "Ground Slam": ("#9a7048", "#5f4429"),
             "War Cry": ("#d6a83e", "#9a7418"), "Hook Throw": ("#3aa6a6", "#1f6f70"), "Iron Skin": ("#5a8ab8", "#34567a")}

def spell_icon(u, x, y, name, size=44):
    c1, c2 = SPELL_COL[name]
    u.put(box_piece(size, size, 6, c1, c2, 1.0, mix(c2, "#000000", .45), 1, "#ffffff", 2, 0.22, hl=("#ffffff", 0.25)), x, y)
    g = fit(spell_glyph(name), int(size * 0.74)); u.put(g, x + (size - g.width) // 2, y + (size - g.height) // 2)

def win_spells(variant):
    u = base(variant, 640, 560, "Spells"); t = u.t
    u.T(14, 52, "Ironjaw spells", 13, 800); u.T(626, 52, "Spell points: 3", 13, 800, u.warn, "rm")
    spells = [("Cleave", "3 AP · Range 1", "Heavy axe strike that also hits the enemy standing behind the target.", 1, "5/5"),
              ("Whirl", "4 AP · Self, radius 1", "Spin and strike every enemy standing next to you.", 3, "4/5"),
              ("Ground Slam", "5 AP · Range 1-3, line", "Smash the ground and push enemies in line back 2 cells.", 6, "3/5"),
              ("War Cry", "2 AP · Self", "+20% damage for 3 turns to you and nearby allies.", 9, "2/5"),
              ("Hook Throw", "3 AP · Range 2-6", "Throw a chained hook and pull a distant enemy next to you.", 12, "2/5"),
              ("Iron Skin", "2 AP · Self", "Take 25% less damage for 2 turns. Cannot be cast twice in a row.", 15, "1/5")]
    y0, rh = 68, 66
    for i, (n_, apr, d_, lv, rk) in enumerate(spells):
        y = y0 + i * (rh + 4)
        u.sub(12, y, 616, rh, 6, border=GOLD if i == 0 else None, bw=2 if i == 0 else 1, a=0.45)
        spell_icon(u, 24, y + (rh - 44) // 2, n_)
        u.T(80, y + 22, n_, 14, 800); u.T(80, y + 44, apr, 11, 600, u.dim)
        dl = u.wrap(d_, 13, 600, 290)[:2]
        for j, ln in enumerate(dl): u.T(236, y + rh // 2 + (j - (len(dl) - 1) / 2) * 18, ln, 13, 600, u.text_c)
        u.pill(628 - 14 - 56, y + 12, 56, 20, "Lv %d" % lv, 11); u.T(628 - 14 - 28, y + 46, "Rank " + rk, 11, 600, u.dim, "mm")
    fy = 560 - 40
    u.sep(12, fy - 6, 616)
    u.put(g2("arrow_exit", 16, u.dim), 214, fy + 4); u.T(236, fy + 12, "Drag a spell to the bar", 13, 700, u.dim, "lm")
    u.T(626, fy + 12, "Hotkey  P", 11, 600, u.dim, "rm")
    return u.L

# ================================================================= 4  Quests (L)
def win_quests(variant):
    u = base(variant, 600, 560, "Quests"); t = u.t
    u.header(14, 54, 208, "Active  3")
    act = [("A Farmer's Worry", "Lv 1 · Crosshaven Farm", False), ("Granary Rats", "Lv 3 · Old Granary", True), ("Herb Gathering", "Lv 4 · Crosshaven Meadow", False)]
    for i, (n_, sb, sel) in enumerate(act):
        y = 66 + i * 52
        u.sub(12, y, 216, 46, 6, border=GOLD if sel else None, bw=2 if sel else 1, a=0.5 if sel else 0.3)
        u.T(24, y + 15, n_, 13, 800); u.T(24, y + 33, sb, 11, 600, u.dim); u.put(g2("eye", 16, u.teal), 228 - 8 - 16 - 4, y + 15)
    u.header(14, 238, 208, "Done  2")
    for i, (n_, sb) in enumerate([("Welcome to Crosshaven", "Lv 1 · Crossroads"), ("The Lost Ladle", "Lv 2 · Crosshaven Farm")]):
        y = 250 + i * 46
        u.sub(12, y, 216, 40, 6, a=0.2); u.T(24, y + 13, n_, 13, 700, u.dim); u.T(24, y + 29, sb, 11, 600, u.dim)
        u.put(g2("tick", 16, u.good), 228 - 8 - 16 - 4, y + 12)
    u.T(14, 536, "Tracked 3/3", 11, 600, u.dim, "lm")
    # detail pane
    DX, DW = 240, 348
    u.sub(DX - 4, 44, DW + 8, 504, 6, a=0.25)
    u.T(DX + 8, 64, "Granary Rats", 16, 700); u.pill(DX + DW - 56 - 4, 54, 56, 20, "Lv 3", 11)
    u.T(DX + 8, 86, "Given by Keeper Odo · Old Granary", 11, 600, u.dim); u.sep(DX + 8, 98, DW - 12)
    txt = "Something has been gnawing through the grain sacks under the Granary, and the rats down there are bolder every night. Clear the cellar so Keeper Odo can save what is left of the harvest, then come back to him."
    for i, ln in enumerate(u.wrap(txt, 13, 600, DW - 20)): u.T(DX + 8, 116 + i * 19, ln, 13, 600, u.text_c, "lm")
    u.header(DX + 8, 238, DW - 12, "Objectives")
    objs = [("Enter the Old Granary Cellar", "", True), ("Defeat 3 Granary Rats", "1/3", False), ("Return to Keeper Odo", "", False)]
    for i, (o, c, d_) in enumerate(objs):
        y = 252 + i * 30; u.cb(DX + 8, y + 5, d_)
        u.T(DX + 30, y + 12, o, 13, 600, u.dim if d_ else u.text_c)
        if c: u.T(DX + DW - 8, y + 12, c, 13, 800, u.text_c if u.dark else "#7a4a10", "rm")
    u.header(DX + 8, 366, DW - 12, "Rewards")
    ry = 382
    u.sub(DX + 8, ry, 96, 44, 6, a=0.45); u.pill(DX + 16, ry + 12, 28, 20, "XP", 11); u.T(DX + 52, ry + 22, "+250", 14, 800, u.teal, "lm")
    u.sub(DX + 112, ry, 96, 44, 6, a=0.45); u.coin(DX + 120, ry + 14, 16); u.T(DX + 142, ry + 22, "+120", 14, 800, u.text_c if u.dark else "#7a4a10", "lm")
    u.slot(DX + 218, ry, "potion_red", "normal", 3); u.T(DX + 270, ry + 22, "Healing Potion", 11, 600, u.dim, "lm")
    u.btn(DX + 8, 548 - 12 - 34 - 0, 120, 34, "Track", "green", 14); u.btn(DX + 136, 548 - 12 - 34, 120, 34, "Abandon", "dark", 14)
    return u.L

# ================================================================= 6  Dungeons
def lock_badge(u, x, y, size=44):
    u.inset(x, y, size, size, 6, a=0.35); u.put(g2("lock", 22, u.dim), x + (size - 22) // 2, y + (size - 22) // 2)

def win_dungeons(variant):
    u = base(variant, 640, 520, "Dungeons"); t = u.t
    u.T(14, 52, "Crosshaven dungeons", 13, 800); u.T(626, 52, "Your level: 23", 11, 600, u.dim, "rm")
    D = [("Old Granary Cellar", "Levels 1-10", True), ("Drowned Abbey", "Levels 10-20", False), ("Frostspire", "Levels 20-30", False), ("Saltmaw", "Levels 30-40", False), ("Heart of the Blight", "Levels 40-50", False)]
    for i, (n_, lv, built) in enumerate(D):
        y = 68 + i * 78
        u.sub(12, y, 292, 72, 6, border=GOLD if i == 0 else None, bw=2 if i == 0 else 1, a=0.5 if built else 0.28)
        if built:
            u.inset(24, y + 12, 48, 48, 6, a=0.6); ic = fit(Image.open(os.path.join(HERE, "assets", "icons", "dungeons.png")).convert("RGBA"), 34)
            ic = tint(ic, t["icon"]) if not u.dark else ic; u.put(ic, 24 + (48 - ic.width) // 2, y + 12 + (48 - ic.height) // 2)
        else: lock_badge(u, 24, y + 12, 48)
        col = u.text_c if built else u.dim
        u.T(84, y + 25, n_, 13, 800, col); u.T(84, y + 46, lv, 11, 600, u.dim)
        if built: u.pill(304 - 12 - 54, y + 12, 54, 20, "Built", 11, fill="#2f8f48")
        else: u.pill(304 - 12 - 58, y + 12, 58, 20, "Locked", 11, fill="#59656a" if u.dark else "#8a8a7a")
    u.T(14, 484, "One dungeon per level band, built by the Crosshaven guild.", 11, 600, u.dim, "lm")
    DX, DW = 316, 312
    u.sub(DX, 68, DW, 96, 6, a=0.5); u.put(radial_glow(DW - 2, 94, "#3aa6a6" if u.dark else "#ffffff", 0.35), DX + 1, 69)
    ic = fit(Image.open(os.path.join(HERE, "assets", "icons", "dungeons.png")).convert("RGBA"), 72); ic = tint(ic, t["icon"]) if not u.dark else ic
    u.put(ic, DX + (DW - ic.width) // 2, 68 + (96 - ic.height) // 2)
    u.T(DX + 4, 184, "Old Granary Cellar", 16, 700); u.T(DX + 4, 206, "Levels 1-10 · Boss: Ratking", 13, 600, u.dim)
    for i, ln in enumerate(u.wrap("Rats, rot and the Ratking in the dark under the Crosshaven granary. Drops the Granary armour set.", 13, 600, DW - 8)): u.T(DX + 4, 232 + i * 18, ln, 13, 600)
    u.header(DX + 4, 298, DW - 4, "Difficulty")
    for i in range(5):
        x = DX + 4 + i * 44; on = i < 3
        u.sub(x, 310, 40, 36, 6, border=GOLD if on else None, bw=1, a=0.45)
        u.put(g2("star", 24, GOLD if on else mix(t["dim"], t["panel_bot"], .45)), x + 8, 316)
    u.T(DX + 4, 360, "3 stars · Hard · +40% rewards", 11, 600, u.dim)
    u.header(DX + 4, 388, DW - 4, "Party size")
    u.field(DX + 4, 400, 110, 28, "1-4 players", False, 13)
    for i in range(4):
        x = DX + 128 + i * 34; u.inset(x, 400, 28, 28, 14, a=0.5)
        if i == 0: u.put(fit(Image.open(os.path.join(HERE, "assets", "crest_ironjaw.png")).convert("RGBA"), 22), x + 3, 403)
    u.btn(DX + DW - 140, 520 - 12 - 38, 140, 38, "Enter", "green", 16)
    u.T(DX + 4, 520 - 12 - 19, "Entry cost: free", 11, 600, u.dim, "lm")
    return u.L

# ================================================================= 7  Koliseo
def win_koliseo(variant):
    u = base(variant, 600, 480, "Koliseo"); t = u.t
    for i, n_ in enumerate(("Duel", "Team", "Ranked")): u.tab(12 + i * 104, 38, 100, 28, n_, i == 2)
    u.T(588, 52, "Season 3 · 12 days left", 11, 600, u.dim, "rm")
    # rank badge
    u.sub(12, 76, 280, 104, 6, a=0.45)
    hexp = P(); hexp.poly([(32, 3), (58, 17), (58, 47), (32, 61), (6, 47), (6, 17)], "#e4ebef", "#8b979f", ow=2)
    hexp.poly([(32, 11), (50, 21), (50, 43), (32, 53), (14, 43), (14, 21)], "#aab4bb", "#69757d", out="#4a555b", ow=1)
    for k in range(2): hexp.poly([(32, 20 + k * 11), (39, 28 + k * 11), (32, 24 + k * 11), (25, 28 + k * 11)], "#fff3d6", "#d9ae52", ow=.8)
    bd = hexp.done(88); u.put(bd, 24, 84)
    u.T(124, 104, "Silver II", 16, 700); u.T(124, 126, "1,420 rating", 13, 600, u.dim)
    u.bar(124, 142, 156, 8, 0.62, "#9fb5bf", "#6c8490"); u.T(124, 164, "80 to Gold I", 11, 600, u.dim)
    u.header(14, 196, 276, "Party  3/4")
    ms = [("Ironjaw", "Lv 23", True), ("Mira", "Lv 22", True), ("Tomas", "Lv 24", False)]
    for i, (n_, lv, rd) in enumerate(ms):
        y = 210 + i * 44; u.sub(12, y, 280, 40, 6, a=0.35)
        u.inset(20, y + 6, 28, 28, 14, a=0.6)
        if i == 0: u.put(fit(Image.open(os.path.join(HERE, "assets", "crest_ironjaw.png")).convert("RGBA"), 22), 23, y + 9)
        else: u.T(34, y + 20, n_[0], 13, 800, u.teal, "mm")
        u.T(58, y + 14, n_, 13, 800); u.T(58, y + 29, lv, 11, 600, u.dim)
        if rd: u.T(280, y + 20, "Ready", 11, 800, u.good, "rm"); u.put(g2("tick", 14, u.good), 280 - u.tl("Ready", 11, 800) - 18, y + 13)
        else: u.T(280, y + 20, "Waiting", 11, 700, u.dim, "rm")
    u.btn(12, 350, 280, 28, "+ Invite player", "dark", 12)
    u.T(14, 394, "Estimated wait 0:25", 11, 600, u.dim, "lm")
    u.btn(12, 480 - 12 - 46, 280, 46, "Find match", "orange", 18)
    # last matches
    RX, RW = 308, 280
    u.header(RX, 88, RW, "Last matches")
    rows = [("W", "Kaelith", "Lv 24", "+18", "4:12", True), ("L", "Brannoch", "Lv 22", "-14", "6:40", False), ("W", "Selke", "Lv 23", "+17", "3:05", True)]
    for i, (r_, o, lv, d_, tm, w_) in enumerate(rows):
        y = 102 + i * 60; u.sub(RX, y, RW, 54, 6, a=0.35)
        u.put(box_piece(28, 28, 14, "#4cc06a" if w_ else "#d85a5a", "#2f8f48" if w_ else "#a73c3c", 1.0, "#1f4a2a" if w_ else "#5f1f1f", 1), RX + 10, y + 13)
        u.T(RX + 24, y + 27, r_, 13, 800, "#ffffff", "mm")
        u.T(RX + 48, y + 20, "vs " + o, 13, 800); u.T(RX + 48, y + 38, "%s · Ranked 1v1" % lv, 11, 600, u.dim)
        u.T(RX + RW - 12, y + 20, d_, 13, 800, u.good if w_ else u.bad, "rm"); u.T(RX + RW - 12, y + 38, tm + " · today", 11, 600, u.dim, "rm")
    u.sub(RX, 288, RW, 66, 6, a=0.35)
    for i, (lb, v) in enumerate([("Wins", "38"), ("Losses", "29"), ("Win rate", "57%")]):
        x = RX + 12 + i * 90; u.T(x, 306, lb, 11, 600, u.dim); u.T(x, 331, v, 16, 800)
    u.T(RX, 376, "Rewards at season end: Silver II = Koliseo banner", 11, 600, u.dim, "lm")
    return u.L

# ================================================================= 8  Shop
def win_shop(variant):
    u = base(variant, 640, 560, "Shop"); t = u.t
    for i, n_ in enumerate(("Potions", "Gear", "Materials", "Scrolls")): u.tab(12 + i * 100, 38, 96, 28, n_, i == 0)
    u.coin(640 - 14 - 16, 44, 16); u.T(640 - 14 - 22, 52, "1,240", 14, 800, u.text_c, "rm")
    u.sub(8, 76, 270, 440, 6, a=0.3)
    grid = [("potion_red", 45), ("potion_blue", 60), ("potion_green", 55), ("potion_purple", 120), ("potion_orange", 70),
            ("potion_cyan", 80), ("bread", 8), ("bandage", 15), ("scroll", 200), ("scroll_blue", 150),
            ("rope", 12), ("pickaxe", 90), ("leaf", 6), ("leaf_teal", 14), ("leaf_gold", 30),
            ("ore", 10), ("gem_red", 250), ("gem_blue", 250), ("key", 500), ("log", 4),
            ("potion_red", 120), ("potion_blue", 140), ("potion_green", 130), None, None,
            None, None, None, None, None, None, None, None, None, None]
    gx, gy = 18, 86
    for i in range(5 * 8):
        c, r = i % 5, i // 5; e = grid[i] if i < len(grid) else None
        if e: u.slot(gx + c * 50, gy + r * 50, e[0], "rare" if i in (1, 3, 5) else "normal", 0, sel=(i == 0))
        else: u.slot(gx + c * 50, gy + r * 50)
    u.scroll(gx + 5 * 50 - 6 + 4, gy, 8 * 50 - 6, 0.5, 0.0, 8)
    py = 484
    u.btn(8 + 6, py - 4, 32, 28, None, "dark", glyph_img=g2("arrow_l", 14, t["icon"])); u.field(8 + 44, py - 4, 74, 28, "1 / 3", False, 13, align="c"); u.btn(8 + 124, py - 4, 32, 28, None, "dark", glyph_img=g2("arrow_r", 14, t["icon"]))
    DX, DW = 290, 342
    u.sub(DX, 76, DW, 440, 6, a=0.3)
    u.slot(DX + 12, 88, "potion_red", "normal", 0, size=72, ipx=58)
    u.T(DX + 96, 104, "Healing Potion", 16, 700); u.T(DX + 96, 126, "Consumable · Level 1", 11, 600, u.dim)
    u.pill(DX + 96, 140, 56, 18, "Common", 11, fill="#59656a" if u.dark else "#8a8a7a")
    for i, ln in enumerate(u.wrap("A sweet red tonic brewed on the Crosshaven farm. Drink it in or out of a fight to patch yourself up.", 13, 600, DW - 24)): u.T(DX + 12, 192 + i * 18, ln, 13, 600)
    u.header(DX + 12, 262, DW - 24, "Effects")
    for i, (tx_, col) in enumerate([("Restores 120 HP", u.good), ("Cooldown 3 turns", u.text_c), ("Stack size 99", u.text_c)]): u.T(DX + 14, 284 + i * 20, tx_, 13, 600, col)
    u.header(DX + 12, 358, DW - 24, "Price")
    u.coin(DX + 14, 372, 18); u.T(DX + 38, 381, "45", 16, 800, u.text_c if u.dark else "#7a4a10"); u.T(DX + 66, 382, "each", 11, 600, u.dim)
    u.T(DX + DW - 12, 372, "Quantity", 11, 600, u.dim, "rm")
    u.btn(DX + DW - 12 - 120, 384, 32, 30, None, "dark", glyph_img=glyph("minus", 16, t["icon"], 2.0)); u.field(DX + DW - 12 - 84, 384, 52, 30, "3", False, 14, align="c")
    u.btn(DX + DW - 12 - 28, 384, 28, 30, None, "dark", glyph_img=glyph("plus", 16, t["icon"], 2.0))
    u.T(DX + 14, 436, "Total", 13, 600, u.dim, "lm"); u.coin(DX + DW - 12 - 16, 428, 16); u.T(DX + DW - 12 - 22, 436, "135", 16, 800, u.text_c if u.dark else "#7a4a10", "rm")
    u.btn(DX + 12, 516 - 12 - 40, 120, 40, "Sell", "dark", 14); u.btn(DX + DW - 12 - 190, 516 - 12 - 40, 190, 40, "Buy", "green", 16)
    u.T(14, 538, "Balance after purchase: 1,105 coins", 11, 600, u.dim, "lm")
    return u.L

# ================================================================= 9  Settings (Esc)
def key_cap(u, x, y, label, w=None):
    px = 12; w = w or max(30, int(u.tl(label, px, 800)) + 18)
    top, bot = ("#3a4448", "#252d30") if u.dark else ("#f6ecd6", "#d9ccaa")
    u.put(box_piece(w, 26, 5, top, bot, 1.0, u.t["btn_border"], 1, hl=("#ffffff", 0.2 if u.dark else 0.6)), x, y)
    u.T(x + w // 2, y + 12, label, px, 800, u.text_c, "mm"); return w

def toggle(u, x, y, on):
    w, h = 40, 20
    u.put(box_piece(w, h, h // 2, "#4cc06a" if on else u.t["track"], "#2f8f48" if on else u.t["track"], 1.0, "#1f6a33" if on else u.t["slot_border"], 1), x, y)
    kx = x + w - h + 2 if on else x + 2
    u.put(box_piece(h - 4, h - 4, (h - 4) // 2, "#fbf6e8", "#d3cab4", 1.0, "#6b665a", 1), kx, y + 2)

def slider(u, x, y, w, frac):
    u.put(nine(u.k.pieces["xp_bar_track"], u.k.meta["xp_bar_track"]["nine_slice"], (w, 6)), x, y + 5)
    u.put(nine(u.k.pieces["xp_bar_fill"], u.k.meta["xp_bar_fill"]["nine_slice"], (max(6, int(w * frac)), 6)), x, y + 5)
    kx = x + int(w * frac) - 8
    u.put(box_piece(16, 16, 8, "#fbf6e8", "#d3cab4", 1.0, GOLD if True else "#17383a", 1, "#000000", 2, 0.18), kx, y + 3)

def win_settings(variant):
    u = base(variant, 520, 560, "Settings"); t = u.t
    for i, n_ in enumerate(("Video", "Audio", "Controls", "Game")): u.tab(12 + i * 98, 38, 94, 28, n_, i == 0)
    LX, RXs, RWs = 24, 236, 260
    u.header(14, 86, 492, "Display")
    u.T(LX, 114, "Resolution", 13, 600); u.field(RXs, 100, RWs, 28, "1920x1080")
    u.T(LX, 150, "Display mode", 13, 600); u.field(RXs, 136, RWs, 28, "Fullscreen")
    u.T(LX, 186, "V-Sync", 13, 600); toggle(u, RXs + RWs - 40, 176, True)
    u.T(LX, 214, "Show FPS", 13, 600); toggle(u, RXs + RWs - 40, 204, False)
    u.header(14, 248, 492, "Audio")
    for i, (n_, v) in enumerate((("Master", 80), ("Music", 60), ("Effects", 70))):
        y = 268 + i * 32; u.T(LX, y + 11, n_, 13, 600); slider(u, 120, y, 316, v / 100); u.T(496, y + 11, str(v), 13, 800, u.text_c, "rm")
    u.header(14, 372, 492, "Controls")
    for i, (n_, k_) in enumerate((("Inventory", "I"), ("Character", "O"), ("Map", "M"), ("Quests", "L"))):
        y = 388 + i * 31; u.T(LX, y + 13, n_, 13, 600);
        kw = max(30, int(u.tl(k_, 12, 800)) + 18); key_cap(u, 496 - kw, y, k_)
        u.T(496 - kw - 10, y + 12, "Rebind", 11, 600, u.dim, "rm")
    u.btn(520 - 14 - 100 - 8 - 100, 560 - 12 - 34, 100, 34, "Close", "dark", 14); u.btn(520 - 14 - 100, 560 - 12 - 34, 100, 34, "Apply", "green", 14)
    return u.L

# ================================================================= 5  Map (M)
def catmull(pts, n=14):
    P_ = [pts[0]] + list(pts) + [pts[-1]]; out = []
    for i in range(1, len(P_) - 2):
        p0, p1, p2, p3 = P_[i - 1], P_[i], P_[i + 1], P_[i + 2]
        for k in range(n):
            t = k / n; t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    out.append(pts[-1]); return out

def marker_icon(kind, px):
    W = px * SS; im = Image.new("RGBA", (W, W), (0, 0, 0, 0)); d = ImageDraw.Draw(im); c = W / 2
    if kind == "quest":
        d.ellipse((1 * SS, 1 * SS, W - SS, W - SS), fill=hx(GOLD) + (255,), outline=hx("#5a4310") + (255,), width=max(1, SS))
        out = im.resize((px, px), Image.LANCZOS); draw_text(out, (px // 2, px // 2 + 1), "!", px * 0.78, 800, "#3a2a08", "mm"); return out
    if kind == "hero":
        pts = [(0, -.46), (.34, .40), (0, .18), (-.34, .40)]; ar = [(c + x * W, c + y * W) for x, y in pts]
        d.polygon(ar, fill=(255, 255, 255, 255)); d.line(ar + [ar[0]], fill=hx("#1d2326") + (255,), width=max(2, int(W * 0.07)), joint="curve")
    elif kind == "dungeon":
        d.ellipse((1 * SS, 1 * SS, W - SS, W - SS), fill=hx("#1f6f70") + (255,), outline=hx("#0f3a3b") + (255,), width=max(1, SS))
        d.rounded_rectangle((W * .32, W * .3, W * .68, W * .78), radius=W * .18, fill=(246, 241, 228, 255)); d.rectangle((W * .32, W * .55, W * .68, W * .78), fill=(246, 241, 228, 255))
        d.rounded_rectangle((W * .41, W * .42, W * .59, W * .78), radius=W * .09, fill=hx("#1b3a3b") + (255,)); d.rectangle((W * .41, W * .6, W * .59, W * .78), fill=hx("#1b3a3b") + (255,))
    elif kind == "house":
        d.rectangle((W * .12, W * .22, W * .88, W * .52), fill=hx("#b35a3c") + (255,)); d.rectangle((W * .12, W * .52, W * .88, W * .8), fill=hx("#8f4430") + (255,))
        d.rectangle((W * .12, W * .22, W * .88, W * .8), outline=hx("#6e3322") + (255,), width=max(1, SS)); d.line([(W * .12, W * .52), (W * .88, W * .52)], fill=hx("#e29a7a") + (255,), width=SS)
    elif kind == "market":
        for i in range(5): d.rectangle((W * (.1 + i * .16), W * .2, W * (.1 + (i + 1) * .16), W * .5), fill=hx("#e0912f" if i % 2 == 0 else "#f6f1e4") + (255,))
        d.rectangle((W * .1, W * .5, W * .9, W * .8), fill=hx("#8a5a33") + (255,)); d.rectangle((W * .1, W * .2, W * .9, W * .8), outline=hx("#4f2f18") + (255,), width=max(1, SS))
    elif kind == "exit":
        return g2("arrow_exit", px, "#f1ece2", 1.8)
    return im.resize((px, px), Image.LANCZOS)

def paint_map(w, h, seed=7):
    S = 2; W, H = w * S, h * S; rnd = random.Random(seed)
    yy = np.linspace(0, 1, H)[:, None, None]; base_ = np.array(hx("#97c841"), float) * (1 - yy) + np.array(hx("#82b436"), float) * yy
    im = Image.fromarray(np.broadcast_to(base_, (H, W, 3)).astype(np.uint8), "RGB").convert("RGBA"); d = ImageDraw.Draw(im, "RGBA")
    occ = Image.new("L", (W, H), 0); od = ImageDraw.Draw(occ)
    P2 = lambda pts: [(x * S, y * S) for x, y in pts]
    for _ in range(90):   # grass blotches
        x, y, r = rnd.uniform(0, w), rnd.uniform(0, h), rnd.uniform(14, 46); col = (120, 180, 50, 46) if rnd.random() < .5 else (160, 205, 80, 40)
        d.ellipse(((x - r) * S, (y - r * .7) * S, (x + r) * S, (y + r * .7) * S), fill=col)
    # water: sea along the bottom + lake south-west
    sea = [(0, 478)] + [(x, 474 + 9 * math.sin(x / 55.0) + 5 * math.sin(x / 23.0)) for x in range(0, w + 1, 12)] + [(w, h), (0, h)]
    d.polygon(P2(sea), fill=hx("#3f95c2") + (255,)); od.polygon(P2(sea), fill=255)
    beach = [(x, 474 + 9 * math.sin(x / 55.0) + 5 * math.sin(x / 23.0)) for x in range(0, w + 1, 12)]
    d.line(P2(beach), fill=hx("#e7d79f") + (255,), width=9 * S, joint="curve"); od.line(P2(beach), fill=255, width=9 * S)
    for (cx, cy, rx, ry) in [(140, 392, 96, 52), (200, 410, 70, 40), (88, 420, 60, 36)]:
        d.ellipse(P2([(cx - rx - 6, cy - ry - 6), (cx + rx + 6, cy + ry + 6)]), fill=hx("#e7d79f") + (255,)); od.ellipse(P2([(cx - rx - 6, cy - ry - 6), (cx + rx + 6, cy + ry + 6)]), fill=255)
        d.ellipse(P2([(cx - rx, cy - ry), (cx + rx, cy + ry)]), fill=hx("#4aa8d0") + (255,))
    for k in range(34):   # wave strokes
        x, y = rnd.uniform(0, w), rnd.uniform(492, h - 6); d.line(P2([(x, y), (x + 14, y - 1.5), (x + 28, y)]), fill=(255, 255, 255, 70), width=2 * S, joint="curve")
    # roads
    roads = [[(0, 276), (150, 262), (300, 272), (430, 270), (490, 270)], [(490, 0), (478, 100), (492, 190), (490, 270)], [(980, 256), (830, 264), (660, 272), (490, 270)],
             [(490, 270), (506, 362), (478, 430), (444, 500)], [(690, 268), (716, 190), (760, 140)], [(556, 300), (640, 372), (706, 410)], [(300, 272), (292, 350), (240, 400)]]
    for r in roads:
        pts = P2(catmull(r)); wd = (26 if r is roads[0] or r is roads[1] or r is roads[2] or r is roads[3] else 16) * S
        d.line(pts, fill=hx("#a07a49") + (255,), width=wd + 4 * S, joint="curve"); d.line(pts, fill=hx("#c9a06b") + (255,), width=wd, joint="curve"); od.line(pts, fill=255, width=wd + 8 * S)
        d.line(pts, fill=(226, 196, 150, 90), width=max(2, wd // 3), joint="curve")
    # plaza
    d.ellipse(P2([(490 - 66, 270 - 66), (490 + 66, 270 + 66)]), fill=hx("#8d877a") + (255,)); d.ellipse(P2([(490 - 62, 270 - 62), (490 + 62, 270 + 62)]), fill=hx("#bdb7a8") + (255,))
    d.ellipse(P2([(490 - 40, 270 - 40), (490 + 40, 270 + 40)]), fill=hx("#cbc5b6") + (255,)); od.ellipse(P2([(490 - 72, 270 - 72), (490 + 72, 270 + 72)]), fill=255)
    for _ in range(260):
        a, r_ = rnd.uniform(0, 6.283), 62 * math.sqrt(rnd.random()); x, y = 490 + r_ * math.cos(a), 270 + r_ * math.sin(a); d.ellipse(P2([(x - 1.6, y - 1.2), (x + 1.6, y + 1.2)]), fill=(120, 114, 100, 120))
    d.polygon(P2([(487, 262), (493, 262), (530, 300), (522, 304)]), fill=(60, 60, 50, 70)); d.polygon(P2([(486, 232), (494, 232), (493, 264), (487, 264)]), fill=hx("#e4e0d4") + (255,), outline=hx("#6b665c") + (255,))
    d.polygon(P2([(486, 232), (490, 224), (494, 232)]), fill=hx("#f6f2e6") + (255,), outline=hx("#6b665c") + (255,))
    # farm (NE)
    d.rectangle(P2([(700, 30), (880, 120)]), fill=hx("#d6a83e") + (255,), outline=hx("#a87f20") + (255,), width=2 * S); od.rectangle(P2([(696, 26), (884, 124)]), fill=255)
    for i in range(10): d.line(P2([(700 + i * 18, 30), (700 + i * 18, 120)]), fill=(168, 127, 32, 140), width=2 * S)
    d.rectangle(P2([(722, 176), (840, 246)]), fill=hx("#7a5638") + (255,), outline=hx("#5b4029") + (255,), width=3 * S); od.rectangle(P2([(718, 172), (844, 250)]), fill=255)
    for i in range(6): d.line(P2([(728, 186 + i * 11), (834, 186 + i * 11)]), fill=hx("#6fae2f" if i % 2 else "#d9b44a") + (255,), width=4 * S)
    # buildings
    def house(x, y, bw, bh, big=False, col=("#b35a3c", "#8f4430")):
        d.rectangle(P2([(x + 6, y + 7), (x + bw + 6, y + bh + 7)]), fill=(0, 0, 0, 62))
        d.rectangle(P2([(x, y), (x + bw, y + bh)]), fill=hx(col[0]) + (255,)); d.rectangle(P2([(x, y + bh / 2), (x + bw, y + bh)]), fill=hx(col[1]) + (255,))
        d.line(P2([(x, y + bh / 2), (x + bw, y + bh / 2)]), fill=hx(mix(col[0], "#ffffff", .35)) + (255,), width=2 * S)
        d.rectangle(P2([(x, y), (x + bw, y + bh)]), outline=hx(mix(col[1], "#000000", .35)) + (255,), width=2 * S); od.rectangle(P2([(x - 4, y - 4), (x + bw + 8, y + bh + 10)]), fill=255)
    for (x, y, bw, bh) in [(376, 168, 66, 48), (562, 164, 72, 50), (590, 336, 70, 52), (240, 196, 62, 46), (232, 330, 58, 46), (630, 214, 56, 42),
                           (330, 96, 60, 46), (572, 78, 66, 48), (160, 250, 0, 0)]:
        if bw: house(x, y, bw, bh)
    house(808, 138, 62, 40, col=("#a56a3a", "#7e4d27"))                                  # barn
    house(690, 388, 96, 62, col=("#9aa0a3", "#6f7679"))                                  # Old Granary
    d.rounded_rectangle(P2([(728, 428), (748, 452)]), radius=6 * S, fill=hx("#2b2f31") + (255,))
    d.rectangle(P2([(358, 322), (420, 362)]), fill=(0, 0, 0, 60))
    for i in range(7):                                                                    # market stall
        d.rectangle(P2([(352 + i * 8, 312), (360 + i * 8, 332)]), fill=hx("#e0912f" if i % 2 == 0 else "#f6f1e4") + (255,))
    d.rectangle(P2([(352, 332), (408, 348)]), fill=hx("#8a5a33") + (255,), outline=hx("#4f2f18") + (255,), width=S); d.rectangle(P2([(352, 312), (408, 348)]), outline=hx("#4f2f18") + (255,), width=2 * S); od.rectangle(P2([(346, 306), (414, 356)]), fill=255)
    d.rectangle(P2([(436, 482), (462, 534)]), fill=hx("#a7743f") + (255,), outline=hx("#5a3820") + (255,), width=2 * S)       # pier
    for i in range(6): d.line(P2([(436, 488 + i * 9), (462, 488 + i * 9)]), fill=hx("#6b4425") + (255,), width=S)
    # trees (rejection sampling against the occupancy mask)
    occ_s = occ.filter(ImageFilter.MaxFilter(9)); oa = np.asarray(occ_s)
    placed = []
    for _ in range(900):
        x, y = rnd.uniform(8, w - 8), rnd.uniform(8, 462); r = rnd.uniform(7, 13)
        if oa[int(y * S), int(x * S)] or any((x - px) ** 2 + (y - py) ** 2 < (r + pr + 3) ** 2 for px, py, pr in placed): continue
        if abs(x - 490) < 22 and y < 300: continue
        placed.append((x, y, r))
        if len(placed) > 72: break
    for (x, y, r) in sorted(placed, key=lambda t: t[1]):
        d.ellipse(P2([(x - r + 3, y - r * .6 + 6), (x + r + 3, y + r * .8 + 6)]), fill=(0, 0, 0, 55))
        d.ellipse(P2([(x - r, y - r), (x + r, y + r)]), fill=hx("#4f8a24") + (255,), outline=hx("#3a6a1a") + (255,), width=S)
        d.ellipse(P2([(x - r * .7, y - r * .8), (x + r * .3, y + r * .1)]), fill=hx("#6aa82f") + (255,))
    for _ in range(140):   # flowers
        x, y = rnd.uniform(0, w), rnd.uniform(0, 460)
        if oa[int(y * S), int(x * S)]: continue
        d.ellipse(P2([(x - 1.4, y - 1.4), (x + 1.4, y + 1.4)]), fill=hx(rnd.choice(["#f6f1e4", "#f0cf72", "#e8a0c0"])) + (230,))
    # vignette
    yy, xx = np.mgrid[0:H, 0:W]; v = np.clip(np.hypot((xx - W / 2) / (W / 2), (yy - H / 2) / (H / 2)) - 0.65, 0, 1) * 0.28
    arr = np.asarray(im).astype(float); arr[..., :3] *= (1 - v[..., None]); im = Image.fromarray(arr.astype(np.uint8), "RGBA")
    return im.resize((w, h), Image.LANCZOS)

def win_map(variant):
    u = base(variant, 1000, 640, "Map"); t = u.t
    MX, MY, MW, MH = 10, 40, 980, 540
    mp = paint_map(MW, MH)
    m = Image.fromarray((B.rr_mask(MW * SS, MH * SS, 0, 6 * SS) * 255).astype(np.uint8)).resize((MW, MH), Image.LANCZOS); mp.putalpha(m)
    u.put(mp, MX, MY); ImageDraw.Draw(u.L).rounded_rectangle((MX, MY, MX + MW - 1, MY + MH - 1), radius=6, outline=hx(t["border"]) + (255,), width=1)
    def lab(x, y, txt, px=12): u.T(MX + x, MY + y, txt, px, 800, "#ffffff", "mm", stroke="#1d2326", sw=2)
    lab(490, 350, "Crossroads Plaza"); lab(780, 258, "Crosshaven Farm"); lab(745, 376, "Old Granary"); lab(380, 362, "Market", 11)
    lab(150, 372, "Millpond", 11)
    # exits
    def exit_pill(cx, cy, label, rot):
        w_ = int(u.tl(label, 13, 800)) + 52; x, y = cx - w_ // 2, cy - 14
        u.put(u.nine("panel_9slice", w_, 28), x, y); ar = g2("arrow_exit", 16, GOLD, 1.8).rotate(rot, resample=Image.BICUBIC)
        u.put(ar, x + 8, y + 6); u.T(x + 30, y + 14, label, 13, 800, u.text_c, "lm")
    exit_pill(MX + 68, MY + 276 - 36, "Stoneford", 90); exit_pill(MX + 490 + 60, MY + 20, "Northgate", 0)
    exit_pill(MX + MW - 78, MY + 256 - 36, "Eastmarch", -90); exit_pill(MX + 444 - 70, MY + 462, "Brinewake", 180)
    # markers
    for (x, y) in [(512, 296), (755, 204), (674, 400), (300, 190)]: u.put(marker_icon("quest", 24), MX + x - 12, MY + y - 12)
    u.put(marker_icon("dungeon", 26), MX + 745 - 13, MY + 462 - 13)
    hero = marker_icon("hero", 30).rotate(-25, resample=Image.BICUBIC); sh = Image.new("RGBA", (44, 44), (0, 0, 0, 0)); ImageDraw.Draw(sh).ellipse((10, 14, 34, 36), fill=(0, 0, 0, 90)); sh = sh.filter(ImageFilter.GaussianBlur(3))
    u.put(sh, MX + 466 - 22 + 2, MY + 300 - 22 + 4); u.put(hero, MX + 466 - 15, MY + 300 - 15)
    # zone label top-left, zoom top-right, coords bottom-right (translucent panels on the map)
    zw_ = int(u.tl("Crosshaven", 16, 700)) + int(u.tl("Hub · 1-10", 11, 700)) + 46
    u.put(u.nine("panel_9slice", zw_, 34), MX + 10, MY + 10); u.T(MX + 22, MY + 27, "Crosshaven", 16, 700); u.T(MX + zw_ - 4, MY + 28, "Hub · 1-10", 11, 700, u.dim, "rm")
    zx = MX + MW - 10 - 34
    u.btn(zx, MY + 10, 34, 34, None, "dark", glyph_img=glyph("plus", 18, t["icon"], 2.0)); u.btn(zx, MY + 48, 34, 34, None, "dark", glyph_img=glyph("minus", 18, t["icon"], 2.0))
    u.put(u.nine("panel_9slice", 54, 24), zx - 60, MY + 15); u.T(zx - 33, MY + 27, "100%", 11, 800, u.text_c, "mm")
    u.put(u.nine("panel_9slice", 118, 26), MX + MW - 10 - 118, MY + MH - 10 - 26); u.T(MX + MW - 10 - 59, MY + MH - 10 - 13, "x 128   y 94", 11, 700, u.dim, "mm")
    # legend
    ly = 610; u.sep(14, 590, 972)
    items = [("hero", "You", 30), ("quest", "Quest giver", 20), ("dungeon", "Dungeon entrance", 22), ("exit", "Zone exit", 18), ("house", "Building", 22), ("market", "Market", 22)]
    x = 16
    for k_, lb, px in items:
        ic = marker_icon(k_, px)
        if k_ == "exit": ic = g2("arrow_exit", 18, GOLD, 1.8)
        elif k_ == "hero": ic = marker_icon("hero", 24)
        u.put(ic, x, ly - ic.height // 2 + 1); u.T(x + ic.width + 8, ly, lb, 13, 600, u.text_c); x += ic.width + 8 + int(u.tl(lb, 13, 600)) + 34
    u.T(984, ly, "Drag to pan · Scroll to zoom", 11, 600, u.dim, "rm")
    return u.L

# ================================================================= compositing
WINDOWS = {   # name -> (builder, active menu button)
    "inventory_equipment": (lambda v: win_inventory(v, "equipment"), "inventory"),
    "character_stats": (lambda v: win_inventory(v, "stats"), "character"),
    "spells": (win_spells, "spells"), "quests": (win_quests, "quests"), "map": (win_map, "map"),
    "dungeons": (win_dungeons, "dungeons"), "koliseo": (win_koliseo, "koliseo"), "shop": (win_shop, "shop"), "settings": (win_settings, "settings"),
}
PRIMARY_FRAME = "real_crosshaven_frame"

def window_pos(name, w, h):
    """Windows are draggable floating panels: placed left of centre so the hero at screen centre (960,540) stays visible;
    the Map is centred."""
    if name == "map": return (1920 - w) // 2, (1080 - h) // 2 - 30
    x = max(24, min(700 - w // 2, 930 - w)); y = max(48, min((1080 - h) // 2 - 30, 900 - h)); return x, y

def chat_layer(variant):
    lay = Image.new("RGBA", (1920, 1080), (0, 0, 0, 0)); B.TEXT_K = 1
    lines = [("[Town]", "#e0b23a", "Mira: anyone up for the Granary cellar?"), ("[Guild]", "#6fd0d0", "Tomas: selling 20 bloodroot, 5 coins each"), ("[Crossroads]", "#cfe0e6", "Ironjaw: heading to the farm, back soon")]
    x, y = 16, 1080 - 16 - 3 * 26 - 2 * 4
    for i, (ch, cc, tx) in enumerate(lines):
        w = int(tlen(ch + " " + tx, 13, 600)) + 24
        lay.alpha_composite(box_piece(w, 26, 6, "#12181a", "#12181a", 0.72, "#2c3a3c", 1), (x, y + i * 30))
        draw_text(lay, (x + 10, y + i * 30 + 13), ch, 13, 800, cc, "lm"); draw_text(lay, (x + 10 + int(tlen(ch + " ", 13, 800)), y + i * 30 + 13), tx, 13, 600, "#f1ece2", "lm")
    return lay

def compose(name, variant, frame_path):
    builder, active = WINDOWS[name]
    win = builder(variant)
    img, hud = B.render(frame_path, variant, 1920, "auto", active=active, spells_key="P")
    out = img.convert("RGBA"); out.alpha_composite(chat_layer(variant))
    x, y = window_pos(name, *win.size)
    sh, pad = B.shadow_of(win, 8, (0, 6), 0.50)
    cx, cy = max(0, -(x - pad)), max(0, -(y - pad + 6))
    out.alpha_composite(sh.crop((cx, cy, sh.width, sh.height)), (x - pad + cx, y - pad + 6 + cy))
    out.alpha_composite(win, (x, y))
    return out.convert("RGB"), win, (x, y)

def name_of(p): return os.path.splitext(os.path.basename(p))[0]

def build(names, variants, frames, outdir, contact=True):
    os.makedirs(outdir, exist_ok=True); res = {}
    for fr in frames:
        suf = "" if name_of(fr) == PRIMARY_FRAME else "_" + name_of(fr)
        for nm in names:
            for v in variants:
                img, win, pos = compose(nm, v, fr)
                fn = "panel_%s_%s%s_1920x1080.png" % (nm, v, suf); img.save(os.path.join(outdir, fn))
                if not suf: win.save(os.path.join(outdir, "win_%s_%s.png" % (nm, v)))
                res[fn] = dict(window=list(win.size), pos=list(pos)); print(fn, win.size, pos)
    if contact and "dark" in variants and all(n in WINDOWS for n in names) and len(names) == len(WINDOWS):
        make_contact(outdir)
    return res

def make_contact(outdir):
    cw, ch = 640, 360; sheet = Image.new("RGB", (cw * 3, ch * 3), (20, 24, 26)); order = list(WINDOWS)
    for i, nm in enumerate(order):
        im = Image.open(os.path.join(outdir, "panel_%s_dark_1920x1080.png" % nm)).convert("RGBA").resize((cw, ch), Image.LANCZOS)
        lay = Image.new("RGBA", im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(lay); lb = nm.replace("_", " · ")
        f = B.font(13, 800); wd = int(f.getlength(lb)) + 14
        d.rounded_rectangle((6, ch - 26, 6 + wd, ch - 6), radius=5, fill=(18, 24, 26, 200)); d.text((13, ch - 16), lb, font=f, fill=(241, 236, 226, 255), anchor="lm")
        im.alpha_composite(lay); sheet.paste(im.convert("RGB"), ((i % 3) * cw, (i // 3) * ch))
    sheet.save(os.path.join(outdir, "contact_panels.png")); print("contact_panels.png")

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--panel", default="all", help="window name or 'all' (%s)" % ", ".join(WINDOWS))
    ap.add_argument("--variant", default="both", choices=["dark", "light", "both"])
    ap.add_argument("--frame", help="one frame (default: every frame in frames/)")
    ap.add_argument("--out", default=os.path.join(HERE, "out", "panels"))
    a = ap.parse_args()
    names = list(WINDOWS) if a.panel == "all" else [a.panel]
    variants = ["dark", "light"] if a.variant == "both" else [a.variant]
    frames = [a.frame] if a.frame else sorted(glob.glob(os.path.join(HERE, "frames", "*.jpg")) + glob.glob(os.path.join(HERE, "frames", "*.png")))
    build(names, variants, frames, a.out)

if __name__ == "__main__":
    main()
