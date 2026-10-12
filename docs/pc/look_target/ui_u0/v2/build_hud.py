#!/usr/bin/env python
"""STASIUM XII  U0 v2 HUD mockups (direction A, charcoal & teal).

HUD is drawn procedurally (Pillow + Nunito) and composited on REAL game frames.
Every dimension is defined in 1920x1080 design px and multiplied by `s`
(= width/1920) so the 1280x720 render is drawn natively, not resized.

  python build_hud.py --frame frames/real_crosshaven_frame.jpg --variant dark --out out/x.png
  python build_hud.py --frame frames/X.jpg --variant light --size 1280 --out out/x_1280.png
  python build_hud.py --all            # every frame in frames/, both variants, both sizes,
                                       # kit, kit.json, contact, details, metrics
  python build_hud.py --kit            # only the UI kit PNGs + kit.json
"""
import argparse, glob, json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SS = 4  # supersampling for shapes
FONT_DIRS = ["/usr/share/fonts/truetype/sand-box/google/Nunito/Nunito-VariableFont_wght.ttf",
             "/usr/share/fonts/truetype/sand-box/google/Inter/Inter-VariableFont_opsz,wght.ttf"]
FONT_PATH = next(p for p in FONT_DIRS if os.path.exists(p))

def hx(c, a=None):
    c = c.lstrip('#'); t = tuple(int(c[i:i+2], 16) for i in (0, 2, 4))
    return t if a is None else t + (int(round(a * 255)),)

RARITY = {"normal": "#9a9a9a", "rare": "#4a8fe0", "legendary": "#e0b23a", "ultra": "#9a62e0"}
GOLD = "#d9ae52"; ACCENT_OK = "#3fae5a"; ACCENT_MAIN = "#e0912f"; HP_RED = "#d04848"; XP_TEAL = "#3aa6a6"

THEMES = {
  "dark": dict(panel_top="#20282b", panel_bot="#1b2124", opacity=0.88, border="#6f8a86", glow="#6f8a86", glow_a=0.22,
               text="#f1ece2", dim="#a9b0ad", icon="#f1ece2", slot_fill="#12181a", slot_a=0.80, slot_border="#4b5d5a",
               btn_top="#2c3639", btn_bot="#1f282b", btn_border="#6f8a86", track="#0f1416",
               tt_top="#2c5a5c", tt_bot="#1f4446", pill="#2c5a5c", pill_text="#f1ece2", shadow_text="#0c1012", orb_in_top="#2a3336", orb_in_bot="#10161a"),
  "light": dict(panel_top="#efe6d2", panel_bot="#e4d8bd", opacity=0.88, border="#8a7a5a", glow="#ffffff", glow_a=0.45,
               text="#2b2a26", dim="#6b665a", icon="#3a3a34", slot_fill="#cdbf9f", slot_a=0.85, slot_border="#8a7a5a",
               btn_top="#e9dec5", btn_bot="#d6c8a6", btn_border="#8a7a5a", track="#b5a780",
               tt_top="#2c5a5c", tt_bot="#1f4446", pill="#2c5a5c", pill_text="#f6f1e4", shadow_text="#f4ecd8", orb_in_top="#3a4548", orb_in_bot="#161d20"),
}

# ----------------------------------------------------------------- fonts / text
_fc = {}
def font(px, weight=700):
    px = max(6.0, round(float(px), 2))   # fractional sizes + RAQM give even spacing at 2/3 scale
    k = (px, weight)
    if k not in _fc:
        try: f = ImageFont.truetype(FONT_PATH, px, layout_engine=ImageFont.Layout.RAQM)
        except Exception: f = ImageFont.truetype(FONT_PATH, px)
        try: f.set_variation_by_axes([weight] if "Nunito" in FONT_PATH else [14, weight])
        except Exception: pass
        _fc[k] = f
    return _fc[k]

TEXT_K = 1   # text supersampling: 1 at 1920 (native hinted), 4 at reduced scales (variable-font advances are wrong when hinted at <9px)

def draw_text(layer, xy, txt, px, weight, color, anchor="lm", stroke=None, sw=1, alpha=1.0):
    """Crisp text on a transparent layer. Drawn on a tmp layer whose RGB equals the ink so no dark fringes."""
    K = TEXT_K; f = font(px * K, weight); x, y = xy
    def one(col, strokew):
        bb = f.getbbox(txt, anchor=anchor, stroke_width=strokew * K)
        pad = 2
        x0 = int(math.floor(bb[0] / K)) - pad; y0 = int(math.floor(bb[1] / K)) - pad
        x1 = int(math.ceil(bb[2] / K)) + pad; y1 = int(math.ceil(bb[3] / K)) + pad
        tmp = Image.new("RGBA", ((x1 - x0) * K, (y1 - y0) * K), hx(col) + (0,))
        ImageDraw.Draw(tmp).text((-x0 * K, -y0 * K), txt, font=f, fill=hx(col) + (255,), anchor=anchor,
                                 stroke_width=strokew * K, stroke_fill=hx(col) + (255,))
        if K > 1: tmp = tmp.resize((x1 - x0, y1 - y0), Image.LANCZOS)
        if alpha < 1: tmp.putalpha(tmp.split()[3].point(lambda v: int(v * alpha)))
        layer.alpha_composite(tmp, (int(x) + x0, int(y) + y0))
    if stroke: one(stroke, max(1, sw))
    one(color, 0)

def tlen(txt, px, weight=700):
    return font(px * TEXT_K, weight).getlength(txt) / TEXT_K

# ----------------------------------------------------------------- primitives
def vgrad(W, H, c1, c2):
    a = np.array(hx(c1), float); b = np.array(hx(c2), float)
    t = np.linspace(0, 1, H)[:, None, None]
    return np.broadcast_to(a * (1 - t) + b * t, (H, W, 3)).copy()

def rr_mask(W, H, inset, rad, corners=None):
    m = Image.new("L", (W, H), 0)
    i = inset
    kw = {} if corners is None else {"corners": corners}
    if W - 1 - i > i and H - 1 - i > i:
        ImageDraw.Draw(m).rounded_rectangle((i, i, W - 1 - i, H - 1 - i), radius=max(0, rad - i), fill=255, **kw)
    return np.asarray(m, float) / 255.0

def fin(arr, w, h):
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    return im.resize((w, h), Image.LANCZOS)

def box_piece(w, h, r, top, bot, alpha, border, bw=1, glow=None, glow_w=2, glow_a=0.2, corners=None, hl=None):
    """Rounded translucent box with 1px border, faint inner glow and optional top highlight (all in px)."""
    W, H = w * SS, h * SS
    o = rr_mask(W, H, 0, r * SS, corners)
    i1 = rr_mask(W, H, bw * SS, r * SS, corners)
    rgb = vgrad(W, H, top, bot)
    a = o * alpha
    if glow:
        i2 = rr_mask(W, H, (bw + glow_w) * SS, r * SS, corners)
        g = np.clip(i1 - i2, 0, 1)[..., None] * glow_a
        rgb = rgb * (1 - g) + np.array(hx(glow)) * g
    if hl:
        hm = np.zeros((H, W)); hm[bw * SS:(bw + 1) * SS, :] = 1
        hm = hm * i1 * hl[1]
        rgb = rgb * (1 - hm[..., None]) + np.array(hx(hl[0])) * hm[..., None]
    b = np.clip(o - i1, 0, 1)
    rgb = rgb * (1 - b[..., None]) + np.array(hx(border)) * b[..., None]
    a = a * (1 - b) + b
    out = np.dstack([rgb, a * 255])
    return fin(out, w, h)

def nine(img, m, size):
    """9-slice stretch. m=(l,t,r,b) in px of the source image."""
    w, h = size; sw_, sh_ = img.size
    l, t, r, b = m
    l = min(l, w // 2); r = min(r, w - l if w - l < r else r); t = min(t, h // 2); b = min(b, h - t if h - t < b else b)
    sl, st, sr, sb = min(m[0], sw_ // 2), min(m[1], sh_ // 2), min(m[2], sw_ // 2), min(m[3], sh_ // 2)
    l, r, t, b = min(l, sl), min(r, sr), min(t, st), min(b, sb)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    xs_src = [0, l, sw_ - r, sw_]; xs_dst = [0, l, w - r, w]
    ys_src = [0, t, sh_ - b, sh_]; ys_dst = [0, t, h - b, h]
    for j in range(3):
        for i in range(3):
            dw, dh = xs_dst[i + 1] - xs_dst[i], ys_dst[j + 1] - ys_dst[j]
            if dw <= 0 or dh <= 0: continue
            reg = img.crop((xs_src[i], ys_src[j], xs_src[i + 1], ys_src[j + 1]))
            if reg.size != (dw, dh): reg = reg.resize((dw, dh), Image.BILINEAR)
            out.alpha_composite(reg, (xs_dst[i], ys_dst[j]))
    return out

def tint(img, color):
    out = Image.new("RGBA", img.size, hx(color) + (255,)); out.putalpha(img.split()[3]); return out

def fit(img, box):
    img = img.copy(); img.thumbnail((box, box), Image.LANCZOS); return img

def glyph(name, px, color, lw=1.6):
    """Small AA glyphs drawn with ImageDraw at SS then downsampled. px = output size."""
    W = px * SS; im = Image.new("RGBA", (W, W), hx(color) + (0,)); d = ImageDraw.Draw(im)
    c = hx(color) + (255,); L = max(2, int(lw * SS * px / 16)); u = W / 16
    if name in ("chev_up", "chev_down"):
        yy = (5, 11) if name == "chev_down" else (11, 5)
        d.line([(3 * u, yy[0] * u), (8 * u, yy[1] * u), (13 * u, yy[0] * u)], fill=c, width=L, joint="curve")
    elif name == "plus":
        d.line([(3 * u, 8 * u), (13 * u, 8 * u)], fill=c, width=L); d.line([(8 * u, 3 * u), (8 * u, 13 * u)], fill=c, width=L)
    elif name == "minus":
        d.line([(3 * u, 8 * u), (13 * u, 8 * u)], fill=c, width=L)
    elif name == "check":
        d.line([(3 * u, 8.5 * u), (6.5 * u, 12 * u), (13 * u, 4 * u)], fill=c, width=L + SS, joint="curve")
    elif name == "envelope":
        d.rounded_rectangle((2 * u, 4 * u, 14 * u, 12.5 * u), radius=1.2 * u, outline=c, width=L)
        d.line([(2.6 * u, 5 * u), (8 * u, 9.2 * u), (13.4 * u, 5 * u)], fill=c, width=L, joint="curve")
    elif name == "bolt":
        d.polygon([(9.5 * u, 1.5 * u), (4 * u, 9 * u), (7.6 * u, 9 * u), (6.4 * u, 14.5 * u), (12 * u, 6.6 * u), (8.3 * u, 6.6 * u)], fill=c)
    elif name == "tri_up":
        d.polygon([(8 * u, 4 * u), (13 * u, 11 * u), (3 * u, 11 * u)], fill=c)
    elif name == "tri_down":
        d.polygon([(8 * u, 12 * u), (13 * u, 5 * u), (3 * u, 5 * u)], fill=c)
    return im.resize((px, px), Image.LANCZOS)

# ----------------------------------------------------------------- the kit
class Kit:
    """All reusable UI pieces for (variant, scale). Drawn once; the mockup composites these."""
    def __init__(self, variant, s=1.0, with_assets=True):
        self.v, self.s, self.t = variant, s, THEMES[variant]
        self.sc = lambda x: int(round(x * s))
        self.px1 = max(1, self.sc(1))
        self.pieces = {}; self.meta = {}
        self._build()

    def add(self, name, img, m=None, note=None):
        self.pieces[name] = img
        self.meta[name] = {"size": list(img.size), "nine_slice": list(m) if m else None, **({"note": note} if note else {})}

    def _build(self):
        sc, t, b1 = self.sc, self.t, self.px1
        R = sc(6)
        # panel 96x96, 12 margins
        N, M = sc(96), sc(12)
        self.add("panel_9slice", box_piece(N, N, R, t["panel_top"], t["panel_bot"], t["opacity"], t["border"], b1, t["glow"], sc(2), t["glow_a"]), (M,) * 4)
        # buttons 96x32, 8 margins
        BW, BH, BM = sc(96), sc(32), sc(8)
        def btn(top, bot, border, **kw):
            return box_piece(BW, BH, R, top, bot, 1.0, border, b1, hl=("#ffffff", 0.22 if self.v == "dark" else 0.5), **kw)
        self.add("button_green", btn("#4cc06a", "#2f8f48", "#1f6a33"), (BM,) * 4)
        self.add("button_orange", btn("#eda646", "#c97a1e", "#8f5510"), (BM,) * 4)
        self.add("button_dark", btn(t["btn_top"], t["btn_bot"], t["btn_border"]), (BM,) * 4)
        self.add("button_dark_active", box_piece(BW, BH, R, t["btn_top"], t["btn_bot"], 1.0, GOLD, b1, glow=GOLD, glow_w=sc(2), glow_a=0.28,
                                                 hl=("#ffffff", 0.22 if self.v == "dark" else 0.5)), (BM,) * 4, "gold trim = active/selected")
        # title bar 96x24 (top corners rounded only)
        TW, TH = sc(96), sc(24)
        self.add("title_bar", box_piece(TW, TH, R, t["tt_top"], t["tt_bot"], 1.0, "#17383a" if self.v == "dark" else "#17383a", b1,
                                        corners=(True, True, False, False), hl=("#ffffff", 0.18)), (BM, sc(6), BM, sc(6)))
        # pill + banner accent
        self.add("pill", box_piece(sc(48), sc(20), sc(10), t["pill"], t["pill"], 1.0, "#3aa6a6" if self.v == "dark" else "#1f4446", b1), (sc(10), sc(10), sc(10), sc(10)))
        self.add("banner_accent", box_piece(sc(6), sc(36), R, "#3aa6a6", "#2c7f80", 1.0, "#2c7f80", 1, corners=(True, False, False, True)), None)
        # slots 44x44
        S44 = sc(44)
        sl = lambda border, bw: box_piece(S44, S44, sc(5), t["slot_fill"], t["slot_fill"], t["slot_a"], border, bw, "#000000", sc(2), 0.35 if self.v == "dark" else 0.12)
        self.add("slot", sl(t["slot_border"], b1), None)
        for k, c in RARITY.items():
            self.add("slot_rarity_" + k, sl(c, max(1, sc(2))), None)
        # xp bar: track 200x6 (3px caps), fill
        XW, XH = sc(200), max(3, sc(6))
        self.add("xp_bar_track", box_piece(XW, XH, XH // 2, t["track"], t["track"], 0.9, t["track"], 1), (XH // 2 + 1, 0, XH // 2 + 1, 0))
        self.add("xp_bar_fill", box_piece(XW, XH, XH // 2, "#4cc3c3", "#2f8f8f", 1.0, "#2f8f8f", 1), (XH // 2 + 1, 0, XH // 2 + 1, 0))
        # checkbox
        CB = sc(14)
        self.add("checkbox", box_piece(CB, CB, sc(3), t["slot_fill"], t["slot_fill"], 0.9, t["border"], b1), None)
        cbc = box_piece(CB, CB, sc(3), "#3fae5a", "#2f8f48", 1.0, "#1f6a33", b1)
        cbc.alpha_composite(glyph("check", CB, "#ffffff", 1.7)); self.add("checkbox_checked", cbc, None)
        # minimap frame 200x200 outer, 4px ring, teal 2px top strip, hole in centre
        FS = sc(200); FB = sc(4); self.fb = FB
        self.add("minimap_frame", self._mm_frame(FS, FB), (sc(12),) * 4, "centre is transparent; fixed 200x200 (square)")
        # orb
        self.add("orb", self._orb(sc(96)), None, "96px; HP ring 75%, stamina arc, crest, level medallion '23'")
        # bar: stretched from panel_9slice in compose

    def _mm_frame(self, FS, FB):
        t, sc = self.t, self.sc
        W = FS * SS; fb = FB * SS
        outer = rr_mask(W, W, 0, sc(5) * SS)
        hole = np.zeros((W, W)); hole[fb:W - fb, fb:W - fb] = 1
        ring = outer * (1 - hole)
        rgb = np.zeros((W, W, 3)) + np.array(hx(t["panel_bot"] if self.v == "dark" else "#d6c8a6"))
        o1 = rr_mask(W, W, self.px1 * SS, sc(5) * SS)
        rgb[(outer - o1) > 0.5] = hx(t["border"])
        # teal 2px top strip just inside the border
        y0, y1 = self.px1 * SS, (self.px1 + max(1, sc(2))) * SS
        strip = np.zeros((W, W)); strip[y0:y1, :] = 1
        strip = strip * o1 * (1 - hole)
        rgb = rgb * (1 - strip[..., None]) + np.array(hx("#3aa6a6")) * strip[..., None]
        # inner 1px edge (hole border)
        hb = np.zeros((W, W)); hb[fb - self.px1 * SS:W - fb + self.px1 * SS, fb - self.px1 * SS:W - fb + self.px1 * SS] = 1; hb = hb * (1 - hole) * ring
        rgb = rgb * (1 - hb[..., None] * 0.9) + np.array(hx(t["track"])) * hb[..., None] * 0.9
        a = ring * 0.97
        return fin(np.dstack([rgb, a * 255]), FS, FS)

    def _orb(self, D):
        t, sc = self.t, self.sc
        W = D * SS; c = W / 2; img = Image.new("RGBA", (W, W), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
        r_out = W / 2 - 0.5 * SS
        def ell(r, fill):
            d.ellipse((c - r, c - r, c + r, c + r), fill=fill)
        gw = max(1.5, 1.5 * self.s) * SS
        ell(r_out, hx(GOLD, 1))                                  # thin gold trim ring
        ell(r_out - gw, hx("#0d1214", 1))                        # dark HP track
        r_hp_o, r_hp_i = r_out - gw - 1 * SS, r_out - gw - 7 * self.s * SS
        # HP red ring: 75% from 12 o'clock clockwise
        ring = Image.new("L", (W, W), 0); rd = ImageDraw.Draw(ring)
        rd.pieslice((c - r_hp_o, c - r_hp_o, c + r_hp_o, c + r_hp_o), -90, -90 + 270, fill=255)
        rd.ellipse((c - r_hp_i, c - r_hp_i, c + r_hp_i, c + r_hp_i), fill=0)
        red = Image.new("RGBA", (W, W), hx(HP_RED) + (255,)); red.putalpha(ring); img.alpha_composite(red)
        # stamina arc (green) hugging the bottom-right, replacing the gold trim there
        st = Image.new("L", (W, W), 0); sd = ImageDraw.Draw(st)
        so, si = r_out + 0.5 * SS, r_out - 3 * self.s * SS
        sd.pieslice((c - so, c - so, c + so, c + so), 22, 78, fill=255); sd.ellipse((c - si, c - si, c + si, c + si), fill=0)
        gr = Image.new("RGBA", (W, W), hx(ACCENT_OK) + (255,)); gr.putalpha(st); img.alpha_composite(gr)
        # inner disc with soft radial gradient
        r_in = r_hp_i - 1 * SS
        yy, xx = np.mgrid[0:W, 0:W]; dist = np.hypot(xx - c, yy - c) / r_in
        g = np.clip(dist, 0, 1)[..., None]
        rgb = np.array(hx(t["orb_in_top"])) * (1 - g) + np.array(hx(t["orb_in_bot"])) * g
        m = (dist <= 1).astype(float)
        disc = Image.fromarray(np.dstack([rgb, m * 255]).astype(np.uint8), "RGBA"); img.alpha_composite(disc)
        ImageDraw.Draw(img).ellipse((c - r_in, c - r_in, c + r_in, c + r_in), outline=hx("#000000", 0.5), width=SS)
        # crest ~60% of orb width
        crest = Image.open(os.path.join(HERE, "assets", "crest_ironjaw.png")).convert("RGBA")
        cs = int(round(D * 0.60)) * SS
        crest = fit(crest, cs)
        img.alpha_composite(crest, (int(c - crest.width / 2), int(c - crest.height / 2 - 1 * SS)))
        # level medallion, docked at the bottom centre
        md = sc(28) * SS; mc = (c, W - md / 2 - 1 * SS)
        mdr = ImageDraw.Draw(img)
        mdr.ellipse((mc[0] - md / 2, mc[1] - md / 2, mc[0] + md / 2, mc[1] + md / 2), fill=hx("#14191b", 1))
        mdr.ellipse((mc[0] - md / 2, mc[1] - md / 2, mc[0] + md / 2, mc[1] + md / 2), outline=hx(GOLD, 1), width=max(SS, int(1.5 * self.s * SS)))
        out = img.resize((D, D), Image.LANCZOS)
        draw_text(out, (int(round(mc[0] / SS)), int(round(mc[1] / SS)) ), "23", 13, 800, "#f1ece2", "mm")
        return out

# ----------------------------------------------------------------- minimap content
def minimap_content(kind, hole, s):
    """Simplified stylised top-down painting, flat colours. Drawn natively at `hole` px square."""
    K = hole / 192.0 * SS; W = hole * SS
    im = Image.new("RGBA", (W, W), hx("#8fc23a") + (255,)); d = ImageDraw.Draw(im)
    P = lambda pts: [(x * K, y * K) for x, y in pts]
    def line(pts, wd, col): d.line(P(pts), fill=hx(col), width=max(1, int(wd * K)), joint="curve")
    def poly(pts, col, outline=None): d.polygon(P(pts), fill=hx(col), outline=hx(outline) if outline else None)
    def circ(x, y, r, col, outline=None): d.ellipse(((x - r) * K, (y - r) * K, (x + r) * K, (y + r) * K), fill=hx(col), outline=hx(outline) if outline else None, width=max(1, int(K)))
    def rect(x0, y0, x1, y1, col, outline=None): d.rectangle((x0 * K, y0 * K, x1 * K, y1 * K), fill=hx(col), outline=hx(outline) if outline else None, width=max(1, int(K)))
    npcs = []
    if kind == "farm":
        f = 0.155
        T = lambda X, Y: (96 + (X * 2.3443 - 960) * f, 96 + (Y * 2.3443 - 540) * f)   # frame coords are the 819px preview coords
        TT = lambda pts: [T(*p) for p in pts]
        # grass texture patches
        for (x, y, r) in [(30, 40, 9), (150, 30, 7), (40, 150, 8), (160, 160, 10), (120, 90, 6), (70, 120, 5), (170, 100, 6)]:
            circ(x, y, r, "#86b834")
        poly(TT([(250, 0), (497, 0), (385, 64)]), "#d6a83e")                                   # wheat field
        line(TT([(0, 180), (110, 235), (240, 300), (360, 350), (470, 400), (560, 445), (610, 470)]), 8, "#c79b66")  # dirt road
        line(TT([(250, 292), (322, 258)]), 4, "#c79b66")                                           # side path
        plot = TT([(215, 208), (380, 125), (548, 205), (385, 305)])
        poly(plot, "#7a5638", "#5b4029")                                                           # fenced farm plot
        for k in range(5):
            a = 0.18 + k * 0.16
            p1 = (plot[0][0] + (plot[3][0] - plot[0][0]) * a, plot[0][1] + (plot[3][1] - plot[0][1]) * a)
            p2 = (plot[1][0] + (plot[2][0] - plot[1][0]) * a, plot[1][1] + (plot[2][1] - plot[1][1]) * a)
            line([p1, p2], 2.2, "#6fae2f" if k % 2 else "#d9b44a")
        bx = TT([(552, 205), (600, 178), (648, 205), (600, 232)])                                  # barn
        poly(bx, "#b35a3c", "#7e3b27")
        poly(TT([(560, 200), (600, 180), (640, 200), (600, 222)]), "#d4a04a")
        rect(*T(412, 300), *T(456, 330), "#c79b66", "#8a6a3f")                                      # hay cart
        for (x, y) in [(26, 152), (105, 270), (215, 384), (572, 370), (684, 313), (350, 458), (360, 123), (676, 96), (25, 98)]:
            circ(*T(x, y), 2.6, "#6aa82f", "#4f8a24")
        for (x, y) in [(220, 92), (300, 80), (545, 85), (627, 97), (738, 215), (710, 262)]:
            circ(*T(x, y), 4.2, "#5b9a2c", "#3f7320")
        npcs = [T(352, 190), T(598, 238)]
    elif kind == "crossroads":
        for (x, y, r) in [(30, 30, 14), (160, 35, 11), (35, 160, 10), (165, 165, 14)]:
            circ(x, y, r, "#86b834")
        poly([(0, 150), (60, 192), (110, 192), (192, 128), (192, 168), (150, 192), (192, 192), (0, 192)], "#4aa0c8")       # water lower-left / right
        poly([(0, 150), (0, 192), (60, 192)], "#4aa0c8")
        line([(96, 0), (96, 192)], 12, "#c79b66"); line([(0, 96), (192, 96)], 12, "#c79b66")
        circ(96, 96, 27, "#b8b2a4", "#8d877a")                                                                           # cobbled plaza
        circ(96, 96, 17, "#c4beb0")
        for (x0, y0, x1, y1) in [(24, 30, 52, 52), (130, 28, 164, 50), (28, 126, 56, 150), (132, 128, 166, 152), (62, 8, 86, 24), (108, 168, 136, 186)]:
            rect(x0, y0, x1, y1, "#b35a3c", "#7e3b27"); rect(x0, y0, x1, y0 + 8, "#8f4430")
        for (x, y) in [(20, 80), (172, 70), (60, 60), (150, 118)]:
            circ(x, y, 4, "#5b9a2c", "#3f7320")
        circ(96, 84, 3.2, "#f1ece2", "#3a3a34")                                                                          # obelisk dot
        npcs = [(110, 108), (80, 70)]
    else:  # dungeon room
        d.rectangle((0, 0, W, W), fill=hx("#2b3235"))
        rect(36, 44, 156, 150, "#4a5457", "#6f8a86"); rect(84, 150, 108, 192, "#4a5457", "#6f8a86"); rect(0, 84, 36, 108, "#4a5457", "#6f8a86")
        rect(92, 40, 100, 46, "#8a5a2f")
        for (x, y) in [(70, 70), (128, 80), (120, 124)]: circ(x, y, 4, "#d04848", "#7a1f1f")
        for (x, y) in [(50, 60), (140, 60), (50, 138), (140, 138)]: rect(x - 3, y - 3, x + 3, y + 3, "#6b655c")
        npcs = []
    # NPC '!' icons
    out = im.resize((hole, hole), Image.LANCZOS)
    cnt = Image.new("RGBA", (W, W), (0, 0, 0, 0)); dd = ImageDraw.Draw(cnt)
    for (x, y) in npcs:
        r = 6.2 * K
        dd.ellipse(((x * K - r), (y * K - r), (x * K + r), (y * K + r)), fill=hx(GOLD, 1), outline=hx("#5a4310", 1), width=max(1, int(K)))
    # hero arrow (white triangle, dark outline), pointing up-right
    cx, cy = 96 * K, 96 * K; ang = math.radians(-20)
    pts = [(0, -8.5), (6.2, 7), (0, 3.4), (-6.2, 7)]
    ar = [(cx + (px * math.cos(ang) - py * math.sin(ang)) * K, cy + (px * math.sin(ang) + py * math.cos(ang)) * K) for px, py in pts]
    dd.polygon(ar, fill=hx("#ffffff", 1), outline=hx("#1d2326", 1)); dd.line(ar + [ar[0]], fill=hx("#1d2326", 1), width=max(1, int(1.2 * K)), joint="curve")
    out.alpha_composite(cnt.resize((hole, hole), Image.LANCZOS))
    for (x, y) in npcs:
        draw_text(out, (int(round(x * hole / 192)), int(round(y * hole / 192))), "!", 10 * hole / 192, 800, "#3a2a08", "mm")
    return out

# ----------------------------------------------------------------- compositing
def shadow_of(piece, blur, off, alpha=0.35):
    pad = blur * 3 + abs(off[1]) + 2
    a = Image.new("L", (piece.width + 2 * pad, piece.height + 2 * pad), 0)
    a.paste(piece.split()[3], (pad, pad))
    a = a.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * alpha))
    sh = Image.new("RGBA", a.size, (0, 0, 0, 0)); sh.putalpha(a)
    return sh, pad

class Hud:
    def __init__(self, size, kit):
        self.size = size; self.k = kit; self.s = kit.s; self.sc = kit.sc
        self.layer = Image.new("RGBA", size, (0, 0, 0, 0)); self.sh = Image.new("RGBA", size, (0, 0, 0, 0))
        self.rects = {}
    def put(self, img, x, y, shadow=True, name=None):
        if shadow:
            sh, pad = shadow_of(img, self.sc(2), (0, self.sc(2)))
            self.sh.alpha_composite(sh, (x - pad, y - pad + self.sc(2))) if x - pad >= 0 and y - pad >= 0 else self._safe(self.sh, sh, x - pad, y - pad + self.sc(2))
        self.layer.alpha_composite(img, (x, y))
        if name: self.rects[name] = (x, y, img.width, img.height)
    def _safe(self, dst, src, x, y):
        cx, cy = max(0, -x), max(0, -y)
        src = src.crop((cx, cy, src.width, src.height)); dst.alpha_composite(src, (x + cx, y + cy))
    def panel(self, x, y, w, h, name=None, shadow=True):
        img = nine(self.k.pieces["panel_9slice"], self.k.meta["panel_9slice"]["nine_slice"], (w, h)); self.put(img, x, y, shadow, name); return img
    def text(self, *a, **kw): draw_text(self.layer, *a, **kw)

def glyph_btn(h, x, y, w, hgt, piece, glyph_img=None, name=None):
    img = nine(h.k.pieces[piece], h.k.meta[piece]["nine_slice"], (w, hgt)); h.put(img, x, y, True, name)
    if glyph_img is not None:
        h.layer.alpha_composite(glyph_img, (x + (w - glyph_img.width) // 2, y + (hgt - glyph_img.height) // 2))

def render(frame_path, variant, width=1920, minimap="auto", active="inventory", spells_key=""):
    """active: menu button name (or iterable of names) drawn with the gold trim. spells_key: hotkey label on the Spells button."""
    global TEXT_K
    act = {active} if isinstance(active, str) else set(active or ())
    s = width / 1920.0; H = int(round(1080 * s)); size = (width, H); TEXT_K = 1 if width >= 1920 else 4
    kit = Kit(variant, s); t = kit.t; sc = kit.sc
    bg = Image.open(frame_path).convert("RGB")
    if bg.size != size: bg = bg.resize(size, Image.LANCZOS)    # scene only; HUD is never resized
    hud = Hud(size, kit)
    # ---------------- bottom bar
    BARW, BARH, MARG = 1040, 64, 8
    bx, by, bw, bh = sc((1920 - BARW) / 2), size[1] - sc(MARG) - sc(BARH), sc(BARW), sc(BARH)
    hud.panel(bx, by, bw, bh, "bar")
    # xp bar: 6px line along the bottom of the bar, 45%
    xh = kit.pieces["xp_bar_track"].height; xpad = sc(14); xw = bw - 2 * xpad; xy = by + bh - xh - max(1, sc(3))
    track = nine(kit.pieces["xp_bar_track"], kit.meta["xp_bar_track"]["nine_slice"], (xw, xh)); hud.put(track, bx + xpad, xy, False, "xp_bar")
    fw = int(round(xw * 0.45)); fill = nine(kit.pieces["xp_bar_fill"], kit.meta["xp_bar_fill"]["nine_slice"], (fw, xh)); hud.layer.alpha_composite(fill, (bx + xpad, xy))
    # slots / buttons are 44px, vertically centred above the xp line
    S44 = sc(44); sy = by + (xy - by - S44) // 2 + sc(1); gap = sc(4)
    menu = [("character", "O"), ("inventory", "I"), ("spells", spells_key), ("quests", "L"), ("map", "M"), ("dungeons", ""), ("koliseo", ""), ("shop", ""), ("settings", "Esc")]
    mx0 = bx + sc(10)
    for i, (nm, key) in enumerate(menu):
        x = mx0 + i * (S44 + gap)
        ic = Image.open(os.path.join(HERE, "assets", "icons", nm + ".png")).convert("RGBA")
        ic = fit(ic, sc(28))
        if variant == "light": ic = tint(ic, t["icon"])
        glyph_btn(hud, x, sy, S44, S44, "button_dark_active" if nm in act else "button_dark", ic, "menu_" + nm)
        if key: hud.text((x + S44 - sc(3), sy + S44 - sc(7)), key, 10 * s, 800, t["dim"] if nm not in act else GOLD, "rm")
    # orb
    orb = kit.pieces["orb"]; D = orb.width
    ox = (size[0] - D) // 2; oy = by - sc(26)
    hud.put(orb, ox, oy, True, "orb")
    # HP numbers on a small pill above the orb
    tw = tlen("240 / 240", 14 * s) + sc(14); ph = sc(20); pill = nine(kit.pieces["panel_9slice"], kit.meta["panel_9slice"]["nine_slice"], (int(tw), ph))
    px_ = (size[0] - pill.width) // 2; py_ = oy - ph - sc(3)
    hud.put(pill, px_, py_, True, "hp_pill")
    hud.text((size[0] // 2, py_ + ph // 2), "240 / 240", 14 * s, 800, t["text"], "mm")
    # item bar
    # NOTE: assets/items/*.png file names are scrambled by slice_assets.py (component order); map by what each file SHOWS.
    ITEM_FILE = {"potion_red": "potion_red", "potion_blue": "potion_blue", "bread": "bread", "rope": "herbs",
                 "bandage": "pickaxe", "quest_scroll": "rope", "pickaxe": "scroll"}
    items = [("potion_red", "normal", 12), ("potion_blue", "rare", 5), ("bread", "normal", 20), ("rope", "normal", 6),
             ("quest_scroll", "ultra", 1), ("bandage", "normal", 8), ("pickaxe", "legendary", 0), (None, "normal", 0)]
    ix0 = ox + D + sc(34)
    for i, (nm, rar, q) in enumerate(items):
        x = ix0 + i * (S44 + gap)
        hud.put(kit.pieces["slot_rarity_" + rar] if nm else kit.pieces["slot"], x, sy, True, "slot%d" % (i + 1))
        if nm:
            im = fit(Image.open(os.path.join(HERE, "assets", "items", ITEM_FILE[nm] + ".png")).convert("RGBA"), sc(34))
            hud.layer.alpha_composite(im, (x + (S44 - im.width) // 2, sy + (S44 - im.height) // 2))
        hud.text((x + sc(4), sy + sc(7)), str(i + 1), 9 * s, 700, t["dim"], "lm", stroke=t["shadow_text"], sw=1)
        if q > 1: hud.text((x + S44 - sc(4), sy + S44 - sc(8)), str(q), 11 * s, 800, t["text"] if variant == "dark" else "#fffaf0", "rm", stroke="#14191b", sw=1)
    ax = ix0 + 8 * (S44 + gap) + sc(2); ag = sc(14)
    for j, g in enumerate(("tri_up", "tri_down")):
        hud.layer.alpha_composite(glyph(g, ag, t["dim"]), (ax, sy + sc(6) + j * (ag + sc(6))))
    # ---------------- minimap (top right)
    m_ = sc(8); FS = kit.pieces["minimap_frame"].width; mx = size[0] - m_ - FS; my = m_
    fb = kit.fb; hole = FS - 2 * fb
    kind = minimap if minimap != "auto" else ("crossroads" if "crossroads" in os.path.basename(frame_path).lower() else
                                              "dungeon" if any(k in os.path.basename(frame_path).lower() for k in ("granary", "dungeon", "fight")) else "farm")
    content = minimap_content(kind, hole, s)
    silhouette = Image.new("RGBA", (FS, FS), (0, 0, 0, 255)); silhouette.putalpha(Image.new("L", (FS, FS), 255))
    sm = Image.new("RGBA", (FS, FS), (0, 0, 0, 0)); sm.putalpha(kit.pieces["minimap_frame"].split()[3].point(lambda v: 255)) ; 
    full = Image.new("RGBA", (FS, FS), (0, 0, 0, 255))
    sh, pad = shadow_of(full, sc(2), (0, sc(2))); hud._safe(hud.sh, sh, mx - pad, my - pad + sc(2))
    hud.layer.alpha_composite(content, (mx + fb, my + fb))
    hud.layer.alpha_composite(kit.pieces["minimap_frame"], (mx, my)); hud.rects["minimap"] = (mx, my, FS, FS)
    # zoom +/- (16px) bottom-right inside
    zb = sc(16)
    for j, g in enumerate(("plus", "minus")):
        glyph_btn(hud, mx + FS - fb - sc(3) - zb, my + FS - fb - sc(3) - 2 * zb - sc(2) + j * (zb + sc(2)), zb, zb, "button_dark", glyph(g, zb, t["icon"], 1.8), "zoom_" + g)
    # zone info panel
    iy = my + FS + sc(6); ih = sc(64)
    hud.panel(mx, iy, FS, ih, "zone_info")
    hud.text((mx + sc(10), iy + sc(19)), "Crossroads", 13 * s, 800, t["text"], "lm")
    hud.text((mx + sc(10), iy + sc(40)), "x 128   y 94", 11 * s, 600, t["dim"], "lm")
    sw_, sh_ = sc(64), sc(24)
    glyph_btn(hud, mx + FS - sc(8) - sw_, iy + sc(8), sw_, sh_, "button_orange", None, "shop_btn")
    hud.text((mx + FS - sc(8) - sw_ // 2, iy + sc(8) + sh_ // 2), "Shop", 12 * s, 800, "#ffffff", "mm", stroke="#7a4a10", sw=1)
    q = sc(24)
    for j, g in enumerate(("envelope", "bolt")):
        glyph_btn(hud, mx + FS - sc(8) - 2 * q - sc(4) + j * (q + sc(4)), iy + ih - sc(8) - q, q, q, "button_dark", glyph(g, sc(16), t["icon"], 1.6), "quick_" + g)
    # ---------------- quest tracker (200 wide, aligned with the minimap column)
    qy = iy + ih + sc(6); qw = FS; th = sc(22); rowh = sc(38)
    qh = th + sc(6) + 3 * rowh + sc(2)
    hud.panel(mx, qy, qw, qh, "quest_tracker")
    tb = nine(kit.pieces["title_bar"], kit.meta["title_bar"]["nine_slice"], (qw - 2 * kit.px1, th)); hud.layer.alpha_composite(tb, (mx + kit.px1, qy + kit.px1))
    hud.text((mx + sc(10), qy + kit.px1 + th // 2), "Quests", 13 * s, 800, "#f1ece2", "lm")
    hud.layer.alpha_composite(glyph("chev_down", sc(16), "#f1ece2"), (mx + qw - sc(8) - sc(16) - kit.px1, qy + kit.px1 + (th - sc(16)) // 2))
    quests = [("A Farmer's Worry", "Talk to the Farmer", "", True), ("Granary Rats", "Defeat 3 Granary Rats", " 1/3", False), ("Herb Gathering", "Collect 6 Bloodroot", " 2/6", False)]
    for i, (nm, obj, cnt, done) in enumerate(quests):
        ry = qy + th + sc(6) + i * rowh
        cb = kit.pieces["checkbox_checked" if done else "checkbox"]; hud.layer.alpha_composite(cb, (mx + sc(10), ry + sc(3)))
        hud.text((mx + sc(10) + cb.width + sc(7), ry + sc(10)), nm, 13 * s, 800, t["dim"] if done else t["text"], "lm")
        hud.text((mx + sc(10) + cb.width + sc(7), ry + sc(27)), obj, 11 * s, 600, t["dim"], "lm")
        if cnt: hud.text((mx + sc(10) + cb.width + sc(7) + tlen(obj, 11 * s, 600), ry + sc(27)), cnt, 11 * s, 800, t["text"] if variant == "dark" else "#7a4a10", "lm")
    # ---------------- zone banner (top left)
    zx, zy, zh = m_, m_, sc(36)
    zn = tlen("Crossroads", 20 * s); pw = int(tlen("1-10", 13 * s)) + sc(20)
    zw = int(sc(14) + zn + sc(14) + pw + sc(10))
    hud.panel(zx, zy, zw, zh, "zone_banner")
    acc = kit.pieces["banner_accent"]; hud.layer.alpha_composite(acc.crop((0, 0, acc.width, min(acc.height, zh))), (zx, zy))
    hud.text((zx + sc(14), zy + zh // 2), "Crossroads", 20 * s, 800, t["text"], "lm")
    pl = nine(kit.pieces["pill"], kit.meta["pill"]["nine_slice"], (pw, sc(20))); hud.layer.alpha_composite(pl, (zx + zw - sc(10) - pw, zy + (zh - sc(20)) // 2))
    hud.text((zx + zw - sc(10) - pw // 2, zy + zh // 2), "1-10", 13 * s, 800, t["pill_text"], "mm")
    # ---------------- composite
    out = bg.convert("RGBA"); out.alpha_composite(hud.sh); out.alpha_composite(hud.layer)
    return out.convert("RGB"), hud

def metrics(hud, size):
    a = np.asarray(hud.layer.split()[3])
    W, H = size
    cov = (a >= 100).sum() / (W * H)
    any_ = (a > 0).sum() / (W * H)
    cx0, cx1, cy0, cy1 = int(W * 0.34), int(W * 0.66), int(H * 0.25), int(H * 0.72)
    centre = int((np.asarray(hud.sh.split()[3])[cy0:cy1, cx0:cx1] > 0).sum() + (a[cy0:cy1, cx0:cx1] > 0).sum())
    return dict(coverage_pct=round(100 * cov, 2), coverage_any_alpha_pct=round(100 * any_, 2),
                hud_in_centre_zone_px=centre, centre_zone=[cx0, cy0, cx1, cy1],
                rects={k: list(v) for k, v in hud.rects.items()})

# ----------------------------------------------------------------- kit export
def write_kit(outdir):
    os.makedirs(os.path.join(outdir, "kit"), exist_ok=True)
    meta = {}
    for v in ("dark", "light"):
        k = Kit(v, 1.0)
        for name, img in k.pieces.items():
            fn = "%s_%s.png" % (name, v); img.save(os.path.join(outdir, "kit", fn))
            meta[fn] = dict(k.meta[name], variant=v)
        # bar (bottom bar panel, no contents) from the same 9-slice
        bar = nine(k.pieces["panel_9slice"], k.meta["panel_9slice"]["nine_slice"], (1040, 64)); fn = "bar_%s.png" % v; bar.save(os.path.join(outdir, "kit", fn))
        meta[fn] = {"size": [1040, 64], "nine_slice": None, "variant": v, "note": "panel_9slice stretched to the bottom bar size"}
        # shop-style note: minimap content is separate
    with open(os.path.join(outdir, "kit", "kit.json"), "w") as f:
        json.dump({"scale": "1920x1080 design px; margins are [left, top, right, bottom]",
                   "panel_9slice": {"size": [96, 96], "margins": [12, 12, 12, 12]}, "files": meta}, f, indent=2)
    with open(os.path.join(outdir, "kit.json"), "w") as f:
        json.dump({"scale": "1920x1080 design px; margins are [left, top, right, bottom]",
                   "panel_9slice": {"size": [96, 96], "margins": [12, 12, 12, 12]}, "files": meta}, f, indent=2)

def name_of(p): return os.path.splitext(os.path.basename(p))[0]

def build_all(outdir):
    os.makedirs(outdir, exist_ok=True)
    write_kit(outdir)
    frames = sorted(glob.glob(os.path.join(HERE, "frames", "*.jpg")) + glob.glob(os.path.join(HERE, "frames", "*.png")))
    allm = {}; renders = {}
    for fr in frames:
        for v in ("dark", "light"):
            for w in (1920, 1280):
                img, hud = render(fr, v, w)
                fn = "mockup_%s_%s_%dx%d.png" % (name_of(fr), v, w, round(w * 9 / 16)); img.save(os.path.join(outdir, fn))
                hud.layer.save(os.path.join(outdir, "overlay_%s_%s_%d.png" % (name_of(fr), v, w))) if False else None
                allm[fn] = metrics(hud, img.size); renders[(fr, v, w)] = img
                if w == 1920:
                    hud.layer.save(os.path.join(outdir, "hud_overlay_%s_%s_1920x1080.png" % (name_of(fr), v)))
    json.dump(allm, open(os.path.join(outdir, "metrics.json"), "w"), indent=1)
    # contact (dark | light) per frame, stacked
    rows = []
    for fr in frames:
        a, b = renders[(fr, "dark", 1920)], renders[(fr, "light", 1920)]
        row = Image.new("RGB", (1920, 540)); row.paste(a.resize((960, 540), Image.LANCZOS), (0, 0)); row.paste(b.resize((960, 540), Image.LANCZOS), (960, 0)); rows.append(row)
    if rows:
        c = Image.new("RGB", (1920, 540 * len(rows)))
        for i, r in enumerate(rows): c.paste(r, (0, 540 * i))
        c.save(os.path.join(outdir, "contact.png"))
    for i, fr in enumerate(frames):
        a, b = renders[(fr, "dark", 1920)], renders[(fr, "light", 1920)]
        bar = lambda im: im.crop((420, 960, 1500, 1080)).resize((2160, 240), Image.NEAREST)
        mm = lambda im: im.crop((1600, 0, 1920, 440)).resize((640, 880), Image.NEAREST)
        db = Image.new("RGB", (2160, 480)); db.paste(bar(a), (0, 0)); db.paste(bar(b), (0, 240))
        dm = Image.new("RGB", (1280, 880)); dm.paste(mm(a), (0, 0)); dm.paste(mm(b), (640, 0))
        sfx = "" if i == 0 else "_" + name_of(fr)
        db.save(os.path.join(outdir, "detail_bar%s.png" % sfx)); dm.save(os.path.join(outdir, "detail_minimap%s.png" % sfx))
        db.save(os.path.join(outdir, "detail_bar_%s.png" % name_of(fr))); dm.save(os.path.join(outdir, "detail_minimap_%s.png" % name_of(fr)))
    return allm

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frame"); ap.add_argument("--variant", choices=["dark", "light"], default="dark")
    ap.add_argument("--out"); ap.add_argument("--size", type=int, default=1920, choices=[1920, 1280])
    ap.add_argument("--minimap", default="auto", choices=["auto", "farm", "crossroads", "dungeon"])
    ap.add_argument("--all", action="store_true"); ap.add_argument("--kit", action="store_true")
    a = ap.parse_args()
    outdir = os.path.join(HERE, "out")
    if a.all:
        m = build_all(outdir); print(json.dumps({k: v["coverage_pct"] for k, v in m.items()}, indent=1)); return
    if a.kit: write_kit(outdir); print("kit written"); return
    if not a.frame or not a.out: ap.error("--frame and --out required (or --all / --kit)")
    img, hud = render(a.frame, a.variant, a.size, a.minimap)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True); img.save(a.out)
    print(a.out, img.size, json.dumps({k: v for k, v in metrics(hud, img.size).items() if k != "rects"}))

if __name__ == "__main__":
    main()
