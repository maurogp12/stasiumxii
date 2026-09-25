class_name HitBands
extends RefCounted

## Locked Chebyshev hit percents through distance 8. Single source of truth.
## Combat resolve and aim chrome both call chance(). Dist 0 shares the dist-1
## melee percent (self casts). Dist >= OPEN_FROM is Open: -1 is not a percent.

const MAX_DISTANCE := 8
const OPEN_FROM := 9
const BY_DISTANCE := {
	1: 90,
	2: 80,
	3: 80,
	4: 75,
	5: 75,
	6: 70,
	7: 70,
	8: 70,
}


static func chance(distance: int) -> int:
	if distance == 0:
		return int(BY_DISTANCE[1])
	if BY_DISTANCE.has(distance):
		return int(BY_DISTANCE[distance])
	return -1


static func is_open(distance: int) -> bool:
	return distance >= OPEN_FROM
