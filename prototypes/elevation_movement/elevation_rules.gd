extends RefCounted
class_name ElevationRules

## Phase B+ prototype. Proposed — not Locked.
## Isolated from Phase A CombatSim / main.tscn flat Manhattan walk.
##
## Proposed (Director starters):
##   Uphill: +1 MP per full elevation level; half-level (+0.5) counts as +1
##   Downhill: +0
##   Equal elevation: terrain cost only
##   Max climb: 1.0; Max drop: 2.0 (illegal beyond)

const MAX_CLIMB: float = 1.0
const MAX_DROP: float = 2.0
const EPS: float = 0.0001


static func elevation_delta(from_elev: float, to_elev: float) -> float:
	return to_elev - from_elev


static func climb_amount(from_elev: float, to_elev: float) -> float:
	return maxf(elevation_delta(from_elev, to_elev), 0.0)


static func drop_amount(from_elev: float, to_elev: float) -> float:
	return maxf(-elevation_delta(from_elev, to_elev), 0.0)


## Proposed: +1 MP per full level; a +0.5 half-level also costs +1 (ceil).
## Downhill and equal elevation add 0.
static func uphill_surcharge(from_elev: float, to_elev: float) -> int:
	var climb := climb_amount(from_elev, to_elev)
	if climb <= EPS:
		return 0
	# ceili(1.0) is 1; subtract EPS so 1.0000001 does not become 2.
	return ceili(climb - EPS)


static func is_legal_step(from_elev: float, to_elev: float) -> bool:
	return step_reject_reason(from_elev, to_elev) == ""


static func step_reject_reason(from_elev: float, to_elev: float) -> String:
	var climb := climb_amount(from_elev, to_elev)
	var drop := drop_amount(from_elev, to_elev)
	# Proposed: inclusive caps. 1.0 climb and 2.0 drop are legal; beyond is not.
	if climb > MAX_CLIMB + EPS:
		return "climb_too_steep"
	if drop > MAX_DROP + EPS:
		return "drop_too_steep"
	return ""
