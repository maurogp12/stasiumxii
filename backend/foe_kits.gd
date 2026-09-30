extends RefCounted

## Stasis monster spells as data (Mauro's "Stasis bosses + room-1 packs" +
## "Boss AP 7" sheets and the implementer answers, 29 Sep 2026). Soft Lock:
## verbs, shapes and AP are the sheet's; damage numbers are the sheet's base
## at Stasis 1 and scale with the star (StasisCatalog.dmg_mult). Trash hits
## use the room's provisional attack base (damage 0 here = use it). HP / EV
## stay Open.
##
## Shapes (all Chebyshev, one-tile bodies):
##   melee   target at range min..max (1 = adjacent)
##   shot    target at min..max, needs line of sight
##   dash    target at exactly 2: step 1 onto a free tile beside it, then hit
##   cone    `size` rows toward a cardinal facing, row k is 2k-1 wide (AOE)
##   line    1..size tiles along a cardinal facing, stops at walls (AOE)
##   radius  every tile at Chebyshev 1 around the caster (AOE)
##   pads    every Charged pad and every ground tile next to one (AOE)
##   self    the caster (Ward)
##   step    walk 1 tile (AP, not MP), voluntary walk gates
## Effects: push N (away), pull N (toward the caster), frozen_on_ice, ward N.
## AOE spells have cd 2 = use, skip a turn, use again (answers: "cd 1").

const SPELLS := {
	# Room 1 trash (sheet ids mob.brute / mob.skirmish / mob.caster).
	"foe.brute_hit": {"name": "Hit", "ap": 3, "shape": "melee", "min": 1, "max": 1, "damage": 0, "element": "Earth"},
	"foe.skirmish_poke": {"name": "Poke", "ap": 3, "shape": "melee", "min": 1, "max": 2, "damage": 0, "element": "Earth", "push": 1},
	"foe.caster_bolt": {"name": "Bolt", "ap": 3, "shape": "shot", "min": 3, "max": 7, "damage": 0, "element": "door", "bolt": true},
	# Sheaf Sovereign (Crosshaven): all melee.
	"sheaf.thresh": {"name": "Thresh", "ap": 3, "shape": "melee", "min": 1, "max": 1, "damage": 16, "element": "Earth"},
	"sheaf.reap": {"name": "Reap Cone", "ap": 4, "shape": "cone", "size": 2, "damage": 12, "element": "Earth", "aoe": true},
	"sheaf.lunge": {"name": "Lunge", "ap": 3, "shape": "dash", "min": 2, "max": 2, "damage": 12, "element": "Earth"},
	"sheaf.wall": {"name": "Sheaf Wall", "ap": 2, "shape": "self", "ward": 8, "cd": 2},
	# Tide-Lord Brineclaw (Brinewake): melee body, range spells.
	"brine.claw": {"name": "Claw", "ap": 3, "shape": "melee", "min": 1, "max": 1, "damage": 14, "element": "Neutral"},
	"brine.bolt": {"name": "Brine Bolt", "ap": 3, "shape": "shot", "min": 3, "max": 7, "damage": 12, "element": "Water", "bolt": true},
	"brine.fan": {"name": "Tide Fan", "ap": 4, "shape": "cone", "size": 3, "damage": 10, "element": "Water", "aoe": true},
	"brine.hook": {"name": "Hook", "ap": 3, "shape": "shot", "min": 2, "max": 5, "damage": 6, "element": "Water", "pull": 1, "cd": 2, "bolt": true},
	# Slagheart (Slagcrown): melee body, melee spells.
	"slag.slam": {"name": "Slam", "ap": 3, "shape": "melee", "min": 1, "max": 1, "damage": 16, "element": "Fire"},
	"slag.cleave": {"name": "Magma Cleave", "ap": 4, "shape": "cone", "size": 2, "damage": 12, "element": "Fire", "aoe": true},
	"slag.shoulder": {"name": "Shoulder", "ap": 3, "shape": "dash", "min": 1, "max": 2, "damage": 8, "element": "Fire", "push": 1},
	"slag.burst": {"name": "Cinder Burst", "ap": 4, "shape": "radius", "damage": 12, "element": "Fire", "aoe": true},
	# Serra White-Spire Regent (Windmere): ranged body, range spells.
	"serra.shard": {"name": "Shard", "ap": 3, "shape": "shot", "min": 3, "max": 8, "damage": 14, "element": "Air", "bolt": true},
	"serra.fan": {"name": "White Fan", "ap": 4, "shape": "line", "size": 5, "damage": 10, "element": "Air", "aoe": true},
	"serra.pin": {"name": "Frost Pin", "ap": 3, "shape": "shot", "min": 3, "max": 7, "damage": 8, "element": "Air", "frozen_on_ice": true, "bolt": true},
	"serra.step": {"name": "Retreat Step", "ap": 2, "shape": "step"},
	# High Coilspire (Stormspire): ranged body, range spells.
	"coil.arc": {"name": "Arc", "ap": 3, "shape": "shot", "min": 3, "max": 8, "damage": 14, "element": "Air", "bolt": true},
	"coil.pulse": {"name": "Grid Pulse", "ap": 4, "shape": "pads", "damage": 10, "element": "Air", "aoe": true},
	"coil.lash": {"name": "Lash", "ap": 3, "shape": "shot", "min": 2, "max": 6, "damage": 6, "element": "Air", "push": 1, "bolt": true},
	"coil.step": {"name": "Coil Step", "ap": 2, "shape": "step"},
}

## Boss kits by door (map id).
const BOSS_KITS := {
	"crosshaven": ["sheaf.thresh", "sheaf.reap", "sheaf.lunge", "sheaf.wall"],
	"brinewake": ["brine.claw", "brine.bolt", "brine.fan", "brine.hook"],
	"slagcrown": ["slag.slam", "slag.cleave", "slag.shoulder", "slag.burst"],
	"windmere": ["serra.shard", "serra.fan", "serra.pin", "serra.step"],
	"stormspire": ["coil.arc", "coil.pulse", "coil.lash", "coil.step"],
}
## Ranged bodies never walk into 0–1 when a shot is legal; they keep 3+.
const RANGED_BOSS := {"windmere": true, "stormspire": true}
const ROLE_KITS := {
	"brute": ["foe.brute_hit"],
	"skirmish": ["foe.skirmish_poke"],
	"caster": ["foe.caster_bolt"],
}
## Caster bolt element per door (the door's element; bolt VFX skin).
const DOOR_ELEMENT := {
	"crosshaven": "Earth",
	"brinewake": "Water",
	"slagcrown": "Fire",
	"windmere": "Air",
	"stormspire": "Air",
}
## AOE cooldown: use, skip one of the caster's turns, use again.
const AOE_CD := 2
## Boss AP (sheet "Boss AP 7"): Stasis 1–4 AP 7, Stasis 5 AP 8. MP 3.
const BOSS_AP := 7
const BOSS_AP_STAR5 := 8
const CASTER_HP_PCT := 70


static func spell(id: String) -> Dictionary:
	return SPELLS.get(id, {})


static func is_foe_spell(id: String) -> bool:
	return SPELLS.has(id)


static func is_aoe(id: String) -> bool:
	return bool(spell(id).get("aoe", false))


static func cooldown(id: String) -> int:
	var def := spell(id)
	if def.has("cd"):
		return int(def["cd"])
	return AOE_CD if bool(def.get("aoe", false)) else 0


static func boss_ap(star: int) -> int:
	return BOSS_AP_STAR5 if star >= 5 else BOSS_AP


## Cone rows toward `dir` from `origin`: row k (1..size) is 2k-1 wide.
static func cone_cells(origin: Vector2i, dir: Vector2i, size: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var side := Vector2i(-dir.y, dir.x)
	for k in range(1, size + 1):
		var center := origin + dir * k
		for w in range(-(k - 1), k):
			out.append(center + side * w)
	return out


static func radius_cells(origin: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dy != 0:
				out.append(origin + Vector2i(dx, dy))
	return out
