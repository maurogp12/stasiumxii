extends RefCounted

## One short line per combat event. Grouped by turn for the fight log.
## Unknown event types return an empty string so the coverage test fails.

const LINES := {
	"deploy_start": true,
	"place": true,
	"reposition": true,
	"ready": true,
	"combat_start": true,
	"turn_start": true,
	"end_turn": true,
	"face": true,
	"move": true,
	"advance": true,
	"cast": true,
	"hit": true,
	"miss": true,
	"push_blocked": true,
	"push_bounce": true,
	"stagger": true,
	"status": true,
	"dead": true,
	"match_over": true,
	"trap": true,
	"electrocuted": true,
	"lava_land": true,
	"slow": true,
	"burn": true,
	"magma": true,
	"blend": true,
	"still": true,
	"revealed": true,
	"expire": true,
	"intercept": true,
	"snap_wall": true,
	"snap_wall_break": true,
	"sudden_death": true,
	"time_up": true,
	"reject": true,
	"shield_blocked": true,
}

const CLASS_COLOR := {
	"kestrel": "#e8c56b",
	"ironjaw": "#e07070",
	"mender": "#7dcea0",
	"gloam": "#c39bd3",
	"bastion": "#85c1e9",
}

const _EXPIRE_NAME := {
	"invisible": "Fade",
	"infusion": "Infusion",
	"pinned": "Pin",
	"mire": "Mire",
	"sparked": "Spark",
	"marks": "Marks",
	"residue": "Residue",
	"skip_next_mp": "Heartstop MP skip",
	"grounded": "Grounded",
	"stun": "Stun",
	"stun_immune": "Stun immunity",
	"trap": "Snare Trap",
	"shade": "Shade",
	"plant": "Plant",
	"wall": "Snap Wall",
	"shield": "Shield",
	"hit_immunity": "Hit immunity",
	"breathless": "Breathless",
	"frozen": "Frozen",
	"impact": "Impact",
	"aegis": "Aegis",
	"pulse": "Pulse",
	"magma": "Magma",
	"steam": "Steam",
}


static func plain(event: Dictionary, snap: Dictionary) -> String:
	var rows := lines(event, snap)
	return "" if rows.is_empty() else str(rows[0])


static func lines(event: Dictionary, snap: Dictionary) -> Array:
	var kind := str(event.get("type", ""))
	if not LINES.has(kind):
		return []
	var veiled := _veiled_line(kind, event, snap)
	if veiled != "":
		return [veiled]
	if kind == "hit":
		var out: Array = [_hit_line(event, snap)]
		var push := _push_success(event, snap)
		if push != "":
			out.append(push)
		return out
	var text := _line(kind, event, snap)
	return [] if text == "" else [text]


## Plain log, newest events last, one header per turn.
static func text(events: Array, snap: Dictionary) -> String:
	var blocks: PackedStringArray = []
	var grouped := false
	for raw in events:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = raw
		var kind := str(event.get("type", ""))
		if kind == "turn_start":
			blocks.append(_turn_header(event, snap))
			grouped = true
			continue
		if kind == "combat_start":
			blocks.append("Fight starts.")
			continue
		for row in lines(event, snap):
			blocks.append(("  " if grouped else "") + str(row))
	if blocks.is_empty():
		return "No events yet."
	return "\n".join(blocks)


static func bbcode(events: Array, snap: Dictionary) -> String:
	var body := text(events, snap)
	var named: Array = []
	for unit in snap.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		var name := str(unit.get("name", ""))
		if name == "":
			continue
		named.append({"name": name, "class_id": str(unit.get("class_id", ""))})
	named.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["name"]).length() > str(b["name"]).length()
	)
	for row in named:
		var name := str(row["name"])
		var color := str(CLASS_COLOR.get(str(row["class_id"]), "#f4ead8"))
		body = body.replace(name, "[color=%s]%s[/color]" % [color, name])
	return body


## Event types written into _last_events (or the blend queue that joins it).
## A new combat event with no log line fails the coverage test.
static func sim_event_types() -> Array:
	var found := {}
	var buf: PackedStringArray = []
	var rows := FileAccess.get_file_as_string("res://backend/combat_sim.gd").split("\n")
	for line in rows:
		if line.begins_with("func ") and not buf.is_empty():
			_collect_types(buf, found)
			buf = PackedStringArray()
		buf.append(line)
	if not buf.is_empty():
		_collect_types(buf, found)
	var out: Array = found.keys()
	out.sort()
	return out


## Rider tags from the element functions. Blend ids are combos, logged on
## their own event, so they are not reaction tags.
static func reaction_tags() -> Array:
	var found := {}
	var rows := FileAccess.get_file_as_string("res://backend/combat_sim.gd").split("\n")
	var watching := false
	var pattern := RegEx.new()
	pattern.compile("tags\\.append\\(\"([a-z_]+)\"\\)")
	for line in rows:
		if line.begins_with("func "):
			watching = line.begins_with("func _add_element_rider(") or line.begins_with("func _flex_caster(") or line.begins_with("func _flex_target(")
		if not watching:
			continue
		for match in pattern.search_all(line):
			var tag := match.get_string(1)
			if tag == "blend" or tag.begins_with("blend_"):
				continue
			found[tag] = true
	var out: Array = found.keys()
	out.sort()
	return out


## Combo ids in CombatSim.BLENDS. A new pair with no log line fails coverage.
static func blend_ids() -> Array:
	var found := {}
	var rows := FileAccess.get_file_as_string("res://backend/combat_sim.gd").split("\n")
	var watching := false
	var pattern := RegEx.new()
	pattern.compile("\"[a-z]+\\+[a-z]+\":\\s*\"([a-z_]+)\"")
	for line in rows:
		var stripped := line.strip_edges()
		if stripped.begins_with("const BLENDS"):
			watching = true
		elif watching and (stripped.begins_with("const ") or stripped.begins_with("func ")):
			watching = false
		if not watching:
			continue
		for match in pattern.search_all(line):
			found[match.get_string(1)] = true
	var out: Array = found.keys()
	out.sort()
	return out


static func _collect_types(buf: PackedStringArray, found: Dictionary) -> void:
	var joined := "\n".join(buf)
	if "_last_events" not in joined and "_blend_queue" not in joined:
		return
	var pattern := RegEx.new()
	pattern.compile("\"type\":\\s*\"([a-z_]+)\"")
	for line in buf:
		if "out.append" in line or "submit(" in line:
			continue
		for match in pattern.search_all(line):
			found[match.get_string(1)] = true
		if "else \"place\"" in line:
			found["place"] = true


static func _line(kind: String, event: Dictionary, snap: Dictionary) -> String:
	match kind:
		"deploy_start":
			return "Deployment."
		"combat_start":
			return "Fight starts."
		"turn_start":
			return _turn_header(event, snap)
		"place":
			return _finish("%s places" % _name(snap, int(event.get("seat", -1))), event, false)
		"reposition":
			return _finish("%s repositions" % _name(snap, int(event.get("seat", -1))), event, false)
		"ready":
			return "%s ready." % _name(snap, int(event.get("seat", -1)))
		"end_turn":
			var who := _name(snap, int(event.get("seat", -1)))
			if bool(event.get("auto", false)) and str(event.get("reason", "")) == "stunned":
				return "%s's stunned turn ends." % who
			if bool(event.get("auto", false)) and str(event.get("reason", "")) == "timer":
				return "%s's turn runs out." % who
			return "%s ends the turn." % who
		"face":
			return "%s faces %s." % [_name(snap, int(event.get("seat", -1))), str(event.get("dir", ""))]
		"move":
			return _move_line(event, snap)
		"advance":
			var note := ""
			if int(event.get("impact_gained", 0)) > 0:
				note = ", Impact +%d" % int(event["impact_gained"])
			return _finish("%s advances%s" % [_name(snap, int(event.get("seat", -1))), note], event, true)
		"cast":
			return _cast_line(event, snap)
		"miss":
			return _miss_line(event, snap)
		"push_blocked":
			return _push_blocked(event, snap)
		"push_bounce":
			return _push_bounce(event, snap)
		"stagger":
			return _stagger_line(event, snap)
		"status":
			return _status_line(event, snap)
		"dead":
			return "%s falls." % _name(snap, int(event.get("seat", -1)))
		"match_over":
			if int(event.get("winner_seat", -1)) < 0:
				return "Match over. Draw."
			return "Match over. %s wins." % _name(snap, int(event.get("winner_seat", -1)))
		"trap":
			return _trap_line(event, snap)
		"electrocuted":
			return _finish("%s Electrocuted" % _name(snap, int(event.get("target_seat", -1))), event, true)
		"lava_land":
			var lava := int(event.get("land_hp", 0))
			if lava == 0:
				lava = absi(int(event.get("hp_delta", 0)))
			return "%s takes %d lava damage." % [_name(snap, int(event.get("target_seat", -1))), lava]
		"slow":
			var who_slow := _name(snap, int(event.get("target_seat", -1)))
			if int(event.get("remaining", 1)) <= 0:
				var cut := int(event.get("mp_delta", -1))
				if cut == 0:
					cut = -1
				var quiet := event.duplicate()
				quiet.erase("mp_delta")
				return _finish("%s Slow %s (last turn)" % [who_slow, _signed(cut, "MP")], quiet, true)
			return _finish("%s Slow" % who_slow, event, true)
		"burn":
			var left := int(event.get("remaining", 0))
			var burn := "%s Burn tick %d" % [_name(snap, int(event.get("target_seat", -1))), int(event.get("damage", 0))]
			burn += ", ends" if left <= 0 else ", %d left" % left
			return burn + "."
		"magma":
			return "%s Magma, %d HP." % [_name(snap, int(event.get("target_seat", -1))), int(event.get("damage", 0))]
		"blend":
			return _blend_line(event, snap)
		"still":
			return _still_line(event, snap)
		"revealed":
			return _revealed_line(event, snap)
		"expire":
			return _expire_line(event, snap)
		"intercept":
			var hp := int(event.get("damage", event.get("hp", 0)))
			return "%s intercepts for %s, %d HP." % [_name(snap, int(event.get("interceptor_seat", -1))), _name(snap, int(event.get("for_seat", -1))), hp]
		"snap_wall":
			var wall := "%s Snap Wall, %d turns" % [_name(snap, int(event.get("seat", -1))), int(event.get("turns", 0))]
			if int(event.get("aegis_spent", 0)) > 0:
				wall += ", -%d Aegis" % int(event["aegis_spent"])
			return _finish(wall, event, true)
		"snap_wall_break":
			var broken := "%s breaks the Snap Wall" % _name(snap, int(event.get("seat", -1)))
			if int(event.get("engine_gained", 0)) > 0:
				broken += ", +%d Aegis" % int(event["engine_gained"])
			return _finish(broken, event, true)
		"sudden_death":
			return "Sudden death: %s -%d (%d%% max HP)." % [_name(snap, int(event.get("target_seat", -1))), int(event.get("damage", 0)), int(event.get("pct", 0))]
		"time_up":
			return "Time. The side with more HP left wins."
		"reject":
			return "Illegal: %s" % _reject_text(str(event.get("coach", event.get("reason", "that action"))))
		"shield_blocked":
			return _shield_blocked_line(event, snap)
		_:
			return ""
	return ""


static func _turn_header(event: Dictionary, snap: Dictionary) -> String:
	var seat := int(event.get("seat", -1))
	var bits: PackedStringArray = []
	bits.append("Turn %d · %s" % [int(event.get("turn", 0)), _name(snap, seat)])
	if event.has("ap_left") or event.has("mp_left"):
		bits.append("AP %d MP %d" % [int(event.get("ap_left", 0)), int(event.get("mp_left", 0))])
	if int(event.get("water_cut", 0)) > 0:
		bits.append("Water -%d MP" % int(event["water_cut"]))
	if int(event.get("gear_cut", 0)) > 0:
		bits.append("Gear slow -%d MP" % int(event["gear_cut"]))
	if int(event.get("steadfast_cut", 0)) > 0:
		bits.append("Steadfast -%d AP" % int(event["steadfast_cut"]))
	if int(event.get("bound_ap_cut", 0)) > 0:
		bits.append("Bound -%d AP" % int(event["bound_ap_cut"]))
	if bool(event.get("pinned", false)):
		bits.append("Pinned")
	if bool(event.get("stunned_skip", false)):
		bits.append("stunned, turn skipped")
	return " · ".join(bits)


static func _move_line(event: Dictionary, snap: Dictionary) -> String:
	var seat := int(event.get("seat", -1))
	var who := _name(snap, seat)
	if str(event.get("still", "")) == "mirror_hour":
		return _finish("%s swaps" % who, event, true)
	if str(event.get("spell", "")) != "":
		return _finish("%s %s" % [who, _spell_name(str(event["spell"]))], event, true)
	var steps := _step_count(event)
	var verb := "walks" if steps < 0 else "walks %d" % steps
	return _finish("%s %s" % [who, verb], event, true)


static func _cast_line(event: Dictionary, snap: Dictionary) -> String:
	var seat := int(event.get("seat", -1))
	var who := _name(snap, seat)
	var spell := str(event.get("spell", ""))
	if spell == SpellKits.FADE:
		var turns := int(event.get("invisible_turns", 0))
		var fade := "%s fades" % who
		if bool(event.get("invisible", false)):
			fade += ", Invisible %d" % turns
		else:
			fade += ", revealed at once"
		if int(event.get("engine_gained", 0)) > 0:
			fade += ", Umbral +%d" % int(event["engine_gained"])
		return _finish(fade, event, true)
	if spell == SpellKits.VAULT:
		var vault := "%s vaults" % who
		if int(event.get("ap_spent", 0)) <= 0:
			vault += ", free"
		return _finish(vault, event, true)
	if spell == SpellKits.SNARE_TRAP:
		return _finish("%s sets a Snare Trap" % who, event, true)
	if spell == SpellKits.DROP_SHADE:
		return _finish("%s drops a Shade" % who, event, true)
	return _finish("%s casts %s" % [who, _spell_name(spell)], event, true)


static func _miss_line(event: Dictionary, snap: Dictionary) -> String:
	var who := _name(snap, int(event.get("seat", -1)))
	var spell := _spell_name(str(event.get("spell", "")))
	if bool(event.get("blind", false)):
		return _finish("%s misses %s, empty air" % [who, spell], event, true)
	var target := ""
	if event.has("target_seat"):
		target = " on " + _name(snap, int(event["target_seat"]))
	return _finish("%s misses %s%s" % [who, spell, target], event, true)


static func _hit_line(event: Dictionary, snap: Dictionary) -> String:
	var actor := _name(snap, int(event.get("seat", -1)))
	var target := _name(snap, int(event.get("target_seat", event.get("seat", -1))))
	var spell := _spell_name(str(event.get("spell", "")))
	if bool(event.get("revived", false)):
		return _finish("%s revives %s with %d HP" % [actor, target, int(event.get("healed", 0))], event, true)
	if int(event.get("shield_gained", 0)) > 0 and int(event.get("damage", 0)) <= 0 and int(event.get("healed", 0)) <= 0:
		return _finish("%s wards %s +%d shield" % [actor, target, int(event["shield_gained"])], event, true)
	if int(event.get("healed", 0)) > 0 and int(event.get("damage", 0)) <= 0:
		var heal := "%s heals %s %d" % [actor, target, int(event["healed"])]
		if bool(event.get("crit", false)):
			heal += ", crit"
		heal += _removed_note(event)
		if str(event.get("infusion", "")) != "":
			heal += ", Infusion %s" % str(event["infusion"]).capitalize()
		if int(event.get("hit_immunity", 0)) > 0:
			heal += ", hit immunity"
		return _finish(heal, event, true)
	var bits: PackedStringArray = ["HIT"]
	if spell != "spell":
		bits.append(spell)
	if int(event.get("bodies", 0)) > 1:
		bits.append("%d fighters" % int(event["bodies"]))
	else:
		bits.append(target)
	bits.append(str(int(event.get("damage", 0))))
	if bool(event.get("crit", false)):
		bits.append("crit")
	if bool(event.get("back", false)):
		bits.append("back")
	if int(event.get("shield_absorbed", 0)) > 0:
		bits.append("shield %d" % int(event["shield_absorbed"]))
	if bool(event.get("immunity_absorbed", false)) or int(event.get("immunity_amount", 0)) > 0:
		bits.append("immunity")
	var head := " ".join(bits)
	var extra := _hit_extras(event)
	if extra != "":
		head = "%s. %s" % [head, extra]
	return _finish(head, event, true)


static func _hit_extras(event: Dictionary) -> String:
	var bits: PackedStringArray = []
	var riders: Array = event.get("riders", []) if event.get("riders", []) is Array else []
	if riders.has("water_slow"):
		var water_mp := int(event.get("water_mp", 1))
		var water_turns := int(event.get("water_turns", 1))
		bits.append("Water slow -%d MP %s" % [water_mp, _for_turns(water_turns)])
	if riders.has("fire_burn"):
		var stacks := int(event.get("burn_stacks", 0))
		var turns := int(event.get("burn_remaining", 0))
		var tick := int(event.get("burn_tick", 0))
		if stacks > 0 and turns > 0:
			bits.append("Burn stack %d, %d HP %s" % [stacks, tick, _for_turns(turns)])
		else:
			bits.append("Burn")
	if riders.has("residue"):
		var residue := str(event.get("residue", ""))
		var residue_name := "Residue" if residue == "" else "Residue %s" % residue.capitalize()
		var residue_turns := int(event.get("residue_turns", 0))
		bits.append(residue_name if residue_turns <= 0 else "%s %s" % [residue_name, _for_turns(residue_turns)])
	if riders.has("grounded"):
		var grounded_turns := int(event.get("grounded_turns", 1))
		bits.append("Grounded %s" % _for_turns(grounded_turns))
	if riders.has("air_mp"):
		bits.append("Air +1 MP")
	if riders.has("unbound"):
		bits.append("Unbound")
	var engine := str(event.get("engine", ""))
	if int(event.get("engine_gained", 0)) > 0 and engine != "":
		bits.append("%s +%d" % [engine.capitalize(), int(event["engine_gained"])])
	elif int(event.get("engine_spent", 0)) > 0 and engine != "":
		bits.append("%s -%d" % [engine.capitalize(), int(event["engine_spent"])])
	if event.has("marks_remaining"):
		bits.append("Marks %d" % int(event["marks_remaining"]))
	if int(event.get("stun_applied", 0)) > 0:
		bits.append("Stun")
	bits.append(_removed_note(event).trim_prefix(", "))
	var cleaned: PackedStringArray = []
	for bit in bits:
		if str(bit) != "":
			cleaned.append(str(bit))
	return ", ".join(cleaned)


static func _removed_note(event: Dictionary) -> String:
	var removed: Variant = event.get("cc_removed", [])
	if typeof(removed) != TYPE_ARRAY or (removed as Array).is_empty():
		return ""
	var names: PackedStringArray = []
	for item in removed:
		names.append(str(item).capitalize())
	return ", cleansed %s" % ", ".join(names)


static func _push_success(event: Dictionary, snap: Dictionary) -> String:
	if not bool(event.get("pushed", false)):
		return ""
	if bool(event.get("push_blocked", false)) or bool(event.get("bounced", false)):
		return ""
	var seat := int(event.get("target_seat", -1))
	var who := _name(snap, seat)
	if _hide_motion(event, snap, seat):
		return "%s moves while hidden." % who
	var verb := "pulled" if bool(event.get("pulled", false)) else "pushed"
	var tiles := _chebyshev(event.get("push_from"), event.get("push_to"))
	var where := ""
	if bool(event.get("burn_applied", false)):
		where = " into lava"
	elif bool(event.get("silence_applied", false)):
		where = " into water"
	elif bool(event.get("slow_applied", false)):
		where = " into mud"
	if tiles > 0:
		return "%s %s %d tile%s%s." % [who, verb, tiles, "" if tiles == 1 else "s", where]
	return "%s %s%s." % [who, verb, where]


static func _push_blocked(event: Dictionary, snap: Dictionary) -> String:
	var who := _name(snap, int(event.get("target_seat", -1)))
	return "Push blocked. %s held by %s." % [who, _terrain_name(str(event.get("reason", "occupied")))]


static func _push_bounce(event: Dictionary, snap: Dictionary) -> String:
	var seat := int(event.get("target_seat", -1))
	var who := _name(snap, seat)
	var hp := int(event.get("stagger_hp", 0))
	var mp := int(event.get("stagger_mp", 0))
	var loss := ""
	if hp > 0:
		loss = ", -%d HP" % hp
	if mp > 0:
		loss += ", -%d MP" % mp
	return "%s bounces off %s%s." % [who, _terrain_name(str(event.get("reason", "wall"))), loss]


static func _stagger_line(event: Dictionary, snap: Dictionary) -> String:
	var who := _name(snap, int(event.get("target_seat", -1)))
	var hp := int(event.get("stagger_hp", absi(int(event.get("hp_delta", 0)))))
	var mp := int(event.get("stagger_mp", 0))
	var text := "%s staggers, -%d HP" % [who, hp]
	if mp > 0:
		text += ", -%d MP" % mp
	return text + "."


static func _status_line(event: Dictionary, snap: Dictionary) -> String:
	var who := _name(snap, int(event.get("target_seat", event.get("seat", -1))))
	var status := str(event.get("status", ""))
	match status:
		"stun":
			return "%s Stunned." % who
		"stun_immune":
			return "%s Stun immunity." % who
		"frozen":
			if bool(event.get("paralyzed", false)):
				return "%s Paralyzed (Frozen 3)." % who
			return "%s Frozen %d." % [who, int(event.get("stacks", 1))]
		"electrocuted":
			return "%s Electrocuted %d, %s next turn." % [who, int(event.get("stacks", 1)), _signed(int(event.get("ap_delta", -int(event.get("stacks", 1)))), "AP")]
		"burn":
			var verb := "Burn extended" if bool(event.get("refreshed", false)) else "Burn"
			return "%s %s stack %d, %d HP for %d." % [who, verb, int(event.get("stacks", 1)), int(event.get("hp_per_tick", 0)), int(event.get("remaining", 0))]
		"silence":
			return "%s Breathless: %s silenced." % [who, _spell_name(str(event.get("spell", "")))]
		"slow":
			var verb := "Slow extended" if bool(event.get("refreshed", false)) else "Slow"
			return "%s %s %s for %d." % [who, verb, _signed(int(event.get("mp_delta", -1)), "MP"), int(event.get("remaining", 1))]
		"cheat_death":
			return "%s holds on at 1 HP." % who
		"pin":
			return "%s Pinned: no walking." % who
		_:
			return "%s %s." % [who, status.capitalize() if status != "" else "gains a status"]


static func _trap_line(event: Dictionary, snap: Dictionary) -> String:
	var who := _name(snap, int(event.get("target_seat", -1)))
	var text := "Snare! %s steps on it" % who
	text += ", -%d HP" % int(event.get("damage", 0))
	if bool(event.get("pin", false)):
		text += ", Pinned"
	return text + "."


static func _shield_blocked_line(event: Dictionary, snap: Dictionary) -> String:
	var who := _name(snap, int(event.get("target_seat", event.get("seat", -1))))
	var source := str(event.get("source", ""))
	if source != "":
		return "Shield blocked (%s). %s is burning." % [source, who]
	return "Shield blocked. %s is burning." % who


static func _blend_line(event: Dictionary, snap: Dictionary) -> String:
	var caster := _name(snap, int(event.get("seat", -1)))
	var target := _name(snap, int(event.get("target_seat", -1)))
	var name := str(event.get("name", event.get("blend", "Blend")))
	if str(event.get("blend", "")) == "magma":
		var stacks := int(event.get("burn_stacks", 0))
		return "%s: %s on %s, Burn %d stacks, no shields while burning." % [name, caster, target, stacks]
	var text := "%s: %s on %s" % [name, caster, target]
	var damage := int(event.get("damage", event.get("chip", 0)))
	if damage > 0:
		text += ", -%d HP" % damage
	if int(event.get("shield_soaked", 0)) > 0:
		text += ", shield %d" % int(event["shield_soaked"])
	var effects: PackedStringArray = []
	var debuffs: Variant = event.get("debuffs", [])
	if typeof(debuffs) == TYPE_ARRAY:
		for raw in debuffs:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var piece := _debuff_text(raw)
			if piece != "":
				effects.append(piece)
	if int(event.get("slide_steps", 0)) > 0 and damage <= 0 and effects.is_empty():
		effects.append("slides %d" % int(event["slide_steps"]))
	var ignored := str(event.get("ignored", ""))
	if ignored != "":
		effects.append("%s ignores it" % ignored)
	var revealed: Variant = event.get("revealed", [])
	if typeof(revealed) == TYPE_ARRAY and not (revealed as Array).is_empty():
		var names: PackedStringArray = []
		for seat in revealed:
			names.append(_name(snap, int(seat)))
		effects.append("reveals %s" % ", ".join(names))
	if effects.is_empty():
		return text + "."
	return "%s. %s." % [text, ", ".join(effects)]


static func _debuff_text(debuff: Dictionary) -> String:
	var debuff_name := str(debuff.get("name", ""))
	if debuff_name == "":
		return ""
	var detail := str(debuff.get("detail", ""))
	var text := debuff_name if detail == "" else "%s %s" % [debuff_name, detail]
	var turns := int(debuff.get("turns", 0))
	if turns > 0:
		text += " " + _for_turns(turns)
	return text


static func _for_turns(turns: int) -> String:
	if turns == 1:
		return "for 1 turn"
	return "for %d turns" % turns


static func _still_line(event: Dictionary, snap: Dictionary) -> String:
	var id := str(event.get("still", ""))
	var who := _name(snap, int(event.get("seat", -1)))
	var title := StillVault.display_name(id)
	match id:
		"tide":
			var cleared: Variant = event.get("cleared", [])
			if typeof(cleared) == TYPE_ARRAY and not (cleared as Array).is_empty():
				var names: PackedStringArray = []
				for item in cleared:
					names.append(str(item))
				return "Tide cleansed %s." % ", ".join(names)
			return "Tide."
		"mirror_hour":
			var other := _name(snap, int(event.get("target_seat", -1)))
			return _finish("Mirror Hour: %s swaps with %s" % [who, other], event, true)
		"bound_hour":
			return _finish("Bound Hour: %s binds %s" % [who, _name(snap, int(event.get("target_seat", -1)))], event, true)
		"bleeding_hour":
			return _finish("Bleeding Hour: %s -%d HP" % [who, int(event.get("hp_spent", 0))], event, true)
		"rewind":
			return "Rewind: %s +%d HP." % [who, int(event.get("healed", 0))]
		"long_shadow":
			return "Long Shadow: %s +%d MP." % [who, int(event.get("mp_gained", 0))]
		"tolling_bell":
			return "Tolling Bell."
		"steadfast":
			return "Steadfast blocks Stun."
		"held_hour":
			if int(event.get("damage", 0)) > 0:
				return "Held Hour: %s -%d HP." % [who, int(event["damage"])]
			return "Held Hour."
		"withering_sand":
			if int(event.get("damage_bonus", 0)) > 0:
				return "Withering Sand +%d." % int(event["damage_bonus"])
			return "Withering Sand."
		"shatterglass":
			return "Shatterglass breaks the shield."
		"gathered_sand":
			return "Gathered Sand releases."
		_:
			return "%s." % title


static func _revealed_line(event: Dictionary, snap: Dictionary) -> String:
	var who := _name(snap, int(event.get("seat", -1)))
	var coach := str(event.get("coach", ""))
	if "Tolling Bell" in coach:
		return "Tolling Bell reveals %s." % who
	return "%s is hit and revealed." % who


static func _expire_line(event: Dictionary, snap: Dictionary) -> String:
	var status := str(event.get("status", ""))
	var label := str(_EXPIRE_NAME.get(status, status.capitalize() if status != "" else "Effect"))
	var seat := int(event.get("target_seat", event.get("owner_seat", -1)))
	var who := _name(snap, seat)
	if status == "invisible":
		return "%s is visible." % who
	return "%s ended on %s." % [label, who]


static func _finish(head: String, event: Dictionary, force_left: bool) -> String:
	var body := head.strip_edges()
	if body.ends_with("."):
		body = body.substr(0, body.length() - 1)
	var pools := _pools(event, force_left)
	if pools == "":
		return body + "."
	return "%s. %s." % [body, pools]


static func _pools(event: Dictionary, force_left: bool) -> String:
	var spent: PackedStringArray = []
	if int(event.get("ap_spent", 0)) > 0:
		spent.append("-%d AP" % int(event["ap_spent"]))
	if int(event.get("mp_spent", 0)) > 0:
		spent.append("-%d MP" % int(event["mp_spent"]))
	if event.has("ap_delta") and int(event["ap_delta"]) != 0:
		spent.append(_signed(int(event["ap_delta"]), "AP"))
	if event.has("mp_delta") and int(event["mp_delta"]) != 0:
		spent.append(_signed(int(event["mp_delta"]), "MP"))
	if int(event.get("ap_gained", 0)) > 0:
		spent.append("+%d AP" % int(event["ap_gained"]))
	if int(event.get("mp_gained", 0)) > 0:
		spent.append("+%d MP" % int(event["mp_gained"]))
	var changed := not spent.is_empty()
	var left := ""
	if (force_left or changed) and (event.has("ap_left") or event.has("mp_left")):
		left = "AP %d MP %d" % [int(event.get("ap_left", 0)), int(event.get("mp_left", 0))]
	if spent.is_empty():
		return left
	if left == "":
		return ", ".join(spent)
	return "%s. %s" % [", ".join(spent), left]


static func _signed(amount: int, unit: String) -> String:
	if amount > 0:
		return "+%d %s" % [amount, unit]
	return "%d %s" % [amount, unit]


## Opposing view while a fighter is invisible. Hot-seat has one shared screen,
## so it uses that view too. The owner's online log keeps the details.
static func _veiled_line(kind: String, event: Dictionary, snap: Dictionary) -> String:
	if kind == "cast" and str(event.get("spell", "")) == SpellKits.FADE:
		return ""
	var actor := int(event.get("seat", -1))
	var target := int(event.get("target_seat", -1))
	if kind in ["move", "advance", "reposition"] and _hide_motion(event, snap, actor):
		return "%s moves while hidden." % _name(snap, actor)
	if kind == "cast" and str(event.get("spell", "")) == SpellKits.VAULT and _hide_motion(event, snap, actor):
		return "%s moves while hidden." % _name(snap, actor)
	if kind in ["trap", "lava_land", "push_bounce", "push_blocked"] and _hide_motion(event, snap, target):
		return "%s moves while hidden." % _name(snap, target)
	if kind == "still" and str(event.get("still", "")) == "mirror_hour" and (_hide_motion(event, snap, actor) or _hide_motion(event, snap, target)):
		var who := actor if _hide_motion(event, snap, actor) else target
		return "%s moves while hidden." % _name(snap, who)
	if kind in ["face", "cast", "miss", "hit", "still"] and _hide_motion(event, snap, actor):
		return "%s (hidden) acts." % _name(snap, actor)
	return ""


static func _hide_motion(_event: Dictionary, snap: Dictionary, seat: int) -> bool:
	if seat < 0 or not _invisible_unit(snap, seat):
		return false
	return not _owner_detail(snap, seat)


static func _owner_detail(snap: Dictionary, seat: int) -> bool:
	if _explicit_local_seat(snap) < 0:
		return false
	return sees_seat(snap, seat)


static func _explicit_local_seat(snap: Dictionary) -> int:
	if snap.has("local_seat"):
		return int(snap.get("local_seat", -1))
	var net: Variant = snap.get("net", {})
	if net is Dictionary and (net as Dictionary).has("local_seat"):
		return int((net as Dictionary).get("local_seat", -1))
	return -1


static func _invisible_unit(snap: Dictionary, seat: int) -> bool:
	var unit := _unit(snap, seat)
	if unit.is_empty():
		return false
	return bool(unit.get("invisible", false)) or bool(unit.get("pos_hidden", false))


static func _step_count(event: Dictionary) -> int:
	var path: Variant = event.get("path", null)
	if typeof(path) != TYPE_ARRAY:
		return -1
	return (path as Array).size()


static func _chebyshev(a: Variant, b: Variant) -> int:
	if typeof(a) != TYPE_VECTOR2I or typeof(b) != TYPE_VECTOR2I:
		return 0
	return maxi(absi((a as Vector2i).x - (b as Vector2i).x), absi((a as Vector2i).y - (b as Vector2i).y))


static func _terrain_name(reason: String) -> String:
	match reason:
		"occupied":
			return "a fighter"
		"grounded":
			return "Grounded"
		"plant_resist", "plant":
			return "a plant"
		"out_of_bounds":
			return "the edge"
		"lava":
			return "lava"
		"water":
			return "water"
		"mud":
			return "mud"
		"wall", "not_walkable":
			return "a wall"
		_:
			return reason if reason != "" else "the tile"


static func _reject_text(coach: String) -> String:
	var text := coach.strip_edges()
	for prefix in ["REJECT — ", "REJECT - ", "REJECT: "]:
		if text.begins_with(prefix):
			text = text.substr(prefix.length())
	return text


static func _spell_name(spell_id: String) -> String:
	if spell_id == "":
		return "spell"
	var def := SpellKits.spell(spell_id)
	var name := str(def.get("name", ""))
	return name if name != "" else spell_id


static func viewer_seat(snap: Dictionary) -> int:
	if snap.has("local_seat") and int(snap.get("local_seat", -1)) >= 0:
		return int(snap["local_seat"])
	var net: Variant = snap.get("net", {})
	if typeof(net) == TYPE_DICTIONARY and (net as Dictionary).has("local_seat") and int((net as Dictionary).get("local_seat", -1)) >= 0:
		return int((net as Dictionary)["local_seat"])
	return int(snap.get("active_seat", 0))


static func sees_seat(snap: Dictionary, seat: int) -> bool:
	var viewer := viewer_seat(snap)
	if int(snap.get("team_size", 1)) > 1 or int(snap.get("party_size", 1)) > 1:
		return _team(snap, seat) == _team(snap, viewer)
	return seat == viewer


static func _team(snap: Dictionary, seat: int) -> int:
	var unit := _unit(snap, seat)
	if unit.is_empty():
		return seat % 2
	return int(unit.get("team", seat % 2))


static func _unit(snap: Dictionary, seat: int) -> Dictionary:
	for raw in snap.get("units", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if int(raw.get("seat", -1)) == seat:
			return raw
	return {}


static func _name(snap: Dictionary, seat: int) -> String:
	var unit := _unit(snap, seat)
	var name := str(unit.get("name", ""))
	if name == "":
		name = SpellKits.display_name(str(unit.get("class_id", "")))
	if name == "":
		return "Seat %d" % seat if seat >= 0 else "Someone"
	return name
