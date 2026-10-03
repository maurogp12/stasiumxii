#!/usr/bin/env python3
"""Build data/world/rewards.json from the WP14 tables in the zones spec.

Numbers that the spec states are written as stated. Splits the spec leaves
unweighted are even, and those rows are listed in the file's notes.
"""

import json
from pathlib import Path

STATS = ["Mastery", "Vitality", "Swift", "Resist"]
SET_SLOTS = ["head", "cape", "belt", "boots", "amulet"]
SLOT_LABEL = {
    "head": "Head",
    "cape": "Cape",
    "belt": "Belt",
    "boots": "Boots",
    "amulet": "Amulet",
    "ring": "Ring",
    "weapon": "Weapon",
}

CLASS_LEANS = {
    "kestrel": ["Mastery", "Swift"],
    "ironjaw": ["Mastery", "Vitality"],
    "mender": ["Vitality", "Resist"],
    "gloam": ["Mastery", "Swift"],
    "bastion": ["Vitality", "Resist"],
}
CLASS_NAME = {
    "kestrel": "Kestrel",
    "ironjaw": "Ironjaw",
    "mender": "Mender",
    "gloam": "Gloam",
    "bastion": "Bastion",
}
CLASS_SETS = {
    "kestrel": ["Fledgling", "Windrunner", "Skyfeather", "Stormquill", "Galecrest", "Zenith Talon"],
    "ironjaw": ["Quarryhand", "Stonefist", "Quarrybreaker", "Ironclad Ram", "Mountainmaw", "Titan's Jaw"],
    "mender": ["Dewdrop", "Brookmender", "Tidewell", "Riverheart", "Deepspring", "Oceansong"],
    "gloam": ["Shadowstep", "Nightcloak", "Duskveil", "Umbral Fang", "Voidshroud", "Eclipse"],
    "bastion": ["Watchpost", "Shieldwall", "Bulwark", "Ironbastion", "Rampart Lord", "Aegis Eternal"],
}
TIERS = [1, 10, 20, 30, 40, 50]
SIGNATURE = {
    "kestrel": "+1 max range on Mark Shot",
    "ironjaw": "Start every fight with +1 Impact",
    "mender": "Mend heals +2 and Pulse Tap heals +1",
    "gloam": "+1 MP on turns you start Invisible",
    "bastion": "The first hit you take in each fight deals half damage",
}

# (id, display name, zone id, set name, class tier, coin level, extras, title)
DUNGEONS = [
    ("old_granary_cellar", "Old Granary Cellar", "crosshaven_heart", "Ratcatcher", 1, 1,
     [("granary_bread", "Granary Bread", "recipe"), ("sackcloth", "Sackcloth", "material"),
      ("old_grain_barrel", "Old Grain Barrel", "decoration")], "Cellar Sweeper"),
    ("millrace_vaults", "Millrace Vaults", "crosshaven_towns", "Millwright", 1, 8,
     [("millstone_stew", "Millstone Stew", "recipe"), ("gear_cog", "Gear Cog", "material"),
      ("water_wheel_model", "Water Wheel model", "decoration")], "Millwright"),
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
    ("heart_of_the_blight", "Heart of the Blight", "blightwood_hollow", "Rotting Elder", 50, 50,
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

ZONE_CLASS = {
    "rowanvale": 10,
    "windmere": 10,
    "brinewake": 20,
    "slagcrown": 20,
    "eastmarch_fen_edge": 20,
    "gloomfen_mire": 30,
    "stormspire": 30,
    "ashen_shardfields": 40,
    "blightwood_hollow": 50,
}


def round_half_away(value: float) -> int:
    if value >= 0:
        return int(value + 0.5)
    return int(value - 0.5)


def slug(name: str) -> str:
    return name.lower().replace("'", "").replace(" ", "_")


def split(total: int, leans: list) -> dict:
    base, rem = divmod(total, len(leans))
    out = {}
    for i, stat in enumerate(leans):
        points = base + (1 if i < rem else 0)
        if points:
            out[stat] = points
    return out


def full_budget(tier: int) -> int:
    # B(T) = round(98 × 1.3^((T − 50) / 10)). Half away from zero, matching Godot round().
    return round_half_away(98 * (1.3 ** ((tier - 50) / 10.0)))


def allocate(full: int, leans: list) -> tuple:
    """Whole stat points whose full set (5 parts + 2-part + 3-part) equals B(T).

    One part and the 2-part bonus share the same split. The 3-part line takes
    the remainder so the total is exactly B(T), not merely near it.
    """
    part_target = full / 7.5
    three_target = full / 5.0
    best = None
    for part_points in range(0, full + 1):
        three_points = full - 6 * part_points
        if three_points < 0:
            continue
        score = abs(part_points - part_target) + abs(three_points - three_target)
        row = (score, part_points, three_points)
        if best is None or row < best:
            best = row
    _score, part_points, three_points = best
    part = split(part_points, leans)
    return part, dict(part), split(three_points, leans)


def leans_for(class_id: str, tier: int) -> list:
    if class_id == "gloam" and tier >= 30:
        return ["Swift", "Resist"]
    return list(CLASS_LEANS[class_id])


def rare_stats(budget: int, leans: list) -> dict:
    stats = split(round_half_away(1.5 * budget), leans)
    for stat in STATS:
        if stat not in leans:
            stats[stat] = stats.get(stat, 0) + 1
            return stats
    # Shared and dungeon parts already list all four stats, so the extra
    # point lands on Mastery.
    stats[STATS[0]] = stats.get(STATS[0], 0) + 1
    return stats


def five_part(text: str) -> dict:
    return {"applies": False, "text": text}


def make_set(set_id: str, name: str, tier: int, kind: str, classes: list, leans: list, five_text: str) -> dict:
    full = full_budget(tier)
    regular, bonus_two, bonus_three = allocate(full, leans)
    budget = sum(regular.values())
    parts = []
    for slot in SET_SLOTS:
        parts.append({
            "id": "%s_%s" % (set_id, slot),
            "slot": slot,
            "name": "%s %s" % (name, SLOT_LABEL[slot]),
        })
    return {
        "id": set_id,
        "name": name,
        "tier": tier,
        "kind": kind,
        "classes": classes,
        "leans": leans,
        "budget": budget,
        "full_budget": full,
        "stats": {
            "regular": regular,
            "rare": rare_stats(budget, leans),
        },
        "bonuses": {
            "2": bonus_two,
            "3": bonus_three,
            "5": five_part(five_text),
        },
        "parts": parts,
    }


def class_five(class_id: str, tier: int) -> str:
    if tier < 20:
        return "Plain stat bonus at five parts. Not applied yet."
    text = SIGNATURE[class_id]
    if tier > 20:
        text += " The later-tier addition is not built yet."
    return text


def shared_row(kind: str, set_id: str) -> dict:
    return {"kind": kind, "set_id": set_id, "weight": 1}


def class_row(tier: int) -> dict:
    return {"kind": "class", "tier": tier, "weight": 1}


def zone_block(world: list, mission: list) -> dict:
    return {"world": world, "mission": mission}


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
    sets = []
    for class_id, names in CLASS_SETS.items():
        for tier, name in zip(TIERS, names):
            leans = leans_for(class_id, tier)
            sets.append(make_set(
                "%s_%s" % (class_id, slug(name)),
                name,
                tier,
                "class",
                [CLASS_NAME[class_id]],
                leans,
                class_five(class_id, tier),
            ))
    sets.append(make_set(
        "wayfarer", "Wayfarer", 1, "shared", [], list(STATS),
        "+1 MP on the first turn of a fight",
    ))
    sets.append(make_set(
        "townguard", "Townguard", 5, "shared", [], list(STATS),
        "Extra Resist when standing next to an ally",
    ))

    items = []
    dungeons = []
    for dung_id, dung_name, zone_id, set_name, class_tier, coin_level, extras, title in DUNGEONS:
        set_id = slug(set_name)
        if set_id == "millwright":
            five = "Extra Mastery on the turn after you are hit"
        else:
            five = "Open"
        sets.append(make_set(set_id, set_name, coin_level, "dungeon", [], list(STATS), five))
        extra_ids = []
        for item_id, item_name, category in extras:
            weight = 20 if category == "decoration" else (0 if category == "recipe" else 1)
            items.append(loose_item(item_id, item_name, category, weight, True))
            extra_ids.append(item_id)
        dungeons.append({
            "id": dung_id,
            "name": dung_name,
            "zone_id": zone_id,
            "set_id": set_id,
            "class_tier": class_tier,
            "coin_level": coin_level,
            "title": title,
            "extras": extra_ids,
        })

    items.append(loose_item(
        "plain_band", "Plain Band", "equipment", 10, False,
        slot="ring", min_level=1, rarity="regular",
    ))
    items.append(loose_item("mystery_box", "Mystery Box", "special", 1, True, drop="rolled"))
    for item_id, name, slot, level, text in EPICS:
        items.append(loose_item(
            item_id, name, "equipment", 15, False,
            slot=slot, min_level=level, rarity="epic",
            effect={"applies": False, "text": text},
        ))
    for item_id, name, slot, text in RELICS:
        items.append(loose_item(
            item_id, name, "equipment", 15, False,
            slot=slot, min_level=50, rarity="relic",
            effect={"applies": False, "text": text},
        ))

    zones = {
        "crosshaven_heart": zone_block(
            [shared_row("shared", "wayfarer")],
            [shared_row("shared", "wayfarer"), class_row(1)],
        ),
        "crosshaven_towns": zone_block(
            [shared_row("shared", "townguard")],
            [shared_row("shared", "townguard")],
        ),
    }
    for zone_id, tier in ZONE_CLASS.items():
        zones[zone_id] = zone_block([class_row(tier)], [class_row(tier)])

    doc = {
        "format": "stasium.world_rewards",
        "format_version": 1,
        "status": "proposed",
        "notes": [
            "A dungeon win's guaranteed part is an even split between that dungeon's own set and a class set of its tier. Section 4.9 names both and does not weight them.",
            "Heart missions split evenly between Wayfarer and a tier-1 class set. Both are named sources.",
            "Crosshaven world fights drop the shared set for that half of the city. Other regions drop a class set of the region's tier.",
            "Millrace, Frostspire, Cinderforge and Sunken Mill drop the class tier just below the top of their zone band. Thunderwell Core is named with the tier-30 sources.",
            "Unique extras, Epics and Relics have drop Open, so the roller does not grant them.",
            "A full set (5 parts + the 2-part bonus + the 3-part bonus) is worth B(T) = round(98 × 1.3^((T-50)/10)), half away from zero. One part and the 2-part bonus are the same split. The 3-part line takes the remainder so the total equals B(T). budget is the one-part point total; full_budget is B(T).",
            "A Rare part is 1.5 times that one-part total, rounded half away from zero, plus one point in the first of Mastery, Vitality, Swift, Resist that the part does not already lean to. Shared and dungeon parts already list all four, so that point goes to Mastery.",
            "Shared and dungeon parts split across all four stats. Class parts split across the two stats that class leans to. Gloam tiers 30 and up lean Swift and Resist.",
            "Five-part texts are stored and not applied. The full Rare tier-30 class set's AP or MP choice is applied, because that choice is already approved.",
            "Mystery Box weight is 1, the consumable weight. Decoration weight uses the stated floor of 20.",
            "The first AP or MP choice on a full Rare tier-30 class set is free. Switching the choice costs Crypto Coins, and that price is Open.",
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
        "class_bias": 0.6,
        "world_part_chance": 0.03,
        "classes": ["Kestrel", "Ironjaw", "Mender", "Gloam", "Bastion"],
        "set_slots": SET_SLOTS,
        "equip_slots": ["head", "amulet", "ring", "ring_b", "cape", "belt", "boots", "weapon"],
        "rare_full": {"tier": 30, "ap": 1, "mp": 1},
        "rarity_colors": {
            "regular": "white",
            "rare": "blue",
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
        "dungeon_rare_by_stars": {"1": 0, "2": 0.05, "3": 0.10, "4": 0.20, "5": 0.35},
        "dungeon_box_by_stars": {"1": 0, "2": 0, "3": 0, "4": 0.10, "5": 0.10},
        "guaranteed_split": {"dungeon_set": 0.5, "class_set": 0.5},
        "sets": sets,
        "items": items,
        "zones": zones,
        "dungeons": dungeons,
    }
    path = Path(__file__).with_name("rewards.json")
    path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    print("wrote %s sets=%d items=%d" % (path.name, len(sets), len(items)))


if __name__ == "__main__":
    main()
