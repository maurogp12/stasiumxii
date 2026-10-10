extends SceneTree

## 2400×1080 shots after the one-time progress epoch.
## Seeds the real user:// saves dirty, deletes the marker, then lets the
## Levels and Gear screens load (which runs ProgressEpoch.ensure).
## godot --rendering-driver opengl3 -s res://tests/shot_progress_reset.gd -- <dir>

var _dir := "/opt/cursor/artifacts/reset"
var _frames := 0
var _phase := 0
var _screen: Control


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_dir = text
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	_seed_dirty()


func _seed_dirty() -> void:
	HeroProgress.save_path = ProgressEpoch.DEFAULT_HERO
	GearBag.save_path = ProgressEpoch.DEFAULT_GEAR
	StillVault.save_path = ProgressEpoch.DEFAULT_STILL
	KoliseoWallet.save_path = ProgressEpoch.DEFAULT_WALLET
	ProgressEpoch.marker_path = ProgressEpoch.MARKER_PATH
	ProgressEpoch.enforce_real_paths = true
	if FileAccess.file_exists(ProgressEpoch.marker_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ProgressEpoch.marker_path))
	var hero := HeroProgress.new()
	for cid in HeroProgress.GROWTH:
		hero.record(cid)["level"] = 30
		hero.record(cid)["spent"] = {"mastery": 10}
		hero.record(cid)["elements"] = {"pair": ["air", "fire"], "spells": {}}
	hero.test_grant = true
	hero.test_backup = {"kestrel": {"level": 4, "xp": 1, "spent": {}}}
	hero.save()
	var bag := GearBag.new()
	for fam in GearBag.FAMILY_ORDER:
		for slot in GearBag.SLOTS:
			var uid := bag.add_item(fam, slot, 5)
			bag.items[bag.find(uid)]["test"] = true
			bag.equip(uid)
	bag.test_grant = true
	bag.loot_day = 4242
	bag.loot_clears_today = 3
	bag.attune["sheaf"] = "Fire"
	bag.save()
	var vault := StillVault.new()
	for id in StillVault.IDS:
		vault.fragments[id] = 99
		vault.test_grant[id] = 99
	vault.socket = "steadfast"
	vault.mode = "overwound"
	vault.save()
	var wallet := KoliseoWallet.new()
	wallet.coins = 12
	wallet.trophies = 40
	wallet.tonics = 2
	wallet.day = 7
	wallet.wins_today = 1
	wallet.total_wins = 9
	wallet.owned = {"pet.mote": 1, "cos.frame.iron": 1, "food.hearth": 3}
	wallet.save()
	print("SEEDED hero_level=%d bag=%d still_socket=%s wallet=%s" % [
		hero.level_of("kestrel"), bag.items.size(), vault.socket, JSON.stringify(wallet.to_dict()),
	])


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 40:
		push_error("progress-reset shot timed out")
		return true
	if _phase == 0 and _frames >= 2:
		var applied := ProgressEpoch.ensure()
		var hero := HeroProgress.load_saved()
		var bag := GearBag.load_saved()
		var vault := StillVault.load_saved()
		var wallet := KoliseoWallet.load_saved()
		print("EPOCH applied=%s marker=%d" % [applied, ProgressEpoch.saved_epoch()])
		for cid in HeroProgress.GROWTH:
			print("HERO %s level=%d xp=%d spent=%s elements=%s" % [
				cid, hero.level_of(cid), hero.xp_of(cid), hero.record(cid)["spent"], hero.elements_of(cid),
			])
		print("BAG items=%d equipped=%s attune=%s loot_day=%d clears=%d grant=%s" % [
			bag.items.size(), bag.equipped, bag.attune, bag.loot_day, bag.loot_clears_today, bag.test_grant,
		])
		print("STILLS fragments=%s socket=%s mode=%s grant=%s" % [vault.fragments, vault.socket, vault.mode, vault.test_grant])
		print("WALLET %s" % JSON.stringify(wallet.to_dict()))
		_screen = (load("res://scenes/character_screen.gd") as Script).new()
		_screen.name = "CharacterScreen"
		root.add_child(_screen)
		_phase = 1
		_frames = 0
		return false
	if _phase == 1 and _frames >= 4:
		var line := str(_screen.find_child("LevelLine", true, false).text)
		var points := str(_screen.find_child("FreePoints", true, false).text)
		var classes: PackedStringArray = PackedStringArray()
		for cid in HeroProgress.GROWTH:
			var button := _screen.find_child("Class_" + str(cid), true, false)
			classes.append(str(button.text) if button != null else str(cid) + " MISSING")
		print("LEVEL_LINE %s" % line)
		print("FREE_POINTS %s" % points)
		print("CLASS_BUTTONS %s" % " | ".join(classes))
		var image := root.get_texture().get_image()
		if image.get_width() != 2400 or image.get_height() != 1080:
			image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
			print("resized hero to 2400x1080 from %dx%d" % [image.get_width(), image.get_height()])
		var err := image.save_png(_dir.path_join("fresh_hero.png"))
		print("SHOT hero %dx%d err=%s" % [image.get_width(), image.get_height(), err])
		if not line.contains("Level 1 /"):
			push_error("hero screen is not level 1: %s" % line)
		_screen.queue_free()
		_screen = (load("res://scenes/gear_screen.gd") as Script).new()
		_screen.name = "GearScreen"
		root.add_child(_screen)
		_phase = 2
		_frames = 0
		return false
	if _phase == 2 and _frames >= 4:
		var empty := ""
		for node in _screen.find_children("*", "Label", true, false):
			var text := str(node.text)
			if text.begins_with("Empty."):
				empty = text
		var header := str(_screen.get("_header").text)
		print("GEAR_HEADER %s" % header)
		print("GEAR_EMPTY %s" % empty)
		print("GEAR_ITEMS %d" % (_screen.bag() as GearBag).items.size())
		var image := root.get_texture().get_image()
		var w := image.get_width()
		var h := image.get_height()
		if w != 2400 or h != 1080:
			image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
			print("resized gear to 2400x1080 from %dx%d" % [w, h])
		var err := image.save_png(_dir.path_join("fresh_gear.png"))
		print("SHOT gear %dx%d err=%s" % [image.get_width(), image.get_height(), err])
		if empty == "" or (_screen.bag() as GearBag).items.size() != 0:
			push_error("gear screen is not empty")
		return true
	return false
