extends RefCounted

## Hands an open-world fight from the map to the fight scene and back.
## Preload. No global class. Same shape as DungeonLauncher.
##
## enter(): keeps the fight config (world cells round the pack, cut by
## world_monsters.fight_config), the pack, the backdrop picture of those
## cells and where to come back to, then swaps to the fight scene. finish():
## keeps the outcome and swaps back to the world, which takes it with
## take_outcome(): a win stands the hero where they were, a loss sends them
## to the zone's safe point. dry_run (tests) records the scene only.

const FIGHT_SCENE := "res://scenes/world/monster/world_fight.tscn"
const WORLD_SCENE := "res://scenes/world/crosshaven/crosshaven_world.tscn"

static var pending: Dictionary = {}
static var outcome: Dictionary = {}
static var dry_run := false
static var last_scene := ""


## ctx: config (CombatSim), pack, entry_id, zone_id, chunk_id, level, class_id,
## backdrop (Image), backdrop_cell00 (Vector2), return_zone, return_cell,
## safe_zone, safe_cell, autoplay, movie.
static func enter(tree: SceneTree, ctx: Dictionary) -> Dictionary:
	if (ctx.get("config", {}) as Dictionary).is_empty():
		return {"ok": false, "reason": "no_board"}
	pending = ctx.duplicate(false)
	outcome = {}
	_swap(tree, FIGHT_SCENE)
	return {"ok": true, "reason": "", "scene": FIGHT_SCENE}


static func take_pending() -> Dictionary:
	var out := pending.duplicate(false)
	pending = {}
	return out


## result "win" / "lose"; summary from world_fight pay_out.
static func finish(tree: SceneTree, ctx: Dictionary, result: String, summary: Dictionary) -> void:
	var lose := result != "win"
	outcome = {
		"result": result,
		"summary": summary.duplicate(true),
		"entry_id": str(ctx.get("entry_id", "")),
		"boss_id": str((ctx.get("pack", {}) as Dictionary).get("boss_id", "")),
		"zone_id": str(ctx.get("zone_id", "")),
		"return_zone": str(ctx.get("safe_zone", ctx.get("return_zone", ""))) if lose else str(ctx.get("return_zone", "")),
		"return_cell": ctx.get("safe_cell", ctx.get("return_cell", Vector2i(-1, -1))) if lose else ctx.get("return_cell", Vector2i(-1, -1)),
		"movie": str(ctx.get("movie", "")),
		"world_state": ctx.get("world_state", {}),
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
