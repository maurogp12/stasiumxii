"""Old Granary Cellar combat-board kit: floor tiles, wheat pad, props, decals, backdrops.

The cutting code is shared (board_kit.py); this file is the Granary's piece
list. See board_kit.py for the board math and the rules.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import board_kit  # noqa: E402

META = {"tiles": [], "props": [], "decals": [], "glows": [], "backdrops": []}


def build():
    gkit.use("old_granary_cellar")
    b = board_kit.Board(key="green")
    for i in (1, 2, 3):
        b.tile("floor_a_%d.jpg" % i, "cellar_floor_%s" % "abc"[i - 1], "a")
        b.tile("floor_b_%d.jpg" % i, "lair_floor_%s" % "abc"[i - 1], "b")
    pr = b.tile("wheat_pad.jpg", "wheat_pad", "a", kind="glow_pad")
    b.pad_glow(pr, "wheat_pad_glow", "wheat_pad")
    g = {"mul": (0.92, 0.9, 0.86), "sat": 0.9}
    b.prop("crate_stack.jpg", "crate_stack", "a+b", 66, grade=g)
    b.prop("grain_sacks.jpg", "grain_sacks", "a+b", 70, grade=g)
    b.prop("barrel_cluster.jpg", "barrel_cluster", "a+b", 60, grade=g)
    b.prop("broken_crate.jpg", "broken_crate", "a+b", 68, grade=g)
    b.prop("bone_throne.jpg", "bone_throne", "b", 150, footprint=(2, 2), grade=g,
           notes="the Ratking's throne; 2x2 blocker, place against the back wall")
    b.decal("drain_grate.jpg", "drain_grate")
    for n in (15, 12):
        b.backdrop("shell_room_a.jpg", "room_a_cellar", "a", n, "cellar_floor")
        b.backdrop("shell_room_b.jpg", "room_b_lair", "b", n, "lair_floor")
    for k in META:
        META[k][:] = b.META[k]
    return META


if __name__ == "__main__":
    import json
    m = build()
    gkit.write_json(os.path.join(os.path.dirname(os.path.abspath(__file__)), "_board_meta.json"), m)
    print(json.dumps({k: [e["id"] for e in v] for k, v in m.items()}))
    for b in m["backdrops"]:
        print(b["id"], b["size"], b["cell00_centre_px"], b["fit_residual_px"])
