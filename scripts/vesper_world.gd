extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const Globe = preload("res://scripts/vesper_globe.gdshader")
const PAD_Y := 0.82
const PAD_RADIUS := 8.0
const AQUA := Color("#75e5e2")
const AMBER := Color("#ffba72")
const STEEL := Color("#465665")

var cruise := Node3D.new()
var surface := Node3D.new()
var ship := Node3D.new()
var flame: MeshInstance3D
var shadow: MeshInstance3D
var _markers: Array[MeshInstance3D] = []


func _ready() -> void:
	add_child(cruise)
	add_child(surface)
	add_child(ship)
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-47, -32, 0)
	light.light_color = Color("#ffd7bb")
	light.light_energy = 1.0
	_build_ship()
	_build_orbit()
	_build_base()
	surface.hide()


func set_landing(landing: bool) -> void:
	cruise.visible = not landing
	surface.visible = landing


func _build_ship() -> void:
	_cylinder(ship, 0.82, 1.18, 5.3, Vector3.UP * 3.95, Color("#e5e1d8"))
	_cylinder(ship, 0.04, 0.83, 2.4, Vector3.UP * 7.8, Color("#f4efea"))
	_cylinder(ship, 0.91, 0.95, 0.62, Vector3.UP * 5.75, Color("#cf6b50"))
	_cylinder(ship, 0.63, 0.82, 1.1, Vector3.UP * 1.15, STEEL)
	for side in 4:
		var azimuth := side * TAU / 4.0
		var radial := Vector3(cos(azimuth), 0, sin(azimuth))
		var strut := Shapes.box(ship, Vector3(0.26, 1.57, 0.29), radial * 1.26 + Vector3.UP * 0.90, STEEL)
		strut.rotation.z = -0.42 if side == 0 else (0.42 if side == 2 else 0.0)
		strut.rotation.x = 0.42 if side == 1 else (-0.42 if side == 3 else 0.0)
		Shapes.box(ship, Vector3(0.64, 0.16, 0.57), radial * 1.55 + Vector3.UP * 0.11, Color("#8796a1"))
	Shapes.box(ship, Vector3(0.93, 0.56, 0.08), Vector3(0, 6.34, 0.78), AQUA).material_override = _glow(AQUA)
	flame = _cylinder(ship, 0.56, 0.0, 3.8, Vector3.DOWN * 1.18, AMBER)
	flame.material_override = _glow(AMBER)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_orbit() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 650.0
	sphere.height = 1300.0
	sphere.radial_segments = 72
	sphere.rings = 32
	var globe := Shapes.attach(cruise, sphere, Vector3(0, -470, -3900), Color.WHITE)
	var shader := ShaderMaterial.new()
	shader.shader = Globe
	globe.material_override = shader
	globe.rotation.z = -0.24
	var rng := RandomNumberGenerator.new()
	rng.seed = 229
	var stars := MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	var point := SphereMesh.new()
	point.radial_segments = 5
	point.rings = 2
	point.material = _glow(Color("#ccdff7"))
	stars.mesh = point
	stars.instance_count = 480
	for index in stars.instance_count:
		var at := Vector3(rng.randf_range(-2200, 2200), rng.randf_range(-900, 1300), rng.randf_range(-5100, -3700))
		stars.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.8, 3.2)), at))
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = stars
	cruise.add_child(batch)


static func ground_height(x: float, z: float) -> float:
	var blend := smoothstep(21.0, 130.0, Vector2(x, z).length())
	return blend * (sin(x * 0.059 + z * 0.023) * 5.7 + cos(z * 0.076) * 4.2 - 1.4)


static func surface_height(x: float, z: float) -> float:
	if absf(z + 29.0) < 7.3 and (absf(x + 30.0) < 9.8 or absf(x - 28.0) < 9.8):
		return 5.60
	return ground_height(x, z)


func _build_base() -> void:
	var terrain := SurfaceTool.new()
	terrain.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-24, 24):
		for z in range(-24, 24):
			for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var px := (x + offset.x) * 7.0
				var pz := (z + offset.y) * 7.0
				var py := ground_height(px, pz)
				terrain.set_color(Color("#53404a").lerp(Color("#b27363"), clampf((py + 11.0) / 22.0, 0, 1)))
				terrain.add_vertex(Vector3(px, py, pz))
	terrain.generate_normals()
	var stone := StandardMaterial3D.new()
	stone.vertex_color_use_as_albedo = true
	terrain.set_material(stone)
	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.mesh = terrain.commit()
	surface.add_child(terrain_mesh)
	_cylinder(surface, PAD_RADIUS, PAD_RADIUS + 0.58, PAD_Y, Vector3.UP * PAD_Y * 0.5, Color("#29384b"))
	for angle in 24:
		var a := angle * TAU / 24.0
		var rim := Vector3(cos(a), 0, sin(a))
		var lamp := Shapes.box(surface, Vector3(0.52, 0.10, 0.25), rim * 7.24 + Vector3.UP * (PAD_Y + 0.05), AQUA)
		lamp.rotation.y = -a + PI * 0.5
		lamp.material_override = _glow(AQUA)
		_markers.append(lamp)
	for offset in [-2.65, 2.65]:
		Shapes.box(surface, Vector3(0.28, 0.021, 5.0), Vector3(offset, PAD_Y + 0.018, 0), Color("#e8ceab"))
	Shapes.box(surface, Vector3(5.45, 0.021, 0.30), Vector3(0, PAD_Y + 0.018, 0), Color("#e8ceab"))
	for x in [-30.0, 28.0]:
		Shapes.box(surface, Vector3(18, 5.7, 13), Vector3(x, 2.4, -29), STEEL)
		Shapes.box(surface, Vector3(18.4, 0.43, 13.4), Vector3(x, 5.38, -29), Color("#a78376"))
		for win in range(-2, 3):
			Shapes.box(surface, Vector3(2.1, 1.03, 0.075), Vector3(x + win * 2.65, 3.55, -22.46), AQUA).material_override = _glow(AQUA.darkened(0.23))
		var deck := Shapes.box(surface, Vector3(14, 0.3, 7.5), Vector3(x, 3.4, -45), Color("#274559"))
		deck.rotation.x = -0.32
		Shapes.box(surface, Vector3(0.62, 4.9, 0.62), Vector3(x, 1.9, -45), STEEL)
	Shapes.box(surface, Vector3(0.47, 15.0, 0.47), Vector3(-26, 7.0, -17), STEEL)
	Shapes.box(surface, Vector3(3.2, 0.28, 0.30), Vector3(-26, 13.7, -17), AMBER).material_override = _glow(AMBER)
	shadow = _cylinder(surface, 2.1, 2.1, 0.009, Vector3(0, 0.025, 0), Color("#252d3a"))
	var shadow_mat := _glow(Color(0.025, 0.038, 0.05, 0.35))
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.material_override = shadow_mat


func update_pad(ship_at: Vector3, aligned: bool) -> void:
	var y := PAD_Y if Vector2(ship_at.x, ship_at.z).length() < PAD_RADIUS else surface_height(ship_at.x, ship_at.z)
	shadow.position = Vector3(ship_at.x, y + 0.024, ship_at.z)
	var paint := _glow(Color("#a4fcae") if aligned else AQUA)
	for marker in _markers:
		marker.material_override = paint


func asteroid(radius: float, variant: int) -> MeshInstance3D:
	var stone := SphereMesh.new()
	stone.radial_segments = 8
	stone.rings = 4
	stone.radius = radius
	stone.height = radius * 2.0
	var rock := Shapes.attach(cruise, stone, Vector3.ZERO, [Color("#877a8b"), Color("#ad806f"), Color("#68788d")][variant])
	rock.scale = Vector3(1.0, 0.76, 1.09)
	return rock


func _cylinder(parent: Node3D, top: float, bottom: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	return Shapes.attach(parent, mesh, at, color)


func _glow(color: Color) -> StandardMaterial3D:
	if not _glow_cache.has(color):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		_glow_cache[color] = mat
	return _glow_cache[color]


var _glow_cache: Dictionary = {}
