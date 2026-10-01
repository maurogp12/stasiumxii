class_name CrosshavenPick
extends RefCounted

## VIEW ONLY. Screen-to-cell picking and cell geometry for the Crosshaven world scene.
## Uses the same projection as `BoardVisualSort.cell_to_local`: 64×32 diamonds,
## +x screen south-east, +y screen south-west, 10 px per height step.

const HALF_W := 32.0
const HALF_H := 16.0


static func cell_center(zone: WorldZone, cell: Vector2i) -> Vector2:
	return BoardVisualSort.cell_to_local(cell, float(zone.height_at(cell)))


## Diamond corners (N, E, S, W) of a cell lifted by `steps` height steps.
static func diamond(cell: Vector2i, steps: float) -> PackedVector2Array:
	var c := BoardVisualSort.cell_to_local(cell, steps)
	return PackedVector2Array([
		c + Vector2(0, -HALF_H),
		c + Vector2(HALF_W, 0),
		c + Vector2(0, HALF_H),
		c + Vector2(-HALF_W, 0),
	])


## Front-most cell whose lifted top diamond contains `point` (zone-local pixels).
## Returns Vector2i(-1, -1) when the point is off the zone.
static func pick(zone: WorldZone, point: Vector2, max_height: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_rank := -1
	for h in range(max_height + 1):
		var q := point + Vector2(0, float(h) * BoardVisualSort.ELEVATION_PIXELS)
		var u := (q.x / HALF_W + q.y / HALF_H) * 0.5
		var v := (q.y / HALF_H - q.x / HALF_W) * 0.5
		var cell := Vector2i(roundi(u), roundi(v))
		if not zone.in_bounds(cell):
			continue
		if zone.height_at(cell) != h:
			continue
		var rank := (cell.x + cell.y) * 64 + h
		if rank > best_rank:
			best_rank = rank
			best = cell
	return best


static func max_height(zone: WorldZone) -> int:
	var top := 0
	for y in zone.height:
		for x in zone.width:
			top = maxi(top, zone.height_at(Vector2i(x, y)))
	return top


## Pixel bounds of the whole chunk, including lifted tiles.
static func zone_rect(zone: WorldZone) -> Rect2:
	var left := -float(zone.height - 1) * HALF_W - HALF_W
	var right := float(zone.width - 1) * HALF_W + HALF_W
	var top := -HALF_H - float(max_height(zone)) * BoardVisualSort.ELEVATION_PIXELS
	var bottom := float(zone.width + zone.height - 2) * HALF_H + HALF_H
	return Rect2(left, top, right - left, bottom - top)


## Display name for a chunk: its first point of interest, else the id.
static func zone_name(zone: WorldZone) -> String:
	for poi in zone.points_of_interest:
		if typeof(poi) == TYPE_DICTIONARY and str(poi.get("name", "")) != "":
			return str(poi["name"])
	return zone.zone_id
