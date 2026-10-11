extends RefCounted

## PC gear: the mobile set ladder (origin/mobile 7035f8f, backend/gear_bag.gd),
## ported for the PC world. Mauro, 11 Oct 2026: "Crea estos sets en el juego
## de pc", then "Ok entonces utiliza los de mobil". Preload. No global class.
##
## 23 sets. Shared: Ashmantle (Normal) and Brightedge (Legendary) fit any
## class. Each class has a Normal, a Rare, a Legendary and an Ultra set, and a
## class set fits only that class. Slots: weapon, head, chest, legs, boots.
## The set ids, names, part numbers and 2/4/5-piece bonuses are mobile's,
## copied as they are (see docs/pc/GEAR_SYSTEM_PC.md).
##
## Fuse: two copies of one piece at the same plus make one piece at plus+1,
## cap +5. The ladder multiplies HP / Mastery / Resist / Init. Crit and the
## Ultra extras do not grow.
## AP/MP: base 6/3, cap 8/5. Legendary and Ultra 5pc +1 AP +1 MP. Rare +5
## weapon +1 AP, Rare +5 boots +1 MP (each once). The PC level milestone
## (level_rewards.json, +1 AP at level 30) is added by pc_progress on top,
## inside the same cap. PC has no Hourglass.
## Crit: x1.3, chance cap 20%, one crit per fighter per turn, heals crit for
## the Mender only (combat_sim.gd). Ultra special lines need a Koliseo fight
## (`pvp`); PC fights are dungeon and world fights, so they stay off.
## Drops: a chest rolls a tier from the star row (or the boss row), then a set
## of that tier at equal odds, then a weighted slot. Ultra sets never drop:
## source "koliseo_shop", ULTRA_PART_COST coins per piece.
## Item ids are mobile's: "<set>.<slot>", e.g. "cragmaw.head". The set id is
## the part before the dot, the slot the part after it.

const SLOTS: Array[String] = ["weapon", "head", "chest", "legs", "boots"]
const SLOT_STAT := {
	"weapon": "Mastery", "head": "HP", "chest": "HP + resist", "legs": "resist", "boots": "Init",
}
const PLUS_CAP := 5
const BASE_AP := 6
const BASE_MP := 3
const AP_CAP := 8
const MP_CAP := 5
const CRIT_CAP := 20
const CRIT_MULT := 1.3
const CLASS_IDS: Array[String] = ["kestrel", "ironjaw", "mender", "gloam", "bastion"]
## Mobile marks the chest size Provisional. PC keeps it: one piece, at +0.
const CHEST_PIECES := 1
const CHEST_PLUS := 0
## Koliseo shop price of one Ultra part (mobile koliseo_wallet.gd ULTRA_PART_COST).
const ULTRA_PART_COST := 30
const ULTRA_SOURCE := "koliseo_shop"

## `bonus` tiers stack. `stats` are what combat applies.
## `owner` "" = shared (any class). `resist_all` = part resist is not elemental.
## Point budget (1 Mastery = 1, 2 HP = 1, 1 Resist = 2, 2 Init = 1, 1% crit = 1):
## Normal ~60, Rare ~70, Legendary ~77.
const FAMILIES := {
	"ashmantle": {
		"name": "Ashmantle", "rarity": "Normal", "owner": "", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★1+", "min_star": 1,
		"bonus": {2: "+6% HP", 4: "+4 Mastery", 5: "+2 Init"},
		"stats": {2: {"hp_pct": 6}, 4: {"mastery": 4}, 5: {"init": 2}},
	},
	"rustward": {
		"name": "Rustward", "rarity": "Normal", "owner": "bastion", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★1+", "min_star": 1,
		"bonus": {2: "+8% HP", 4: "+4 Resist", 5: "First hit you take each turn deals 4 less"},
		"stats": {2: {"hp_pct": 8}, 4: {"resist": 4}, 5: {"guard_flat": 4}},
	},
	"ironveil": {
		"name": "Ironveil", "rarity": "Rare", "owner": "bastion", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★3+", "min_star": 3,
		"bonus": {2: "+10% HP", 4: "+6 Resist", 5: "First hit you take each turn deals 6 less"},
		"stats": {2: {"hp_pct": 10}, 4: {"resist": 6}, 5: {"guard_flat": 6}},
	},
	"oathgrave": {
		"name": "Oathgrave", "rarity": "Legendary", "owner": "bastion", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★5 / boss", "min_star": 5,
		"bonus": {2: "+12% HP", 4: "+6 Resist", 5: "+1 AP +1 MP. Ward shield 25 (cap 40). Start with 1 Aegis. No Aegis refund when Ward breaks."},
		"stats": {2: {"hp_pct": 12}, 4: {"resist": 6}, 5: {"ap": 1, "mp": 1, "ward_shield": 25, "start_aegis": 1}},
	},
	"undertow": {
		"name": "Undertow", "rarity": "Normal", "owner": "kestrel", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★1+", "min_star": 1,
		"bonus": {2: "+4 Init", 4: "+4% crit", 5: "Your first hit each turn deals +4"},
		"stats": {2: {"init": 4}, 4: {"crit": 4}, 5: {"first_hit": 4}},
	},
	"gallowsight": {
		"name": "Gallowsight", "rarity": "Rare", "owner": "kestrel", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★3+", "min_star": 3,
		"bonus": {2: "+4 Init", 4: "+6% crit", 5: "Your first hit each turn deals +6"},
		"stats": {2: {"init": 4}, 4: {"crit": 6}, 5: {"first_hit": 6}},
	},
	"ravenmourn": {
		"name": "Ravenmourn", "rarity": "Legendary", "owner": "kestrel", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★5 / boss", "min_star": 5,
		"bonus": {2: "+6 Init", 4: "+6% crit", 5: "+1 AP +1 MP"},
		"stats": {2: {"init": 6}, 4: {"crit": 6}, 5: {"ap": 1, "mp": 1}},
	},
	"cragmaw": {
		"name": "Cragmaw", "rarity": "Normal", "owner": "ironjaw", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★1+", "min_star": 1,
		"bonus": {2: "+8% HP", 4: "+4 Resist", 5: "Hits at range 1 deal +4"},
		"stats": {2: {"hp_pct": 8}, 4: {"resist": 4}, 5: {"melee": 4}},
	},
	"maulgrave": {
		"name": "Maulgrave", "rarity": "Rare", "owner": "ironjaw", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★3+", "min_star": 3,
		"bonus": {2: "+10% HP", 4: "+4 Resist", 5: "Hits at range 1 deal +6"},
		"stats": {2: {"hp_pct": 10}, 4: {"resist": 4}, 5: {"melee": 6}},
	},
	"tyrantjaw": {
		"name": "Tyrantjaw", "rarity": "Legendary", "owner": "ironjaw", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★5 / boss", "min_star": 5,
		"bonus": {2: "+12% HP", 4: "+4% crit", 5: "+1 AP +1 MP"},
		"stats": {2: {"hp_pct": 12}, 4: {"crit": 4}, 5: {"ap": 1, "mp": 1}},
	},
	"nightglass": {
		"name": "Nightglass", "rarity": "Normal", "owner": "gloam", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★1+", "min_star": 1,
		"bonus": {2: "+4 Init", 4: "+4% crit", 5: "Your first back hit each turn deals +4"},
		"stats": {2: {"init": 4}, 4: {"crit": 4}, 5: {"first_back": 4}},
	},
	"stillcut": {
		"name": "Stillcut", "rarity": "Rare", "owner": "gloam", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★3+", "min_star": 3,
		"bonus": {2: "+6 Init", 4: "+4% crit", 5: "Your first back hit each turn deals +6"},
		"stats": {2: {"init": 6}, 4: {"crit": 4}, 5: {"first_back": 6}},
	},
	"gravewhisper": {
		"name": "Gravewhisper", "rarity": "Legendary", "owner": "gloam", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★5 / boss", "min_star": 5,
		"bonus": {2: "+6 Init", 4: "Back hits deal +6% damage", 5: "+1 AP +1 MP"},
		"stats": {2: {"init": 6}, 4: {"back_pct": 6}, 5: {"ap": 1, "mp": 1}},
	},
	"vesperwell": {
		"name": "Vesperwell", "rarity": "Normal", "owner": "mender", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★1+", "min_star": 1,
		"bonus": {2: "+8% HP", 4: "Heals +4", 5: "+4 Resist"},
		"stats": {2: {"hp_pct": 8}, 4: {"heal_flat": 4}, 5: {"resist": 4}},
	},
	"sheaf": {
		"name": "Sheaf", "rarity": "Rare", "owner": "mender", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★3+", "min_star": 3,
		"bonus": {2: "+10% HP", 4: "Heals +6", 5: "+4 Resist"},
		"stats": {2: {"hp_pct": 10}, 4: {"heal_flat": 6}, 5: {"resist": 4}},
	},
	"hallowmourn": {
		"name": "Hallowmourn", "rarity": "Legendary", "owner": "mender", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★5 / boss", "min_star": 5,
		"bonus": {2: "+12% HP", 4: "Heals +6", 5: "+1 AP +1 MP"},
		"stats": {2: {"hp_pct": 12}, 4: {"heal_flat": 6}, 5: {"ap": 1, "mp": 1}},
	},
	"brightedge": {
		"name": "Brightedge", "rarity": "Legendary", "owner": "", "resist_all": true,
		"source": "dungeon_chest", "source_text": "Dungeon chest ★5 / boss", "min_star": 5,
		"bonus": {2: "+4% crit", 4: "+6 Mastery", 5: "+1 AP +1 MP"},
		"stats": {2: {"crit": 4}, 4: {"mastery": 6}, 5: {"ap": 1, "mp": 1}},
	},
	# Ultra. pvp_only: special lines need a Koliseo fight (flatten_plus).
	# The 5pc +1 AP +1 MP always applies. Plain HP / Mastery / Resist / Init
	# always apply. They never drop.
	"gatewarden": {
		"name": "Gatewarden", "rarity": "Ultra", "owner": "bastion", "resist_all": true, "pvp_only": true,
		"source": "koliseo_shop", "source_text": "Koliseo shop, 30 coins per piece. Never drops", "min_star": 99,
		"bonus": {
			2: "Pushes on you deal no extra damage (you are still moved)",
			4: "The first back hit on you each turn gets no back bonus",
			5: "+1 AP +1 MP. Once per turn, a crit on you or an ally within 3 tiles deals normal damage",
		},
		"stats": {2: {"push_guard": 1}, 4: {"no_back": 1}, 5: {"ap": 1, "mp": 1, "crit_ward": 1}},
	},
	"sandhawk": {
		"name": "Sandhawk", "rarity": "Ultra", "owner": "kestrel", "resist_all": true, "pvp_only": true,
		"source": "koliseo_shop", "source_text": "Koliseo shop, 30 coins per piece. Never drops", "min_star": 99,
		"bonus": {
			2: "Once per match, when an enemy steps next to you, your next Vault is free (0 AP, and it still starts the cooldown)",
			4: "Fade on an enemy with 2+ of your Marks lasts 1 turn",
			5: "+1 AP +1 MP. Once per turn, Detonate removes 1 class stack",
		},
		"stats": {2: {"free_vault": 1}, 4: {"fade_cut": 1}, 5: {"ap": 1, "mp": 1, "detonate_strip": 1}},
	},
	"pitmaw": {
		"name": "Pitmaw", "rarity": "Ultra", "owner": "ironjaw", "resist_all": true, "pvp_only": true,
		"source": "koliseo_shop", "source_text": "Koliseo shop, 30 coins per piece. Never drops", "min_star": 99,
		"bonus": {
			2: "Once per fight below 35% HP: Berserk (+15% melee, +1 MP) for your next 2 turns, and you take +5% damage",
			4: "Your first hit each turn gives the target −1 MP next turn (a Slow)",
			5: "+1 AP +1 MP. A Shoulder hit removes 1 class stack, at most once every 2 turns",
		},
		"stats": {2: {"berserk": 1}, 4: {"hit_slow": 1}, 5: {"ap": 1, "mp": 1, "shoulder_strip": 1}},
	},
	"hushring": {
		"name": "Hushring", "rarity": "Ultra", "owner": "gloam", "resist_all": true, "pvp_only": true,
		"source": "koliseo_shop", "source_text": "Koliseo shop, 30 coins per piece. Never drops", "min_star": 99,
		"bonus": {
			2: "Enemies you hit heal 25% less until their next turn",
			4: "Your first hit each turn deals +50% damage to shields",
			5: "+1 AP +1 MP. Your Fade lasts 3 of your turns",
		},
		"stats": {2: {"heal_suppress": 1}, 4: {"shield_burst": 1}, 5: {"ap": 1, "mp": 1, "long_fade": 1}},
	},
	"mercywell": {
		"name": "Mercywell", "rarity": "Ultra", "owner": "mender", "resist_all": true, "pvp_only": true,
		"source": "koliseo_shop", "source_text": "Koliseo shop, 30 coins per piece. Never drops", "min_star": 99,
		"bonus": {
			2: "Cleanse also removes Stun",
			4: "Once per fight, a lethal hit leaves you at 1 HP",
			5: "+1 AP +1 MP. Rekindle costs 5 AP and 4 Pulse, range 3, revives at 40% HP plus a 10 shield",
		},
		"stats": {2: {"cleanse_stun": 1}, 4: {"cheat_death": 1}, 5: {"ap": 1, "mp": 1, "rekindle_ultra": 1}},
	},
}
## +0 part numbers (mobile PARTS). Crit% is not on the fuse ladder.
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
	"gatewarden.weapon": {"name": "Gatebreaker Mace", "hp": 0, "mastery": 6, "resist": 1, "init": 0, "crit": 0, "ward_shield": 25},
	"gatewarden.head": {"name": "Grille Helm", "hp": 16, "mastery": 0, "resist": 2, "init": 0, "crit": 0},
	"gatewarden.chest": {"name": "Gate Plate", "hp": 32, "mastery": 0, "resist": 3, "init": 0, "crit": 0},
	"gatewarden.legs": {"name": "Gate Greaves", "hp": 14, "mastery": 0, "resist": 4, "init": 0, "crit": 0},
	"gatewarden.boots": {"name": "Gate Sabatons", "hp": 9, "mastery": 0, "resist": 1, "init": 2, "crit": 0},
	"sandhawk.weapon": {"name": "Sandhawk Recurve", "hp": 0, "mastery": 6, "resist": 0, "init": 0, "crit": 3, "bow_range": 1},
	"sandhawk.head": {"name": "Hawk Hood", "hp": 16, "mastery": 0, "resist": 0, "init": 0, "crit": 2, "extra_mark": 1},
	"sandhawk.chest": {"name": "Sandhawk Jerkin", "hp": 22, "mastery": 3, "resist": 2, "init": 0, "crit": 0},
	"sandhawk.legs": {"name": "Sash Guards", "hp": 12, "mastery": 2, "resist": 3, "init": 0, "crit": 0},
	"sandhawk.boots": {"name": "Sand Striders", "hp": 6, "mastery": 1, "resist": 1, "init": 6, "crit": 0, "unbound": 1},
	"pitmaw.weapon": {"name": "Pitmaw Axes", "hp": 0, "mastery": 4, "resist": 0, "init": 0, "crit": 3, "melee_pct": 8},
	"pitmaw.head": {"name": "Jaw-Guard Helm", "hp": 22, "mastery": 0, "resist": 2, "init": 0, "crit": 0, "crit_dmg": 10},
	"pitmaw.chest": {"name": "Pit Hide", "hp": 30, "mastery": 2, "resist": 3, "init": 0, "crit": 0},
	"pitmaw.legs": {"name": "Chain Wraps", "hp": 12, "mastery": 0, "resist": 4, "init": 0, "crit": 0},
	"pitmaw.boots": {"name": "Pit Treads", "hp": 6, "mastery": 0, "resist": 1, "init": 0, "crit": 0, "push_flat": 2},
	"hushring.weapon": {"name": "Hush Knives", "hp": 0, "mastery": 14, "resist": 0, "init": 0, "crit": 4, "back_pct": 10},
	"hushring.head": {"name": "Half-Mask Hood", "hp": 16, "mastery": 3, "resist": 0, "init": 0, "crit": 2, "crit_dmg": 10},
	"hushring.chest": {"name": "Hushsilk Vest", "hp": 24, "mastery": 4, "resist": 0, "init": 4, "crit": 0},
	"hushring.legs": {"name": "Silk Wraps", "hp": 14, "mastery": 1, "resist": 0, "init": 2, "crit": 0},
	"hushring.boots": {"name": "Hush Steps", "hp": 8, "mastery": 1, "resist": 0, "init": 8, "crit": 0},
	"mercywell.weapon": {"name": "Mercywell Censer", "hp": 0, "mastery": 5, "resist": 0, "init": 0, "crit": 0, "crit_heal": 3, "heal_pct": 8},
	"mercywell.head": {"name": "Shell Circlet", "hp": 20, "mastery": 2, "resist": 2, "init": 0, "crit": 0},
	"mercywell.chest": {"name": "Mercy Vestments", "hp": 28, "mastery": 2, "resist": 3, "init": 0, "crit": 0},
	"mercywell.legs": {"name": "Linen Robe-Skirt", "hp": 12, "mastery": 0, "resist": 4, "init": 0, "crit": 0},
	"mercywell.boots": {"name": "Linen Treads", "hp": 8, "mastery": 0, "resist": 1, "init": 6, "crit": 0},
}
## Fuse ladder: plus 0..5 multiplies HP / Mastery / Resist / Init. Not crit.
const FUSE_MULT: Array[float] = [1.00, 1.12, 1.26, 1.41, 1.58, 1.78]
## Slot weights (mobile slot_w_*): weapon is rarer.
const SLOT_WEIGHT := {"weapon": 18.0, "head": 20.5, "chest": 20.5, "legs": 20.5, "boots": 20.5}
## Normals, then Rares, then Legendaries. Ultra sets are not in this list.
const FAMILY_ORDER: Array[String] = [
	"ashmantle", "rustward", "undertow", "cragmaw", "nightglass", "vesperwell",
	"ironveil", "gallowsight", "maulgrave", "stillcut", "sheaf",
	"oathgrave", "ravenmourn", "tyrantjaw", "gravewhisper", "hallowmourn", "brightedge",
]
## Koliseo-only sets. Kept out of FAMILY_ORDER so loot never rolls them.
const ULTRA_ORDER: Array[String] = ["gatewarden", "sandhawk", "pitmaw", "hushring", "mercywell"]
const ULTRA_BY_CLASS := {
	"bastion": "gatewarden",
	"kestrel": "sandhawk",
	"ironjaw": "pitmaw",
	"gloam": "hushring",
	"mender": "mercywell",
}
const RARITIES: Array[String] = ["Normal", "Rare", "Legendary"]
## Chest tier weights, out of 100. ★2 reads ★1, ★4 reads ★3. Boss is its own row.
const DROP_WEIGHTS := {
	1: {"Normal": 100, "Rare": 0, "Legendary": 0},
	3: {"Normal": 70, "Rare": 30, "Legendary": 0},
	5: {"Normal": 60, "Rare": 30, "Legendary": 10},
}
const BOSS_DROP_WEIGHTS := {"Normal": 50, "Rare": 30, "Legendary": 20}


## "Kestrel", "kestrel" → "kestrel". Anything else → "".
static func class_key(class_id: String) -> String:
	var key := class_id.strip_edges().to_lower()
	return key if CLASS_IDS.has(key) else ""


static func owner_of(family: String) -> String:
	return str(FAMILIES.get(family, {}).get("owner", ""))


static func rarity_of(family: String) -> String:
	return str(FAMILIES.get(family, {}).get("rarity", ""))


static func is_ultra(family: String) -> bool:
	return bool(FAMILIES.get(family, {}).get("pvp_only", false))


## Shared sets (owner "") fit every class. A class set fits only its owner.
static func can_wear(family: String, class_id: String) -> bool:
	var key := class_key(class_id)
	if not FAMILIES.has(family) or key == "":
		return false
	var owner := owner_of(family)
	return owner == "" or owner == key


static func item_id_for(family: String, slot: String) -> String:
	return "%s.%s" % [family, slot]


static func family_of(item_id: String) -> String:
	return item_id.get_slice(".", 0)


static func slot_of(item_id: String) -> String:
	return item_id.get_slice(".", 1)


static func is_valid_item_id(item_id: String) -> bool:
	return item_id.count(".") == 1 and FAMILIES.has(family_of(item_id)) and SLOTS.has(slot_of(item_id))


## Every part id, sets in FAMILY_ORDER then ULTRA_ORDER, slots in SLOTS order.
static func all_item_ids() -> Array:
	var out: Array = []
	var order: Array = []
	order.append_array(FAMILY_ORDER)
	order.append_array(ULTRA_ORDER)
	for fam in order:
		for slot in SLOTS:
			out.append(item_id_for(fam, slot))
	return out


static func part_name(item_id: String) -> String:
	var part: Dictionary = PARTS.get(item_id, {})
	var name := str(part.get("name", ""))
	if name == "":
		name = "%s %s" % [str(FAMILIES.get(family_of(item_id), {}).get("name", "?")), slot_of(item_id).capitalize()]
	return name


static func item_label(item_id: String, plus: int) -> String:
	return "%s +%d" % [part_name(item_id), clampi(plus, 0, PLUS_CAP)]


## One part's numbers at its plus (fuse ladder), rounded. Crit does not grow.
static func part_stats(item_id: String, plus: int) -> Dictionary:
	var part: Dictionary = PARTS.get(item_id, {})
	var mult: float = FUSE_MULT[clampi(plus, 0, PLUS_CAP)]
	var out := {}
	for key in ["hp", "mastery", "resist", "init"]:
		out[key] = roundi(float(part.get(key, 0)) * mult)
	out["crit"] = int(part.get("crit", 0))
	return out


## Short stat line for a part, e.g. "HP 28 · Mastery 2 · Resist 2".
static func part_line(item_id: String, plus: int) -> String:
	var st := part_stats(item_id, plus)
	var bits: Array[String] = []
	var label := {"hp": "HP", "mastery": "Mastery", "resist": "Resist", "init": "Init", "crit": "Crit %"}
	for key in ["hp", "mastery", "resist", "init", "crit"]:
		if int(st[key]) > 0:
			bits.append("%s %d" % [label[key], int(st[key])])
	var special := special_line(item_id)
	if special != "":
		bits.append(special)
	return " · ".join(bits)


## The Koliseo-only rider on one Ultra part. Empty for ladder sets.
static func special_line(item_id: String) -> String:
	var part: Dictionary = PARTS.get(item_id, {})
	var bits: Array[String] = []
	if int(part.get("ward_shield", 0)) > 0:
		bits.append("Ward %d" % int(part["ward_shield"]))
	if int(part.get("bow_range", 0)) > 0:
		bits.append("+1 range")
	if int(part.get("extra_mark", 0)) > 0:
		bits.append("+1 Mark on first hit")
	if int(part.get("unbound", 0)) > 0:
		bits.append("Unbound")
	if int(part.get("melee_pct", 0)) > 0:
		bits.append("Melee +%d%%" % int(part["melee_pct"]))
	if int(part.get("crit_dmg", 0)) > 0:
		bits.append("Crit dmg +%d%%" % int(part["crit_dmg"]))
	if int(part.get("push_flat", 0)) > 0:
		bits.append("Push +%d" % int(part["push_flat"]))
	if int(part.get("back_pct", 0)) > 0:
		bits.append("Back +%d%%" % int(part["back_pct"]))
	if int(part.get("heal_pct", 0)) > 0:
		bits.append("Heal +%d%%" % int(part["heal_pct"]))
	if int(part.get("crit_heal", 0)) > 0:
		bits.append("Crit heal %d%%" % int(part["crit_heal"]))
	if bits.is_empty():
		return ""
	return "%s  (Koliseo only)" % " · ".join(bits)


## Sanitised worn list: valid ids, one per slot, plus 0–5.
static func clean_worn(raw: Variant) -> Array:
	var out: Array = []
	var used := {}
	if not raw is Array:
		return out
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_id := str(entry.get("item_id", ""))
		if not is_valid_item_id(item_id):
			continue
		var slot := slot_of(item_id)
		if used.has(slot):
			continue
		used[slot] = true
		out.append({"item_id": item_id, "plus": clampi(int(entry.get("plus", 0)), 0, PLUS_CAP)})
	return out


static func worn_counts(worn: Array) -> Dictionary:
	var counts := {}
	for entry in worn:
		var fam := family_of(str(entry["item_id"]))
		counts[fam] = int(counts.get(fam, 0)) + 1
	return counts


## Summed set-bonus stats (tiers stack). `pvp` includes Ultra special lines.
## The +1 AP +1 MP on an Ultra 5pc always counts.
static func stats_of_worn(worn: Array, pvp: bool = false) -> Dictionary:
	var total := {}
	var counts := worn_counts(worn)
	var order: Array = []
	order.append_array(FAMILY_ORDER)
	order.append_array(ULTRA_ORDER)
	for fam in order:
		var pieces := int(counts.get(fam, 0))
		var stats: Dictionary = FAMILIES[fam]["stats"]
		var ultra := is_ultra(fam)
		for tier in [2, 4, 5]:
			if pieces >= tier and stats.has(tier):
				for key in stats[tier]:
					if ultra and not pvp and key != "ap" and key != "mp":
						continue
					total[key] = int(total.get(key, 0)) + int(stats[tier][key])
	return total


## Rare +5 weapon → +1 AP. Rare +5 boots → +1 MP. Not stacked; a Normal,
## Legendary or Ultra +5 does not open the gate.
static func gate_of_worn(worn: Array) -> Dictionary:
	var out := {"ap": 0, "mp": 0}
	for entry in worn:
		if int(entry.get("plus", 0)) < PLUS_CAP:
			continue
		var item_id := str(entry.get("item_id", ""))
		if rarity_of(family_of(item_id)) != "Rare":
			continue
		var slot := slot_of(item_id)
		if slot == "weapon":
			out["ap"] = 1
		elif slot == "boots":
			out["mp"] = 1
	return out


## AP/MP from gear, clamped 8/5. `extra_ap` is the PC level milestone AP.
static func ap_mp_of_worn(worn: Array, pvp: bool = false, extra_ap: int = 0) -> Dictionary:
	var stats := stats_of_worn(worn, pvp)
	var gate := gate_of_worn(worn)
	var raw_ap := BASE_AP + int(stats.get("ap", 0)) + int(gate["ap"]) + maxi(extra_ap, 0)
	var raw_mp := BASE_MP + int(stats.get("mp", 0)) + int(gate["mp"])
	return {
		"ap": mini(raw_ap, AP_CAP), "mp": mini(raw_mp, MP_CAP),
		"raw_ap": raw_ap, "raw_mp": raw_mp,
		"ap_greyed": maxi(raw_ap - AP_CAP, 0), "mp_greyed": maxi(raw_mp - MP_CAP, 0),
	}


## What a fight uses from worn gear: part numbers × fuse multiplier (not
## crit), plus set bonuses. Every set is resist_all, so part resist counts
## against every element. `class_id` drops pieces that class cannot wear.
## `pvp` (Koliseo): part numbers count as +0 and Ultra lines turn on; the
## Rare +5 gates still read the real plus. PC fights pass pvp = false.
static func combat_stats(raw_worn: Variant, class_id: String = "", pvp: bool = false, extra_ap: int = 0) -> Dictionary:
	var worn := clean_worn(raw_worn)
	if class_id != "":
		var filtered: Array = []
		for entry in worn:
			if can_wear(family_of(str(entry["item_id"])), class_id):
				filtered.append(entry)
		worn = filtered
	var gates := gate_of_worn(worn)
	if pvp:
		for entry in worn:
			entry["plus"] = 0
	var stats := stats_of_worn(worn, pvp)
	var raw_ap := BASE_AP + int(stats.get("ap", 0)) + int(gates["ap"]) + maxi(extra_ap, 0)
	var raw_mp := BASE_MP + int(stats.get("mp", 0)) + int(gates["mp"])
	var hp_flat := 0
	var mastery := int(stats.get("mastery", 0))
	var init := int(stats.get("init", 0))
	var resist := int(stats.get("resist", 0))
	var crit := int(stats.get("crit", 0))
	var extras := {
		"crit_dmg": 0, "melee_pct": 0, "heal_pct": 0, "crit_heal": 0, "bow_range": 0,
		"extra_mark": 0, "unbound": 0, "push_flat": 0, "ward_shield": 0, "back_pct": 0,
	}
	for entry in worn:
		var item_id := str(entry["item_id"])
		var st := part_stats(item_id, int(entry["plus"]))
		hp_flat += int(st["hp"])
		mastery += int(st["mastery"])
		init += int(st["init"])
		resist += int(st["resist"])
		if pvp or not is_ultra(family_of(item_id)):
			crit += int(st["crit"])
			var part: Dictionary = PARTS.get(item_id, {})
			for key in extras.keys():
				extras[key] = int(extras[key]) + int(part.get(key, 0))
	var out := {
		"hp_flat": hp_flat,
		"hp_pct": int(stats.get("hp_pct", 0)),
		"mastery": mastery,
		"resist": resist,
		"crit": mini(crit, CRIT_CAP),
		"init": init,
		"ap": mini(raw_ap, AP_CAP),
		"mp": mini(raw_mp, MP_CAP),
		"raw_ap": raw_ap,
		"raw_mp": raw_mp,
		"first_hit": int(stats.get("first_hit", 0)),
		"melee": int(stats.get("melee", 0)),
		"heal_flat": int(stats.get("heal_flat", 0)),
		"first_back": int(stats.get("first_back", 0)),
		"guard_flat": int(stats.get("guard_flat", 0)),
		"start_aegis": int(stats.get("start_aegis", 0)),
		"worn": worn,
	}
	for key in extras.keys():
		out[key] = int(extras[key])
	out["back_pct"] = int(out["back_pct"]) + int(stats.get("back_pct", 0))
	out["ward_shield"] = int(out["ward_shield"]) + int(stats.get("ward_shield", 0))
	for key in [
		"push_guard", "no_back", "crit_ward", "free_vault", "fade_cut", "detonate_strip",
		"berserk", "hit_slow", "shoulder_strip", "heal_suppress", "shield_burst",
		"long_fade", "cleanse_stun", "cheat_death", "rekindle_ultra",
	]:
		out[key] = int(stats.get(key, 0))
	return out


## Max HP for a body: (base + level HP + part HP) × (1 + set HP%).
static func max_hp(base_hp: int, level_hp: int, stats: Dictionary) -> int:
	return roundi(float(base_hp + level_hp + int(stats.get("hp_flat", 0))) * (1.0 + float(stats.get("hp_pct", 0)) / 100.0))


## [{family, name, pieces, tier, text}] for every reached tier.
static func active_bonuses(raw_worn: Variant) -> Array:
	var out: Array = []
	var counts := worn_counts(clean_worn(raw_worn))
	var order: Array = []
	order.append_array(FAMILY_ORDER)
	order.append_array(ULTRA_ORDER)
	for fam in order:
		var pieces := int(counts.get(fam, 0))
		if pieces <= 0:
			continue
		var bonus: Dictionary = FAMILIES[fam]["bonus"]
		for tier in [2, 4, 5]:
			if pieces >= tier:
				out.append({"family": fam, "name": str(FAMILIES[fam]["name"]), "pieces": pieces, "tier": tier, "text": str(bonus[tier]), "koliseo_only": is_ultra(fam)})
	return out


## Tier weights for one chest. ★2 uses ★1, ★4 uses ★3. `boss` is the boss row.
static func drop_weights(star: int, boss: bool = false) -> Dictionary:
	if boss:
		return BOSS_DROP_WEIGHTS.duplicate()
	var key := 5
	if star <= 2:
		key = 1
	elif star <= 4:
		key = 3
	return (DROP_WEIGHTS[key] as Dictionary).duplicate()


## Sets of one rarity, in FAMILY_ORDER. Ultra is never in this list.
static func families_of_rarity(rarity: String) -> Array:
	var pool: Array = []
	for fam in FAMILY_ORDER:
		if str(FAMILIES[fam]["rarity"]) == rarity:
			pool.append(fam)
	return pool


## Rarity for a 0..1 roll. Walks Normal, then Rare, then Legendary.
static func roll_tier(weights: Dictionary, roll: float) -> String:
	var total := 0
	for rarity in RARITIES:
		total += int(weights.get(rarity, 0))
	if total <= 0:
		return ""
	var at := clampf(roll, 0.0, 0.999999) * float(total)
	for rarity in RARITIES:
		at -= float(int(weights.get(rarity, 0)))
		if at < 0.0:
			return rarity
	return RARITIES[RARITIES.size() - 1]


static func roll_family(rarity: String, roll: float) -> String:
	var pool := families_of_rarity(rarity)
	if pool.is_empty():
		return ""
	return str(pool[mini(int(clampf(roll, 0.0, 0.999999) * pool.size()), pool.size() - 1)])


## Slot for a 0..1 roll (weapon 18%, every other slot 20.5%).
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


## One piece from a tier-weight row: tier, then a set of that tier (equal
## odds), then a weighted slot. Three rng.randf() calls, always.
static func roll_piece(weights: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var r_tier := rng.randf()
	var r_fam := rng.randf()
	var r_slot := rng.randf()
	var rarity := roll_tier(weights, r_tier)
	var fam := roll_family(rarity, r_fam)
	if fam == "":
		return {}
	var slot := weighted_slot(r_slot)
	return {"rarity": rarity, "family": fam, "slot": slot, "item_id": item_id_for(fam, slot), "plus": CHEST_PLUS}


## One dungeon chest piece at a star (or the boss row).
static func roll_chest(star: int, boss: bool, rng: RandomNumberGenerator) -> Dictionary:
	return roll_piece(drop_weights(star, boss), rng)


## A chest of one fixed tier (world fights, missions, the Mystery Box).
static func roll_tier_chest(rarity: String, rng: RandomNumberGenerator) -> Dictionary:
	var weights := {"Normal": 0, "Rare": 0, "Legendary": 0}
	weights[rarity] = 100
	return roll_piece(weights, rng)


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


## Rows are {item_id, plus}. Same item id and same plus, below the cap.
static func can_fuse(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.is_empty() or b.is_empty():
		return {"ok": false, "reason": "no_item"}
	if not is_valid_item_id(str(a.get("item_id", ""))):
		return {"ok": false, "reason": "not_gear"}
	if str(a.get("item_id", "")) != str(b.get("item_id", "")):
		return {"ok": false, "reason": "different_item"}
	if int(a.get("plus", 0)) != int(b.get("plus", 0)):
		return {"ok": false, "reason": "different_plus"}
	if int(a.get("plus", 0)) >= PLUS_CAP:
		return {"ok": false, "reason": "plus_cap"}
	return {"ok": true, "reason": ""}


## What the paper doll needs from a worn piece: set id, part id, slot, plus.
## Empty when the item is not a set part (an epic, a relic, a ring).
static func look_of(item_id: String, plus: int = 0) -> Dictionary:
	if not is_valid_item_id(item_id):
		return {}
	var fam := family_of(item_id)
	return {
		"set_id": fam,
		"part_id": item_id,
		"slot": slot_of(item_id),
		"plus": clampi(plus, 0, PLUS_CAP),
		"rarity": rarity_of(fam),
		"owner": owner_of(fam),
	}
