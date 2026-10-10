class_name GearBag
extends RefCounted

## Mobile gear. The old "six families only" cap is retired (Mauro, issue #333).
## Each class has Normal / Rare / Legendary sets, plus shared Ashmantle
## (Normal) and Brightedge (Legendary). Duskbrand is gone. A piece is
## class-locked to its owner's sets; Ashmantle and Brightedge fit anyone.
## Each class keeps its own equipped loadout.
## Slots: weapon, head, chest, legs, boots.
## Fuse: same item_id + same plus → plus+1, cap +5. Crit% does not fuse.
## These sets have no attune. Part resist counts against every element.
## AP/MP: base 6/3 + Legendary 5pc +1/+1 + Rare +5 weapon (+1 AP) and
## Rare +5 boots (+1 MP), clamped to 8/5. Koliseo flattens parts to +0
## (set bonuses still apply, so the +5 gates do not).
## Stasis loot: Normal from ★1, Rare from ★3, Legendary from ★5, using the
## existing "min star or below" pool. 5 clears a day; clear 6+ is empty.
## Ultra PvP sets are not in this file yet. The ladder leaves room for them.

const _TestLoadout := preload("res://backend/test_loadout.gd")
const SLOTS: Array[String] = ["weapon", "head", "chest", "legs", "boots"]
const SLOT_STAT := {
	"weapon": "Mastery", "head": "HP", "chest": "HP + resist", "legs": "resist", "boots": "Init",
}
const ELEMENTS: Array[String] = ["Air", "Earth", "Fire", "Water"]
const PLUS_CAP := 5
const ATTUNE_PIECES := 2
const BASE_AP := 6
const BASE_MP := 3
const AP_CAP := 8
const MP_CAP := 5
const CRIT_CAP := 20
const CLASS_IDS: Array[String] = ["kestrel", "ironjaw", "mender", "gloam", "bastion"]
const LOOT_CLEARS_PER_DAY := 5
## Chest size for a Stasis 1 clear. Provisional: the Blueprint does not give
## the chest size (Stasis >1 chest loot is Open).
const STASIS_1_CHEST_PIECES := 1
const SECONDS_PER_DAY := 86400

## `bonus` tiers stack. `stats` are what combat actually applies.
## `owner` "" = shared (any class). `resist_all` = part resist is not elemental.
## Point budget (1 Mastery = 1, 2 HP = 1, 1 Resist = 2, 2 Init = 1, 1% crit = 1):
## Normal ~60, Rare ~70, Legendary ~77.
const FAMILIES := {
	"ashmantle": {
		"name": "Ashmantle", "rarity": "Normal", "owner": "", "resist_all": true,
		"source": "Stasis ★1+", "min_star": 1,
		"bonus": {2: "+6% HP", 4: "+4 Mastery", 5: "+2 Init"},
		"stats": {2: {"hp_pct": 6}, 4: {"mastery": 4}, 5: {"init": 2}},
	},
	"rustward": {
		"name": "Rustward", "rarity": "Normal", "owner": "bastion", "resist_all": true,
		"source": "Stasis ★1+", "min_star": 1,
		"bonus": {2: "+8% HP", 4: "+4 Resist", 5: "First hit you take each turn deals 4 less"},
		"stats": {2: {"hp_pct": 8}, 4: {"resist": 4}, 5: {"guard_flat": 4}},
	},
	"ironveil": {
		"name": "Ironveil", "rarity": "Rare", "owner": "bastion", "resist_all": true,
		"source": "Stasis ★3+", "min_star": 3,
		"bonus": {2: "+10% HP", 4: "+6 Resist", 5: "First hit you take each turn deals 6 less"},
		"stats": {2: {"hp_pct": 10}, 4: {"resist": 6}, 5: {"guard_flat": 6}},
	},
	"oathgrave": {
		"name": "Oathgrave", "rarity": "Legendary", "owner": "bastion", "resist_all": true,
		"source": "Stasis ★5 / boss", "min_star": 5,
		"bonus": {2: "+12% HP", 4: "+6 Resist", 5: "+1 AP +1 MP. Ward shield 25 (cap 40). Start with 1 Aegis. No Aegis refund when Ward breaks."},
		"stats": {2: {"hp_pct": 12}, 4: {"resist": 6}, 5: {"ap": 1, "mp": 1, "ward_shield": 25, "start_aegis": 1}},
	},
	"undertow": {
		"name": "Undertow", "rarity": "Normal", "owner": "kestrel", "resist_all": true,
		"source": "Stasis ★1+", "min_star": 1,
		"bonus": {2: "+4 Init", 4: "+4% crit", 5: "Your first hit each turn deals +4"},
		"stats": {2: {"init": 4}, 4: {"crit": 4}, 5: {"first_hit": 4}},
	},
	"gallowsight": {
		"name": "Gallowsight", "rarity": "Rare", "owner": "kestrel", "resist_all": true,
		"source": "Stasis ★3+", "min_star": 3,
		"bonus": {2: "+4 Init", 4: "+6% crit", 5: "Your first hit each turn deals +6"},
		"stats": {2: {"init": 4}, 4: {"crit": 6}, 5: {"first_hit": 6}},
	},
	"ravenmourn": {
		"name": "Ravenmourn", "rarity": "Legendary", "owner": "kestrel", "resist_all": true,
		"source": "Stasis ★5 / boss", "min_star": 5,
		"bonus": {2: "+6 Init", 4: "+6% crit", 5: "+1 AP +1 MP"},
		"stats": {2: {"init": 6}, 4: {"crit": 6}, 5: {"ap": 1, "mp": 1}},
	},
	"cragmaw": {
		"name": "Cragmaw", "rarity": "Normal", "owner": "ironjaw", "resist_all": true,
		"source": "Stasis ★1+", "min_star": 1,
		"bonus": {2: "+8% HP", 4: "+4 Resist", 5: "Hits at range 1 deal +4"},
		"stats": {2: {"hp_pct": 8}, 4: {"resist": 4}, 5: {"melee": 4}},
	},
	"maulgrave": {
		"name": "Maulgrave", "rarity": "Rare", "owner": "ironjaw", "resist_all": true,
		"source": "Stasis ★3+", "min_star": 3,
		"bonus": {2: "+10% HP", 4: "+4 Resist", 5: "Hits at range 1 deal +6"},
		"stats": {2: {"hp_pct": 10}, 4: {"resist": 4}, 5: {"melee": 6}},
	},
	"tyrantjaw": {
		"name": "Tyrantjaw", "rarity": "Legendary", "owner": "ironjaw", "resist_all": true,
		"source": "Stasis ★5 / boss", "min_star": 5,
		"bonus": {2: "+12% HP", 4: "+4% crit", 5: "+1 AP +1 MP"},
		"stats": {2: {"hp_pct": 12}, 4: {"crit": 4}, 5: {"ap": 1, "mp": 1}},
	},
	"nightglass": {
		"name": "Nightglass", "rarity": "Normal", "owner": "gloam", "resist_all": true,
		"source": "Stasis ★1+", "min_star": 1,
		"bonus": {2: "+4 Init", 4: "+4% crit", 5: "Your first back hit each turn deals +4"},
		"stats": {2: {"init": 4}, 4: {"crit": 4}, 5: {"first_back": 4}},
	},
	"stillcut": {
		"name": "Stillcut", "rarity": "Rare", "owner": "gloam", "resist_all": true,
		"source": "Stasis ★3+", "min_star": 3,
		"bonus": {2: "+6 Init", 4: "+4% crit", 5: "Your first back hit each turn deals +6"},
		"stats": {2: {"init": 6}, 4: {"crit": 4}, 5: {"first_back": 6}},
	},
	"gravewhisper": {
		"name": "Gravewhisper", "rarity": "Legendary", "owner": "gloam", "resist_all": true,
		"source": "Stasis ★5 / boss", "min_star": 5,
		"bonus": {2: "+6 Init", 4: "Back hits deal +6% damage", 5: "+1 AP +1 MP"},
		"stats": {2: {"init": 6}, 4: {"back_pct": 6}, 5: {"ap": 1, "mp": 1}},
	},
	"vesperwell": {
		"name": "Vesperwell", "rarity": "Normal", "owner": "mender", "resist_all": true,
		"source": "Stasis ★1+", "min_star": 1,
		"bonus": {2: "+8% HP", 4: "Heals +4", 5: "+4 Resist"},
		"stats": {2: {"hp_pct": 8}, 4: {"heal_flat": 4}, 5: {"resist": 4}},
	},
	"sheaf": {
		"name": "Sheaf", "rarity": "Rare", "owner": "mender", "resist_all": true,
		"source": "Stasis ★3+", "min_star": 3,
		"bonus": {2: "+10% HP", 4: "Heals +6", 5: "+4 Resist"},
		"stats": {2: {"hp_pct": 10}, 4: {"heal_flat": 6}, 5: {"resist": 4}},
	},
	"hallowmourn": {
		"name": "Hallowmourn", "rarity": "Legendary", "owner": "mender", "resist_all": true,
		"source": "Stasis ★5 / boss", "min_star": 5,
		"bonus": {2: "+12% HP", 4: "Heals +6", 5: "+1 AP +1 MP"},
		"stats": {2: {"hp_pct": 12}, 4: {"heal_flat": 6}, 5: {"ap": 1, "mp": 1}},
	},
	"brightedge": {
		"name": "Brightedge", "rarity": "Legendary", "owner": "", "resist_all": true,
		"source": "Stasis ★5 / boss", "min_star": 5,
		"bonus": {2: "+4% crit", 4: "+6 Mastery", 5: "+1 AP +1 MP"},
		"stats": {2: {"crit": 4}, 4: {"mastery": 6}, 5: {"ap": 1, "mp": 1}},
	},
}
## +0 part numbers. Crit% is not on the fuse ladder. Resist on these sets
## counts against every element (resist_all). Point budgets are on FAMILIES.
const PARTS := {
	"ashmantle.weapon": {"name": "Ashmantle Brand", "hp": 0, "mastery": 12, "resist": 0, "init": 0, "crit": 2},
	"ashmantle.head": {"name": "Ashmantle Helm", "hp": 16, "mastery": 0, "resist": 2, "init": 0, "crit": 0},
	"ashmantle.chest": {"name": "Ashmantle Coat", "hp": 24, "mastery": 2, "resist": 2, "init": 0, "crit": 0},
	"ashmantle.legs": {"name": "Ashmantle Guards", "hp": 12, "mastery": 0, "resist": 2, "init": 0, "crit": 0},
	"ashmantle.boots": {"name": "Ashmantle Treads", "hp": 8, "mastery": 0, "resist": 0, "init": 4, "crit": 0},
	"rustward.weapon": {"name": "Rustward Bit", "hp": 0, "mastery": 4, "resist": 2, "init": 0, "crit": 0},
	"rustward.head": {"name": "Rustward Helm", "hp": 20, "mastery": 0, "resist": 3, "init": 0, "crit": 0},
	"rustward.chest": {"name": "Rustward Plate", "hp": 26, "mastery": 0, "resist": 3, "init": 0, "crit": 0},
	"rustward.legs": {"name": "Rustward Guards", "hp": 16, "mastery": 0, "resist": 2, "init": 0, "crit": 0},
	"rustward.boots": {"name": "Rustward Treads", "hp": 8, "mastery": 0, "resist": 0, "init": 2, "crit": 0},
	"ironveil.weapon": {"name": "Veil Bit", "hp": 0, "mastery": 6, "resist": 2, "init": 0, "crit": 0},
	"ironveil.head": {"name": "Veil Casque", "hp": 22, "mastery": 0, "resist": 3, "init": 0, "crit": 0},
	"ironveil.chest": {"name": "Veil Plate", "hp": 32, "mastery": 0, "resist": 4, "init": 0, "crit": 0},
	"ironveil.legs": {"name": "Veil Guards", "hp": 16, "mastery": 0, "resist": 3, "init": 0, "crit": 0},
	"ironveil.boots": {"name": "Veil Treads", "hp": 8, "mastery": 0, "resist": 0, "init": 2, "crit": 0},
	"oathgrave.weapon": {"name": "Oathgrave Bit", "hp": 0, "mastery": 6, "resist": 3, "init": 0, "crit": 0},
	"oathgrave.head": {"name": "Oathgrave Helm", "hp": 24, "mastery": 0, "resist": 4, "init": 0, "crit": 0},
	"oathgrave.chest": {"name": "Oathgrave Plate", "hp": 36, "mastery": 0, "resist": 4, "init": 0, "crit": 0},
	"oathgrave.legs": {"name": "Oathgrave Guards", "hp": 16, "mastery": 0, "resist": 3, "init": 0, "crit": 0},
	"oathgrave.boots": {"name": "Oathgrave Treads", "hp": 8, "mastery": 0, "resist": 0, "init": 2, "crit": 0},
	"undertow.weapon": {"name": "Undertow Edge", "hp": 0, "mastery": 16, "resist": 0, "init": 0, "crit": 4},
	"undertow.head": {"name": "Undertow Helm", "hp": 12, "mastery": 0, "resist": 0, "init": 0, "crit": 4},
	"undertow.chest": {"name": "Undertow Plate", "hp": 16, "mastery": 4, "resist": 0, "init": 0, "crit": 0},
	"undertow.legs": {"name": "Undertow Guards", "hp": 8, "mastery": 2, "resist": 1, "init": 0, "crit": 0},
	"undertow.boots": {"name": "Undertow Treads", "hp": 4, "mastery": 0, "resist": 0, "init": 12, "crit": 2},
	"gallowsight.weapon": {"name": "Gallowsight Edge", "hp": 0, "mastery": 18, "resist": 0, "init": 0, "crit": 6},
	"gallowsight.head": {"name": "Gallowsight Helm", "hp": 12, "mastery": 2, "resist": 0, "init": 0, "crit": 4},
	"gallowsight.chest": {"name": "Gallowsight Plate", "hp": 16, "mastery": 4, "resist": 1, "init": 0, "crit": 0},
	"gallowsight.legs": {"name": "Gallowsight Guards", "hp": 10, "mastery": 2, "resist": 1, "init": 0, "crit": 0},
	"gallowsight.boots": {"name": "Gallowsight Treads", "hp": 6, "mastery": 0, "resist": 0, "init": 12, "crit": 2},
	"ravenmourn.weapon": {"name": "Ravenmourn Edge", "hp": 0, "mastery": 19, "resist": 0, "init": 0, "crit": 6},
	"ravenmourn.head": {"name": "Ravenmourn Helm", "hp": 12, "mastery": 4, "resist": 0, "init": 0, "crit": 4},
	"ravenmourn.chest": {"name": "Ravenmourn Plate", "hp": 16, "mastery": 6, "resist": 1, "init": 0, "crit": 0},
	"ravenmourn.legs": {"name": "Ravenmourn Guards", "hp": 10, "mastery": 2, "resist": 1, "init": 2, "crit": 0},
	"ravenmourn.boots": {"name": "Ravenmourn Treads", "hp": 6, "mastery": 0, "resist": 0, "init": 14, "crit": 2},
	"cragmaw.weapon": {"name": "Cragmaw Bit", "hp": 0, "mastery": 10, "resist": 0, "init": 0, "crit": 3},
	"cragmaw.head": {"name": "Cragmaw Helm", "hp": 18, "mastery": 0, "resist": 2, "init": 0, "crit": 0},
	"cragmaw.chest": {"name": "Cragmaw Plate", "hp": 24, "mastery": 2, "resist": 2, "init": 0, "crit": 0},
	"cragmaw.legs": {"name": "Cragmaw Guards", "hp": 12, "mastery": 0, "resist": 2, "init": 0, "crit": 0},
	"cragmaw.boots": {"name": "Cragmaw Treads", "hp": 8, "mastery": 0, "resist": 0, "init": 2, "crit": 1},
	"maulgrave.weapon": {"name": "Maulgrave Bit", "hp": 0, "mastery": 10, "resist": 0, "init": 0, "crit": 5},
	"maulgrave.head": {"name": "Maulgrave Helm", "hp": 20, "mastery": 0, "resist": 3, "init": 0, "crit": 0},
	"maulgrave.chest": {"name": "Maulgrave Plate", "hp": 28, "mastery": 2, "resist": 3, "init": 0, "crit": 0},
	"maulgrave.legs": {"name": "Maulgrave Guards", "hp": 14, "mastery": 0, "resist": 2, "init": 0, "crit": 0},
	"maulgrave.boots": {"name": "Maulgrave Treads", "hp": 8, "mastery": 0, "resist": 0, "init": 2, "crit": 1},
	"tyrantjaw.weapon": {"name": "Tyrantjaw Bit", "hp": 0, "mastery": 12, "resist": 0, "init": 0, "crit": 5},
	"tyrantjaw.head": {"name": "Tyrantjaw Helm", "hp": 22, "mastery": 0, "resist": 3, "init": 0, "crit": 0},
	"tyrantjaw.chest": {"name": "Tyrantjaw Plate", "hp": 30, "mastery": 2, "resist": 3, "init": 0, "crit": 0},
	"tyrantjaw.legs": {"name": "Tyrantjaw Guards", "hp": 14, "mastery": 0, "resist": 3, "init": 0, "crit": 0},
	"tyrantjaw.boots": {"name": "Tyrantjaw Treads", "hp": 8, "mastery": 0, "resist": 0, "init": 2, "crit": 2},
	"nightglass.weapon": {"name": "Nightglass Edge", "hp": 0, "mastery": 15, "resist": 0, "init": 0, "crit": 3},
	"nightglass.head": {"name": "Nightglass Helm", "hp": 10, "mastery": 3, "resist": 0, "init": 0, "crit": 3},
	"nightglass.chest": {"name": "Nightglass Plate", "hp": 14, "mastery": 4, "resist": 0, "init": 0, "crit": 0},
	"nightglass.legs": {"name": "Nightglass Guards", "hp": 8, "mastery": 2, "resist": 0, "init": 4, "crit": 0},
	"nightglass.boots": {"name": "Nightglass Treads", "hp": 4, "mastery": 1, "resist": 0, "init": 14, "crit": 2},
	"stillcut.weapon": {"name": "Stillcut Edge", "hp": 0, "mastery": 18, "resist": 0, "init": 0, "crit": 4},
	"stillcut.head": {"name": "Stillcut Helm", "hp": 12, "mastery": 2, "resist": 0, "init": 0, "crit": 2},
	"stillcut.chest": {"name": "Stillcut Plate", "hp": 16, "mastery": 4, "resist": 1, "init": 0, "crit": 0},
	"stillcut.legs": {"name": "Stillcut Guards", "hp": 8, "mastery": 2, "resist": 0, "init": 6, "crit": 0},
	"stillcut.boots": {"name": "Stillcut Treads", "hp": 4, "mastery": 1, "resist": 0, "init": 20, "crit": 2},
	"gravewhisper.weapon": {"name": "Gravewhisper Edge", "hp": 0, "mastery": 18, "resist": 0, "init": 0, "crit": 5},
	"gravewhisper.head": {"name": "Gravewhisper Helm", "hp": 10, "mastery": 4, "resist": 0, "init": 0, "crit": 4},
	"gravewhisper.chest": {"name": "Gravewhisper Plate", "hp": 14, "mastery": 6, "resist": 1, "init": 0, "crit": 0},
	"gravewhisper.legs": {"name": "Gravewhisper Guards", "hp": 8, "mastery": 2, "resist": 0, "init": 8, "crit": 0},
	"gravewhisper.boots": {"name": "Gravewhisper Treads", "hp": 4, "mastery": 1, "resist": 0, "init": 20, "crit": 3},
	"vesperwell.weapon": {"name": "Vesperwell Staff", "hp": 0, "mastery": 11, "resist": 0, "init": 0, "crit": 0},
	"vesperwell.head": {"name": "Vesperwell Helm", "hp": 16, "mastery": 0, "resist": 2, "init": 0, "crit": 0},
	"vesperwell.chest": {"name": "Vesperwell Coat", "hp": 24, "mastery": 2, "resist": 2, "init": 0, "crit": 0},
	"vesperwell.legs": {"name": "Vesperwell Guards", "hp": 14, "mastery": 0, "resist": 2, "init": 0, "crit": 0},
	"vesperwell.boots": {"name": "Vesperwell Treads", "hp": 8, "mastery": 0, "resist": 1, "init": 2, "crit": 1},
	"sheaf.weapon": {"name": "Sheaf Hook", "hp": 0, "mastery": 12, "resist": 0, "init": 0, "crit": 2},
	"sheaf.head": {"name": "Sheaf Helm", "hp": 18, "mastery": 0, "resist": 2, "init": 0, "crit": 0},
	"sheaf.chest": {"name": "Sheaf Coat", "hp": 28, "mastery": 2, "resist": 3, "init": 0, "crit": 0},
	"sheaf.legs": {"name": "Sheaf Guards", "hp": 14, "mastery": 0, "resist": 3, "init": 0, "crit": 0},
	"sheaf.boots": {"name": "Sheaf Treads", "hp": 8, "mastery": 0, "resist": 1, "init": 4, "crit": 0},
	"hallowmourn.weapon": {"name": "Hallowmourn Staff", "hp": 0, "mastery": 14, "resist": 0, "init": 0, "crit": 3},
	"hallowmourn.head": {"name": "Hallowmourn Helm", "hp": 20, "mastery": 0, "resist": 3, "init": 0, "crit": 0},
	"hallowmourn.chest": {"name": "Hallowmourn Coat", "hp": 26, "mastery": 2, "resist": 3, "init": 0, "crit": 0},
	"hallowmourn.legs": {"name": "Hallowmourn Guards", "hp": 16, "mastery": 0, "resist": 3, "init": 0, "crit": 0},
	"hallowmourn.boots": {"name": "Hallowmourn Treads", "hp": 8, "mastery": 0, "resist": 1, "init": 4, "crit": 1},
	"brightedge.weapon": {"name": "Brightedge", "hp": 0, "mastery": 14, "resist": 0, "init": 0, "crit": 4},
	"brightedge.head": {"name": "Gleam Helm", "hp": 16, "mastery": 4, "resist": 0, "init": 0, "crit": 2},
	"brightedge.chest": {"name": "Gleam Coat", "hp": 20, "mastery": 7, "resist": 2, "init": 0, "crit": 0},
	"brightedge.legs": {"name": "Gleam Guards", "hp": 12, "mastery": 2, "resist": 2, "init": 0, "crit": 0},
	"brightedge.boots": {"name": "Gleam Treads", "hp": 8, "mastery": 2, "resist": 0, "init": 10, "crit": 1},
}
## Fuse ladder: plus 0..5 multiplies HP / Mastery / Resist / Init. Not crit.
const FUSE_MULT: Array[float] = [1.00, 1.12, 1.26, 1.41, 1.58, 1.78]
## No family on this ladder attunes. Left empty so old loops stay valid.
const DEFAULT_ATTUNE := {}
const ATTUNE_RIDER := {}
## Designer knobs slot_w_*: weapon is rarer.
const SLOT_WEIGHT := {"weapon": 18.0, "head": 20.5, "chest": 20.5, "legs": 20.5, "boots": 20.5}
## Normals, then Rares, then Legendaries, so a ★1 roll of 0 is Ashmantle.
const FAMILY_ORDER: Array[String] = [
	"ashmantle", "rustward", "undertow", "cragmaw", "nightglass", "vesperwell",
	"ironveil", "gallowsight", "maulgrave", "stillcut", "sheaf",
	"oathgrave", "ravenmourn", "tyrantjaw", "gravewhisper", "hallowmourn", "brightedge",
]
## Temporary art: new families reuse an existing set sheet until Scenario icons land.
const ICON_ALIAS := {
	"ashmantle": "sheaf",
	"rustward": "ironveil",
	"oathgrave": "brightedge",
	"gallowsight": "undertow",
	"ravenmourn": "duskbrand",
	"cragmaw": "sheaf",
	"maulgrave": "ironveil",
	"tyrantjaw": "duskbrand",
	"nightglass": "stillcut",
	"gravewhisper": "duskbrand",
	"vesperwell": "sheaf",
	"hallowmourn": "brightedge",
}

static var save_path: String = "user://gear_bag.json"

## [{"uid": int, "item_id": "sheaf.head", "plus": 0}]
var items: Array = []
## class_id → {slot → uid}. One uid sits on one class only.
var loadouts: Dictionary = {}
## The focused class's slot map. Same Dictionary as loadouts[focus_class].
var equipped: Dictionary = {}
var focus_class: String = "kestrel"
## family → element. Unused on this ladder (no attune). Kept for old saves.
var attune: Dictionary = {}
var next_uid: int = 1
var loot_day: int = -1
var loot_clears_today: int = 0
## TEMPORARY balance-test kit granted (backend/test_loadout.gd).
var test_grant: bool = false


func _init() -> void:
	_reset_loadouts()


func _reset_loadouts() -> void:
	loadouts = {}
	for cid in CLASS_IDS:
		loadouts[cid] = {}
	focus_class = "kestrel"
	equipped = loadouts[focus_class]


func _bind_focus() -> void:
	if not CLASS_IDS.has(focus_class):
		focus_class = "kestrel"
	if typeof(loadouts.get(focus_class, null)) != TYPE_DICTIONARY:
		loadouts[focus_class] = {}
	equipped = loadouts[focus_class]


func set_focus(class_id: String) -> void:
	if CLASS_IDS.has(class_id):
		focus_class = class_id
	_bind_focus()


static func owner_of(family: String) -> String:
	return str(FAMILIES.get(family, {}).get("owner", ""))


## Shared sets (owner "") fit every class. A class set fits only its owner.
static func can_wear(family: String, class_id: String) -> bool:
	if not FAMILIES.has(family) or not CLASS_IDS.has(class_id):
		return false
	var owner := owner_of(family)
	return owner == "" or owner == class_id


func _class_or_focus(class_id: String) -> String:
	return class_id if CLASS_IDS.has(class_id) else focus_class


func _slots_of(class_id: String) -> Dictionary:
	var use := _class_or_focus(class_id)
	if typeof(loadouts.get(use, null)) != TYPE_DICTIONARY:
		loadouts[use] = {}
	return loadouts[use]


func _strip_uid(uid: int) -> void:
	for cid in CLASS_IDS:
		var slots: Dictionary = loadouts.get(cid, {})
		for slot in slots.keys():
			if int(slots[slot]) == uid:
				slots.erase(slot)


static func item_id_for(family: String, slot: String) -> String:
	return "%s.%s" % [family, slot]


static func family_of(item_id: String) -> String:
	return item_id.get_slice(".", 0)


static func slot_of(item_id: String) -> String:
	return item_id.get_slice(".", 1)


static func is_valid_item_id(item_id: String) -> bool:
	return FAMILIES.has(family_of(item_id)) and SLOTS.has(slot_of(item_id)) and item_id.count(".") == 1


## Item icons cut from the set art in the GDD Blueprint
## (build_tools/art/gear_icons). Armour: <family>_<slot>.png. The weapon slot
## shows that family's weapon for the class looking at it (Kestrel bow,
## Ironjaw axes, Mender staff, Gloam daggers, Bastion mace + shield); with no
## class it shows the Ironjaw axes.
const ICON_ROOT := "res://art/items/gear/"


static func icon_path(item_id: String, class_id: String = "") -> String:
	var fam := family_of(item_id)
	var slot := slot_of(item_id)
	if not FAMILIES.has(fam) or not SLOTS.has(slot):
		return ""
	var art := str(ICON_ALIAS.get(fam, fam))
	if slot == "weapon":
		var cls := class_id if CLASS_IDS.has(class_id) else "ironjaw"
		return "%s%s_weapon_%s.png" % [ICON_ROOT, art, cls]
	return "%s%s_%s.png" % [ICON_ROOT, art, slot]


## Loaded icons stay referenced here. A texture loaded inside a _draw() and
## dropped when it returns is freed before the frame renders, and the renderer
## then paints a plain white square (the loot board bug, 0.1.64–0.1.68).
static var _icon_cache: Dictionary = {}


static func icon(item_id: String, class_id: String = "") -> Texture2D:
	var path := icon_path(item_id, class_id)
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not _icon_cache.has(path):
		_icon_cache[path] = load(path) as Texture2D
	return _icon_cache[path]


static func item_label(item: Dictionary) -> String:
	var item_id := str(item.get("item_id", ""))
	var part: Dictionary = PARTS.get(item_id, {})
	var name := str(part.get("name", ""))
	if name == "":
		name = "%s %s" % [str(FAMILIES.get(family_of(item_id), {}).get("name", "?")), slot_of(item_id).capitalize()]
	return "%s +%d" % [name, int(item.get("plus", 0))]


## One part's numbers at its plus (fuse ladder), rounded.
static func part_stats(item_id: String, plus: int) -> Dictionary:
	var part: Dictionary = PARTS.get(item_id, {})
	var mult: float = FUSE_MULT[clampi(plus, 0, PLUS_CAP)]
	var out := {}
	for key in ["hp", "mastery", "resist", "init"]:
		out[key] = roundi(float(part.get(key, 0)) * mult)
	# Crit% is the printed chance. Fusing a piece does not raise it.
	out["crit"] = int(part.get("crit", 0))
	return out


## Short stat line for a part, e.g. "HP 28 · Mastery 2 · Resist 2".
static func part_line(item_id: String, plus: int) -> String:
	var st := part_stats(item_id, plus)
	var bits: Array[String] = []
	for key in ["hp", "mastery", "resist", "init", "crit"]:
		if int(st[key]) > 0:
			bits.append("%s %d" % [{"hp": "HP", "mastery": "Mastery", "resist": "Resist", "init": "Init", "crit": "Crit"}[key], int(st[key])])
	return " · ".join(bits)


## The element a family's attune gives while 2+ pieces are worn: the
## player's pick, else the family default. "" = none (Neutral).
static func element_for(family: String, worn_count: int, attune_map: Dictionary) -> String:
	if worn_count < ATTUNE_PIECES:
		return ""
	var pick := str(attune_map.get(family, ""))
	if ELEMENTS.has(pick):
		return pick
	return str(DEFAULT_ATTUNE.get(family, ""))


static func utc_day(unix_seconds: int) -> int:
	return int(floor(float(unix_seconds) / float(SECONDS_PER_DAY)))


static func load_saved() -> GearBag:
	ProgressEpoch.ensure()
	var bag := GearBag.new()
	if not FileAccess.file_exists(save_path):
		return _with_test_loadout(bag)
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return bag
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		bag.from_dict(parsed)
	return _with_test_loadout(bag)


## TEMPORARY (backend/test_loadout.gd): the real save only; tests use other paths.
static func _with_test_loadout(bag: GearBag) -> GearBag:
	if save_path == _TestLoadout.DEFAULT_GEAR_PATH and _TestLoadout.sync_bag(bag):
		bag.save()
	return bag


func save() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return true


func to_dict() -> Dictionary:
	var saved := {}
	for cid in CLASS_IDS:
		saved[cid] = (loadouts.get(cid, {}) as Dictionary).duplicate()
	return {
		"items": items.duplicate(true),
		"equipped": equipped.duplicate(),
		"loadouts": saved,
		"focus_class": focus_class,
		"attune": attune.duplicate(),
		"next_uid": next_uid,
		"loot_day": loot_day,
		"loot_clears_today": loot_clears_today,
		"test_grant": test_grant,
	}


func _accept_slot(slots: Dictionary, slot: String, uid: int, class_id: String) -> void:
	var index := find(uid)
	if not SLOTS.has(slot) or index == -1:
		return
	if slot_of(str(items[index]["item_id"])) != slot:
		return
	if not can_wear(family_of(str(items[index]["item_id"])), class_id):
		return
	if _uid_is_worn(uid):
		return
	slots[slot] = uid


func _uid_is_worn(uid: int) -> bool:
	for cid in CLASS_IDS:
		if (loadouts.get(cid, {}) as Dictionary).values().has(uid):
			return true
	return false


## A saved `loadouts` map (class → slots) wins. A flat `equipped` map is the
## pre-ladder bag: a class piece moves to that class, a shared piece stays
## in the bag (one uid cannot be copied onto five classes).
func from_dict(data: Dictionary) -> void:
	items = []
	var top_uid := 0
	for raw in data.get("items", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item_id := str(raw.get("item_id", ""))
		if not is_valid_item_id(item_id):
			continue
		var uid := int(raw.get("uid", 0))
		if uid <= 0 or find(uid) != -1:
			continue
		items.append({"uid": uid, "item_id": item_id, "plus": clampi(int(raw.get("plus", 0)), 0, PLUS_CAP)})
		if bool(raw.get("test", false)):
			items[-1]["test"] = true
		if bool(raw.get("debug", false)):
			items[-1]["debug"] = true
		top_uid = maxi(top_uid, uid)
	next_uid = maxi(int(data.get("next_uid", 1)), top_uid + 1)
	_reset_loadouts()
	var raw_loadouts: Variant = data.get("loadouts", {})
	var used_loadouts := false
	if typeof(raw_loadouts) == TYPE_DICTIONARY:
		for cid in raw_loadouts:
			if CLASS_IDS.has(str(cid)) and typeof(raw_loadouts[cid]) == TYPE_DICTIONARY:
				used_loadouts = true
				break
	if used_loadouts:
		for cid in CLASS_IDS:
			var raw_slots: Variant = (raw_loadouts as Dictionary).get(cid, {})
			if typeof(raw_slots) != TYPE_DICTIONARY:
				continue
			for slot in raw_slots:
				_accept_slot(loadouts[cid], str(slot), int(raw_slots[slot]), cid)
	else:
		var raw_eq: Variant = data.get("equipped", {})
		if typeof(raw_eq) == TYPE_DICTIONARY:
			for slot in raw_eq:
				var uid := int(raw_eq[slot])
				var index := find(uid)
				if index == -1 or not SLOTS.has(str(slot)):
					continue
				if slot_of(str(items[index]["item_id"])) != str(slot):
					continue
				var owner := owner_of(family_of(str(items[index]["item_id"])))
				if owner == "":
					continue
				_accept_slot(loadouts[owner], str(slot), uid, owner)
	var saved_focus := str(data.get("focus_class", "kestrel"))
	focus_class = saved_focus if CLASS_IDS.has(saved_focus) else "kestrel"
	_bind_focus()
	attune = {}
	var raw_att: Variant = data.get("attune", {})
	if typeof(raw_att) == TYPE_DICTIONARY:
		for fam in raw_att:
			if FAMILIES.has(str(fam)) and ELEMENTS.has(str(raw_att[fam])):
				attune[str(fam)] = str(raw_att[fam])
	loot_day = int(data.get("loot_day", -1))
	loot_clears_today = maxi(int(data.get("loot_clears_today", 0)), 0)
	test_grant = bool(data.get("test_grant", false))


func find(uid: int) -> int:
	for i in items.size():
		if int(items[i]["uid"]) == uid:
			return i
	return -1


func item(uid: int) -> Dictionary:
	var index := find(uid)
	return {} if index == -1 else (items[index] as Dictionary).duplicate()


func add_item(family: String, slot: String, plus: int = 0) -> int:
	var item_id := item_id_for(family, slot)
	if not is_valid_item_id(item_id):
		return -1
	var uid := next_uid
	next_uid += 1
	items.append({"uid": uid, "item_id": item_id, "plus": clampi(plus, 0, PLUS_CAP)})
	return uid


func count_of(item_id: String) -> int:
	var count := 0
	for it in items:
		if str(it["item_id"]) == item_id:
			count += 1
	return count


func is_equipped(uid: int) -> bool:
	return _uid_is_worn(uid)


## Wear `uid` on `class_id` (or on the piece's own class, or the focus for a
## shared piece). A class piece refused by that class stays in the bag.
func equip(uid: int, class_id: String = "") -> Dictionary:
	var index := find(uid)
	if index == -1:
		return _fail("no_item")
	var item_id := str(items[index]["item_id"])
	var fam := family_of(item_id)
	var slot := slot_of(item_id)
	var owner := owner_of(fam)
	var use := class_id if class_id != "" else (owner if owner != "" else focus_class)
	if not CLASS_IDS.has(use):
		use = focus_class
	if not can_wear(fam, use):
		return _fail("wrong_class")
	_strip_uid(uid)
	_slots_of(use)[slot] = uid
	set_focus(use)
	return {"ok": true, "reason": "", "slot": slot, "class_id": use}


func unequip(slot: String, class_id: String = "") -> Dictionary:
	var slots := _slots_of(class_id if class_id != "" else focus_class)
	if not slots.has(slot):
		return _fail("empty_slot")
	slots.erase(slot)
	_bind_focus()
	return {"ok": true, "reason": ""}


func equipped_item(slot: String, class_id: String = "") -> Dictionary:
	var slots := _slots_of(class_id if class_id != "" else focus_class)
	if not slots.has(slot):
		return {}
	return item(int(slots[slot]))


## Fuse b into a: same item_id and same plus, below the +5 cap.
func can_fuse(uid_a: int, uid_b: int) -> Dictionary:
	if uid_a == uid_b:
		return _fail("same_item")
	var a := item(uid_a)
	var b := item(uid_b)
	if a.is_empty() or b.is_empty():
		return _fail("no_item")
	if str(a["item_id"]) != str(b["item_id"]):
		return _fail("different_item")
	if int(a["plus"]) != int(b["plus"]):
		return _fail("different_plus")
	if int(a["plus"]) >= PLUS_CAP:
		return _fail("plus_cap")
	return {"ok": true, "reason": ""}


func fuse(uid_a: int, uid_b: int) -> Dictionary:
	var gate := can_fuse(uid_a, uid_b)
	if not bool(gate["ok"]):
		return gate
	var worn_class := ""
	var worn_slot := ""
	for cid in CLASS_IDS:
		for slot in loadouts[cid]:
			if int(loadouts[cid][slot]) == uid_b:
				worn_class = cid
				worn_slot = str(slot)
	items.remove_at(find(uid_b))
	var a_index := find(uid_a)
	items[a_index]["plus"] = int(items[a_index]["plus"]) + 1
	if worn_class != "":
		_strip_uid(uid_a)
		loadouts[worn_class][worn_slot] = uid_a
		_bind_focus()
	return {"ok": true, "reason": "", "uid": uid_a, "plus": int(items[a_index]["plus"])}


## A partner to fuse `uid` with (same item_id and plus, not itself), or -1.
## Prefers a partner that is not worn.
func fuse_partner(uid: int) -> int:
	var base := item(uid)
	if base.is_empty():
		return -1
	var worn_match := -1
	for it in items:
		var other := int(it["uid"])
		if other == uid or str(it["item_id"]) != str(base["item_id"]) or int(it["plus"]) != int(base["plus"]):
			continue
		if not is_equipped(other):
			return other
		worn_match = other
	return worn_match


func set_counts(class_id: String = "") -> Dictionary:
	var counts := {}
	for slot in _slots_of(class_id if class_id != "" else focus_class):
		var fam := family_of(str(item(int(_slots_of(class_id if class_id != "" else focus_class)[slot])).get("item_id", "")))
		if fam == "":
			continue
		counts[fam] = int(counts.get(fam, 0)) + 1
	return counts


func can_attune(family: String, element: String) -> Dictionary:
	if not FAMILIES.has(family):
		return _fail("unknown_family")
	if not bool(FAMILIES[family].get("can_attune", false)):
		return _fail("no_attune")
	if not ELEMENTS.has(element):
		return _fail("unknown_element")
	if int(set_counts().get(family, 0)) < ATTUNE_PIECES:
		return _fail("needs_2_pieces")
	return {"ok": true, "reason": ""}


func set_attune(family: String, element: String) -> Dictionary:
	var gate := can_attune(family, element)
	if not bool(gate["ok"]):
		return gate
	attune[family] = element
	return {"ok": true, "reason": ""}


## The chosen element (or the family default) — only while 2+ pieces are worn.
## A pick is kept when pieces come off.
func attune_active(family: String) -> String:
	return element_for(family, int(set_counts().get(family, 0)), attune)


## [{family, pieces, tier, text}] for every reached tier, family order.
func active_bonuses() -> Array:
	var out: Array = []
	var counts := set_counts()
	for fam in FAMILY_ORDER:
		var pieces := int(counts.get(fam, 0))
		var bonus: Dictionary = FAMILIES[fam]["bonus"]
		for tier in [2, 4, 5]:
			if pieces >= tier:
				out.append({"family": fam, "pieces": pieces, "tier": tier, "text": str(bonus[tier])})
	return out


## Worn pieces of one class as [{item_id, plus}]. Test and debug tags ride
## along so clean_worn can drop them. Combat recomputes stats from the list.
func worn_list(class_id: String = "") -> Array:
	var out: Array = []
	for slot in SLOTS:
		var it := equipped_item(slot, class_id)
		if not it.is_empty():
			var row := {"item_id": str(it["item_id"]), "plus": int(it["plus"])}
			if bool(it.get("test", false)):
				row["test"] = true
			if bool(it.get("debug", false)):
				row["debug"] = true
			out.append(row)
	return out


## Sanitised worn list: valid ids, one per slot, plus 0–5.
## `drop_debug` is true on the server path. A local fight keeps debug pieces
## so a review build can wear a set, and still sends the flag so a later
## clean drops them.
static func clean_worn(raw: Variant, drop_debug: bool = true) -> Array:
	var out: Array = []
	var used := {}
	if not raw is Array:
		return out
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		# The dedicated server (and every other fight) refuses kit pieces.
		# A missing flag cannot be detected; the epoch wipe is what clears the bag.
		if bool(entry.get("test", false)):
			continue
		if drop_debug and bool(entry.get("debug", false)):
			continue
		var item_id := str(entry.get("item_id", ""))
		if not is_valid_item_id(item_id):
			continue
		var slot := slot_of(item_id)
		if used.has(slot):
			continue
		used[slot] = true
		var row := {"item_id": item_id, "plus": clampi(int(entry.get("plus", 0)), 0, PLUS_CAP)}
		if bool(entry.get("debug", false)):
			row["debug"] = true
		out.append(row)
	return out


static func worn_counts(worn: Array) -> Dictionary:
	var counts := {}
	for entry in worn:
		var fam := family_of(str(entry["item_id"]))
		counts[fam] = int(counts.get(fam, 0)) + 1
	return counts


static func stats_of_worn(worn: Array) -> Dictionary:
	var total := {}
	var counts := worn_counts(worn)
	for fam in FAMILY_ORDER:
		var pieces := int(counts.get(fam, 0))
		var stats: Dictionary = FAMILIES[fam]["stats"]
		for tier in [2, 4, 5]:
			if pieces >= tier and stats.has(tier):
				for key in stats[tier]:
					total[key] = int(total.get(key, 0)) + int(stats[tier][key])
	return total


## Rare +5 weapon → +1 AP. Rare +5 boots → +1 MP. Not stacked, and a
## Normal or Legendary +5 does not open the gate. Koliseo flattens plus
## to 0 before this runs, so the gates do not apply in the arena.
static func gate_of_worn(worn: Array) -> Dictionary:
	var out := {"ap": 0, "mp": 0}
	for entry in worn:
		if int(entry.get("plus", 0)) < PLUS_CAP:
			continue
		var fam := family_of(str(entry.get("item_id", "")))
		if str(FAMILIES.get(fam, {}).get("rarity", "")) != "Rare":
			continue
		var slot := slot_of(str(entry.get("item_id", "")))
		if slot == "weapon":
			out["ap"] = 1
		elif slot == "boots":
			out["mp"] = 1
	return out


static func ap_mp_of_worn(worn: Array) -> Dictionary:
	var stats := stats_of_worn(worn)
	var gate := gate_of_worn(worn)
	var raw_ap := BASE_AP + int(stats.get("ap", 0)) + int(gate["ap"])
	var raw_mp := BASE_MP + int(stats.get("mp", 0)) + int(gate["mp"])
	return {
		"ap": mini(raw_ap, AP_CAP), "mp": mini(raw_mp, MP_CAP),
		"raw_ap": raw_ap, "raw_mp": raw_mp,
		"ap_greyed": maxi(raw_ap - AP_CAP, 0), "mp_greyed": maxi(raw_mp - MP_CAP, 0),
	}


## What a fight uses from worn gear. Part numbers × fuse multiplier (not
## crit), plus set bonuses. resist_all families add part resist to the
## universal resist, which hits every element. A class_id drops pieces
## that class cannot wear. `flatten_plus`: Koliseo arena — parts count as
## +0, so the Rare +5 gates do not; set bonuses still apply.
static func combat_stats(raw_worn: Variant, attune_map: Dictionary = {}, flatten_plus: bool = false, class_id: String = "", drop_debug: bool = false) -> Dictionary:
	var worn := clean_worn(raw_worn, drop_debug)
	if class_id != "":
		var filtered: Array = []
		for entry in worn:
			if can_wear(family_of(str(entry["item_id"])), class_id):
				filtered.append(entry)
		worn = filtered
	if flatten_plus:
		for entry in worn:
			entry["plus"] = 0
	var stats := stats_of_worn(worn)
	var apmp := ap_mp_of_worn(worn)
	var counts := worn_counts(worn)
	var hp_flat := 0
	var mastery_flat := int(stats.get("mastery", 0))
	var init := int(stats.get("init", 0))
	var resist_all := int(stats.get("resist", 0))
	var crit := int(stats.get("crit", 0))
	var resist_elem := {}
	for entry in worn:
		var item_id := str(entry["item_id"])
		var fam := family_of(item_id)
		var st := part_stats(item_id, int(entry["plus"]))
		hp_flat += int(st["hp"])
		mastery_flat += int(st["mastery"])
		init += int(st["init"])
		crit += int(st["crit"])
		if bool(FAMILIES.get(fam, {}).get("resist_all", false)):
			resist_all += int(st["resist"])
		else:
			var element := element_for(fam, int(counts.get(fam, 0)), attune_map).to_lower()
			if element == "":
				element = "neutral"
			resist_elem[element] = int(resist_elem.get(element, 0)) + int(st["resist"])
	var riders := {}
	for fam in ATTUNE_RIDER:
		var element := element_for(fam, int(counts.get(fam, 0)), attune_map).to_lower()
		if element != "":
			riders[element] = int(riders.get(element, 0)) + int(ATTUNE_RIDER[fam])
	var attuned: Array = []
	for fam in FAMILY_ORDER:
		var element := element_for(fam, int(counts.get(fam, 0)), attune_map).to_lower()
		if element != "" and not attuned.has(element):
			attuned.append(element)
	return {
		"hp_flat": hp_flat,
		"hp_pct": int(stats.get("hp_pct", 0)),
		"mastery": roundi(float(mastery_flat) * (1.0 + float(stats.get("mastery_pct", 0)) / 100.0)),
		"resist": resist_all,
		"resist_elem": resist_elem,
		"crit": mini(crit, CRIT_CAP),
		"flex_pct": int(stats.get("flex_pct", 0)),
		"riders": riders,
		"attuned": attuned,
		"first_flex_pct": int(stats.get("first_flex_pct", 0)),
		"init": init,
		"ap": int(apmp["ap"]),
		"mp": int(apmp["mp"]),
		"back_pct": int(stats.get("back_pct", 0)),
		"first_hit": int(stats.get("first_hit", 0)),
		"melee": int(stats.get("melee", 0)),
		"heal_flat": int(stats.get("heal_flat", 0)),
		"first_back": int(stats.get("first_back", 0)),
		"guard_flat": int(stats.get("guard_flat", 0)),
		"ward_shield": int(stats.get("ward_shield", 0)),
		"start_aegis": int(stats.get("start_aegis", 0)),
	}


## Summed numeric set stats of what is worn (tiers stack).
func bonus_stats(class_id: String = "") -> Dictionary:
	return stats_of_worn(worn_list(class_id))


## Rare +5 weapon / boots gate for the focused class (or `class_id`).
func rare_gate(class_id: String = "") -> Dictionary:
	return gate_of_worn(worn_list(class_id))


## AP/MP after gear, clamped 8/5.
func ap_mp(class_id: String = "") -> Dictionary:
	return ap_mp_of_worn(worn_list(class_id))


## Sanitised fight gear from any source (a peer, a save): worn + attune.
static func clean_fight_gear(raw: Variant) -> Dictionary:
	var out := {"worn": [], "attune": {}}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	out["worn"] = clean_worn(raw.get("worn", []))
	var att: Variant = raw.get("attune", {})
	if typeof(att) == TYPE_DICTIONARY:
		for fam in att:
			if FAMILIES.has(str(fam)) and ELEMENTS.has(str(att[fam])):
				out["attune"][str(fam)] = str(att[fam])
	# One XII Still for this fight (StillVault); cleaned again by the sim.
	var still := StillVault.clean(raw.get("still", {}))
	if not still.is_empty():
		out["still"] = still
	# Levels ride along; CombatSim recomputes them with HeroProgress.combat_stats.
	var heroes: Variant = raw.get("heroes", {})
	if typeof(heroes) == TYPE_DICTIONARY:
		out["heroes"] = {}
		for class_id in heroes:
			if HeroProgress.GROWTH.has(str(class_id)) and typeof(heroes[class_id]) == TYPE_DICTIONARY:
				var lvl := clampi(int(heroes[class_id].get("level", 1)), 1, HeroProgress.MAX_LEVEL)
				out["heroes"][str(class_id)] = {"level": lvl, "spent": HeroProgress.clean_spent(heroes[class_id].get("spent", {}), lvl)}
				# Elements Step 3: the class's spell → element picks ({} = Neutral).
				if (heroes[class_id] as Dictionary).has("elements"):
					out["heroes"][str(class_id)]["elements"] = clean_spell_elements(str(class_id), heroes[class_id]["elements"])
	return out


## A fight's spell → element map: FLEX spells of the class only, at most two
## different elements (a phone cannot smuggle a third). Bad input → {}.
static func clean_spell_elements(class_id: String, raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var out := {}
	var seen: Array = []
	for id in SpellKits.flex_spells(class_id):
		var el := str((raw as Dictionary).get(id, "")).to_lower()
		if not SpellKits.ELEMENTS.has(el):
			continue
		if not seen.has(el):
			seen.append(el)
		out[id] = el
	return out if seen.size() <= 2 else {}


## Everything a fight needs from one class loadout.
## Test pieces are stripped. Debug pieces stay (flagged) so a review build
## can fight with them; the online send path runs clean_fight_gear, which
## drops debug.
func fight_gear(with_still: bool = false, class_id: String = "") -> Dictionary:
	var out := {"worn": clean_worn(worn_list(class_id), false), "attune": attune.duplicate(), "heroes": HeroProgress.load_saved().fight_heroes()}
	if with_still:
		var still := StillVault.load_saved().fight_still()
		if not still.is_empty():
			out["still"] = still
	return out


## Editor / debug builds only. Wears a full +0 set on `class_id`, ignoring
## the class lock, and tags every piece debug so a server clean drops it.
func debug_equip_set(class_id: String, family: String) -> Dictionary:
	if not OS.is_debug_build():
		return _fail("not_debug")
	if not CLASS_IDS.has(class_id) or not FAMILIES.has(family):
		return _fail("bad_args")
	for slot in SLOTS:
		var uid := add_item(family, slot, 0)
		var index := find(uid)
		if index == -1:
			return _fail("bad_args")
		items[index]["debug"] = true
		_strip_uid(uid)
		var slots: Dictionary = _slots_of(class_id)
		var previous := int(slots.get(slot, -1))
		if previous != -1:
			slots.erase(slot)
		slots[slot] = uid
	set_focus(class_id)
	return {"ok": true, "reason": "", "class_id": class_id, "family": family}


## Families a door of this star can drop (min_star <= star).
static func families_for_star(star: int) -> Array:
	var pool: Array = []
	for fam in FAMILY_ORDER:
		if int(FAMILIES[fam]["min_star"]) <= star:
			pool.append(fam)
	return pool


## +0 point budget. 1 Mastery = 1, 2 HP = 1, 1 Resist = 2, 2 Init = 1, 1% crit = 1.
static func budget_points(family: String) -> int:
	var points := 0
	for slot in SLOTS:
		var part: Dictionary = PARTS.get(item_id_for(family, slot), {})
		points += int(part.get("mastery", 0))
		points += int(part.get("hp", 0)) / 2
		points += int(part.get("resist", 0)) * 2
		points += int(part.get("init", 0)) / 2
		points += int(part.get("crit", 0))
	return points


func loot_clears_left(unix_seconds: int) -> int:
	if utc_day(unix_seconds) != loot_day:
		return LOOT_CLEARS_PER_DAY
	return maxi(LOOT_CLEARS_PER_DAY - loot_clears_today, 0)


## A Stasis door cleared. The first 5 clears of the UTC day open a chest of
## +0 pieces from the families that door's star can drop; clear 6+ is empty.
## `pick` is 0..1 values (tests pass fixed ones; the game passes randf).
func record_stasis_clear(unix_seconds: int, star: int = 1, pick: Callable = Callable()) -> Dictionary:
	var today := utc_day(unix_seconds)
	if today != loot_day:
		loot_day = today
		loot_clears_today = 0
	loot_clears_today += 1
	if loot_clears_today > LOOT_CLEARS_PER_DAY:
		return {"chest": false, "items": [], "clears_today": loot_clears_today}
	var pool: Array[String] = []
	for fam in FAMILY_ORDER:
		if int(FAMILIES[fam]["min_star"]) <= star:
			pool.append(fam)
	var dropped: Array = []
	for i in STASIS_1_CHEST_PIECES:
		if pool.is_empty():
			break
		var r1 := float(pick.call()) if pick.is_valid() else randf()
		var r2 := float(pick.call()) if pick.is_valid() else randf()
		var fam := pool[mini(int(r1 * pool.size()), pool.size() - 1)]
		var slot := weighted_slot(r2)
		var uid := add_item(fam, slot, 0)
		dropped.append(item(uid))
	return {"chest": true, "items": dropped, "clears_today": loot_clears_today}


## Slot for a 0..1 roll using the slot_w_* weights (weapon 18%, others 20.5%).
static func weighted_slot(roll: float) -> String:
	var total := 0.0
	for slot in SLOTS:
		total += float(SLOT_WEIGHT[slot])
	var at := clampf(roll, 0.0, 0.999999) * total
	for slot in SLOTS:
		at -= float(SLOT_WEIGHT[slot])
		if at < 0.0:
			return slot
	return SLOTS[SLOTS.size() - 1]


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
