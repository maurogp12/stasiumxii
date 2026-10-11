extends SceneTree

## Visible gear (paper doll), PC pilot: Ironjaw's unarmoured base and the
## Cragmaw (Ironjaw Normal) looks. Run:
##   godot --headless --path . -s res://tests/run_visible_gear_tests.gd
## Covers: each slot swaps exactly its own strip on and off; the stack order
## per facing; strips stay on the body's frame in every action; only worn
## strips load; the other classes keep their locked looks; performance mode.

const LOOKS := preload("res://units/gear_looks.gd")
const STACK := preload("res://units/gear_stack.gd")
const GSPECS := preload("res://units/pc_gear_specs.gd")
const Specs := preload("res://units/pc_character_specs.gd")
const Painted := preload("res://units/painted_looks.gd")
const Walker := preload("res://scenes/world/crosshaven/crosshaven_walker.gd")
const PAWN_SCENE := preload("res://units/pawn.tscn")
const MOTION := preload("res://units/view_motion.gd")
const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const CHAR_WINDOW := preload("res://scenes/world/ui/character_window.gd")

const SLOTS: Array[String] = ["weapon", "head", "chest", "legs", "boots"]
const KINDS: Array[String] = ["walk", "idle", "attack", "skill", "hit", "death"]
const OTHERS: Array[String] = ["bastion", "gloam", "kestrel", "mender"]
const FAMILY := "cragmaw"
const FAMILIES: Array[String] = ["cragmaw", "tyrantjaw", "pitmaw"]
const GROUPS: Array[String] = ["weapon", "head", "chest", "legs", "boots", "skin"]
const LEGS_JSON := "res://art/characters/painted/ironjaw_gear/legs_joints.json"

var passed := 0
var failed := 0


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	MOTION.set_reduce_motion(false)
	LOOKS.clear_cache()
	Painted.clear_cache()
	_test_data()
	_test_strip_sheets()
	_test_slot_swaps()
	_test_stack_order()
	_test_no_holes()
	_test_legs()
	await _test_walker_layers()
	await _test_only_worn_load()
	await _test_pawn_sync()
	await _test_other_classes()
	await _test_portrait()
	await _test_performance_mode()
	MOTION.clear_reduce_motion()
	print("visible gear tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _parts(slots: Array) -> Array:
	var out: Array = []
	for s in slots:
		out.append("%s.%s" % [FAMILY, s])
	return out


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Data and the built table: Ironjaw draws the base, the five Cragmaw strips
## and the six base slot strips are on disk.
func _test_data() -> void:
	var doc := LOOKS.doc()
	check(doc.get("format", "") == "stasium.pc_gear_looks", "gear_looks.json loads")
	check(LOOKS.slots() == ["weapon", "head", "chest", "legs", "boots"], "the visible slots are the mobile five")
	check(LOOKS.base_enabled("ironjaw"), "Ironjaw draws the paper-doll base")
	check(Painted.uses_gear_base("ironjaw"), "painted_looks routes Ironjaw to the base sheets")
	for g in ["weapon", "head", "chest", "legs", "boots", "skin"]:
		check(LOOKS.has_strip("ironjaw", "base_" + g), "base strip base_%s is built" % g)
	for s in SLOTS:
		check(LOOKS.has_strip("ironjaw", "%s_%s" % [FAMILY, s]), "look strip %s_%s is built" % [FAMILY, s])
		check(LOOKS.strip_of_part("ironjaw", "%s.%s" % [FAMILY, s]) == "%s_%s" % [FAMILY, s], "mobile part id %s.%s maps to its strip" % [FAMILY, s])
	check(LOOKS.strip_of_part("ironjaw", "cragmaw.ring") == "", "a slot with no look draws nothing")
	check(LOOKS.strip_of_part("ironjaw", "nosuchset.head") == "", "a part of an unknown set draws nothing")
	check(LOOKS.strip_of_part("kestrel", "cragmaw.head") == "", "an Ironjaw look does not map for another class")


## Every strip sheet has the body's cells, frame counts and the 256 px cap.
func _test_strip_sheets() -> void:
	var strips: Dictionary = GSPECS.STRIPS["ironjaw"]
	for kind in KINDS:
		var s := LOOKS.spec("ironjaw", kind)
		var cell: Vector2i = s.get("cell", Vector2i.ZERO)
		check(cell.x > 0 and cell.x <= Specs.MAX_CELL and cell.y <= Specs.MAX_CELL, "%s cell %s within %d px (1x)" % [kind, cell, Specs.MAX_CELL])
		check(s == Painted.spec("ironjaw", kind), "%s: the body and every strip share one spec" % kind)
		for strip in strips.keys():
			var facings: Array = (strips[strip] as Dictionary).get(kind, [])
			for art in facings:
				var tex := LOOKS.sheet("ironjaw", strip, kind, art)
				check(tex != null and tex.get_width() == cell.x * int(s["frames"]) and tex.get_height() == cell.y, "%s %s %s is frames x cell" % [strip, kind, art])
	LOOKS.clear_cache()


## Equipping each slot alone swaps exactly that slot's base strip for the
## look; unequipping brings back the single base sheet.
func _test_slot_swaps() -> void:
	for s in SLOTS:
		var looks := LOOKS.looks_for("ironjaw", _parts([s]))
		check(looks.size() == 1 and looks.get(s, "") == "%s_%s" % [FAMILY, s], "equipping %s gives exactly its look" % s)
		for art in ["S", "E"]:
			var stack := LOOKS.stack_for("ironjaw", looks, art)
			var mine := 0
			for st in stack:
				if st.begins_with(FAMILY):
					mine += 1
					check(st.trim_suffix("_back") == "%s_%s" % [FAMILY, s], "%s %s: only the %s look is on (%s)" % [s, art, s, st])
			check(mine >= 1, "%s %s: the look is drawn" % [s, art])
			check(not stack.has("base_" + s), "%s %s: the base %s strip is replaced" % [s, art, s])
			for other in SLOTS:
				if other != s:
					check(stack.has("base_" + other), "%s %s: the empty %s slot shows the base" % [s, art, other])
			check(stack.has("base_skin"), "%s %s: the bare hands still draw" % [s, art])
	check(LOOKS.stack_for("ironjaw", {}, "S").is_empty(), "nothing worn: no strips (the single base sheet draws)")
	var full := LOOKS.looks_for("ironjaw", {"weapon": "cragmaw.weapon", "head": "cragmaw.head", "chest": "cragmaw.chest", "legs": "cragmaw.legs", "boots": "cragmaw.boots"})
	check(full.size() == 5, "a slot -> part loadout maps all five")
	for art in ["S", "E"]:
		for st in LOOKS.stack_for("ironjaw", full, art):
			check(st.begins_with(FAMILY) or st.begins_with("base_skin"), "full set %s: no base clothing strip (%s)" % [art, st])


## White silhouette of a sheet (or a blank image when the strip has none).
func _sil(strip: String, kind: String, art: String, size: Vector2i) -> Image:
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for name in [strip, strip + "_back"]:
		var tex := LOOKS.sheet("ironjaw", name, kind, art)
		if tex == null:
			continue
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var white := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		white.fill(Color.WHITE)
		out.blend_rect_mask(white, img, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	return out


func _sil_full(kind: String, art: String, size: Vector2i) -> Image:
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var img := Painted.sheet("ironjaw", kind, art).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var white := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	out.blend_rect_mask(white, img, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	return out


## Pixels of `inner` not inside `outer` (both white silhouettes), as a count.
func _outside(inner: Image, outer: Image) -> int:
	var both := outer.duplicate() as Image
	both.blend_rect(inner, Rect2i(Vector2i.ZERO, inner.get_size()), Vector2i.ZERO)
	var m := both.compute_image_metrics(outer, false)
	if float(m.get("max", 0.0)) <= 0.0:
		return 0
	# per-channel mean difference: an open pixel differs by 255 on all four
	var n := float(inner.get_width() * inner.get_height())
	return maxi(1, int(round(float(m.get("mean", 0.0)) * n / 255.0)))


func _union(sils: Array) -> Image:
	var out: Image = (sils[0] as Image).duplicate()
	for i in range(1, sils.size()):
		out.blend_rect(sils[i], Rect2i(Vector2i.ZERO, out.get_size()), Vector2i.ZERO)
	return out


## No holes: wherever the bare base is opaque, the layered hero stays opaque,
## for every combination of worn slots, every kind, frame and facing. Proven
## per slot (any stack is the base strips with some slots swapped):
## 1. the base slot strips together cover the whole base;
## 2. each look covers the base strip of the slot it replaces (the weapon is
##    the exception: where the old axe was, the ground shows);
## and checked directly on each set worn whole and on every single piece.
func _test_no_holes() -> void:
	for kind in KINDS:
		var s := LOOKS.spec("ironjaw", kind)
		var size := Vector2i(int(s["cell"].x) * int(s["frames"]), int(s["cell"].y))
		for art in ["S", "E"]:
			var full := _sil_full(kind, art, size)
			var base := {}
			var parts: Array = []
			for g in GROUPS:
				base[g] = _sil("base_" + g, kind, art, size)
				parts.append(base[g])
			var split := _union(parts)
			check(_outside(full, split) == 0, "%s %s: the base slot strips cover the whole base (%d px open)" % [kind, art, _outside(full, split)])
			for fam in FAMILIES:
				var worn: Array = [base["skin"]]
				for g in SLOTS:
					var look := _sil("%s_%s" % [fam, g], kind, art, size)
					worn.append(look)
					if g != "weapon":
						var open := _outside(base[g], look)
						check(open == 0, "%s %s %s_%s covers the base %s it replaces (%d px open)" % [kind, art, fam, g, g, open])
					var single: Array = [look]
					for h in GROUPS:
						if h != g:
							single.append(base[h])
					var allowed := _union(single + [base["weapon"]])
					check(_outside(full, allowed) == 0, "%s %s: %s_%s alone leaves no hole" % [kind, art, fam, g])
				var whole := _union(worn + [base["weapon"]])
				var open_full := _outside(full, whole)
				check(open_full == 0, "%s %s: the full %s set leaves no hole (%d px open)" % [kind, art, fam, open_full])


## Legs: the knee and ankle joints are covered by both pieces in every frame
## (no gap), the knee bends the way the joints say, and the walk's knee angle
## is continuous from frame to frame (no snap). The worn leg looks have the
## base leg silhouettes, so they share these joints exactly.
func _test_legs() -> void:
	check(FileAccess.file_exists(LEGS_JSON), "the build wrote the leg joints")
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGS_JSON))
	if not (doc is Dictionary):
		return
	var legs: Dictionary = doc["legs"]
	for kind in KINDS:
		var s := LOOKS.spec("ironjaw", kind)
		var cw := int(s["cell"].x)
		for art in ["S", "E"]:
			var rows: Array = (legs.get(kind, {}) as Dictionary).get(art, [])
			check(rows.size() == int(s["frames"]), "%s %s: leg joints for every frame" % [kind, art])
			var sheets := {}
			for st in ["base_legs"] + FAMILIES.map(func(f): return f + "_legs"):
				var t := LOOKS.sheet("ironjaw", st, kind, art)
				var tb := LOOKS.sheet("ironjaw", st + "_back", kind, art)
				var imgs: Array = []
				for tex in [t, tb]:
					if tex != null:
						var im := (tex as Texture2D).get_image()
						if im.is_compressed():
							im.decompress()
						imgs.append(im)
				sheets[st] = imgs
			for i in rows.size():
				for sd in ["R", "L"]:
					var r: Dictionary = rows[i][sd]
					check(float(r["knee_cover"]) >= 0.9, "%s %s f%02d %s knee: thigh and shin meet (%.2f)" % [kind, art, i, sd, float(r["knee_cover"])])
					check(float(r["ankle_cover"]) >= 0.9, "%s %s f%02d %s ankle: shin and boot meet (%.2f)" % [kind, art, i, sd, float(r["ankle_cover"])])
					if kind == "walk" or kind == "idle":
						check(absf(float(r["knee_deg"])) <= 130.0, "%s %s f%02d %s knee bends %.0f deg (not folded back)" % [kind, art, i, sd, float(r["knee_deg"])])
					if kind == "walk":
						# the walk loops: frame 0 follows frame 11
						var prev: Dictionary = rows[(i + rows.size() - 1) % rows.size()][sd]
						var step := absf(float(r["knee_deg"]) - float(prev["knee_deg"]))
						check(step <= 50.0, "walk %s f%02d %s knee angle is continuous (%.0f deg step)" % [art, i, sd, step])
						check(signf(float(r["knee_deg"])) == signf(float(prev["knee_deg"])) or absf(float(r["knee_deg"])) < 10.0 or absf(float(prev["knee_deg"])) < 10.0, "walk %s f%02d %s knee never flips side" % [art, i, sd])
					var kp: Array = r["knee"]
					var px := Vector2i(int(round(float(kp[0]))) + i * cw, int(round(float(kp[1]))))
					for st in sheets.keys():
						var hit := false
						for im in sheets[st]:
							var img := im as Image
							for dy in [-1, 0, 1]:
								for dx in [-1, 0, 1]:
									var q := px + Vector2i(dx, dy)
									if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() and img.get_pixel(q.x, q.y).a > 0.5:
										hit = true
						check(hit, "%s %s f%02d %s: %s is drawn at the knee joint" % [kind, art, i, sd, st])
	LOOKS.clear_cache()


## The order is the data's stack per facing; strips behind the body first.
func _test_stack_order() -> void:
	var full := LOOKS.looks_for("ironjaw", _parts(SLOTS))
	var order: Dictionary = LOOKS.doc()["stack"]
	for art in ["S", "E"]:
		var stack := LOOKS.stack_for("ironjaw", full, art)
		var backs_done := false
		var last := -1
		var last_back := -1
		for st in stack:
			var is_back := st.ends_with("_back")
			var group := st.trim_suffix("_back").rsplit("_", true, 1)[1]
			var at: int = (order[art] as Array).find(group)
			check(at >= 0, "%s %s is a stack group" % [art, st])
			if is_back:
				check(not backs_done, "%s: %s comes before every front strip" % [art, st])
				check(at > last_back, "%s: back strips follow the stack order" % art)
				last_back = at
			else:
				backs_done = true
				check(at > last, "%s: %s is above %s in the stack order" % [art, st, str(last)])
				last = at
		check((order[art] as Array).find("chest") > (order[art] as Array).find("legs"), "%s: the chest draws over the legs" % art)
		check((order[art] as Array).find("weapon") > (order[art] as Array).find("chest"), "%s: the weapon draws over the chest" % art)
	check(LOOKS.stack_for("ironjaw", full, "S").has("cragmaw_chest_back"), "S: the far arm's sleeve is drawn behind the body")


func _walker(cls: String) -> Node2D:
	var w: Node2D = Walker.new()
	w.class_id = cls
	w.auto_advance = false
	root.add_child(w)
	return w


func _gear_nodes(host: CanvasItem) -> Array:
	var out: Array = []
	for c in host.get_children():
		if str(c.name).begins_with(STACK.NODE_PREFIX) and (c as CanvasItem).visible:
			out.append(c)
	return out


## World walker: each slot on and off, nodes follow the body's region.
func _test_walker_layers() -> void:
	var w := _walker("ironjaw")
	await process_frame
	var body: Sprite2D = w._sprite
	check(w.gear_strips().is_empty() and _gear_nodes(body).is_empty(), "walker: nothing worn adds no node")
	for s in SLOTS:
		w.set_gear_parts(_parts([s]))
		var shown: Array[String] = w.gear_strips()
		var looks := 0
		for st in shown:
			if st.begins_with(FAMILY):
				looks += 1
		check(looks >= 1 and shown.has("%s_%s" % [FAMILY, s]) or shown.has("%s_%s_back" % [FAMILY, s]), "walker: %s on draws its strip (%s)" % [s, shown])
		check(not shown.has("base_" + s), "walker: %s on hides the base %s" % [s, s])
		check(is_zero_approx(body.self_modulate.a), "walker: the single base sheet hides under the strips")
		w.set_gear_parts([])
		check(w.gear_strips().is_empty() and is_equal_approx(body.self_modulate.a, 1.0), "walker: %s off restores the bare base" % s)
	w.set_gear_parts(_parts(SLOTS))
	for dir in ["e", "n", "s", "w"]:
		w.face(dir)
		w._show_idle()
		for n in _gear_nodes(body):
			var spr := n as Sprite2D
			check(spr.region_rect == body.region_rect and spr.flip_h == body.flip_h and spr.offset == body.offset, "walker %s: %s shows the body's cell" % [dir, n.name])
	w.queue_free()
	await process_frame


## Only the strips of the worn slots (and the base strips of the empty ones)
## load, and only for the kind on screen.
func _test_only_worn_load() -> void:
	LOOKS.clear_cache()
	var w := _walker("ironjaw")
	await process_frame
	check(LOOKS.loaded_paths.is_empty(), "nothing worn: no gear sheet is loaded")
	w.set_gear_parts(_parts(["head"]))
	w._show_idle()
	var looks_loaded := []
	for p in LOOKS.loaded_paths:
		check(p.contains("_idle_"), "only the idle on screen loads (%s)" % p.get_file())
		if p.contains("/%s_" % FAMILY):
			looks_loaded.append(p.get_file())
	check(looks_loaded.size() >= 1, "the worn head look loads")
	for f in looks_loaded:
		check(f.contains("cragmaw_head"), "no unworn look loads (%s)" % f)
	w.queue_free()
	await process_frame
	LOOKS.clear_cache()


func _hero(cls: String) -> Pawn:
	var pawn: Pawn = PAWN_SCENE.instantiate()
	pawn.painted_look = true
	pawn.set_gear_parts(_parts(SLOTS))
	root.add_child(pawn)
	pawn.apply_snapshot({"pos": Vector2i(3, 3), "name": "Hero", "class_id": cls, "facing": "E", "seat": 0, "hp": 60, "max_hp": 60, "alive": true}, 0)
	return pawn


func _check_pawn_sync(pawn: Pawn, label: String) -> void:
	var host := pawn._gear_host()
	check(host != null, "%s: the pawn has a body" % label)
	if host == null:
		return
	var tex: Texture2D = null
	if host is AnimatedSprite2D:
		var a := host as AnimatedSprite2D
		tex = a.sprite_frames.get_frame_texture(a.animation, a.frame)
	else:
		tex = (host as Sprite2D).texture
	check(tex != null and tex.has_meta(Painted.KEY_META), "%s: the body shows a painted cell" % label)
	if tex == null or not tex.has_meta(Painted.KEY_META):
		return
	var key: Array = tex.get_meta(Painted.KEY_META)
	var nodes := _gear_nodes(host)
	check(nodes.size() >= 5, "%s: the full set draws its strips (%d)" % [label, nodes.size()])
	for n in nodes:
		var cell: Texture2D = (n as Sprite2D).texture
		var gk: Array = cell.get_meta(LOOKS.KEY_META) if cell != null and cell.has_meta(LOOKS.KEY_META) else []
		check(gk.size() == 5 and gk[2] == key[1] and gk[3] == key[2] and gk[4] == key[3], "%s: %s plays the body's frame %s" % [label, n.name, str(key)])
		check(cell != null and cell.get_size() == tex.get_size(), "%s: %s has the body's cell size" % [label, n.name])


## Dungeon pawn: in every action the strips show the body's kind, facing and frame.
func _test_pawn_sync() -> void:
	var pawn := _hero("ironjaw")
	await _frames(3)
	pawn._sync_gear()
	_check_pawn_sync(pawn, "pawn idle")
	for facing in ["N", "E", "S", "W"]:
		pawn.apply_snapshot({"pos": Vector2i(3, 3), "name": "Hero", "class_id": "ironjaw", "facing": facing, "seat": 0, "hp": 60, "max_hp": 60, "alive": true}, 1)
		await _frames(2)
		pawn._sync_gear()
		_check_pawn_sync(pawn, "pawn idle %s" % facing)
	var plays := {"walk": "walk", "attack": "attack", "cast": "skill", "hit": "hit"}
	for anim in plays.keys():
		var f := pawn.facing.to_lower()
		var name := "%s_%s" % [anim, f]
		var frames: SpriteFrames = Painted.pawn_frames("ironjaw")
		check(frames.has_animation(name), "pawn has %s" % name)
		var strip := pawn.get_node_or_null(Pawn.BODY_STRIP_PATH) as AnimatedSprite2D
		if strip == null:
			pawn._ensure_motion_strips()
			strip = pawn.get_node_or_null(Pawn.BODY_STRIP_PATH) as AnimatedSprite2D
		pawn._strip_holds_body = true
		pawn._active_strip = strip
		strip.visible = true
		strip.play(name)
		for k in [0, 3, 6]:
			strip.frame = mini(k, frames.get_frame_count(name) - 1)
			pawn._sync_gear()
			_check_pawn_sync(pawn, "pawn %s f%d" % [name, strip.frame])
	pawn.queue_free()
	await process_frame


## Other classes: no paper doll, their locked looks, no gear node.
func _test_other_classes() -> void:
	for cls in OTHERS:
		check(not LOOKS.base_enabled(cls) and not Painted.uses_gear_base(cls), "%s keeps its locked look" % cls)
		check(str(Painted.spec(cls, "walk").get("source", "")) == str(Specs.SPECS[cls]["walk"].get("source", "")), "%s walk spec is the locked one" % cls)
		check(Painted.sheet_path(cls, "idle", "S").begins_with("res://art/characters/painted/%s/" % cls), "%s draws its locked sheets" % cls)
		check(LOOKS.looks_for(cls, _parts(SLOTS)).is_empty(), "%s: Ironjaw looks draw nothing on it" % cls)
		var w := _walker(cls)
		await process_frame
		w.set_gear_parts(_parts(SLOTS))
		check(w.gear_strips().is_empty() and is_equal_approx(w._sprite.self_modulate.a, 1.0), "%s walker draws no gear" % cls)
		w.queue_free()
	await process_frame


## Character window portrait stacks the worn looks over the front idle.
func _test_portrait() -> void:
	var win = CHAR_WINDOW.new()
	root.add_child(win)
	win.ensure_built()
	win.progress = {"hero_class": "ironjaw"}
	win._portrait_class = ""
	win._sync_portrait()
	check(win.portrait_gear() == null or win.portrait_gear().node_count() == 0, "portrait: nothing worn adds no node")
	win.refresh_gear(_parts(SLOTS))
	var g = win.portrait_gear()
	check(g != null and g.shown_strips().size() >= 5, "portrait: the full set stacks on the portrait")
	check(g != null and g.shown_strips().has("cragmaw_chest") and not g.shown_strips().has("base_chest"), "portrait: the chest replaces the tunic")
	win.refresh_gear([])
	check(win.portrait_gear().node_count() == 0, "portrait: unequipping clears the stack")
	win.queue_free()
	await process_frame


## Performance mode: the hero keeps 1x cells, gear still draws, nothing extra
## exists when nothing is worn.
func _test_performance_mode() -> void:
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	await _frames(2)
	w.settings.set_performance(true)
	await _frames(2)
	w.walker.use_class("ironjaw")
	w.walker.set_gear_parts([])
	check(w.walker.gear_strips().is_empty() and w.walker.gear_stack().node_count() == 0, "performance: nothing worn costs no node")
	w.walker.set_gear_parts(_parts(SLOTS))
	w.walker._show_idle()
	var strips: Array[String] = w.walker.gear_strips()
	check(strips.size() >= 5, "performance: the full set still draws (%d strips)" % strips.size())
	for n in _gear_nodes(w.walker._sprite):
		var tex := (n as Sprite2D).texture
		check(tex != null and tex.get_height() <= Specs.MAX_CELL, "performance: %s is a 1x sheet" % n.name)
	w.walker.set_gear_parts([])
	w.settings.set_performance(false)
	w.queue_free()
	await _frames(2)
