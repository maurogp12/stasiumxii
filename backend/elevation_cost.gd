extends RefCounted

## Live elevation step helper. Ported from proto/elevation/elevation_cost.gd (reference).
## Locked integer z: climb/drop in units of 1. Uphill +1 MP per z step. Downhill +0.
## Max climb 1. Max drop 2. No leftover half-steps. No z1→z3 hop (climb 2).
## Hit bands / facing / spell LoS do not read this. Stairs / ramps / flying stay Open.

const MAX_CLIMB := 1
const MAX_DROP := 2


static func analyze(from_elev: Variant, to_elev: Variant) -> Dictionary:
	var src := as_z(from_elev)
	var dest := as_z(to_elev)
	var delta := dest - src
	var out := {
		"delta": delta,
		"legal": true,
		"reason": "",
		"climb_mp": 0,
	}
	if delta > MAX_CLIMB:
		out["legal"] = false
		out["reason"] = "climb_too_steep"
		return out
	if -delta > MAX_DROP:
		out["legal"] = false
		out["reason"] = "drop_too_far"
		return out
	if delta > 0:
		out["climb_mp"] = delta
	return out


static func climb_mp(from_elev: Variant, to_elev: Variant) -> int:
	return int(analyze(from_elev, to_elev).get("climb_mp", 0))


static func is_legal(from_elev: Variant, to_elev: Variant) -> bool:
	return bool(analyze(from_elev, to_elev).get("legal", false))


static func as_z(value: Variant) -> int:
	if value == null:
		return 0
	return int(round(float(value)))
