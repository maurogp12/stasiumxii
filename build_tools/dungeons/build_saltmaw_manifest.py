"""Write art/pc/dungeons/saltmaw_grotto/manifest.json (format stasium.dungeon_art v1, the same keys
as the Old Granary Cellar's and the Frostspire Archive's): every shipped file with its kind, size,
pivot/anchor, footprint or cell, frame counts and fps.

Run after build_saltmaw_town.py, build_saltmaw_board.py, build_saltmaw_fx.py and
saltmaw_monsters.py. A monster whose meta.json is not built yet gets a "status": "pending"
entry with its planned cell, pivot and frame counts.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import build_saltmaw_board as board  # noqa: E402
import build_saltmaw_fx as fx  # noqa: E402
import manifest_kit  # noqa: E402

FPS = 17.144
BASE_ACTS = {"idle": 12, "walk": 12, "attack": 12, "hit": 8, "death": 13}
LOOP = {"idle": True, "walk": True}
ABYSS_GLOW = "bioluminescent abyssal cyan spots, veins, runes, eyes and lure bloomed + faint cyan aura"
PLAN = {
    "reef_crab": ("Reef Crab", False, (512, 360), (256, 329), {}),
    "drowned_sailor": ("Drowned Sailor", False, (512, 360), (256, 329), {}),
    "drowned_harpooner": ("Drowned Harpooner", False, (512, 360), (256, 329), {}),
    "old_saltmaw": ("Old Saltmaw", False, (768, 540), (384, 494), {"summon": 14}),
    "abyssal_saltmaw": ("Abyssal Saltmaw", True, (768, 540), (384, 494), {"summon": 14}),
    "abyssal_reef_crab": ("Abyssal Reef Crab", True, (512, 360), (256, 329), {}),
    "abyssal_drowned_sailor": ("Abyssal Drowned Sailor", True, (512, 360), (256, 329), {}),
    "abyssal_drowned_harpooner": ("Abyssal Drowned Harpooner", True, (512, 360), (256, 329), {}),
}
SIG = {"action": "summon", "name": "Lantern Lure",
       "note": ("a pull: he crouches (f00-f02), lifts the glowing lure high (f03-f06); on f07 the lure FLARES and the pull fires "
                "(slide the hero toward him over f07-f10, optionally stretch board/projectiles/lure_line from the hero to lure_point); "
                "f10-f13 he settles back to idle. The strip name stays 'summon' (14 frames)"),
       "frames": {"crouch": [0, 2], "lift": [3, 6], "flare": 7, "pull": [7, 10], "settle": [10, 13]}}
BIG_NOTE = ("1.5x the hero height: 768x540 cell, pivot (384,494) = the hero cell scaled 1.5x. "
            "Draw it exactly like a hero cell at the same sprite scale, but so that pixel (384,494) lands where a hero's (256,329) lands: "
            "for a centred Sprite2D, offset_boss = offset_hero + (0, (540-360)/2 - (494-329)) = offset_hero - (0, 75) (before scale).")
MELEE_NOTE = "melee: the attack connects on f06 (play the hit reaction / damage number there)"


def pending(mid):
    name, star, cell, piv, extra = PLAN[mid]
    d = ("star5/monsters/" if star else "monsters/") + mid
    acts = dict(BASE_ACTS, **extra)
    e = {"id": mid, "name": name, "dir": d, "cell": list(cell), "pivot": list(piv), "fps": FPS, "status": "pending",
         "actions": {a: {"frames": n, "loop": LOOP.get(a, False), "fps": FPS, "duration_s": round(n / FPS, 3),
                         "pattern": "%s/%s/%s_{S,E}_f{00..%02d}.png" % (d, a, a, n - 1)} for a, n in acts.items()}}
    if star:
        e["star"] = 5
    if mid in ("drowned_harpooner", "abyssal_drowned_harpooner"):
        e["release"] = {"action": "attack", "frame": 7, "point_px": "pending"}
    return e


def main():
    gkit.use("saltmaw_grotto")
    meta_board = board.build()
    mk = manifest_kit.Manifest()
    add, size = mk.add, mk.size

    for sub, sc in (("", 1), ("_2x/", 2)):
        for nm, kind in (("saltmaw_door", "building"), ("saltmaw_door_glow", "glow_add")):
            add("town/%s%s.png" % (sub, nm), kind, scale=1.0 / sc, master="2x" if sc == 2 else "1x")
    w, h = size("town/saltmaw_door.png")
    town_entry = {
        "id": "saltmaw_door", "zone": "eastmarch",
        "file": "town/saltmaw_door.png", "file_2x": "town/_2x/saltmaw_door.png",
        "hatch_glow": "town/saltmaw_door_glow.png", "hatch_glow_2x": "town/_2x/saltmaw_door_glow.png",
        "size": [w, h], "size_2x": size("town/_2x/saltmaw_door.png"),
        "footprint_size": [3, 3], "footprint_from_nw": [[x, y] for y in range(3) for x in range(3)],
        "blocks": True, "anchor_cell_from_nw": [2, 2],
        "anchor": "image bottom-centre = south tip of cell origin+[2,2] (Crosshaven kit rule: draw at cell_to_local(origin+(2,2)) + (0,16) + (-w/2, -h); 2x master at scale 0.5, same placement)",
        "bottom_centre_from_nw_centre_1x": [0, 80],
        "pivot_px_1x": [w // 2, h],
        "y_sort": "z = (south cell x+y) * TILE_Z_SCALE + 2, as crosshaven_prop.gd; y-sort point = image bottom - 16 px",
        "door_cell_from_nw": [1, 3],
        "door_note": ("the fanged sea-cave maw opens on the SW (+y) face and its plank pier runs out to the lower left, ending at the SW edge of cell (1,2); "
                      "the passable, clickable door cell is just outside the footprint at the pier end, origin+(1,3). The Door Keeper NPC "
                      "(eastmarch_door_keeper, body npc_door_keeper) stands beside it, e.g. origin+(0,3) or origin+(2,3). "
                      "The small rock at the front tip and the pier posts overhang the footprint's south edge by a few px."),
        "hatch_glow_note": "the teal-green light deep inside the cave maw; additive blend (CanvasItemMaterial BLEND_MODE_ADD), same canvas and anchor as the building; fade modulate 0 -> 1 on hover of the door cell or the building",
        "source_painting": "build_tools/dungeons/saltmaw_src/town_saltmaw.jpg",
    }

    for t in meta_board["tiles"]:
        k = "floor_tile" if t["kind"] == "floor" else "glow_pad_tile"
        add(t["file"], k, room=t["room"], anchor="centre on cell centre")
        add(t["file_2x"], k, room=t["room"], master="2x", scale=0.5)
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

    def monster(mid):
        try:
            d = mk.mm_dir(mid)
        except FileNotFoundError:
            return pending(mid)
        e = mk.monster(mid, glow_what=ABYSS_GLOW)
        mm = json.load(open(os.path.join(mk.root, d, "meta.json")))
        if mm.get("lure_point"):
            e["lure_point"] = dict(mm["lure_point"], note=("the lure tip on the signature's flare frame, per facing, in cell pixels (same space as the pivot); "
                                                            "mirror x about the cell centre for the mirrored facings. Start the pull and the lure_line here"))
        return e

    monsters = [monster(m) for m in ("reef_crab", "drowned_sailor", "drowned_harpooner", "old_saltmaw")]
    monsters[0]["pawn_note"] = ("Hero-format cell (512x360, pivot (256,329)): place it exactly as the hero action cells. "
                                "Same for the Drowned Sailor and the Drowned Harpooner.")
    monsters[0]["role"] = "room A melee tank: a low, wide barnacled reef crab with coral on its back; " + MELEE_NOTE
    monsters[1]["role"] = "room A melee: a drowned pirate with a rusty cutlass and a teal lantern; " + MELEE_NOTE
    monsters[2]["role"] = ("room A ranged: a drowned whaler who throws harpoons; attack = wind-up and throw, projectile "
                           "board/projectiles/harpoon released on the release frame (the harpoon in his hand is hidden f07-f10, a fresh one is back on f11), "
                           "board/projectiles/harpoon_impact on hit")
    monsters[3]["size_note"] = BIG_NOTE
    monsters[3]["signature"] = SIG
    monsters[3]["role"] = "boss: a huge anglerfish beast wrapped in anchor chains; attack = a lunging bite that snaps shut on f06"

    star5_monsters = [monster(m) for m in ("abyssal_saltmaw", "abyssal_reef_crab", "abyssal_drowned_sailor", "abyssal_drowned_harpooner")]
    star5_monsters[0]["size_note"] = BIG_NOTE
    star5_monsters[0]["signature"] = SIG
    star5_monsters[0]["special"] = ("'Riptide': leaves star5/board/riptide decals (1 cell each) around the board; ending a turn on one deals damage and "
                                    "drags the hero 1 cell toward him. The decal is purely visual, gameplay is CombatSim's")
    star5_monsters[0]["turnaround"] = "_mock/abyssal_saltmaw_turnaround.png"

    s5 = fx.build()
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

    props = {p["id"]: p for p in meta_board["props"]}
    man = {
        "format": "stasium.dungeon_art", "format_version": 1,
        "dungeon": "saltmaw_grotto", "name": "Saltmaw Grotto", "town": "Eastmarch", "levels": [20, 30],
        "root": "res://art/pc/dungeons/saltmaw_grotto/",
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
            "draw_order": ["backdrop (behind everything, board hole cut out)", "floor tiles (grotto_floor_* room A / lair_floor_* room B; pick variant by h(x,y,3) as the kit hash; coral_pad on pad cells)",
                           "floor decals + their glows (whirlpool, ground layer; star-5 riptide)", "coral_pad_glow (add) on pad cells",
                           "props and units y-sorted by south-most cell (x+y); prop glows (coral_cluster_glow) added on top of their prop"],
            "rooms": {
                "a": {"name": "The sea cave (pack fight)", "floor": ["grotto_floor_a", "grotto_floor_b", "grotto_floor_c"], "pad": "coral_pad", "pad_glow": "coral_pad_glow",
                      "props": [p for p in ("sunken_crate", "barrel", "coral_cluster", "anchor", "barnacle_rock") if p in props],
                      "monsters": ["reef_crab", "drowned_sailor", "drowned_harpooner"], "backdrop": {"15": "room_a_grotto_15x15", "12": "room_a_grotto_12x12"}},
                "b": {"name": "Old Saltmaw's treasure lair (boss)", "floor": ["lair_floor_a", "lair_floor_b", "lair_floor_c"], "pad": "coral_pad", "pad_glow": "coral_pad_glow",
                      "props": [p for p in ("rock_spire", "giant_clam", "treasure_chest", "sunken_statue", "barrel", "sunken_crate", "barnacle_rock") if p in props],
                      "decals": ["whirlpool"], "decal_note": "the whirlpool is a walkable 5x5 floor decal (measured on the design): its stone kerb runs along the 5x5 border cells and the swirling water fills about the inner 3x3; stand blocking rock_spire props on some of the 16 border cells (the design shows 8-10 standing rocks on the kerb), leaving gaps so the water stays reachable",
                      "monsters": ["old_saltmaw", "reef_crab", "drowned_sailor"],
                      "backdrop": {"15": "room_b_lair_15x15", "12": "room_b_lair_12x12"}},
            },
            "mock": "_mock/rooms_mock.png",
        },
        "monsters": monsters,
        "projectiles": base_proj,
        "star5": {
            "rule": ("at star-5 difficulty the Saltmaw Grotto boss is the Abyssal Saltmaw (replaces old_saltmaw), risen from the deepest trench; "
                     "room A's monsters may be abyssal_reef_crab, abyssal_drowned_sailor and abyssal_drowned_harpooner"),
            "monsters": star5_monsters,
            "board": {"decals": s5["decals"], "glows": s5["glows"]},
            "projectiles": star5_proj,
            "turnaround": "_mock/abyssal_saltmaw_turnaround.png",
            "contact_sheets": ["_mock/star5_abyssal_saltmaw_contact.png", "_mock/star5_abyssal_reef_crab_contact.png",
                               "_mock/star5_abyssal_drowned_sailor_contact.png", "_mock/star5_abyssal_drowned_harpooner_contact.png"],
        },
        "files": mk.files,
        "build": "python3 build_tools/dungeons/build_saltmaw_town.py; python3 build_tools/dungeons/build_saltmaw_board.py; python3 build_tools/dungeons/build_saltmaw_fx.py; python3 build_tools/dungeons/saltmaw_monsters.py; python3 build_tools/dungeons/saltmaw_monsters.py abyssal_saltmaw abyssal_reef_crab abyssal_drowned_sailor abyssal_drowned_harpooner; python3 build_tools/dungeons/build_saltmaw_manifest.py; python3 build_tools/dungeons/mock_rooms.py saltmaw_grotto [--star5]; python3 build_tools/dungeons/mock_town.py saltmaw_grotto; python3 build_tools/dungeons/mock_turnarounds.py --dungeon saltmaw_grotto; python3 build_tools/dungeons/mock_monsters.py --dungeon saltmaw_grotto --clip <out.mp4> --clip5 <out_star5.mp4>",
    }
    gkit.write_json(os.path.join(gkit.OUT, "manifest.json"), man)
    missing, extra = mk.check()
    if missing or extra:
        raise SystemExit("manifest does not match the files on disk")
    return man


if __name__ == "__main__":
    main()
