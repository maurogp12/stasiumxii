"""Heart of the Blight effect pieces.

Base:  spore_bolt, spore_impact (the Blight Horror's ranged attack), root_crack (the Root Wall beam),
       root_wall (1x1 blocking prop with rise / idle / wither strips, the Rotting Elder's signature).
Star 5 (the Crystal Colossus set, Mauro's pick B): crystal_shard, crystal_shard_impact (the Crystal Horror),
       crystal_wall (the Colossus's Root Wall, same strips), crystal_bloom (1-cell hazard pod with an 8-frame
       swell loop) and crystal_bloom_burst (8 frames over the pod cell and its 8 neighbours).

Outputs under art/pc/dungeons/heart_of_the_blight/ (every piece also has a _2x/ master):
  board/projectiles/spore_bolt, spore_impact, root_crack (+ _glow)
  board/props/root_wall.png (+ _glow), board/props/root_wall/{rise_f00..05, idle_f00, wither_f00..05}(+ _glow)
  star5/board/projectiles/crystal_shard, crystal_shard_impact (+ _glow)
  star5/board/props/crystal_wall.png (+ _glow) and star5/board/props/crystal_wall/... (as root_wall)
  star5/board/crystal_bloom.png (64x32) + crystal_bloom_glow.png (96x56), star5/board/crystal_bloom/swell_f00..07 (+ _glow)
  star5/board/crystal_bloom_burst/burst_f00..07.png (192x96, the 3x3 diamond) (+ _glow)
All keyed pieces are on flat green. Translucent violet haze over green keys out greyish (its alpha is over-estimated,
the Abbey's lesson with magenta), so violet_fix() puts every grey pixel of an effect back on a violet ramp.
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import fx_kit  # noqa: E402
import board_kit  # noqa: E402
from board_kit import addglow  # noqa: E402
from build_blight_board import violet_mask  # noqa: E402

META = {"decals": [], "glows": [], "projectiles": [], "walls": [], "anims": []}
VIOLET = (0.8, 0.38, 1.0)
CRYSTAL = (0.72, 0.42, 1.0)
SRC_REL = "build_tools/dungeons/blight_src/%s"
RISE, WITHER, SWELL, BURST = 6, 6, 8, 8


def load(rel):
    return np.asarray(Image.open(os.path.join(gkit.OUT, rel)).convert("RGBA")).copy()


def violet_fix(rel, ramp=((70, 20, 110), (190, 110, 255), (250, 225, 255)), two_too=True):
    """Recolour the grey (unsaturated) pixels of a cut effect onto a violet ramp by their luminance, 1x and 2x.
    The brown roots and bone of a piece are warm (red > green > blue) and are left alone."""
    for two in ((False, True) if two_too else (False,)):
        p = fx_kit.path(rel, two)
        im = np.asarray(Image.open(p).convert("RGBA")).copy()
        rgb = im[..., :3].astype(np.float32)
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        grey = (im[..., 3] > 0) & (np.abs(r - g) < 26) & (np.abs(b - g) < 30) & ~((r > g + 8) & (g > b + 4))
        greenish = (im[..., 3] > 0) & (g > np.maximum(r, b) + 4)
        sel = grey | greenish
        lum = rgb.mean(-1) / 255.0
        lo, mid, hi = (np.array(c, np.float32) for c in ramp)
        t = np.clip(lum * 1.3, 0, 1)[..., None]
        col = np.where(t < 0.6, lo + (mid - lo) * (t / 0.6), mid + (hi - mid) * ((t - 0.6) / 0.4))
        im[..., :3] = np.where(sel[..., None], np.clip(col + 0.5, 0, 255).astype(np.uint8), im[..., :3])
        gkit.save_png(p, im)


def projectiles():
    fly = ("spore_bolt: a glowing violet spore glob pointing along +x with a tail of spores; rotate it to the flight direction and fly it "
           "from the release point to the target at ~420 px/s board scale on a shallow arc (about 14 px of lift), no spin")
    specs = [
        {"id": "spore_bolt", "quad": (0, 0), "box": (30, 170, 480, 380), "size": 44, "glow_col": VIOLET, "glow_fit": True, "keep_main": False,
         "min_island": 30, "note": fly},
        {"id": "spore_impact", "quad": (1, 0), "box": (550, 60, 1000, 480), "size": 52, "kind": "impact_effect", "keep_main": False, "min_island": 30,
         "note": "one-shot spore burst: scale 0.6 -> 1.2 and fade alpha 1 -> 0 over ~0.3 s at the target's chest (about 40 px above the cell centre)"},
        {"id": "root_crack", "quad": (1, 1), "box": (520, 630, 1010, 880), "size": 96, "kind": "beam_effect", "glow_col": VIOLET, "glow_fit": True,
         "keep_main": False, "min_island": 30,
         "note": ("the Root Wall crack: a violet glowing crack along +x. On summon f07 draw one from staff_point's floor spot (the staff foot) to each "
                  "new wall cell: rotate to that direction, scale x to the distance / width, ground layer under units, fade out over f07-f12; its glow is "
                  "additive")},
    ]
    out = fx_kit.projectile_sheet("spore_projectiles.jpg", specs, SRC_REL % "spore_projectiles.jpg")
    violet_fix("board/projectiles/spore_impact.png")
    violet_fix("board/projectiles/spore_bolt.png")
    s5 = [
        {"id": "crystal_shard", "quad": (0, 0), "box": (10, 130, 500, 330), "size": 46, "star": 5, "glow_col": CRYSTAL, "glow_fit": True,
         "keep_main": False, "min_island": 30,
         "note": "the Crystal Horror's star-5 bolt: a violet crystal shard along +x; fly it like spore_bolt but straight (no arc), with its glow (add)"},
        {"id": "crystal_shard_impact", "quad": (1, 0), "box": (540, 20, 1000, 480), "size": 54, "star": 5, "kind": "impact_effect", "keep_main": False,
         "min_island": 30, "glow_col": CRYSTAL, "glow_fit": True,
         "note": "one-shot burst of crystal fragments: scale 0.6 -> 1.2 and fade over ~0.3 s at the target's chest"},
    ]
    out += fx_kit.projectile_sheet("crystal_projectiles.jpg", s5, SRC_REL % "crystal_projectiles.jpg")
    violet_fix("star5/board/projectiles/crystal_shard_impact.png")
    META["projectiles"].extend(out)


# --------------------------------------------------------------- walls (rise / idle / wither)

def cut_prop(src, box=None):
    """Keyed prop painting -> premultiplied float cut, cropped to content (box = optional source sub-rectangle)."""
    rgb = gkit.load_rgb(src)
    if box:
        x0, y0, x1, y1 = box
        rgb = rgb[y0:y1, x0:x1]
    prem = gkit.clean_alpha(gkit.key_green(rgb))
    crop, _ = gkit.crop_bbox(prem)
    return crop


def wall_frames(prem, target_w, k):
    """Rise / idle / wither frames on one canvas (bottom-centre = the cell's south tip), at scale k (1 or 2)."""
    s = target_w * k / float(prem.shape[1])
    w = int(round(prem.shape[1] * s / 2)) * 2
    h = int(round(prem.shape[0] * s))
    full = gkit.resize_prem(prem, w, h)
    W, H = w + 8 * k, h + 6 * k
    frames = {}

    def place(img, dy=0, sx=1.0, sy=1.0, clip_y=None, dark=1.0, shake=0):
        ww, hh = max(2, int(round(w * sx))), max(2, int(round(h * sy)))
        im = gkit.resize_prem(img, ww, hh)
        can = np.zeros((H, W, 4), np.float32)
        x0 = (W - ww) // 2 + shake
        y0 = H - hh + int(round(dy))
        ys0, ys1 = max(0, y0), min(H, y0 + hh)
        if ys1 > ys0:
            can[ys0:ys1, x0:x0 + ww] = im[ys0 - y0:ys1 - y0]
        if clip_y is not None:  # nothing below the ground line (the wall comes out of / sinks into the floor)
            can[int(clip_y):] = 0
        if dark != 1.0:
            can[..., :3] *= dark
        return can

    ground = H - 3 * k  # ground line, a little above the canvas bottom: the rubble base pokes just below it
    rise = [(0.18, 0.55, 3), (0.42, 0.75, -3), (0.68, 0.9, 2), (0.9, 1.04, -1), (1.04, 1.02, 1), (1.0, 1.0, 0)]
    for i, (sy, sx, sh) in enumerate(rise):
        frames["rise_f%02d" % i] = place(full, dy=0, sx=sx, sy=sy, clip_y=None if i >= 4 else ground + 3 * k, shake=sh * k)
    frames["idle_f00"] = place(full)
    wither = [(1.0, 1.0, 0.95), (0.94, 0.98, 0.88), (0.8, 0.95, 0.8), (0.6, 0.9, 0.72), (0.38, 0.82, 0.62), (0.15, 0.7, 0.5)]
    for i, (sy, sx, dk) in enumerate(wither):
        sink = (1 - sy) * h  # it sinks into the floor rather than shrinking
        frames["wither_f%02d" % i] = place(full, dy=sink, sx=sx, clip_y=ground + 3 * k if i else None, dark=dk)
    return frames, (W, H)


def walls():
    # (id, source, source box, prefix, glow colour, 1x width, glow gain, note); the crystal wall is all crystal, so its glow is kept low
    specs = [("root_wall", "root_wall.jpg", None, "", VIOLET, 50, 2.2,
              "the Rotting Elder's Root Wall: a barrier of thick thorny roots bursting out of the floor"),
             ("crystal_wall", "crystal_projectiles.jpg", (20, 420, 520, 1000), "star5/", CRYSTAL, 52, 0.7,
              "the Crystal Colossus's star-5 Root Wall: tall violet crystal spikes out of heaved floor stones")]
    for wid, src, box, pre, col, tw, gain, note in specs:
        prem = cut_prop(src, box)
        sizes = {}
        for k, sub in ((1, ""), (2, "_2x/")):
            frames, size = wall_frames(prem, tw, k)
            sizes[k] = list(size)
            for name, can in frames.items():
                im = gkit.binarize(can)
                al = can[..., 3]
                st = can[..., :3] / np.maximum(al, 1e-4)[..., None]
                m = violet_mask(st, al) * (im[..., 3] > 0)
                g = np.clip(cv2.GaussianBlur(m, (0, 0), 3 * k) * gain + m * 0.3 * min(gain, 1.0), 0, 1)
                d = os.path.join(gkit.OUT, pre + "board", "props", wid, sub.rstrip("/"))
                gkit.save_png(os.path.join(d, name + ".png"), im)
                gkit.save_png(os.path.join(d, name + "_glow.png"), addglow(g, col))
                if name == "idle_f00":  # the standing wall is also a plain prop image next to the other props
                    gkit.save_png(os.path.join(gkit.OUT, pre + "board", "props", sub, wid + ".png"), im)
                    gkit.save_png(os.path.join(gkit.OUT, pre + "board", "props", sub, wid + "_glow.png"), addglow(g, col))
        e = {"id": wid, "kind": "summoned_obstacle", "blocks": True, "walkable": False, "star": 5 if pre else None,
             "file": pre + "board/props/%s.png" % wid, "file_2x": pre + "board/props/_2x/%s.png" % wid,
             "glow": pre + "board/props/%s_glow.png" % wid, "glow_2x": pre + "board/props/_2x/%s_glow.png" % wid,
             "size": sizes[1], "size_2x": sizes[2], "footprint_size": [1, 1], "anchor_cell_from_nw": [0, 0],
             "anchor": "image bottom-centre = the cell's south tip + (0, -3) at 1x (draw at cell_to_local(cell) + (-w/2, 16 - h + 3)); every strip frame uses the same canvas",
             "y_sort": "by its cell (x+y), like a unit or prop",
             "rise": {"frames": RISE, "fps": 17.144, "loop": False,
                      "pattern": pre + "board/props/%s/rise_f{00..%02d}.png" % (wid, RISE - 1)},
             "idle": {"frames": 1, "loop": True, "pattern": pre + "board/props/%s/idle_f00.png" % wid,
                                 "note": "a still frame; pulse its _glow modulate 0.6..1.0 over ~1.6 s for life"},
                        "wither": {"frames": WITHER, "fps": 17.144, "loop": False,
                        "pattern": pre + "board/props/%s/wither_f{00..%02d}.png" % (wid, WITHER - 1)},
             "glow_note": "every strip frame has a same-canvas additive <frame>_glow.png (the violet veins / crystal light)",
             "note": note + ". Play rise when the wall appears (it blocks from f00), idle while it stands, wither when it goes (then remove the blocker)",
             "source": SRC_REL % src}
        META["walls"].append(e)


# --------------------------------------------------------------- star-5 hazard: crystal bloom

def crystal_bloom():
    def bright(rgb):
        return np.clip((np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1] - 0.15) / 0.3, 0, 1) * np.clip((rgb.max(-1) - 0.6) / 0.3, 0, 1)
    fx_kit.cell_decal("crystal_bloom.jpg", "star5/board/crystal_bloom.png", grade={"mul": (0.95, 0.92, 0.98), "sat": 1.0},
                      glow_col=CRYSTAL, gain=(5, 2.0, 1.5, 0.7), bright_fn=bright, inset=0.98)
    base = load("star5/board/crystal_bloom.png")
    base2 = load("star5/board/_2x/crystal_bloom.png")
    gbase = load("star5/board/crystal_bloom_glow.png")
    gbase2 = load("star5/board/_2x/crystal_bloom_glow.png")
    # Swell loop: the pod breathes (scale about the cell centre) and its light pulses; 8 frames.
    for i in range(SWELL):
        ph = np.sin(2 * np.pi * i / SWELL)
        sc = 1.0 + 0.06 * ph
        gain = 0.75 + 0.25 * (ph + 1)
        for im, gl, sub, k in ((base, gbase, "", 1), (base2, gbase2, "_2x", 2)):
            H, W = im.shape[:2]
            M = cv2.getRotationMatrix2D((W / 2, H / 2), 0, sc)
            f = cv2.warpAffine(im, M, (W, H), flags=cv2.INTER_NEAREST, borderValue=(0, 0, 0, 0))
            gkit.save_png(os.path.join(gkit.OUT, "star5/board/crystal_bloom", sub, "swell_f%02d.png" % i), f)
            gH, gW = gl.shape[:2]
            M2 = cv2.getRotationMatrix2D((gW / 2, gH / 2 + 4 * k), 0, sc)
            g = cv2.warpAffine(gl, M2, (gW, gH), flags=cv2.INTER_LINEAR, borderValue=(0, 0, 0, 0)).astype(np.float32)
            g[..., :3] = np.clip(g[..., :3] * gain, 0, 255)
            on = g[..., :3].max(-1) >= 3
            g[..., 3] = np.where(on, 255, 0)
            g[..., :3] *= on[..., None]
            gkit.save_png(os.path.join(gkit.OUT, "star5/board/crystal_bloom", sub, "swell_f%02d_glow.png" % i), g.astype(np.uint8))
    META["decals"].append({
        "id": "crystal_bloom", "kind": "floor_decal", "star": 5, "blocks": False, "walkable": True,
        "file": "star5/board/crystal_bloom.png", "file_2x": "star5/board/_2x/crystal_bloom.png",
        "size": [64, 32], "size_2x": [128, 64], "footprint_size": [1, 1],
        "anchor": "image centre = cell centre (cell_to_local), same as a floor tile; ground layer over the floor tile",
        "swell": {"frames": SWELL, "fps": 10, "loop": True, "pattern": "star5/board/crystal_bloom/swell_f{00..07}.png",
                  "glow_pattern": "star5/board/crystal_bloom/swell_f{00..07}_glow.png",
                  "note": "the pod breathes while it waits to burst; same 64x32 canvas as crystal_bloom.png, glow frames on the 96x56 glow canvas"},
        "note": ("'Crystal Bloom', the Crystal Colossus's star-5 hazard (the rule is CombatSim's): a crystal pod in a nest of roots. "
                 "Fade it in over ~0.3 s, loop swell, then play crystal_bloom_burst on its cell"),
        "source": SRC_REL % "crystal_bloom.jpg",
    })
    META["glows"].append({
        "id": "crystal_bloom_glow", "for": "crystal_bloom", "blend": "add", "star": 5,
        "file": "star5/board/crystal_bloom_glow.png", "file_2x": "star5/board/_2x/crystal_bloom_glow.png",
        "size": [96, 56], "size_2x": [192, 112],
        "anchor": "image centre = cell centre + (0, -4) at 1x (draw at cell_to_local - (48, 32)); with the swell loop use the matching swell_fNN_glow",
    })


def bloom_burst():
    """8-frame area burst over the 3x3 cells around the pod: the top-down burst painting projected onto the 3x3 diamond,
    growing from the centre (f00-f03), full on f03, then shattering apart (f04-f07, an eroding dither)."""
    rgb = gkit.load_rgb("crystal_bloom_burst.jpg")
    prem = gkit.clean_alpha(gkit.key_green(rgb), min_island=30)
    # the burst is all violet crystal: no pixel should keep any green (spill flecks between the shards)
    a = np.maximum(prem[..., 3:4], 1e-4)
    st = prem[..., :3] / a
    st[..., 1] = np.minimum(st[..., 1], np.minimum(st[..., 0], st[..., 2]) * 0.85)
    prem[..., :3] = st * a
    prem = cv2.resize(prem, (768, 768), interpolation=cv2.INTER_AREA)
    bright = np.clip((prem[..., :3].max(-1) / np.maximum(prem[..., 3], 1e-4) - 0.7) / 0.3, 0, 1) * prem[..., 3]
    rng = np.random.RandomState(7)
    scales = [0.35, 0.6, 0.85, 1.0, 1.06, 1.1, 1.13, 1.15]
    keep = [1, 1, 1, 1, 0.8, 0.55, 0.3, 0.12]
    for k, sub in ((1, ""), (2, "_2x")):
        W, H = 192 * k, 96 * k
        noise = cv2.resize(rng.rand(H // k + 1, W // k + 1).astype(np.float32), (W, H), interpolation=cv2.INTER_NEAREST)
        for i in range(BURST):
            ss = 3
            ys, xs = np.mgrid[0:H * ss, 0:W * ss].astype(np.float32) + 0.5
            px = (xs - W * ss / 2) / (W * ss / 2) / scales[i]
            py = (ys - H * ss / 2) / (H * ss / 2) / scales[i]
            s = (px + py) / 2.0 + 0.5
            t = (py - px) / 2.0 + 0.5
            mx = (s * 767).astype(np.float32)
            my = (t * 767).astype(np.float32)
            big = cv2.remap(prem, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
            small = cv2.resize(big, (W, H), interpolation=cv2.INTER_AREA)
            small[noise > keep[i]] = 0
            im = gkit.binarize(small)
            gb = cv2.resize(cv2.remap(bright.astype(np.float32), mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0), (W, H),
                            interpolation=cv2.INTER_AREA) * (im[..., 3] > 0)
            flash = [0.6, 1.0, 1.0, 0.9, 0.7, 0.5, 0.3, 0.15][i]
            g = np.clip(cv2.GaussianBlur(gb, (0, 0), 4 * k) * 2.0 * flash + cv2.GaussianBlur((im[..., 3] > 0).astype(np.float32), (0, 0), 10 * k) * 0.5 * flash, 0, 1)
            d = os.path.join(gkit.OUT, "star5/board/crystal_bloom_burst", sub)
            gkit.save_png(os.path.join(d, "burst_f%02d.png" % i), im)
            gkit.save_png(os.path.join(d, "burst_f%02d_glow.png" % i), addglow(g, CRYSTAL))
    META["anims"].append({
        "id": "crystal_bloom_burst", "kind": "area_effect", "star": 5, "frames": BURST, "fps": 17.144, "loop": False,
        "pattern": "star5/board/crystal_bloom_burst/burst_f{00..07}.png", "glow_pattern": "star5/board/crystal_bloom_burst/burst_f{00..07}_glow.png",
        "pattern_2x": "star5/board/crystal_bloom_burst/_2x/burst_f{00..07}.png",
        "size": [192, 96], "size_2x": [384, 192], "footprint_size": [3, 3],
        "anchor": "image centre = the pod cell's centre (cell_to_local(pod)); the canvas is the 3x3 diamond around it (the pod cell and its 8 neighbours)",
        "layer": "over units (it is an explosion), additive glow on top",
        "note": "grows out of the pod f00-f03 (full on f03: the damage frame), then shatters apart f04-f07; remove the crystal_bloom decal on f00",
        "source": SRC_REL % "crystal_bloom_burst.jpg",
    })


def build():
    gkit.use("heart_of_the_blight")
    for v in META.values():
        v.clear()
    projectiles()
    walls()
    crystal_bloom()
    bloom_burst()
    return META


if __name__ == "__main__":
    import json
    print(json.dumps({k: [(e["id"], e.get("size")) for e in v] for k, v in build().items()}))
