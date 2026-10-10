class_name VisualSettings
extends RefCounted

## Player-facing optional visuals for the PC client. Not an autoload: the
## world scene and the hub each keep one, and the file is the shared store.
## Gameplay (walk mesh, blockers, exits, the character, HUD) does not read these.

signal flag_changed(flag: String, enabled: bool)
signal preset_changed(preset_name: String)

const FLAGS: Array[String] = ["animations", "weather", "post_fx", "sway_shadows", "decor"]
const STORE := "user://crosshaven_visual.cfg"
## Performance mode: the world keeps its look but holds still, and loads the
## 1x art instead of the 2x masters. Not one of the preset FLAGS: it sits on
## top of them. `bind(host, "performance", ...)` follows it.
const PERFORMANCE := "performance"
## Derived: true while ambient motion plays (animations on, performance off).
## `bind(host, "motion", ...)` follows both switches at once.
const MOTION := "motion"
## A machine under any of these looks weak; the world offers performance mode once.
const WEAK_CORES := 4
const WEAK_RAM_BYTES := 8 * 1024 * 1024 * 1024

var flags := {
	"animations": true,
	"weather": true,
	"post_fx": true,
	"sway_shadows": true,
	"decor": true,
}
var preset := "Full"
## Performance mode on (world animations off, 1x art, lighter caches).
var performance := false
## The one-time "this machine looks slow" offer was shown (answered or not).
var performance_prompted := false

static var current: VisualSettings
## Performance mode as last loaded or set by any instance. Every instance
## shares the one store, so the newest value wins; `still()` reads this.
static var _still_now := false
static var _still_known := false

var _binds: Array = []


func _init() -> void:
	current = self
	load_store()


func enabled(flag: String) -> bool:
	if flag == PERFORMANCE:
		return performance
	if flag == MOTION:
		return motion()
	return bool(flags.get(flag, false))


## Ambient motion plays: the animations flag is on and performance mode is off.
func motion() -> bool:
	return bool(flags.get("animations", true)) and not performance


## True while the live settings ask the world to hold still. With no settings
## object yet (a scene opened on its own) the saved store answers.
static func still() -> bool:
	if not _still_known:
		VisualSettings.new()
	return _still_now


static func _note_still(on: bool) -> void:
	_still_now = on
	_still_known = true


## Turn performance mode on or off. Saved, and applied live through `bind`.
func set_performance(on: bool) -> void:
	if performance == on:
		return
	var was_motion := motion()
	performance = on
	_note_still(on)
	save_store()
	flag_changed.emit(PERFORMANCE, on)
	if motion() != was_motion:
		flag_changed.emit(MOTION, motion())
	preset_changed.emit(preset)


## What this machine looks like: CPU cores, physical RAM, and the GPU.
static func machine_profile() -> Dictionary:
	var mem: Dictionary = OS.get_memory_info()
	var gpu_type := -1
	var gpu_name := ""
	if DisplayServer.get_name() != "headless":
		gpu_type = int(RenderingServer.get_video_adapter_type())
		gpu_name = RenderingServer.get_video_adapter_name()
	return {
		"cores": OS.get_processor_count(),
		"ram": int(mem.get("physical", -1)),
		"gpu_type": gpu_type,
		"gpu_name": gpu_name,
	}


## Why a machine with `profile` looks weak (empty when it does not): fewer
## than 4 cores, under 8 GB of RAM, or an integrated or software GPU.
static func weak_reasons(profile: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var cores := int(profile.get("cores", 0))
	if cores > 0 and cores < WEAK_CORES:
		out.append("%d CPU cores" % cores)
	var ram := int(profile.get("ram", -1))
	if ram > 0 and ram < WEAK_RAM_BYTES:
		out.append("%.1f GB of RAM" % (float(ram) / 1073741824.0))
	var gpu_type := int(profile.get("gpu_type", -1))
	var gpu_name := str(profile.get("gpu_name", "")).to_lower()
	if gpu_type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		out.append("an integrated GPU")
	elif gpu_type == RenderingDevice.DEVICE_TYPE_CPU or gpu_name.contains("llvmpipe") or gpu_name.contains("swiftshader") or gpu_name.contains("software"):
		out.append("software graphics")
	return out


## True once per install: the offer has not been shown, performance mode is
## off, and the machine looks weak.
func should_offer_performance(profile: Dictionary) -> bool:
	return not performance_prompted and not performance and not weak_reasons(profile).is_empty()


## The offer was shown. It never comes back, whatever the player picked.
func mark_performance_prompted() -> void:
	if performance_prompted:
		return
	performance_prompted = true
	save_store()


func set_flag(flag: String, on: bool) -> void:
	if flag == PERFORMANCE:
		set_performance(on)
		return
	if not flags.has(flag) or bool(flags[flag]) == on:
		return
	var was_motion := motion()
	flags[flag] = on
	preset = _matching_preset()
	save_store()
	flag_changed.emit(flag, on)
	if motion() != was_motion:
		flag_changed.emit(MOTION, motion())
	preset_changed.emit(preset)


## Presets set the five FLAGS. "Full" is everything on, so it also turns
## performance mode off; the others leave performance mode as it is.
func apply_preset(preset_name: String) -> void:
	var next := {}
	match preset_name:
		"Reduced":
			next = {
				"animations": true,
				"weather": false,
				"post_fx": false,
				"sway_shadows": false,
				"decor": true,
			}
		"Minimal":
			next = {
				"animations": false,
				"weather": false,
				"post_fx": false,
				"sway_shadows": false,
				"decor": false,
			}
		_:
			preset_name = "Full"
			next = {
				"animations": true,
				"weather": true,
				"post_fx": true,
				"sway_shadows": true,
				"decor": true,
			}
	preset = preset_name
	var was_motion := motion()
	var was_performance := performance
	var changed: Array[String] = []
	for flag in FLAGS:
		if bool(flags[flag]) != bool(next[flag]):
			flags[flag] = bool(next[flag])
			changed.append(flag)
	if preset_name == "Full":
		performance = false
	_note_still(performance)
	save_store()
	for flag in changed:
		flag_changed.emit(flag, bool(flags[flag]))
	if performance != was_performance:
		flag_changed.emit(PERFORMANCE, performance)
	if motion() != was_motion:
		flag_changed.emit(MOTION, motion())
	preset_changed.emit(preset)


## Future effects call this once. `apply` receives the current value immediately
## and again whenever that flag changes. `host` is unused except to document
## the owner; the callable is what runs.
func bind(host: Object, flag: String, apply: Callable) -> void:
	_binds.append({"host": host, "flag": flag, "apply": apply})
	apply.call(enabled(flag))
	if not flag_changed.is_connected(_on_flag):
		flag_changed.connect(_on_flag)


func load_store() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(STORE) != OK:
		preset = "Full"
		performance = false
		performance_prompted = false
		_note_still(false)
		return
	for flag in FLAGS:
		flags[flag] = bool(cfg.get_value("visuals", flag, true))
	preset = str(cfg.get_value("visuals", "preset", _matching_preset()))
	performance = bool(cfg.get_value("visuals", PERFORMANCE, false))
	_note_still(performance)
	performance_prompted = bool(cfg.get_value("visuals", "performance_prompted", false))


func save_store() -> void:
	var cfg := ConfigFile.new()
	for flag in FLAGS:
		cfg.set_value("visuals", flag, bool(flags[flag]))
	cfg.set_value("visuals", "preset", preset)
	cfg.set_value("visuals", PERFORMANCE, performance)
	cfg.set_value("visuals", "performance_prompted", performance_prompted)
	cfg.save(STORE)


func detach() -> void:
	_binds.clear()
	if flag_changed.is_connected(_on_flag):
		flag_changed.disconnect(_on_flag)


func _on_flag(flag: String, on: bool) -> void:
	for rec in _binds:
		if str(rec["flag"]) == flag:
			(rec["apply"] as Callable).call(on)


func _matching_preset() -> String:
	if enabled("animations") and enabled("weather") and enabled("post_fx") and enabled("sway_shadows") and enabled("decor"):
		return "Full"
	if enabled("animations") and enabled("decor") and not enabled("weather") and not enabled("post_fx") and not enabled("sway_shadows"):
		return "Reduced"
	if not enabled("animations") and not enabled("weather") and not enabled("post_fx") and not enabled("sway_shadows") and not enabled("decor"):
		return "Minimal"
	return "Custom"
