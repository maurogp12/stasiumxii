#!/usr/bin/env python3
"""Rebuild the combat character strips so each fighter is one body in every state.

Why: the shipped strips had holes from background keying (the floor showed
through Kestrel and Gloam), mixed costumes (Ironjaw attack/death was an old
hammer dwarf, Kestrel/Gloam attack, cast and death an older skinny look),
height pulsing inside one walk cycle, and a Mender south sheet with white
boxes. Looks follow GDD Blueprint §6 (Mauro, 27 Sep):

  kestrel  shipped walk (hooded archer). Gaps backed with dark, as §6 shows it.
  gloam    shipped walk (purple hood, gold trim, yellow grin). Same backing.
  ironjaw  §6 "SIDE walk": red plate, grill helm, dual axes. Cut from the
           blueprint by extract_blueprint_refs.py into refs/ironjaw_walk_e.png.
           South is the east mirror (down-left). North is east, back-lit.
  mender   shipped walk; south from the v4 sheet (the shipped one was a box).
  bastion  NOT touched (Mauro, 29 Sep): keep its shipped art.

West is always the per-cell mirror of east (the sprite tests require it).
Output keeps every file name and size, so SpriteFrames .tres slices and the
StripLibrary contract keep working:
  art/export_2x/characters/<c>/anims/<c>_walk_<d>.png  (864x160, 6 cells)
  art/export_2x/walk_src/<c>_walk_<d>.pngbin            (same bytes)
  art/export_2x/characters/<c>/anims/<c>_{hit,attack,cast,cast_mark,death}_<d>.png
      only where that file already exists; width kept, cells 144x160
  art/characters/<c>/<c>_<d>.png                        (walk frame 0)
Derived actions come from the walk cells (lean, lunge, recoil, flash, glow,
fall). Impact frame is index 3. Presentation only: no kit data.

Run from the repo root:  python3 build_tools/art/rebuild_character_strips.py
Needs: git, pillow, numpy, scipy.
"""
import io
import math
import os
import subprocess

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

SHIPPED = "8fe3424"  # mobile 0.1.34 tip: the art on phones today
V4 = "e0b3eb3"       # v4 walk strips (#163)
REF = "build_tools/art/refs/%s_walk_e.png"
DARK_BACK = (22, 18, 16)
# face -> ("git", rev) | ("ref",) | ("mirror_e",) | ("backlit_e",)
SOURCES = {
    "kestrel": {"e": ("git", SHIPPED), "s": ("git", SHIPPED), "n": ("git", SHIPPED)},
    "gloam": {"e": ("git", SHIPPED), "s": ("git", SHIPPED), "n": ("git", SHIPPED)},
    "ironjaw": {"e": ("ref",), "s": ("mirror_e",), "n": ("backlit_e",)},
    "mender": {"e": ("git", SHIPPED), "s": ("git", V4), "n": ("git", SHIPPED)},
}
# Keyed gaps in these looks are backed with dark (how §6 shows them on black).
BACKFILL = {"kestrel", "gloam"}
# Bastion is excluded on purpose (Mauro, 2026-09-29): keep its shipped art.
CLASSES = ["kestrel", "gloam", "ironjaw", "mender"]
CELL_W, CELL_H = 144, 160
FOOT_Y = 150
ANIMS = "art/export_2x/characters/%s/anims/%s_%s_%s.png"
# Screen x of "forward" per facing letter (E=SE, S=SW, N=NE, W=NW).
FORWARD_X = {"e": 1, "s": -1, "n": 1, "w": -1}
CAST_GLOW = {
    "kestrel": (150, 255, 200),
    "gloam": (190, 120, 255),
    "mender": (140, 255, 170),
    "ironjaw": (255, 150, 90),
}


def git_png(path, rev):
    data = subprocess.run(["git", "show", "%s:%s" % (rev, path)], capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(data)).convert("RGBA")


def cells(strip):
    return [strip.crop((i * CELL_W, 0, (i + 1) * CELL_W, CELL_H)) for i in range(strip.width // CELL_W)]


def join(frames):
    out = Image.new("RGBA", (CELL_W * len(frames), CELL_H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * CELL_W, 0))
    return out


def clean(cell):
    """Fill keyed-out holes inside the body and drop floating specks."""
    a = np.array(cell).astype(np.float32)
    alpha = a[:, :, 3]
    lab, n = ndi.label(alpha >= 40, structure=np.ones((3, 3)))
    if n > 1:
        sizes = ndi.sum(np.ones_like(alpha), lab, range(1, n + 1))
        for idx, size in enumerate(sizes, start=1):
            if size < 30:
                alpha[lab == idx] = 0
    body = ndi.binary_fill_holes(alpha >= 128)
    interior = ndi.binary_erosion(body, iterations=1)
    need = interior & (alpha < 200)
    if need.any():
        known = alpha >= 200
        rgb = a[:, :, :3].copy()
        # Diffuse known colors into the gaps (cheap inpaint).
        acc = np.where(known[..., None], rgb, 0.0)
        wgt = known.astype(np.float32)
        for _ in range(12):
            if (wgt[need] > 0).all():
                break
            acc_b = ndi.uniform_filter(acc, size=(3, 3, 1))
            wgt_b = ndi.uniform_filter(wgt, size=3)
            fill = need & (wgt == 0) & (wgt_b > 0)
            acc[fill] = acc_b[fill]
            wgt[fill] = wgt_b[fill]
        col = acc / np.maximum(wgt[..., None], 1e-4)
        # Keyed holes were shadow and visor slits: sit them darker.
        dark = np.where((alpha[need] < 40)[:, None], 0.55, 0.85)
        rgb[need] = col[need] * dark
        a[:, :, :3] = rgb
        alpha[need] = 255
    a[:, :, 3] = alpha
    a[alpha < 8] = 0
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def backfill(cell, radius=4):
    """Close the keyed silhouette and sit it on dark, so a gap reads as shadow
    instead of showing the floor through the body."""
    a = np.array(cell)
    alpha = a[:, :, 3]
    solid = alpha >= 90
    if not solid.any():
        return cell
    yy, xx = np.mgrid[-radius:radius + 1, -radius:radius + 1]
    disk = (xx * xx + yy * yy) <= radius * radius
    pad = radius + 1
    closed = ndi.binary_closing(np.pad(solid, pad), structure=disk)[pad:-pad, pad:-pad]
    body = ndi.binary_fill_holes(closed | solid)
    back_a = np.array(Image.fromarray((body * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)))
    back = Image.fromarray(np.dstack([np.full(alpha.shape + (3,), DARK_BACK, np.uint8), back_a]), "RGBA")
    back.alpha_composite(cell)
    return back


def anchor(frames):
    """Feet on FOOT_Y for every cell; strip centered on frame 0's body."""
    out = []
    a0 = np.array(frames[0])[:, :, 3]
    cols = np.where((a0 >= 128).sum(0) > 0)[0]
    dx = CELL_W // 2 - int((cols[0] + cols[-1]) / 2) if len(cols) else 0
    for f in frames:
        a = np.array(f)[:, :, 3]
        rows = np.where((a >= 128).sum(1) >= 3)[0]
        dy = FOOT_Y - int(rows[-1]) if len(rows) else 0
        c = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
        c.paste(f, (dx, dy), f)
        out.append(c)
    return out


def even_height(frames, tol=4):
    """Scale each cell about the foot so the head sits on the strip's median
    row. Some cells were drawn ~10% taller, which read as the body pulsing."""
    tops = []
    for f in frames:
        rows = np.where((np.array(f)[:, :, 3] > 20).sum(1) > 0)[0]
        tops.append(int(rows[0]) if len(rows) else FOOT_Y)
    target = int(np.median(tops))
    out = []
    for f, top in zip(frames, tops):
        if abs(top - target) <= tol:
            out.append(f)
            continue
        k = (FOOT_Y - target) / float(FOOT_Y - top)
        out.append(xform(f, sx=k, sy=k))
    return out


def mirror(frames):
    return [f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames]


def xform(cell, angle=0.0, dx=0, dy=0, sx=1.0, sy=1.0):
    """Rotate/scale about the foot, then shift. Positive angle leans forward on screen right."""
    img = cell
    if sx != 1.0 or sy != 1.0:
        w, h = int(round(CELL_W * sx)), int(round(CELL_H * sy))
        scaled = cell.resize((w, h), Image.BICUBIC)
        img = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
        img.paste(scaled, (CELL_W // 2 - int(CELL_W // 2 * sx), FOOT_Y - int(FOOT_Y * sy)), scaled)
    # Work on a padded canvas so a lean or a fall is not clipped by the cell.
    pad = CELL_W
    big = Image.new("RGBA", (CELL_W + 2 * pad, CELL_H + 2 * pad), (0, 0, 0, 0))
    big.paste(img, (pad, pad), img)
    if angle:
        big = big.rotate(-angle, resample=Image.BICUBIC, center=(pad + CELL_W // 2, pad + FOOT_Y))
    x0, y0 = pad - int(dx), pad - int(dy)
    return big.crop((x0, y0, x0 + CELL_W, y0 + CELL_H))


def tint(cell, mul=(1, 1, 1), add=(0, 0, 0), toward=None, amount=0.0):
    a = np.array(cell).astype(np.float32)
    rgb = a[:, :, :3] * np.array(mul) + np.array(add)
    if toward is not None:
        rgb = rgb * (1 - amount) + np.array(toward) * amount
    a[:, :, :3] = rgb
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def fade(cell, k):
    a = np.array(cell)
    a[:, :, 3] = (a[:, :, 3].astype(np.float32) * k).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def glow(cell, color, strength):
    if strength <= 0:
        return cell
    alpha = cell.split()[3].filter(ImageFilter.GaussianBlur(5))
    halo = Image.new("RGBA", cell.size, color + (0,))
    halo.putalpha(alpha.point(lambda v: int(min(255, v * strength))))
    base = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    base.alpha_composite(halo)
    base.alpha_composite(tint(cell, toward=color, amount=0.18 * strength))
    return base


def desat(cell, k):
    a = np.array(cell).astype(np.float32)
    lum = (a[:, :, :3] @ np.array([0.299, 0.587, 0.114]))[..., None]
    a[:, :, :3] = a[:, :, :3] * (1 - k) + lum * k
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def build_hit(walk, face, n):
    back = -FORWARD_X[face]
    base = walk[0]
    seq = [
        tint(base, toward=(255, 255, 255), amount=0.7),
        xform(tint(base, mul=(1.0, 0.78, 0.78)), angle=-6 * FORWARD_X[face], dx=5 * back),
        xform(base, angle=-3 * FORWARD_X[face], dx=2 * back),
        base,
    ]
    return (seq + [base] * n)[:n]


def build_attack(walk, face, n):
    f = FORWARD_X[face]
    steps = [
        (walk[0], -5, -2, 0),
        (walk[1], -9, -4, 0),
        (walk[2], -4, -1, 0),
        (walk[3], 9, 10, 0),   # impact, index 3
        (walk[4], 5, 6, 0),
        (walk[0], 1, 2, 0),
    ]
    if n == 5:
        steps = steps[:4] + [steps[5]]
    return [xform(c, angle=ang * f, dx=dx * f, dy=dy) for c, ang, dx, dy in steps[:n]]


def build_cast(walk, face, cls, n):
    color = CAST_GLOW[cls]
    ramp = [0.25, 0.6, 1.0, 1.0, 0.7, 0.35] if n != 4 else [0.35, 0.8, 1.0, 0.5]
    rise = [0, -1, -2, -3, -2, -1]
    return [glow(xform(walk[0], dy=rise[i % 6]), color, ramp[i % len(ramp)]) for i in range(n)]


def build_death(walk, face, n):
    """Topple backward about the foot. The body slides forward as it falls so
    the resting pose stays centered in the cell."""
    f = FORWARD_X[face]
    angles = [0, -10, -26, -48, -66, -72]
    out = []
    for i in range(n):
        slide = 0.42 * 120 * math.sin(math.radians(-angles[i]))
        sc = [1, 0.98, 0.95, 0.9, 0.86, 0.84][i]
        c = xform(walk[0], angle=angles[i] * f, dx=slide * f, dy=[0, 0, 1, 2, 3, 3][i], sx=sc, sy=sc)
        c = desat(c, i / (n - 1) * 0.55)
        out.append(fade(c, [1, 1, 0.97, 0.94, 0.9, 0.86][i]))
    return out


def save(img, path, also=None):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    data = buf.getvalue()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(data)
    if also:
        with open(also, "wb") as fh:
            fh.write(data)


def load_walks(cls):
    walks = {}
    spec = SOURCES[cls]
    for face in ["e", "s", "n"]:
        kind = spec[face][0]
        if kind == "git":
            src = git_png(ANIMS % (cls, cls, "walk", face), spec[face][1])
        elif kind == "ref":
            src = Image.open(REF % cls).convert("RGBA")
        else:
            continue
        frames = [clean(c) for c in cells(src)]
        if cls in BACKFILL:
            frames = [backfill(c) for c in frames]
        walks[face] = even_height(anchor(frames))
    for face in ["s", "n"]:
        kind = spec[face][0]
        if kind == "mirror_e":
            # East faces screen down-right; its mirror faces down-left (south).
            walks[face] = mirror(walks["e"])
        elif kind == "backlit_e":
            # No back sheet exists: the side walk, a touch darker, reads as walking away.
            walks[face] = [tint(c, mul=(0.8, 0.78, 0.78)) for c in walks["e"]]
    walks["w"] = mirror(walks["e"])
    return walks


def main():
    for cls in CLASSES:
        walks = load_walks(cls)
        for face, frames in walks.items():
            save(join(frames), ANIMS % (cls, cls, "walk", face), "art/export_2x/walk_src/%s_walk_%s.pngbin" % (cls, face))
            save(frames[0], "art/characters/%s/%s_%s.png" % (cls, cls, face))
        for kind in ["hit", "attack", "cast", "cast_mark", "death"]:
            for face in ["e", "s", "n", "w"]:
                path = ANIMS % (cls, cls, kind, face)
                if not os.path.exists(path):
                    continue
                n = Image.open(path).width // CELL_W
                w = walks[face]
                if kind == "hit":
                    frames = build_hit(w, face, n)
                elif kind == "attack":
                    frames = build_attack(w, face, n)
                elif kind in ("cast", "cast_mark"):
                    frames = build_cast(w, face, cls, n)
                else:
                    frames = build_death(w, face, n)
                save(join(frames), path)
        print("rebuilt", cls)


if __name__ == "__main__":
    main()
