"""Contact sheets (one per monster, every frame of every action, S and E) and the review clip.

  python3 mock_monsters.py [--clip OUT.mp4] [--scale 0.5]
Sheets go to art/pc/dungeons/old_granary_cellar/_mock/<id>_contact.png on grey 172,
with the cell pivot marked.
"""
import glob
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402

MON = os.path.join(gkit.OUT, "monsters")
MOCK = os.path.join(gkit.OUT, "_mock")
ORDER = ["idle", "walk", "attack", "hit", "death", "summon"]


def frames(mid, act, f):
    return sorted(glob.glob(os.path.join(MON, mid, act, "%s_%s_f*.png" % (act, f))))


def sheet(mid, sc=0.5):
    meta = json.load(open(os.path.join(MON, mid, "meta.json")))
    cw, ch = meta["cell"]
    pw, ph = int(cw * sc), int(ch * sc)
    rows = []
    for act in ORDER:
        if act not in meta["actions"]:
            continue
        for f in ("S", "E"):
            rows.append((act, f, frames(mid, act, f)))
    ncol = max(len(r[2]) for r in rows)
    lab = 90
    W, H = lab + ncol * pw, len(rows) * (ph + 4) + 30
    img = Image.new("RGB", (W, H), (172, 172, 172))
    d = ImageDraw.Draw(img)
    d.text((6, 6), "%s  cell %dx%d  pivot %s  %.3f fps  (shown at %.2fx)" % (meta["name"], cw, ch, meta["pivot"], meta["fps"], sc), fill=(0, 0, 0))
    y = 30
    for act, f, fl in rows:
        d.text((6, y + ph // 2 - 6), "%s %s (%d)" % (act, f, len(fl)), fill=(0, 0, 0))
        for i, p in enumerate(fl):
            im = Image.open(p).convert("RGBA").resize((pw, ph), Image.LANCZOS)
            x = lab + i * pw
            img.paste(im, (x, y), im)
            px, py = x + meta["pivot"][0] * sc, y + meta["pivot"][1] * sc
            d.line([(px - 4, py), (px + 4, py)], fill=(200, 0, 0))
            d.line([(px, py - 4), (px, py + 4)], fill=(200, 0, 0))
        y += ph + 4
    os.makedirs(MOCK, exist_ok=True)
    out = os.path.join(MOCK, "%s_contact.png" % mid)
    img.save(out)
    return out


def clip(out_path):
    """All three monsters, each action S then E side by side, plus mirrored W/N, on grey."""
    fps = 17.144
    W, H = 1280, 720
    tmp = tempfile.mkdtemp(prefix="gclip_")
    n = 0
    from PIL import ImageFont  # noqa: F401
    for mid in ("granary_rat", "scarecrow_drudge", "the_ratking"):
        meta = json.load(open(os.path.join(MON, mid, "meta.json")))
        cw, ch = meta["cell"]
        sc = 0.75 if cw == 512 else 0.6
        for act in ORDER:
            if act not in meta["actions"]:
                continue
            fs = {f: [Image.open(p).convert("RGBA") for p in frames(mid, act, f)] for f in ("S", "E")}
            nf = len(fs["S"])
            reps = 3 if meta["actions"][act]["loop"] else 2
            seq = list(range(nf)) * reps
            if not meta["actions"][act]["loop"]:
                seq = (list(range(nf)) + [nf - 1] * 8) * reps
            for i in seq:
                img = Image.new("RGB", (W, H), (172, 172, 172))
                d = ImageDraw.Draw(img)
                d.text((20, 16), "%s - %s" % (meta["name"], act), fill=(0, 0, 0))
                tiles = [("S: front, down-right", fs["S"][i], False), ("E: back, up-right", fs["E"][i], False), ("S mirrored: front, down-left", fs["S"][i], True), ("E mirrored: back, up-left", fs["E"][i], True)]
                tw = W // 4
                for k, (lbl, im, mir) in enumerate(tiles):
                    if mir:
                        im = im.transpose(Image.FLIP_LEFT_RIGHT)
                    im2 = im.resize((int(cw * sc), int(ch * sc)), Image.LANCZOS)
                    x = k * tw + (tw - im2.width) // 2
                    yb = 560
                    piv_y = meta["pivot"][1] * sc
                    img.paste(im2, (x, int(yb - piv_y)), im2)
                    d.text((k * tw + tw // 2 - 70, 600), lbl, fill=(0, 0, 0))
                img.save(os.path.join(tmp, "f%05d.png" % n))
                n += 1
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i", os.path.join(tmp, "f%05d.png"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", out_path], check=True)
    for p in glob.glob(os.path.join(tmp, "*.png")):
        os.remove(p)
    os.rmdir(tmp)
    return out_path, n


if __name__ == "__main__":
    for mid in sorted(os.listdir(MON)):
        if os.path.exists(os.path.join(MON, mid, "meta.json")):
            print(sheet(mid))
    if "--clip" in sys.argv:
        print(clip(sys.argv[sys.argv.index("--clip") + 1]))
