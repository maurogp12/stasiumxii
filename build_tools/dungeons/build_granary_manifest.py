"""Write art/pc/dungeons/old_granary_cellar/manifest.json: every shipped file with its
kind, size, pivot/anchor, footprint or cell, frame counts and fps.

Run after build_granary_town.py, build_granary_board.py and granary_monsters.py.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import build_granary_board as board  # noqa: E402
import build_granary_star5 as build_star5  # noqa: E402

import manifest_kit  # noqa: E402


def main():
    gkit.use("old_granary_cellar")
    ROOT = gkit.OUT
    meta_board = board.build()
    mk = manifest_kit.Manifest()
    files = mk.files
    size = mk.size
    add = mk.add

    # Town door.
    town = []
    for sub, sc in (("", 1), ("_2x/", 2)):
        for nm, kind in (("granary_door", "building"), ("granary_door_hatch_glow", "glow_add")):
            p = "town/%s%s.png" % (sub, nm)
            add(p, kind, scale=1.0 / sc, master="2x" if sc == 2 else "1x")
    town_entry = {
        "id": "granary_door", "zone": "stoneford",
        "file": "town/granary_door.png", "file_2x": "town/_2x/granary_door.png",
        "hatch_glow": "town/granary_door_hatch_glow.png", "hatch_glow_2x": "town/_2x/granary_door_hatch_glow.png",
        "size": size("town/granary_door.png"), "size_2x": size("town/_2x/granary_door.png"),
        "footprint_size": [3, 3], "footprint_from_nw": [[x, y] for y in range(3) for x in range(3)],
        "blocks": True, "anchor_cell_from_nw": [2, 2],
        "anchor": "image bottom-centre = south tip of cell origin+[2,2] (Crosshaven kit rule: draw at cell_to_local(origin+(2,2)) + (0,16) + (-w/2, -h); 2x master at scale 0.5, same placement)",
        "bottom_centre_from_nw_centre_1x": [0, 80],
        "pivot_px_1x": [size("town/granary_door.png")[0] // 2, size("town/granary_door.png")[1]],
        "y_sort": "z = (south cell x+y) * TILE_Z_SCALE + 2, as crosshaven_prop.gd; y-sort point = image bottom - 16 px",
        "door_cell_from_nw": [1, 3],
        "door_note": "the open hatch and stair pit face SW (+y); the passable, clickable door cell is just outside the footprint in front of the stairs, origin+(1,3). The Door Keeper NPC stands beside it, e.g. origin+(3,3) or origin+(0,3).",
        "hatch_glow_note": "additive blend (CanvasItemMaterial BLEND_MODE_ADD), same canvas and anchor as the building; fade modulate 0 -> 1 on hover of the door cell or the building",
        "source_painting": "build_tools/dungeons/granary_src/town_granary.jpg",
    }

    # Board kit.
    for t in meta_board["tiles"]:
        add(t["file"], "floor_tile" if t["kind"] == "floor" else "glow_pad_tile", room=t["room"], anchor="centre on cell centre")
        add(t["file_2x"], "floor_tile" if t["kind"] == "floor" else "glow_pad_tile", room=t["room"], master="2x", scale=0.5)
    for g in meta_board["glows"]:
        add(g["file"], "glow_add", for_id=g["for"])
        add(g["file_2x"], "glow_add", for_id=g["for"], master="2x", scale=0.5)
    for p in meta_board["props"]:
        add(p["file"], "board_prop", footprint=p["footprint_size"], anchor="bottom-centre on south tip of the south-most footprint cell")
        add(p["file_2x"], "board_prop", footprint=p["footprint_size"], master="2x", scale=0.5)
    for d in meta_board["decals"]:
        add(d["file"], "floor_decal", footprint=d["footprint_size"])
        add(d["file_2x"], "floor_decal", footprint=d["footprint_size"], master="2x", scale=0.5)
    for b in meta_board["backdrops"]:
        add(b["file"], "backdrop", board_size=b["board_size"], cell00_centre_px=b["cell00_centre_px"])

    # Monsters.
    monster = mk.monster

    monsters = [monster(m) for m in ("granary_rat", "sling_rat", "scarecrow_drudge", "the_ratking")]
    big_note = ("1.5x the hero height: 768x540 cell, pivot (384,494) = the hero cell scaled 1.5x. "
                "Draw it exactly like a hero cell at the same sprite scale, but so that pixel (384,494) lands where a hero's (256,329) lands: "
                "for a centred Sprite2D, offset_ratking = offset_hero + (0, (540-360)/2 - (494-329)) = offset_hero - (0, 75) (before scale).")
    monsters[3]["size_note"] = big_note
    monsters[0]["pawn_note"] = ("Hero-format cell (512x360, pivot (256,329)): place it exactly as the hero action cells. "
                                "Same for the Sling Rat and the Scarecrow Drudge.")
    monsters[1]["role"] = ("room A ranged attacker: a Granary Rat on its hind legs with a sack hood and a leather sling; "
                           "attack = sling wind-up, whirl and throw, projectile board/projectiles/sling_pebble (or sling_seed) released on the release frame, "
                           "board/projectiles/sling_impact_puff on hit")
    sig = {"action": "summon", "note": "raises the crook and squeals; spawn the summoned Granary Rats around frame 9 (crook at its highest, squeal held f3-f9), crook slams at f10"}
    monsters[3]["signature"] = sig

    star5_monsters = [monster(m) for m in ("radioactive_ratking", "radioactive_rat", "radioactive_sling_rat")]
    star5_monsters[0]["size_note"] = big_note
    star5_monsters[0]["signature"] = dict(sig, note=sig["note"].replace("Granary Rats", "Radioactive Rats (star5 radioactive_rat)"))
    star5_monsters[0]["special"] = ("leaves star5/board/toxic_pool decals: e.g. on the attack's impact frame (f06) under the target, "
                                    "or on the cells he walks through; the pool is purely visual, gameplay is CombatSim's")
    star5_monsters[0]["turnaround"] = "_mock/radioactive_ratking_turnaround.png"

    s5 = build_star5.build()
    for d in s5["decals"]:
        add(d["file"], "floor_decal", footprint=d["footprint_size"], star=5)
        add(d["file_2x"], "floor_decal", footprint=d["footprint_size"], star=5, master="2x", scale=0.5)
    for g in s5["glows"]:
        add(g["file"], "glow_add", for_id=g["for"], star=5)
        add(g["file_2x"], "glow_add", for_id=g["for"], star=5, master="2x", scale=0.5)
    projectiles = []
    for p in s5["projectiles"]:
        add(p["file"], p["kind"], anchor="centre")
        add(p["file_2x"], p["kind"], anchor="centre", master="2x", scale=0.5)
        if p.get("glow"):
            add(p["glow"], "glow_add", for_id=p["id"], anchor="centre")
            add(p["glow_2x"], "glow_add", for_id=p["id"], anchor="centre", master="2x", scale=0.5)
        projectiles.append(p)
    base_proj = [p for p in projectiles if p.get("star") != 5]
    star5_proj = [p for p in projectiles if p.get("star") == 5]

    man = {
        "format": "stasium.dungeon_art", "format_version": 1,
        "dungeon": "old_granary_cellar", "name": "Old Granary Cellar", "town": "Stoneford", "levels": [1, 10],
        "root": "res://art/pc/dungeons/old_granary_cellar/",
        "conventions": {
            "alpha": "every PNG is binary alpha (0/255) with RGB 0 under alpha 0; glow_add files are additive (black adds nothing) and must use an add blend",
            "masters": "files under _2x/ are 2x masters: draw at scale 0.5 with the same placement as the 1x file (crosshaven_art.gd prefers _2x)",
            "grid": "64x32 diamonds; cell_to_local(x,y) = ((x-y)*32, (x+y)*16) = the diamond centre; south tip = centre + (0,16)",
            "import": "linear filter, no mipmaps, plain alpha",
            "review_only": "_mock/ has a .gdignore and is not game art",
        },
        "town_door": town_entry,
        "board": {
            "tiles": meta_board["tiles"], "glows": meta_board["glows"], "props": meta_board["props"],
            "decals": meta_board["decals"], "backdrops": meta_board["backdrops"],
            "draw_order": ["backdrop (behind everything, board hole cut out)", "floor tiles (cellar_floor_* room A / lair_floor_* room B; pick variant by h(x,y,3) as the kit hash; wheat_pad on pad cells)",
                           "floor decals + their glows (drain_grate, ground layer)", "wheat_pad_glow (add) on pad cells",
                           "props and units y-sorted by south-most cell (x+y)"],
            "rooms": {
                "a": {"name": "Old Granary Cellar (pack fight)", "floor": ["cellar_floor_a", "cellar_floor_b", "cellar_floor_c"], "pad": "wheat_pad",
                      "props": ["crate_stack", "grain_sacks", "barrel_cluster", "broken_crate"], "monsters": ["granary_rat", "sling_rat", "scarecrow_drudge"], "backdrop": {"15": "room_a_cellar_15x15", "12": "room_a_cellar_12x12"}},
                "b": {"name": "The Ratking's lair (boss)", "floor": ["lair_floor_a", "lair_floor_b", "lair_floor_c"], "pad": "wheat_pad",
                      "props": ["bone_throne", "crate_stack", "grain_sacks", "barrel_cluster", "broken_crate"], "decals": ["drain_grate"],
                      "backdrop": {"15": "room_b_lair_15x15", "12": "room_b_lair_12x12"}},
            },
            "mock": "_mock/rooms_mock.png",
        },
        "monsters": monsters,
        "projectiles": base_proj,
        "star5": {
            "rule": "at star-5 difficulty the Old Granary Cellar boss is the Radioactive Ratking (replaces the_ratking), his summons are radioactive_rat, and room A's sling rats may be radioactive_sling_rat; mobile's equivalent is boss_art_5",
            "monsters": star5_monsters,
            "board": {"decals": s5["decals"], "glows": s5["glows"]},
            "projectiles": star5_proj,
            "turnaround": "_mock/radioactive_ratking_turnaround.png",
            "contact_sheets": ["_mock/star5_radioactive_ratking_contact.png", "_mock/star5_radioactive_rat_contact.png", "_mock/star5_radioactive_sling_rat_contact.png"],
        },
        "files": files,
        "build": "python3 build_tools/dungeons/build_granary_town.py; python3 build_tools/dungeons/build_granary_board.py; python3 build_tools/dungeons/build_granary_star5.py; python3 build_tools/dungeons/granary_monsters.py; python3 build_tools/dungeons/build_granary_manifest.py; python3 build_tools/dungeons/mock_granary_rooms.py; python3 build_tools/dungeons/mock_monsters.py --clip <out.mp4> --clip5 <out_star5.mp4>",
    }
    gkit.write_json(os.path.join(ROOT, "manifest.json"), man)
    # Sanity: every PNG under ROOT (except _mock) is listed.
    mk.check()
    return man


if __name__ == "__main__":
    main()
