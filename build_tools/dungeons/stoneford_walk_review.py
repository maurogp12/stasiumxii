"""Walk review media for the Stoneford world monsters (package Z1).

For each monster and facing: a frame strip of one walk cycle (with the
planted feet marked) and a clip of the creature crossing a Stoneford grass
field at 1:1 (cell pixels) at its real ground speed, so a sliding foot shows.

  python3 stoneford_walk_review.py OUTDIR [id ...]
"""
import json
import math
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402

gkit.use_world("stoneford")
MON = os.path.join(gkit.OUT, "monsters")
TILE = os.path.join(gkit.REPO, "art/world/crosshaven/tiles/_2x/golden_plains_c.png")
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
W, H = 1280, 720
TILE_SCALE = 2.35  # a 128x64 world master tile at the cell's hero scale


def frames(mid, act, f):
    meta = json.load(open(os.path.join(MON, mid, "meta.json")))
    n = meta["actions"][act]["frames"]
    return [Image.open(os.path.join(MON, mid, act, "%s_%s_f%02d.png" % (act, f, i))).convert("RGBA") for i in range(n)], meta


def ground(offset):
    t = Image.open(TILE).convert("RGBA")
    t = t.resize((int(t.width * TILE_SCALE), int(t.height * TILE_SCALE)), Image.LANCZOS)
    tw, th = t.width, t.height
    g = Image.new("RGBA", (W, H), (88, 120, 50, 255))
    ox, oy = offset
    for j in range(-2, H // (th // 2) + 3):
        for i in range(-2, W // tw + 3):
            x = i * tw + (tw // 2 if j % 2 else 0) - int(ox) % tw
            y = j * (th // 2) - int(oy) % th
            g.alpha_composite(t, (x, y))
    return g


def strip(mid, f, out):
    fr, meta = frames(mid, "walk", f)
    g = meta.get("gait", {}).get(f)
    cw, ch = fr[0].size
    sheet = Image.new("RGBA", (cw * 6, ch * 2 + 40), (172, 172, 172, 255))
    d = ImageDraw.Draw(sheet)
    for i, im in enumerate(fr):
        x, y = (i % 6) * cw, (i // 6) * ch + 40
        sheet.alpha_composite(im, (x, y))
        d.text((x + 6, y + 4), "f%02d" % i, fill=(30, 30, 30), font=FONT)
        px, py = meta["pivot"]
        d.line([(x + px - 6, y + py), (x + px + 6, y + py)], fill=(200, 0, 0))
        if g:
            for leg, track in g["feet"].items():
                fx, fy = track[i]
                planted = g["stance"][leg][i]
                d.ellipse([x + fx - 4, y + fy - 4, x + fx + 4, y + fy + 4], outline=(0, 120, 255) if planted else (255, 140, 0), width=2)
    title = "%s  walk %s  (%d frames @ 17.144 fps)" % (meta["name"], f, len(fr))
    if g:
        title += "  ground speed %.2f cell px/frame; blue = planted foot, orange = swing" % g["speed_px_per_frame"]
    else:
        title += "  (flies: no planted feet)"
    d.text((8, 10), title, fill=(20, 20, 20), font=FONT)
    sheet.convert("RGB").save(out, quality=92)


def clip(mid, f, out, seconds=None):
    fr, meta = frames(mid, "walk", f)
    g = meta.get("gait", {}).get(f)
    speed = g["speed_px_per_frame"] if g else 3.0
    dx, dy = (math.cos(math.atan2(0.5, 1)), math.sin(math.atan2(0.5, 1))) if f == "S" else (math.cos(math.atan2(-0.5, 1)), math.sin(math.atan2(-0.5, 1)))
    cw, ch = fr[0].size
    px, py = meta["pivot"]
    travel = W * 0.75
    n = int(travel / speed) if seconds is None else int(seconds * 17.144)
    start = (W * 0.12, H * 0.25 if f == "S" else H * 0.85)
    tmp = tempfile.mkdtemp()
    for k in range(n):
        x = start[0] + dx * speed * k
        y = start[1] + dy * speed * k
        frame = ground((0, 0))
        im = fr[k % len(fr)]
        frame.alpha_composite(im, (int(round(x - px)), int(round(y - py))))
        d = ImageDraw.Draw(frame)
        d.text((10, 10), "%s  walk %s  1:1 cell px, real ground speed" % (meta["name"], f), fill=(255, 255, 255), font=FONT)
        frame.convert("RGB").save(os.path.join(tmp, "%05d.jpg" % k), quality=93)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "17.144", "-i", os.path.join(tmp, "%05d.jpg"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", out], check=True)
    for p in os.listdir(tmp):
        os.remove(os.path.join(tmp, p))
    os.rmdir(tmp)


if __name__ == "__main__":
    outdir = sys.argv[1]
    os.makedirs(outdir, exist_ok=True)
    strip_only = "--strip" in sys.argv
    ids = [a for a in sys.argv[2:] if not a.startswith("--")] or sorted(os.listdir(MON))
    for mid in ids:
        meta = json.load(open(os.path.join(MON, mid, "meta.json")))
        for f in ("S", "E"):
            if f not in meta["actions"].get("walk", {}).get("files", {}):
                continue
            strip(mid, f, os.path.join(outdir, "%s_walk_%s_strip.jpg" % (mid, f)))
            if not strip_only:
                clip(mid, f, os.path.join(outdir, "%s_walk_%s.mp4" % (mid, f)))
            print(mid, f, "done")
