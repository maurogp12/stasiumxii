extends RefCounted

## Walk grid from the city layout: every passable cell of the plan is a node
## (8-way, no corner cutting past blocked cells), A* finds the route, then
## line-of-sight string pulling turns the cell staircase into a few straight
## legs, so the hero glides along smooth lines instead of grid steps.
## Pure (no scene): the same layout rules as the 2D city (TileCity.passable),
## so 2D and 3D agree on what is walkable.

var plan
var astar := AStarGrid2D.new()
var shut: Dictionary = {}   ## cells closed on top of the layout (e.g. a shut gate)


func setup(p) -> void:
	plan = p
	astar.region = Rect2i(0, 0, plan.width, plan.height)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in plan.height:
		for x in plan.width:
			var c := Vector2i(x, y)
			if not plan.passable(c):
				astar.set_point_solid(c, true)


func walkable(c: Vector2i) -> bool:
	return astar.is_in_boundsv(c) and not astar.is_point_solid(c)


## Cell route from a to b (b snapped to the nearest walkable cell).
func cell_path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	if not walkable(a):
		a = plan.nearest_passable(a, 6)
	if not walkable(b):
		b = plan.nearest_passable(b, 6)
	if not walkable(a) or not walkable(b):
		return []
	return astar.get_id_path(a, b)


## World route (metres, Vector2 on the ground) from a to b, smoothed.
func world_path(a: Vector2, b: Vector2) -> Array:
	var cells := cell_path(plan.world_to_cell(a), plan.world_to_cell(b))
	if cells.is_empty():
		return []
	var pts: Array = [a]
	for i in range(1, cells.size() - 1):
		pts.append(plan.cell_center(cells[i]))
	var end_c: Vector2i = cells[cells.size() - 1]
	pts.append(b if plan.world_to_cell(b) == end_c else plan.cell_center(end_c))
	return smooth(pts)


## Drop every point the walker can skip with a clear straight line.
func smooth(pts: Array) -> Array:
	if pts.size() <= 2:
		return pts
	var out: Array = [pts[0]]
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not line_clear(pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out


## True when the straight segment only crosses walkable cells, keeping a
## small body radius clear of blocked cells.
func line_clear(a: Vector2, b: Vector2, radius := 0.35) -> bool:
	var step: float = plan.cell_m * 0.25
	var n := maxi(1, ceili(a.distance_to(b) / step))
	var side := (b - a).normalized().orthogonal() * radius
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		for q in [p, p + side, p - side]:
			if not walkable(plan.world_to_cell(q)):
				return false
	return true


## Every cell reachable from `from` (flood over the walk grid, 4-way).
func reach(from: Vector2i) -> Dictionary:
	var seen := {from: true}
	if not walkable(from):
		return seen
	var q: Array[Vector2i] = [from]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and walkable(n):
				seen[n] = true
				q.append(n)
	return seen
