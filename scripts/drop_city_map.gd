extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const Cloud = preload("res://scripts/drop_cloud.gdshader")
const Region = preload("res://scripts/region_terrain.gd")
const Signals = preload("res://scripts/city_signals.gd")
const Glass = preload("res://scripts/city_glass.gdshader")
const Surface = preload("res://scripts/road_surface.gd")
const Grass = preload("res://scripts/park_grass.gdshader")
const BLOCK := 40.0
const ROAD := Color("#354450")
const SIDEWALK := Color("#9ca6ab")
const COLORS: Array[Color] = [Color("#718c9b"), Color("#ac8b77"), Color("#8d92aa"), Color("#7e9c92")]
const DROP_PADS: Array[Vector3] = [Vector3(10, 0, 8), Vector3(-71, 0, 70), Vector3(89, 0, -90)]
var _rng := RandomNumberGenerator.new()
var _box_batches: Dictionary = {}
var _detail_batches: Dictionary = {}
var _clouds: Array[MeshInstance3D] = []


func build() -> void:
	_rng.seed = 7341
	_build_city(Vector3.ZERO, false)
	_build_city(Vector3(Region.CITY_DISTANCE, 0, 0), true)
	var region := Region.new()
	add_child(region)
	region.build()
	_draw_boxes()
	_build_clouds()


func _build_city(origin: Vector3, east: bool) -> void:
	var ground := _solid(Vector3(350, 1.0, 350), origin + Vector3(0, -0.51, 0), ROAD)
	Surface.set_surface(ground, Surface.Type.ASPHALT)
	for line in range(-4, 5):
		var offset := line * BLOCK
		for mark in range(-21, 22):
			_detail(Vector3(0.13, 0.012, 2.8), origin + Vector3(offset, 0.002, mark * 7.2), Color("#ded3a0"))
			_detail(Vector3(2.8, 0.012, 0.13), origin + Vector3(mark * 7.2, 0.002, offset), Color("#ded3a0"))
	for x in range(-4, 4):
		for z in range(-4, 4):
			_block(origin + Vector3((x + 0.5) * BLOCK, 0.0, (z + 0.5) * BLOCK), x, z, east)
	for index in DROP_PADS.size():
		var point := origin + DROP_PADS[index]
		_box(Vector3(3.6, 0.035, 3.6), point + Vector3.UP * 0.032, Color("#39bfb0"))
		_box(Vector3(0.16, 3.0, 0.16), point + Vector3(1.4, 1.5, 1.4), Color("#255d69"))
		_sign("DROP POINT", point + Vector3(1.4, 2.9, 1.4))
	_sign("RIDGE CITY" if east else "COASTAL CITY", origin + Vector3(-155, 3.5, 7))
	for stop in Signals.BUS_SHELTERS:
		_bus_stop(origin + stop)


func _build_clouds() -> void:
	var cloud := ShaderMaterial.new()
	cloud.shader = Cloud
	for index in 13:
		var puff := MeshInstance3D.new()
		puff.mesh = BoxMesh.new()
		puff.material_override = cloud
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.position = Vector3(_rng.randf_range(-155, 155), _rng.randf_range(174, 202), _rng.randf_range(-155, 155))
		if index == 0:
			puff.position = Vector3(0, 185, 5)
		puff.scale = Vector3(_rng.randf_range(66, 112), _rng.randf_range(23, 40), _rng.randf_range(66, 110))
		add_child(puff)
		_clouds.append(puff)
	for index in 9:
		var puff := _clouds[index].duplicate() as MeshInstance3D
		puff.position.x += Region.CITY_DISTANCE
		add_child(puff)
		_clouds.append(puff)


func cloud_moisture(at: Vector3) -> float:
	var moisture := 0.0
	if at.y < 140.0 or at.y > 230.0:
		return moisture
	for cloud in _clouds:
		var relative := (at - cloud.position) / cloud.scale
		moisture = maxf(moisture, 1.0 - smoothstep(0.24, 0.51, relative.length()))
	return moisture


func near_drop_pad(at: Vector3) -> bool:
	for pad in DROP_PADS:
		if at.distance_squared_to(pad) < 7.5 or at.distance_squared_to(pad + Vector3.RIGHT * Region.CITY_DISTANCE) < 7.5:
			return true
	return false


func _block(center: Vector3, x: int, z: int, east: bool) -> void:
	_box(Vector3(28.0, 0.10, 28.0), center + Vector3.UP * 0.045, SIDEWALK)
	var curb := StaticBody3D.new()
	curb.collision_layer = 8
	curb.collision_mask = 0
	curb.position = center
	add_child(curb)
	Surface.set_surface(curb, Surface.Type.CURB)
	var edge := CollisionShape3D.new()
	edge.shape = Surface.bevel(29.6, 29.6, -0.02, 0.09, 0.70)
	curb.add_child(edge)
	_street_furniture(center, x, z)
	if east and x == -1 and z == 0:
		_box(Vector3(22, 0.018, 22), center + Vector3.UP * 0.102, Color("#668a6d"))
		return
	if x == 1 and z == -2:
		_beacon_tower(center)
		return
	var has_venue := (x == 2 and z == -3) or (x == -2 and z == 1)
	if posmod(x * 3 + z * 5, 8) == 0 or has_venue:
		_park(center, has_venue)
		return
	for index in 2:
		var shift := -7.2 if index == 0 else 7.2
		var height := _rng.randf_range(12.0, 43.0) + (9.0 if east else 0.0)
		if posmod(x + z, 7) == 0 and index == 0:
			height += 18.0
		var base := center + Vector3(shift, 0, _rng.randf_range(-1.4, 1.4))
		var width := _rng.randf_range(8.2, 12.0)
		var depth := _rng.randf_range(14.0, 20.0)
		var paint := COLORS[_rng.randi_range(0, COLORS.size() - 1)].lerp(Color("#af8c83"), 0.36 if east else 0.0)
		_solid(Vector3(width, height, depth), base + Vector3.UP * (height * 0.5), paint)
		_box(Vector3(width + 0.55, 0.40, depth + 0.55), base + Vector3.UP * (height - 0.20), paint.lightened(0.20))
		_detail(Vector3(2.8, 1.2, 2.1), base + Vector3(1.6, height + 0.58, 0.0), Color("#53686c"))
		_detail(Vector3(0.62, 0.9, 0.55), base + Vector3(-1.8, height + 0.42, 0.7), Color("#99a3a0"))
		_detail(Vector3(width * 0.68, 1.8, 0.08), base + Vector3(0, 1.35, depth * 0.5 + 0.07), Color("#789b9c"))
		_detail(Vector3(width * 0.76, 0.46, 0.24), base + Vector3(0, 2.67, depth * 0.5 + 0.09), Color("#d4ab68"))
		if index == 1:
			for level in range(2, mini(7, floori(height / 3.4))):
				_detail(Vector3(1.65, 0.12, 0.9), base + Vector3(width * 0.5 + 0.51, level * 3.4, 2.7), Color("#546770"))
				_detail(Vector3(0.11, 3.5, 0.49), base + Vector3(width * 0.5 + 0.88, level * 3.4 + 1.56, 2.7), Color("#546770"))
		for row in range(1, floori(height / 3.4)):
			var level := base + Vector3.UP * (row * 3.4)
			var window := Color("#36586b") if row % 4 != 1 else Color("#d8bb7e")
			for side in [-1.0, 1.0]:
				_detail(Vector3(width * 0.73, 0.92, 0.06), level + Vector3(0, 0, side * (depth * 0.5 + 0.024)), window)
			if row % 2 == 0:
				_detail(Vector3(0.06, 0.98, depth * 0.72), level + Vector3(width * 0.5 + 0.024, 0, 0), window)
		for side in [-1.0, 1.0]:
			_solid(Vector3(2.8, 1.18, 0.54), center + Vector3(shift + side * 2.4, 0.72, 12.8), Color("#6f8186"))


func _park(center: Vector3, has_venue: bool) -> void:
	_box(Vector3(23, 0.018, 23), center + Vector3.UP * 0.102, Color("#668a6d"))
	for offset in [Vector3(-8, 0, -7), Vector3(8, 0, -7), Vector3(-8, 0, 7), Vector3(8, 0, 7)]:
		_solid(Vector3(0.65, 3.4, 0.65), center + offset + Vector3.UP * 1.7, Color("#755d4c"))
		_detail(Vector3(4.0, 3.3, 4.0), center + offset + Vector3.UP * 3.5, Color("#437664"))
	for side in [-1.0, 1.0]:
		for index in 7:
			if has_venue and side > 0.0 and abs(index - 3) < 2:
				continue
			_detail(Vector3(1.31, 0.60, 1.03), center + Vector3((index - 3) * 1.65, 0.39, side * 10.8), Color("#527455"))
			_detail(Vector3(0.25, 0.26, 0.24), center + Vector3((index - 3) * 1.43, 0.21, side * 9.68),
				Color("#d49983") if index % 2 == 0 else Color("#e6c785"))


func _street_furniture(center: Vector3, x: int, z: int) -> void:
	var corner := center + Vector3(-13.4, 0, -13.4)
	var steel := Color("#465f65")
	_detail(Vector3(0.17, 5.6, 0.17), corner + Vector3.UP * 2.8, steel)
	for level in [3.75, 5.45]:
		_detail(Vector3(1.55, 0.13, 0.24), corner + Vector3(-0.66, level, 0), steel)
		_detail(Vector3(0.45, 0.13, 0.26), corner + Vector3(-1.22, level - 0.11, 0), Color("#f3d39c"))
	var tree := center + Vector3(12.5, 0, -11.4)
	_detail(Vector3(0.30, 2.7, 0.30), tree + Vector3.UP * 1.45, Color("#715d4a"))
	_detail(Vector3(2.38, 1.9, 2.24), tree + Vector3.UP * 3.07, Color("#4d785c"))
	_detail(Vector3(1.57, 1.36, 1.91), tree + Vector3(-0.62, 3.67, 0.25), Color("#618764"))
	for index in 3:
		_detail(Vector3(0.80, 0.39, 0.76), tree + Vector3((index - 1) * 0.58, 0.30, -1.21), Color("#527455"))
	var bench := center + Vector3(-9, 0, -13.15)
	_detail(Vector3(2.2, 0.13, 0.52), bench + Vector3.UP * 0.51, Color("#906a50"))
	_detail(Vector3(2.2, 0.40, 0.10), bench + Vector3(0, 0.77, 0.23), Color("#906a50"))
	for side in [-0.8, 0.8]:
		_detail(Vector3(0.11, 0.48, 0.35), bench + Vector3(side, 0.24, 0), steel)
	_detail(Vector3(0.47, 0.83, 0.49), bench + Vector3(2.0, 0.42, 0), Color("#527c66"))
	_detail(Vector3(0.47, 0.83, 0.49), bench + Vector3(2.62, 0.42, 0), Color("#467581"))
	_detail(Vector3(0.28, 0.52, 0.27), corner + Vector3(1.0, 0.26, 1.1), Color("#b35750"))
	_detail(Vector3(0.11, 1.02, 0.11), corner + Vector3(3.0, 0.51, 0.13), steel)
	_detail(Vector3(0.26, 0.32, 0.22), corner + Vector3(3.0, 1.17, 0.13), Color("#a1bcb6"))
	for index in 3:
		_detail(Vector3(0.21, 0.68, 0.21), corner + Vector3(1.0 + index * 1.25, 0.34, -0.55), Color("#969e95"))
	for stripe in 6:
		var offset := (stripe - 2.5) * 1.35
		_detail(Vector3(0.67, 0.014, 2.8), center + Vector3(-20.0 + offset, 0.017, -13.8), Color("#e4dcc2"))
		_detail(Vector3(2.8, 0.014, 0.67), center + Vector3(-13.8, 0.017, -20.0 + offset), Color("#e4dcc2"))
	if posmod(x + z, 3) == 0:
		var cafe := center + Vector3(-12.2, 0, 7.5)
		_detail(Vector3(0.13, 2.4, 0.13), cafe + Vector3.UP * 1.2, steel)
		_detail(Vector3(2.35, 0.16, 2.1), cafe + Vector3.UP * 2.33, Color("#bc775f"))
		_detail(Vector3(1.0, 0.11, 0.80), cafe + Vector3.UP * 0.84, Color("#ab896d"))
		for side in [-1.0, 1.0]:
			_detail(Vector3(0.50, 0.52, 0.55), cafe + Vector3(0, 0.26, side * 0.73), steel)
		_detail(Vector3(0.82, 0.54, 0.86), cafe + Vector3(0, 0.27, 2.0), Color("#638f72"))
	if posmod(x - z, 5) == 0:
		var kiosk := center + Vector3(7.2, 0, -12.3)
		_detail(Vector3(1.72, 2.15, 1.34), kiosk + Vector3.UP * 1.075, Color("#647d7d"))
		_detail(Vector3(1.95, 0.26, 1.58), kiosk + Vector3.UP * 2.2, Color("#d6af74"))
		_detail(Vector3(1.35, 0.75, 0.045), kiosk + Vector3(0, 1.37, -0.69), Color("#ead19e"))
		_detail(Vector3(3.2, 1.28, 0.18), center + Vector3(8, 4.5, -11.2), Color("#ddac70"))


func _bus_stop(at: Vector3) -> void:
	_detail(Vector3(5.25, 0.19, 1.77), at + Vector3.UP * 2.65, Color("#356877"))
	for side in [-2.4, 2.4]:
		_detail(Vector3(0.13, 2.62, 0.13), at + Vector3(side, 1.31, 0.66), Color("#53686c"))
	_detail(Vector3(4.9, 1.24, 0.12), at + Vector3(0, 1.69, 0.72), Color("#85a9b0"))
	_detail(Vector3(3.6, 0.15, 0.48), at + Vector3(0, 0.49, 0.34), Color("#906a50"))
	_detail(Vector3(0.69, 0.86, 0.12), at + Vector3(-2.08, 1.68, 0.61), Color("#eee3bb"))
	_sign("BUS STOP", at + Vector3(0, 2.88, 0))


func _beacon_tower(center: Vector3) -> void:
	_solid(Vector3(16, 56, 16), center + Vector3.UP * 28, Color("#427c90"))
	_solid(Vector3(19, 4.5, 19), center + Vector3.UP * 58.25, Color("#a4bfbe"))
	_solid(Vector3(10, 9, 10), center + Vector3.UP * 65.0, Color("#417486"))
	_solid(Vector3(1.2, 16, 1.2), center + Vector3.UP * 77.5, Color("#c5c9c0"))
	_box(Vector3(1.9, 1.9, 1.9), center + Vector3.UP * 86.0, Color("#e58859"))
	for row in range(2, 16):
		var y := row * 3.4
		_box(Vector3(16.08, 0.54, 16.08), center + Vector3.UP * y, Color("#80a7ae"))
	_sign("BEACON TOWER", center + Vector3(0, 3.25, 9.0))


func _box(size: Vector3, at: Vector3, color: Color) -> void:
	if not _box_batches.has(color):
		_box_batches[color] = []
	_box_batches[color].append(Transform3D(Basis.from_scale(size), at))


func _draw_boxes() -> void:
	for color: Color in _box_batches:
		_draw_batch(color, _box_batches[color])
	for sector: Vector2i in _detail_batches:
		var colors: Dictionary = _detail_batches[sector]
		for color: Color in colors:
			_draw_batch(color, colors[color], 230.0)
	_box_batches.clear()
	_detail_batches.clear()


func _detail(size: Vector3, at: Vector3, color: Color) -> void:
	var sector := Vector2i(floori(at.x / 80.0), floori(at.z / 80.0))
	if not _detail_batches.has(sector):
		_detail_batches[sector] = {}
	var colors: Dictionary = _detail_batches[sector]
	if not colors.has(color):
		colors[color] = []
	colors[color].append(Transform3D(Basis.from_scale(size), at))


func _draw_batch(color: Color, transforms: Array, far_limit: float = 0.0) -> void:
	var material: Material
	if color == Color("#668a6d"):
		var grass := ShaderMaterial.new()
		grass.shader = Grass
		material = grass
	elif color == Color("#36586b") or color == Color("#789b9c"):
		var glass := ShaderMaterial.new()
		glass.shader = Glass
		glass.set_shader_parameter("tint", color)
		material = glass
	else:
		var paint := StandardMaterial3D.new()
		paint.albedo_color = color
		paint.roughness = 0.72
		material = paint
	var leaf := color == Color("#437664") or color == Color("#4d785c") or color == Color("#618764") or color == Color("#527455")
	var mesh: PrimitiveMesh = BoxMesh.new()
	if leaf:
		var foliage := SphereMesh.new()
		foliage.radial_segments = 8
		foliage.rings = 4
		mesh = foliage
	mesh.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for index in transforms.size():
		batch.set_instance_transform(index, transforms[index])
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = batch
	visual.visibility_range_end = far_limit
	if far_limit > 0.0 and not leaf:
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)


func _solid(size: Vector3, at: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	body.position = at
	add_child(body)
	_box(size, at, color)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	if size.y >= 28.0:
		var occluder := OccluderInstance3D.new()
		var bounds := BoxOccluder3D.new()
		bounds.size = size - Vector3(0.5, 0.6, 0.5)
		occluder.occluder = bounds
		body.add_child(occluder)
	return body


func _sign(title: String, at: Vector3) -> void:
	var sign := Label3D.new()
	sign.text = title
	sign.position = at
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 42
	sign.pixel_size = 0.012
	sign.modulate = Color("#d8ffef")
	add_child(sign)
