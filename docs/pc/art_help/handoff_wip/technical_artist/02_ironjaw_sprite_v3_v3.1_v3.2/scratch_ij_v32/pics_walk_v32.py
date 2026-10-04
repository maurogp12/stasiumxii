#!/usr/bin/env python3
"""ironjaw_v32_walk.gif: v3.2 walk in all four facings, idle -> one 12-frame walk cycle (1.44 cells) -> idle, on an iso grass strip.
Game draw scale 0.578 (Lanczos, preview only), then x2 nearest for viewing. Travel = 89.2/12 cell px per walk frame along the
2:1 diagonal x 0.578 = 4.296 board px per frame (x2 view); one walk frame per GIF frame, GIF delays 60,60,60,60,60,50 ms
(mean 58.33 ms = the authored 17.144 fps) -> one cell (35.78 board px) per 0.486 s = recommended_tile_sec. Legs and travel match."""
import os, math, numpy as np
from PIL import Image, ImageDraw, ImageFont
V = "/workspace/art/ironjaw_full/v3.2"; OUT = "/workspace/luca_pics/chars/ironjaw_v32_walk.gif"
DS, ZV = 0.578, 2; S = DS*ZV; PX, PY = 82, 140
TW, TH = 64*ZV, 32*ZV                      # tile in view px
STEP = 89.2/12*DS*ZV                        # view px per walk frame along the diagonal
U = np.array([2, 1])/math.sqrt(5)
NW = int(os.environ.get("NW", "12")); CELLS = NW*STEP/ZV/math.hypot(32, 16)   # one 12-frame cycle = 1.44 cells (GIF size cap 400 KB)
F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
FB = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
DIRS = {"S": (1, 1), "W": (-1, 1), "N": (-1, -1), "E": (1, -1)}
PW, PH = int(os.environ.get("PW", "400")), int(os.environ.get("PH", "300"))
def ld(st, fc, i):
    im = Image.open(f"{V}/{st}/ironjaw_{st}_{fc}_f{i:02d}.png").convert("RGBA")
    sm = im.resize((round(165*DS), round(157*DS)), Image.LANCZOS)
    return sm.resize((sm.width*ZV, sm.height*ZV), Image.NEAREST)
def background(fc):
    sx, sy = DIRS[fc]; total = CELLS*TW/2, CELLS*TH/2
    x0 = PW/2 - sx*total[0]/2; y0 = PH/2 + 70 - sy*total[1]/2        # start tile centre (feet), path centred
    bg = Image.new("RGB", (PW, PH), (58, 52, 40)); d = ImageDraw.Draw(bg)
    cols = [(96, 124, 64), (88, 116, 58), (102, 128, 68)]
    for k in range(-1, int(math.ceil(CELLS))+2):
        cx, cy = x0 + sx*k*TW/2, y0 + sy*k*TH/2
        poly = [(cx, cy-TH/2), (cx+TW/2, cy), (cx, cy+TH/2), (cx-TW/2, cy)]
        d.polygon(poly, fill=cols[k % 3], outline=(70, 92, 48))
    return bg, (x0, y0)
def frame(fc, im, pos, label, bg):
    c = bg.copy().convert("RGBA"); x, y = pos
    c.alpha_composite(im, (int(round(x - PX*S)), int(round(y - PY*S))))
    d = ImageDraw.Draw(c); d.rectangle([0, 0, PW, 20], fill=(34, 36, 30)); d.text((6, 3), f"{fc}  {label}", fill=(240, 236, 220), font=F)
    return c.convert("RGB")
seq = []   # (state, frame index or walk frame, distance travelled, label, duration)
seq.append(("idle", 0, 0.0, "idle f00", 700))
pattern = [60, 60, 60, 60, 60, 50]
for k in range(NW+1):
    if k < NW: seq.append(("walk", k % 12, k*STEP, f"walk f{k % 12:02d}  0.486 s/cell", pattern[k % 6]))
seq.append(("idle", 0, NW*STEP, "idle f00", 900))
bgs = {fc: background(fc) for fc in "SWNE"}; cache = {}
frames = []
for st, i, dist, label, dur in seq:
    canvas = Image.new("RGB", (2*PW + 6, 2*PH + 6 + 40), (24, 24, 20))
    for j, fc in enumerate("SWNE"):
        bg, (x0, y0) = bgs[fc]; sx, sy = DIRS[fc]
        pos = (x0 + sx*U[0]*dist, y0 + sy*U[1]*dist)
        key = (st, fc, i)
        if key not in cache: cache[key] = ld(st, fc, i)
        canvas.paste(frame(fc, cache[key], pos, label, bg), ((j % 2)*(PW+6), 40 + (j//2)*(PH+6)))
    d = ImageDraw.Draw(canvas)
    d.text((8, 4), "IRONJAW v3.2 walk, game scale 0.578 x2. 1 cell per 0.486 s at 17.14 fps: feet stick.", fill=(240, 236, 220), font=FB)
    d.text((8, 22), f"idle -> one 12-frame walk cycle ({NW*STEP/ZV/math.hypot(32, 16):.2f} cells) -> idle. N/E walk now starts on the idle stance boot.", fill=(210, 210, 195), font=F)
    frames.append((canvas, dur))
# global palette (index 255 reserved = transparent), no dithering; frames after the first store only changed pixels
NCOL = int(os.environ.get("NCOL", "28"))
# palette: the 5 flat background/UI colours + median cut over sprite pixels only (so every entry serves the art)
spr = np.concatenate([np.array(v.convert("RGBA")).reshape(-1, 4) for v in cache.values()]); spr = spr[spr[:, 3] > 200][:, :3]
sq = Image.fromarray(spr[::3].reshape(-1, 1, 3).astype(np.uint8)).quantize(colors=NCOL-8, method=Image.MEDIANCUT)
fixed = [(58, 52, 40), (96, 124, 64), (88, 116, 58), (102, 128, 68), (70, 92, 48), (34, 36, 30), (240, 236, 220), (24, 24, 20)]
plist = [c for t in fixed for c in t] + sq.getpalette()[:(NCOL-8)*3]
pal = Image.new("P", (1, 1)); pal.putpalette(plist)
full = [np.array(f.quantize(palette=pal, dither=Image.Dither.NONE)) for f, _ in frames]
palette = plist + [0, 0, 0]*(256-NCOL)
out = []
for k, a in enumerate(full):
    b = a.copy()
    if k: b[a == full[k-1]] = 255
    im = Image.fromarray(b.astype(np.uint8), "P"); im.putpalette(palette); out.append(im)
out[0].save(OUT, save_all=True, append_images=out[1:], duration=[d for _, d in frames], loop=0, optimize=False,
            disposal=1, transparency=255)
# read back and verify every composited frame equals the intended (quantized) frame
chk = Image.open(OUT); bad = 0
for k in range(len(full)):
    chk.seek(k); got = np.array(chk.convert("RGB")); want = np.array(Image.fromarray(full[k].astype(np.uint8), "P").convert("RGB")) if False else None
    ref = np.array(plist, np.uint8).reshape(-1, 3)[full[k]]
    bad += int((got != ref).any(-1).sum())
print("readback mismatched px", bad)
print(OUT, frames[0][0].size, len(frames), "walk frames", NW, os.path.getsize(OUT)//1024, "KB")
frames[4][0].save("/workspace/scratch/ij_v32/gif_f04.png"); frames[min(20, len(frames)-1)][0].save("/workspace/scratch/ij_v32/gif_f20.png")
