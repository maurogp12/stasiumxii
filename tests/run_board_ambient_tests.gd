extends SceneTree

## View-only board chrome: shimmer, overlay breathe, motes, crisp outlines.
## Run: godot --headless --path . -s res://tests/run_board_ambient_tests.gd

const AMBIENT := preload("res://board/board_ambient.gd")
const TILE_SCRIPT := preload("res://board/tile.gd")
const VISUAL_SORT := preload("res://board/visual_sort.gd")
const MOTION := preload("res://units/view_motion.gd")

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	print("Board ambient tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_tunables_stay_in_range()
	_test_shimmer_is_water_and_mud_only()
	_test_overlay_breathe_is_a_slow_sine()
	_test_tile_filter_seam_and_shimmer()
	_test_crisp_outline_does_not_replace_fill()
	_test_ambient_props_pulse_from_the_foot()
	_test_motes_stay_sparse()
	_test_view_wires_chrome_without_rules()


func _test_tunables_stay_in_range() -> void:
	eq(AMBIENT.OVERLAY_PERIOD >= 1.2 and AMBIENT.OVERLAY_PERIOD <= 1.8, true, "overlay breathe period is 1.2–1.8s")
	near(AMBIENT.OVERLAY_ALPHA_MIN, 0.46, "overlay breathe floor")
	near(AMBIENT.OVERLAY_ALPHA_MAX, 0.54, "overlay breathe ceiling")
	eq(AMBIENT.OVERLAY_ALPHA_MAX - AMBIENT.OVERLAY_ALPHA_MIN <= 0.081, true, "opacity swing stays within about 8%")
	eq(AMBIENT.OVERLAY_ALPHA_MIN >= 0.45, true, "a legal wash stays clearly filled")
	eq(AMBIENT.CRISP_OUTLINE_PX >= 1.0 and AMBIENT.CRISP_OUTLINE_PX <= 2.0, true, "selected rim is 1–2 px")
	eq(AMBIENT.CRISP_INNER_PX >= 1.0 and AMBIENT.CRISP_INNER_PX <= 2.0, true, "selected core is 1–2 px")
	eq(AMBIENT.SEAM_BLEED_PX > 0.0 and AMBIENT.SEAM_BLEED_PX <= 1.5, true, "seam overlap stays a hairline")
	eq(AMBIENT.MOTE_AMOUNT <= 8, true, "mote count stays sparse")
	eq(AMBIENT.MOTE_AMOUNT >= 4, true, "motes are visible")
	eq(AMBIENT.MOTE_LIFETIME >= 6.0, true, "motes live long enough to read as dust")
	eq(AMBIENT.MOTE_Z < 0, true, "motes sort under tiles and pawns")
	near(AMBIENT.MOTE_ALPHA, 0.14, "mote alpha stays faint")
	eq(AMBIENT.SHIMMER_PERIOD >= 3.5, true, "water pulse is slower than a hit flash")
	eq(AMBIENT.SHIMMER_AMPLITUDE_MUD < AMBIENT.SHIMMER_AMPLITUDE_WATER, true, "mud shimmer is the quieter of the two")
	eq(AMBIENT.SHIMMER_AMPLITUDE_WATER <= 0.04, true, "water shimmer stays a low mid-value drift")
	var prop_crest := AMBIENT.prop_gain(AMBIENT.PROP_PERIOD * 0.25, 0.0)
	near(prop_crest, 1.0, "prop pulse crests at the painted value")
	eq(AMBIENT.prop_gain(AMBIENT.PROP_PERIOD * 0.75, 0.0) < 1.0, true, "prop pulse only dips")
	eq(AMBIENT.prop_is_ambient("waterfall"), true, "waterfall can idle-breathe")
	eq(AMBIENT.prop_is_ambient("steam_vent"), true, "steam vent can idle-breathe")
	eq(AMBIENT.prop_is_ambient("spark"), true, "spark can idle-breathe")
	eq(AMBIENT.prop_is_ambient("crystal"), true, "crystal can idle-breathe")
	eq(AMBIENT.prop_is_ambient("ruins"), false, "ruins stay still")
	eq(AMBIENT.prop_is_ambient("crystal_bolt"), false, "crystal bolt is not the idle crystal")


func _test_shimmer_is_water_and_mud_only() -> void:
	eq(AMBIENT.shimmers("water"), true, "water shimmers")
	eq(AMBIENT.shimmers("mud"), true, "mud shimmers")
	eq(AMBIENT.shimmers("ground"), false, "ground stays still")
	eq(AMBIENT.shimmers("lava"), false, "lava stays still")
	var shader := AMBIENT.shimmer_shader()
	truthy(shader != null, "shimmer shader loads")
	var src := FileAccess.get_file_as_string("res://board/board_shimmer.gdshader")
	truthy(src.contains("shader_type canvas_item"), "shimmer is a canvas_item shader")
	truthy(src.contains("uv"), "shimmer moves UVs")
	truthy(src.contains("1.0 - amplitude"), "shimmer never adds light above the texel")
	eq(src.contains("1.0 + sin"), false, "shimmer has no specular add")
	var lo := 2.0
	var hi := 0.0
	for step in 32:
		var t := AMBIENT.SHIMMER_PERIOD * float(step) / 32.0
		var gain := AMBIENT.shimmer_gain(t, 0.0, "water")
		lo = minf(lo, gain)
		hi = maxf(hi, gain)
	near(lo, 1.0 - AMBIENT.SHIMMER_AMPLITUDE_WATER, "water gain trough")
	near(hi, 1.0, "water gain crests at the painted mid value")
	eq(hi <= 1.001, true, "water never brightens past the texture")


func _test_overlay_breathe_is_a_slow_sine() -> void:
	eq(AMBIENT.overlay_breathes("move", false), true, "move overlays breathe")
	eq(AMBIENT.overlay_breathes("range", false), true, "range overlays breathe")
	eq(AMBIENT.overlay_breathes("target", false), true, "target overlays breathe")
	eq(AMBIENT.overlay_breathes("selected", false), true, "selected overlays breathe")
	eq(AMBIENT.overlay_breathes("", true), true, "a selected tile breathes")
	eq(AMBIENT.overlay_breathes("advance", false), false, "advance chrome stays steady")
	eq(AMBIENT.overlay_breathes("blocked", true), false, "blocked chrome stays steady")
	eq(AMBIENT.overlay_breathes("origin", false), false, "origin chrome stays steady")
	var crest := AMBIENT.overlay_fill_alpha(AMBIENT.OVERLAY_PERIOD * 0.25, 0.0)
	var trough := AMBIENT.overlay_fill_alpha(AMBIENT.OVERLAY_PERIOD * 0.75, 0.0)
	near(crest, AMBIENT.OVERLAY_ALPHA_MAX, "sine crest is the breathe ceiling")
	near(trough, AMBIENT.OVERLAY_ALPHA_MIN, "sine trough is the breathe floor")
	var mid := AMBIENT.overlay_fill_alpha(0.0, 0.0)
	near(mid, BoardTile.HIGHLIGHT_FILL_ALPHA, "breathe is centered on the fill alpha")
	eq(crest - trough <= 0.081, true, "the sine swing stays within about 8% opacity")


func _test_tile_filter_seam_and_shimmer() -> void:
	var bare := TILE_SCRIPT.new() as BoardTile
	eq(bare.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "terrain draw uses linear filtering")
	var art: Texture2D = load("res://board/koliseo_art.gd").terrain_texture("ground", 0)
	truthy(art != null, "ground art still loads")
	var placed: Dictionary = load("res://board/koliseo_art.gd").terrain_placement(art)
	eq((placed["dest"] as Rect2).size, Vector2(64, 32), "placement cache stays the 64×32 diamond")
	var painted := bare.painted_terrain_dest(placed, art)
	eq(painted.position, Vector2(-33, -17), "paint grows the diamond by the seam bleed")
	eq(painted.size, Vector2(66, 34), "seam bleed is one pixel on every side")
	bare.free()

	var water := TILE_SCRIPT.new() as BoardTile
	water.grid_position = Vector2i.ZERO
	get_root().add_child(water)
	water.apply_board_data("water", 0)
	truthy(water.material is ShaderMaterial, "water tiles carry the shimmer material")
	var mat := water.material as ShaderMaterial
	near(float(mat.get_shader_parameter("amplitude")), AMBIENT.shimmer_amplitude("water"), "water amplitude matches the tunable")
	near(float(mat.get_shader_parameter("uv_amp")), AMBIENT.shimmer_uv("water"), "water UV amplitude matches the tunable")
	eq(water.fill_color(), Color(0.28, 0.54, 0.80), "water fill helper stays the flat color")
	water.apply_board_data("ground", 0)
	eq(water.material, null, "ground clears the shimmer material")
	water.apply_board_data("mud", 0)
	truthy(water.material is ShaderMaterial, "mud reuses the shimmer material")
	near(float((water.material as ShaderMaterial).get_shader_parameter("amplitude")), AMBIENT.shimmer_amplitude("mud"), "mud amplitude is the quiet tunable")
	MOTION.set_reduce_motion(true)
	water.resync_shimmer()
	eq(water.material, null, "reduce motion drops the shimmer")
	water.apply_ambient_frame(AMBIENT.SHIMMER_PERIOD * 0.25)
	eq(water.self_modulate, Color.WHITE, "reduce motion holds the flat modulate")
	MOTION.set_reduce_motion(false)
	water.resync_shimmer()
	truthy(water.material is ShaderMaterial, "motion back on restores the mud shimmer")
	water.free()


func _test_crisp_outline_does_not_replace_fill() -> void:
	var tile := TILE_SCRIPT.new() as BoardTile
	tile.grid_position = Vector2i.ZERO
	get_root().add_child(tile)
	tile.apply_board_data("mud", 1)
	tile.set_hovered(true)
	eq(tile.overlay_color().a, 0.0, "hover does not invent a fill")
	eq(tile.draws_crisp_outline(), true, "hover draws the crisp rim")
	eq(tile.fill_color(), Color(0.56, 0.38, 0.20), "hover leaves the mud fill")
	tile.set_highlight("move")
	eq(tile.overlay_color(), Color(0.45, 0.78, 0.92, BoardTile.HIGHLIGHT_FILL_ALPHA), "move fill alpha stays the constant")
	eq(tile.draws_crisp_outline(), true, "hover on a move tile uses the crisp rim")
	tile.set_hovered(false)
	eq(tile.draws_crisp_outline(), false, "leaving the tile drops the crisp rim")
	tile.set_selected(true)
	eq(tile.overlay_color().a, BoardTile.HIGHLIGHT_FILL_ALPHA, "selected fill stays readable")
	eq(tile.draws_crisp_outline(), true, "selected draws the crisp rim")
	MOTION.set_reduce_motion(true)
	tile.apply_ambient_frame(AMBIENT.OVERLAY_PERIOD * 0.25)
	near(tile.breathe_fill_alpha(), BoardTile.HIGHLIGHT_FILL_ALPHA, "reduce motion holds the fill alpha")
	MOTION.set_reduce_motion(false)
	tile.apply_ambient_frame(AMBIENT.OVERLAY_PERIOD * 0.25)
	near(tile.breathe_fill_alpha(), AMBIENT.OVERLAY_ALPHA_MAX, "selected fill breathes to the ceiling")
	tile.set_highlight("blocked")
	eq(tile.draws_crisp_outline(), false, "blocked tiles keep their own mark")
	eq(tile.overlay_color().a, BoardTile.HIGHLIGHT_FILL_ALPHA, "blocked fill alpha is unchanged")
	tile.free()


func _test_ambient_props_pulse_from_the_foot() -> void:
	var tile := TILE_SCRIPT.new() as BoardTile
	tile.grid_position = Vector2i(1, 2)
	get_root().add_child(tile)
	tile.set_paint_props(["ruins", "crystal"])
	eq(tile.get_node_or_null("AmbientProp0") != null, true, "crystal becomes a sprite")
	eq(tile.get_child_count(), 2, "only the crystal is split out of the draw")
	var pivot := tile.get_node("AmbientProp0") as Node2D
	eq(pivot.position, Vector2(0, 16), "ambient prop pivots on the south tip")
	var sprite := pivot.get_node("Sprite") as Sprite2D
	eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "prop art is linear")
	var tex_h := sprite.texture.get_height()
	eq(sprite.position, Vector2(0, -tex_h * 0.5), "the foot stays on the pivot")
	var kept := pivot
	tile.set_paint_props(["ruins", "crystal"])
	eq(tile.get_node("AmbientProp0"), kept, "the same prop list does not rebuild the sprite")
	MOTION.set_reduce_motion(false)
	var phase := AMBIENT.phase_for(tile.grid_position)
	tile.apply_ambient_frame(AMBIENT.PROP_PERIOD * 0.25)
	near(pivot.scale.x, AMBIENT.prop_scale(AMBIENT.PROP_PERIOD * 0.25, phase), "crystal scale breathes")
	eq(pivot.scale.x > 1.0 and pivot.scale.x < 1.04, true, "the prop pulse is tiny")
	MOTION.set_reduce_motion(true)
	tile.apply_ambient_frame(AMBIENT.PROP_PERIOD * 0.25)
	near(pivot.scale.x, 1.0, "reduce motion rests the prop")
	MOTION.set_reduce_motion(false)
	tile.set_paint_props(["waterfall", "steam_vent"])
	eq(tile.get_node_or_null("AmbientProp1") != null, true, "a second ambient prop gets its own pivot")
	tile.free()


func _test_motes_stay_sparse() -> void:
	var ambient := AMBIENT.new() as BoardAmbient
	get_root().add_child(ambient)
	ambient.fit_to_size(15)
	var left := ambient.get_node("Motes/Left") as CPUParticles2D
	var right := ambient.get_node("Motes/Right") as CPUParticles2D
	truthy(left != null and right != null, "dust is two apron strips")
	eq(left.amount + right.amount, AMBIENT.MOTE_AMOUNT, "both strips share the mote budget")
	eq(left.one_shot, false, "dust loops")
	eq(left.emitting and right.emitting, true, "dust is on while motion is allowed")
	eq(left.lifetime, AMBIENT.MOTE_LIFETIME, "dust lifetime matches the tunable")
	eq(left.z_index, AMBIENT.MOTE_Z, "dust sorts under the board")
	eq(right.z_index < VISUAL_SORT.unit_z_index(Vector2i(0, 0), 0.0), true, "dust cannot cover a pawn")
	eq(left.z_as_relative, false, "dust z is absolute")
	eq(left.gravity, Vector2.ZERO, "dust does not fall onto the diamond")
	eq(left.direction.x < 0.0, true, "the left strip drifts outward")
	eq(right.direction.x > 0.0, true, "the right strip drifts outward")
	var bounds := AMBIENT.diamond_bounds(15)
	eq(AMBIENT.strip_clears_playfield(left.position, left.emission_rect_extents, bounds, left.direction.x), true, "left dust stays outside the diamond")
	eq(AMBIENT.strip_clears_playfield(right.position, right.emission_rect_extents, bounds, right.direction.x), true, "right dust stays outside the diamond")
	var inward := AMBIENT.MOTE_SPEED_MAX * AMBIENT.MOTE_LIFETIME * sin(deg_to_rad(AMBIENT.MOTE_SPREAD_DEG))
	var gap := (AMBIENT.APRON_PX - AMBIENT.APRON_BAND) * 0.5
	eq(inward < gap, true, "spread cannot carry dust onto the playfield")
	var ramp := left.color_ramp as Gradient
	var peak := 0.0
	for i in ramp.get_point_count():
		peak = maxf(peak, ramp.get_color(i).a)
	near(peak, AMBIENT.MOTE_ALPHA, "dust alpha peaks at the faint tunable")
	MOTION.set_reduce_motion(true)
	ambient.fit_to_size(15)
	eq(left.emitting, false, "reduce motion stops the dust")
	eq(right.emitting, false, "reduce motion stops both strips")
	MOTION.set_reduce_motion(false)
	ambient.free()


func _test_view_wires_chrome_without_rules() -> void:
	var parsed: Script = load("res://board_view.gd") as Script
	truthy(parsed != null, "board view parses")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("BOARD_AMBIENT"), "board view owns the ambient layer")
	truthy(view.contains("_set_board_hover"), "desktop motion sets tile hover")
	eq(view.contains("hp"), false, "board_view still does not mention hp")
	var sim := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim.contains("BoardAmbient"), false, "CombatSim does not read the ambient layer")
	eq(sim.contains("board_shimmer"), false, "CombatSim does not read the shimmer shader")
	var sort := FileAccess.get_file_as_string("res://board/visual_sort.gd")
	truthy(sort.contains("float(cell.x - cell.y) * 32.0"), "cell_to_local keeps the 32 px iso step")
	truthy(sort.contains("float(cell.x + cell.y) * 16.0"), "cell_to_local keeps the 16 px iso step")
	eq(VISUAL_SORT.cell_to_local(Vector2i(1, 0), 0.0), Vector2(32, 16), "flat iso formula is unchanged")
	eq(VISUAL_SORT.cell_to_local(Vector2i(1, 0), 1.0), Vector2(32, 6), "elevation lift is still 10 px")
	var hud := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud.contains("Color(0.92, 0.22, 0.14)"), "reject toast red is unchanged")
	truthy(view.contains("flash_hit"), "hit flash still plays on the pawn")
	truthy(view.contains("flash_impact"), "impact flash still plays on the caster")
	eq(view.contains("vignette"), false, "the board does not dim the corners")
	eq(FileAccess.get_file_as_string("res://board/board_shimmer.gdshader").contains("vignette"), false, "the floor shader does not dim corners")


func near(actual: float, expected: float, msg: String) -> void:
	if absf(actual - expected) > 0.002:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1


func truthy(value: Variant, msg: String) -> void:
	if not value:
		_failed += 1
		print("FAIL: %s  (got %s)" % [msg, value])
	else:
		_passed += 1
