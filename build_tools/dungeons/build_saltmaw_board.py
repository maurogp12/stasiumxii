"""Saltmaw Grotto combat-board kit: floor tiles, coral pad, props, whirlpool, backdrops.

The cutting code is shared (board_kit.py); this file is the Saltmaw piece list.
Every keyed piece here is painted on flat MAGENTA (#FF00FF): the teal water, the
glowing coral and the green seaweed would be eaten by a green key.
Room A = the sea cave (pack fight), room B = Old Saltmaw's treasure lair (boss).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import board_kit  # noqa: E402

TEAL = (0.25, 1.0, 0.8)
META = {"tiles": [], "props": [], "decals": [], "glows": [], "backdrops": []}


def teal_bright(rgb):
    """Bright glowing teal paint of a top-down painting (rgb 0..1)."""
    lum = rgb.mean(-1)
    t = np.minimum(rgb[..., 1], rgb[..., 2]) - rgb[..., 0]
    return (np.clip((lum - 0.5) / 0.3, 0, 1) * np.clip((t - 0.15) / 0.25, 0, 1)).astype(np.float32)


def whirl_lines(rgb, alpha):
    """The whirlpool's glowing water and foam (not the stone kerb)."""
    lum = rgb.mean(-1)
    t = rgb[..., 1] - rgb[..., 0]
    return (np.clip((lum - 0.42) / 0.35, 0, 1) * np.clip((t - 0.08) / 0.2, 0, 1) * alpha).astype(np.float32)


def coral_glow(st, al):
    """The glowing teal coral fans on a prop (straight rgb 0..1)."""
    lum = st.mean(-1)
    t = np.minimum(st[..., 1], st[..., 2]) - st[..., 0]
    return (np.clip((lum - 0.55) / 0.25, 0, 1) * np.clip((t - 0.25) / 0.25, 0, 1) * (al > 0.5)).astype(np.float32)


def build():
    gkit.use("saltmaw_grotto")
    b = board_kit.Board(key="magenta", floor_fill=(14, 24, 26))
    for i in (1, 2, 3):
        b.tile("floor_a_%d.jpg" % i, "grotto_floor_%s" % "abc"[i - 1], "a")
        b.tile("floor_b_%d.jpg" % i, "lair_floor_%s" % "abc"[i - 1], "b")
    pr = b.tile("coral_pad.jpg", "coral_pad", "a", kind="glow_pad")
    b.pad_glow(pr, "coral_pad_glow", "coral_pad", col=TEAL, bright=teal_bright(pr), gain=(3.0, 0.9))
    g = {"mul": (0.9, 0.93, 0.95), "sat": 0.92}
    b.prop("sunken_crate.jpg", "sunken_crate", "a+b", 60, grade=g,
           notes="barnacled crate stack with a rope coil and a starfish; line-of-fire cover in room A")
    b.prop("barrel.jpg", "barrel", "a+b", 60, grade=g, notes="two barnacled barrels and one on its side, with a rope coil")
    b.prop("coral_cluster.jpg", "coral_cluster", "a", 56, grade={"mul": (0.95, 0.97, 0.98), "sat": 0.95},
           notes="barnacled rock mound with glowing teal coral fans; has an additive _glow", glow=(coral_glow, TEAL, 4, 1.5))
    b.prop("anchor.jpg", "anchor", "a", 60, grade=g, notes="rusty ship anchor and chains leaning on a barnacled rock mound")
    b.prop("barnacle_rock.jpg", "barnacle_rock", "a+b", 58, grade=g, notes="knee-high barnacle and mussel rock with small teal anemones")
    b.prop("giant_clam.jpg", "giant_clam", "b", 60, grade=g, notes="giant open clam with a pearl on gold coins")
    b.prop("treasure_chest.jpg", "treasure_chest", "b", 56, grade=g, notes="open sunken pirate chest overflowing with gold")
    b.prop("sunken_statue.jpg", "sunken_statue", "b", 48, grade=g, notes="barnacled mermaid statue with a trident on a broken plinth (tall)")
    b.prop("rock_spire.jpg", "rock_spire", "b", 40, grade=g,
           notes="jagged green-grey standing rock; ring the whirlpool with these (blocking)")
    b.decal("whirlpool.jpg", "whirlpool", n=3, room="b", glow_mask=whirl_lines, glow_col=TEAL, glow_gain=(3, 0.9, 0.3))
    for n in (15, 12):
        b.backdrop("shell_room_a.jpg", "room_a_grotto", "a", n, "grotto_floor")
        b.backdrop("shell_room_b.jpg", "room_b_lair", "b", n, "lair_floor")
    for k in META:
        META[k][:] = b.META[k]
    return META


if __name__ == "__main__":
    import json
    m = build()
    print(json.dumps({k: [(e["id"], e.get("size")) for e in v] for k, v in m.items()}))
    for bd in m["backdrops"]:
        print(bd["id"], bd["size"], bd["cell00_centre_px"], bd["fit_residual_px"])
