"""Contact sheets (one per monster, every frame of every action, S and E) and the review clip.

  python3 mock_monsters.py [--dungeon frostspire_archive] [--clip OUT.mp4] [--clip5 OUT5.mp4]
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

if "--dungeon" in sys.argv:
    gkit.use(sys.argv[sys.argv.index("--dungeon") + 1])
MON = os.path.join(gkit.OUT, "monsters")
MOCK = os.path.join(gkit.OUT, "_mock")
ORDER = ["idle", "walk", "attack", "hit", "death", "summon"]


def mdir(mid):
    for root in (MON, os.path.join(gkit.OUT, "star5", "monsters")):
        if os.path.exists(os.path.join(root, mid, "meta.json")):
            return os.path.join(root, mid)
    raise FileNotFoundError(mid)


def frames(mid, act, f):
    return sorted(p for p in glob.glob(os.path.join(mdir(mid), act, "%s_%s_f*.png" % (act, f))) if not p.endswith("_glow.png"))


def lit(path):
    """Frame as RGBA; for star-5 frames the additive glow is baked over it (review only)."""
    im = Image.open(path).convert("RGBA")
    g = path[:-4] + "_glow.png"
    if not os.path.exists(g):
        return im
    a = np.array(im).astype(np.int32)
    gl = np.array(Image.open(g).convert("RGB")).astype(np.int32)
    # premultiply the sprite over transparent, add glow, alpha = max(sprite, glow brightness)
    out = np.zeros_like(a)
    sa = a[..., 3:4] / 255.0
    rgb = a[..., :3] * sa + gl
    ga = np.clip(gl.max(-1, keepdims=True) / 255.0 * 1.6, 0, 1)
    al = np.maximum(sa, ga)
    out[..., :3] = np.clip(rgb / np.maximum(al, 1e-4), 0, 255)
    out[..., 3:] = (al * 255).astype(np.int32)
    return Image.fromarray(out.astype(np.uint8))


def sheet(mid, sc=0.5):
    meta = json.load(open(os.path.join(mdir(mid), "meta.json")))
    bgc = (48, 44, 40) if meta.get("star5") else (172, 172, 172)
    fg = (230, 230, 220) if meta.get("star5") else (0, 0, 0)
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
    img = Image.new("RGB", (W, H), bgc)
    d = ImageDraw.Draw(img)
    d.text((6, 6), "%s  cell %dx%d  pivot %s  %.3f fps  (shown at %.2fx)" % (meta["name"], cw, ch, meta["pivot"], meta["fps"], sc)
           + (("  release f%02d" % meta["release"]["frame"]) if meta.get("release") else "")
           + ("  (star 5: additive glow baked in for review)" if meta.get("star5") else ""), fill=fg)
    y = 30
    for act, f, fl in rows:
        d.text((6, y + ph // 2 - 6), "%s %s (%d)" % (act, f, len(fl)), fill=fg)
        for i, p in enumerate(fl):
            im = lit(p).resize((pw, ph), Image.LANCZOS)
            x = lab + i * pw
            img.paste(im, (x, y), im)
            px, py = x + meta["pivot"][0] * sc, y + meta["pivot"][1] * sc
            d.line([(px - 4, py), (px + 4, py)], fill=(200, 0, 0))
            d.line([(px, py - 4), (px, py + 4)], fill=(200, 0, 0))
        y += ph + 4
    os.makedirs(MOCK, exist_ok=True)
    out = os.path.join(MOCK, ("star5_" if meta.get("star5") else "") + "%s_contact.png" % mid)
    img.save(out)
    return out


def clip(out_path, mids=None, bg=(172, 172, 172)):
    """Each monster, each action: S, E and both mirrors side by side."""
    if mids is None:
        mids = sorted(m for m in os.listdir(MON) if os.path.exists(os.path.join(MON, m, "meta.json"))) if gkit.DUNGEON != "old_granary_cellar" \
            else ("granary_rat", "sling_rat", "scarecrow_drudge", "the_ratking")
    fps = 17.144
    W, H = 1280, 720
    tmp = tempfile.mkdtemp(prefix="gclip_")
    n = 0
    from PIL import ImageFont  # noqa: F401
    fg = (0, 0, 0) if sum(bg) > 300 else (230, 230, 220)
    for mid in mids:
        meta = json.load(open(os.path.join(mdir(mid), "meta.json")))
        cw, ch = meta["cell"]
        sc = 0.75 if cw == 512 else 0.6
        for act in ORDER:
            if act not in meta["actions"]:
                continue
            fs = {f: [lit(p) for p in frames(mid, act, f)] for f in ("S", "E")}
            nf = len(fs["S"])
            reps = 3 if meta["actions"][act]["loop"] else 2
            seq = list(range(nf)) * reps
            if not meta["actions"][act]["loop"]:
                seq = (list(range(nf)) + [nf - 1] * 8) * reps
            for i in seq:
                img = Image.new("RGB", (W, H), bg)
                d = ImageDraw.Draw(img)
                rel = "  (release f%02d)" % meta["release"]["frame"] if act == "attack" and meta.get("release") else ""
                d.text((20, 16), "%s - %s%s" % (meta["name"], act, rel), fill=fg)
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
                    d.text((k * tw + tw // 2 - 70, 600), lbl, fill=fg)
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
    roots = [MON, os.path.join(gkit.OUT, "star5", "monsters")]
    for root in roots:
        for mid in sorted(os.listdir(root)) if os.path.isdir(root) else []:
            if os.path.exists(os.path.join(root, mid, "meta.json")):
                print(sheet(mid))
    if "--clip" in sys.argv:
        print(clip(sys.argv[sys.argv.index("--clip") + 1]))
    if "--clip5" in sys.argv:
        s5 = os.path.join(gkit.OUT, "star5", "monsters")
        mids5 = ("radioactive_ratking", "radioactive_rat", "radioactive_sling_rat") if gkit.DUNGEON == "old_granary_cellar" \
            else sorted(m for m in os.listdir(s5) if os.path.exists(os.path.join(s5, m, "meta.json")))
        print(clip(sys.argv[sys.argv.index("--clip5") + 1], mids=mids5, bg=(48, 44, 40)))
