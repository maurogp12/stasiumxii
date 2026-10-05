extends RefCounted

## PC NPC missions (spec 4.7). Preload. No global class.
## Pure logic: the world scene only calls these methods.
## Does not import phone scripts. Story XP is the number stored in the file.
## Repeatable task XP is xp_percent of xp_to_next(player level) times pace(level).

const Levels = preload("res://backend/world_levels.gd")
const Npcs = preload("res://backend/world_npcs.gd")
const Progress = preload("res://backend/pc_progress.gd")
const Maps = preload("res://backend/world_map.gd")
const Walk = preload("res://backend/world_walk.gd")
const Regions = preload("res://backend/world_regions.gd")
const Dungeons = preload("res://backend/world_dungeons.gd")

const MISSIONS_PATH := "res://data/world/missions.json"
const TEMPLATES_PATH := "res://data/world/task_templates.json"
const BALANCE_PATH := "res://data/world/balance_inputs.json"
const FORMAT := "stasium.world_missions"
const TEMPLATES_FORMAT := "stasium.world_task_templates"
const FORMAT_VERSION := 1
const DOC_KEYS: Array[String] = [
	"format", "format_version", "status", "notes", "reach_index", "missions",
]
const TEMPLATE_KEYS: Array[String] = [
	"format", "format_version", "status", "notes", "templates",
]
const MISSION_KEYS: Array[String] = [
	"id", "name", "kind", "chain", "level_zone", "giver", "turn_in",
	"min_level", "requires", "steps", "rewards", "lines",
]
const STEP_KEYS: Array[String] = [
	"type", "npc", "zone_id", "landmark", "cell", "dungeon", "family", "count", "place",
	"pending_chunk",
]
const CHAINS: Array[String] = ["welcome", "scout", "dungeon", "side"]
const OUTER_DUNGEONS: Array[String] = [
	"rotting_orchard_barrow",
	"cinderforge_depths",
	"sunken_mill",
	"thunderwell_core",
	"shard_hollow",
]
const CORE_ROLES: Array[String] = ["warden", "trader", "door_keeper"]
const TASK_DENIED_ROLES: Array[String] = ["door_keeper", "banker", "herald"]
const MAX_ACTIVE_TASKS := 3
## Shortest walk from a task giver to a landmark, in ortho steps.
const MIN_TASK_WALK := 40
## Half of 100, for rounding a percent. Not the level cap.
const HALF := 100 / 2

var _rows: Array = []
var _by_id: Dictionary = {}
var _order: Array[String] = []
var _zones: Array = []
var _reach: Array = []
var _templates: Array = []
var _npc_names: Dictionary = {}
var _npc_cells: Dictionary = {}
var _npc_roles: Dictionary = {}
var _pace_start := 0.0
var _pace_ratio := 0.0
var _max_level := 0
var _coin_base := 0.0
var _coin_per_level := 0.0
var _fight_minutes := 0.0
var _reach_minutes := 0
var _defeat_minutes := 0
var _clear_minutes := 0
var _reach_percent := 0
var _defeat_percent := 0
var _clear_percent := 0
var _map = null
var _walk_cache: Dictionary = {}
var _migrating := false
## Dungeon ids whose run is built (dungeons.json status "built"). A
## clear_dungeon step on any other dungeon stays "coming soon".
var _built_dungeons: Dictionary = {}


static func load_default() -> Dictionary:
	var missions_doc: Variant = _read_json(MISSIONS_PATH)
	var templates_doc: Variant = _read_json(TEMPLATES_PATH)
	if typeof(missions_doc) != TYPE_DICTIONARY or typeof(templates_doc) != TYPE_DICTIONARY:
		return _fail(["missions files must be JSON objects"])
	return load_documents(missions_doc, templates_doc)


static func load_documents(missions_doc: Dictionary, templates_doc: Dictionary) -> Dictionary:
	var levels_loaded: Dictionary = Levels.load_default()
	if not bool(levels_loaded.get("ok", false)):
		return _fail(levels_loaded.get("errors", ["level zones failed"]))
	var npcs_loaded: Dictionary = Npcs.load_default()
	if not bool(npcs_loaded.get("ok", false)):
		return _fail(npcs_loaded.get("errors", ["npc book failed"]))
	var curve: Dictionary = Progress.load_curve()
	if not bool(curve.get("ok", false)):
		return _fail(curve.get("errors", ["level curve failed"]))
	var book = new()
	var errors: Array = []
	book._read(missions_doc, templates_doc, levels_loaded["levels"], npcs_loaded["npcs"], curve, errors)
	if not errors.is_empty():
		return _fail(errors)
	return {"ok": true, "reason": "", "errors": [], "missions": book}


func mission(id: String) -> Dictionary:
	var found: Variant = _by_id.get(id, {})
	if typeof(found) != TYPE_DICTIONARY:
		return {}
	return (found as Dictionary).duplicate(true)


func all_ids() -> Array:
	var ids: Array = []
	for id in _order:
		ids.append(id)
	return ids


func status_of(mission_id: String, hero) -> String:
	if not _by_id.has(mission_id):
		return ""
	var saved := _story_state(hero, mission_id)
	var stored := str(saved.get("status", ""))
	if stored == "done":
		return "done"
	if stored == "active" or stored == "ready":
		if _steps_complete(mission_id, saved):
			return "ready"
		return "active"
	var row: Dictionary = _by_id[mission_id]
	if int(hero.level) < int(row["min_level"]):
		return "locked"
	for req in row["requires"]:
		if status_of(str(req), hero) != "done":
			return "locked"
	return "available"


func label_for(mission_id: String, hero) -> String:
	var status := status_of(mission_id, hero)
	if status == "available" and _blocked(_by_id[mission_id]):
		return "coming soon"
	return status


func available_for(npc_id: String, hero) -> Array:
	var found: Array = []
	if _outer_giver_closed(npc_id):
		return found
	if _active_from(npc_id, hero) != "":
		return found
	if _is_talk_target(npc_id, hero):
		return found
	for id in _order:
		var row: Dictionary = _by_id[id]
		if str(row["giver"]) != npc_id:
			continue
		if status_of(id, hero) != "available":
			continue
		if _blocked(row):
			continue
		found.append({
			"id": id,
			"name": str(row["name"]),
			"kind": str(row["kind"]),
			"status": "available",
		})
	if not found.is_empty():
		return found
	if not _gives_tasks(npc_id):
		return found
	if _task_blocks_offer(npc_id, hero):
		return found
	if _active_task_count(hero) >= MAX_ACTIVE_TASKS:
		return found
	var preview := _preview_task(npc_id, hero)
	if preview.is_empty():
		return found
	found.append({
		"id": "task_offer:%s" % npc_id,
		"name": str(preview["name"]),
		"kind": "task",
		"status": "available",
	})
	return found


func accept(mission_id: String, hero) -> Dictionary:
	_reconcile(hero)
	if mission_id.begins_with("task_offer:"):
		return _accept_task(mission_id.trim_prefix("task_offer:"), hero)
	if not _by_id.has(mission_id):
		return _no("missing")
	var status := status_of(mission_id, hero)
	if status != "available":
		return _no(status if status != "" else "missing")
	var row: Dictionary = _by_id[mission_id]
	if _blocked(row):
		return _no("coming soon")
	var done: Array = []
	for _step in row["steps"]:
		done.append(false)
	_put_story(hero, mission_id, {"status": "active", "done": done})
	return {"ok": true, "reason": "", "id": mission_id}


func on_talk(npc_id: String, hero) -> Array:
	_reconcile(hero)
	var changed: Array = []
	for id in _order:
		if status_of(id, hero) != "active":
			continue
		var row: Dictionary = _by_id[id]
		var state := _story_state(hero, id)
		var index := _current_index(row, state)
		if index < 0:
			continue
		var step: Dictionary = row["steps"][index]
		if str(step.get("type", "")) != "talk":
			continue
		if str(step.get("npc", "")) != npc_id:
			continue
		_complete_story_step(hero, id, index)
		changed.append(id)
	return changed


func on_reach(zone_id: String, cell: Vector2i, hero) -> Array:
	_reconcile(hero)
	var changed: Array = []
	for id in _order:
		if status_of(id, hero) != "active":
			continue
		var row: Dictionary = _by_id[id]
		var state := _story_state(hero, id)
		if str(row["chain"]) == "scout":
			var flags: Array = state.get("done", [])
			var steps: Array = row["steps"]
			for index in steps.size():
				var already := false
				if index < flags.size():
					already = bool(flags[index])
				if already:
					continue
				var step: Dictionary = steps[index]
				if str(step.get("type", "")) != "reach":
					continue
				if bool(step.get("pending_chunk", false)):
					continue
				if _reach_hit(step, zone_id, cell):
					_complete_story_step(hero, id, index)
					changed.append(id)
			continue
		var index := _current_index(row, state)
		if index < 0:
			continue
		var step: Dictionary = row["steps"][index]
		if str(step.get("type", "")) != "reach":
			continue
		if bool(step.get("pending_chunk", false)):
			continue
		if _reach_hit(step, zone_id, cell):
			_complete_story_step(hero, id, index)
			changed.append(id)
	var tasks := _tasks(hero)
	var walked := false
	for npc_id in tasks.keys():
		if walked:
			break
		var raw: Variant = tasks[npc_id]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var one: Dictionary = raw
		if str(one.get("status", "")) != "active":
			continue
		if bool(one.get("pending_chunk", false)):
			continue
		if _task_hit(one, zone_id, cell):
			one["status"] = "ready"
			one["ready_level"] = int(hero.level)
			tasks[str(npc_id)] = one
			changed.append(str(one.get("id", npc_id)))
			walked = true
	return changed


func on_dungeon_won(dungeon_id: String, hero) -> Array:
	_reconcile(hero)
	var changed: Array = []
	for id in _order:
		if status_of(id, hero) != "active":
			continue
		var row: Dictionary = _by_id[id]
		var state := _story_state(hero, id)
		var index := _current_index(row, state)
		if index < 0:
			continue
		var step: Dictionary = row["steps"][index]
		if str(step.get("type", "")) != "clear_dungeon":
			continue
		if str(step.get("dungeon", "")) != dungeon_id:
			continue
		_complete_story_step(hero, id, index)
		changed.append(id)
	return changed


func turn_in(mission_id: String, hero) -> Dictionary:
	_reconcile(hero)
	if mission_id.begins_with("task_"):
		return _turn_in_task(mission_id, hero)
	if not _by_id.has(mission_id):
		return _empty_turn("missing")
	var status := status_of(mission_id, hero)
	if status != "ready":
		return _empty_turn(status if status != "" else "missing")
	var row: Dictionary = _by_id[mission_id]
	var rewards: Dictionary = row["rewards"]
	var xp := int(rewards["xp"])
	var coins := int(rewards["coins"])
	var items: Array = []
	var raw_items: Variant = rewards.get("items", [])
	if typeof(raw_items) == TYPE_ARRAY:
		items = (raw_items as Array).duplicate(true)
	var state := _story_state(hero, mission_id)
	state["status"] = "done"
	_put_story(hero, mission_id, state)
	var events: Array = hero.add_xp(xp)
	return {
		"ok": true,
		"reason": "",
		"id": mission_id,
		"name": str(row["name"]),
		"xp": xp,
		"coins": coins,
		"items": items,
		"events": events,
	}


func mark_for(npc_id: String, hero) -> String:
	if _ready_turn_in(npc_id, hero) != "":
		return "?"
	if not available_for(npc_id, hero).is_empty():
		return "!"
	return ""


func panel_for(npc_id: String, hero) -> Dictionary:
	_reconcile(hero)
	var ready_id := _ready_turn_in(npc_id, hero)
	if ready_id != "":
		if ready_id.begins_with("task_"):
			var task := _task_for_npc(hero, npc_id)
			return _panel(str(task.get("ready_line", "")), "", ready_id, false, "")
		var ready_row: Dictionary = _by_id[ready_id]
		return _panel(_line(ready_row, "ready"), "", ready_id, false, "")
	var active_id := _active_from(npc_id, hero)
	if active_id != "":
		var active_row: Dictionary = _by_id[active_id]
		var text := _line(active_row, "active")
		var step := _step_line(active_row, _story_state(hero, active_id))
		if step != "":
			text += "\nNext: " + step
		return _panel(text, "", "", false, "")
	var active_task := _task_for_npc(hero, npc_id)
	if str(active_task.get("status", "")) == "active":
		return _panel(str(active_task.get("active_line", "")), "", "", false, "")
	var heard := _talk_target_line(npc_id, hero)
	if heard != "":
		return _panel(heard, "", "", false, "")
	var offers: Array = available_for(npc_id, hero)
	var soon_row := _soon_from(npc_id, hero)
	if not offers.is_empty():
		var offer: Dictionary = offers[0]
		var offer_id := str(offer["id"])
		if offer_id.begins_with("task_offer:"):
			var preview := _preview_task(npc_id, hero)
			var soon_name := ""
			if not soon_row.is_empty():
				soon_name = str(soon_row["name"])
			return _panel(str(preview.get("offer_line", "")), offer_id, "", soon_name != "", soon_name)
		var story: Dictionary = _by_id[offer_id]
		return _panel(_line(story, "offer"), offer_id, "", false, "")
	if not soon_row.is_empty():
		return _panel(_line(soon_row, "offer"), "", "", true, str(soon_row["name"]))
	if _task_ground_closed(npc_id, hero):
		var zone := _band_zone(int(hero.level))
		return _panel("That ground is not open yet.", "", "", true, str(zone.get("name", "This region")))
	return _panel("", "", "", false, "")


func tracker_rows(hero) -> Array:
	var rows: Array = []
	for id in _order:
		var status := status_of(id, hero)
		if status != "active" and status != "ready":
			continue
		var row: Dictionary = _by_id[id]
		var step := "Return to " + _npc_name(str(row["turn_in"]))
		if status == "active":
			step = _step_line(row, _story_state(hero, id))
		rows.append({"name": str(row["name"]), "status": status, "step": step})
	var tasks := _tasks(hero)
	for npc_id in tasks.keys():
		var raw: Variant = tasks[npc_id]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var task: Dictionary = raw
		var status := str(task.get("status", ""))
		if status != "active" and status != "ready":
			continue
		var step := str(task.get("step_line", ""))
		if status == "ready":
			step = "Return to " + _npc_name(str(npc_id))
		rows.append({"name": str(task.get("name", "Task")), "status": status, "step": step})
	return rows


func log_sections(hero) -> Array:
	var sections: Array = []
	for zone in _zones:
		var zone_id := str(zone["id"])
		var rows: Array = []
		for id in _order:
			var row: Dictionary = _by_id[id]
			if str(row["level_zone"]) != zone_id:
				continue
			rows.append({
				"name": str(row["name"]),
				"status": label_for(id, hero),
			})
		var tasks := _tasks(hero)
		for npc_id in tasks.keys():
			var raw: Variant = tasks[npc_id]
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var task: Dictionary = raw
			if str(task.get("level_zone", "")) != zone_id:
				continue
			var task_status := str(task.get("status", ""))
			if task_status != "active" and task_status != "ready" and task_status != "done":
				continue
			rows.append({
				"name": str(task.get("name", "Task")),
				"status": task_status,
			})
		sections.append({"zone": str(zone["name"]), "rows": rows})
	return sections


func _accept_task(npc_id: String, hero) -> Dictionary:
	if not _gives_tasks(npc_id):
		return _no("role")
	if _task_blocks_offer(npc_id, hero):
		return _no("active")
	if _active_task_count(hero) >= MAX_ACTIVE_TASKS:
		return _no("cap")
	var offers: Array = available_for(npc_id, hero)
	if not offers.is_empty() and not str(offers[0]["id"]).begins_with("task_offer:"):
		return _no("story")
	var preview := _preview_task(npc_id, hero)
	if preview.is_empty():
		return _no("no landmark")
	preview["status"] = "active"
	var tasks := _tasks(hero)
	tasks[npc_id] = preview
	_put_tasks(hero, tasks)
	return {"ok": true, "reason": "", "id": str(preview["id"])}


func _turn_in_task(mission_id: String, hero) -> Dictionary:
	var tasks := _tasks(hero)
	for npc_id in tasks.keys():
		var raw: Variant = tasks[npc_id]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var task: Dictionary = raw
		if str(task.get("id", "")) != mission_id:
			continue
		if str(task.get("status", "")) != "ready":
			return _empty_turn(str(task.get("status", "missing")))
		var pay_level := int(hero.level)
		if task.has("ready_level"):
			pay_level = int(task["ready_level"])
		var xp := _task_xp(hero, int(task.get("xp_percent", 0)), pay_level)
		var coins := _task_coins(pay_level, float(task.get("minutes", 0)))
		task["status"] = "done"
		tasks[str(npc_id)] = task
		_put_tasks(hero, tasks)
		var events: Array = hero.add_xp(xp)
		return {
			"ok": true,
			"reason": "",
			"id": mission_id,
			"name": str(task.get("name", "Task")),
			"xp": xp,
			"coins": coins,
			"items": [],
			"events": events,
		}
	return _empty_turn("missing")


func _preview_task(npc_id: String, hero) -> Dictionary:
	var template := _offer_template()
	if template.is_empty():
		return {}
	var zone := _band_zone(int(hero.level))
	if zone.is_empty():
		return {}
	var pool := _open_marks(str(zone["id"]), npc_id, hero)
	if pool.is_empty():
		return {}
	var serial := _next_serial(npc_id, hero)
	var index := (_hash_id(npc_id) + serial) % pool.size()
	var mark: Dictionary = pool[index]
	var place := str(mark["name"])
	var task_id := "task_%s_%d" % [npc_id, serial]
	return {
		"id": task_id,
		"serial": serial,
		"status": "offered",
		"name": "Reach %s" % place,
		"level_zone": str(zone["id"]),
		"zone_id": str(mark["zone_id"]),
		"landmark": str(mark["landmark"]),
		"x": int(mark["x"]),
		"y": int(mark["y"]),
		"proximity": str(mark["proximity"]),
		"giver": npc_id,
		"turn_in": npc_id,
		"step_line": "Reach %s" % place,
		"offer_line": "Walk to %s. The mark is in %s." % [place, str(zone["name"])],
		"active_line": "The mark at %s is still ahead." % place,
		"ready_line": "You reached %s. I can mark this done." % place,
		"xp_percent": int(template.get("xp_percent", 0)),
		"minutes": float(template.get("minutes", 0)),
		"pending_chunk": false,
	}


func _task_blocks_offer(npc_id: String, hero) -> bool:
	var task := _task_for_npc(hero, npc_id)
	var status := str(task.get("status", ""))
	return status == "active" or status == "ready"


func _gives_tasks(npc_id: String) -> bool:
	var role := str(_npc_roles.get(npc_id, ""))
	if role == "":
		return false
	return not TASK_DENIED_ROLES.has(role)


func _active_task_count(hero) -> int:
	var count := 0
	var tasks := _tasks(hero)
	for npc_id in tasks.keys():
		var raw: Variant = tasks[npc_id]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var status := str((raw as Dictionary).get("status", ""))
		if status == "active" or status == "ready":
			count += 1
	return count


func _open_marks(level_zone: String, npc_id: String, hero) -> Array:
	var open: Array = []
	for row in _pool_for(level_zone, npc_id):
		var mark: Dictionary = row
		if bool(mark.get("pending_chunk", false)):
			continue
		if _landmark_taken(hero, mark):
			continue
		open.append(mark)
	return open


func _landmark_taken(hero, mark: Dictionary) -> bool:
	var tasks := _tasks(hero)
	for npc_id in tasks.keys():
		var raw: Variant = tasks[npc_id]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var task: Dictionary = raw
		var status := str(task.get("status", ""))
		if status != "active" and status != "ready":
			continue
		if str(task.get("zone_id", "")) != str(mark.get("zone_id", "")):
			continue
		if str(task.get("landmark", "")) != str(mark.get("landmark", "")):
			continue
		return true
	return false


func _task_ground_closed(npc_id: String, hero) -> bool:
	if not _gives_tasks(npc_id) or _task_blocks_offer(npc_id, hero):
		return false
	if _active_task_count(hero) >= MAX_ACTIVE_TASKS:
		return false
	var zone := _band_zone(int(hero.level))
	if zone.is_empty():
		return false
	var marks := _pool_for(str(zone["id"]), npc_id)
	if marks.is_empty():
		return false
	var pending := false
	for row in marks:
		var mark: Dictionary = row
		if not bool(mark.get("pending_chunk", false)) and not _landmark_taken(hero, mark):
			return false
		if bool(mark.get("pending_chunk", false)):
			pending = true
	return pending


func _next_serial(npc_id: String, hero) -> int:
	var task := _task_for_npc(hero, npc_id)
	if task.is_empty():
		return 1
	var serial := int(task.get("serial", 1))
	var status := str(task.get("status", ""))
	if status == "done" or status == "dropped":
		return serial + 1
	return serial


func _pool_for(level_zone: String, npc_id: String) -> Array:
	var npc: Dictionary = _npc_cells.get(npc_id, {})
	var chunks := _chunks_for_band(level_zone)
	var usable: Array = []
	for row in _reach:
		var mark: Dictionary = row
		if not chunks.is_empty():
			if not chunks.has(str(mark.get("zone_id", ""))):
				continue
		elif str(mark["level_zone"]) != level_zone:
			continue
		# Outer regions stay out of the pool until they reopen. Crosshaven only.
		if _map == null or not _map.zones.has(str(mark.get("zone_id", ""))):
			continue
		if bool(mark.get("pending_chunk", false)):
			usable.append(mark)
			continue
		if _walk_length(npc, mark) >= MIN_TASK_WALK:
			usable.append(mark)
	return usable


func _walk_length(npc: Dictionary, mark: Dictionary) -> int:
	if _map == null or npc.is_empty():
		return -1
	var from_zone := str(npc.get("zone_id", ""))
	var to_zone := str(mark.get("zone_id", ""))
	var from_cell := Vector2i(int(npc.get("x", 0)), int(npc.get("y", 0)))
	var to_cell := Vector2i(int(mark.get("x", 0)), int(mark.get("y", 0)))
	# Both ends have to be on the loaded walk map. An outer giver is not given a fake length.
	if not _map.zones.has(to_zone) or not _map.zones.has(from_zone):
		return -1
	var key := "%s#%d#%d>%s#%d#%d" % [from_zone, from_cell.x, from_cell.y, to_zone, to_cell.x, to_cell.y]
	if _walk_cache.has(key):
		return int(_walk_cache[key])
	var result: Dictionary = Walk.find_path(_map, from_zone, from_cell, to_zone, to_cell)
	var length := -1
	if bool(result.get("ok", false)):
		length = int(result["length"])
	_walk_cache[key] = length
	return length


## Town bands come from level_zones.json. The Crossroads hub is level 1 and
## safe, so a task at that level uses Stoneford. A shared level belongs to the
## later band. Outer zones stay out of the pool while the flag is off.
func _band_zone(level: int) -> Dictionary:
	var best: Dictionary = {}
	var best_min := -1
	for zone_value in _zones:
		var zone: Dictionary = zone_value
		if str(zone["id"]) == "crossroads":
			continue
		if not Regions.enabled() and not _home_zone(zone):
			continue
		var lo := int(zone["level_min"])
		var hi := int(zone["level_max"])
		if level < lo or level > hi:
			continue
		if lo > best_min:
			best_min = lo
			best = zone
	return best


func _chunks_for_band(band_id: String) -> Array:
	for zone_value in _zones:
		var zone: Dictionary = zone_value
		if str(zone["id"]) == band_id:
			return zone["chunks"]
	return []


func _story_chunks(zone: Dictionary) -> Array:
	var chunks: Array = (zone["chunks"] as Array).duplicate()
	var nxt := _next_home(zone)
	if nxt.is_empty():
		return chunks
	for chunk in nxt["chunks"]:
		chunks.append(chunk)
	return chunks


func _home_zones() -> Array:
	var rows: Array = []
	for zone_value in _zones:
		var zone: Dictionary = zone_value
		if _home_zone(zone):
			rows.append(zone)
	return rows


func _home_zone(zone: Dictionary) -> bool:
	return str(Levels.REGION_OF.get(str(zone.get("id", "")), "")) == Regions.HOME


func _next_home(zone: Dictionary) -> Dictionary:
	var homes := _home_zones()
	for index in homes.size():
		var row: Dictionary = homes[index]
		if str(row["id"]) != str(zone["id"]):
			continue
		if index + 1 < homes.size():
			return homes[index + 1]
		return {}
	return {}


func _town_chunk(zone: Dictionary) -> String:
	for chunk in zone["chunks"]:
		var chunk_id := str(chunk)
		if chunk_id.find("road") < 0:
			return chunk_id
	return ""


func _town_talks(npcs, zone: Dictionary) -> Array:
	var talks: Array = []
	for role in ["warden", "trader", "door_keeper"]:
		var npc_id := _one_role(npcs, zone, role)
		if npc_id != "":
			talks.append(npc_id)
	return talks


func _one_role(npcs, zone: Dictionary, role: String) -> String:
	var chunks: Array = zone["chunks"]
	var found := ""
	for row in npcs.all():
		var record: Dictionary = row
		if str(record["role"]) != role:
			continue
		if not chunks.has(str(record["zone_id"])):
			continue
		if found != "":
			return ""
		found = str(record["id"])
	return found


func _outer_giver_closed(npc_id: String) -> bool:
	if Regions.enabled():
		return false
	var npc: Dictionary = _npc_cells.get(npc_id, {})
	if npc.is_empty() or _map == null:
		return false
	return not _map.zones.has(str(npc.get("zone_id", "")))


func _offer_template() -> Dictionary:
	for row in _templates:
		var template: Dictionary = row
		if bool(template.get("offer_now", false)) and str(template.get("step", "")) == "reach":
			return template
	return {}


func _task_xp(hero, percent: int, at_level: int = -1) -> int:
	var level := at_level
	if level < 1:
		level = int(hero.level)
	if percent <= 0 or level < 1 or level >= _max_level:
		return 0
	var steps: Array = hero.xp_to_next
	if level - 1 >= steps.size():
		return 0
	var raw := float(steps[level - 1]) * float(percent) / 100.0 * _pace(level)
	return int(round(raw))


func _task_coins(level: int, minutes: float) -> int:
	if level < 1 or minutes <= 0.0 or _fight_minutes <= 0.0:
		return 0
	var per_fight := _coin_base + _coin_per_level * float(level)
	return int(round(per_fight * (minutes / _fight_minutes)))


func _pace(level: int) -> float:
	if _pace_start <= 0.0 or _pace_ratio <= 0.0:
		return 1.0
	return _pace_start * pow(_pace_ratio, float(level - 1))


func _coin_low(level: int) -> int:
	if level <= 10:
		return 20
	if level <= 20:
		return 60
	if level <= 30:
		return 150
	if level <= 40:
		return 300
	return 600


func _reach_hit(step: Dictionary, zone_id: String, cell: Vector2i) -> bool:
	if str(step.get("zone_id", "")) != zone_id:
		return false
	var at: Dictionary = step.get("cell", {})
	var target := Vector2i(int(at.get("x", -999)), int(at.get("y", -999)))
	var dx := absi(cell.x - target.x)
	var dy := absi(cell.y - target.y)
	if str(step.get("landmark", "")) != "":
		return maxi(dx, dy) <= 1
	return dx == 0 and dy == 0


func _task_hit(task: Dictionary, zone_id: String, cell: Vector2i) -> bool:
	if str(task.get("zone_id", "")) != zone_id:
		return false
	var target := Vector2i(int(task.get("x", -999)), int(task.get("y", -999)))
	var dx := absi(cell.x - target.x)
	var dy := absi(cell.y - target.y)
	if str(task.get("proximity", "")) == "cell":
		return dx == 0 and dy == 0
	return maxi(dx, dy) <= 1


func _ready_turn_in(npc_id: String, hero) -> String:
	for id in _order:
		if str(_by_id[id]["turn_in"]) != npc_id:
			continue
		if status_of(id, hero) == "ready":
			return id
	var task := _task_for_npc(hero, npc_id)
	if str(task.get("status", "")) == "ready":
		return str(task.get("id", ""))
	return ""


func _active_from(npc_id: String, hero) -> String:
	for id in _order:
		var row: Dictionary = _by_id[id]
		if str(row["giver"]) != npc_id:
			continue
		if status_of(id, hero) == "active":
			return id
	return ""


func _soon_from(npc_id: String, hero) -> Dictionary:
	for id in _order:
		var row: Dictionary = _by_id[id]
		if str(row["giver"]) != npc_id:
			continue
		if not _blocked(row):
			continue
		if status_of(id, hero) == "available":
			return row
	return {}


func _is_talk_target(npc_id: String, hero) -> bool:
	return _talk_target_line(npc_id, hero) != ""


func _talk_target_line(npc_id: String, hero) -> String:
	for id in _order:
		if status_of(id, hero) != "active":
			continue
		var row: Dictionary = _by_id[id]
		var index := _current_index(row, _story_state(hero, id))
		if index < 0:
			continue
		var step: Dictionary = row["steps"][index]
		if str(step.get("type", "")) != "talk" or str(step.get("npc", "")) != npc_id:
			continue
		return "%s sent you. I will remember you." % _npc_name(str(row["giver"]))
	return ""


func _soon(row: Dictionary) -> bool:
	for step_value in row["steps"]:
		var step: Dictionary = step_value
		if str(step.get("type", "")) == "clear_dungeon" and not _built_dungeons.has(str(step.get("dungeon", ""))):
			return true
	return false


func _has_dungeon_step(row: Dictionary) -> bool:
	for step_value in row["steps"]:
		var step: Dictionary = step_value
		if str(step.get("type", "")) == "clear_dungeon":
			return true
	return false


func _blocked(row: Dictionary) -> bool:
	if _soon(row):
		return true
	for step_value in row["steps"]:
		var step: Dictionary = step_value
		if bool(step.get("pending_chunk", false)):
			return true
	return false


func _line(row: Dictionary, key: String) -> String:
	var lines: Dictionary = row["lines"]
	var block: Array = lines[key]
	var text := ""
	for line in block:
		if text != "":
			text += "\n"
		text += str(line)
	return text


func _step_line(row: Dictionary, state: Dictionary) -> String:
	var index := _current_index(row, state)
	if index < 0:
		return ""
	var step: Dictionary = row["steps"][index]
	var kind := str(step.get("type", ""))
	var place := str(step.get("place", ""))
	if kind == "talk":
		return "Talk to %s" % place
	if kind == "reach":
		if bool(step.get("pending_chunk", false)):
			return "coming soon"
		return "Reach %s" % place
	if kind == "clear_dungeon":
		return "Clear %s" % place
	return kind


func _panel(text: String, accept_id: String, turn_in_id: String, soon: bool, soon_name: String) -> Dictionary:
	return {
		"lines": text,
		"accept_id": accept_id,
		"turn_in_id": turn_in_id,
		"soon": soon,
		"soon_name": soon_name,
	}


func _npc_name(npc_id: String) -> String:
	return str(_npc_names.get(npc_id, npc_id))


func _complete_story_step(hero, mission_id: String, index: int) -> void:
	var row: Dictionary = _by_id[mission_id]
	var state := _story_state(hero, mission_id)
	var previous: Array = state.get("done", [])
	var done: Array = []
	var steps: Array = row["steps"]
	var ready := true
	for i in steps.size():
		var flag := false
		if i < previous.size():
			flag = bool(previous[i])
		if i == index:
			flag = true
		if not flag:
			ready = false
		done.append(flag)
	state["done"] = done
	state["status"] = "ready" if ready else "active"
	_put_story(hero, mission_id, state)


func _steps_complete(mission_id: String, state: Dictionary) -> bool:
	var row: Dictionary = _by_id[mission_id]
	var done: Array = state.get("done", [])
	var steps: Array = row["steps"]
	if done.size() < steps.size():
		return false
	for flag in done:
		if not bool(flag):
			return false
	return true


func _current_index(row: Dictionary, state: Dictionary) -> int:
	var done: Array = state.get("done", [])
	var steps: Array = row["steps"]
	for i in steps.size():
		var flag := false
		if i < done.size():
			flag = bool(done[i])
		if not flag:
			return i
	return -1


func _story_state(hero, mission_id: String) -> Dictionary:
	var story := _story(hero)
	var raw: Variant = story.get(mission_id, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return (raw as Dictionary).duplicate(true)


func _put_story(hero, mission_id: String, state: Dictionary) -> void:
	var blob := _blob(hero)
	var story: Variant = blob.get("story", {})
	if typeof(story) != TYPE_DICTIONARY:
		story = {}
	(story as Dictionary)[mission_id] = state
	blob["story"] = story
	hero.mission_blob = blob


func _story(hero) -> Dictionary:
	var blob: Dictionary = _blob(hero)
	var story: Variant = blob.get("story", {})
	if typeof(story) != TYPE_DICTIONARY:
		return {}
	return story


func _tasks(hero) -> Dictionary:
	var blob := _blob(hero)
	var tasks: Variant = blob.get("tasks", {})
	if typeof(tasks) != TYPE_DICTIONARY:
		tasks = {}
		blob["tasks"] = tasks
		hero.mission_blob = blob
	return tasks


func _put_tasks(hero, tasks: Dictionary) -> void:
	var blob := _blob(hero)
	blob["tasks"] = tasks
	hero.mission_blob = blob


func _task_for_npc(hero, npc_id: String) -> Dictionary:
	var raw: Variant = _tasks(hero).get(npc_id, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


func reconcile(hero) -> Array:
	return _reconcile(hero)


func _reconcile(hero) -> Array:
	if _migrating:
		return []
	_migrating = true
	var notes: Array = []
	_reconcile_tasks(hero, notes)
	_reconcile_story(hero, notes)
	if not notes.is_empty():
		var blob := _blob(hero)
		var log: Variant = blob.get("migration_log", [])
		if typeof(log) != TYPE_ARRAY:
			log = []
		for line in notes:
			(log as Array).append(line)
		blob["migration_log"] = log
		hero.mission_blob = blob
	_migrating = false
	return notes


func _reconcile_tasks(hero, notes: Array) -> void:
	var tasks := _tasks(hero)
	var template := _offer_template()
	for npc_id in tasks.keys():
		var raw: Variant = tasks[npc_id]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var task: Dictionary = raw
		var status := str(task.get("status", ""))
		if status != "active" and status != "ready":
			continue
		if int(task.get("xp_percent", 0)) <= 0 and not template.is_empty():
			task["xp_percent"] = int(template.get("xp_percent", 0))
			notes.append("%s filled xp_percent" % str(task.get("id", npc_id)))
		if float(task.get("minutes", 0)) <= 0.0 and not template.is_empty():
			task["minutes"] = float(template.get("minutes", 0))
			notes.append("%s filled minutes" % str(task.get("id", npc_id)))
		var mark := _mark_by_id(str(task.get("zone_id", "")), str(task.get("landmark", "")))
		if mark.is_empty():
			task["status"] = "dropped"
			notes.append("%s dropped, landmark gone, refund 0" % str(task.get("id", npc_id)))
			tasks[str(npc_id)] = task
			continue
		var moved := int(task.get("x", 0)) != int(mark.get("x", 0)) or int(task.get("y", 0)) != int(mark.get("y", 0))
		if bool(mark.get("pending_chunk", false)):
			task["status"] = "dropped"
			task["pending_chunk"] = true
			notes.append("%s dropped, landmark pending, refund 0" % str(task.get("id", npc_id)))
			tasks[str(npc_id)] = task
			continue
		if moved:
			task["x"] = int(mark.get("x", 0))
			task["y"] = int(mark.get("y", 0))
			notes.append("%s moved to %d,%d" % [str(task.get("id", npc_id)), int(task["x"]), int(task["y"])])
		task["pending_chunk"] = false
		tasks[str(npc_id)] = task


func _reconcile_story(hero, notes: Array) -> void:
	for id in _order:
		var state := _story_state(hero, id)
		var status := str(state.get("status", ""))
		if status != "active" and status != "ready":
			continue
		var row: Dictionary = _by_id[id]
		var steps: Array = row["steps"]
		var flags: Array = state.get("done", [])
		var missing := false
		var pending := false
		for index in steps.size():
			var done := false
			if index < flags.size():
				done = bool(flags[index])
			if done:
				continue
			var step: Dictionary = steps[index]
			if str(step.get("type", "")) != "reach":
				continue
			if bool(step.get("pending_chunk", false)):
				missing = true
				pending = true
				continue
			var landmark := str(step.get("landmark", ""))
			if landmark == "":
				continue
			var mark := _mark_by_id(str(step.get("zone_id", "")), landmark)
			if mark.is_empty():
				missing = true
			elif bool(mark.get("pending_chunk", false)):
				missing = true
				pending = true
		if missing:
			state["status"] = "dropped"
			_put_story(hero, id, state)
			if pending:
				notes.append("%s dropped, landmark pending, refund 0" % id)
			else:
				notes.append("%s dropped, landmark gone, refund 0" % id)


func _mark_by_id(zone_id: String, landmark: String) -> Dictionary:
	if landmark == "":
		return {}
	for row_value in _reach:
		var row: Dictionary = row_value
		if str(row.get("zone_id", "")) == zone_id and str(row.get("landmark", "")) == landmark:
			return row
	return {}


func _blob(hero) -> Dictionary:
	var raw: Variant = hero.mission_blob
	if typeof(raw) != TYPE_DICTIONARY:
		hero.mission_blob = {}
		return hero.mission_blob
	return raw


func _rounded_share(need: int, percent: int) -> int:
	return (need * percent + HALF) / 100


func _hash_id(text: String) -> int:
	var n := 0
	for i in text.length():
		n = (n * 33 + text.unicode_at(i)) % 100000
	return n


func _no(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


func _empty_turn(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "xp": 0, "coins": 0, "items": [], "events": []}


func _read(missions_doc: Dictionary, templates_doc: Dictionary, levels, npcs, curve: Dictionary, errors: Array) -> void:
	_load_built_dungeons()
	_load_pace(curve, errors)
	_load_economy(errors)
	_load_walk_map(errors)
	if not errors.is_empty():
		return
	_check_doc(missions_doc, errors)
	_check_templates(templates_doc, errors)
	if not errors.is_empty():
		return
	_zones = levels.zones.duplicate(true)
	_templates = (templates_doc["templates"] as Array).duplicate(true)
	_reach = (missions_doc["reach_index"] as Array).duplicate(true)
	for row in npcs.all():
		var record: Dictionary = row
		var npc_id := str(record["id"])
		_npc_names[npc_id] = str(record["name"])
		_npc_roles[npc_id] = str(record["role"])
		var at: Dictionary = record["cell"]
		_npc_cells[npc_id] = {
			"zone_id": str(record["zone_id"]),
			"x": int(at["x"]),
			"y": int(at["y"]),
		}
	var rows: Array = missions_doc["missions"]
	var seen := {}
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			_err(errors, "mission row")
			continue
		var row: Dictionary = row_value
		_check_mission_shape(row, npcs, levels, errors)
		var mission_id := str(row.get("id", ""))
		if seen.has(mission_id):
			_err(errors, "duplicate mission %s" % mission_id)
		seen[mission_id] = true
		_rows.append(row.duplicate(true))
		_by_id[mission_id] = row.duplicate(true)
		_order.append(mission_id)
	_check_rewards(curve, errors)
	_check_chain(npcs, errors)
	_check_sides(npcs, errors)
	_check_refs(errors)
	_check_cycle(errors)
	_check_reach_index(levels, errors)


func _check_doc(doc: Dictionary, errors: Array) -> void:
	for key in doc.keys():
		if not DOC_KEYS.has(str(key)):
			_err(errors, "unknown key %s" % str(key))
	if str(doc.get("format", "")) != FORMAT:
		_err(errors, "format")
	if int(doc.get("format_version", 0)) != FORMAT_VERSION:
		_err(errors, "format_version")
	if str(doc.get("status", "")) != "proposed":
		_err(errors, "status")
	if typeof(doc.get("notes", null)) != TYPE_ARRAY:
		_err(errors, "notes")
	if typeof(doc.get("reach_index", null)) != TYPE_ARRAY:
		_err(errors, "reach_index")
	if typeof(doc.get("missions", null)) != TYPE_ARRAY or (doc["missions"] as Array).is_empty():
		_err(errors, "missions")


func _check_templates(doc: Dictionary, errors: Array) -> void:
	for key in doc.keys():
		if not TEMPLATE_KEYS.has(str(key)):
			_err(errors, "unknown template key %s" % str(key))
	if str(doc.get("format", "")) != TEMPLATES_FORMAT:
		_err(errors, "template format")
	if int(doc.get("format_version", 0)) != FORMAT_VERSION:
		_err(errors, "template format_version")
	if str(doc.get("status", "")) != "proposed":
		_err(errors, "template status")
	var rows: Variant = doc.get("templates", null)
	if typeof(rows) != TYPE_ARRAY:
		_err(errors, "templates")
		return
	var offered := 0
	var ids := {}
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			_err(errors, "template row")
			continue
		var row: Dictionary = row_value
		var template_id := str(row.get("id", ""))
		if ids.has(template_id) or template_id == "":
			_err(errors, "template id")
		ids[template_id] = true
		var step := str(row.get("step", ""))
		if step != "reach" and step != "defeat" and step != "clear_dungeon":
			_err(errors, "template step %s" % template_id)
		if bool(row.get("offer_now", false)):
			offered += 1
			if step != "reach":
				_err(errors, "only reach tasks are offered")
		else:
			if step == "defeat" and str(row.get("family", "")) != "Open":
				_err(errors, "defeat families are not listed")
		var percent := int(row.get("xp_percent", -1))
		if step == "reach" and percent != _reach_percent:
			_err(errors, "reach task XP share")
		if step == "defeat" and percent != _defeat_percent:
			_err(errors, "defeat task XP share")
		if step == "clear_dungeon" and percent != _clear_percent:
			_err(errors, "dungeon task XP share")
		var minutes := int(row.get("minutes", -1))
		if step == "reach" and minutes != _reach_minutes:
			_err(errors, "reach task minutes")
		if step == "defeat" and minutes != _defeat_minutes:
			_err(errors, "defeat task minutes")
		if step == "clear_dungeon" and minutes != _clear_minutes:
			_err(errors, "dungeon task minutes")
	if offered != 1:
		_err(errors, "one offered task template")
	if not ids.has("defeat_family") or not ids.has("clear_band_dungeon") or not ids.has("reach_landmark"):
		_err(errors, "task templates are reach, defeat, and clear")


func _check_mission_shape(row: Dictionary, npcs, levels, errors: Array) -> void:
	for key in row.keys():
		if not MISSION_KEYS.has(str(key)):
			_err(errors, "%s has unknown key %s" % [str(row.get("id", "?")), str(key)])
	var mission_id := str(row.get("id", ""))
	if mission_id == "":
		_err(errors, "mission id")
		return
	if str(row.get("kind", "")) != "story" and str(row.get("kind", "")) != "side":
		_err(errors, "%s kind" % mission_id)
	if not CHAINS.has(str(row.get("chain", ""))):
		_err(errors, "%s chain" % mission_id)
	if str(row.get("kind", "")) == "side" and str(row.get("chain", "")) != "side":
		_err(errors, "%s side chain" % mission_id)
	if str(row.get("kind", "")) == "story" and str(row.get("chain", "")) == "side":
		_err(errors, "%s story chain" % mission_id)
	var zone_id := str(row.get("level_zone", ""))
	if not levels.by_id.has(zone_id):
		_err(errors, "%s level zone" % mission_id)
		return
	var zone: Dictionary = levels.by_id[zone_id]
	if int(row.get("min_level", -1)) != int(zone["level_min"]):
		_err(errors, "%s min_level" % mission_id)
	if npcs.by_id(str(row.get("giver", ""))).is_empty():
		_err(errors, "%s giver" % mission_id)
	if npcs.by_id(str(row.get("turn_in", ""))).is_empty():
		_err(errors, "%s turn_in" % mission_id)
	if typeof(row.get("requires", null)) != TYPE_ARRAY:
		_err(errors, "%s requires" % mission_id)
	var mission_steps: Variant = row.get("steps", null)
	if typeof(mission_steps) != TYPE_ARRAY or (mission_steps as Array).is_empty():
		_err(errors, "%s steps" % mission_id)
		return
	for step_value in mission_steps:
		if typeof(step_value) != TYPE_DICTIONARY:
			_err(errors, "%s step" % mission_id)
			continue
		_check_step(mission_id, step_value, levels, npcs, errors)
	var rewards: Variant = row.get("rewards", null)
	if typeof(rewards) != TYPE_DICTIONARY:
		_err(errors, "%s rewards" % mission_id)
		return
	var reward_row: Dictionary = rewards
	for key in reward_row.keys():
		if str(key) != "xp" and str(key) != "coins" and str(key) != "items":
			_err(errors, "%s reward key" % mission_id)
	if typeof(reward_row.get("items", null)) != TYPE_ARRAY or not (reward_row["items"] as Array).is_empty():
		_err(errors, "%s items wait for the reward catalog" % mission_id)
	var lines: Variant = row.get("lines", null)
	if typeof(lines) != TYPE_DICTIONARY:
		_err(errors, "%s lines" % mission_id)
		return
	for key in ["offer", "active", "ready", "done"]:
		if typeof((lines as Dictionary).get(key, null)) != TYPE_ARRAY:
			_err(errors, "%s lines %s" % [mission_id, key])


func _check_step(mission_id: String, step: Dictionary, levels, npcs, errors: Array) -> void:
	for key in step.keys():
		if not STEP_KEYS.has(str(key)):
			_err(errors, "%s step key %s" % [mission_id, str(key)])
	var kind := str(step.get("type", ""))
	if kind == "talk":
		if npcs.by_id(str(step.get("npc", ""))).is_empty():
			_err(errors, "%s talk npc" % mission_id)
		return
	if kind == "reach":
		var chunk := str(step.get("zone_id", ""))
		if not levels.by_chunk.has(chunk):
			_err(errors, "%s reach chunk" % mission_id)
		var cell: Variant = step.get("cell", null)
		if typeof(cell) != TYPE_DICTIONARY:
			_err(errors, "%s reach cell" % mission_id)
			return
		if step.has("pending_chunk") and typeof(step.get("pending_chunk")) != TYPE_BOOL:
			_err(errors, "%s pending_chunk" % mission_id)
		var at: Dictionary = cell
		var stand_in := str(step.get("landmark", "")) != "" and int(at.get("x", -1)) == 20 and int(at.get("y", -1)) == 12
		if stand_in != bool(step.get("pending_chunk", false)):
			_err(errors, "%s pending_chunk mark" % mission_id)
		return
	if kind == "clear_dungeon":
		var dungeon := str(step.get("dungeon", ""))
		var known := false
		for zone_value in levels.zones:
			var zone: Dictionary = zone_value
			if str(zone.get("dungeon", "")) == dungeon:
				known = true
		if not known:
			_err(errors, "%s dungeon" % mission_id)
		return
	if kind == "defeat":
		_err(errors, "%s defeat families are not listed" % mission_id)
		return
	_err(errors, "%s step type" % mission_id)


func _check_rewards(curve: Dictionary, errors: Array) -> void:
	var curve_steps: Array = curve["xp_to_next"]
	for id in _order:
		var row: Dictionary = _by_id[id]
		var level_min := int(row["min_level"])
		if level_min < 1 or level_min - 1 >= curve_steps.size():
			_err(errors, "%s level is outside the curve" % id)
			continue
		var percent := 15
		for step_value in row["steps"]:
			var step: Dictionary = step_value
			if str(step.get("type", "")) == "clear_dungeon":
				percent = 60
				break
			if str(step.get("type", "")) == "reach":
				percent = 25
		var want := _rounded_share(int(curve_steps[level_min - 1]), percent)
		var rewards: Dictionary = row["rewards"]
		if int(rewards.get("xp", -1)) != want:
			_err(errors, "%s XP is not the stored 4.7 share" % id)
		if int(rewards.get("coins", -1)) != _coin_low(level_min):
			_err(errors, "%s coins are not the low end of the band" % id)


func _check_chain(npcs, errors: Array) -> void:
	for id in _order:
		var row: Dictionary = _by_id[id]
		if str(row["kind"]) != "story":
			continue
		var home: Dictionary = {}
		for zone_value in _home_zones():
			var candidate: Dictionary = zone_value
			if str(candidate["id"]) == str(row["level_zone"]):
				home = candidate
		if home.is_empty():
			_err(errors, "%s keeps an outer level zone" % id)
		for step_value in row["steps"]:
			var step: Dictionary = step_value
			if OUTER_DUNGEONS.has(str(step.get("dungeon", ""))):
				_err(errors, "%s points at an outer dungeon" % id)
	var previous_scout := ""
	for zone_value in _home_zones():
		var zone: Dictionary = zone_value
		var zone_id := str(zone["id"])
		var welcome := _one_chain(zone_id, "welcome", errors)
		var scout := _one_chain(zone_id, "scout", errors)
		var skip_dungeon := str(zone.get("dungeon", "")) == ""
		var dungeon := {}
		if skip_dungeon:
			if zone_id != "crossroads":
				_err(errors, "%s needs a dungeon" % zone_id)
			elif _chain_count(zone_id, "dungeon") != 0:
				_err(errors, "crossroads has no dungeon mission")
		else:
			dungeon = _one_chain(zone_id, "dungeon", errors)
		if welcome.is_empty() or scout.is_empty() or (not skip_dungeon and dungeon.is_empty()):
			continue
		var welcome_steps: Array = welcome["steps"]
		var giver := ""
		if zone_id == "crossroads":
			giver = _role_id(npcs, zone, "warden", errors)
			var trader := _role_id(npcs, zone, "trader", errors)
			var guide := _role_id(npcs, zone, "guide", errors)
			if welcome_steps.size() != 2:
				_err(errors, "%s welcome steps" % zone_id)
			elif str(welcome_steps[0].get("npc", "")) != trader or str(welcome_steps[1].get("npc", "")) != guide:
				_err(errors, "%s welcome talks" % zone_id)
		else:
			giver = _role_id(npcs, zone, "elder", errors)
			var talks := _town_talks(npcs, zone)
			if talks.is_empty():
				var town := _town_chunk(zone)
				if welcome_steps.size() != 1 or str(welcome_steps[0].get("type", "")) != "reach":
					_err(errors, "%s welcome steps" % zone_id)
				elif str(welcome_steps[0].get("zone_id", "")) != town:
					_err(errors, "%s welcome leaves the town" % zone_id)
			elif welcome_steps.size() != talks.size():
				_err(errors, "%s welcome steps" % zone_id)
			else:
				for index in talks.size():
					var talk_step: Dictionary = welcome_steps[index]
					if str(talk_step.get("type", "")) != "talk" or str(talk_step.get("npc", "")) != str(talks[index]):
						_err(errors, "%s welcome talks" % zone_id)
					if str(talk_step.get("npc", "")) == giver:
						_err(errors, "%s welcome repeats the giver" % zone_id)
		if str(welcome["giver"]) != giver or str(welcome["turn_in"]) != giver:
			_err(errors, "%s welcome giver" % zone_id)
		if str(scout["giver"]) != giver or (not skip_dungeon and str(dungeon["giver"]) != giver):
			_err(errors, "%s chain giver" % zone_id)
		var scout_steps: Array = scout["steps"]
		var allowed := _story_chunks(zone)
		if scout_steps.size() < 2 or scout_steps.size() > 3:
			_err(errors, "%s scout length" % zone_id)
		for step_value in scout_steps:
			var scout_step: Dictionary = step_value
			if str(scout_step.get("type", "")) != "reach":
				_err(errors, "%s scout step" % zone_id)
			elif not str(scout_step.get("zone_id", "")).begins_with("crosshaven_"):
				_err(errors, "%s scout leaves Crosshaven" % zone_id)
			elif not allowed.has(str(scout_step.get("zone_id", ""))):
				_err(errors, "%s scout leaves the zone" % zone_id)
		var nxt := _next_home(zone)
		if not nxt.is_empty() and not scout_steps.is_empty():
			var last: Dictionary = scout_steps[scout_steps.size() - 1]
			if not (nxt["chunks"] as Array).has(str(last.get("zone_id", ""))):
				_err(errors, "%s scout does not hand on" % zone_id)
		if not skip_dungeon:
			var dungeon_steps: Array = dungeon["steps"]
			if dungeon_steps.size() != 1 or str(dungeon_steps[0].get("type", "")) != "clear_dungeon":
				_err(errors, "%s dungeon step" % zone_id)
			elif str(dungeon_steps[0].get("dungeon", "")) != str(zone.get("dungeon", "")):
				_err(errors, "%s dungeon id" % zone_id)
			elif bool(dungeon_steps[0].get("pending_chunk", false)) == _built_dungeons.has(str(zone.get("dungeon", ""))):
				# Pending until the dungeon's run is built (dungeons.json), then live.
				_err(errors, "%s dungeon pending flag does not match its build status" % zone_id)
		if not _same_requires(welcome, previous_scout):
			_err(errors, "%s welcome requires the previous scout" % zone_id)
		if not _same_requires(scout, str(welcome["id"])):
			_err(errors, "%s scout requires the welcome" % zone_id)
		if not skip_dungeon and not _same_requires(dungeon, str(scout["id"])):
			_err(errors, "%s dungeon requires the scout" % zone_id)
		if zone_id == "crossroads" and str(welcome["id"]) != "heart_welcome":
			_err(errors, "heart welcome id")
		if zone_id == "crossroads" and str(welcome["name"]) != "Welcome to Crosshaven":
			_err(errors, "heart welcome name")
		previous_scout = str(scout["id"])


func _check_sides(npcs, errors: Array) -> void:
	var extras: Array[String] = []
	for row in npcs.all():
		var record: Dictionary = row
		if CORE_ROLES.has(str(record["role"])):
			continue
		extras.append(str(record["id"]))
	var seen := {}
	var side_count := 0
	for id in _order:
		var row: Dictionary = _by_id[id]
		if str(row["chain"]) != "side":
			continue
		side_count += 1
		var giver := str(row["giver"])
		if seen.has(giver):
			_err(errors, "two sides from %s" % giver)
		seen[giver] = true
		if str(row["turn_in"]) != giver:
			_err(errors, "%s side turn-in" % id)
		if not (row["requires"] as Array).is_empty():
			_err(errors, "%s side requires" % id)
		if _has_dungeon_step(row):
			_err(errors, "%s side cannot be a dungeon" % id)
		for step_value in row["steps"]:
			var step: Dictionary = step_value
			if str(step.get("type", "")) == "defeat":
				_err(errors, "%s side defeat" % id)
	if side_count != extras.size():
		_err(errors, "one side mission per extra NPC")
	for npc_id in extras:
		if not seen.has(npc_id):
			_err(errors, "missing side for %s" % npc_id)


func _check_refs(errors: Array) -> void:
	for id in _order:
		var row: Dictionary = _by_id[id]
		for req in row["requires"]:
			if not _by_id.has(str(req)):
				_err(errors, "%s requires a missing mission" % id)
		for step_value in row["steps"]:
			var step: Dictionary = step_value
			if str(step.get("type", "")) != "reach":
				continue
			var landmark := str(step.get("landmark", ""))
			if landmark == "":
				continue
			if not _index_has(step):
				_err(errors, "%s landmark is not in the reach index" % id)


func _check_cycle(errors: Array) -> void:
	var state := {}
	for id in _order:
		if _cycle_from(id, state):
			_err(errors, "requires has a cycle")
			return


func _cycle_from(mission_id: String, state: Dictionary) -> bool:
	if int(state.get(mission_id, 0)) == 1:
		return true
	if int(state.get(mission_id, 0)) == 2:
		return false
	state[mission_id] = 1
	var row: Dictionary = _by_id[mission_id]
	for req in row["requires"]:
		if _by_id.has(str(req)) and _cycle_from(str(req), state):
			return true
	state[mission_id] = 2
	return false


func _check_reach_index(levels, errors: Array) -> void:
	var seen := {}
	for row_value in _reach:
		if typeof(row_value) != TYPE_DICTIONARY:
			_err(errors, "reach index row")
			continue
		var row: Dictionary = row_value
		var chunk := str(row.get("zone_id", ""))
		if not levels.by_chunk.has(chunk):
			_err(errors, "reach index chunk %s" % chunk)
			continue
		var zone: Dictionary = levels.by_chunk[chunk]
		if str(row.get("level_zone", "")) != str(zone["id"]):
			_err(errors, "reach index zone %s" % chunk)
		var proximity := str(row.get("proximity", ""))
		if proximity != "landmark" and proximity != "cell":
			_err(errors, "reach index proximity")
		if row.has("pending_chunk") and typeof(row.get("pending_chunk")) != TYPE_BOOL:
			_err(errors, "reach index pending_chunk")
		var stand_in := proximity == "landmark" and int(row.get("x", -1)) == 20 and int(row.get("y", -1)) == 12
		if stand_in != bool(row.get("pending_chunk", false)):
			_err(errors, "reach index pending_chunk %s" % chunk)
		var key := "%s:%s" % [chunk, str(row.get("landmark", ""))]
		if seen.has(key):
			_err(errors, "duplicate reach index %s" % key)
		seen[key] = true


func _index_has(step: Dictionary) -> bool:
	var chunk := str(step.get("zone_id", ""))
	var landmark := str(step.get("landmark", ""))
	var cell: Dictionary = step.get("cell", {})
	for row_value in _reach:
		var row: Dictionary = row_value
		if str(row.get("zone_id", "")) != chunk or str(row.get("landmark", "")) != landmark:
			continue
		if int(row.get("x", -1)) == int(cell.get("x", -2)) and int(row.get("y", -1)) == int(cell.get("y", -2)):
			return true
	return false


func _chain_count(zone_id: String, chain: String) -> int:
	var count := 0
	for id in _order:
		var row: Dictionary = _by_id[id]
		if str(row["level_zone"]) == zone_id and str(row["chain"]) == chain:
			count += 1
	return count


func _one_chain(zone_id: String, chain: String, errors: Array) -> Dictionary:
	var found: Dictionary = {}
	var count := 0
	for id in _order:
		var row: Dictionary = _by_id[id]
		if str(row["level_zone"]) == zone_id and str(row["chain"]) == chain:
			found = row
			count += 1
	if count != 1:
		_err(errors, "%s needs one %s" % [zone_id, chain])
		return {}
	return found


func _role_id(npcs, zone: Dictionary, role: String, errors: Array) -> String:
	var chunks: Array = zone["chunks"]
	var found := ""
	var count := 0
	for row in npcs.all():
		var record: Dictionary = row
		if str(record["role"]) != role:
			continue
		if not chunks.has(str(record["zone_id"])):
			continue
		found = str(record["id"])
		count += 1
	if count != 1:
		_err(errors, "%s needs one %s" % [str(zone["id"]), role])
	return found


func _same_requires(row: Dictionary, only: String) -> bool:
	var requires: Array = row["requires"]
	if only == "":
		return requires.is_empty()
	return requires.size() == 1 and str(requires[0]) == only


func _load_built_dungeons() -> void:
	_built_dungeons = {}
	var loaded: Dictionary = Dungeons.load_default()
	if not bool(loaded.get("ok", false)):
		return
	for row in loaded["dungeons"].built():
		_built_dungeons[str(row["id"])] = true


func _load_pace(curve: Dictionary, errors: Array) -> void:
	var doc: Variant = _read_json(Progress.CURVE_PATH)
	if typeof(doc) != TYPE_DICTIONARY:
		_err(errors, "level curve has no pace")
		return
	var raw: Dictionary = doc
	if not raw.has("pace_start") or not raw.has("pace_ratio"):
		_err(errors, "level curve has no pace")
		return
	_pace_start = float(raw["pace_start"])
	_pace_ratio = float(raw["pace_ratio"])
	_max_level = int(curve.get("max_level", raw.get("max_level", 0)))
	if _pace_start <= 0.0 or _pace_ratio <= 0.0 or _max_level < 2:
		_err(errors, "level curve pace")


func _load_economy(errors: Array) -> void:
	var doc: Variant = _read_json(BALANCE_PATH)
	if typeof(doc) != TYPE_DICTIONARY:
		_err(errors, "balance inputs")
		return
	var coins: Dictionary = (doc as Dictionary).get("coins", {})
	var minutes: Dictionary = (doc as Dictionary).get("minutes", {})
	_coin_base = float(coins.get("world_base", 0))
	_coin_per_level = float(coins.get("world_per_level", 0))
	_fight_minutes = float(minutes.get("world_fight", 0))
	_reach_minutes = int(minutes.get("mission_reach", 0))
	_defeat_minutes = int(minutes.get("mission_defeat_fights", 0)) * int(minutes.get("mission_defeat_per_fight", 0))
	_clear_minutes = int(minutes.get("mission_clear", 0))
	var shares: Dictionary = (doc as Dictionary).get("xp_share_of_step", {})
	_reach_percent = int(round(float(shares.get("mission_reach", -1)) * 100.0))
	_defeat_percent = int(round(float(shares.get("mission_defeat", -1)) * 100.0))
	_clear_percent = int(round(float(shares.get("mission_clear_dungeon", -1)) * 100.0))
	if _coin_base <= 0.0 or _coin_per_level <= 0.0 or _fight_minutes <= 0.0:
		_err(errors, "world-fight coin rate")
	if _reach_minutes <= 0 or _defeat_minutes <= 0 or _clear_minutes <= 0:
		_err(errors, "task minutes")
	if _reach_percent <= 0 or _defeat_percent <= 0 or _clear_percent <= 0:
		_err(errors, "task XP shares")


func _load_walk_map(errors: Array) -> void:
	var loaded: Dictionary = Maps.load_default()
	if not bool(loaded.get("ok", false)):
		_err(errors, "walk map")
		return
	_map = loaded["map"]


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func _fail(errors: Array) -> Dictionary:
	var reason := ""
	if not errors.is_empty():
		reason = str(errors[0])
	return {"ok": false, "reason": reason, "errors": errors}


static func _err(errors: Array, message: String) -> void:
	if errors.size() < 32:
		errors.append(message)
