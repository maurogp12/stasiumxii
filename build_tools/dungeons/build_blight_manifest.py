"""Write art/pc/dungeons/heart_of_the_blight/manifest.json (format stasium.dungeon_art v1, the same keys as the Granary's,
the Frostspire Archive's, the Saltmaw Grotto's and the Drowned Abbey's): every shipped file with its kind, size,
pivot/anchor, footprint or cell, frame counts and fps.

Run after build_blight_town.py, build_blight_board.py, build_blight_fx.py and blight_monsters.py. A monster whose
meta.json is not built yet gets a "status": "pending" entry with its planned cell, pivot and frame counts.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import build_blight_board as board  # noqa: E402
import build_blight_fx as fx  # noqa: E402
import manifest_kit  # noqa: E402

FPS = 17.144
BASE_ACTS = {"idle": 12, "walk": 12, "attack": 12, "hit": 8, "death": 13}
LOOP = {"idle": True, "walk": True}
CRYSTAL_GLOW_WHAT = "the violet crystal faces (heart, shoulders, spikes, claws, face) bloomed + faint violet aura"
PLAN = {
    "blight_hound": ("Blight Hound", False, (512, 360), (256, 329), {}),
    "blight_horror": ("Blight Horror", False, (512, 360), (256, 329), {}),
    "rotting_elder": ("The Rotting Elder", False, (768, 540), (384, 494), {"summon": 14}),
    "crystal_colossus": ("The Crystal Colossus", True, (768, 540), (384, 494), {"summon": 14}),
    "crystal_hound": ("Crystal Hound", True, (512, 360), (256, 329), {}),
    "crystal_horror": ("Crystal Horror", True, (512, 360), (256, 329), {}),
}
SIG = {"action": "summon", "name": "Root Wall",
       "note": ("he lifts the staff while the crystal heart dims (f00-f02); staff high, the heart flares violet and the roots writhe at his feet "
                "(f03-f06); on f07 he drives the staff into the floor and the wall fires: spawn root_wall (rise strip) on each wall cell and "
                "draw a board/projectiles/root_crack from staff_point's floor spot to each wall cell; shockwave ripple f08-f10; he settles "
                "f11-f13. The strip name stays 'summon' (14 frames)"),
       "frames": {"lift": [0, 2], "charge": [3, 6], "fire": 7, "shockwave": [8, 10], "settle": [11, 13]}}
BIG_NOTE = ("1.5x the hero height: 768x540 cell, pivot (384,494) = the hero cell scaled 1.5x. "
            "Draw it exactly like a hero cell at the same sprite scale, but so that pixel (384,494) lands where a hero's (256,329) lands: "
            "for a centred Sprite2D, offset_boss = offset_hero + (0, (540-360)/2 - (494-329)) = offset_hero - (0, 75) (before scale).")
MELEE_NOTE = "melee: the attack connects on f06 (play the hit reaction / damage number there)"
RANGED = ("room A ranged: a gaunt root figure with a glowing violet face; attack = it rears back with its arms spread (f01-f06), then snaps "
          "forward and spits a spore bolt from its face on the release frame, projectile board/projectiles/spore_bolt, "
          "board/projectiles/spore_impact on hit")
STAFF_NOTE = ("the staff foot on the signature's fire frame (f07), per facing, in cell pixels (same space as the pivot); mirror x about the "
              "cell centre for the mirrored facings. The root_cracks start here (on the floor) and run to each wall cell")


def pending(mid):
    name, star, cell, piv, extra = PLAN[mid]
    d = ("star5/monsters/" if star else "monsters/") + mid
    acts = dict(BASE_ACTS, **extra)
    e = {"id": mid, "name": name, "dir": d, "cell": list(cell), "pivot": list(piv), "fps": FPS, "status": "pending",
         "actions": {a: {"frames": n, "loop": LOOP.get(a, False), "fps": FPS, "duration_s": round(n / FPS, 3),
                         "pattern": "%s/%s/%s_{S,E}_f{00..%02d}.png" % (d, a, a, n - 1)} for a, n in acts.items()}}
    if star:
        e["star"] = 5
    if mid in ("blight_horror", "crystal_horror"):
        e["release"] = {"action": "attack", "frame": 7, "point_px": "pending"}
    if mid in ("rotting_elder", "crystal_colossus"):
        e["staff_point"] = {"action": "summon", "frame": 7, "point_px": "pending"}
    return e


def wall_files(add, w):
    for two, sub in ((False, ""), (True, "_2x/")):
        sc = 0.5 if two else 1.0
        add(w["file_2x" if two else "file"], "board_prop", footprint=[1, 1], scale=sc, master="2x" if two else "1x", star=w["star"])
        add(w["glow_2x" if two else "glow"], "glow_add", for_id=w["id"], scale=sc, master="2x" if two else "1x", star=w["star"])
        base = os.path.dirname(w["file"]) + "/" + w["id"] + "/" + sub
        for strip, n in (("rise", fx.RISE), ("idle", 1), ("wither", fx.WITHER)):
            for i in range(n):
                add(base + "%s_f%02d.png" % (strip, i), "prop_anim_frame", for_id=w["id"], strip=strip, frame=i, frames=n,
                    scale=sc, master="2x" if two else "1x", star=w["star"])
                add(base + "%s_f%02d_glow.png" % (strip, i), "glow_add", for_id=w["id"], strip=strip, frame=i, frames=n,
                    scale=sc, master="2x" if two else "1x", star=w["star"])


def main():
    gkit.use("heart_of_the_blight")
    meta_board = board.build()
    mk = manifest_kit.Manifest()
    add, size = mk.add, mk.size

    for sub, sc in (("", 1), ("_2x/", 2)):
        for nm, kind in (("blight_door", "building"), ("blight_door_glow", "glow_add")):
            add("town/%s%s.png" % (sub, nm), kind, scale=1.0 / sc, master="2x" if sc == 2 else "1x")
    w, h = size("town/blight_door.png")
    town_entry = {
        "id": "blight_door", "zone": "westwatch",
        "file": "town/blight_door.png", "file_2x": "town/_2x/blight_door.png",
        "hatch_glow": "town/blight_door_glow.png", "hatch_glow_2x": "town/_2x/blight_door_glow.png",
        "size": [w, h], "size_2x": size("town/_2x/blight_door.png"),
        "footprint_size": [4, 4], "footprint_from_nw": [[x, y] for y in range(4) for x in range(4)],
        "blocks": True, "anchor_cell_from_nw": [3, 3],
        "anchor": "image bottom-centre = south tip of cell origin+[3,3] (Crosshaven kit rule: draw at cell_to_local(origin+(3,3)) + (0,16) + (-w/2, -h); 2x master at scale 0.5, same placement)",
        "bottom_centre_from_nw_centre_1x": [0, 112],
        "pivot_px_1x": [w // 2, h],
        "y_sort": "z = (south cell x+y) * TILE_Z_SCALE + 2, as crosshaven_prop.gd; y-sort point = image bottom - 16 px",
        "door_cell_from_nw": [3, 4],
        "door_note": ("the hollow blighted stump's cave mouth glows violet on the front; the trodden path runs out of it to the south, over the "
                      "SW edge of the corner cell (3,3), so the passable, clickable door cell is origin+(3,4), just outside the footprint. "
                      "On crosshaven_westwatch the building is on (2..5, 9..12) (origin (2,9)), the door cell is (5,13) and the Door Keeper "
                      "NPC (body npc_door_keeper) stands at (6,13) = origin+(4,4). The painted earth is rounder than a 2:1 diamond: its front, "
                      "with the path, overhangs the footprint's south edges by up to ~45 px at 1x (it is part of the sprite)."),
        "hatch_glow_note": "the violet light in the cave mouth and the violet lantern; additive blend (CanvasItemMaterial BLEND_MODE_ADD), same canvas and anchor as the building; fade modulate 0 -> 1 on hover of the door cell or the building",
        "source_painting": "build_tools/dungeons/blight_src/town_blight.jpg",
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
        e = mk.monster(mid, glow_what=CRYSTAL_GLOW_WHAT)
        mm = json.load(open(os.path.join(mk.root, d, "meta.json")))
        if mm.get("staff_point"):
            e["staff_point"] = dict(mm["staff_point"], note=STAFF_NOTE)
        return e

    monsters = [monster(m) for m in ("blight_hound", "blight_horror", "rotting_elder")]
    monsters[0]["pawn_note"] = "Hero-format cell (512x360, pivot (256,329)): place it exactly as the hero action cells. Same for the Blight Horror."
    monsters[0]["role"] = "room A fast melee: a low, wide blighted wolf of bark, moss and thorns; a crouch and pounce-bite; " + MELEE_NOTE
    monsters[1]["role"] = RANGED
    monsters[2]["size_note"] = BIG_NOTE
    monsters[2]["signature"] = SIG
    monsters[2]["role"] = ("boss: a huge hunched treant of rotting bark and moss with an antler-branch crown, a crystal heart in its split chest and a "
                           "crystal-topped staff; attack = 'Root Claw' (range 1), the root-claw arm rakes down and across and connects on f06")

    star5_monsters = [monster(m) for m in ("crystal_colossus", "crystal_hound", "crystal_horror")]
    star5_monsters[0]["size_note"] = BIG_NOTE
    star5_monsters[0]["signature"] = SIG
    star5_monsters[0]["special"] = ("'Crystal Bloom': leaves star5/board/crystal_bloom pods that burst (crystal_bloom_burst); the rule is CombatSim's, "
                                    "the art is purely visual. Its Root Wall raises star5 crystal_wall instead of root_wall")
    star5_monsters[0]["turnaround"] = "_mock/crystal_colossus_turnaround.png"
    star5_monsters[0]["role"] = ("star-5 boss, a NEW silhouette with its own rig (Mauro's pick B): the Rotting Elder consumed by the blight crystal, a "
                                 "hulking crystal giant with a crown of crystal antlers, a crystal fist and a long crystal spear-staff; attack 'Crystal "
                                 "Lance' (range 1-2): the spear-staff thrusts forward and down, connecting on f06; summon = Root Wall with the base "
                                 "timing (fire f07, staff_point = the spear foot per facing)")
    star5_monsters[0]["placement_note"] = "same cell and pivot as rotting_elder (768x540, (384,494)); the pivot is between its feet"
    star5_monsters[2]["role"] = ("star-5 room A ranged: the Blight Horror grown through with violet crystal; it spits star5 crystal_shard (straight, "
                                 "no arc) on release f07, crystal_shard_impact on hit")

    s5 = fx.build()
    projectiles = []
    for p in s5["projectiles"]:
        st = p.get("star")
        add(p["file"], p["kind"], anchor="centre", star=st)
        add(p["file_2x"], p["kind"], anchor="centre", master="2x", scale=0.5, star=st)
        if p.get("glow"):
            add(p["glow"], "glow_add", for_id=p["id"], anchor="centre", star=st)
            add(p["glow_2x"], "glow_add", for_id=p["id"], anchor="centre", master="2x", scale=0.5, star=st)
        projectiles.append(p)
    base_proj = [p for p in projectiles if p.get("star") != 5]
    star5_proj = [p for p in projectiles if p.get("star") == 5]
    walls = {w["id"]: w for w in s5["walls"]}
    for w in s5["walls"]:
        wall_files(add, w)
    for d in s5["decals"]:
        add(d["file"], "floor_decal", footprint=d["footprint_size"], star=5)
        add(d["file_2x"], "floor_decal", footprint=d["footprint_size"], star=5, master="2x", scale=0.5)
        for i in range(fx.SWELL):
            for two, sub in ((False, ""), (True, "_2x/")):
                add("star5/board/crystal_bloom/%sswell_f%02d.png" % (sub, i), "decal_anim_frame", for_id="crystal_bloom", frame=i, frames=fx.SWELL,
                    star=5, master="2x" if two else "1x", scale=0.5 if two else 1.0)
                add("star5/board/crystal_bloom/%sswell_f%02d_glow.png" % (sub, i), "glow_add", for_id="crystal_bloom", frame=i, frames=fx.SWELL,
                    star=5, master="2x" if two else "1x", scale=0.5 if two else 1.0)
    for g in s5["glows"]:
        add(g["file"], "glow_add", for_id=g["for"], star=5)
        add(g["file_2x"], "glow_add", for_id=g["for"], star=5, master="2x", scale=0.5)
    for a in s5["anims"]:
        for i in range(a["frames"]):
            for two, sub in ((False, ""), (True, "_2x/")):
                add("star5/board/crystal_bloom_burst/%sburst_f%02d.png" % (sub, i), "area_effect_frame", for_id=a["id"], frame=i, frames=a["frames"],
                    star=5, master="2x" if two else "1x", scale=0.5 if two else 1.0)
                add("star5/board/crystal_bloom_burst/%sburst_f%02d_glow.png" % (sub, i), "glow_add", for_id=a["id"], frame=i, frames=a["frames"],
                    star=5, master="2x" if two else "1x", scale=0.5 if two else 1.0)

    props = {p["id"]: p for p in meta_board["props"]}
    board_props = meta_board["props"] + [walls["root_wall"]]
    man = {
        "format": "stasium.dungeon_art", "format_version": 1,
        "dungeon": "heart_of_the_blight", "name": "Heart of the Blight", "town": "Westwatch", "levels": [40, 50],
        "root": "res://art/pc/dungeons/heart_of_the_blight/",
        "conventions": {
            "alpha": "every PNG is binary alpha (0/255) with RGB 0 under alpha 0; glow_add files are additive (black adds nothing) and must use an add blend",
            "masters": "files under _2x/ are 2x masters: draw at scale 0.5 with the same placement as the 1x file (crosshaven_art.gd prefers _2x)",
            "grid": "64x32 diamonds; cell_to_local(x,y) = ((x-y)*32, (x+y)*16) = the diamond centre; south tip = centre + (0,16)",
            "import": "linear filter, no mipmaps, plain alpha",
            "review_only": "_mock/ has a .gdignore and is not game art",
        },
        "town_door": town_entry,
        "board": {
            "tiles": meta_board["tiles"], "glows": meta_board["glows"], "props": board_props,
            "decals": meta_board["decals"], "backdrops": meta_board["backdrops"],
            "draw_order": ["backdrop (behind everything, board hole cut out)",
                           "floor tiles (crypt_floor_* room A / heart_floor_* room B; pick variant by h(x,y,3) as the kit hash; blight_pad on pad cells)",
                           "floor decals + their glows (root_rune_circle, root_veins, ground layer; root_crack beams; star-5 crystal_bloom)",
                           "blight_pad_glow (add) on pad cells",
                           "props, root_wall / crystal_wall and units y-sorted by south-most cell (x+y); prop glows added on top of their prop",
                           "star-5 crystal_bloom_burst over units"],
            "rooms": {
                "a": {"name": "The blighted crypt (pack fight)", "floor": ["crypt_floor_a", "crypt_floor_b", "crypt_floor_c"], "pad": "blight_pad", "pad_glow": "blight_pad_glow",
                      "props": [p for p in ("root_mound", "root_knot", "violet_crystals", "bone_pile", "fungus_clump") if p in props],
                      "decals": ["root_veins"],
                      "monsters": ["blight_hound", "blight_horror"], "backdrop": {"15": "room_a_crypt_15x15", "12": "room_a_crypt_12x12"}},
                "b": {"name": "The Rotting Elder's heart chamber (boss)", "floor": ["heart_floor_a", "heart_floor_b", "heart_floor_c"], "pad": "blight_pad", "pad_glow": "blight_pad_glow",
                      "props": [p for p in ("crystal_spire", "chained_cocoon", "blight_eggs", "broken_masonry", "violet_crystals", "root_knot", "bone_pile") if p in props],
                      "decals": ["root_rune_circle", "root_veins"],
                      "decal_note": ("the root-rune circle is a walkable 5x5 floor decal. Measured on the approved boss-room design: the ring is ~3.8 tile "
                                     "widths across, a top-down circle of ~5.4 cells, so 5x5 (as the Abbey and Saltmaw circles). Its rings and glyph band run "
                                     "through the 16 border cells and the starburst sits on the centre cell. The inner 3x3 cells are the room's pads: draw the "
                                     "plain heart floor there (not blight_pad; the circle is the pad art) and add blight_pad_glow on those 9 cells"),
                      "monsters": ["rotting_elder", "blight_hound", "blight_horror"],
                      "backdrop": {"15": "room_b_heart_15x15", "12": "room_b_heart_12x12"},
                      "backdrop_note": "the pulsing heart of the blight is painted in the back corner of the shell; pulse it in-game with a violet glow sprite if wanted (it is not a separate layer)"},
            },
            "mock": "_mock/rooms_mock.png",
        },
        "monsters": monsters,
        "projectiles": base_proj,
        "star5": {
            "rule": ("at star-5 difficulty the boss is the Crystal Colossus (replaces rotting_elder; Mauro's pick B), the Rotting Elder consumed by the "
                     "blight crystal; room A's monsters may be crystal_hound and crystal_horror. The star-5 projectile is crystal_shard (+ crystal_shard_impact), "
                     "the Root Wall raises crystal_wall, and the hazard is crystal_bloom (+ crystal_bloom_burst)"),
            "monsters": star5_monsters,
            "board": {"props": [walls["crystal_wall"]], "decals": s5["decals"], "glows": s5["glows"], "anims": s5["anims"]},
            "projectiles": star5_proj,
            "turnaround": "_mock/crystal_colossus_turnaround.png",
            "contact_sheets": ["_mock/star5_crystal_colossus_contact.png", "_mock/star5_crystal_hound_contact.png", "_mock/star5_crystal_horror_contact.png"],
        },
        "files": mk.files,
        "build": ("python3 build_tools/dungeons/build_blight_town.py; python3 build_tools/dungeons/build_blight_board.py; "
                  "python3 build_tools/dungeons/build_blight_fx.py; python3 build_tools/dungeons/blight_monsters.py; "
                  "python3 build_tools/dungeons/blight_monsters.py crystal_colossus crystal_hound crystal_horror; "
                  "python3 build_tools/dungeons/build_blight_manifest.py; python3 build_tools/dungeons/mock_rooms.py heart_of_the_blight [--star5]; "
                  "python3 build_tools/dungeons/mock_town.py heart_of_the_blight; python3 build_tools/dungeons/mock_turnarounds.py --dungeon heart_of_the_blight; "
                  "python3 build_tools/dungeons/mock_monsters.py --dungeon heart_of_the_blight --clip <out.mp4> --clip5 <out_star5.mp4>"),
    }
    gkit.write_json(os.path.join(gkit.OUT, "manifest.json"), man)
    missing, extra = mk.check()
    if missing or extra:
        raise SystemExit("manifest does not match the files on disk")
    return man


if __name__ == "__main__":
    main()
