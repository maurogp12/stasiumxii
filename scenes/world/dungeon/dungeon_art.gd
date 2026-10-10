extends RefCounted

## VIEW ONLY. Art for a PC dungeon, read through the art manifest
## (art/pc/dungeons/<id>/manifest.json). Preload. No global class.
##
## The manifest lists every file with its path, kind, size, pivot, footprint
## or cell, and frame counts. This loader reads it loosely (any of the usual
## key spellings) so the painted files drop in without code changes. When the
## manifest or a file is missing, a clearly drawn placeholder stands in.
##
## Lookups: building (town entrance), floor (per room), backdrop (per room),
## props (per room, by cell or prop name), pads (per room), monster strips
## (idle, walk, attack, hit, death, summon; S and E facings, W and N mirrored).

const MONSTER_ANIMS: Array[String] = ["idle", "walk", "attack", "hit", "death", "summon"]
## Screen height (px at zoom 1) a placeholder monster stands.
const PLACEHOLDER_HEIGHT := {"granary_rat": 54.0, "scarecrow_drudge": 104.0, "the_ratking": 128.0}

static var _cache: Dictionary = {}


## Normalised manifest: {ok, path, dir, entries: [entry]}. Never fails hard.
static func manifest(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var out := {"ok": false, "path": path, "dir": path.get_base_dir(), "entries": [], "raw": {}}
	if path != "" and FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var rows: Array = []
		if typeof(parsed) == TYPE_ARRAY:
			rows = parsed
		elif typeof(parsed) == TYPE_DICTIONARY:
			out["raw"] = parsed
			rows = _collect_rows(parsed as Dictionary)
		for row in rows:
			if typeof(row) == TYPE_DICTIONARY:
				out["entries"].append(_normalise(row as Dictionary, str(out["dir"])))
		out["ok"] = not (out["entries"] as Array).is_empty()
	_cache[path] = out
	return out


static func clear_cache() -> void:
	_cache.clear()


## Rows may sit under files / assets / entries / items, or grouped by kind
## (a dictionary of lists or of id -> row). Nested groups are flattened and
## the group name is kept as a kind / group hint.
static func _collect_rows(doc: Dictionary, hint: String = "") -> Array:
	var rows: Array = []
	if doc.has("path") or doc.has("file"):
		var one := doc.duplicate()
		if hint != "" and not one.has("group"):
			one["group"] = hint
		return [one]
	for key in doc.keys():
		var value: Variant = doc[key]
		var name := str(key)
		if typeof(value) == TYPE_ARRAY:
			for item in value:
				if typeof(item) == TYPE_DICTIONARY:
					var row: Dictionary = (item as Dictionary).duplicate()
					if not row.has("group"):
						row["group"] = name if hint == "" else "%s/%s" % [hint, name]
					rows.append_array(_collect_rows(row, str(row["group"])))
		elif typeof(value) == TYPE_DICTIONARY:
			var sub: Dictionary = value
			if sub.has("path") or sub.has("file"):
				var row2 := sub.duplicate()
				if not row2.has("id"):
					row2["id"] = name
				if not row2.has("group"):
					row2["group"] = hint
				rows.append(row2)
			else:
				rows.append_array(_collect_rows(sub, name if hint == "" else "%s/%s" % [hint, name]))
	return rows


static func _normalise(row: Dictionary, dir: String) -> Dictionary:
	var path := str(row.get("path", row.get("file", "")))
	if path != "" and not path.begins_with("res://"):
		if path.begins_with("art/"):
			path = "res://" + path
		else:
			path = dir.path_join(path)
	var id := str(row.get("id", row.get("name", path.get_file().get_basename())))
	var text := ("%s %s %s %s" % [id, path.get_file(), str(row.get("kind", "")), str(row.get("group", ""))]).to_lower()
	return {
		"id": id,
		"path": path,
		"kind": str(row.get("kind", row.get("type", ""))).to_lower(),
		"group": str(row.get("group", "")).to_lower(),
		"text": text,
		"size": _vec2(row.get("size", row.get("px", null)), Vector2.ZERO),
		"pivot": _vec2(row.get("pivot", row.get("anchor", null)), Vector2(-1, -1)),
		"cell": _cell(row.get("cell", null)),
		"cells": _cells(row.get("cells", null)),
		"footprint": _cells(row.get("footprint", null)),
		"frames": row.get("frames", row.get("frame_count", 1)),
		"fps": float(row.get("fps", 10.0)),
		"room": str(row.get("room", "")).to_lower(),
		"monster": str(row.get("monster", row.get("unit", ""))).to_lower(),
		"anim": str(row.get("anim", row.get("animation", row.get("action", "")))).to_lower(),
		"facing": str(row.get("facing", row.get("dir", ""))).to_lower(),
		"scale": float(row.get("scale", 0.0)),
		"raw": row,
	}


## First entry whose text holds every word in `all` (and none in `none`).
static func find(man: Dictionary, all: Array, none: Array = []) -> Dictionary:
	for entry in man.get("entries", []):
		var text := str(entry["text"])
		var ok := true
		for word in all:
			if not text.contains(str(word)):
				ok = false
				break
		for word in none:
			if text.contains(str(word)):
				ok = false
		if ok:
			return entry
	return {}


static func find_all(man: Dictionary, all: Array, none: Array = []) -> Array:
	var out: Array = []
	for entry in man.get("entries", []):
		var text := str(entry["text"])
		var ok := true
		for word in all:
			if not text.contains(str(word)):
				ok = false
				break
		for word in none:
			if text.contains(str(word)):
				ok = false
		if ok:
			out.append(entry)
	return out


static func building(man: Dictionary) -> Dictionary:
	for words in [["building"], ["entrance"], ["granary", "door"], ["door_old_granary"], ["hatch", "granary"]]:
		var hit := find(man, words, ["room", "backdrop", "floor", "glow", "hover"])
		if not hit.is_empty():
			return hit
	return {}


## Building size in cells (x wide, y tall) from the manifest footprint.
static func building_size(man: Dictionary, fallback: Vector2i) -> Vector2i:
	var td: Variant = (man.get("raw", {}) as Dictionary).get("town_door", null)
	if typeof(td) == TYPE_DICTIONARY and (td as Dictionary).has("footprint_size"):
		var fs: Array = td["footprint_size"]
		return Vector2i(int(fs[0]), int(fs[1]))
	var entry := building(man)
	var cells: Array = entry.get("footprint", [])
	if cells.is_empty():
		var raw: Dictionary = entry.get("raw", {})
		var fp: Variant = raw.get("footprint", null)
		if typeof(fp) == TYPE_DICTIONARY and (fp as Dictionary).has("w"):
			return Vector2i(int(fp["w"]), int(fp.get("h", fp["w"])))
		if typeof(fp) == TYPE_ARRAY and (fp as Array).size() == 2 and typeof((fp as Array)[0]) != TYPE_ARRAY and typeof((fp as Array)[0]) != TYPE_DICTIONARY:
			return Vector2i(int(fp[0]), int(fp[1]))
		return fallback
	var xs := {}
	var ys := {}
	for c in cells:
		xs[(c as Vector2i).x] = true
		ys[(c as Vector2i).y] = true
	return Vector2i(xs.size(), ys.size())


static func room_entry(man: Dictionary, room_id: String, what: String) -> Dictionary:
	var hit := find(man, [room_id, what])
	if hit.is_empty():
		var letter := room_id.trim_prefix("room_")
		hit = find(man, ["room" + letter, what])
	if hit.is_empty():
		var alias := "cellar" if room_id == "room_a" else ("boss" if room_id == "room_b" else room_id)
		hit = find(man, [alias, what], ["monster"])
	return hit


static func room_props(man: Dictionary, room_id: String) -> Array:
	var out: Array = []
	for entry in man.get("entries", []):
		var text := str(entry["text"])
		var room := str(entry["room"])
		var kind := str(entry["kind"]) + " " + str(entry["group"])
		if not kind.contains("prop") and not text.contains("prop"):
			continue
		if room != "" and room != room_id and not text.contains(room_id):
			continue
		out.append(entry)
	return out


## Monster strip entry for an anim and facing ("s" / "e"). Empty when absent.
static func monster_strip(man: Dictionary, monster_id: String, anim: String, face: String) -> Dictionary:
	var short := monster_id.trim_prefix("the_")
	var best: Dictionary = {}
	for entry in man.get("entries", []):
		var text := str(entry["text"])
		var owner := str(entry["monster"])
		if owner != "" and owner != monster_id and owner != short:
			continue
		if owner == "" and not text.contains(short):
			continue
		var entry_anim := str(entry["anim"])
		if entry_anim != "" and entry_anim != anim:
			continue
		if entry_anim == "" and not text.contains(anim):
			continue
		var f := str(entry["facing"])
		if f == "":
			for cand in ["_" + face + ".", "_" + face + "_", "_" + face + " ", "_" + face]:
				if str(entry["path"]).get_file().to_lower().contains(cand):
					f = face
					break
		if f == face:
			return entry
		if best.is_empty() and f == "":
			best = entry
	return best


## Texture for an entry. Imported files load through ResourceLoader; a fresh
## unimported PNG is read straight from disk so the art shows before import.
static func texture(entry: Dictionary) -> Texture2D:
	var path := str(entry.get("path", ""))
	if path == "":
		return null
	var key := "tex:" + path
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded: Variant = ResourceLoader.load(path)
		tex = loaded as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Frames of a horizontal strip (or a grid when rows are given).
static func strip_frames(entry: Dictionary) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var tex := texture(entry)
	if tex == null:
		return out
	var count := frame_count(entry)
	var raw: Dictionary = entry.get("raw", {})
	var cols := int(raw.get("columns", raw.get("cols", count)))
	var rows := int(raw.get("rows", 1))
	if cols <= 0:
		cols = count
	rows = maxi(rows, int(ceil(float(count) / float(maxi(cols, 1)))))
	var fw := tex.get_width() / maxi(cols, 1)
	var fh := tex.get_height() / maxi(rows, 1)
	if raw.has("frame_size"):
		var fs := _vec2(raw["frame_size"], Vector2(fw, fh))
		fw = int(fs.x)
		fh = int(fs.y)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((i % cols) * fw, int(i / cols) * fh, fw, fh)
		out.append(at)
	return out


static func frame_count(entry: Dictionary) -> int:
	var frames: Variant = entry.get("frames", 1)
	if typeof(frames) == TYPE_DICTIONARY:
		var anim := str(entry.get("anim", ""))
		return maxi(int((frames as Dictionary).get(anim, (frames as Dictionary).get("count", 1))), 1)
	return maxi(int(frames), 1)


## Facing to draw for a requested facing: the drawn letter and a flip flag.
## W mirrors E and N mirrors S when only S and E are painted.
static func facing_source(face: String, has_face: Callable) -> Dictionary:
	var f := face.to_lower()
	if has_face.call(f):
		return {"face": f, "flip": false}
	var mirror := {"w": "e", "n": "s", "e": "w", "s": "n"}
	var other := str(mirror.get(f, "s"))
	if has_face.call(other):
		return {"face": other, "flip": true}
	for any in ["s", "e", "n", "w"]:
		if has_face.call(any):
			return {"face": any, "flip": f in ["w", "n"]}
	return {"face": "s", "flip": f in ["w", "n"]}


# --- Placeholders ---------------------------------------------------------
# Drawn shapes, plainly not final art: flat colours, an outline, no painting.

## SpriteFrames for a monster: manifest strips when present, else drawn ones.
## Anim names are "<anim>_<face>" for the painted faces (s, e).
static func monster_frames(man: Dictionary, monster_id: String) -> Dictionary:
	var key := "frames:%s:%s" % [str(man.get("path", "")), monster_id]
	if _cache.has(key):
		return _cache[key]
	var kit_frames := _kit_monster(man, monster_id)
	if not kit_frames.is_empty():
		_cache[key] = kit_frames
		return kit_frames
	var frames := SpriteFrames.new()
	var painted := false
	var faces := {}
	var pivot := Vector2(-1, -1)
	var height := 0.0
	var scale := 0.0
	for anim in MONSTER_ANIMS:
		for face in ["s", "e", "n", "w"]:
			var entry := monster_strip(man, monster_id, anim, face)
			if entry.is_empty():
				continue
			if str(entry["facing"]) != "" and str(entry["facing"]) != face:
				continue
			var cut := strip_frames(entry)
			if cut.is_empty():
				continue
			var name := "%s_%s" % [anim, face]
			if frames.has_animation(name):
				continue
			frames.add_animation(name)
			frames.set_animation_loop(name, anim in ["idle", "walk"])
			frames.set_animation_speed(name, float(entry.get("fps", 10.0)))
			for t in cut:
				frames.add_frame(name, t)
			painted = true
			faces[face] = true
			if pivot.x < 0 and (entry["pivot"] as Vector2).x >= 0:
				pivot = entry["pivot"]
			if scale <= 0.0 and float(entry.get("scale", 0.0)) > 0.0:
				scale = float(entry["scale"])
			if height <= 0.0:
				height = float(cut[0].get_height())
	if not painted:
		var drawn := _placeholder_monster(monster_id)
		frames = drawn["frames"]
		faces = {"s": true, "e": true}
		pivot = drawn["pivot"]
		height = drawn["height"]
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var cell_px := float(PLACEHOLDER_HEIGHT.get(monster_id, 80.0))
	if scale <= 0.0:
		scale = cell_px / maxf(height, 1.0)
	var out := {"frames": frames, "faces": faces, "pivot": pivot, "scale": scale, "painted": painted}
	_cache[key] = out
	return out


static func _placeholder_monster(monster_id: String) -> Dictionary:
	var size := Vector2i(128, 160)
	var frames := SpriteFrames.new()
	for anim in MONSTER_ANIMS:
		for face in ["s", "e"]:
			var name := "%s_%s" % [anim, face]
			frames.add_animation(name)
			frames.set_animation_loop(name, anim in ["idle", "walk"])
			frames.set_animation_speed(name, 8.0)
			var count: int = int({"idle": 2, "walk": 4, "attack": 4, "hit": 2, "death": 4, "summon": 4}[anim])
			for i in count:
				var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
				img.fill(Color(0, 0, 0, 0))
				_paint_monster(img, monster_id, face, anim, i, count)
				frames.add_frame(name, with_pick_mask(ImageTexture.create_from_image(img), img))
	return {"frames": frames, "pivot": Vector2(64, 150), "height": 150.0}


static func _paint_monster(img: Image, monster_id: String, face: String, anim: String, i: int, count: int) -> void:
	var t := float(i) / float(maxi(count - 1, 1))
	var dx := 0.0
	var dy := 0.0
	var squash := 1.0
	var tint := Color(1, 1, 1, 1)
	match anim:
		"idle":
			dy = -2.0 * float(i)
		"walk":
			dy = -4.0 * absf(sin(t * PI * 2.0))
			dx = 3.0 * sin(t * PI * 2.0)
		"attack":
			dx = 18.0 * sin(t * PI)
			dy = -6.0 * sin(t * PI)
		"hit":
			dx = -8.0
			tint = Color(1.0, 0.55, 0.55, 1.0)
		"death":
			squash = 1.0 - 0.55 * t
			tint = Color(1, 1, 1, 1.0 - 0.6 * t)
		"summon":
			dy = -10.0 * sin(t * PI)
			tint = Color(1.0, 0.9 + 0.1 * t, 0.6 + 0.4 * (1.0 - t), 1.0)
	var flip := -1.0 if face == "s" else 1.0
	var base := Vector2(64 + dx * flip, 150 + dy)
	match monster_id:
		"granary_rat":
			_rat(img, base, flip, 0.75, squash, tint, false)
		"the_ratking":
			_rat(img, base, flip, 1.15, squash, tint, true)
			if anim == "summon":
				_ring(img, base + Vector2(0, -6), 40.0 + 20.0 * t, Color(1.0, 0.75, 0.25, 0.8 * (1.0 - t)))
		_:
			_drudge(img, base, flip, squash, tint)


static func _rat(img: Image, feet: Vector2, flip: float, s: float, squash: float, tint: Color, king: bool) -> void:
	var fur := Color(0.47, 0.38, 0.32).lerp(Color(0.35, 0.27, 0.36), 0.6 if king else 0.0) * tint
	var belly := Color(0.68, 0.58, 0.5) * tint
	var dark := Color(0.16, 0.12, 0.1, tint.a)
	var h := 1.0 * squash
	# Tail.
	for k in 18:
		var p := feet + Vector2(-flip * (26 + k * 2.0) * s, (-10.0 - sin(float(k) * 0.35) * 8.0) * s * h)
		_disc(img, p, 2.2 * s, Color(0.78, 0.55, 0.52, tint.a))
	if king:
		# Sack-cloth cloak behind the body.
		_ellipse(img, feet + Vector2(-flip * 6 * s, -40 * s * h), Vector2(34, 40) * s * Vector2(1, h), Color(0.42, 0.3, 0.2, tint.a))
	_ellipse(img, feet + Vector2(0, -22 * s * h), Vector2(30, 22) * s * Vector2(1, h), fur)
	_ellipse(img, feet + Vector2(flip * 4 * s, -17 * s * h), Vector2(18, 11) * s * Vector2(1, h), belly)
	var head := feet + Vector2(flip * 26 * s, -36 * s * h)
	_ellipse(img, head, Vector2(17, 14) * s * Vector2(1, h), fur)
	_disc(img, head + Vector2(flip * 15 * s, 4 * s * h), 4.0 * s, Color(0.85, 0.5, 0.55, tint.a))
	_disc(img, head + Vector2(-flip * 6 * s, -14 * s * h), 7.0 * s, Color(0.85, 0.55, 0.6, tint.a))
	_disc(img, head + Vector2(flip * 6 * s, -15 * s * h), 6.0 * s, Color(0.85, 0.55, 0.6, tint.a))
	_disc(img, head + Vector2(flip * 6 * s, -3 * s * h), 3.0 * s, Color(0.9, 0.15, 0.1, tint.a))
	_disc(img, feet + Vector2(-12 * s, -3), 5.0 * s, dark)
	_disc(img, feet + Vector2(14 * s, -3), 5.0 * s, dark)
	if king:
		# Horseshoe crown and a crook.
		var crown := head + Vector2(0, -22 * s * h)
		for k in 9:
			var a := PI + PI * float(k) / 8.0
			_disc(img, crown + Vector2(cos(a), sin(a) * 0.6) * 12.0 * s, 3.4 * s, Color(0.93, 0.74, 0.25, tint.a))
		var hand := feet + Vector2(flip * 34 * s, -28 * s * h)
		for k in 30:
			_disc(img, hand + Vector2(0, -float(k) * 2.2 * s), 2.0 * s, Color(0.45, 0.3, 0.16, tint.a))
		for k in 10:
			var a2 := PI * float(k) / 9.0
			_disc(img, hand + Vector2(0, -66 * s) + Vector2(cos(a2) * flip, -sin(a2)) * 9.0 * s, 2.0 * s, Color(0.45, 0.3, 0.16, tint.a))


static func _drudge(img: Image, feet: Vector2, flip: float, squash: float, tint: Color) -> void:
	var straw := Color(0.86, 0.72, 0.36) * tint
	var sack := Color(0.6, 0.47, 0.3) * tint
	var dark := Color(0.15, 0.1, 0.05, tint.a)
	var h := squash
	_rect(img, feet + Vector2(-6, -60 * h), Vector2(12, 60 * h), Color(0.4, 0.28, 0.15, tint.a))
	_ellipse(img, feet + Vector2(0, -78 * h), Vector2(26, 30 * h), sack)
	for k in 7:
		_rect(img, feet + Vector2(-28 + k * 8, -56 * h), Vector2(4, 16 * h), straw)
	_rect(img, feet + Vector2(-48, -96 * h), Vector2(96, 8), Color(0.4, 0.28, 0.15, tint.a))
	for k in 4:
		_rect(img, feet + Vector2(-56 + k * 3, -100 * h + k * 2), Vector2(6, 4), straw)
		_rect(img, feet + Vector2(46 - k * 3, -100 * h + k * 2), Vector2(6, 4), straw)
	var head := feet + Vector2(flip * 2, -122 * h)
	_ellipse(img, head, Vector2(20, 19 * h), Color(0.78, 0.66, 0.46) * tint)
	_disc(img, head + Vector2(-7, -3), 4.0, dark)
	_disc(img, head + Vector2(7, -3), 4.0, dark)
	_rect(img, head + Vector2(-8, 7), Vector2(16, 2), dark)
	_ellipse(img, head + Vector2(0, -16 * h), Vector2(26, 6), Color(0.5, 0.38, 0.2) * tint)
	# Sickle.
	var hand := feet + Vector2(flip * 46, -90 * h)
	_rect(img, hand + Vector2(-2, 0), Vector2(4, 30), Color(0.45, 0.3, 0.16, tint.a))
	for k in 12:
		var a := PI * float(k) / 11.0
		_disc(img, hand + Vector2(flip * (cos(a) * 14.0 - 10.0 * flip), -sin(a) * 14.0), 2.2, Color(0.75, 0.78, 0.82, tint.a))


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	_ellipse(img, c, Vector2(r, r), col)


static func _ellipse(img: Image, c: Vector2, r: Vector2, col: Color) -> void:
	if col.a <= 0.0 or r.x <= 0.0 or r.y <= 0.0:
		return
	var x0 := maxi(int(c.x - r.x - 1), 0)
	var x1 := mini(int(c.x + r.x + 1), img.get_width() - 1)
	var y0 := maxi(int(c.y - r.y - 1), 0)
	var y1 := mini(int(c.y + r.y + 1), img.get_height() - 1)
	var edge := Color(col.r * 0.45, col.g * 0.45, col.b * 0.45, col.a)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var nx := (float(x) - c.x) / r.x
			var ny := (float(y) - c.y) / r.y
			var d := nx * nx + ny * ny
			if d <= 1.0:
				img.set_pixel(x, y, edge if d > 0.78 and r.x > 4.0 else col)


static func _rect(img: Image, at: Vector2, size: Vector2, col: Color) -> void:
	var x0 := maxi(int(at.x), 0)
	var y0 := maxi(int(at.y), 0)
	var x1 := mini(int(at.x + size.x), img.get_width())
	var y1 := mini(int(at.y + size.y), img.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			img.set_pixel(x, y, col)


static func _ring(img: Image, c: Vector2, r: float, col: Color) -> void:
	for k in 48:
		var a := TAU * float(k) / 48.0
		_disc(img, c + Vector2(cos(a), sin(a) * 0.5) * r, 2.0, col)


static func _vec2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if typeof(value) == TYPE_DICTIONARY:
		var d: Dictionary = value
		if d.has("x"):
			return Vector2(float(d["x"]), float(d.get("y", 0)))
		if d.has("w"):
			return Vector2(float(d["w"]), float(d.get("h", 0)))
		if d.has("width"):
			return Vector2(float(d["width"]), float(d.get("height", 0)))
	return fallback


static func _cell(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2 and typeof((value as Array)[0]) != TYPE_ARRAY:
		return Vector2i(int(value[0]), int(value[1]))
	if typeof(value) == TYPE_DICTIONARY and (value as Dictionary).has("x"):
		return Vector2i(int(value["x"]), int(value["y"]))
	return Vector2i(-1, -1)


static func _cells(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for item in value:
		var c := _cell(item)
		if c.x >= 0 or (typeof(item) == TYPE_ARRAY and (item as Array).size() >= 2):
			if c.x < 0 and typeof(item) == TYPE_ARRAY:
				c = Vector2i(int(item[0]), int(item[1]))
			out.append(c)
	return out



# --- The granary art kit (manifest format stasium.dungeon_art v1) -----------
# town_door, board {tiles, glows, props, decals, backdrops, rooms}, monsters.
# Files under _2x/ are 2x masters drawn at 0.5 with the 1x placement.

## Board scale of a hero-format monster cell (512x360, pivot 256,329): a
## Scarecrow Drudge stands about as tall as a hero on the board.
const MONSTER_CELL_SCALE := 0.28
## Monster frames are cropped to the used area and kept at this fraction of
## the master size (they are drawn at MONSTER_CELL_SCALE, so 0.5 keeps them sharp).
const MONSTER_KEEP := 0.5


static func is_kit(man: Dictionary) -> bool:
	return str((man.get("raw", {}) as Dictionary).get("format", "")) == "stasium.dungeon_art"


static func kit_path(man: Dictionary, rel: String) -> String:
	if rel == "" or rel.begins_with("res://"):
		return rel
	var raw: Dictionary = man.get("raw", {})
	var base := str(raw.get("root", str(man.get("dir", "")) + "/"))
	if not base.ends_with("/"):
		base += "/"
	return base + rel


static func tex_at(man: Dictionary, rel: String) -> Texture2D:
	if rel == "":
		return null
	return texture({"path": kit_path(man, rel)})


## {tex, scale} preferring the 2x master.
static func _pick(man: Dictionary, row: Dictionary, one: String = "file", two: String = "file_2x") -> Dictionary:
	# Performance mode takes the 1x file first (a quarter of the memory).
	if VisualSettings.still():
		var small := tex_at(man, str(row.get(one, "")))
		if small != null:
			return {"tex": small, "scale": 1.0}
	var hi := tex_at(man, str(row.get(two, "")))
	if hi != null:
		return {"tex": hi, "scale": 0.5}
	var lo := tex_at(man, str(row.get(one, "")))
	if lo != null:
		return {"tex": lo, "scale": 1.0}
	return {}


## Town entrance: {tex, scale, glow, glow_scale, footprint}. Empty without art.
static func door_kit(man: Dictionary) -> Dictionary:
	var td: Variant = (man.get("raw", {}) as Dictionary).get("town_door", null)
	if typeof(td) != TYPE_DICTIONARY:
		return {}
	var row: Dictionary = td
	var body := _pick(man, row)
	if body.is_empty():
		return {}
	var glow := _pick(man, row, "hatch_glow", "hatch_glow_2x")
	var out := body.duplicate()
	out["glow"] = glow.get("tex", null)
	out["glow_scale"] = float(glow.get("scale", 1.0))
	out["footprint"] = building_size(man, Vector2i(3, 3))
	return out


static func _by_id(list: Variant, id: String) -> Dictionary:
	if typeof(list) != TYPE_ARRAY:
		return {}
	for row in list:
		if typeof(row) == TYPE_DICTIONARY and str((row as Dictionary).get("id", "")) == id:
			return row
	return {}


## Board kit for one room on an n x n board. Every key may be missing.
static func room_kit(man: Dictionary, room_id: String, n: int) -> Dictionary:
	var key := "room:%s:%s:%d" % [str(man.get("path", "")), room_id, n]
	if _cache.has(key):
		return _cache[key]
	var out := {"floors": [], "pad": {}, "pad_glow": {}, "backdrop": {}, "props": {}, "decals": {}}
	var board: Variant = (man.get("raw", {}) as Dictionary).get("board", null)
	if typeof(board) != TYPE_DICTIONARY:
		_cache[key] = out
		return out
	var letter := room_id.trim_prefix("room_")
	var rooms: Dictionary = (board as Dictionary).get("rooms", {})
	var spec: Dictionary = rooms.get(letter, {})
	for name in spec.get("floor", []):
		var pick := _pick(man, _by_id(board["tiles"], str(name)))
		if not pick.is_empty():
			(out["floors"] as Array).append(pick)
	var pad_id := str(spec.get("pad", ""))
	if pad_id != "":
		out["pad"] = _pick(man, _by_id(board["tiles"], pad_id))
		for g in board.get("glows", []):
			if str(g.get("for", "")) == pad_id:
				out["pad_glow"] = _pick(man, g)
	var bd: Variant = spec.get("backdrop", {})
	if typeof(bd) == TYPE_DICTIONARY:
		var row := _by_id(board.get("backdrops", []), str((bd as Dictionary).get(str(n), "")))
		var tex := tex_at(man, str(row.get("file", "")))
		if tex != null:
			var c00: Array = row.get("cell00_centre_px", [0, 0])
			out["backdrop"] = {"tex": tex, "scale": 1.0, "cell00": Vector2(float(c00[0]), float(c00[1]))}
	for row in board.get("props", []):
		var pick2 := _pick(man, row)
		if not pick2.is_empty():
			var fp: Array = row.get("footprint_size", [1, 1])
			pick2["footprint"] = Vector2i(int(fp[0]), int(fp[1]))
			(out["props"] as Dictionary)[str(row["id"])] = pick2
	for row in board.get("decals", []):
		var pick3 := _pick(man, row)
		if pick3.is_empty():
			continue
		var fp2: Array = row.get("footprint_size", [1, 1])
		pick3["footprint"] = Vector2i(int(fp2[0]), int(fp2[1]))
		for g in board.get("glows", []):
			if str(g.get("for", "")) == str(row["id"]):
				var gl := _pick(man, g)
				pick3["glow"] = gl.get("tex", null)
				pick3["glow_scale"] = float(gl.get("scale", 1.0))
		(out["decals"] as Dictionary)[str(row["id"])] = pick3
	_cache[key] = out
	return out


## Monster frames from the kit: one PNG per frame, S and E painted, cropped to
## the used area and kept at MONSTER_KEEP. Empty when the kit has no monster.
static func _monster_row(man: Dictionary, monster_id: String) -> Dictionary:
	var raw: Dictionary = man.get("raw", {})
	var row := _by_id(raw.get("monsters", null), monster_id)
	if row.is_empty() and typeof(raw.get("star5", null)) == TYPE_DICTIONARY:
		row = _by_id((raw["star5"] as Dictionary).get("monsters", null), monster_id)
	return row


static func _kit_monster(man: Dictionary, monster_id: String) -> Dictionary:
	var row := _monster_row(man, monster_id)
	if row.is_empty():
		return {}
	var dir := str(row.get("dir", "monsters/%s" % monster_id))
	var pivot := _vec2(row.get("pivot", [256, 329]), Vector2(256, 329))
	var fps := float(row.get("fps", 12.0))
	var actions: Dictionary = row.get("actions", {})
	var images := {}
	var glows := {}
	var used := Rect2i()
	var first := true
	for act in actions.keys():
		var count := int((actions[act] as Dictionary).get("frames", 1))
		for face in ["S", "E"]:
			var list_imgs: Array = []
			var list_glows: Array = []
			for i in count:
				var rel := "%s/%s/%s_%s_f%02d.png" % [dir, act, act, face, i]
				var img := _image_at(man, rel)
				if img == null:
					continue
				list_imgs.append(img)
				var glow := _image_at(man, rel.trim_suffix(".png") + "_glow.png")
				if glow != null:
					list_glows.append(glow)
				var r := img.get_used_rect()
				if r.size.x <= 0:
					continue
				used = r if first else used.merge(r)
				first = false
			if not list_imgs.is_empty():
				images["%s_%s" % [act, face.to_lower()]] = list_imgs
			if list_glows.size() == list_imgs.size() and not list_glows.is_empty():
				glows["%s_%s" % [act, face.to_lower()]] = list_glows
	if images.is_empty():
		return {}
	used = used.grow(2).intersection(Rect2i(Vector2i.ZERO, (images.values()[0][0] as Image).get_size()))
	var frames := _cut_frames(images, used, actions, fps)
	var glow_frames: SpriteFrames = _cut_frames(glows, used, actions, fps) if not glows.is_empty() else null
	var faces := {}
	for name in images.keys():
		faces[str(name).get_slice("_", 1)] = true
	var new_pivot := (pivot - Vector2(used.position)) * MONSTER_KEEP
	var release := {}
	var rel_doc: Dictionary = row.get("release", {})
	if not rel_doc.is_empty():
		var pts: Dictionary = rel_doc.get("point_px", {})
		var by_face := {}
		for f in pts.keys():
			by_face[str(f).to_lower()] = (_vec2(pts[f], pivot) - pivot) * MONSTER_CELL_SCALE
		release = {"frame": int(rel_doc.get("frame", 0)), "sec": float(rel_doc.get("frame", 0)) / maxf(fps, 1.0), "offset": by_face}
	return {
		"frames": frames,
		"glow_frames": glow_frames,
		"faces": faces,
		"pivot": new_pivot,
		"scale": MONSTER_CELL_SCALE / MONSTER_KEEP,
		"painted": true,
		"height": float(used.size.y) * MONSTER_CELL_SCALE,
		"release": release,
	}


static func _cut_frames(images: Dictionary, used: Rect2i, actions: Dictionary, fps: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for name in images.keys():
		var act := str(name).get_slice("_", 0)
		frames.add_animation(name)
		frames.set_animation_loop(name, bool((actions.get(act, {}) as Dictionary).get("loop", act in ["idle", "walk"])))
		frames.set_animation_speed(name, fps)
		for img in images[name]:
			var cut := (img as Image).get_region(used)
			cut.resize(maxi(int(used.size.x * MONSTER_KEEP), 1), maxi(int(used.size.y * MONSTER_KEEP), 1), Image.INTERPOLATE_LANCZOS)
			frames.add_frame(name, with_pick_mask(ImageTexture.create_from_image(cut), cut))
	return frames


## Board picking: each monster frame keeps a 1-bit alpha mask (meta
## "pick_mask") so a click on the visible pixels picks that monster.
const PICK_ALPHA := 0.2


static func with_pick_mask(tex: Texture2D, img: Image) -> Texture2D:
	if tex == null or img == null or img.is_empty():
		return tex
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, PICK_ALPHA)
	tex.set_meta("pick_mask", bm)
	return tex


## The pick mask of a frame texture, built on first use when the frame came
## without one. Null when the pixels cannot be read (headless dummy renderer).
static func pick_mask(tex: Texture2D) -> BitMap:
	if tex == null:
		return null
	if tex.has_meta("pick_mask"):
		return tex.get_meta("pick_mask") as BitMap
	if tex.has_meta("pick_mask_none"):
		return null
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		tex.set_meta("pick_mask_none", true)
		return null
	if img.is_compressed():
		img.decompress()
	with_pick_mask(tex, img)
	return tex.get_meta("pick_mask") as BitMap


static func _image_at(man: Dictionary, rel: String) -> Image:
	var path := kit_path(man, rel)
	if ResourceLoader.exists(path):
		var tex := ResourceLoader.load(path) as Texture2D
		if tex != null:
			var img := tex.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
				return img
	if FileAccess.file_exists(path):
		var raw_img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if raw_img != null and not raw_img.is_empty():
			raw_img.convert(Image.FORMAT_RGBA8)
			return raw_img
	return null



# --- Effects and ★5 pieces (manifest "star5" / "fx" sections) --------------

## First manifest file entry whose text holds every word.
static func _file_by_words(man: Dictionary, words: Array) -> Dictionary:
	return find(man, words, ["_2x/", "mock"])


static func fx_texture(man: Dictionary, kind: String, what: String) -> Texture2D:
	var e := _file_by_words(man, [what, "sling"] if not kind.begins_with("rad") else [what, "rad"])
	if e.is_empty():
		e = _file_by_words(man, [what, "sling"])
	return texture(e) if not e.is_empty() else null


static func fx_frames(man: Dictionary, kind: String, what: String) -> Array:
	var out: Array = []
	var want := "rad" if kind.begins_with("rad") else "sling"
	var rows := find_all(man, [what, want], ["_2x/", "mock"])
	if rows.is_empty() and want == "rad":
		rows = find_all(man, [what, "sling"], ["_2x/", "mock", "rad"])
	rows.sort_custom(func(a, b): return str(a["path"]) < str(b["path"]))
	for e in rows:
		var t := texture(e)
		if t != null:
			out.append(t)
	return out


static func pool_texture(man: Dictionary) -> Texture2D:
	var e := _file_by_words(man, ["toxic", "pool"])
	return texture(e) if not e.is_empty() else null



## Projectile kit: {tex, scale, glow, glow_scale} for a projectile id
## (projectiles[] or star5.projectiles[]); "impact" gives the puff.
static func projectile_kit(man: Dictionary, id: String) -> Dictionary:
	var raw: Dictionary = man.get("raw", {})
	var row := _by_id(raw.get("projectiles", null), id)
	if row.is_empty() and typeof(raw.get("star5", null)) == TYPE_DICTIONARY:
		row = _by_id((raw["star5"] as Dictionary).get("projectiles", null), id)
	if row.is_empty():
		return {}
	var out := _pick(man, row)
	if out.is_empty():
		return {}
	var g := _pick(man, row, "glow", "glow_2x")
	out["glow"] = g.get("tex", null)
	out["glow_scale"] = float(g.get("scale", 1.0))
	return out


## ★5 toxic pool decal: {tex, scale, glow, glow_scale}.
static func pool_kit(man: Dictionary) -> Dictionary:
	var raw: Dictionary = man.get("raw", {})
	var s5: Variant = raw.get("star5", null)
	if typeof(s5) != TYPE_DICTIONARY:
		return {}
	var board: Dictionary = (s5 as Dictionary).get("board", {})
	var row := _by_id(board.get("decals", []), "toxic_pool")
	var out := _pick(man, row)
	if out.is_empty():
		return {}
	for g in board.get("glows", []):
		if str(g.get("for", "")) == "toxic_pool":
			var gl := _pick(man, g)
			out["glow"] = gl.get("tex", null)
			out["glow_scale"] = float(gl.get("scale", 1.0))
	return out
