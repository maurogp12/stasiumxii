extends RefCounted

## Live elevation step helper. Ported from proto/elevation/elevation_cost.gd (reference).
## Locked: uphill +1 MP per full level; leftover half-level also +1. Downhill +0.
## Max climb 1.0. Max drop 2.0.
## Hit bands / facing / spell LoS do not read this. Stairs / ramps / flying stay Open.

const MAX_CLIMB := 1.0
const MAX_DROP := 2.0
const EPS := 0.0001


static func analyze(from_elev: float, to_elev: float) -> Dictionary:
	var delta := to_elev - from_elev
	var out := {
		"delta": delta,
		"legal": true,
		"reason": "",
		"climb_mp": 0,
	}
	if delta > MAX_CLIMB + EPS:
		out["legal"] = false
		out["reason"] = "climb_too_steep"
		return out
	if -delta > MAX_DROP + EPS:
		out["legal"] = false
		out["reason"] = "drop_too_far"
		return out
	if delta > EPS:
		# Locked: +1 per full level; half-level (0.5) also +1.
		out["climb_mp"] = maxi(ceili(delta), 1)
	return out


static func climb_mp(from_elev: float, to_elev: float) -> int:
	return int(analyze(from_elev, to_elev).get("climb_mp", 0))


static func is_legal(from_elev: float, to_elev: float) -> bool:
	return bool(analyze(from_elev, to_elev).get("legal", false))
