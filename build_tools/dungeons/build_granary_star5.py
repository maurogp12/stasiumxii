"""Star-5 (radioactive) extras for the Old Granary Cellar: the toxic pool floor decal
(left behind by the Radioactive Ratking) and the Sling Rat projectiles.

Outputs under art/pc/dungeons/old_granary_cellar/:
  star5/board/toxic_pool.png (64x32), _2x/ (128x64), toxic_pool_glow.png (96x56 add)
  board/projectiles/sling_pebble.png, sling_seed.png, sling_impact_puff.png (+ _2x)
  star5/board/projectiles/sling_pebble_radioactive.png (+ _glow, + _2x)
The cutting code is shared (fx_kit.py).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import fx_kit  # noqa: E402

META = {"decals": [], "glows": [], "projectiles": []}
SRC_REL = "build_tools/dungeons/granary_src/sling_projectiles.jpg"


def toxic_pool():
    fx_kit.cell_decal("toxic_pool.jpg", "star5/board/toxic_pool.png", grade={"mul": (0.86, 0.86, 0.8), "sat": 0.82})
    META["decals"].append({
        "id": "toxic_pool", "kind": "floor_decal", "star": 5, "blocks": False, "walkable": True,
        "file": "star5/board/toxic_pool.png", "file_2x": "star5/board/_2x/toxic_pool.png",
        "size": [64, 32], "size_2x": [128, 64], "footprint_size": [1, 1],
        "anchor": "image centre = cell centre (cell_to_local), same as a floor tile; draw on the ground layer over the floor tile",
        "note": "left behind by the Radioactive Ratking (his star-5 special); fade it in over ~0.3 s and out when it expires",
        "source": "build_tools/dungeons/granary_src/toxic_pool.jpg",
    })
    META["glows"].append({
        "id": "toxic_pool_glow", "for": "toxic_pool", "blend": "add", "star": 5,
        "file": "star5/board/toxic_pool_glow.png", "file_2x": "star5/board/_2x/toxic_pool_glow.png",
        "size": [96, 56], "size_2x": [192, 112],
        "anchor": "image centre = cell centre + (0, -4) at 1x (draw at cell_to_local - (48, 32)); pulse modulate 0.6..1.0",
    })


def projectiles():
    sling = "sling stone; fly it on a shallow arc (peak ~24 px) from the release point to the target, spin it ~720 deg/s; sling_seed is an alternative (grain-hard seed) ammo"
    specs = [
        {"id": "sling_pebble", "quad": (0, 0), "size": 12, "note": sling},
        {"id": "sling_seed", "quad": (1, 0), "size": 11, "note": sling},
        {"id": "sling_impact_puff", "quad": (0, 1), "size": 44, "kind": "impact_effect", "keep_main": False, "dust_fix": True,
         "note": "one-shot puff: scale 0.6 -> 1.2 and fade alpha 1 -> 0 over ~0.25 s at the target's chest (about 40 px above the cell centre at board scale)"},
        {"id": "sling_pebble_radioactive", "quad": (1, 1), "size": 13, "star": 5, "glow_col": (0.5, 1.0, 0.15),
         "note": "radioactive pebble for the star-5 Radioactive Sling Rat; draw its glow (add) centred on it; may leave a toxic_pool on impact"},
    ]
    META["projectiles"].extend(fx_kit.projectile_sheet("sling_projectiles.jpg", specs, SRC_REL))


def build():
    gkit.use("old_granary_cellar")
    for v in META.values():
        v.clear()
    toxic_pool()
    projectiles()
    return META


if __name__ == "__main__":
    import json
    print(json.dumps({k: [e["id"] for e in v] for k, v in build().items()}))
