extends RefCounted

## Low fog and sparse spores for Blightwood Hollow. Fog fades out across the
## entry's west and north edges so the meadow join is not a fog wall.

const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")
const Kit := preload("res://scenes/world/crosshaven/blightwood_art.gd")
const FOG_SHADER := preload("res://scenes/world/crosshaven/blightwood_fog.gdshader")
const DRIFT := "res://art/world/blightwood_hollow/animated/ground_fog_drift_12f.png"

static var _mat: ShaderMaterial
static var _spores: SpriteFrames


static func dress(ground: Node2D) -> void:
	var zone: WorldZone = ground.get("zone")
	if zone == null or zone.region != "blightwood_hollow":
		return
	var mat := _fog_mat()
	for row in ground.get_children():
		if not str(row.name).begins_with("Row"):
			continue
		var fog := Node2D.new()
		fog.name = "BlightFog"
		fog.z_as_relative = false
		fog.z_index = (row as Node2D).z_index
		fog.material = mat
		var diagonal := int(str(row.name).trim_prefix("Row"))
		fog.draw.connect(_draw_fog.bind(ground, fog, diagonal))
		row.add_child(fog)
	_scatter_spores(ground)


static func _fog_mat() -> ShaderMaterial:
	if _mat != null:
		_mat.set_shader_parameter("animate", 1.0 if Kit.animated() else 0.0)
		return _mat
	_mat = ShaderMaterial.new()
	_mat.shader = FOG_SHADER
	_mat.set_shader_parameter("drift", load(DRIFT))
	_mat.set_shader_parameter("animate", 1.0 if Kit.animated() else 0.0)
	return _mat


static func _fog_alpha(zone: WorldZone, cell: Vector2i) -> float:
	var a := 0.45
	if not zone.zone_id.ends_with("_entry"):
		return a
	var edge := mini(cell.x, cell.y)
	if edge < 5:
		a *= clampf(float(edge) / 5.0, 0.0, 1.0)
	return a


static func _draw_fog(ground: Node2D, ci: Node2D, diagonal: int) -> void:
	var zone: WorldZone = ground.get("zone")
	if zone == null:
		return
	var origin: Vector2i = ground.get("world_origin")
	for cell in ground._row_cells(diagonal):
		if Art.terrain_seen(zone, cell) == "":
			continue
		var a := _fog_alpha(zone, cell)
		if a <= 0.01:
			continue
		var poly := PackedVector2Array()
		var center := BoardVisualSort.cell_to_local(cell, float(Art.height_seen(zone, cell)))
		poly.append(center + Vector2(0, -16))
		poly.append(center + Vector2(32, 0))
		poly.append(center + Vector2(0, 16))
		poly.append(center + Vector2(-32, 0))
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		var tint := Color(1, 1, 1, a)
		for p in poly:
			# World pixels, so the drift continues across cells.
			var world := p + Vector2(origin.x - origin.y, origin.x + origin.y) * 16.0
			uvs.append(Vector2(world.x / 256.0, world.y / 128.0))
			cols.append(tint)
		ci.draw_polygon(poly, cols, uvs)


static func _spore_frames() -> SpriteFrames:
	if _spores != null:
		return _spores
	_spores = Kit._frames(
		"res://art/world/blightwood_hollow/animated/spores_drift_12f.png",
		12, Vector2i(128, 128), 10.0, "drift"
	)
	return _spores


static func _scatter_spores(ground: Node2D) -> void:
	var zone: WorldZone = ground.get("zone")
	var origin: Vector2i = ground.get("world_origin")
	var frames := _spore_frames()
	var host := Node2D.new()
	host.name = "BlightSpores"
	ground.add_child(host)
	for y in zone.height:
		for x in zone.width:
			var cell := Vector2i(x, y)
			if zone.terrain_at(cell) == "dirt_road":
				continue
			if zone.zone_id.ends_with("_entry") and mini(x, y) < 5:
				continue
			var wc := cell + origin
			if Art.h(wc.x, wc.y, 36) != 0:
				continue
			var spr := AnimatedSprite2D.new()
			spr.sprite_frames = frames
			spr.animation = "drift"
			spr.centered = true
			spr.scale = Vector2(0.55, 0.55)
			spr.modulate = Color(1, 1, 1, 0.7)
			var south := BoardVisualSort.cell_to_local(cell) + Vector2(0, 16)
			spr.position = south + Vector2(0, -52)
			spr.z_as_relative = false
			spr.z_index = (cell.x + cell.y) * BoardVisualSort.TILE_Z_SCALE + 4
			host.add_child(spr)
			if Kit.animated():
				spr.frame = Art.h(wc.x, wc.y, 12)
				spr.play("drift")
			else:
				spr.frame = Art.h(wc.x, wc.y, 12)
				spr.pause()
