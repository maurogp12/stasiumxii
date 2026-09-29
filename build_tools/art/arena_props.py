#!/usr/bin/env python3
"""Cut the scenery objects out of Mauro's look pictures (29 Sep).

Each arena's tags already place visual-only props (paint_only) by name:
driftwood, rock_cluster, conduit, crystal, hay, ... This script cuts the
matching object out of that arena's picture (crate, coral rock, obelisk,
ice crystal, market stall, ...) with background removal, trims it, scales it
to a board-sized sprite and saves it as art/maps/arena_look/<map>/prop_<name>.png.
The board draws that sprite instead of the older prop sheet. Tags, walk, MP
and LoS are untouched: a prop is still paint only.

Run from the repo root: python3 build_tools/art/arena_props.py
Needs: pillow, numpy, rembg (isnet-general-use model).
"""
import os

import numpy as np
from PIL import Image
from rembg import new_session, remove

REFS = "art/maps/arena_look/refs/"
MAX_H = 92
# Centrepieces may stand taller than a board prop.
TALL = {"tower"}
OUT = "art/maps/arena_look/"

# map -> prop name -> (picture box x0, y0, x1, y1, sprite width in board px[, model])
# The default model is isnet-general-use; u2net cuts some busy scenes better.
# Props with no clean cut (Brinewake coral, Crosshaven banner poles and flower
# pots, the Stormspire lightning tower) are left out and keep the older sprite.
CUTS = {
    "slagcrown": {
        "ref": "slagcrown_look.jpg",
        "basalt_pillar": (610, 1640, 745, 1935, 26),
        "rock_pillar": (520, 30, 665, 378, 30),
        "ash_rock": (870, 190, 1178, 380, 52),
        "floor_seal": (870, 190, 1178, 380, 40),
        # Mauro: one volcano, in the centre of the map. The three steam vents
        # are hidden; ArenaLook draws "volcano" as the centrepiece on (7,7).
        "steam_vent": ("none",),
        "volcano": (800, 760, 1330, 1250, 112),
        # Pale stone chunks read as litter on the basalt.
        "rubble": ("none",),
    },
    "brinewake": {
        "ref": "brinewake_look.jpg",
        "driftwood": (1135, 595, 1325, 755, 40),
        "ruins": (1890, 455, 2095, 660, 46),
        "rock_cluster": (1700, 455, 1885, 655, 42, "u2net"),
        "floor_seal": (940, 735, 1130, 840, 30),
        "fence": (2370, 480, 2555, 785, 36, "u2net"),
        "rubble": (1668, 124, 1800, 222, 26),
        # The old waterfall sprite read as a yellow stick on the dock.
        "waterfall": ("none",),
        "rock_pillar": ("none",),
    },
    "stormspire": {
        "ref": "stormspire_look.jpg",
        "conduit": (355, 195, 595, 515, 46, "isnet-general-use", 150),
        "rock_pillar": (1215, 105, 1410, 340, 36, "isnet-general-use", 150),
        "arc": (0, 25, 200, 400, 34),
        "spark": (965, 870, 1095, 1018, 22),
        # The old pink crystal spires clashed: use the picture's blue crystal.
        "crystal_bolt": ("alias", "spark"),
        # Centre tower from the second picture (Mauro, 29 Sep).
        "tower": ("ref2", "stormspire_look2.jpg", (800, 330, 1210, 1200, 56, "u2net")),
        # The picture's floor is clean slate: no grey rocks or plates.
        "rubble": ("none",),
        "floor_seal": ("none",),
    },
    "windmere": {
        "ref": "windmere_look.jpg",
        "crystal": ("alias", "spark"),
        "ice_shard": ("alias", "spark"),
        # Grates and grey rubble do not belong on the ice ring.
        "floor_seal": ("none",),
        "rubble": ("none",),
        "ice_sheet": ("none",),
        "spark": (760, 278, 874, 420, 34, "u2net"),
    },
    "crosshaven": {
        "ref": "crosshaven_look.jpg",
        "hay": (262, 150, 372, 236, 52, "u2net"),
        "rock_pillar": (522, 152, 641, 256, 52),
        "well": (381, 262, 522, 355, 60),
        "ruins": (46, 20, 212, 198, 78, "u2net"),
        # No mountains in a city plaza: the grassland rubble becomes the shipped bush.
        "rubble": ("copy", "art/maps/arena_colosseum_v2/tiled/tiles/prop_hay.png"),
    },
}


def cut(session, img, box, width, floor=70.0, max_h=MAX_H):
    x0, y0, x1, y1 = box
    crop = img.crop((x0, y0, x1, y1))
    rgba = remove(crop, session=session)
    a = np.array(rgba)
    # The model leaves soft, half-clear bodies on busy painted floors. A prop
    # is a solid object: push alpha to opaque inside, keep a 1-2 px soft edge.
    soft = a[..., 3].astype(np.float32)
    # floor: raise it for props whose cut keeps a grey haze at the base.
    a[..., 3] = np.clip((soft - floor) * 3.0, 0, 255).astype(np.uint8)
    rgba = Image.fromarray(a, "RGBA")
    alpha = a[..., 3]
    ys, xs = np.where(alpha > 24)
    if len(xs) == 0:
        return None
    rgba = rgba.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    h = max(1, int(round(rgba.height * width / float(rgba.width))))
    if h > max_h:
        # Tall, thin cuts (ice spires) would tower over the board: cap height.
        width = max(1, int(round(width * max_h / float(h))))
        h = max_h
    return rgba.resize((width, h), Image.LANCZOS)


def main():
    sessions = {}
    for name, spec in CUTS.items():
        img = Image.open(REFS + spec["ref"]).convert("RGB")
        out_dir = OUT + name
        os.makedirs(out_dir, exist_ok=True)
        for f in os.listdir(out_dir):
            if f.startswith("prop_") and f.endswith(".png"):
                os.remove(os.path.join(out_dir, f))
                if os.path.exists(os.path.join(out_dir, f + ".import")):
                    os.remove(os.path.join(out_dir, f + ".import"))
        aliases = []
        for prop, entry in [(k, v) for k, v in spec.items() if k != "ref"]:
            if entry[0] == "none":
                # Decoration only: a clear 1x1 sprite hides the older prop.
                Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(os.path.join(out_dir, "prop_%s.png" % prop))
                print(name, prop, "hidden")
                continue
            if entry[0] == "alias":
                aliases.append((prop, entry[1]))
                continue
            if entry[0] == "ref2":
                other = Image.open(REFS + entry[1]).convert("RGB")
                bx0, by0, bx1, by1, bw = entry[2][:5]
                bmodel = entry[2][5] if len(entry[2]) > 5 else "isnet-general-use"
                if bmodel not in sessions:
                    sessions[bmodel] = new_session(bmodel)
                sprite = cut(sessions[bmodel], other, (bx0, by0, bx1, by1), bw, 70.0, 150 if prop in TALL else MAX_H)
                if sprite is not None:
                    sprite.save(os.path.join(out_dir, "prop_%s.png" % prop), optimize=True)
                    print(name, prop, sprite.size, "from", entry[1])
                continue
            if entry[0] == "copy":
                Image.open(entry[1]).save(os.path.join(out_dir, "prop_%s.png" % prop), optimize=True)
                print(name, prop, "copied")
                continue
            x0, y0, x1, y1, width = entry[:5]
            model = entry[5] if len(entry) > 5 else "isnet-general-use"
            floor = float(entry[6]) if len(entry) > 6 else 70.0
            if model not in sessions:
                sessions[model] = new_session(model)
            sprite = cut(sessions[model], img, (x0, y0, x1, y1), width, floor)
            if sprite is None:
                print(name, prop, "EMPTY")
                continue
            sprite.save(os.path.join(out_dir, "prop_%s.png" % prop), optimize=True)
            print(name, prop, sprite.size)
        for prop, source in aliases:
            Image.open(os.path.join(out_dir, "prop_%s.png" % source)).save(os.path.join(out_dir, "prop_%s.png" % prop), optimize=True)
            print(name, prop, "=", source)


if __name__ == "__main__":
    main()
