"""Frostspire Archive effect pieces: the Book Wraith's projectiles and the star-5 frost patch.

Outputs under art/pc/dungeons/frostspire_archive/:
  board/projectiles/frost_bolt.png (+ _glow), paper_bolt.png, frost_bolt_impact.png (+ _2x)
  star5/board/projectiles/frost_bolt_frozen.png (+ _glow, + _2x)
  star5/board/frost_patch.png (64x32), _2x/ (128x64), frost_patch_glow.png (96x56 add)
The cutting code is shared (fx_kit.py).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import fx_kit  # noqa: E402

META = {"decals": [], "glows": [], "projectiles": []}
SRC_REL = "build_tools/dungeons/frostspire_src/frost_projectiles.jpg"
ICE = (0.42, 0.74, 1.0)
CYAN = (0.3, 0.85, 1.0)


def frost_patch():
    def bright(rgb):
        lum = rgb.mean(-1)
        return np.clip((lum - 0.5) / 0.3, 0, 1) * np.clip((rgb[..., 2] - rgb[..., 0] - 0.1) / 0.25, 0, 1)
    fx_kit.cell_decal("frost_patch.jpg", "star5/board/frost_patch.png", grade={"mul": (0.9, 0.94, 1.0), "sat": 0.95},
                      glow_col=CYAN, gain=(5, 2.6, 1.5, 0.7), bright_fn=bright)
    META["decals"].append({
        "id": "frost_patch", "kind": "floor_decal", "star": 5, "blocks": False, "walkable": True,
        "file": "star5/board/frost_patch.png", "file_2x": "star5/board/_2x/frost_patch.png",
        "size": [64, 32], "size_2x": [128, 64], "footprint_size": [1, 1],
        "anchor": "image centre = cell centre (cell_to_local), same as a floor tile; draw on the ground layer over the floor tile",
        "note": "'Rime Patches': left by the Frozen Archivist (his star-5 special) on 2-3 cells around the hero; fade it in over ~0.3 s and out when it expires",
        "source": "build_tools/dungeons/frostspire_src/frost_patch.jpg",
    })
    META["glows"].append({
        "id": "frost_patch_glow", "for": "frost_patch", "blend": "add", "star": 5,
        "file": "star5/board/frost_patch_glow.png", "file_2x": "star5/board/_2x/frost_patch_glow.png",
        "size": [96, 56], "size_2x": [192, 112],
        "anchor": "image centre = cell centre + (0, -4) at 1x (draw at cell_to_local - (48, 32)); pulse modulate 0.6..1.0",
    })


def projectiles():
    fly = ("frost bolt: points along +x; rotate it to the flight direction and fly it straight (no arc) from the release point "
           "to the target at ~420 px/s board scale, with its glow (add) on top; paper_bolt is an alternative look (a frost-edged paper dart)")
    specs = [
        {"id": "frost_bolt", "quad": (0, 0), "size": 30, "glow_col": ICE, "glow_fit": True, "note": fly},
        {"id": "paper_bolt", "quad": (1, 0), "size": 26, "note": fly},
        {"id": "frost_bolt_impact", "quad": (0, 1), "size": 46, "kind": "impact_effect", "keep_main": False, "dust_fix": True,
         "dust_col": [0.92, 1.0, 1.12],
         "note": "one-shot burst: scale 0.6 -> 1.2 and fade alpha 1 -> 0 over ~0.25 s at the target's chest (about 40 px above the cell centre at board scale)"},
        {"id": "frost_bolt_frozen", "quad": (1, 1), "size": 32, "star": 5, "glow_col": CYAN, "glow_fit": True,
         "note": "black-ice bolt for the star-5 Frozen Book Wraith; fly it like frost_bolt, with its glow (add) centred on it"},
    ]
    META["projectiles"].extend(fx_kit.projectile_sheet("frost_projectiles.jpg", specs, SRC_REL))


def build():
    gkit.use("frostspire_archive")
    for v in META.values():
        v.clear()
    frost_patch()
    projectiles()
    return META


if __name__ == "__main__":
    import json
    print(json.dumps({k: [(e["id"], e.get("size")) for e in v] for k, v in build().items()}))
