#!/usr/bin/env python3
"""Build data/world/rewards.json (format_version 2).

The set parts are the mobile gear ladder (backend/pc_gear.gd, ported from
origin/mobile backend/gear_bag.gd). This file keeps the PC layers: Crypto
Coins, carry rules, the Mystery Box, the loose items (extras, epics, relics),
the dungeon rows and their star_drops, and the PC mapping of the mobile chest
onto PC sources. Mauro, 11 Oct 2026: "Ok entonces utiliza los de mobil" and
"Sí, como en el móvil".
"""

import json
from pathlib import Path

GEAR_SLOTS = ["weapon", "head", "chest", "legs", "boots"]

# (id, display name, zone id, set name, class tier, coin level, extras, title)
DUNGEONS = [
    ("old_granary_cellar", "Old Granary Cellar", "crosshaven_heart", "Ratcatcher", 1, 1,
     [("granary_bread", "Granary Bread", "recipe"), ("sackcloth", "Sackcloth", "material"),
      ("old_grain_barrel", "Old Grain Barrel", "decoration"),
      ("millstone_stew", "Millstone Stew", "recipe"), ("gear_cog", "Gear Cog", "material"),
      ("water_wheel_model", "Water Wheel model", "decoration")], "Cellar Sweeper"),
    ("rotting_orchard_barrow", "Rotting Orchard Barrow", "rowanvale", "Orchard Warden", 10, 10,
     [("blight_free_cider", "Blight-free Cider", "recipe"), ("grave_apple", "Grave Apple", "material"),
      ("barrow_lantern", "Barrow Lantern", "decoration")], "Orchard Keeper"),
    ("frostspire_archive", "Frostspire Archive", "windmere", "Pale Archivist", 10, 15,
     [("frost_tonic", "Frost Tonic", "recipe"), ("rime_ink", "Rime Ink", "material"),
      ("frozen_bookshelf", "Frozen Bookshelf", "decoration")], "Archivist"),
    ("saltmaw_grotto", "Saltmaw Grotto", "brinewake", "Saltmaw", 20, 20,
     [("reef_chowder", "Reef Chowder", "recipe"), ("pearl_shell", "Pearl Shell", "material"),
      ("ship_in_a_bottle", "Ship in a Bottle", "decoration")], "Grotto Diver"),
    ("cinderforge_depths", "Cinderforge Depths", "slagcrown", "Ember Smith", 20, 25,
     [("cinder_draught", "Cinder Draught", "recipe"), ("ember_ore", "Ember Ore", "material"),
      ("anvil", "Anvil", "decoration")], "Forgeborn"),
    ("sunken_mill", "Sunken Mill", "eastmarch_fen_edge", "Millwheel Hag", 20, 25,
     [("fen_broth", "Fen Broth", "recipe"), ("bog_iron", "Bog Iron", "material"),
      ("rusted_millwheel", "Rusted Millwheel", "decoration")], "Fenwalker"),
    ("drowned_abbey", "Drowned Abbey", "gloomfen_mire", "Mire Abbess", 30, 30,
     [("swamp_elixir", "Swamp Elixir", "recipe"), ("abbey_candle_wax", "Abbey Candle Wax", "material"),
      ("sunken_bell", "Sunken Bell", "decoration")], "Bog Pilgrim"),
    ("thunderwell_core", "Thunderwell Core", "stormspire", "Storm Engine", 30, 35,
     [("charged_tonic", "Charged Tonic", "recipe"), ("storm_coil", "Storm Coil", "material"),
      ("tesla_lamp", "Tesla Lamp", "decoration")], "Spark Tamer"),
    ("shard_hollow", "Shard Hollow", "ashen_shardfields", "Ashen Prism", 40, 40,
     [("crystal_brew", "Crystal Brew", "recipe"), ("prism_shard", "Prism Shard", "material"),
      ("glowing_crystal", "Glowing Crystal", "decoration")], "Shardbreaker"),
    ("heart_of_the_blight", "Heart of the Blight", "blightwood_hollow", "Rotting Elder", 40, 40,
     [("elderroot_feast", "Elderroot Feast", "recipe"), ("blight_heartwood", "Blight Heartwood", "material"),
      ("blight_seedling", "Blight Seedling", "decoration")], "Blightbane"),
]

EPICS = [
    ("gale_signet", "Gale Signet", "ring", 40, "+1 MP, + Swift"),
    ("abbess_rosary", "Abbess's Rosary", "amulet", 40, "+8% healing done, + Resist"),
    ("ember_crown", "Ember Crown", "head", 45, "+1 range on spells with range 2 or more"),
    ("stormheart_gauntlet", "Stormheart Gauntlet", "weapon", 45,
     "Your first hit each turn also deals 4 Air damage to one enemy next to the target"),
    ("prism_striders", "Prism Striders", "boots", 50,
     "+1 MP. The first 3 push attempts on you in a fight work normally; after that you can't be pushed for the rest of the fight"),
]
RELICS = [
    ("heart_of_the_elder", "Heart of the Elder", "amulet", "+1 AP, -10% max HP"),
    ("crown_of_crosshaven", "Crown of Crosshaven", "head",
     "+1 AP and +1 MP for your first 2 turns of each fight"),
    ("blightroot_ring", "Blightroot Ring", "ring",
     "No AP. Your hits poison: 3 damage at the start of the target's turn for 2 turns, stacking up to 3"),
]

STAR_DROPS = {
    "drowned_abbey": {
        "status": "proposed",
        "note": "The Abbess's Rosary drops only at ★5. Mauro, 11 Oct 2026: \"Si a todo\".",
        "groups": [
            {"id": "epic", "max_per_run": 1, "above_run_level": "drop", "pools": [
                {"items": ["abbess_rosary"], "chance_by_stars": {"5": 0.15}},
            ]},
        ],
    },
    "heart_of_the_blight": {
        "status": "proposed",
        "note": "Epics at ★4 and ★5, relics and Prism Striders at ★5 only. Crown of Crosshaven has no source (Open). Mauro, 11 Oct 2026: \"Si a todo\".",
        "groups": [
            {"id": "epic", "max_per_run": 1, "above_run_level": "drop", "pools": [
                {"items": ["gale_signet", "ember_crown", "stormheart_gauntlet"], "chance_by_stars": {"4": 0.10, "5": 0.20}},
                {"items": ["prism_striders"], "chance_by_stars": {"5": 0.05}},
            ]},
            {"id": "relic", "max_per_run": 1, "above_run_level": "drop", "pools": [
                {"items": ["heart_of_the_elder"], "chance_by_stars": {"5": 0.05}},
                {"items": ["blightroot_ring"], "chance_by_stars": {"5": 0.05}},
            ]},
        ],
    },
}
SOURCED = {item_id for row in STAR_DROPS.values() for group in row["groups"]
           for pool in group["pools"] for item_id in pool.get("items", [])}

# The old level-tier sets (format_version 1, 43 sets, slots head / cape /
# belt / boots / amulet). A saved part "<set>_<slot>" is migrated on load to
# an Ashmantle piece in the mapped slot (Ashmantle fits every class). An old
# Rare part becomes that piece at +1 (two +0 copies fused).
LEGACY_SLOT_MAP = {"head": "head", "cape": "chest", "belt": "legs", "boots": "boots", "amulet": "weapon"}
LEGACY_SETS = [
    "kestrel_fledgling", "kestrel_windrunner", "kestrel_skyfeather", "kestrel_stormquill",
    "kestrel_galecrest", "kestrel_zenith_talon", "ironjaw_quarryhand", "ironjaw_stonefist",
    "ironjaw_quarrybreaker", "ironjaw_ironclad_ram", "ironjaw_mountainmaw", "ironjaw_titans_jaw",
    "mender_dewdrop", "mender_brookmender", "mender_tidewell", "mender_riverheart",
    "mender_deepspring", "mender_oceansong", "gloam_shadowstep", "gloam_nightcloak",
    "gloam_duskveil", "gloam_umbral_fang", "gloam_voidshroud", "gloam_eclipse",
    "bastion_watchpost", "bastion_shieldwall", "bastion_bulwark", "bastion_ironbastion",
    "bastion_rampart_lord", "bastion_aegis_eternal", "wayfarer", "townguard", "ratcatcher",
    "millwright", "orchard_warden", "pale_archivist", "saltmaw", "ember_smith",
    "millwheel_hag", "mire_abbess", "storm_engine", "ashen_prism", "rotting_elder",
]


def loose_item(item_id: str, name: str, category: str, weight: int, stack: bool, **extra) -> dict:
    row = {
        "id": item_id,
        "name": name,
        "category": category,
        "weight": weight,
        "stack": stack,
        "slot": extra.get("slot", ""),
        "min_level": extra.get("min_level", 1),
        "classes": extra.get("classes", []),
        "rarity": extra.get("rarity", ""),
        "set_id": "",
        "drop": extra.get("drop", "Open"),
        "effect": extra.get("effect", {"applies": False, "text": ""}),
    }
    return row




def main() -> None:
    items = []
    dungeons = []
    for dung_id, dung_name, zone_id, _set_name, _class_tier, coin_level, extras, title in DUNGEONS:
        extra_ids = []
        for item_id, item_name, category in extras:
            weight = 20 if category == "decoration" else (0 if category == "recipe" else 1)
            items.append(loose_item(item_id, item_name, category, weight, True))
            extra_ids.append(item_id)
        row = {
            "id": dung_id,
            "name": dung_name,
            "zone_id": zone_id,
            "coin_level": coin_level,
            "title": title,
            "extras": extra_ids,
        }
        if dung_id in STAR_DROPS:
            row["star_drops"] = STAR_DROPS[dung_id]
        dungeons.append(row)

    items.append(loose_item(
        "plain_band", "Plain Band", "equipment", 10, False,
        slot="ring", min_level=1, rarity="regular",
    ))
    items.append(loose_item("mystery_box", "Mystery Box", "special", 1, True, drop="rolled"))
    for item_id, name, slot, level, text in EPICS:
        items.append(loose_item(
            item_id, name, "equipment", 15, False,
            slot=slot, min_level=level, rarity="epic",
            drop="rolled" if item_id in SOURCED else "Open",
            effect={"applies": False, "text": text},
        ))
    for item_id, name, slot, text in RELICS:
        items.append(loose_item(
            item_id, name, "equipment", 15, False,
            slot=slot, min_level=50, rarity="relic",
            drop="rolled" if item_id in SOURCED else "Open",
            effect={"applies": False, "text": text},
        ))

    doc = {
        "format": "stasium.world_rewards",
        "format_version": 2,
        "status": "proposed",
        "notes": [
            "Set parts are the mobile gear ladder: 22 sets in backend/pc_gear.gd (origin/mobile 7035f8f backend/gear_bag.gd), slots weapon, head, chest, legs, boots. Item ids are mobile's, <set>.<slot>. Mauro, 11 Oct 2026: \"Ok entonces utiliza los de mobil\".",
            "Dungeon win: one gear chest, at the boss (room B), one piece at +0, rolled on the chosen star's tier row: ★1-2 all Normal, ★3-4 70 / 30 Normal / Rare, ★5 60 / 30 / 10 Normal / Rare / Legendary. The chest rolls a tier, then a set of that tier at equal odds, then a slot (weapon 18%, each other slot 20.5%). No daily clear cap on PC (mobile caps Stasis chests at 5 clears a day). Mauro, 12 Oct 2026: \"Un cofre\", \"Sin límite\"; earlier \"Sí, como en el móvil\".",
            "World fights (Proposed): world_chance per win of one Normal-tier piece (Ashmantle and the five class Normal sets at equal odds), through pc_gear.roll_world_drop(zone_level, rng). 0.08 is sized so a hero on the normal mix (about 14 world wins a level, so about 140 a 10-level band) finds about 11 Normal pieces a band, about 4 of them for its own class or Ashmantle, which covers about 3 slots. The open-world zone monsters that will pay these drops are a later package. Mauro, 12 Oct 2026: \"Para eso tiene que haber mobs en el openworld… debe de haber zonas de lvl\". Missions (Proposed): the rank's regular share is a Normal-tier piece, its rare share a Rare-tier piece (the five class Rare sets). The Mystery Box part rows map the same way.",
            "Ultra sets (Gatewarden, Sandhawk, Pitmaw, Hushring, Mercywell) never drop. Source koliseo_shop, 30 Koliseo coins per piece. PC has no Koliseo shop or Koliseo wallet yet (Open).",
            "Class sets fit only their class; Ashmantle and Brightedge fit any class. Drops are uniform over sets, so a hero receives other classes' pieces. Selling and trading are not built (the Trader NPCs say the shop is not open).",
            "Epics, relics, the Mystery Box and star_drops are a separate layer and roll as before. The ★5 Mystery Box stays guaranteed. The ★5 guaranteed Rare part and the old Rare-part roll are retired: the chests carry the tiers now. The blight's tier-50 Rotting Elder pool is gone with the old sets.",
            "Coins and XP are unchanged.",
            "legacy_gear: a saved part of an old set migrates on load to the Ashmantle piece of the mapped slot, at +0, or +1 for an old Rare part. A worn part stays worn in the new slot when it is free.",
            "Unique extras have drop Open, so the roller does not grant them. Epics and Relics drop only through a dungeon row's star_drops (drop rolled); Crown of Crosshaven keeps drop Open.",
            "star_drops (Proposed): one draw per group, so a group gives at most one item a run. A pool's chance is per win at that star; pools at the same star add up. above_run_level drop: an item above the run level still drops and waits in the bag until the hero can wear it. skip: it does not drop.",
            "Mystery Box weight is 1, the consumable weight. Decoration weight uses the stated floor of 20.",
        ],
        "coins": {
            "world_base": 3,
            "world_per_level": 1.5,
            "dungeon_times_world": 8,
            "mission_tiers": [
                {"level_min": 1, "level_max": 10, "min": 20, "max": 40},
                {"level_min": 11, "level_max": 20, "min": 60, "max": 100},
                {"level_min": 21, "level_max": 30, "min": 150, "max": 250},
                {"level_min": 31, "level_max": 40, "min": 300, "max": 500},
                {"level_min": 41, "level_max": 50, "min": 600, "max": 1000},
            ],
            "box_times_mission": 5,
        },
        "carry": {
            "bag_slots": 60,
            "bank_slots": 20,
            "weight_base": 1000,
            "weight_per_level": 5,
        },
        "weights": {
            "recipe": 0,
            "material": 1,
            "consumable": 1,
            "equipment": 10,
            "epic": 15,
            "relic": 15,
            "decoration": 20,
            "special": 1,
        },
        "classes": ["Kestrel", "Ironjaw", "Mender", "Gloam", "Bastion"],
        "gear_slots": GEAR_SLOTS,
        "equip_slots": GEAR_SLOTS + ["amulet", "ring", "ring_b"],
        "gear": {
            "source": "res://backend/pc_gear.gd",
            "dungeon_chests": [
                {"room": "b", "row": "star"},
            ],
            "daily_clear_cap": None,
            "world_chance": 0.08,
            "world_band_levels": 10,
            "world_tier": "Normal",
            "mission_tiers": {"regular": "Normal", "rare": "Rare"},
            "box_tiers": {"regular": "Normal", "rare": "Rare"},
            "star5_box": True,
            "ultra": {"source": "koliseo_shop", "cost": 30, "currency": "koliseo_coins", "shop_built": False},
        },
        "legacy_gear": {
            "to_set": "ashmantle",
            "slot_map": LEGACY_SLOT_MAP,
            "rare_plus": 1,
            "sets": LEGACY_SETS,
        },
        "rarity_colors": {
            "regular": "white",
            "normal": "white",
            "rare": "blue",
            "legendary": "orange",
            "ultra": "red",
            "epic": "purple",
            "relic": "gold",
        },
        "mission_ranks": [
            {"rank": 1, "finished_min": 0, "finished_max": 9, "regular": 0.20, "rare": 0, "box": 0},
            {"rank": 2, "finished_min": 10, "finished_max": 24, "regular": 0.35, "rare": 0, "box": 0.03},
            {"rank": 3, "finished_min": 25, "finished_max": 49, "regular": 0.40, "rare": 0.05, "box": 0.08},
            {"rank": 4, "finished_min": 50, "finished_max": 99, "regular": 0.40, "rare": 0.10, "box": 0.12},
            {"rank": 5, "finished_min": 100, "finished_max": -1, "regular": 0.35, "rare": 0.15, "box": 0.20},
        ],
        "box": [
            {"kind": "coins", "chance": 0.50},
            {"kind": "part", "rarity": "regular", "chance": 0.35},
            {"kind": "part", "rarity": "rare", "chance": 0.15},
        ],
        "dungeon_box_by_stars": {"1": 0, "2": 0, "3": 0, "4": 0.10, "5": 0.10},
        "items": items,
        "dungeons": dungeons,
    }
    path = Path(__file__).with_name("rewards.json")
    path.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("wrote %s items=%d dungeons=%d" % (path.name, len(items), len(dungeons)))


if __name__ == "__main__":
    main()
