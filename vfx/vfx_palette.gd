extends RefCounted
class_name VfxPalette

## Colours from the VFX plan section 2.3 and the floating-number style notes.
## Damage is orange-red, heals are green, absorbed and shield values are grey-blue.

const OUTLINE := Color("1A1016")
const NUMBER_OUTLINE := Color("1a0c06")
const NUMBER_SHADOW := Color(0.08, 0.04, 0.03, 0.45)

const DAMAGE_TOP := Color(1.0, 0.745098, 0.27451)
const DAMAGE_BOTTOM := Color(0.941176, 0.203922, 0.094118)
const HEAL_TOP := Color(0.882353, 1.0, 0.54902)
const HEAL_BOTTOM := Color(0.180392, 0.745098, 0.235294)
const SHIELD_TOP := Color(0.78, 0.84, 0.90)
const SHIELD_BOTTOM := Color(0.42, 0.50, 0.60)
const MISS := Color(0.55, 0.55, 0.58)
const BURN := Color(0.92, 0.28, 0.1)
const EMBER := Color("FFC266")
const STUN := Color(0.95, 0.78, 0.2, 1.0)

const KESTREL := Color("3FA35B")
const KESTREL_AIR := Color("EAF6F0")
const IRONJAW := Color("C23B2E")
const IRONJAW_EARTH := Color("7A5230")
const IRONJAW_DUST := Color("B89468")
const MENDER := Color("4FD1B5")
const MENDER_CREAM := Color("F3E9D2")
const GLOAM := Color("6B4FA0")
const GLOAM_RIM := Color("9F8CFF")
const GLOAM_VOID := Color("140F24")
const BASTION := Color("D4A437")
const BASTION_BLACK := Color("15151A")

static var _dot: Texture2D
static var _ellipse: Texture2D


static func class_tint(class_id: String) -> Color:
	match class_id:
		"kestrel":
			return KESTREL
		"ironjaw":
			return IRONJAW
		"mender":
			return MENDER
		"gloam":
			return GLOAM
		"bastion":
			return BASTION
		_:
			return KESTREL_AIR


static func spell_tint(spell_id: String) -> Color:
	var def: Dictionary = SpellKits.spell(spell_id)
	return class_tint(str(def.get("class_id", "")))


static func dust_tint(spell_id: String) -> Color:
	var def: Dictionary = SpellKits.spell(spell_id)
	var class_id := str(def.get("class_id", ""))
	if class_id == "ironjaw":
		return IRONJAW_EARTH
	if class_id == "bastion":
		return BASTION
	return class_tint(class_id)


static func number_colors(kind: String) -> Dictionary:
	match kind:
		"heal":
			return {"top": HEAL_TOP, "bottom": HEAL_BOTTOM, "size": VfxBudget.NUMBER_SIZE}
		"shield", "absorb":
			return {"top": SHIELD_TOP, "bottom": SHIELD_BOTTOM, "size": VfxBudget.NUMBER_SIZE}
		"miss":
			return {"top": MISS, "bottom": MISS.darkened(0.15), "size": VfxBudget.NUMBER_SIZE_SMALL}
		"burn":
			return {"top": EMBER, "bottom": BURN, "size": VfxBudget.NUMBER_SIZE}
		"resource", "mp":
			return {"top": KESTREL_AIR, "bottom": KESTREL_AIR.darkened(0.25), "size": VfxBudget.NUMBER_SIZE_SMALL}
		"stagger":
			return {"top": DAMAGE_TOP, "bottom": DAMAGE_BOTTOM, "size": VfxBudget.NUMBER_SIZE_SMALL}
		_:
			return {"top": DAMAGE_TOP, "bottom": DAMAGE_BOTTOM, "size": VfxBudget.NUMBER_SIZE}


static func dot_texture() -> Texture2D:
	if _dot != null:
		return _dot
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in 8:
		for x in 8:
			var dist := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(Vector2(4.0, 4.0))
			var alpha := clampf(1.0 - dist / 3.6, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	_dot = ImageTexture.create_from_image(image)
	return _dot


static func ellipse_texture() -> Texture2D:
	if _ellipse != null:
		return _ellipse
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(32.0, 16.0)
	for y in 32:
		for x in 64:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var local := (p - center) / Vector2(26.0, 12.0)
			var dist := local.length()
			var alpha := clampf((1.0 - dist) * 1.6, 0.0, 0.55)
			if dist > 0.72 and dist < 1.0:
				alpha = maxf(alpha, 0.85)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	_ellipse = ImageTexture.create_from_image(image)
	return _ellipse


static func engine_label(engine: String) -> String:
	match engine:
		"impact":
			return "Impact"
		"mark":
			return "Mark"
		"umbral":
			return "Umbral"
		"aegis":
			return "Aegis"
		"pulse":
			return "Pulse"
		_:
			return engine.capitalize()
