extends RefCounted

## Painted NPC role art for the open world. Preload. No global class.
##
## Files live in `res://art/characters/world/npc/<folder>/`:
##   <folder>.json             frame_size_2x, pivot_px_2x, mirror, anims
##   <anim>_s.png, <anim>_n.png    1x strips (half of the 2x frame), played in game
##   _2x/<anim>_{s,n}.png          2x masters, kept for rebakes and media
##
## Only S and N are painted. W and E come from the json `mirror` block, which
## follows the locked facing rule: W = S flipped, E = N flipped.
##
## Art letters are the locked rule (S front down-right, W front down-left,
## N back up-left, E back up-right). The world walker names grid steps instead:
## e = +x (screen down-right), s = +y (down-left), n = -y (up-right),
## w = -x (up-left). `ART_FOR_STEP` converts one to the other.

const ROOT := "res://art/characters/world/npc/"

## data/world/npcs.json `role` -> art folder. Every other role uses its own name.
const ROLE_FOLDER := {
	"seer": "shard_seer",
}

## World step letter -> locked art letter.
const ART_FOR_STEP := {
	"e": "S",
	"s": "W",
	"w": "N",
	"n": "E",
}

## Drawn scale of a 1x frame. A 1x figure is about 64 px tall, so the NPC
## stands about 54 px on screen at zoom 1.0. The default hero (Ironjaw)
## is about 56 px to the top of the helm, so NPCs read a touch shorter.
const DRAW_SCALE_1X := 0.84

## Anim a paused NPC plays at its post or prop. Wardens ship `patrol_look`.
const WORK_ANIMS: Array[String] = ["work", "patrol_look"]

static var _cache: Dictionary = {}


static func folder_for(role: String) -> String:
	return str(ROLE_FOLDER.get(role, role))


static func has_role(role: String) -> bool:
	return not load_role(role).is_empty()


static func clear_cache() -> void:
	_cache.clear()


## Empty when the role has no painted folder (the caller falls back).
static func load_role(role: String) -> Dictionary:
	var folder := folder_for(role)
	if folder == "":
		return {}
	if _cache.has(folder):
		return _cache[folder]
	var built := _build(folder)
	_cache[folder] = built
	return built


static func _build(folder: String) -> Dictionary:
	var root := ROOT + folder + "/"
	var meta_path := root + folder + ".json"
	if not FileAccess.file_exists(meta_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var meta: Dictionary = parsed
	var size_2x: Array = meta.get("frame_size_2x", [256, 256])
	var pivot_2x: Array = meta.get("pivot_px_2x", [128, 240])
	var frame := Vector2i(int(size_2x[0]) / 2, int(size_2x[1]) / 2)
	var pivot := Vector2(float(pivot_2x[0]) * 0.5, float(pivot_2x[1]) * 0.5)
	var anims := {}
	var raw_anims: Dictionary = meta.get("anims", {})
	for anim_name in raw_anims.keys():
		var spec: Dictionary = raw_anims[anim_name]
		var texs := {}
		for src in ["s", "n"]:
			var path := "%s%s_%s.png" % [root, str(anim_name), src]
			if not ResourceLoader.exists(path):
				continue
			var tex := load(path) as Texture2D
			if tex != null:
				texs[src] = tex
		if texs.size() < 2:
			continue
		anims[str(anim_name)] = {
			"frames": maxi(1, int(spec.get("frames", 1))),
			"fps": maxf(1.0, float(spec.get("fps", 8.0))),
			"loop": bool(spec.get("loop", true)),
			"stride_px_2x": float(spec.get("stride_px", 0.0)),
			"tex": texs,
		}
	if not anims.has("idle"):
		return {}
	var mirror: Dictionary = meta.get("mirror", {})
	var work := ""
	for name in WORK_ANIMS:
		if anims.has(name):
			work = name
			break
	var built := {
		"folder": folder,
		"meta": meta,
		"frame": frame,
		"pivot": pivot,
		"mirror": mirror,
		"anims": anims,
		"work": work,
	}
	built["head_top"] = _head_top(built)
	return built


## Where a facing draws from: the painted strip letter and the flip.
## Uses the json mirror block for W and E; S and N are drawn as painted.
static func source_for(art: Dictionary, step_dir: String) -> Dictionary:
	var letter := str(ART_FOR_STEP.get(step_dir.to_lower(), "S"))
	if letter == "S" or letter == "N":
		return {"src": letter.to_lower(), "flip": false}
	var mirror: Dictionary = art.get("mirror", {})
	var rule: Dictionary = mirror.get(letter, {})
	var src := str(rule.get("src", "S" if letter == "W" else "N")).to_lower()
	return {"src": src, "flip": bool(rule.get("flip_h", true))}


## Highest opaque row over every idle frame (S and N), in 1x frame pixels.
## The name plate sits on this line so it does not bob with each frame.
static func _head_top(art: Dictionary) -> int:
	var frame: Vector2i = art["frame"]
	var best := frame.y
	var idle: Dictionary = (art["anims"] as Dictionary)["idle"]
	for src in ["s", "n"]:
		var tex: Texture2D = (idle["tex"] as Dictionary).get(src, null)
		if tex == null:
			continue
		var image := tex.get_image()
		if image == null or image.is_empty():
			continue
		if image.is_compressed():
			image.decompress()
		var rows := mini(image.get_height(), frame.y)
		for y in rows:
			if y >= best:
				break
			var hit := false
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.2:
					hit = true
					break
			if hit:
				best = y
				break
	return best if best < frame.y else 0


## Region of one frame on a strip.
static func frame_rect(art: Dictionary, frame_index: int) -> Rect2:
	var frame: Vector2i = art["frame"]
	return Rect2(frame_index * frame.x, 0, frame.x, frame.y)


## Ground speed in world pixels per second for the walk strip.
## stride_px is the 2x distance of one full walk loop.
static func walk_speed(art: Dictionary) -> float:
	var anims: Dictionary = art["anims"]
	if not anims.has("walk"):
		return 0.0
	var walk: Dictionary = anims["walk"]
	var stride_world := float(walk["stride_px_2x"]) * 0.5 * DRAW_SCALE_1X
	var loop_sec := float(walk["frames"]) / float(walk["fps"])
	if loop_sec <= 0.0:
		return 0.0
	return stride_world / loop_sec
