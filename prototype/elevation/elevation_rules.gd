extends RefCounted
class_name ElevationRules

## Proposed (not Locked) elevation MP helpers for Phase B+.
## CombatSim.submit(move) does not call this. Phase A walk stays flat Manhattan.

## Proposed: cannot climb more than one full level in a single ortho step.
const MAX_CLIMB := 1.0
## Proposed: cannot drop more than two full levels in a single ortho step.
const MAX_DROP := 2.0
const FULL_LEVEL := 1.0
const HALF_STEP := 0.5
## Proposed: +1 MP per full level climbed.
const UPHILL_MP_PER_FULL_LEVEL := 1
## Proposed: a leftover half-step up also costs +1 MP.
const HALF_STEP_UPHILL_MP := 1
## Proposed: downhill is free (0 extra MP). Flat is also 0.
const DOWNHILL_MP := 0


static func elev_delta(from_elev: float, to_elev: float) -> float:
	return to_elev - from_elev


static func climb_allowed(delta: float) -> bool:
	if delta <= 0.0:
		return true
	return delta < MAX_CLIMB or is_equal_approx(delta, MAX_CLIMB)


static func drop_allowed(delta: float) -> bool:
	if delta >= 0.0:
		return true
	return delta > -MAX_DROP or is_equal_approx(delta, -MAX_DROP)


## Proposed uphill MP: +1 per full level, +1 for a leftover half step.
## Downhill / flat: 0. Does not apply max climb/drop (see MovementCost).
static func elevation_mp(from_elev: float, to_elev: float) -> int:
	var delta := elev_delta(from_elev, to_elev)
	if delta <= 0.0 or is_zero_approx(delta):
		return DOWNHILL_MP
	var full_levels := int(floor(delta + 0.0001))
	var remainder := delta - float(full_levels)
	var half := HALF_STEP_UPHILL_MP if remainder > HALF_STEP - 0.0001 else 0
	return full_levels * UPHILL_MP_PER_FULL_LEVEL + half


static func climb_or_drop_reason(from_elev: float, to_elev: float) -> String:
	var delta := elev_delta(from_elev, to_elev)
	if not climb_allowed(delta):
		return "climb_exceeded"
	if not drop_allowed(delta):
		return "drop_exceeded"
	return ""
