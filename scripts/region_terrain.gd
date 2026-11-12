extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const Surface = preload("res://scripts/road_surface.gd")
const CITY_DISTANCE := 2400.0
const RIVER_X := 1330.0
const TERRAIN_STEP := 10.0


static func height_at(x: float, z: float) -> float:
	var rural := smoothstep(18.0, 105.0, absf(z))
	var ridge := exp(-pow((x - 1810.0) / 290.0, 2.0)) * 35.0
	var hills := 14.0 + sin(x * 0.014 + z * 0.011) * 12.0 + cos(z * 0.023) * 8.0
	var river := 1.0 - smoothstep(22.0, 76.0, absf(x - river_center(z)))
	var end_fade := smoothstep(160.0, 260.0, x) * (1.0 - smoothstep(2140.0, 2240.0, x))
	return (rural * (hills + ridge) * (1.0 - river) - river * 5.8) * end_fade


static func river_center(z: float) -> float:
	return RIVER_X + sin(z * 0.010) * 48.0


static func mesh_height(x: float, z: float) -> float:
	var x0 := floorf(x / TERRAIN_STEP) * TERRAIN_STEP
	var z0 := floorf(z / TERRAIN_STEP) * TERRAIN_STEP
	var u := (x - x0) / TERRAIN_STEP
	var v := (z - z0) / TERRAIN_STEP
	var a := height_at(x0, z0)
	var c := height_at(x0 + TERRAIN_STEP, z0 + TERRAIN_STEP)
	if u >= v:
		return a * (1.0 - u) + height_at(x0 + TERRAIN_STEP, z0) * (u - v) + c * v - 0.10
	return a * (1.0 - v) + c * u + height_at(x0, z0 + TERRAIN_STEP) * (v - u) - 0.10


func build() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for column in 208:
		var x := 160.0 + column * TERRAIN_STEP
		for row in 64:
			var z := -320.0 + row * TERRAIN_STEP
			var points := [Vector2(x, z), Vector2(x + TERRAIN_STEP, z),
				Vector2(x + TERRAIN_STEP, z + TERRAIN_STEP), Vector2(x, z + TERRAIN_STEP)]
			for index in [0, 1, 2, 0, 2, 3]:
				var point: Vector2 = points[index]
				var y := height_at(point.x, point.y)
				var color := Color("#79926c").lerp(Color("#667b68"), clampf(y / 62.0, 0.0, 1.0))
				if y < -1.2:
					color = Color("#8d9980")
				surface.set_color(color)
				surface.add_vertex(Vector3(point.x, y - 0.10, point.y))
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	surface.set_material(material)
	var terrain := MeshInstance3D.new()
	terrain.mesh = surface.commit()
	add_child(terrain)
	var body := StaticBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	Surface.set_surface(body, Surface.Type.GRASS)
	add_child(body)
	var collider := CollisionShape3D.new()
	collider.shape = terrain.mesh.create_trimesh_shape()
	body.add_child(collider)
	_build_highway()
	_build_overpass()
	_build_river()
	_build_forests()


func _build_highway() -> void:
	var span := CITY_DISTANCE - 320.0
	Shapes.box(self, Vector3(span, 0.28, 19.4), Vector3(CITY_DISTANCE * 0.5, -0.12, 0), Color("#354450"))
	var bridge := StaticBody3D.new()
	bridge.collision_layer = 8
	bridge.collision_mask = 0
	Surface.set_surface(bridge, Surface.Type.ASPHALT)
	add_child(bridge)
	var deck := CollisionShape3D.new()
	deck.shape = Surface.bevel(20.6, span, -0.27, 0.02, 0.60)
	deck.position = Vector3(CITY_DISTANCE * 0.5, 0, 0)
	deck.rotation.y = PI * 0.5
	bridge.add_child(deck)
	var lane_marks: Array[Transform3D] = []
	for index in 245:
		for z in [-4.85, 4.85]:
			lane_marks.append(Transform3D(Basis.from_scale(Vector3(4.5, 0.018, 0.13)), Vector3(168.0 + index * 8.45, 0.03, z)))
	_batch(BoxMesh.new(), lane_marks, Color("#e4dcc2"))
	Shapes.box(self, Vector3(span, 0.24, 0.34), Vector3(CITY_DISTANCE * 0.5, 0.14, 0), Color("#c0bbb0"))
	for side in [-1.0, 1.0]:
		Shapes.box(self, Vector3(180, 0.28, 0.23), Vector3(RIVER_X, 0.77, side * 9.45), Color("#cad1d0"))
		Shapes.box(self, Vector3(140, 1.6, 0.25), Vector3(400, 0.79, side * 9.55), Color("#7b9092"))
		var trail := SurfaceTool.new()
		trail.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in 208:
			var x := 160.0 + index * TERRAIN_STEP
			var next_x := x + TERRAIN_STEP
			var z: float = side * (54.0 + sin(x * 0.013) * 19.0)
			var next_z: float = side * (54.0 + sin(next_x * 0.013) * 19.0)
			for point: Vector2 in [Vector2(x, z - 2.3), Vector2(next_x, next_z - 2.3), Vector2(next_x, next_z + 2.3),
					Vector2(x, z - 2.3), Vector2(next_x, next_z + 2.3), Vector2(x, z + 2.3)]:
				trail.add_vertex(Vector3(point.x, mesh_height(point.x, point.y) + 0.045, point.y))
		trail.generate_normals()
		var dirt_mesh := trail.commit()
		Shapes.attach(self, dirt_mesh, Vector3.ZERO, Color("#a29172"))
		var dirt := StaticBody3D.new()
		dirt.collision_layer = 8
		dirt.collision_mask = 0
		Surface.set_surface(dirt, Surface.Type.DIRT)
		add_child(dirt)
		var dirt_shape := CollisionShape3D.new()
		dirt_shape.shape = dirt_mesh.create_trimesh_shape()
		dirt.add_child(dirt_shape)


func _build_river() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 32:
		var z := -320.0 + index * 20.0
		var next_z := z + 20.0
		var x := river_center(z)
		var next_x := river_center(next_z)
		for vertex: Vector3 in [Vector3(x - 34, -2.6, z), Vector3(x + 34, -2.6, z), Vector3(next_x + 34, -2.6, next_z),
				Vector3(x - 34, -2.6, z), Vector3(next_x + 34, -2.6, next_z), Vector3(next_x - 34, -2.6, next_z)]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	Shapes.attach(self, surface.commit(), Vector3.ZERO, Color("#4c879c"))


func _build_overpass() -> void:
	var x := 1735.0
	_deck_section(Vector3(x, 5.8, -18.0), Vector3(x, 5.8, 18.0), 8.4)
	for side in [-1.0, 1.0]:
		var end_z: float = side * 44.0
		_deck_section(Vector3(x, 5.8, side * 18.0), Vector3(x, height_at(x, end_z) + 0.18, end_z), 8.4)
		Shapes.box(self, Vector3(1.28, 5.3, 0.9), Vector3(x - 3.3, 2.65, side * 13.5), Color("#a5a79e"))
		Shapes.box(self, Vector3(1.28, 5.3, 0.9), Vector3(x + 3.3, 2.65, side * 13.5), Color("#a5a79e"))


func _deck_section(start: Vector3, end: Vector3, width: float) -> void:
	var mid := (start + end) * 0.5
	var direction := end - start
	var size := Vector3(width, 0.38, direction.length() + 0.20)
	var body := StaticBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	body.position = mid
	add_child(body)
	body.basis = Basis.looking_at(direction)
	Shapes.box(body, size, Vector3.ZERO, Color("#506066"))
	Shapes.box(body, Vector3(0.13, 0.025, size.z), Vector3(0, 0.205, 0), Color("#e6dba6"))
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)


func _build_forests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1629
	var pine := CylinderMesh.new()
	pine.top_radius = 0.0
	pine.bottom_radius = 0.5
	pine.height = 1.0
	pine.radial_segments = 7
	var leafy := SphereMesh.new()
	leafy.radial_segments = 8
	leafy.rings = 4
	for sector in 12:
		var cones: Array[Transform3D] = []
		var crowns: Array[Transform3D] = []
		var trunks: Array[Transform3D] = []
		var shrubs: Array[Transform3D] = []
		var logs: Array[Transform3D] = []
		var stones: Array[Transform3D] = []
		for index in 280:
			var x := 192.0 + sector * 169.0 + rng.randf_range(0, 168)
			var z := rng.randf_range(82.0, 310.0) * (-1.0 if index % 2 == 0 else 1.0)
			if absf(x - river_center(z)) < 48.0:
				continue
			var y := mesh_height(x, z)
			var height := rng.randf_range(4.8, 11.0)
			var transforms := cones if index % 3 else crowns
			transforms.append(Transform3D(Basis.from_scale(Vector3(height * 0.48, height * 0.79, height * 0.48)),
				Vector3(x, y + height * 0.64, z)))
			trunks.append(Transform3D(Basis.from_scale(Vector3(0.33, height * 0.53, 0.33)), Vector3(x, y + height * 0.25, z)))
			for offset in [Vector2(1.7, -1.8), Vector2(-2.0, 2.4)]:
				var px: float = x + offset.x
				var pz: float = z + offset.y
				shrubs.append(Transform3D(Basis.from_scale(Vector3(1.4, 0.67, 1.3)),
					Vector3(px, mesh_height(px, pz) + 0.28, pz)))
			if index % 6 == 0:
				var orientation := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
				logs.append(Transform3D(orientation.scaled(Vector3(2.4, 0.24, 0.30)), Vector3(x - 1.4, mesh_height(x - 1.4, z) + 0.11, z)))
				stones.append(Transform3D(Basis.from_scale(Vector3(1.04, 0.55, 0.84)), Vector3(x + 1.4, mesh_height(x + 1.4, z) + 0.22, z)))
		_batch(pine, cones, Color("#325f53"), 640.0)
		_batch(leafy, crowns, Color("#4c7657"), 640.0)
		_batch(BoxMesh.new(), trunks, Color("#64594a"), 250.0)
		_batch(leafy, shrubs, Color("#587649"), 145.0)
		_batch(BoxMesh.new(), logs, Color("#6c5542"), 115.0)
		_batch(leafy, stones, Color("#83877a"), 128.0)


func _batch(mesh: PrimitiveMesh, transforms: Array[Transform3D], color: Color, far_limit: float = 0.0) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for index in transforms.size():
		batch.set_instance_transform(index, transforms[index])
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = batch
	visual.material_override = material
	visual.visibility_range_end = far_limit
	add_child(visual)
