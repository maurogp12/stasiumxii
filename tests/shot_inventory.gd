extends SceneTree

## Dev screenshot helper (not a test suite): the hub Inventory with a small
## bag, a worn piece, tonics and fragments, plus the Room Tonic shop row.
## xvfb-run godot ... -s res://tests/shot_inventory.gd -- <out_dir>
## Uses throwaway save paths; the real saves are never touched.

var _out := "user://"
var _frames := 0
var _hub: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	GearBag.save_path = "user://shot_inv_bag.json"
	HeroProgress.save_path = "user://shot_inv_hero.json"
	KoliseoWallet.save_path = "user://shot_inv_wallet.json"
	StillVault.save_path = "user://shot_inv_still.json"
	var bag := GearBag.new()
	var head := bag.add_item("sheaf", "head", 1)
	var wpn := bag.add_item("duskbrand", "weapon", 0)
	bag.add_item("stillcut", "boots", 0)
	bag.add_item("stillcut", "boots", 0)
	bag.add_item("ironveil", "chest", 2)
	bag.add_item("brightedge", "legs", 0)
	bag.add_item("undertow", "head", 0)
	bag.equip(head)
	bag.equip(wpn)
	bag.save()
	var wallet := KoliseoWallet.new()
	wallet.coins = 7
	wallet.trophies = 42
	wallet.tonics = 2
	wallet.save()
	var vault := StillVault.new()
	vault.fragments = {"stride": 5, "cut": 12, "ember": 2}
	vault.save()
	var hero := HeroProgress.new()
	hero.add_xp("kestrel", 500)
	hero.save()
	root.size = Vector2i(960, 720)
	_hub = (load("res://scenes/mobile_hub.tscn") as PackedScene).instantiate()
	_hub.set("_auto_launch", false)
	root.add_child(_hub)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		_hub.open_inventory()
	elif _frames == 8:
		var inv := _hub.find_child("InventoryScreen", true, false)
		inv.select({"kind": "item", "uid": 3})
	elif _frames == 14:
		root.get_texture().get_image().save_png(_out.path_join("inventory.png"))
		var inv := _hub.find_child("InventoryScreen", true, false)
		inv.show_tab("consumables")
		inv.select({"kind": "sku", "sku": KoliseoWallet.TONIC_SKU})
	elif _frames == 20:
		root.get_texture().get_image().save_png(_out.path_join("inventory_tonic.png"))
		_hub.find_child("InventoryScreen", true, false).close()
		_hub.open_shop()
	elif _frames == 26:
		root.get_texture().get_image().save_png(_out.path_join("shop_tonic.png"))
	elif _frames == 28:
		return true
	return false
