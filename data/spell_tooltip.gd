extends RefCounted
class_name SpellTooltip

## Proposed attack-card chrome. Formats CombatSim.preview_cast only.
## Does not invent kit numbers, rolls, or Open rules. Mastery 0 is omitted.
## Resist is shown only if the preview notes it (provisional/Open, never Locked).

const LONG_PRESS_SEC := 0.45


static func card_text(preview: Dictionary) -> String:
	return "\n".join(card_lines(preview))


static func card_lines(preview: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if preview.is_empty():
		return lines
	var name := str(preview.get("name", ""))
	if name == "" and str(preview.get("spell_id", "")) == "":
		return lines
	if name == "":
		name = str(preview.get("spell_id", ""))
	lines.append(name)
	# Presentation only: preview_cast reason / marks_on_target. No client kit math.
	var needs_marks := _preview_needs_marks(preview)
	if needs_marks:
		var gate := str(preview.get("gate_text", "")).strip_edges()
		lines.append(gate if gate != "" else "needs Marks")
	var range_line := str(preview.get("range_text", "")).strip_edges()
	if range_line == "":
		range_line = SpellKits.range_text(preview)
	lines.append("%d AP / %d MP · %s" % [
		int(preview.get("ap", 0)),
		int(preview.get("mp", 0)),
		range_line,
	])
	var on_connect := str(preview.get("on_connect_text", "")).strip_edges()
	if on_connect != "":
		lines.append("On connect: %s" % on_connect)
	var miss := str(preview.get("on_miss_text", "")).strip_edges()
	if miss != "":
		lines.append("On miss: %s" % miss)
	if preview.get("hit_chance", null) != null:
		lines.append("HIT %d%% (Locked)" % int(preview["hit_chance"]))
	if preview.get("sample_damage", null) != null and not needs_marks:
		var sample := "sample %d  ·  CritMult(1.0) × live Facing" % int(preview["sample_damage"])
		if preview.has("marks_on_target"):
			var formula := str(preview.get("formula", "6+6*M"))
			sample += "  ·  M=%d (%s)" % [int(preview["marks_on_target"]), formula]
		lines.append(sample)
	if str(preview.get("reason", "")) == "needs_marks":
		# Do not lead with a fake sample 6 when M=0; on_connect already has 6+6×M.
		lines.append("Needs 1+ Marks. 6+6×M when Marks exist.")
	if bool(preview.get("would_stun", false)):
		lines.append("Stun 1 (Locked A′) this cast.")
	for note in preview.get("notes", []):
		var text := str(note)
		if text == "":
			continue
		if text.contains("Push") or text.contains("push_blocked"):
			lines.append(text)
		elif text.contains("Resist"):
			lines.append(text)
		elif text.contains("teleport") or text.contains("Facing unchanged"):
			if not on_connect.contains("Teleport") and not on_connect.contains("Facing unchanged"):
				lines.append(text)
	return lines


static func _preview_needs_marks(preview: Dictionary) -> bool:
	if str(preview.get("reason", "")) == "needs_marks":
		return true
	if bool(preview.get("needs_marks", false)):
		return true
	if preview.has("marks_on_target") and int(preview["marks_on_target"]) == 0:
		return true
	return false
