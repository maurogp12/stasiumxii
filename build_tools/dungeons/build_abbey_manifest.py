"""Write art/pc/dungeons/drowned_abbey/manifest.json (format stasium.dungeon_art v1, the same keys
as the Granary's, the Frostspire Archive's and the Saltmaw Grotto's): every shipped file with its kind, size,
pivot/anchor, footprint or cell, frame counts and fps.

Run after build_abbey_town.py, build_abbey_board.py, build_abbey_fx.py and
abbey_monsters.py. A monster whose meta.json is not built yet gets a "status": "pending"
entry with its planned cell, pivot and frame counts.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import build_abbey_board as board  # noqa: E402
import build_abbey_fx as fx  # noqa: E402
import manifest_kit  # noqa: E402

FPS = 17.144
BASE_ACTS = {"idle": 12, "walk": 12, "attack": 12, "hit": 8, "death": 13}
LOOP = {"idle": True, "walk": True}
GHOST_GLOW_WHAT = "green ghost-light (under the bell rim, veils, wisps, eyes, pustules) and candle flames bloomed + faint green aura"
PLAN = {
    "bog_dead": ("Bog Dead", False, (512, 360), (256, 329), {}),
    "mire_leech": ("Mire Leech", False, (512, 360), (256, 329), {}),
    "mire_abbess": ("The Mire Abbess", False, (768, 540), (384, 494), {"summon": 14}),
    "bell_wraith": ("The Bell Wraith", True, (768, 540), (384, 494), {"summon": 14}),
    "bellbound_bog_dead": ("Bellbound Bog Dead", True, (512, 360), (256, 329), {}),
    "bellbound_mire_leech": ("Bellbound Mire Leech", True, (512, 360), (256, 329), {}),
}
SIG = {"action": "summon", "name": "Rite of Rising",
       "note": ("she raises a FALLEN Bog Dead on its death cell: she lowers the censer (f00-f02), swings it high over her head while the "
                "floating candles rise and flare (f03-f06); on f07 the green smoke bursts and the rite fires (stretch board/projectiles/rite_glow "
                "from rite_point to the corpse cell; the risen Bog Dead plays its own death strip reversed), she holds the censer high (f07-f09) "
                "and settles back to idle (f10-f13). The strip name stays 'summon' (14 frames)"),
       "frames": {"lower": [0, 2], "swing": [3, 6], "burst": 7, "hold": [7, 9], "settle": [10, 13]}}
BIG_NOTE = ("1.5x the hero height: 768x540 cell, pivot (384,494) = the hero cell scaled 1.5x. "
            "Draw it exactly like a hero cell at the same sprite scale, but so that pixel (384,494) lands where a hero's (256,329) lands: "
            "for a centred Sprite2D, offset_boss = offset_hero + (0, (540-360)/2 - (494-329)) = offset_hero - (0, 75) (before scale).")
MELEE_NOTE = "melee: the attack connects on f06 (play the hit reaction / damage number there)"
RANGED = ("room A ranged: a giant bog worm; attack = it rears back with its throat swelling (f01-f06) and spits a glob of acid bile on the "
          "release frame, projectile board/projectiles/bile_spit (lobbed), board/projectiles/bile_impact on hit")


def pending(mid):
    name, star, cell, piv, extra = PLAN[mid]
    d = ("star5/monsters/" if star else "monsters/") + mid
    acts = dict(BASE_ACTS, **extra)
    e = {"id": mid, "name": name, "dir": d, "cell": list(cell), "pivot": list(piv), "fps": FPS, "status": "pending",
         "actions": {a: {"frames": n, "loop": LOOP.get(a, False), "fps": FPS, "duration_s": round(n / FPS, 3),
                         "pattern": "%s/%s/%s_{S,E}_f{00..%02d}.png" % (d, a, a, n - 1)} for a, n in acts.items()}}
    if star:
        e["star"] = 5
    if mid in ("mire_leech", "bellbound_mire_leech"):
        e["release"] = {"action": "attack", "frame": 7, "point_px": "pending"}
    return e



def main():
    gkit.use("drowned_abbey")
    meta_board = board.build()
    mk = manifest_kit.Manifest()
    add, size = mk.add, mk.size

    for sub, sc in (("", 1), ("_2x/", 2)):
        for nm, kind in (("abbey_door", "building"), ("abbey_door_glow", "glow_add")):
            add("town/%s%s.png" % (sub, nm), kind, scale=1.0 / sc, master="2x" if sc == 2 else "1x")
    w, h = size("town/abbey_door.png")
    town_entry = {
        "id": "abbey_door", "zone": "southbridge",
        "file": "town/abbey_door.png", "file_2x": "town/_2x/abbey_door.png",
        "hatch_glow": "town/abbey_door_glow.png", "hatch_glow_2x": "town/_2x/abbey_door_glow.png",
        "size": [w, h], "size_2x": size("town/_2x/abbey_door.png"),
        "footprint_size": [3, 3], "footprint_from_nw": [[x, y] for y in range(3) for x in range(3)],
        "blocks": True, "anchor_cell_from_nw": [2, 2],
        "anchor": "image bottom-centre = south tip of cell origin+[2,2] (Crosshaven kit rule: draw at cell_to_local(origin+(2,2)) + (0,16) + (-w/2, -h); 2x master at scale 0.5, same placement)",
        "bottom_centre_from_nw_centre_1x": [0, 80],
        "pivot_px_1x": [w // 2, h],
        "y_sort": "z = (south cell x+y) * TILE_Z_SCALE + 2, as crosshaven_prop.gd; y-sort point = image bottom - 16 px",
        "door_cell_from_nw": [1, 3],
        "door_note": ("the ruined chapel's half-open door glows green on the SW (+y) face and a short plank pier runs out of it, ending at the SW edge "
                      "of cell (1,2); the passable, clickable door cell is just outside the footprint at the pier end, origin+(1,3). The Door Keeper NPC "
                      "(southbridge_door_keeper, body npc_door_keeper) stands beside it, e.g. origin+(0,3) (crosshaven_southbridge (23,26) for the "
                      "chapel at (23..25, 23..25) and the door at (24,26)). The foundation's front-right corner and the pier posts overhang the "
                      "footprint's south edges by a few px."),
        "hatch_glow_note": "the eerie green light in the half-open chapel door; additive blend (CanvasItemMaterial BLEND_MODE_ADD), same canvas and anchor as the building; fade modulate 0 -> 1 on hover of the door cell or the building",
        "source_painting": "build_tools/dungeons/abbey_src/town_abbey.jpg",
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
        e = mk.monster(mid, glow_what=GHOST_GLOW_WHAT)
        mm = json.load(open(os.path.join(mk.root, d, "meta.json")))
        if mm.get("rite_point"):
            e["rite_point"] = dict(mm["rite_point"], note=("the censer on the signature's burst frame, per facing, in cell pixels (same space as the pivot); "
                                                            "mirror x about the cell centre for the mirrored facings. Start rite_glow here and stretch it to the corpse cell"))
        return e

    monsters = [monster(m) for m in ("bog_dead", "mire_leech", "mire_abbess")]
    monsters[0]["pawn_note"] = ("Hero-format cell (512x360, pivot (256,329)): place it exactly as the hero action cells. Same for the Mire Leech.")
    monsters[0]["role"] = "room A melee shambler: a drowned monk in a rotten robe dripping bog weed; double claw rake; " + MELEE_NOTE
    monsters[0]["rise_note"] = "when the Mire Abbess's Rite of Rising raises a fallen Bog Dead, play its death strip in reverse (f12 -> f00) on the corpse cell, then idle"
    monsters[1]["role"] = RANGED
    monsters[2]["size_note"] = BIG_NOTE
    monsters[2]["signature"] = SIG
    monsters[2]["role"] = ("boss: a tall drowned abbess with an iron-cross halo, a bronze censer on chains and three floating candles; attack = "
                           "'Censer Lash' (range 1-2), she whips the censer out on its chains and it connects on f06")

    star5_monsters = [monster(m) for m in ("bell_wraith", "bellbound_bog_dead", "bellbound_mire_leech")]
    star5_monsters[0]["size_note"] = BIG_NOTE
    star5_monsters[0]["signature"] = SIG
    star5_monsters[0]["special"] = ("'Grasping Mire': leaves star5/board/grasping_mire decals (1 cell each); the rule is CombatSim's, the decal is purely visual")
    star5_monsters[0]["turnaround"] = "_mock/bell_wraith_turnaround.png"
    star5_monsters[0]["role"] = ("star-5 boss, a NEW silhouette with its own rig: the Mire Abbess risen as a ghost whose lower half is the fallen abbey bell, "
                                 "long spectral arms, the censer, five orbiting candles; attack 'Spectral Grasp' (range 1-2): the left spectral arm lashes down "
                                 "and across, connecting on f06; summon = Rite of Rising with the base timing (burst f07, rite_point per facing)")
    star5_monsters[0]["placement_note"] = ("same cell and pivot as mire_abbess (768x540, (384,494)); she floats: the pivot is the bell rim's bottom centre, "
                                           "the green ghost-light spills a little below it")

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
        "dungeon": "drowned_abbey", "name": "Drowned Abbey", "town": "Southbridge", "levels": [30, 40],
        "root": "res://art/pc/dungeons/drowned_abbey/",
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
            "draw_order": ["backdrop (behind everything, board hole cut out)", "floor tiles (nave_floor_* room A / sanctum_floor_* room B; pick variant by h(x,y,3) as the kit hash; candle_pad on pad cells)",
                           "floor decals + their glows (rune_circle, lily_pads, ground layer; star-5 grasping_mire)", "candle_pad_glow (add) on pad cells",
                           "props and units y-sorted by south-most cell (x+y); prop glows (candle_cluster_glow, altar_glow, candle_stand_glow) added on top of their prop"],
            "rooms": {
                "a": {"name": "The flooded nave (pack fight)", "floor": ["nave_floor_a", "nave_floor_b", "nave_floor_c"], "pad": "candle_pad", "pad_glow": "candle_pad_glow",
                      "props": [p for p in ("pew", "broken_pillar", "fallen_statue", "candle_cluster", "coffin", "gravestone", "gnarled_roots") if p in props],
                      "decals": ["lily_pads"],
                      "monsters": ["bog_dead", "mire_leech"], "backdrop": {"15": "room_a_nave_15x15", "12": "room_a_nave_12x12"}},
                "b": {"name": "The Mire Abbess's sanctum (boss)", "floor": ["sanctum_floor_a", "sanctum_floor_b", "sanctum_floor_c"], "pad": "candle_pad", "pad_glow": "candle_pad_glow",
                      "props": [p for p in ("altar", "fallen_bell", "candle_stand", "coffin", "floating_coffin", "saint_statue", "candle_cluster", "gnarled_roots", "broken_pillar") if p in props],
                      "decals": ["rune_circle", "lily_pads"],
                      "decal_note": ("the rune circle is a walkable 5x5 floor decal (the design's ring is ~4.2 tile widths across, a top-down circle of ~6 cells; "
                                     "5x5 as the room layout asks): its outer ring and glyph band run through the 16 border cells and the cross sits on the centre cell. "
                                     "The inner 3x3 cells are the room's pads: draw the plain sanctum floor there (not candle_pad, the circle is the pad art) and "
                                     "add candle_pad_glow on those 9 cells"),
                      "monsters": ["mire_abbess", "bog_dead", "mire_leech"],
                      "backdrop": {"15": "room_b_sanctum_15x15", "12": "room_b_sanctum_12x12"}},
            },
            "mock": "_mock/rooms_mock.png",
        },
        "monsters": monsters,
        "projectiles": base_proj,
        "star5": {
            "rule": ("at star-5 difficulty the Drowned Abbey boss is the Bell Wraith (replaces mire_abbess), the Abbess risen as a ghost from the fallen abbey bell; "
                     "room A's monsters may be bellbound_bog_dead and bellbound_mire_leech. The star-5 projectile (gravebound_bile) and hazard (grasping_mire) "
                     "keep their first-pass ids and are recoloured to the bell's green ghost-light"),
            "monsters": star5_monsters,
            "board": {"decals": s5["decals"], "glows": s5["glows"]},
            "projectiles": star5_proj,
            "turnaround": "_mock/bell_wraith_turnaround.png",
            "contact_sheets": ["_mock/star5_bell_wraith_contact.png", "_mock/star5_bellbound_bog_dead_contact.png",
                               "_mock/star5_bellbound_mire_leech_contact.png"],
        },
        "files": mk.files,
        "build": "python3 build_tools/dungeons/build_abbey_town.py; python3 build_tools/dungeons/build_abbey_board.py; python3 build_tools/dungeons/build_abbey_fx.py; python3 build_tools/dungeons/abbey_monsters.py; python3 build_tools/dungeons/abbey_monsters.py bell_wraith bellbound_bog_dead bellbound_mire_leech; python3 build_tools/dungeons/build_abbey_manifest.py; python3 build_tools/dungeons/mock_rooms.py drowned_abbey [--star5]; python3 build_tools/dungeons/mock_town.py drowned_abbey; python3 build_tools/dungeons/mock_turnarounds.py --dungeon drowned_abbey; python3 build_tools/dungeons/mock_monsters.py --dungeon drowned_abbey --clip <out.mp4> --clip5 <out_star5.mp4>",
    }
    gkit.write_json(os.path.join(gkit.OUT, "manifest.json"), man)
    missing, extra = mk.check()
    if missing or extra:
        raise SystemExit("manifest does not match the files on disk")
    return man


if __name__ == "__main__":
    main()
