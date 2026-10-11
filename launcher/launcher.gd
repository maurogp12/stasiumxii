extends Control

## The PC launcher screen: news, installed vs latest version, update with
## progress and speed, Repair, Visual settings and Play.
## Network and disk work runs on a worker thread; this script only draws.

const Core := preload("res://launcher/launcher_core.gd")
const Config := preload("res://launcher/launcher_config.gd")
const Updater := preload("res://launcher/launcher_updater.gd")
const BACKDROP := preload("res://launcher/art/backdrop.jpg")

const GOLD := Color(0.98, 0.82, 0.42)
const INK := Color(0.07, 0.08, 0.11, 0.86)

var boot: Node
var updater := Updater.new()
var manifest: Dictionary = {}
var plan: Dictionary = {}

var _thread: Thread
var _job := ""
var _job_result: Dictionary = {}
var _job_done := false
var _job_mutex := Mutex.new()
## True once files on disk differ from what was mounted at boot.
var _needs_restart := false
var _offline := false

var news_label: RichTextLabel
var version_label: Label
var status_label: Label
var detail_label: Label
var progress: ProgressBar
var play_button: Button
var update_button: Button
var repair_button: Button
var visuals_button: Button
var _visuals_panel: Node


func _ready() -> void:
	boot = get_node_or_null("/root/LauncherBoot")
	_build_ui()
	if boot == null:
		_show_status("Launcher boot missing: run the PC build.", "")
		return
	if boot.mount_error == "restarting":
		_show_status("Finishing the launcher update...", "")
		return
	_needs_restart = not boot.content_ready()
	_refresh_versions()
	visuals_button.visible = boot.content_ready()
	if boot.autoplay and boot.content_ready():
		_show_status("Starting...", "")
		_go_play.call_deferred()
		return
	_check_updates(false)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		updater.cancel()
		_thread.wait_to_finish()


# --- worker jobs -------------------------------------------------------------

func _check_updates(deep: bool) -> void:
	_start_job("repair" if deep else "check", func() -> Dictionary:
		var got := updater.fetch_manifest(boot.manifest_url)
		if not got["ok"]:
			return got
		var p := updater.make_plan(got["manifest"], boot.install_dir, deep)
		return {"ok": true, "manifest": got["manifest"], "plan": p})


func _apply_update() -> void:
	var m := manifest
	var p := plan
	_start_job("apply", func() -> Dictionary:
		return updater.apply(p, m, boot.manifest_url, boot.install_dir))


func _start_job(job: String, work: Callable) -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_job = job
	_job_done = false
	_set_busy(true)
	_thread = Thread.new()
	_thread.start(func() -> void:
		var r: Dictionary = work.call()
		_job_mutex.lock()
		_job_result = r
		_job_done = true
		_job_mutex.unlock())


func _process(_delta: float) -> void:
	if _job == "":
		return
	var snap := updater.snapshot()
	_draw_progress(snap)
	_job_mutex.lock()
	var finished := _job_done
	var result := _job_result
	_job_mutex.unlock()
	if not finished:
		return
	_thread.wait_to_finish()
	var job := _job
	_job = ""
	_set_busy(false)
	match job:
		"check", "repair":
			_on_checked(result, job == "repair")
		"apply":
			_on_applied(result)


func _on_checked(result: Dictionary, deep: bool) -> void:
	if not result["ok"]:
		_offline = true
		if boot.content_ready():
			_show_status("Offline - you can play the installed version.", str(result["error"]))
			play_button.disabled = false
		else:
			_show_status("Could not check for updates.", str(result["error"]))
		update_button.text = "Retry"
		update_button.disabled = false
		return
	_offline = false
	manifest = result["manifest"]
	plan = result["plan"]
	news_label.text = str(manifest.get("news", ""))
	_refresh_versions()
	if plan["fetch"].is_empty() and plan["remove"].is_empty():
		if not plan["up_to_date"]:
			# Only the record is behind (a news-only release): note it.
			var record := Core.record_for(manifest, Core.read_install(boot.install_dir))
			record["manifest_url"] = boot.manifest_url
			Core.write_install(boot.install_dir, record)
			_needs_restart = _needs_restart or not boot.content_ready()
			_refresh_versions()
		_show_status("All files verified. Ready to play." if deep else "Up to date. Ready to play.", "")
		progress.value = 100.0
		update_button.text = "Up to date"
		update_button.disabled = true
		play_button.disabled = false
		if boot.auto:
			_go_play.call_deferred()
		return
	var what := "Repair needs %s." if deep else "Update available: %s."
	_show_status(what % Core.human_bytes(plan["download_bytes"]), _reasons_text())
	update_button.text = "Update"
	update_button.disabled = false
	play_button.disabled = true
	# Like Wakfu: start right away; Update is there to retry.
	_apply_update()


func _on_applied(result: Dictionary) -> void:
	if not result["ok"]:
		_show_status("Update stopped.", str(result["error"]))
		update_button.text = "Retry"
		update_button.disabled = false
		play_button.disabled = not boot.content_ready()
		return
	_needs_restart = _needs_restart or bool(result.get("changed", true))
	_refresh_versions()
	_show_status("Update installed (%s downloaded)." % Core.human_bytes(result["downloaded"]), "")
	progress.value = 100.0
	update_button.text = "Up to date"
	update_button.disabled = true
	play_button.disabled = false
	if boot.auto:
		_go_play.call_deferred()


func _reasons_text() -> String:
	var lines: PackedStringArray = []
	for item in plan["fetch"]:
		lines.append("%s  %s  (%s)" % [item["entry"]["name"], Core.human_bytes(item["entry"]["size"]), item["reason"]])
	return "\n".join(lines)


# --- buttons -----------------------------------------------------------------

func _on_play() -> void:
	_go_play()


func _go_play() -> void:
	if _needs_restart:
		# Fresh packs are only mounted at boot, before the game's autoloads.
		_show_status("Starting the game...", "")
		boot.restart(PackedStringArray(["--play"]))
		return
	get_tree().change_scene_to_file(Config.GAME_SCENE)


func _on_update() -> void:
	if not manifest.is_empty() and not plan.is_empty() and not _offline and not plan["fetch"].is_empty():
		_apply_update()
	else:
		_check_updates(false)


func _on_repair() -> void:
	_check_updates(true)


func _on_visuals() -> void:
	if _visuals_panel == null:
		var settings: RefCounted = load("res://backend/visual_settings.gd").new()
		_visuals_panel = load("res://ui/visual_settings_panel.gd").new()
		add_child(_visuals_panel)
		_visuals_panel.setup(settings, true)
	_visuals_panel.show_panel()


# --- drawing -----------------------------------------------------------------

func _draw_progress(snap: Dictionary) -> void:
	var phase := str(snap["phase"])
	if phase in ["downloading", "verifying"]:
		var total := maxi(1, int(snap["bytes_total"]))
		progress.value = 100.0 * float(snap["bytes_done"]) / float(total)
		var speed := float(snap["speed"])
		var eta := ""
		if speed > 1.0 and phase == "downloading":
			var secs := int((total - int(snap["bytes_done"])) / speed)
			eta = "   ·   %d:%02d left" % [secs / 60, secs % 60]
		detail_label.text = "%s / %s   ·   %.1f MB/s%s\n%s" % [
			Core.human_bytes(snap["bytes_done"]), Core.human_bytes(total),
			speed / (1024.0 * 1024.0), eta, str(snap["file"])]
		status_label.text = str(snap["message"])
	elif phase == "checking":
		status_label.text = str(snap["message"])


func _show_status(text: String, detail: String) -> void:
	status_label.text = text
	detail_label.text = detail


func _set_busy(busy: bool) -> void:
	update_button.disabled = busy
	repair_button.disabled = busy
	if busy:
		play_button.disabled = true


func _refresh_versions() -> void:
	var installed: String = Core.read_install(boot.install_dir).get("version", "")
	var latest: String = manifest.get("version", "?")
	version_label.text = "Installed: %s      Latest: %s" % [installed if installed != "" else "none", latest]


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = BACKDROP
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.18)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := Label.new()
	title.text = "STASIUM XII"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.02))
	title.add_theme_constant_override("outline_size", 12)
	title.position = Vector2(36, 22)
	add_child(title)
	var sub := Label.new()
	sub.text = "PC launcher"
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	sub.add_theme_constant_override("outline_size", 6)
	sub.position = Vector2(40, 92)
	add_child(sub)

	var news_card := _card()
	news_card.anchor_left = 0.0
	news_card.anchor_right = 0.0
	news_card.anchor_top = 0.0
	news_card.anchor_bottom = 1.0
	news_card.offset_left = 32
	news_card.offset_right = 452
	news_card.offset_top = 132
	news_card.offset_bottom = -212
	add_child(news_card)
	var news_box := VBoxContainer.new()
	news_card.add_child(news_box)
	var news_title := Label.new()
	news_title.text = "News"
	news_title.add_theme_font_size_override("font_size", 22)
	news_title.add_theme_color_override("font_color", GOLD)
	news_box.add_child(news_title)
	news_label = RichTextLabel.new()
	news_label.bbcode_enabled = false
	news_label.fit_content = false
	news_label.scroll_active = true
	news_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	news_label.add_theme_font_size_override("normal_font_size", 15)
	news_label.text = "Checking for news..."
	news_box.add_child(news_label)

	var bar := _card()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 32
	bar.offset_right = -32
	bar.offset_top = -196
	bar.offset_bottom = -24
	add_child(bar)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	bar.add_child(col)
	version_label = Label.new()
	version_label.add_theme_font_size_override("font_size", 15)
	version_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	col.add_child(version_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 19)
	status_label.text = "Starting..."
	col.add_child(status_label)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 22)
	progress.show_percentage = true
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(6)
	progress.add_theme_stylebox_override("fill", fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(6)
	progress.add_theme_stylebox_override("background", track)
	col.add_child(progress)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	detail_label = Label.new()
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88))
	detail_label.clip_text = true
	detail_label.custom_minimum_size = Vector2(0, 40)
	row.add_child(detail_label)
	visuals_button = _button("Visual settings", 15, _on_visuals)
	row.add_child(visuals_button)
	repair_button = _button("Repair", 15, _on_repair)
	row.add_child(repair_button)
	update_button = _button("Update", 15, _on_update)
	row.add_child(update_button)
	play_button = _button("PLAY", 24, _on_play)
	play_button.custom_minimum_size = Vector2(170, 52)
	play_button.disabled = true
	var play_style := StyleBoxFlat.new()
	play_style.bg_color = Color(0.85, 0.55, 0.12)
	play_style.set_corner_radius_all(8)
	play_button.add_theme_stylebox_override("normal", play_style)
	var play_hover := play_style.duplicate()
	play_hover.bg_color = Color(0.95, 0.65, 0.2)
	play_button.add_theme_stylebox_override("hover", play_hover)
	row.add_child(play_button)


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = Color(GOLD, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	return card


func _button(text: String, size: int, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	return b
