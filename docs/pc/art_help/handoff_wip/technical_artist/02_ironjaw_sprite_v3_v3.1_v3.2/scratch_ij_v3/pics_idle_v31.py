#!/usr/bin/env python3
"""Pictures for the Ironjaw v3.1 idle S stance fix."""
import io, numpy as np, sys
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, "/workspace/scratch/ij_v3")
from idle_fix_comp import SPEC, STRIP, seam_curve
V3 = "/workspace/art/ironjaw_full/v3"; PREV = "/workspace/scratch/ij_v3/idle_prev"; OUT = "/workspace/luca_pics/chars"
F = lambda s: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", s)
FB = lambda s: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", s)
PX, PY = 82, 140; BGC = (122, 112, 92); TXT = (245, 240, 220); DARK = (36, 38, 32)
def ld(p): return Image.open(p).convert("RGBA")
def save_jpg(im, path, maxkb=245):
    q = 92
    while True:
        b = io.BytesIO(); im.convert("RGB").save(b, "JPEG", quality=q, optimize=True, subsampling=0 if q >= 80 else 2)
        if b.tell() <= maxkb*1024 or q <= 40: break
        q -= 4
    open(path, "wb").write(b.getvalue()); return b.tell()//1024, q
def sole(im):
    a = np.array(im)[..., 3] > 0; return int(np.where(a.any(1))[0].max())
def panel(im, z, title, sub):
    w, h = im.size; bg = Image.new("RGBA", (w, h), BGC + (255,)); bg.alpha_composite(im)
    big = bg.resize((w*z, h*z), Image.NEAREST); d = ImageDraw.Draw(big)
    s = sole(im)
    d.line([(0, PY*z), (w*z, PY*z)], fill=(230, 40, 40), width=2)                       # pivot / feet line
    d.line([(0, (s+1)*z), (w*z, (s+1)*z)], fill=(255, 220, 0), width=1)                 # under the lowest opaque row
    d.line([(PX*z, (PY-8)*z), (PX*z, (PY+6)*z)], fill=(230, 40, 40), width=2)
    d.text((4, PY*z - 18), "pivot y140", fill=(255, 90, 90), font=F(14))
    d.text((w*z - 150, (s+1)*z - 17), f"lowest row {s} ({s-PY:+d})", fill=(255, 220, 0), font=F(14))
    hdr = Image.new("RGBA", (w*z, 48), DARK + (255,)); dh = ImageDraw.Draw(hdr)
    dh.text((6, 4), title, fill=TXT, font=FB(17)); dh.text((6, 26), sub, fill=(200, 200, 185), font=F(14))
    c = Image.new("RGBA", (w*z, h*z + 48)); c.paste(hdr, (0, 0)); c.paste(big, (0, 48)); return c
def crop4(im, box, z, title, seam=False):
    x0, y0, x1, y1 = box
    bg = Image.new("RGBA", im.size, BGC + (255,)); bg.alpha_composite(im)
    c = bg.crop(box).resize(((x1-x0)*z, (y1-y0)*z), Image.NEAREST); d = ImageDraw.Draw(c)
    if seam:
        S = seam_curve(SPEC)
        for x in range(x0, x1):
            yy = (S[x]-y0)*z
            d.line([((x-x0)*z, yy), ((x-x0+1)*z, yy)], fill=(0, 255, 255), width=1)
            if x+1 < x1 and S[x+1] != S[x]:
                d.line([((x-x0+1)*z, yy), ((x-x0+1)*z, (S[x+1]-y0)*z)], fill=(0, 255, 255), width=1)
        for (x, y) in STRIP:
            d.rectangle([((x-x0)*z, (y-y0)*z), ((x-x0+1)*z-1, (y-y0+1)*z-1)], outline=(255, 0, 255))
    hdr = Image.new("RGBA", (c.width, 24), DARK + (255,)); ImageDraw.Draw(hdr).text((6, 4), title, fill=TXT, font=F(14))
    o = Image.new("RGBA", (c.width, c.height + 24)); o.paste(hdr, (0, 0)); o.paste(c, (0, 24)); return o
def hrow(ims, gap=10, bg=(50, 54, 46)):
    W = sum(i.width for i in ims) + gap*(len(ims)+1); H = max(i.height for i in ims) + 2*gap
    c = Image.new("RGBA", (W, H), bg + (255,)); x = gap
    for i in ims: c.alpha_composite(i, (x, gap)); x += i.width + gap
    return c
old = ld(f"{PREV}/ironjaw_idle_S_f00.png"); new = ld(f"{V3}/idle/ironjaw_idle_S_f00.png")
walk = ld(f"{V3}/walk/ironjaw_walk_S_f00.png"); att = ld(f"{V3}/attack/ironjaw_attack_S_f00.png")
z = 2
top = hrow([panel(old, z, "BEFORE idle S f00 (v3.0)", "neutral stand, feet 27 px left"),
            panel(new, z, "AFTER idle S f00 (v3.1)", "upper body v3.0 idle + walk f00 legs"),
            panel(walk, z, "walk S f00", "stride start (leg source)"),
            panel(att, z, "attack S f00", "same stride")])
box = (30, 88, 112, 136)
bot = hrow([crop4(old, box, 4, "before, hip 4x"), crop4(new, box, 4, "after, hip 4x (clean)"),
            crop4(new, box, 4, "after 4x: cyan seam, magenta kept px", seam=True), crop4(walk, box, 4, "walk S f00, hip 4x")])
cap = Image.new("RGBA", (max(top.width, bot.width), 54), (50, 54, 46, 255)); d = ImageDraw.Draw(cap)
d.text((10, 6), "IRONJAW v3.1 idle S stance fix: red = pivot/feet line y140, yellow = under lowest opaque row. S/W idle -> walk/attack/hit/death f0:", fill=TXT, font=F(16))
d.text((10, 28), "lowest foot jump 12 px -> 0 px, feet centre 30.5-31 px -> 0-0.5 px, torso unchanged. W = file flip of S. Pixels: 7590 from v3.0 idle + 1007 from walk S f00, 0 new.", fill=TXT, font=F(16))
W = max(top.width, bot.width); pic = Image.new("RGBA", (W, cap.height + top.height + bot.height), (50, 54, 46, 255))
pic.alpha_composite(cap, (0, 0)); pic.alpha_composite(top, (0, cap.height)); pic.alpha_composite(bot, (0, cap.height + top.height))
print("jpg", pic.size, save_jpg(pic, f"{OUT}/ironjaw_idle_fix.jpg"))

# ---- GIF: idle S 4 frames x2 then walk S 12 frames, sprite at 0.5 game scale, everything x2 for viewing, on grass
S_GAME, ZV = 0.5, 2; TW, TH = 64*ZV, 32*ZV
GW, GH = 300, 240; fx, fy = GW//2, 190
rng = np.random.default_rng(7)
grass = np.zeros((GH, GW, 3), float)
ys, xs = np.mgrid[0:GH, 0:GW]
u = ((xs - fx)/(TW/2) + (ys - fy)/(TH/2))/2; v = ((ys - fy)/(TH/2) - (xs - fx)/(TW/2))/2
iu, iv = np.floor(u + 0.5), np.floor(v + 0.5)
tile = (iu*7 + iv*13) % 3
base = np.array([[86, 112, 62], [80, 106, 58], [92, 116, 66]], float)[tile.astype(int)]
grass = base + rng.normal(0, 6, (GH, GW, 1)) * np.array([0.8, 1, 0.6])
edge = (np.abs(u + 0.5 - iu - 0.5 + 0.5) < 0) # placeholder
fu, fv = (u + 0.5) % 1, (v + 0.5) % 1
grid = (np.minimum(fu, 1-fu) < 0.012) | (np.minimum(fv, 1-fv) < 0.012)
grass[grid] = grass[grid]*0.85
centre = (iu == 0) & (iv == 0); grass[centre] = grass[centre]*1.08
G = Image.fromarray(np.clip(grass, 0, 255).astype(np.uint8)).convert("RGBA")
def sprite_frame(im, label):
    w, h = im.size; s = S_GAME*ZV
    sm = im.resize((round(w*S_GAME), round(h*S_GAME)), Image.LANCZOS)           # game draw scale 0.5
    sm = sm.resize((sm.width*ZV, sm.height*ZV), Image.NEAREST)                     # x2 for viewing
    c = G.copy(); c.alpha_composite(sm, (round(fx - PX*s), round(fy - PY*s)))
    d = ImageDraw.Draw(c); d.line([(fx-6, fy), (fx+6, fy)], fill=(230, 40, 40)); d.line([(fx, fy-6), (fx, fy+3)], fill=(230, 40, 40))
    d.rectangle([0, 0, GW, 18], fill=DARK); d.text((5, 2), label, fill=TXT, font=F(12))
    return c.convert("RGB")
frames, durs = [], []
idle = [ld(f"{V3}/idle/ironjaw_idle_S_f{i:02d}.png") for i in range(4)]
for loop in range(2):
    for i in range(4): frames.append(sprite_frame(idle[i], f"v3.1 idle S f{i:02d} (4 fps)  0.5x game, x2 view")); durs.append(250)
for i in range(12):
    frames.append(sprite_frame(ld(f"{V3}/walk/ironjaw_walk_S_f{i:02d}.png"), f"walk S f{i:02d} (17 fps, in place)  0.5x game, x2")); durs.append(60)
pal = frames[0].quantize(colors=255, method=Image.MEDIANCUT)
q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
q[0].save(f"{OUT}/ironjaw_idle_to_walk.gif", save_all=True, append_images=q[1:], duration=durs, loop=0, optimize=False, disposal=1)
import os; print("gif", GW, GH, len(frames), os.path.getsize(f"{OUT}/ironjaw_idle_to_walk.gif")//1024, "KB")
# stills of the switch for checking
st = Image.new("RGB", (GW*3, GH)); [st.paste(frames[k], (GW*j, 0)) for j, k in enumerate((7, 8, 9))]
st.save("/workspace/scratch/ij_v3/idlefix/gif_switch_stills.png"); bot.convert("RGB").save("/workspace/scratch/ij_v3/idlefix/hip_row.png")
