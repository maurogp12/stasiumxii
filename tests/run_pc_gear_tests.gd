extends SceneTree

## PC gear (backend/pc_gear.gd): the mobile set ladder on PC. The 22 sets
## against the reference PDF, fusing, AP / MP rules and caps, crit, HP %,
## chest odds by star, even set choice, Ultra never drops, class fit, old
## save migration, the fight wiring, and the paper-doll look fields.
## Run: godot --headless --path . -s res://tests/run_pc_gear_tests.gd

const Gear = preload("res://backend/pc_gear.gd")
const Rewards = preload("res://backend/pc_rewards.gd")
const Progress = preload("res://backend/pc_progress.gd")
const Run = preload("res://backend/pc_dungeon_run.gd")

## Read from the reference PDF (Sets_stasium.pdf, origin/mobile 7035f8f).
## set → [name, tier, {slot: [piece, HP +0, HP +5, Mastery +0, +5, Resist +0, +5, Init +0, +5, Crit %]}, {2, 4, 5 texts}]
const PDF := {
	"ashmantle": ["Ashmantle", "Normal", {"weapon": ["Ashmantle Brand", 0, 0, 12, 21, 0, 0, 0, 0, 2], "head": ["Ashmantle Helm", 16, 28, 0, 0, 2, 4, 0, 0, 0], "chest": ["Ashmantle Coat", 24, 43, 2, 4, 2, 4, 0, 0, 0], "legs": ["Ashmantle Guards", 12, 21, 0, 0, 2, 4, 0, 0, 0], "boots": ["Ashmantle Treads", 8, 14, 0, 0, 0, 0, 4, 7, 0]}, {2: "+6% HP", 4: "+4 Mastery", 5: "+2 Init"}],
	"brightedge": ["Brightedge", "Legendary", {"weapon": ["Brightedge", 0, 0, 14, 25, 0, 0, 0, 0, 4], "head": ["Gleam Helm", 16, 28, 4, 7, 0, 0, 0, 0, 2], "chest": ["Gleam Coat", 20, 36, 7, 12, 2, 4, 0, 0, 0], "legs": ["Gleam Guards", 12, 21, 2, 4, 2, 4, 0, 0, 0], "boots": ["Gleam Treads", 8, 14, 2, 4, 0, 0, 10, 18, 1]}, {2: "+4% crit", 4: "+6 Mastery", 5: "+1 AP +1 MP"}],
	"rustward": ["Rustward", "Normal", {"weapon": ["Rustward Bit", 0, 0, 4, 7, 2, 4, 0, 0, 0], "head": ["Rustward Helm", 20, 36, 0, 0, 3, 5, 0, 0, 0], "chest": ["Rustward Plate", 26, 46, 0, 0, 3, 5, 0, 0, 0], "legs": ["Rustward Guards", 16, 28, 0, 0, 2, 4, 0, 0, 0], "boots": ["Rustward Treads", 8, 14, 0, 0, 0, 0, 2, 4, 0]}, {2: "+8% HP", 4: "+4 Resist", 5: "First hit you take each turn deals 4 less"}],
	"ironveil": ["Ironveil", "Rare", {"weapon": ["Veil Bit", 0, 0, 6, 11, 2, 4, 0, 0, 0], "head": ["Veil Casque", 22, 39, 0, 0, 3, 5, 0, 0, 0], "chest": ["Veil Plate", 32, 57, 0, 0, 4, 7, 0, 0, 0], "legs": ["Veil Guards", 16, 28, 0, 0, 3, 5, 0, 0, 0], "boots": ["Veil Treads", 8, 14, 0, 0, 0, 0, 2, 4, 0]}, {2: "+10% HP", 4: "+6 Resist", 5: "First hit you take each turn deals 6 less"}],
	"oathgrave": ["Oathgrave", "Legendary", {"weapon": ["Oathgrave Bit", 0, 0, 6, 11, 3, 5, 0, 0, 0], "head": ["Oathgrave Helm", 24, 43, 0, 0, 4, 7, 0, 0, 0], "chest": ["Oathgrave Plate", 36, 64, 0, 0, 4, 7, 0, 0, 0], "legs": ["Oathgrave Guards", 16, 28, 0, 0, 3, 5, 0, 0, 0], "boots": ["Oathgrave Treads", 8, 14, 0, 0, 0, 0, 2, 4, 0]}, {2: "+12% HP", 4: "+6 Resist", 5: "+1 AP +1 MP. Ward shield 25 (cap 40). Start with 1 Aegis. No Aegis refund when Ward breaks."}],
	"gatewarden": ["Gatewarden", "Ultra", {"weapon": ["Gatebreaker Mace", 0, 0, 6, 11, 1, 2, 0, 0, 0], "head": ["Grille Helm", 16, 28, 0, 0, 2, 4, 0, 0, 0], "chest": ["Gate Plate", 32, 57, 0, 0, 3, 5, 0, 0, 0], "legs": ["Gate Greaves", 14, 25, 0, 0, 4, 7, 0, 0, 0], "boots": ["Gate Sabatons", 9, 16, 0, 0, 1, 2, 2, 4, 0]}, {2: "Pushes on you deal no extra damage (you are still moved)", 4: "The first back hit on you each turn gets no back bonus", 5: "+1 AP +1 MP. Once per turn, a crit on you or an ally within 3 tiles deals normal damage"}],
	"undertow": ["Undertow", "Normal", {"weapon": ["Undertow Edge", 0, 0, 16, 28, 0, 0, 0, 0, 4], "head": ["Undertow Helm", 12, 21, 0, 0, 0, 0, 0, 0, 4], "chest": ["Undertow Plate", 16, 28, 4, 7, 0, 0, 0, 0, 0], "legs": ["Undertow Guards", 8, 14, 2, 4, 1, 2, 0, 0, 0], "boots": ["Undertow Treads", 4, 7, 0, 0, 0, 0, 12, 21, 2]}, {2: "+4 Init", 4: "+4% crit", 5: "Your first hit each turn deals +4"}],
	"gallowsight": ["Gallowsight", "Rare", {"weapon": ["Gallowsight Edge", 0, 0, 18, 32, 0, 0, 0, 0, 6], "head": ["Gallowsight Helm", 12, 21, 2, 4, 0, 0, 0, 0, 4], "chest": ["Gallowsight Plate", 16, 28, 4, 7, 1, 2, 0, 0, 0], "legs": ["Gallowsight Guards", 10, 18, 2, 4, 1, 2, 0, 0, 0], "boots": ["Gallowsight Treads", 6, 11, 0, 0, 0, 0, 12, 21, 2]}, {2: "+4 Init", 4: "+6% crit", 5: "Your first hit each turn deals +6"}],
	"ravenmourn": ["Ravenmourn", "Legendary", {"weapon": ["Ravenmourn Edge", 0, 0, 19, 34, 0, 0, 0, 0, 6], "head": ["Ravenmourn Helm", 12, 21, 4, 7, 0, 0, 0, 0, 4], "chest": ["Ravenmourn Plate", 16, 28, 6, 11, 1, 2, 0, 0, 0], "legs": ["Ravenmourn Guards", 10, 18, 2, 4, 1, 2, 2, 4, 0], "boots": ["Ravenmourn Treads", 6, 11, 0, 0, 0, 0, 14, 25, 2]}, {2: "+6 Init", 4: "+6% crit", 5: "+1 AP +1 MP"}],
	"sandhawk": ["Sandhawk", "Ultra", {"weapon": ["Sandhawk Recurve", 0, 0, 6, 11, 0, 0, 0, 0, 3], "head": ["Hawk Hood", 16, 28, 0, 0, 0, 0, 0, 0, 2], "chest": ["Sandhawk Jerkin", 22, 39, 3, 5, 2, 4, 0, 0, 0], "legs": ["Sash Guards", 12, 21, 2, 4, 3, 5, 0, 0, 0], "boots": ["Sand Striders", 6, 11, 1, 2, 1, 2, 6, 11, 0]}, {2: "Once per match, when an enemy steps next to you, your next Vault is free (0 AP, and it still starts the cooldown)", 4: "Fade on an enemy with 2+ of your Marks lasts 1 turn", 5: "+1 AP +1 MP. Once per turn, Detonate removes 1 class stack"}],
	"cragmaw": ["Cragmaw", "Normal", {"weapon": ["Cragmaw Bit", 0, 0, 10, 18, 0, 0, 0, 0, 3], "head": ["Cragmaw Helm", 18, 32, 0, 0, 2, 4, 0, 0, 0], "chest": ["Cragmaw Plate", 24, 43, 2, 4, 2, 4, 0, 0, 0], "legs": ["Cragmaw Guards", 12, 21, 0, 0, 2, 4, 0, 0, 0], "boots": ["Cragmaw Treads", 8, 14, 0, 0, 0, 0, 2, 4, 1]}, {2: "+8% HP", 4: "+4 Resist", 5: "Hits at range 1 deal +4"}],
	"maulgrave": ["Maulgrave", "Rare", {"weapon": ["Maulgrave Bit", 0, 0, 10, 18, 0, 0, 0, 0, 5], "head": ["Maulgrave Helm", 20, 36, 0, 0, 3, 5, 0, 0, 0], "chest": ["Maulgrave Plate", 28, 50, 2, 4, 3, 5, 0, 0, 0], "legs": ["Maulgrave Guards", 14, 25, 0, 0, 2, 4, 0, 0, 0], "boots": ["Maulgrave Treads", 8, 14, 0, 0, 0, 0, 2, 4, 1]}, {2: "+10% HP", 4: "+4 Resist", 5: "Hits at range 1 deal +6"}],
	"tyrantjaw": ["Tyrantjaw", "Legendary", {"weapon": ["Tyrantjaw Bit", 0, 0, 12, 21, 0, 0, 0, 0, 5], "head": ["Tyrantjaw Helm", 22, 39, 0, 0, 3, 5, 0, 0, 0], "chest": ["Tyrantjaw Plate", 30, 53, 2, 4, 3, 5, 0, 0, 0], "legs": ["Tyrantjaw Guards", 14, 25, 0, 0, 3, 5, 0, 0, 0], "boots": ["Tyrantjaw Treads", 8, 14, 0, 0, 0, 0, 2, 4, 2]}, {2: "+12% HP", 4: "+4% crit", 5: "+1 AP +1 MP"}],
	"pitmaw": ["Pitmaw", "Ultra", {"weapon": ["Pitmaw Axes", 0, 0, 4, 7, 0, 0, 0, 0, 3], "head": ["Jaw-Guard Helm", 22, 39, 0, 0, 2, 4, 0, 0, 0], "chest": ["Pit Hide", 30, 53, 2, 4, 3, 5, 0, 0, 0], "legs": ["Chain Wraps", 12, 21, 0, 0, 4, 7, 0, 0, 0], "boots": ["Pit Treads", 6, 11, 0, 0, 1, 2, 0, 0, 0]}, {2: "Once per fight below 35% HP: Berserk (+15% melee, +1 MP) for your next 2 turns, and you take +5% damage", 4: "Your first hit each turn gives the target −1 MP next turn (a Slow)", 5: "+1 AP +1 MP. A Shoulder hit removes 1 class stack, at most once every 2 turns"}],
	"nightglass": ["Nightglass", "Normal", {"weapon": ["Nightglass Edge", 0, 0, 15, 27, 0, 0, 0, 0, 3], "head": ["Nightglass Helm", 10, 18, 3, 5, 0, 0, 0, 0, 3], "chest": ["Nightglass Plate", 14, 25, 4, 7, 0, 0, 0, 0, 0], "legs": ["Nightglass Guards", 8, 14, 2, 4, 0, 0, 4, 7, 0], "boots": ["Nightglass Treads", 4, 7, 1, 2, 0, 0, 14, 25, 2]}, {2: "+4 Init", 4: "+4% crit", 5: "Your first back hit each turn deals +4"}],
	"stillcut": ["Stillcut", "Rare", {"weapon": ["Stillcut Edge", 0, 0, 18, 32, 0, 0, 0, 0, 4], "head": ["Stillcut Helm", 12, 21, 2, 4, 0, 0, 0, 0, 2], "chest": ["Stillcut Plate", 16, 28, 4, 7, 1, 2, 0, 0, 0], "legs": ["Stillcut Guards", 8, 14, 2, 4, 0, 0, 6, 11, 0], "boots": ["Stillcut Treads", 4, 7, 1, 2, 0, 0, 20, 36, 2]}, {2: "+6 Init", 4: "+4% crit", 5: "Your first back hit each turn deals +6"}],
	"gravewhisper": ["Gravewhisper", "Legendary", {"weapon": ["Gravewhisper Edge", 0, 0, 18, 32, 0, 0, 0, 0, 5], "head": ["Gravewhisper Helm", 10, 18, 4, 7, 0, 0, 0, 0, 4], "chest": ["Gravewhisper Plate", 14, 25, 6, 11, 1, 2, 0, 0, 0], "legs": ["Gravewhisper Guards", 8, 14, 2, 4, 0, 0, 8, 14, 0], "boots": ["Gravewhisper Treads", 4, 7, 1, 2, 0, 0, 20, 36, 3]}, {2: "+6 Init", 4: "Back hits deal +6% damage", 5: "+1 AP +1 MP"}],
	"hushring": ["Hushring", "Ultra", {"weapon": ["Hush Knives", 0, 0, 14, 25, 0, 0, 0, 0, 4], "head": ["Half-Mask Hood", 16, 28, 3, 5, 0, 0, 0, 0, 2], "chest": ["Hushsilk Vest", 24, 43, 4, 7, 0, 0, 4, 7, 0], "legs": ["Silk Wraps", 14, 25, 1, 2, 0, 0, 2, 4, 0], "boots": ["Hush Steps", 8, 14, 1, 2, 0, 0, 8, 14, 0]}, {2: "Enemies you hit heal 25% less until their next turn", 4: "Your first hit each turn deals +50% damage to shields", 5: "+1 AP +1 MP. Your Fade lasts 3 of your turns"}],
	"vesperwell": ["Vesperwell", "Normal", {"weapon": ["Vesperwell Staff", 0, 0, 11, 20, 0, 0, 0, 0, 0], "head": ["Vesperwell Helm", 16, 28, 0, 0, 2, 4, 0, 0, 0], "chest": ["Vesperwell Coat", 24, 43, 2, 4, 2, 4, 0, 0, 0], "legs": ["Vesperwell Guards", 14, 25, 0, 0, 2, 4, 0, 0, 0], "boots": ["Vesperwell Treads", 8, 14, 0, 0, 1, 2, 2, 4, 1]}, {2: "+8% HP", 4: "Heals +4", 5: "+4 Resist"}],
	"sheaf": ["Sheaf", "Rare", {"weapon": ["Sheaf Hook", 0, 0, 12, 21, 0, 0, 0, 0, 2], "head": ["Sheaf Helm", 18, 32, 0, 0, 2, 4, 0, 0, 0], "chest": ["Sheaf Coat", 28, 50, 2, 4, 3, 5, 0, 0, 0], "legs": ["Sheaf Guards", 14, 25, 0, 0, 3, 5, 0, 0, 0], "boots": ["Sheaf Treads", 8, 14, 0, 0, 1, 2, 4, 7, 0]}, {2: "+10% HP", 4: "Heals +6", 5: "+4 Resist"}],
	"hallowmourn": ["Hallowmourn", "Legendary", {"weapon": ["Hallowmourn Staff", 0, 0, 14, 25, 0, 0, 0, 0, 3], "head": ["Hallowmourn Helm", 20, 36, 0, 0, 3, 5, 0, 0, 0], "chest": ["Hallowmourn Coat", 26, 46, 2, 4, 3, 5, 0, 0, 0], "legs": ["Hallowmourn Guards", 16, 28, 0, 0, 3, 5, 0, 0, 0], "boots": ["Hallowmourn Treads", 8, 14, 0, 0, 1, 2, 4, 7, 1]}, {2: "+12% HP", 4: "Heals +6", 5: "+1 AP +1 MP"}],
	"mercywell": ["Mercywell", "Ultra", {"weapon": ["Mercywell Censer", 0, 0, 5, 9, 0, 0, 0, 0, 0], "head": ["Shell Circlet", 20, 36, 2, 4, 2, 4, 0, 0, 0], "chest": ["Mercy Vestments", 28, 50, 2, 4, 3, 5, 0, 0, 0], "legs": ["Linen Robe-Skirt", 12, 21, 0, 0, 4, 7, 0, 0, 0], "boots": ["Linen Treads", 8, 14, 0, 0, 1, 2, 6, 11, 0]}, {2: "Cleanse also removes Stun", 4: "Once per fight, a lethal hit leaves you at 1 HP", 5: "+1 AP +1 MP. Rekindle costs 5 AP and 4 Pulse, range 3, revives at 40% HP plus a 10 shield"}],
}

var _passed := 0
var _failed := 0
var _had_save := false
var _backup := ""


func _initialize() -> void:
	_backup_save()
	_clear_save()
	_run.call_deferred()


func _run() -> void:
	_test_pdf_sets()
	_test_fuse_ladder()
	_test_fuse_bag()
	_test_ap_mp()
	_test_crit()
	_test_hp_pct()
	_test_chest_odds()
	_test_uniform_sets()
	_test_world_drop()
	_test_ultra_never_drops()
	_test_class_fit()
	_test_migration()
	_test_fight_wiring()
	_test_looks()
	_restore_save()
	print("pc gear tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Every set of the PDF, every slot: name, tier, the +0 and +5 numbers, crit,
## and the 2 / 4 / 5-piece lines. The PDF lists 22 sets (2 shared + 5 x 4).
func _test_pdf_sets() -> void:
	eq(PDF.size(), 22, "the PDF lists 22 sets")
	eq(Gear.FAMILIES.size(), 22, "pc_gear has the same 22 sets")
	eq(Gear.FAMILY_ORDER.size() + Gear.ULTRA_ORDER.size(), 22, "17 ladder sets and 5 Ultra sets")
	for fam in PDF.keys():
		var row: Array = PDF[fam]
		eq(Gear.FAMILIES.has(fam), true, "%s exists" % fam)
		if not Gear.FAMILIES.has(fam):
			continue
		eq(str(Gear.FAMILIES[fam]["name"]), str(row[0]), "%s name" % fam)
		eq(Gear.rarity_of(fam), str(row[1]), "%s tier" % fam)
		var parts: Dictionary = row[2]
		for slot in Gear.SLOTS:
			var want: Array = parts[slot]
			var item_id := Gear.item_id_for(fam, slot)
			eq(Gear.part_name(item_id), str(want[0]), "%s piece name" % item_id)
			var at0 := Gear.part_stats(item_id, 0)
			var at5 := Gear.part_stats(item_id, 5)
			var got := [at0["hp"], at5["hp"], at0["mastery"], at5["mastery"], at0["resist"], at5["resist"], at0["init"], at5["init"], at0["crit"]]
			eq(got, want.slice(1), "%s +0 / +5 numbers match the PDF" % item_id)
		var bonus: Dictionary = row[3]
		for tier in [2, 4, 5]:
			var text := str(Gear.FAMILIES[fam]["bonus"][tier])
			eq(text.begins_with(str(bonus[tier])), true, "%s %dpc line matches the PDF" % [fam, tier])
	# Owners as the PDF's class table.
	var table := {
		"bastion": ["rustward", "ironveil", "oathgrave", "gatewarden"],
		"kestrel": ["undertow", "gallowsight", "ravenmourn", "sandhawk"],
		"ironjaw": ["cragmaw", "maulgrave", "tyrantjaw", "pitmaw"],
		"gloam": ["nightglass", "stillcut", "gravewhisper", "hushring"],
		"mender": ["vesperwell", "sheaf", "hallowmourn", "mercywell"],
	}
	for cls in table.keys():
		var tiers := ["Normal", "Rare", "Legendary", "Ultra"]
		for i in 4:
			var fam := str(table[cls][i])
			eq(Gear.owner_of(fam), cls, "%s is %s's" % [fam, cls])
			eq(Gear.rarity_of(fam), tiers[i], "%s is %s" % [fam, tiers[i]])
	eq(Gear.owner_of("ashmantle"), "", "Ashmantle is shared")
	eq(Gear.owner_of("brightedge"), "", "Brightedge is shared")
	eq(Gear.rarity_of("ashmantle"), "Normal", "Ashmantle is Normal")
	eq(Gear.rarity_of("brightedge"), "Legendary", "Brightedge is Legendary")
	eq(Array(Gear.SLOTS), ["weapon", "head", "chest", "legs", "boots"], "slots: the 4th slot is legs")
	for fam in Gear.ULTRA_ORDER:
		eq(str(Gear.FAMILIES[fam]["source"]), "koliseo_shop", "%s source is koliseo_shop" % fam)
	eq(Gear.ULTRA_PART_COST, 30, "an Ultra piece costs 30 coins")
	# rewards.json item defs come from pc_gear.
	var book = Rewards.load_default()["rewards"]
	eq(book.sets().size(), 22, "the catalog lists the 22 sets")
	eq(str(book.item("cragmaw.head").get("name", "")), "Cragmaw Helm", "catalog item for a part")
	eq(str(book.item("cragmaw.head").get("set_id", "")), "cragmaw", "catalog item knows its set")


func _test_fuse_ladder() -> void:
	eq(Array(Gear.FUSE_MULT), [1.00, 1.12, 1.26, 1.41, 1.58, 1.78], "fuse multipliers")
	for plus in 6:
		var st := Gear.part_stats("oathgrave.chest", plus)
		eq(int(st["hp"]), roundi(36.0 * Gear.FUSE_MULT[plus]), "Oathgrave Plate HP at +%d" % plus)
		eq(int(st["resist"]), roundi(4.0 * Gear.FUSE_MULT[plus]), "Oathgrave Plate Resist at +%d" % plus)
		eq(int(Gear.part_stats("undertow.weapon", plus)["crit"]), 4, "crit does not grow at +%d" % plus)
		eq(int(Gear.part_stats("undertow.boots", plus)["init"]), roundi(12.0 * Gear.FUSE_MULT[plus]), "Init grows at +%d" % plus)
	eq(int(Gear.part_stats("x.y", 9)["hp"]), 0, "unknown part is zero")
	eq(int(Gear.part_stats("ashmantle.head", 9)["hp"]), 28, "plus clamps to +5")
	eq(Gear.special_line("gatewarden.weapon").find("Ward 25") >= 0, true, "Ultra extra shown, not fuse-scaled")
	var a := {"item_id": "cragmaw.head", "plus": 1}
	eq(bool(Gear.can_fuse(a, {"item_id": "cragmaw.head", "plus": 1})["ok"]), true, "same piece, same plus fuses")
	eq(str(Gear.can_fuse(a, {"item_id": "cragmaw.head", "plus": 0})["reason"]), "different_plus", "different plus does not fuse")
	eq(str(Gear.can_fuse(a, {"item_id": "cragmaw.legs", "plus": 1})["reason"]), "different_item", "different piece does not fuse")
	eq(str(Gear.can_fuse({"item_id": "cragmaw.head", "plus": 5}, {"item_id": "cragmaw.head", "plus": 5})["reason"]), "plus_cap", "+5 is the cap")


func _test_fuse_bag() -> void:
	_clear_save()
	var hero = Progress.new()
	hero.set_hero_class("ironjaw")
	hero.grant({"items": [
		{"item_id": "cragmaw.head", "rarity": "normal", "count": 1, "plus": 0},
		{"item_id": "cragmaw.head", "rarity": "normal", "count": 1, "plus": 0},
		{"item_id": "cragmaw.head", "rarity": "normal", "count": 1, "plus": 1},
	]})
	var uids: Array = []
	for row in hero.bag:
		uids.append(int(row["uid"]))
	eq(hero.equip_uid(uids[0])["ok"], true, "wear one copy")
	var fused: Dictionary = hero.fuse_uid(uids[1])
	eq(bool(fused["ok"]), true, "fuse a bag copy into the worn copy")
	eq(int(fused["plus"]), 1, "two +0 make a +1")
	eq(int(hero.equipped["head"].get("plus", 0)), 1, "the worn piece is now +1 and still worn")
	eq(hero.bag.size(), 1, "one copy is used up")
	var again: Dictionary = hero.fuse_uid(int(hero.equipped["head"]["uid"]))
	eq(bool(again["ok"]), true, "+1 and +1 fuse")
	eq(int(hero.equipped["head"]["plus"]), 2, "now +2")
	eq(hero.bag.size(), 0, "bag is empty")
	eq(str(hero.fuse_uid(int(hero.equipped["head"]["uid"]))["reason"]), "no_partner", "no partner left")
	var reread = Progress.new()
	eq(int(reread.equipped.get("head", {}).get("plus", 0)), 2, "plus survives a save and load")
	_clear_save()


func _test_ap_mp() -> void:
	eq([Gear.BASE_AP, Gear.BASE_MP, Gear.AP_CAP, Gear.MP_CAP], [6, 3, 8, 5], "base 6/3, cap 8/5")
	var bare := Gear.ap_mp_of_worn([])
	eq([bare["ap"], bare["mp"]], [6, 3], "no gear is 6/3")
	var oath := _full("oathgrave", 0)
	var five := Gear.ap_mp_of_worn(oath)
	eq([five["ap"], five["mp"]], [7, 4], "Legendary 5pc gives +1 AP +1 MP")
	var four := Gear.ap_mp_of_worn(oath.slice(0, 4))
	eq([four["ap"], four["mp"]], [6, 3], "Legendary 4pc gives no AP / MP")
	var ultra := Gear.ap_mp_of_worn(_full("pitmaw", 0), false)
	eq([ultra["ap"], ultra["mp"]], [7, 4], "Ultra 5pc +1/+1 works outside the Koliseo")
	var normal := Gear.ap_mp_of_worn(_full("cragmaw", 5))
	eq([normal["ap"], normal["mp"]], [6, 3], "Normal 5pc +5 gives no AP / MP")
	var rare_wb := [{"item_id": "maulgrave.weapon", "plus": 5}, {"item_id": "maulgrave.boots", "plus": 5}]
	var gated := Gear.ap_mp_of_worn(rare_wb)
	eq([gated["ap"], gated["mp"]], [7, 4], "Rare weapon +5 gives +1 AP, Rare boots +5 give +1 MP")
	var rare4 := Gear.ap_mp_of_worn([{"item_id": "maulgrave.weapon", "plus": 4}, {"item_id": "maulgrave.boots", "plus": 4}])
	eq([rare4["ap"], rare4["mp"]], [6, 3], "Rare at +4 does not open the gate")
	var leg5 := Gear.ap_mp_of_worn([{"item_id": "tyrantjaw.weapon", "plus": 5}])
	eq(leg5["ap"], 6, "a Legendary +5 weapon does not open the Rare gate")
	var gate_twice := Gear.gate_of_worn([{"item_id": "maulgrave.weapon", "plus": 5}, {"item_id": "ironveil.weapon", "plus": 5}])
	eq(gate_twice["ap"], 1, "the Rare gate does not stack")
	var capped := Gear.ap_mp_of_worn(oath, false, 3)
	eq(capped["ap"], 8, "AP clamps to 8")
	eq(capped["raw_ap"], 10, "raw AP is kept for the sheet")
	eq(capped["ap_greyed"], 2, "AP over the cap is greyed")
	# PC level rule: +1 AP at level 30 (level_rewards.json), inside the same cap.
	_clear_save()
	var hero = Progress.new()
	hero.set_hero_class("bastion")
	eq(int(hero.sheet_view()["ap"]), 6, "level 1 sheet AP 6")
	hero.level = 30
	eq(int(hero.sheet_view()["ap"]), 7, "level 30 milestone keeps +1 AP")
	for slot in Gear.SLOTS:
		hero.grant({"items": [{"item_id": Gear.item_id_for("oathgrave", slot), "rarity": "legendary", "count": 1}]})
	for row in hero.bag.duplicate():
		hero.equip_uid(int(row["uid"]))
	var view: Dictionary = hero.sheet_view()
	eq([int(view["ap"]), int(view["mp"])], [8, 4], "level 30 + Oathgrave 5pc is 8 AP 4 MP")
	eq(int(hero.fight_gear()["extra_ap"]), 1, "the fight gets the milestone AP")
	eq(int(hero.sheet_view(true)["ap"]), 7, "a Koliseo sheet drops gear and keeps the level AP")
	_clear_save()


func _test_crit() -> void:
	eq(Gear.CRIT_CAP, 20, "crit cap 20%")
	eq(Gear.CRIT_MULT, 1.3, "a crit deals x1.3")
	var big := Gear.combat_stats(_full("undertow", 0), "kestrel")
	eq(int(big["crit"]), 14, "Undertow 5pc crit: parts 4 + 4 + 2, set 4")
	var gallows := Gear.combat_stats(_full("gallowsight", 5), "kestrel")
	eq(int(gallows["crit"]), 18, "Gallowsight 5pc +5 crit 18: crit does not fuse")
	var ultra_out := Gear.combat_stats(_full("hushring", 0), "gloam", false)
	eq(int(ultra_out["crit"]), 0, "Ultra crit counts only in the Koliseo")
	eq(int(Gear.combat_stats(_full("hushring", 0), "gloam", true)["crit"]), 6, "Ultra crit in the Koliseo")
	var sim: Node = root.get_node("CombatSim")
	var actor := {"seat": 0, "class_id": "gloam", "pc_gear": [], "crit": 100, "crit_landed": false}
	sim._active_seat = 0
	sim._crit_rng.seed = 5
	var hits := 0
	var trials := 4000
	for i in trials:
		actor["crit_landed"] = false
		if sim._gear_crit_mult(actor, false) > 1.0:
			hits += 1
	var rate := float(hits) / float(trials)
	eq(rate > 0.17 and rate < 0.23, true, "crit chance 100 is capped to about 20%% (got %.3f)" % rate)
	actor["crit_landed"] = false
	var first := 1.0
	var tries := 0
	while first <= 1.0 and tries < 500:
		first = sim._gear_crit_mult(actor, false)
		tries += 1
	eq(first, 1.3, "a crit lands at x1.3")
	var later := 0
	for i in 200:
		if sim._gear_crit_mult(actor, false) > 1.0:
			later += 1
	eq(later, 0, "at most one crit per fighter per turn")
	sim._refresh_gear_turn(actor)
	eq(bool(actor["crit_landed"]), false, "the next turn may crit again")
	var not_mine := {"seat": 3, "class_id": "gloam", "pc_gear": [], "crit": 100}
	var off := 0
	for i in 200:
		if sim._gear_crit_mult(not_mine, false) > 1.0:
			off += 1
	eq(off, 0, "no crit off the fighter's own turn")
	var healer := {"seat": 0, "class_id": "bastion", "pc_gear": [], "crit": 100}
	var heal_crits := 0
	for i in 400:
		healer["crit_landed"] = false
		if sim._gear_crit_mult(healer, true) > 1.0:
			heal_crits += 1
	eq(heal_crits, 0, "only the Mender's heals crit")
	var mender := {"seat": 0, "class_id": "mender", "pc_gear": [], "crit": 100}
	var mender_crits := 0
	for i in 400:
		mender["crit_landed"] = false
		if sim._gear_crit_mult(mender, true) > 1.0:
			mender_crits += 1
	eq(mender_crits > 0, true, "a Mender heal can crit")
	var bare := {"seat": 0, "class_id": "gloam", "crit": 100}
	eq(sim._gear_crit_mult(bare, false), 1.0, "a unit without PC gear never crits")


func _test_hp_pct() -> void:
	var st := Gear.combat_stats(_full("oathgrave", 0), "bastion")
	eq(int(st["hp_flat"]), 84, "Oathgrave parts HP 84")
	eq(int(st["hp_pct"]), 12, "Oathgrave 2pc +12% HP")
	eq(Gear.max_hp(80, 0, st), roundi(164.0 * 1.12), "HP% multiplies base + level + gear HP")
	eq(Gear.max_hp(80, 10, st), roundi(174.0 * 1.12), "level HP is inside the multiplier")
	eq(int(Gear.combat_stats(_full("oathgrave", 0), "kestrel")["hp_flat"]), 0, "a class set does nothing on another class")


func _test_chest_odds() -> void:
	var book = Rewards.load_default()["rewards"]
	var rows := {
		"1": [false, 1, {"Normal": 1.0, "Rare": 0.0, "Legendary": 0.0}],
		"2": [false, 2, {"Normal": 1.0, "Rare": 0.0, "Legendary": 0.0}],
		"3": [false, 3, {"Normal": 0.7, "Rare": 0.3, "Legendary": 0.0}],
		"4": [false, 4, {"Normal": 0.7, "Rare": 0.3, "Legendary": 0.0}],
		"5": [false, 5, {"Normal": 0.6, "Rare": 0.3, "Legendary": 0.1}],
		"boss": [true, 1, {"Normal": 0.5, "Rare": 0.3, "Legendary": 0.2}],
	}
	var n := 6000
	for key in rows.keys():
		var row: Array = rows[key]
		var rng := _rng(400 + str(key).hash() % 1000)
		var counts := {"normal": 0, "rare": 0, "legendary": 0}
		var slots := {}
		for i in n:
			var piece: Dictionary = book.chest_piece(int(row[1]), bool(row[0]), rng)
			counts[str(piece["rarity"])] = int(counts.get(str(piece["rarity"]), 0)) + 1
			slots[Gear.slot_of(str(piece["item_id"]))] = int(slots.get(Gear.slot_of(str(piece["item_id"])), 0)) + 1
			if int(piece.get("plus", -1)) != 0:
				eq(int(piece.get("plus", -1)), 0, "a chest piece is +0")
		var want: Dictionary = row[2]
		for tier in ["Normal", "Rare", "Legendary"]:
			var got := float(counts[tier.to_lower()]) / float(n)
			eq(absf(got - float(want[tier])) < 0.025, true, "chest %s %s %.3f near %.2f" % [key, tier, got, float(want[tier])])
		var weapon := float(slots.get("weapon", 0)) / float(n)
		eq(absf(weapon - 0.18) < 0.02, true, "chest %s weapon slot %.3f near 0.18" % [key, weapon])
		var head := float(slots.get("head", 0)) / float(n)
		eq(absf(head - 0.205) < 0.02, true, "chest %s head slot %.3f near 0.205" % [key, head])
	# A dungeon win: room A at the star row, room B at the boss row.
	var won: Dictionary = book.roll("dungeon", {"dungeon_id": "old_granary_cellar", "level": 2, "stars": 1}, _rng(9))
	var chests: Array = []
	for item in won["items"]:
		if Gear.is_valid_item_id(str(item["item_id"])):
			chests.append(str(item.get("chest", "")))
	eq(chests, ["b"], "a dungeon win pays one chest, at the boss (Mauro: \"Un cofre\")")
	# The boss chest rolls the chosen star's row, not mobile's boss row.
	for star in [1, 2]:
		var srng := _rng(70 + star)
		for i in 400:
			for item in book.roll("dungeon", {"dungeon_id": "old_granary_cellar", "level": 2, "stars": star}, srng)["items"]:
				if Gear.is_valid_item_id(str(item["item_id"])) and str(item["rarity"]) != "normal":
					eq(str(item["rarity"]), "normal", "★%d chest is always Normal" % star)
	var leg := 0
	var lrng := _rng(91)
	var n5 := 3000
	for i in n5:
		for item in book.roll("dungeon", {"dungeon_id": "old_granary_cellar", "level": 2, "stars": 5}, lrng)["items"]:
			if str(item.get("rarity", "")) == "legendary":
				leg += 1
	eq(absf(float(leg) / n5 - 0.10) < 0.02, true, "★5 chest Legendary %.3f near 0.10" % (float(leg) / n5))
	# No daily cap: the 30th win of a run of wins still pays.
	var many := 0
	var mrng := _rng(5)
	for i in 30:
		for item in book.roll("dungeon", {"dungeon_id": "old_granary_cellar", "level": 2, "stars": 1}, mrng)["items"]:
			if Gear.is_valid_item_id(str(item["item_id"])):
				many += 1
	eq(many, 30, "no daily cap: 30 wins pay 30 chests")


func _test_uniform_sets() -> void:
	var rng := _rng(77)
	for tier in ["Normal", "Rare", "Legendary"]:
		var pool := Gear.families_of_rarity(tier)
		var counts := {}
		var n := 6000
		for i in n:
			var piece := Gear.roll_tier_chest(tier, rng)
			counts[str(piece["family"])] = int(counts.get(str(piece["family"]), 0)) + 1
		eq(counts.size(), pool.size(), "%s rolls every set of its tier" % tier)
		for fam in pool:
			var share := float(counts.get(fam, 0)) / float(n)
			eq(absf(share - 1.0 / float(pool.size())) < 0.025, true, "%s share %.3f is even (%d sets)" % [fam, share, pool.size()])
	eq(Gear.families_of_rarity("Normal").size(), 6, "Normal: Ashmantle and the five class sets")
	eq(Gear.families_of_rarity("Rare").size(), 5, "Rare: the five class sets")
	eq(Gear.families_of_rarity("Legendary").size(), 6, "Legendary: Brightedge and the five class sets")
	# World fights: Normal tier only.
	var book = Rewards.load_default()["rewards"]
	var world_rng := _rng(5)
	var seen_world := {}
	for i in 4000:
		for item in book.roll("world", {"level": 5}, world_rng)["items"]:
			seen_world[Gear.rarity_of(Gear.family_of(str(item["item_id"])))] = true
	eq(seen_world.keys(), ["Normal"], "world fights drop Normal-tier pieces only")


## World fights, for the open-world zone monsters to come (Mauro, 12 Oct
## 2026: "Para eso tiene que haber mobs en el openworld… debe de haber zonas
## de lvl"): roll_world_drop(zone_level, rng), chance from rewards.json.
func _test_world_drop() -> void:
	var rules := Gear.world_rules()
	eq(absf(float(rules["world_chance"]) - 0.08) < 0.0001, true, "world chance 0.08 from the data")
	var rng := _rng(808)
	var n := 20000
	var got := 0
	var levels := {}
	for i in n:
		var piece := Gear.roll_world_drop(17, rng)
		if piece.is_empty():
			continue
		got += 1
		eq(Gear.rarity_of(str(piece["family"])), "Normal", "a world drop is Normal")
		eq(int(piece["plus"]), 0, "a world drop is +0")
		levels[int(piece["zone_level"])] = true
	eq(absf(float(got) / n - 0.08) < 0.006, true, "world drop rate %.4f near 0.08" % (float(got) / n))
	eq(levels.keys(), [17], "the drop carries its zone level")
	eq(Gear.roll_world_drop(5, _rng(1), 0.0).is_empty(), true, "chance 0 drops nothing")
	eq(Gear.roll_world_drop(5, _rng(1), 1.0, "Rare")["rarity"], "Rare", "the tier is a parameter")
	# The proposed rate: about 14 world wins a level (balance_inputs: world 50%
	# of XP at 3.5% of a step a fight) over a 10-level band gives about three
	# wearable Normal slots.
	var est := Gear.world_band_estimate(14.0)
	eq(float(est["slots"]) > 2.5 and float(est["slots"]) < 3.5, true, "about 3 Normal slots a band (%.2f slots, %.1f pieces, %.1f wearable)" % [float(est["slots"]), float(est["pieces"]), float(est["wearable"])])
	# Simulated: one class over a band of world wins.
	var srng := _rng(4242)
	var bands := 400
	var total_slots := 0
	for b in bands:
		var slots := {}
		for w in 140:
			var p := Gear.roll_world_drop(5, srng)
			if p.is_empty():
				continue
			if Gear.can_wear(str(p["family"]), "kestrel"):
				slots[str(p["slot"])] = true
		total_slots += slots.size()
	var mean := float(total_slots) / bands
	eq(mean > 2.4 and mean < 3.6, true, "a Kestrel ends a 140-win band with about 3 Normal slots filled (%.2f)" % mean)
	# The rewards roll goes through the same pipe.
	var book = Rewards.load_default()["rewards"]
	var a := Gear.roll_world_drop(9, _rng(3))
	var b: Dictionary = book.roll_world_drop(9, _rng(3))
	eq(str(a.get("item_id", "")), str(b.get("item_id", "")), "pc_rewards.roll_world_drop is the pc_gear pipe")


func _test_ultra_never_drops() -> void:
	var book = Rewards.load_default()["rewards"]
	var rng := _rng(31)
	var ultra := 0
	var rolled := 0
	for i in 1500:
		for star in [1, 3, 5]:
			for item in book.roll("dungeon", {"dungeon_id": "heart_of_the_blight", "level": 45, "stars": star}, rng)["items"]:
				rolled += 1
				if Gear.is_ultra(Gear.family_of(str(item["item_id"]))):
					ultra += 1
		for item in book.roll("mission", {"level": 30, "missions_finished": 120 + (i % 9)}, rng)["items"]:
			if Gear.is_ultra(Gear.family_of(str(item["item_id"]))):
				ultra += 1
		for item in book.open_box({"level": 30}, rng)["items"]:
			if Gear.is_ultra(Gear.family_of(str(item["item_id"]))):
				ultra += 1
	eq(rolled > 4000, true, "many pieces rolled")
	eq(ultra, 0, "Ultra never drops (dungeon, mission, box)")
	for fam in Gear.ULTRA_ORDER:
		eq(Gear.FAMILY_ORDER.has(fam), false, "%s is not on the loot ladder" % fam)
		eq(str(book.item(Gear.item_id_for(fam, "head")).get("drop", "")), "Open", "%s parts have no drop source" % fam)


func _test_class_fit() -> void:
	for cls in Gear.CLASS_IDS:
		eq(Gear.can_wear("ashmantle", cls), true, "Ashmantle fits %s" % cls)
		eq(Gear.can_wear("brightedge", cls), true, "Brightedge fits %s" % cls)
	eq(Gear.can_wear("cragmaw", "ironjaw"), true, "Cragmaw fits Ironjaw")
	eq(Gear.can_wear("cragmaw", "Ironjaw"), true, "display class names work")
	eq(Gear.can_wear("cragmaw", "kestrel"), false, "Cragmaw does not fit Kestrel")
	eq(Gear.can_wear("sheaf", "bastion"), false, "Sheaf does not fit Bastion")
	_clear_save()
	var hero = Progress.new()
	hero.set_hero_class("kestrel")
	var got: Dictionary = hero.grant({"items": [{"item_id": "cragmaw.head", "rarity": "normal", "count": 1}, {"item_id": "ashmantle.head", "rarity": "normal", "count": 1}]})
	eq(bool(got["ok"]), true, "a Kestrel can receive an Ironjaw piece")
	eq(hero.bag.size(), 2, "both pieces sit in the bag")
	var wrong: Dictionary = hero.equip_uid(int(hero.bag[0]["uid"]))
	eq(str(wrong.get("reason", "")), "class", "a Kestrel cannot wear Cragmaw")
	eq(bool(hero.equip_uid(int(hero.bag[1]["uid"]))["ok"]), true, "a Kestrel wears Ashmantle")
	eq(hero.bag.size(), 1, "the Ironjaw piece stays in the bag (to sell or trade later)")
	hero.set_hero_class("ironjaw")
	eq(bool(hero.equip_uid(int(hero.bag[0]["uid"]))["ok"]), true, "an Ironjaw wears it")
	hero.set_hero_class("kestrel")
	eq(hero.equipped.has("head"), false, "switching class takes the Ironjaw piece off")
	_clear_save()


## An old save: level-tier parts in the bag, the bank and worn (head, cape,
## belt), one Rare. It loads, every old part becomes the Ashmantle piece of
## the mapped slot, a Rare part becomes +1, worn parts stay worn.
func _test_migration() -> void:
	_write_save({
		"level": 12, "xp": 5, "coins": 77, "hero_class": "Gloam",
		"bag": [
			{"uid": 1, "item_id": "kestrel_fledgling_head", "rarity": "regular", "count": 1},
			{"uid": 2, "item_id": "ratcatcher_amulet", "rarity": "rare", "count": 1},
			{"uid": 3, "item_id": "mystery_box", "rarity": "regular", "count": 2},
		],
		"bank": [{"uid": 4, "item_id": "townguard_boots", "rarity": "regular", "count": 1}],
		"equipped": {
			"head": {"uid": 5, "item_id": "gloam_shadowstep_head", "rarity": "regular", "seq": 1},
			"cape": {"uid": 6, "item_id": "gloam_shadowstep_cape", "rarity": "rare", "seq": 2},
			"belt": {"uid": 7, "item_id": "wayfarer_belt", "rarity": "regular", "seq": 3},
			"ring": {"uid": 8, "item_id": "plain_band", "rarity": "regular", "seq": 4},
		},
		"rare_choice": "ap",
		"next_uid": 9,
	})
	var hero = Progress.new()
	eq(hero.level, 12, "old save loads (level kept)")
	eq(hero.coins, 77, "coins kept")
	var bag_ids: Array = []
	for row in hero.bag:
		bag_ids.append("%s+%d" % [str(row["item_id"]), int(row.get("plus", 0))])
	eq(bag_ids.has("ashmantle.head+0"), true, "an old head part becomes Ashmantle Helm")
	eq(bag_ids.has("ashmantle.weapon+1"), true, "an old Rare amulet becomes Ashmantle Brand +1")
	eq(bag_ids.has("mystery_box+0"), true, "the Mystery Box is untouched")
	eq(str(hero.bank[0]["item_id"]), "ashmantle.boots", "a banked part migrates too")
	eq(str(hero.equipped.get("head", {}).get("item_id", "")), "ashmantle.head", "a worn head stays worn as Ashmantle")
	eq(str(hero.equipped.get("chest", {}).get("item_id", "")), "ashmantle.chest", "a worn cape becomes a worn chest")
	eq(int(hero.equipped.get("chest", {}).get("plus", 0)), 1, "an old Rare cape is +1")
	eq(str(hero.equipped.get("legs", {}).get("item_id", "")), "ashmantle.legs", "a worn belt becomes worn legs")
	eq(str(hero.equipped.get("ring", {}).get("item_id", "")), "plain_band", "the ring stays")
	eq(hero.equipped.has("cape") or hero.equipped.has("belt"), false, "no retired slot is left")
	eq(hero.load_log.size() >= 6, true, "the load log lists the migrated parts")
	var uids := {}
	for row in hero.bag + hero.bank:
		uids[int(row["uid"])] = true
	for slot in hero.equipped.keys():
		uids[int(hero.equipped[slot]["uid"])] = true
	eq(uids.size(), hero.bag.size() + hero.bank.size() + hero.equipped.size(), "uids stay unique")
	hero.save()
	var again = Progress.new()
	eq(str(again.equipped.get("chest", {}).get("item_id", "")), "ashmantle.chest", "the migrated save reloads")
	# A save with an unknown non-gear item still refuses, as before.
	_write_save({"level": 3, "xp": 0, "bag": [{"uid": 1, "item_id": "no_such_thing", "rarity": "regular", "count": 1}]})
	var bad = Progress.new()
	eq(bad.level, 1, "a broken save is still refused without a crash")
	_clear_save()


## The dungeon run carries pc_progress.fight_gear into CombatSim.
func _test_fight_wiring() -> void:
	var made: Dictionary = Run.create("old_granary_cellar", 2, "bastion", "", 1)
	eq(bool(made.get("ok", false)), true, "run builds")
	var run = made["run"]
	var sim: Node = root.get_node("CombatSim")
	sim.reset_match(run.combat_config(0, 3))
	var bare: Dictionary = sim.snapshot()["units"][0]
	eq(int(bare["max_hp"]), 80, "no gear: the 80 HP body")
	run.hero_gear = {"worn": _full("oathgrave", 0), "class_id": "bastion", "extra_ap": 0}
	sim.reset_match(run.combat_config(0, 3))
	var geared: Dictionary = sim.snapshot()["units"][0]
	eq(int(geared["max_hp"]), roundi(164.0 * 1.12), "Oathgrave on a Bastion: (80 + 84) x 1.12")
	eq(int(geared["hp"]), int(geared["max_hp"]), "the room starts at full geared HP")
	eq(int(geared["max_ap"]), 7, "Legendary 5pc: 7 AP in the fight")
	eq(int(geared["max_mp"]), 4, "Legendary 5pc: 4 MP in the fight")
	eq(int(geared["ap"]), 7, "first turn starts with 7 AP")
	run.hero_gear = {"worn": _full("oathgrave", 0), "class_id": "kestrel", "extra_ap": 0}
	var kestrel_made: Dictionary = Run.create("old_granary_cellar", 2, "kestrel", "", 1)
	var krun = kestrel_made["run"]
	krun.hero_gear = run.hero_gear
	sim.reset_match(krun.combat_config(0, 3))
	eq(int(sim.snapshot()["units"][0]["max_hp"]), 80, "a Kestrel gains nothing from Bastion gear")


## The paper doll reads set id, part id and slot from a worn piece.
func _test_looks() -> void:
	_clear_save()
	var hero = Progress.new()
	hero.set_hero_class("ironjaw")
	hero.grant({"items": [{"item_id": "cragmaw.chest", "rarity": "normal", "count": 1, "plus": 3}]})
	hero.equip_uid(int(hero.bag[0]["uid"]))
	var look: Dictionary = hero.equipped_look("chest")
	eq(str(look.get("set_id", "")), "cragmaw", "look set id")
	eq(str(look.get("part_id", "")), "cragmaw.chest", "look part id")
	eq(str(look.get("slot", "")), "chest", "look slot")
	eq(int(look.get("plus", -1)), 3, "look plus")
	eq(hero.equipped_looks().keys(), ["chest"], "looks keyed by slot")
	eq(hero.equipped_look("head").is_empty(), true, "an empty slot has no look")
	_clear_save()


func _full(fam: String, plus: int) -> Array:
	var out: Array = []
	for slot in Gear.SLOTS:
		out.append({"item_id": Gear.item_id_for(fam, slot), "plus": plus})
	return out


func _write_save(doc: Dictionary) -> void:
	var file := FileAccess.open(Progress.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(doc))
	file.close()


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


func _clear_save() -> void:
	if FileAccess.file_exists(Progress.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Progress.SAVE_PATH))


func _backup_save() -> void:
	_had_save = FileAccess.file_exists(Progress.SAVE_PATH)
	if _had_save:
		_backup = FileAccess.get_file_as_string(Progress.SAVE_PATH)


func _restore_save() -> void:
	if _had_save:
		var file := FileAccess.open(Progress.SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_backup)
	else:
		_clear_save()


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL %s (got %s, expected %s)" % [msg, str(actual), str(expected)])
	else:
		_passed += 1
