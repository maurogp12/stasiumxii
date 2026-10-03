extends RefCounted

## Loads one world hero from `res://art/characters/world/<id>/`.
##
## Files (horizontal strips, one row, equal frames, left to right):
##   <id>_idle_<dir>.png     one frame. Its size is the frame size.
##   <id>_walk_<dir>.png     walk cycle. Frame count = width / frame width.
##   <id>_run_<dir>.png      run cycle, separate from walk.
##   <id>.json               scale, pivot, and per-gait fps + stride.
## `dir` is n, e, s, or w. A direction may have any frame count.
## `stride` is world pixels traveled in one full loop of that gait.
## Ground speed is stride * fps / frame_count, so the feet keep up with the art.
## Optional `frame_w` / `frame_h` override the idle size. A direction object
## under the gait (`"n": {"fps": 10, "stride": 18}`) overrides that strip only.
##
## Locked front walks (art-team "S", screen down-right) live in
## `locked_s/<id>_walk_S_f00.png` … `f11.png` and replace walk east only.
## Down-left (s), up-right (n), and up-left (w) keep their strips. Facings are
## not mirrored. East scale and pivot come from the walk `"e"` object so the
## planted boot sits on the same ground line as the previous strip.

const DIRS := ["n", "e", "s", "w"]
const LOCKED_FRAMES := 12

var scale := 0.33
var pivot := Vector2(0, -72)
var _gaits := {}
var _idles := {}


func load_class(class_id: String) -> void:
	var root := "res://art/characters/world/%s/" % class_id
	var meta := {}
	var meta_path := root + class_id + ".json"
	if FileAccess.file_exists(meta_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		if typeof(parsed) == TYPE_DICTIONARY:
			meta = parsed
	scale = float(meta.get("scale", 0.33))
	var piv: Array = meta.get("pivot", [0, -72])
	pivot = Vector2(float(piv[0]), float(piv[1])) if piv.size() >= 2 else Vector2(0, -72)
	var idle_s := _tex(root + "%s_idle_s.png" % class_id)
	var frame_w := int(meta.get("frame_w", idle_s.get_width() if idle_s != null else 144))
	var frame_h := int(meta.get("frame_h", idle_s.get_height() if idle_s != null else 160))
	_idles.clear()
	_gaits.clear()
	for dir in DIRS:
		var idle := _tex(root + "%s_idle_%s.png" % [class_id, dir])
		if idle != null:
			_idles[dir] = idle
	for gait in ["walk", "run"]:
		var spec: Dictionary = meta.get(gait, {})
		var texs := {}
		var counts := {}
		for dir in DIRS:
			var tex := _tex(root + "%s_%s_%s.png" % [class_id, gait, dir])
			if tex == null:
				continue
			var fw := frame_w
			var dir_spec: Dictionary = spec.get(dir, {})
			if dir_spec.has("frame_w"):
				fw = int(dir_spec["frame_w"])
			var count := maxi(1, int(tex.get_width() / maxi(fw, 1)))
			texs[dir] = tex
			counts[dir] = count
		var gait_row := {
			"fps": float(spec.get("fps", 8.0)),
			"stride": float(spec.get("stride", 24.0)),
			"frame": Vector2i(frame_w, frame_h),
			"tex": texs,
			"count": counts,
			"spec": spec,
			"cell": {},
			"draw_scale": {},
			"draw_pivot": {},
		}
		if gait == "walk":
			_install_locked_east(class_id, root, spec, gait_row)
		_gaits[gait] = gait_row


func _install_locked_east(class_id: String, root: String, spec: Dictionary, gait_row: Dictionary) -> void:
	var packed := _pack_locked(class_id, root)
	if packed.is_empty():
		return
	(gait_row["tex"] as Dictionary)["e"] = packed["tex"]
	(gait_row["count"] as Dictionary)["e"] = int(packed["count"])
	(gait_row["cell"] as Dictionary)["e"] = packed["frame"]
	var over: Dictionary = spec.get("e", {})
	if over.has("scale"):
		(gait_row["draw_scale"] as Dictionary)["e"] = float(over["scale"])
	if over.has("pivot"):
		var piv: Array = over["pivot"]
		if piv.size() >= 2:
			(gait_row["draw_pivot"] as Dictionary)["e"] = Vector2(float(piv[0]), float(piv[1]))


## Copies the delivered frames into one strip. Pixels are not resampled.
func _pack_locked(class_id: String, root: String) -> Dictionary:
	var images: Array[Image] = []
	for i in LOCKED_FRAMES:
		var path := "%slocked_s/%s_walk_S_f%02d.png" % [root, class_id, i]
		var tex := _tex(path)
		if tex == null:
			return {}
		var img := tex.get_image()
		if img == null or img.is_empty():
			return {}
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		images.append(img)
	var fw := images[0].get_width()
	var fh := images[0].get_height()
	if fw <= 0 or fh <= 0:
		return {}
	var sheet := Image.create(fw * LOCKED_FRAMES, fh, false, Image.FORMAT_RGBA8)
	for i in LOCKED_FRAMES:
		var img := images[i]
		if img.get_width() != fw or img.get_height() != fh:
			return {}
		sheet.blit_rect(img, Rect2i(0, 0, fw, fh), Vector2i(i * fw, 0))
	return {
		"tex": ImageTexture.create_from_image(sheet),
		"frame": Vector2i(fw, fh),
		"count": LOCKED_FRAMES,
	}


func _tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	return res as Texture2D


func has_gait(gait: String) -> bool:
	return _gaits.has(gait) and not (_gaits[gait]["tex"] as Dictionary).is_empty()


func idle(dir: String) -> Texture2D:
	return _idles.get(dir, null)


func texture(gait: String, dir: String) -> Texture2D:
	if not _gaits.has(gait):
		return null
	return (_gaits[gait]["tex"] as Dictionary).get(dir, null)


func frame_size(gait: String) -> Vector2i:
	if not _gaits.has(gait):
		return Vector2i(144, 160)
	return _gaits[gait]["frame"]


func frame_size_of(gait: String, dir: String) -> Vector2i:
	if not _gaits.has(gait):
		return Vector2i(144, 160)
	var cells: Dictionary = _gaits[gait]["cell"]
	if cells.has(dir):
		return cells[dir]
	return _gaits[gait]["frame"]


func has_locked_walk(dir: String) -> bool:
	if not _gaits.has("walk"):
		return false
	return (_gaits["walk"]["cell"] as Dictionary).has(dir)


func draw_scale(gait: String, dir: String) -> float:
	if not _gaits.has(gait):
		return scale
	var scales: Dictionary = _gaits[gait]["draw_scale"]
	if scales.has(dir):
		return float(scales[dir])
	return scale


func draw_pivot(gait: String, dir: String) -> Vector2:
	if not _gaits.has(gait):
		return pivot
	var pivots: Dictionary = _gaits[gait]["draw_pivot"]
	if pivots.has(dir):
		return pivots[dir]
	return pivot


func frame_count(gait: String, dir: String) -> int:
	if not _gaits.has(gait):
		return 1
	return int((_gaits[gait]["count"] as Dictionary).get(dir, 1))


func fps_of(gait: String, dir: String) -> float:
	return float(_numbers(gait, dir).x)


func stride_of(gait: String, dir: String) -> float:
	return float(_numbers(gait, dir).y)


func speed_of(gait: String, dir: String) -> float:
	var n := _numbers(gait, dir)
	var count := maxi(1, frame_count(gait, dir))
	return float(n.x) * float(n.y) / float(count)


func _numbers(gait: String, dir: String) -> Vector2:
	if not _gaits.has(gait):
		return Vector2(8, 24)
	var g: Dictionary = _gaits[gait]
	var fps := float(g["fps"])
	var stride := float(g["stride"])
	var spec: Dictionary = g["spec"]
	var over: Dictionary = spec.get(dir, {})
	if over.has("fps"):
		fps = float(over["fps"])
	if over.has("stride"):
		stride = float(over["stride"])
	return Vector2(fps, stride)
