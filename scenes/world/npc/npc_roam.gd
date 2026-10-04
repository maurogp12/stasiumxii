extends RefCounted

## Where a moving NPC may go. Pure grid logic, no nodes. Preload. No global class.
## Spec 4.5a Movement:
##   townsfolk wander within 4–6 cells of home and pause at props;
##   wardens walk a slow patrol around their square;
##   everyone else stays at the post and turns to face the player.
## Walkers use passable cells only. The world passes `forbidden` cells (exits
## and their first ring, gates, doors and other points of interest and the
## spawn with one cell of clearance, and the cells touching another NPC's
## post) and `no_dwell` cells (closer than 3 cells to another NPC's post).
## A walker may pass through a no_dwell cell but never pauses there, so every
## place an NPC stands still keeps the 4.5 spacing.

const POST := "post"
const PATROL := "patrol"
const WANDER := "wander"

const WANDER_ROLES: Array[String] = ["farmer", "woodcutter", "fisher", "smith", "hermit", "coil_engineer"]
const PATROL_ROLES: Array[String] = ["warden"]

## Townsfolk stay within this many walk cells (Manhattan) of home. Spec: 4–6.
const WANDER_RADIUS := 6
## Wardens walk a loop this far out from their post.
const PATROL_RADIUS := 3

const ORTHO: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const RING: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
	Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),
]


static func behaviour_for(role: String) -> String:
	if WANDER_ROLES.has(role):
		return WANDER
	if PATROL_ROLES.has(role):
		return PATROL
	return POST


static func radius_for(behaviour: String) -> int:
	if behaviour == WANDER:
		return WANDER_RADIUS
	if behaviour == PATROL:
		return PATROL_RADIUS
	return 0


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Column gap or row gap, whichever is larger (the 4.5 spacing measure).
static func cells_apart(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Cells reachable from home by orthogonal steps over passable, non-forbidden
## cells, never farther than `radius` (Manhattan) from home. Home is always in.
static func area(zone: WorldZone, home: Vector2i, radius: int, forbidden: Dictionary) -> Dictionary:
	var out := {home: true}
	if zone == null or radius <= 0:
		return out
	var queue: Array[Vector2i] = [home]
	var head := 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		for dir in ORTHO:
			var next: Vector2i = at + dir
			if out.has(next):
				continue
			if manhattan(next, home) > radius:
				continue
			if not usable(zone, next, forbidden):
				continue
			out[next] = true
			queue.append(next)
	return out


static func usable(zone: WorldZone, cell: Vector2i, forbidden: Dictionary) -> bool:
	if zone == null or not zone.in_bounds(cell):
		return false
	if not zone.passable_at(cell):
		return false
	if not zone.exit_link(cell).is_empty():
		return false
	return not forbidden.has(cell)


## True when standing on `cell` leaves its passable neighbours connected
## around it, so a paused NPC never cuts a lane in two.
static func dwell_ok(zone: WorldZone, cell: Vector2i) -> bool:
	if zone == null:
		return false
	var open: Array[bool] = []
	for off in RING:
		var c: Vector2i = cell + off
		open.append(zone.in_bounds(c) and zone.passable_at(c))
	var groups := 0
	var touches := 0
	# Walk the ring of 8; orthogonal neighbours that are open must all sit in
	# one run of open ring cells (diagonal corners join them).
	var seen := []
	seen.resize(8)
	for i in 8:
		seen[i] = false
	for i in [1, 3, 5, 7]:
		if not open[i]:
			continue
		touches += 1
		if seen[i]:
			continue
		groups += 1
		var stack: Array[int] = [i]
		seen[i] = true
		while not stack.is_empty():
			var k: int = stack.pop_back()
			for step in [-1, 1]:
				var j: int = (k + step + 8) % 8
				if seen[j] or not open[j]:
					continue
				# A diagonal ring cell joins two orthogonals only when it is open.
				seen[j] = true
				stack.append(j)
	return touches <= 1 or groups == 1


## BFS path inside `allowed` (Dictionary of cells). Excludes `from`.
## Empty when there is no way.
static func path(allowed: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if from == to or not allowed.has(to):
		return out
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		if at == to:
			break
		for dir in ORTHO:
			var next: Vector2i = at + dir
			if prev.has(next) or not allowed.has(next):
				continue
			prev[next] = at
			queue.append(next)
	if not prev.has(to):
		return out
	var walk: Vector2i = to
	while walk != from:
		out.push_front(walk)
		walk = prev[walk]
	return out


## Pause spots for a wandering NPC: cells in its area beside a prop (field
## fence, woodpile, dock, anvil, stall...), plus home. Each spot carries the
## step letter that faces the prop (empty at home).
static func pause_spots(zone: WorldZone, home: Vector2i, allowed: Dictionary, no_dwell: Dictionary = {}) -> Array:
	var spots: Array = [{"cell": home, "face": ""}]
	if zone == null:
		return spots
	var prop_cells := {}
	for prop in zone.props:
		var rec: Dictionary = prop
		for foot in rec.get("footprint", []):
			prop_cells[Vector2i(int(foot["x"]), int(foot["y"]))] = true
	var cells: Array = allowed.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var open_ground: Array = []
	for cell in cells:
		var c: Vector2i = cell
		if c == home or manhattan(c, home) < 2 or no_dwell.has(c):
			continue
		if not dwell_ok(zone, c):
			continue
		var face := ""
		for dir in ORTHO:
			if prop_cells.has(c + dir):
				face = step_letter(dir)
				break
		if face == "":
			# Field, shore or pond edge: work facing the field or the water.
			for dir in ORTHO:
				var t := zone.terrain_at(c + dir)
				if t.begins_with("farm_") or t == "water":
					face = step_letter(dir)
					break
		if face != "":
			spots.append({"cell": c, "face": face})
		elif manhattan(c, home) >= 3:
			open_ground.append(c)
	# Few props in reach: work on open ground too, spread over the area.
	if spots.size() < 3 and not open_ground.is_empty():
		var step := maxi(1, open_ground.size() / 3)
		var i := 0
		while i < open_ground.size() and spots.size() < 4:
			var c: Vector2i = open_ground[i]
			spots.append({"cell": c, "face": face_toward(home, c)})
			i += step
	return spots


## Patrol stops around the post: one per diagonal quadrant where one fits,
## in loop order, starting and ending at home.
static func patrol_stops(zone: WorldZone, home: Vector2i, allowed: Dictionary, no_dwell: Dictionary = {}) -> Array[Vector2i]:
	var stops: Array[Vector2i] = [home]
	var quads: Array[Vector2i] = [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for q in quads:
		var best := Vector2i(-9999, -9999)
		var best_score := -1
		for cell in allowed.keys():
			var c: Vector2i = cell
			var d := c - home
			if signi(d.x) != q.x and d.x != 0:
				continue
			if signi(d.y) != q.y and d.y != 0:
				continue
			if d.x == 0 and d.y == 0:
				continue
			var m := manhattan(c, home)
			if m < 2 or no_dwell.has(c):
				continue
			if not dwell_ok(zone, c):
				continue
			# Prefer the far corner of the quadrant, then a balanced diagonal.
			var score := m * 10 - absi(absi(d.x) - absi(d.y))
			if score > best_score:
				best_score = score
				best = c
		if best_score >= 0 and not stops.has(best):
			stops.append(best)
	return stops


static func step_letter(step: Vector2i) -> String:
	if step.x > 0:
		return "e"
	if step.x < 0:
		return "w"
	if step.y > 0:
		return "s"
	if step.y < 0:
		return "n"
	return ""


## Letter that faces from `a` toward `b` along the larger axis.
static func face_toward(a: Vector2i, b: Vector2i) -> String:
	var d := b - a
	if d == Vector2i.ZERO:
		return ""
	if absi(d.x) >= absi(d.y):
		return "e" if d.x > 0 else "w"
	return "s" if d.y > 0 else "n"
