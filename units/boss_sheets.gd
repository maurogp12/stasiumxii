extends RefCounted

## Boss frame sheets (Mauro 2 Oct 2026: "fix how the dungeon bosses look …
## they have no legs"; option 1: new art with legs, same looks, wired here).
## View only. A boss with no sheet keeps its painting and the foe gait.
##
## Files: res://art/stasis/bosses/<art>/<art>_<anim>_<dir>.png
##   art  = the boss painting's name (e.g. warden_of_the_sheaves)
##   anim = idle | walk | attack | cast | hit
##   dir  = the artist's letter (Mauro 2 Oct 2026 boss rule): s = front walking
##          down-right, w = front walking down-left, e = back walking up-right,
##          n = back walking up-left. FILE_LETTER maps the engine's grid
##          facing (E down-right, S down-left, N up-right, W up-left) to it.
## One horizontal strip per file, cells CELL.x wide, frame count = width / CELL.x.
## Feet on FEET_Y in every cell; walk strips may be taller (336) with the
## same feet line so the low foot fits.
## Fallbacks: a missing facing uses its screen mirror (E↔S, N↔W), then any
## other; cast uses attack.

const DIR := "res://art/stasis/bosses/"
const CELL := Vector2i(288, 320)
const FEET_Y := 300
const ANIMS := ["idle", "walk", "attack", "cast", "hit"]
const IDLE_FPS := 6.0
## Engine grid facing → artist file letter.
const FILE_LETTER := {"e": "s", "s": "w", "n": "e", "w": "n"}
## Engine facings tried in order, with the screen mirror flag.
const _DIR_ORDER := {
	"e": [["e", false], ["s", true], ["n", false], ["w", true]],
	"s": [["s", false], ["e", true], ["w", false], ["n", true]],
	"n": [["n", false], ["w", true], ["e", false], ["s", true]],
	"w": [["w", false], ["n", true], ["s", false], ["e", true]],
}

static var _cache: Dictionary = {}
## Tests: path → Texture2D, read before the disk.
static var overrides: Dictionary = {}


static func art_name(art_path: String) -> String:
	return art_path.get_file().get_basename()


static func sheet_path(art: String, anim: String, dir: String) -> String:
	return "%s%s/%s_%s_%s.png" % [DIR, art, art, anim, dir]


## {"frames": Array of Texture2D, "mirror": bool} for anim facing dir, or {}.
static func frames_for(art_path: String, anim: String, dir: String) -> Dictionary:
	var art := art_name(art_path)
	if art == "":
		return {}
	var d := dir.strip_edges().to_lower()
	var order: Array = _DIR_ORDER.get(d, _DIR_ORDER["s"])
	var anims := [anim, "attack"] if anim == "cast" else [anim]
	for a in anims:
		for pick in order:
			var frames := _frames_at(sheet_path(art, str(a), str(FILE_LETTER[str(pick[0])])))
			if not frames.is_empty():
				return {"frames": frames, "mirror": bool(pick[1])}
	return {}


static func has_any(art_path: String) -> bool:
	for anim in ANIMS:
		if not frames_for(art_path, anim, "s").is_empty():
			return true
	return false


## Frame index for a one-shot (attack, hit): t 0..1 runs the strip once.
static func once_index(t: float, count: int) -> int:
	if count <= 1:
		return 0
	return clampi(int(floor(clampf(t, 0.0, 1.0) * float(count))), 0, count - 1)


## Walk stride, one step per tile (t 0..1): half the cycle per tile, odd
## tiles lead with the other foot, so a full cycle spans two tiles.
static func cycle_index(t: float, count: int, tile: int = 0) -> int:
	if count <= 1:
		return 0
	var half := maxi(count / 2, 1)
	var base := posmod(tile, 2) * half
	if t <= 0.0:
		return base % count
	if t >= 1.0:
		return (base + half) % count
	return (base + clampi(int(floor(t * float(half))), 0, half - 1)) % count


## Idle loop at IDLE_FPS from a clock in seconds.
static func idle_index(seconds: float, count: int) -> int:
	if count <= 1:
		return 0
	return posmod(int(floor(seconds * IDLE_FPS)), count)


static func clear_cache() -> void:
	_cache.clear()


static func _frames_at(path: String) -> Array:
	if _cache.has(path):
		return _cache[path]
	var sheet: Texture2D = null
	if overrides.has(path):
		sheet = overrides[path]
	elif ResourceLoader.exists(path):
		var loaded: Variant = load(path)
		sheet = loaded if loaded is Texture2D else null
	var frames: Array = []
	if sheet != null and sheet.get_height() > 0:
		var count := maxi(1, int(round(float(sheet.get_width()) / float(CELL.x))))
		var w := float(sheet.get_width()) / float(count)
		for i in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(w * i, 0.0, w, float(sheet.get_height()))
			frames.append(atlas)
	_cache[path] = frames
	return frames
