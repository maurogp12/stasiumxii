"""Write art/pc/dungeons/frostspire_archive/manifest.json (format stasium.dungeon_art v1, the
same keys as the Old Granary Cellar's): every shipped file with its kind, size,
pivot/anchor, footprint or cell, frame counts and fps.

Run after build_frostspire_town.py, build_frostspire_board.py, build_frostspire_fx.py
and frostspire_monsters.py. A monster whose meta.json is not built yet gets a
"status": "pending" entry with its planned cell, pivot and frame counts.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import build_frostspire_board as board  # noqa: E402
import build_frostspire_fx as fx  # noqa: E402
import manifest_kit  # noqa: E402

FPS = 17.144
BASE_ACTS = {"idle": 12, "walk": 12, "attack": 12, "hit": 8, "death": 13}
LOOP = {"idle": True, "walk": True}
FROST_GLOW = "cyan frost runes, eyes and black-ice cores bloomed + faint ice-blue aura"
PLAN = {
    "ice_construct": ("Ice Construct", False, (512, 360), (256, 329), {}),
    "book_wraith": ("Book Wraith", False, (512, 360), (256, 329), {}),
    "the_pale_archivist": ("The Pale Archivist", False, (768, 540), (384, 494), {"summon": 14}),
    "frozen_ice_construct": ("Frozen Ice Construct", True, (512, 360), (256, 329), {}),
    "frozen_book_wraith": ("Frozen Book Wraith", True, (512, 360), (256, 329), {}),
    "the_frozen_archivist": ("The Frozen Archivist", True, (768, 540), (384, 494), {"summon": 14}),
}
SIG = {"action": "summon", "name": "Unbound Pages",
       "note": ("raises the chained grimoire high, it glows and the pages strain (f03-f09); at f09 the pages burst out: "
                "spawn the summoned Book Wraiths on f09; f10-f13 the arms lower back to idle"),
       "frames": {"raise_start": 3, "glow_hold": [3, 9], "spawn": 9, "lower": [10, 13]}}
BIG_NOTE = ("1.5x the hero height: 768x540 cell, pivot (384,494) = the hero cell scaled 1.5x. "
            "Draw it exactly like a hero cell at the same sprite scale, but so that pixel (384,494) lands where a hero's (256,329) lands: "
            "for a centred Sprite2D, offset_boss = offset_hero + (0, (540-360)/2 - (494-329)) = offset_hero - (0, 75) (before scale).")


def pending(mid):
    name, star, cell, piv, extra = PLAN[mid]
    d = ("star5/monsters/" if star else "monsters/") + mid
    acts = dict(BASE_ACTS, **extra)
    e = {"id": mid, "name": name, "dir": d, "cell": list(cell), "pivot": list(piv), "fps": FPS, "status": "pending",
         "actions": {a: {"frames": n, "loop": LOOP.get(a, False), "fps": FPS, "duration_s": round(n / FPS, 3),
                         "pattern": "%s/%s/%s_{S,E}_f{00..%02d}.png" % (d, a, a, n - 1)} for a, n in acts.items()}}
    if star:
        e["star"] = 5
    return e


def main():
    gkit.use("frostspire_archive")
    meta_board = board.build()
    mk = manifest_kit.Manifest()
    add, size = mk.add, mk.size

    for sub, sc in (("", 1), ("_2x/", 2)):
        for nm, kind in (("frostspire_door", "building"), ("frostspire_door_glow", "glow_add")):
            add("town/%s%s.png" % (sub, nm), kind, scale=1.0 / sc, master="2x" if sc == 2 else "1x")
    w, h = size("town/frostspire_door.png")
    town_entry = {
        "id": "frostspire_door", "zone": "northgate",
        "file": "town/frostspire_door.png", "file_2x": "town/_2x/frostspire_door.png",
        "hatch_glow": "town/frostspire_door_glow.png", "hatch_glow_2x": "town/_2x/frostspire_door_glow.png",
        "size": [w, h], "size_2x": size("town/_2x/frostspire_door.png"),
        "footprint_size": [3, 3], "footprint_from_nw": [[x, y] for y in range(3) for x in range(3)],
        "blocks": True, "anchor_cell_from_nw": [2, 2],
        "anchor": "image bottom-centre = south tip of cell origin+[2,2] (Crosshaven kit rule: draw at cell_to_local(origin+(2,2)) + (0,16) + (-w/2, -h); 2x master at scale 0.5, same placement)",
        "bottom_centre_from_nw_centre_1x": [0, 80],
        "pivot_px_1x": [w // 2, h],
        "y_sort": "z = (south cell x+y) * TILE_Z_SCALE + 2, as crosshaven_prop.gd; y-sort point = image bottom - 16 px",
        "door_cell_from_nw": [2, 3],
        "door_note": "the open archive doors and the frosted steps face SW (+y); the passable, clickable door cell is just outside the footprint in front of the steps, origin+(2,3) (the steps fill cell (2,2), next to the south tip). The Door Keeper NPC (northgate_door_keeper, body npc_door_keeper) stands beside it, e.g. origin+(1,3) or origin+(3,3). The book crates at the left overhang the footprint's west corner by a few px.",
        "hatch_glow_note": "the ice-blue light inside the open doors and on the steps; additive blend (CanvasItemMaterial BLEND_MODE_ADD), same canvas and anchor as the building; fade modulate 0 -> 1 on hover of the door cell or the building",
        "source_painting": "build_tools/dungeons/frostspire_src/town_frostspire.jpg",
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
            mk.mm_dir(mid)
        except FileNotFoundError:
            return pending(mid)
        return mk.monster(mid, glow_what=FROST_GLOW)

    monsters = [monster(m) for m in ("ice_construct", "book_wraith", "the_pale_archivist")]
    monsters[0]["pawn_note"] = ("Hero-format cell (512x360, pivot (256,329)): place it exactly as the hero action cells. "
                                "Same for the Book Wraith.")
    monsters[0]["role"] = "room A heavy melee tank: a hulking golem of frozen books and shelves; slow, hits hard with its ice fists"
    monsters[1]["role"] = ("room A ranged caster: a floating wraith of shrouds and pages with a book for a head; "
                           "attack = wind-up and a thrown frost bolt, projectile board/projectiles/frost_bolt (or paper_bolt) released on the release frame, "
                           "board/projectiles/frost_bolt_impact on hit; it floats (no feet), so its walk is a glide")
    monsters[2]["size_note"] = BIG_NOTE
    monsters[2]["signature"] = SIG

    star5_monsters = [monster(m) for m in ("the_frozen_archivist", "frozen_ice_construct", "frozen_book_wraith")]
    star5_monsters[0]["size_note"] = BIG_NOTE
    star5_monsters[0]["signature"] = dict(SIG, note=SIG["note"].replace("Book Wraiths", "Frozen Book Wraiths (star5 frozen_book_wraith)"))
    star5_monsters[0]["special"] = ("'Rime Patches': leaves star5/board/frost_patch decals on 2-3 cells around the hero "
                                    "(e.g. on the summon's f09 or the attack's impact frame f06); the patch is purely visual, gameplay is CombatSim's")
    star5_monsters[0]["turnaround"] = "_mock/the_frozen_archivist_turnaround.png"

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
        "dungeon": "frostspire_archive", "name": "Frostspire Archive", "town": "Northgate", "levels": [10, 20],
        "root": "res://art/pc/dungeons/frostspire_archive/",
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
            "draw_order": ["backdrop (behind everything, board hole cut out)", "floor tiles (archive_floor_* room A / hall_floor_* room B; pick variant by h(x,y,3) as the kit hash; rune_pad on pad cells)",
                           "floor decals + their glows (rune_circle, ground layer; star-5 frost_patch)", "rune_pad_glow (add) on pad cells",
                           "props and units y-sorted by south-most cell (x+y); prop glows (ice_crystals_glow, frost_brazier_glow) added on top of their prop"],
            "rooms": {
                "a": {"name": "The archive stacks (pack fight)", "floor": ["archive_floor_a", "archive_floor_b", "archive_floor_c"], "pad": "rune_pad", "pad_glow": "rune_pad_glow",
                      "props": [p for p in ("frozen_bookshelf", "book_pile", "reading_desk", "ice_crystals", "frozen_chest") if p in props],
                      "monsters": ["ice_construct", "book_wraith"], "backdrop": {"15": "room_a_archive_15x15", "12": "room_a_archive_12x12"}},
                "b": {"name": "The Pale Archivist's reading hall (boss)", "floor": ["hall_floor_a", "hall_floor_b", "hall_floor_c"], "pad": "rune_pad", "pad_glow": "rune_pad_glow",
                      "props": [p for p in ("ice_throne", "frost_brazier", "book_pile", "frozen_chest", "frozen_bookshelf", "ice_crystals") if p in props],
                      "decals": ["rune_circle"], "monsters": ["the_pale_archivist", "ice_construct", "book_wraith"],
                      "backdrop": {"15": "room_b_hall_15x15", "12": "room_b_hall_12x12"}},
            },
            "mock": "_mock/rooms_mock.png",
        },
        "monsters": monsters,
        "projectiles": base_proj,
        "star5": {
            "rule": ("at star-5 difficulty the Frostspire Archive boss is The Frozen Archivist (replaces the_pale_archivist), a blizzard-bound frozen lich; "
                     "his summons are frozen_book_wraith, and room A's monsters may be frozen_ice_construct and frozen_book_wraith"),
            "monsters": star5_monsters,
            "board": {"decals": s5["decals"], "glows": s5["glows"]},
            "projectiles": star5_proj,
            "turnaround": "_mock/the_frozen_archivist_turnaround.png",
            "contact_sheets": ["_mock/star5_the_frozen_archivist_contact.png", "_mock/star5_frozen_ice_construct_contact.png", "_mock/star5_frozen_book_wraith_contact.png"],
        },
        "files": mk.files,
        "build": "python3 build_tools/dungeons/build_frostspire_town.py; python3 build_tools/dungeons/build_frostspire_board.py; python3 build_tools/dungeons/build_frostspire_fx.py; python3 build_tools/dungeons/frostspire_monsters.py; python3 build_tools/dungeons/build_frostspire_manifest.py; python3 build_tools/dungeons/mock_rooms.py frostspire_archive; python3 build_tools/dungeons/mock_town.py frostspire_archive; python3 build_tools/dungeons/mock_monsters.py --dungeon frostspire_archive --clip <out.mp4> --clip5 <out_star5.mp4>",
    }
    gkit.write_json(os.path.join(gkit.OUT, "manifest.json"), man)
    missing, extra = mk.check()
    if missing or extra:
        raise SystemExit("manifest does not match the files on disk")
    return man


if __name__ == "__main__":
    main()
