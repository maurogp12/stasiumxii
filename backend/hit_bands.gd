class_name HitBands
extends RefCounted

## Locked Chebyshev hit percents (Mauro / Rules Keeper). Single source of truth.
## Combat resolve and aim chrome both call chance(). Dist 0 shares the dist-1
## melee percent (self casts). Dist > MAX_DISTANCE returns -1: not a percent.

const MAX_DISTANCE := 14
const BY_DISTANCE := {
	1: 90,
	2: 80,
	3: 80,
	4: 75,
	5: 75,
	6: 70,
	7: 70,
	8: 70,
	9: 65,
	10: 60,
	11: 55,
	12: 50,
	13: 45,
	14: 40,
}


static func chance(distance: int) -> int:
	if distance == 0:
		return int(BY_DISTANCE[1])
	if BY_DISTANCE.has(distance):
		return int(BY_DISTANCE[distance])
	return -1
