"""Drowned Abbey effect pieces: the Mire Leech's bile spit and its splash, the Mire Abbess's
Rite of Rising beam (rite_glow), the star-5 gravebound bile and the star-5 grasping mire hazard.

Outputs under art/pc/dungeons/drowned_abbey/:
  board/projectiles/bile_spit.png, bile_impact.png, rite_glow.png (+ _glow) (+ _2x)
  star5/board/projectiles/gravebound_bile.png (+ _glow, + _2x)
  star5/board/grasping_mire.png (64x32), _2x/ (128x64), grasping_mire_glow.png (96x56 add)
The cutting code is shared (fx_kit.py).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import fx_kit  # noqa: E402

META = {"decals": [], "glows": [], "projectiles": []}
SRC_REL = "build_tools/dungeons/abbey_src/bile_projectiles.jpg"
BILE = (0.7, 1.0, 0.2)
RITE = (0.5, 1.0, 0.4)
JADE = (0.55, 1.0, 0.75)


def grasping_mire():
    def bright(rgb):
        lum = rgb.mean(-1)
        return np.clip((lum - 0.25) / 0.25, 0, 1) * np.clip((rgb[..., 1] - rgb[..., 0] - 0.12) / 0.2, 0, 1)
    fx_kit.cell_decal("grasping_mire.jpg", "star5/board/grasping_mire.png", grade={"mul": (0.85, 0.9, 0.9), "sat": 0.95},
                      glow_col=JADE, gain=(5, 2.2, 1.5, 0.6), bright_fn=bright)
    META["decals"].append({
        "id": "grasping_mire", "kind": "floor_decal", "star": 5, "blocks": False, "walkable": True,
        "file": "star5/board/grasping_mire.png", "file_2x": "star5/board/_2x/grasping_mire.png",
        "size": [64, 32], "size_2x": [128, 64], "footprint_size": [1, 1],
        "anchor": "image centre = cell centre (cell_to_local), same as a floor tile; draw on the ground layer over the floor tile",
        "note": ("'Grasping Mire': the Gravebound Abbess's star-5 hazard, black bog water with drowned skeletal hands and roots "
                 "reaching up (the rule is CombatSim's). Fade it in over ~0.3 s; pulse the glow"),
        "source": "build_tools/dungeons/abbey_src/grasping_mire.jpg",
    })
    META["glows"].append({
        "id": "grasping_mire_glow", "for": "grasping_mire", "blend": "add", "star": 5,
        "file": "star5/board/grasping_mire_glow.png", "file_2x": "star5/board/_2x/grasping_mire_glow.png",
        "size": [96, 56], "size_2x": [192, 112],
        "anchor": "image centre = cell centre + (0, -4) at 1x (draw at cell_to_local - (48, 32)); pulse modulate 0.6..1.0",
    })


def projectiles():
    fly = ("bile_spit: a glob of acid bile pointing along +x; rotate it to the flight direction and fly it from the release point "
           "to the target at ~380 px/s board scale on a lobbed arc (about 20 px of lift at mid-flight), no spin")
    specs = [
        {"id": "bile_spit", "quad": (0, 0), "box": (40, 150, 470, 370), "size": 40, "glow_col": BILE, "glow_fit": True, "note": fly},
        {"id": "bile_impact", "quad": (1, 0), "box": (560, 50, 990, 480), "size": 50, "kind": "impact_effect", "keep_main": False,
         "dust_fix": True, "dust_col": [0.95, 1.08, 0.8],
         "note": "one-shot acid splash: scale 0.6 -> 1.2 and fade alpha 1 -> 0 over ~0.3 s at the target's chest (about 40 px above the cell centre at board scale)"},
        {"id": "gravebound_bile", "quad": (0, 1), "box": (20, 640, 470, 870), "size": 42, "star": 5, "glow_col": JADE, "glow_fit": True,
         "keep_main": False, "dust_fix": True, "dust_col": [0.9, 1.08, 0.98],
         "note": "pale-jade soul bile of the star-5 Gravebound Mire Leech; fly it like bile_spit, with its glow (add) centred on it"},
        {"id": "rite_glow", "quad": (1, 1), "box": (520, 640, 1010, 880), "size": 96, "kind": "beam_effect", "glow_col": RITE, "glow_fit": True,
         "keep_main": False, "dust_fix": True, "dust_col": [0.9, 1.08, 0.9],
         "note": ("the Mire Abbess's 'Rite of Rising' streak: green ritual smoke and light along +x, bright end at +x. On summon f07 stretch it "
                  "from rite_point (the censer, dim -x end) to the corpse cell (bright +x end, where the Bog Dead rises): rotate to that direction, "
                  "scale x to the distance / width, fade out over f07-f10; draw it and its glow with an add blend")},
    ]
    META["projectiles"].extend(fx_kit.projectile_sheet("bile_projectiles.jpg", specs, SRC_REL))
    ramp_png("board/projectiles/rite_glow.png", (70, 235, 90), (225, 255, 200))


def ramp_png(rel, base, white):
    """Recolour a cut smoke streak onto a green-to-white ramp by its luminance (the painted smoke came out grey
    after the magenta un-mix), 1x and 2x (as Saltmaw's lure_line)."""
    from PIL import Image
    for two in (False, True):
        p = fx_kit.path(rel, two)
        im = np.asarray(Image.open(p).convert("RGBA")).copy()
        on = im[..., 3] > 0
        lum = im[..., :3].astype(np.float32).mean(-1) / 255.0
        w = np.clip((lum - 0.8) / 0.18, 0, 1)[..., None] ** 1.5
        col = (np.array(base, np.float32) * np.clip(lum * 1.1, 0.35, 1.0)[..., None]) * (1 - w) + np.array(white, np.float32) * w
        im[..., :3] = np.where(on[..., None], np.clip(col + 0.5, 0, 255).astype(np.uint8), 0)
        gkit.save_png(p, im)


def build():
    gkit.use("drowned_abbey")
    for v in META.values():
        v.clear()
    grasping_mire()
    projectiles()
    return META


if __name__ == "__main__":
    import json
    print(json.dumps({k: [(e["id"], e.get("size")) for e in v] for k, v in build().items()}))
