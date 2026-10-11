extends Node

## First autoload of the PC build. It runs before the game's own autoloads,
## so it mounts the installed content packs (base, then patches oldest first)
## while nothing from them has loaded yet. The launcher scene then shows
## update and Play; Play only changes scene when the packs here are current.
##
## Only lives in StasiumXII.pck (the launcher pack); the content packs never
## carry res://launcher/. See build_tools/pc_release/release.py.

const Core := preload("res://launcher/launcher_core.gd")
const Config := preload("res://launcher/launcher_config.gd")

var install_dir := ""
var manifest_url := ""
## Pack paths mounted at boot, in order.
var mounted: Array[String] = []
var installed_version := ""
var mount_error := ""
## --play: go straight to the game when the install is current (used after a restart).
var autoplay := false
## --auto: update without waiting for a click, then play (tests and the demo clip).
var auto := false
## --self-pack=PATH: the launcher pack to pass back with --main-pack on restart
## (editor binaries on Linux; the Windows exe finds StasiumXII.pck by itself).
var self_pack := ""
var user_args: PackedStringArray = []


func _init() -> void:
	name = "LauncherBoot"
	user_args = OS.get_cmdline_user_args()
	install_dir = _arg("--install-dir=", OS.get_executable_path().get_base_dir())
	self_pack = _arg("--self-pack=", "")
	autoplay = user_args.has("--play")
	auto = user_args.has("--auto")
	manifest_url = _resolve_manifest_url()
	_clean_old_files()
	if _apply_staged_launcher():
		return
	var record := Core.read_install(install_dir)
	installed_version = str(record.get("version", ""))
	var order := Core.mount_order(install_dir, record)
	if order.is_empty():
		mount_error = "not installed" if record.is_empty() else "install incomplete"
		return
	for path in order:
		if not ProjectSettings.load_resource_pack(path, true):
			mount_error = "could not open %s" % path.get_file()
			break
		mounted.append(path)


func _ready() -> void:
	if mount_error == "restarting":
		restart()


## A launcher pack staged as StasiumXII.pck.new by an update Windows would not
## let us swap while running. Nothing has been read from the old one yet that
## matters, so swap now and start again on the new one.
func _apply_staged_launcher() -> bool:
	var main_pack := self_pack if self_pack != "" else install_dir.path_join(
		OS.get_executable_path().get_file().get_basename() + ".pck")
	var staged := main_pack + ".new"
	if not FileAccess.file_exists(staged):
		return false
	var old := main_pack + ".old"
	DirAccess.remove_absolute(old)
	if FileAccess.file_exists(main_pack) and DirAccess.rename_absolute(main_pack, old) != OK:
		return false
	if DirAccess.rename_absolute(staged, main_pack) != OK:
		DirAccess.rename_absolute(old, main_pack)
		return false
	mount_error = "restarting"
	return true


func content_ready() -> bool:
	return mount_error == "" and not mounted.is_empty()


func _arg(prefix: String, fallback: String) -> String:
	for a in user_args:
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


func _resolve_manifest_url() -> String:
	var from_arg := _arg("--manifest-url=", "")
	if from_arg != "":
		return from_arg
	var cfg_path := install_dir.path_join("launcher_config.json")
	if FileAccess.file_exists(cfg_path):
		var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
		if cfg is Dictionary and str(cfg.get("manifest_url", "")).begins_with("http"):
			return str(cfg["manifest_url"])
	return Config.MANIFEST_URL


## Leftovers from swapping files in: the exe or packs renamed to *.old.
func _clean_old_files() -> void:
	for dir in [install_dir, install_dir.path_join(Core.CONTENT_DIR)]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			if f.get_extension().begins_with("old") or f.ends_with(".part"):
				DirAccess.remove_absolute(dir.path_join(f))


## Starts a fresh copy of the game and quits this one.
func restart(extra: PackedStringArray = []) -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	if self_pack != "":
		args.append_array(["--main-pack", self_pack])
		if DisplayServer.get_name() == "headless":
			args.append("--headless")
		else:
			args.append_array(["--rendering-driver", RenderingServer.get_current_rendering_driver_name()])
	var users: PackedStringArray = []
	for a in user_args:
		if a != "--play" and not extra.has(a):
			users.append(a)
	users.append_array(extra)
	if not users.is_empty():
		args.append("--")
		args.append_array(users)
	OS.create_process(OS.get_executable_path(), args)
	get_tree().quit()
