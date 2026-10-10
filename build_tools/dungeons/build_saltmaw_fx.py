"""Saltmaw Grotto effect pieces: the Drowned Harpooner's harpoon, its impact splash,
Old Saltmaw's lure line, the star-5 abyssal harpoon and the star-5 riptide hazard.

Outputs under art/pc/dungeons/saltmaw_grotto/:
  board/projectiles/harpoon.png, harpoon_impact.png, lure_line.png (+ _glow) (+ _2x)
  star5/board/projectiles/abyssal_harpoon.png (+ _glow, + _2x)
  star5/board/riptide.png (64x32), _2x/ (128x64), riptide_glow.png (96x56 add)
The cutting code is shared (fx_kit.py).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import fx_kit  # noqa: E402

META = {"decals": [], "glows": [], "projectiles": []}
SRC_REL = "build_tools/dungeons/saltmaw_src/harpoon_projectiles.jpg"
TEAL = (0.25, 1.0, 0.8)
CYAN = (0.3, 0.9, 1.0)


def riptide():
    def bright(rgb):
        lum = rgb.mean(-1)
        return np.clip((lum - 0.45) / 0.3, 0, 1) * np.clip((rgb[..., 1] - rgb[..., 0] - 0.1) / 0.25, 0, 1)
    fx_kit.cell_decal("riptide.jpg", "star5/board/riptide.png", grade={"mul": (0.88, 0.95, 1.0), "sat": 0.95},
                      glow_col=CYAN, gain=(5, 2.2, 1.5, 0.6), bright_fn=bright)
    META["decals"].append({
        "id": "riptide", "kind": "floor_decal", "star": 5, "blocks": False, "walkable": True,
        "file": "star5/board/riptide.png", "file_2x": "star5/board/_2x/riptide.png",
        "size": [64, 32], "size_2x": [128, 64], "footprint_size": [1, 1],
        "anchor": "image centre = cell centre (cell_to_local), same as a floor tile; draw on the ground layer over the floor tile",
        "note": ("'Riptide': the Abyssal Saltmaw's star-5 hazard. Ending a turn on it deals damage and drags the hero 1 cell toward him "
                 "(the rule is CombatSim's). Fade it in over ~0.3 s; rotate its sprite slowly or pulse the glow to sell the swirl"),
        "source": "build_tools/dungeons/saltmaw_src/riptide.jpg",
    })
    META["glows"].append({
        "id": "riptide_glow", "for": "riptide", "blend": "add", "star": 5,
        "file": "star5/board/riptide_glow.png", "file_2x": "star5/board/_2x/riptide_glow.png",
        "size": [96, 56], "size_2x": [192, 112],
        "anchor": "image centre = cell centre + (0, -4) at 1x (draw at cell_to_local - (48, 32)); pulse modulate 0.6..1.0",
    })


def projectiles():
    fly = ("harpoon: points along +x; rotate it to the flight direction and fly it from the release point to the target "
           "at ~460 px/s board scale with a slight arc (about 12 px of lift at mid-flight), no spin")
    specs = [
        {"id": "harpoon", "quad": (0, 0), "box": (20, 170, 600, 390), "size": 44, "note": fly},
        {"id": "harpoon_impact", "quad": (1, 0), "box": (600, 80, 1010, 470), "size": 46, "kind": "impact_effect", "keep_main": False, "dust_fix": True,
         "dust_col": [0.9, 1.04, 1.06],
         "note": "one-shot splash: scale 0.6 -> 1.2 and fade alpha 1 -> 0 over ~0.25 s at the target's chest (about 40 px above the cell centre at board scale)"},
        {"id": "abyssal_harpoon", "quad": (0, 1), "box": (20, 630, 575, 860), "size": 46, "star": 5, "glow_col": CYAN, "glow_fit": True,
         "note": "black-iron rune harpoon of the star-5 Abyssal Drowned Harpooner; fly it like harpoon, with its glow (add) centred on it"},
        {"id": "lure_line", "quad": (1, 1), "box": (585, 660, 1010, 770), "size": 96, "kind": "beam_effect", "glow_col": TEAL, "glow_fit": True,
         "note": ("Old Saltmaw's 'Lantern Lure' streak: a teal light streak along +x, bright end at +x. On summon f07 stretch it from the hero "
                  "(dim -x end) to the lure_point (bright +x end): rotate to that direction, scale x to the distance / width, fade out over f07-f10; "
                  "draw it and its glow with an add blend")},
    ]
    META["projectiles"].extend(fx_kit.projectile_sheet("harpoon_projectiles.jpg", specs, SRC_REL))
    despill_png("board/projectiles/lure_line.png")


def despill_png(rel):
    """Recolour a cut light streak onto a teal-to-white ramp by its luminance (the painted streak came out
    blue-violet next to the magenta key), 1x and 2x."""
    from PIL import Image
    for two in (False, True):
        p = fx_kit.path(rel, two)
        im = np.asarray(Image.open(p).convert("RGBA")).copy()
        on = im[..., 3] > 0
        lum = im[..., :3].astype(np.float32).mean(-1) / 255.0
        teal = np.array([40, 230, 190], np.float32)
        white = np.array([225, 255, 245], np.float32)
        w = np.clip((lum - 0.8) / 0.18, 0, 1)[..., None] ** 1.5
        col = (teal * np.clip(lum, 0.35, 1.0)[..., None]) * (1 - w) + white * w
        im[..., :3] = np.where(on[..., None], np.clip(col + 0.5, 0, 255).astype(np.uint8), 0)
        gkit.save_png(p, im)


def build():
    gkit.use("saltmaw_grotto")
    for v in META.values():
        v.clear()
    riptide()
    projectiles()
    return META


if __name__ == "__main__":
    import json
    print(json.dumps({k: [(e["id"], e.get("size")) for e in v] for k, v in build().items()}))
