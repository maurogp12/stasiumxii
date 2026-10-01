class_name VisualSettings
extends RefCounted

## Player-facing optional visuals for the PC client. Not an autoload: the
## world scene and the hub each keep one, and the file is the shared store.
## Gameplay (walk mesh, blockers, exits, the character, HUD) does not read these.

signal flag_changed(flag: String, enabled: bool)
signal preset_changed(preset_name: String)

const FLAGS: Array[String] = ["animations", "weather", "post_fx", "sway_shadows", "decor"]
const STORE := "user://crosshaven_visual.cfg"

var flags := {
	"animations": true,
	"weather": true,
	"post_fx": true,
	"sway_shadows": true,
	"decor": true,
}
var preset := "Full"

static var current: VisualSettings

var _binds: Array = []


func _init() -> void:
	current = self
	load_store()


func enabled(flag: String) -> bool:
	return bool(flags.get(flag, false))


func set_flag(flag: String, on: bool) -> void:
	if not flags.has(flag) or bool(flags[flag]) == on:
		return
	flags[flag] = on
	preset = _matching_preset()
	save_store()
	flag_changed.emit(flag, on)
	preset_changed.emit(preset)


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
	var changed: Array[String] = []
	for flag in FLAGS:
		if bool(flags[flag]) != bool(next[flag]):
			flags[flag] = bool(next[flag])
			changed.append(flag)
	save_store()
	for flag in changed:
		flag_changed.emit(flag, bool(flags[flag]))
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
		return
	for flag in FLAGS:
		flags[flag] = bool(cfg.get_value("visuals", flag, true))
	preset = str(cfg.get_value("visuals", "preset", _matching_preset()))


func save_store() -> void:
	var cfg := ConfigFile.new()
	for flag in FLAGS:
		cfg.set_value("visuals", flag, bool(flags[flag]))
	cfg.set_value("visuals", "preset", preset)
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
