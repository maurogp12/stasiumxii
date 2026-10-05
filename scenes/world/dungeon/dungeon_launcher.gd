extends RefCounted

## Hands a dungeon run from the world to the room scene and back.
## Preload. No global class. (Spec WP7 names a DungeonLauncher.enter stub;
## this is that launcher with the run built.)
##
## enter(): checks the run can start, keeps where to come back to (the door
## cell), then swaps to the dungeon scene. finish(): keeps the outcome and
## swaps back to the world, which takes it with take_outcome() and stands
## the hero on the door cell. Either way the hero returns to the door.
## dry_run (tests) records the scene it would open without swapping.

const Run := preload("res://backend/pc_dungeon_run.gd")
const RUN_SCENE := "res://scenes/world/dungeon/dungeon_run.tscn"
const WORLD_SCENE := "res://scenes/world/crosshaven/crosshaven_world.tscn"

static var pending: Dictionary = {}
static var outcome: Dictionary = {}
static var dry_run := false
static var last_scene := ""


## ctx: level, class_id, name, star (1-5), return_zone, return_cell, autoplay, movie.
static func enter(tree: SceneTree, dungeon_id: String, ctx: Dictionary) -> Dictionary:
	var made: Dictionary = Run.create(dungeon_id, int(ctx.get("level", 1)), str(ctx.get("class_id", "")), str(ctx.get("name", "")), int(ctx.get("star", 1)))
	if not bool(made.get("ok", false)):
		return {"ok": false, "reason": "not_ready", "errors": made.get("errors", [])}
	pending = ctx.duplicate(true)
	pending["dungeon_id"] = dungeon_id
	outcome = {}
	_swap(tree, RUN_SCENE)
	return {"ok": true, "reason": "", "scene": RUN_SCENE}


static func take_pending() -> Dictionary:
	var out := pending.duplicate(true)
	pending = {}
	return out


## result "win" / "lose" / "left"; summary from pc_dungeon_run.pay_out.
static func finish(tree: SceneTree, ctx: Dictionary, result: String, summary: Dictionary) -> void:
	outcome = {
		"dungeon_id": str(ctx.get("dungeon_id", "")),
		"result": result,
		"summary": summary.duplicate(true),
		"return_zone": str(ctx.get("return_zone", "")),
		"return_cell": ctx.get("return_cell", Vector2i(-1, -1)),
		"movie": str(ctx.get("movie", "")),
	}
	_swap(tree, WORLD_SCENE)


static func take_outcome() -> Dictionary:
	var out := outcome.duplicate(true)
	outcome = {}
	return out


static func _swap(tree: SceneTree, scene: String) -> void:
	last_scene = scene
	if dry_run or tree == null:
		return
	tree.call_deferred("change_scene_to_file", scene)
