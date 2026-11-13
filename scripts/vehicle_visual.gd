extends RefCounted

const Catalog = preload("res://scripts/garage_catalog.gd")
const PLAYER_LENGTHS: Array[float] = [3.62, 3.86, 3.91, 4.02]
const TIRE: Color = Color("#171f2b")
const GLASS: Color = Color("#29485c")
const CHROME: Color = Color("#92a3a9")
const LAMP: Color = Color("#fff0bb")
const TAIL: Color = Color("#ff4e52")

static var materials: Dictionary = {}


static func create(parent: Node3D, kind: int, color: Color) -> Node3D:
	var visual := Node3D.new()
	visual.name = "Visual"
	parent.add_child(visual)
	var lengths: Array[float] = [3.7, 5.0, 6.2]
	var length := lengths[kind]
	box(visual, Vector3(1.82, 0.24, length - 0.15), Vector3(0, 0.38, 0), TIRE)
	match kind:
		0:
			_shell(visual, Vector3(1.84, 0.42, length), Vector3(1.68, 0.0, length - 0.18), Vector3(0, 0.64, 0), color)
			_shell(visual, Vector3(1.62, 0.52, 1.94), Vector3(1.36, 0.0, 1.12), Vector3(0, 1.07, 0.12), GLASS)
			box(visual, Vector3(1.36, 0.10, 1.13), Vector3(0, 1.37, 0.12), color)
			for side in [-1.0, 1.0]:
				box(visual, Vector3(0.23, 0.13, 0.24), Vector3(side * 0.9, 1.0, -0.38), color)
		1:
			box(visual, Vector3(1.82, 0.84, length), Vector3(0, 0.86, 0), color)
			_shell(visual, Vector3(1.80, 0.91, length - 0.14), Vector3(1.63, 0.0, length - 0.5), Vector3(0, 1.72, 0.08), color)
			box(visual, Vector3(1.52, 0.49, 0.06), Vector3(0, 1.65, -2.36), GLASS)
			box(visual, Vector3(1.46, 0.34, 0.07), Vector3(0, 1.78, 2.43), GLASS)
			for side in [-1.0, 1.0]:
				for row in range(4):
					box(visual, Vector3(0.07, 0.39, 0.91), Vector3(side * 0.88, 1.68, -1.51 + row * 1.05), GLASS)
				box(visual, Vector3(0.024, 0.11, 4.85), Vector3(side * 0.91, 1.13, 0), LAMP)
		2:
			box(visual, Vector3(1.82, 0.77, 2.03), Vector3(0, 0.84, -2.04), color)
			_shell(visual, Vector3(1.76, 0.94, 1.87), Vector3(1.55, 0.0, 1.52), Vector3(0, 1.63, -1.99), color)
			box(visual, Vector3(1.51, 0.47, 0.08), Vector3(0, 1.67, -2.86), GLASS)
			box(visual, Vector3(1.86, 1.99, 3.98), Vector3(0, 1.57, 1.09), color.lightened(0.26))
			for side in [-1.0, 1.0]:
				box(visual, Vector3(0.04, 0.28, 3.99), Vector3(side * 0.94, 1.52, 1.09), color.darkened(0.35))
			box(visual, Vector3(0.04, 1.91, 0.04), Vector3(0, 1.57, 3.09), CHROME)
	for side in [-1.0, 1.0]:
		box(visual, Vector3(0.36, 0.16, 0.1), Vector3(side * 0.56, 0.65, length / 2.0), TAIL)
		box(visual, Vector3(0.37, 0.16, 0.1), Vector3(side * 0.57, 0.64, -length / 2.0), LAMP)
		for axle in [-1.0, 1.0]:
			_wheel(visual, Vector3(side * 0.89, 0.37, axle * length * 0.33), side)
		if kind == 2:
			_wheel(visual, Vector3(side * 0.89, 0.37, 1.21), side)
	box(visual, Vector3(0.45, 0.13, 0.08), Vector3(0, 0.54, length / 2.0 + 0.02), CHROME)
	return visual


static func find_wheels(visual: Node3D) -> Array[Node3D]:
	var wheels: Array[Node3D] = []
	for part in visual.get_children():
		if part.is_in_group(&"vehicle_wheel"):
			wheels.append(part)
	return wheels


static func _wheel(parent: Node3D, center: Vector3, side: float) -> void:
	var axle := Node3D.new()
	axle.position = center
	axle.add_to_group(&"vehicle_wheel")
	parent.add_child(axle)
	_cylinder(axle, 0.36, 0.28, 12, Vector3.ZERO, TIRE)
	_cylinder(axle, 0.23, 0.03, 8, Vector3(side * 0.15, 0, 0), CHROME)
	box(axle, Vector3(0.02, 0.24, 0.056), Vector3(side * 0.17, 0, 0), TIRE)


static func _cylinder(parent: Node3D, radius: float, width: float, sides: int, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mesh.radial_segments = sides
	var part := attach(parent, mesh, position, color)
	part.rotation_degrees.z = 90.0
	return part


static func _shell(parent: Node3D, lower: Vector3, upper: Vector3, position: Vector3, color: Color) -> void:
	var x := lower.x * 0.5
	var z := lower.z * 0.5
	var tx := upper.x * 0.5
	var tz := upper.z * 0.5
	var h := lower.y * 0.5
	var corners: Array[Vector3] = [
		Vector3(-x, -h, -z), Vector3(x, -h, -z), Vector3(x, -h, z), Vector3(-x, -h, z),
		Vector3(-tx, h, -tz), Vector3(tx, h, -tz), Vector3(tx, h, tz), Vector3(-tx, h, tz),
	]
	var faces := [0, 2, 3, 0, 1, 2, 4, 7, 6, 4, 6, 5,
		0, 4, 5, 0, 5, 1, 1, 5, 6, 1, 6, 2, 2, 6, 7, 2, 7, 3, 3, 7, 4, 3, 4, 0]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for index in range(0, faces.size(), 3):
		surface.add_vertex(corners[faces[index]])
		surface.add_vertex(corners[faces[index + 2]])
		surface.add_vertex(corners[faces[index + 1]])
	surface.generate_normals()
	attach(parent, surface.commit(), position, color)


static func box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return attach(parent, mesh, position, color)


static func attach(parent: Node3D, mesh: Mesh, position: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = position
	if not materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.72
		materials[color] = material
	part.material_override = materials[color]
	parent.add_child(part)
	return part



static func create_player(parent: Node3D, model: int) -> Node3D:
	var car := Node3D.new()
	car.name = "Visual"
	parent.add_child(car)
	var paint := Catalog.PAINTS[model]
	var length := PLAYER_LENGTHS[model]
	var width := [1.73, 1.85, 1.91, 1.96][model] as float
	var roof_height := [1.35, 1.27, 1.16, 1.10][model] as float
	var shoulder := [0.80, 0.76, 0.70, 0.67][model] as float
	var cabin_z := [0.04, 0.30, 0.13, 0.06][model] as float
	var cabin_length := [1.99, 1.73, 1.61, 1.52][model] as float
	var nose := -length * 0.5
	var tail := length * 0.5
	var dark := Color("#121d2a")

	box(car, Vector3(width - 0.16, 0.18, length - 0.10), Vector3(0, 0.31, 0), dark)
	_shell(car, Vector3(width, shoulder - 0.40, length), Vector3(width - 0.13, 0, length - 0.30),
		Vector3(0, (shoulder + 0.40) * 0.5, 0), paint)
	_shell(car, Vector3(width - 0.24, roof_height - shoulder, cabin_length),
		Vector3(width - 0.55, 0, cabin_length * 0.64), Vector3(0, (roof_height + shoulder) * 0.5, cabin_z), GLASS)
	box(car, Vector3(width - 0.56, 0.075, cabin_length * 0.64),
		Vector3(0, roof_height + 0.025, cabin_z), dark if model == 3 else paint)

	var grille_width := 0.67 if model < 2 else 1.16
	box(car, Vector3(grille_width, 0.18, 0.09), Vector3(0, 0.49, nose + 0.025), dark)
	box(car, Vector3(0.39, 0.11, 0.06), Vector3(0, 0.48, tail + 0.032), CHROME.darkened(0.12))
	for side in [-1.0, 1.0]:
		var x: float = side * width * 0.32
		var headlight := box(car, Vector3(0.41, 0.07 if model >= 2 else 0.13, 0.15),
			Vector3(x, shoulder - 0.08, nose + 0.025), LAMP)
		headlight.rotation.y = side * (0.24 if model >= 2 else 0.08)
		_light_finish(headlight, Color("#dcf6ff"), 0.50)
		_light_finish(box(car, Vector3(0.39, 0.065, 0.08),
			Vector3(x, shoulder - 0.07, tail - 0.008), TAIL), TAIL, 0.48)
		box(car, Vector3(0.18, 0.105, 0.21), Vector3(side * (width * 0.5 + 0.02), shoulder + 0.15, cabin_z - 0.57), paint)
		box(car, Vector3(0.045, 0.085, 1.18), Vector3(side * width * 0.50, 0.40, 0.02), dark)
		for axle in [-1.0, 1.0]:
			var wheel_center := Vector3(side * (width * 0.5 - 0.035), 0.36, axle * length * 0.33)
			_player_wheel(car, wheel_center, side, model)
		var exhaust := _cylinder(car, 0.073, 0.12, 12, Vector3(side * 0.51, 0.37, tail - 0.015), CHROME)
		exhaust.rotation = Vector3(PI * 0.5, 0, 0)
		if model >= 2:
			box(car, Vector3(0.08, 0.18, 0.40), Vector3(side * width * 0.50, shoulder - 0.08, 0.65), dark)
	match model:
		1:
			box(car, Vector3(1.38, 0.07, 0.23), Vector3(0, shoulder + 0.045, tail - 0.30), paint)
		2, 3:
			var wing_height := 0.99 if model == 2 else 1.19
			for side in [-1.0, 1.0]:
				box(car, Vector3(0.09, wing_height - shoulder, 0.16),
					Vector3(side * 0.53, (wing_height + shoulder) * 0.5, tail - 0.31), dark)
			box(car, Vector3(width - 0.10, 0.09, 0.33), Vector3(0, wing_height, tail - 0.30), dark)
			box(car, Vector3(width - 0.03, 0.075, 0.32), Vector3(0, 0.32, nose + 0.04), dark)
	if model == 3:
		for x in [-0.26, 0.26]:
			box(car, Vector3(0.16, 0.022, 0.50), Vector3(x, shoulder + 0.009, -1.15), dark)
	return car


static func _player_wheel(car: Node3D, center: Vector3, side: float, model: int) -> void:
	var wheel := Node3D.new()
	wheel.position = center
	wheel.add_to_group(&"vehicle_wheel")
	car.add_child(wheel)
	_cylinder(wheel, 0.35, 0.29, 24, Vector3.ZERO, TIRE)
	_cylinder(wheel, 0.25, 0.036, 24, Vector3(side * 0.15, 0, 0), CHROME if model < 2 else Color("#536075"))
	_cylinder(wheel, 0.19, 0.039, 20, Vector3(side * 0.16, 0, 0), Color("#202c3a"))
	for index in 5:
		var spoke := box(wheel, Vector3(0.025, 0.19, 0.038), Vector3(side * 0.186, 0, 0), CHROME)
		spoke.rotation.x = TAU * index / 5.0
		spoke.position += Vector3.UP.rotated(Vector3.RIGHT, spoke.rotation.x) * 0.10
	_cylinder(wheel, 0.066, 0.034, 12, Vector3(side * 0.18, 0, 0), Catalog.PAINTS[model])


static func create_nitro(car: Node3D, model: int) -> Node3D:
	var jets := Node3D.new()
	car.add_child(jets)
	for side in [-1.0, 1.0]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.075
		cone.height = 0.85
		var flame := attach(jets, cone, Vector3(side * 0.51, 0.37, PLAYER_LENGTHS[model] * 0.5 + 0.41), Color.WHITE)
		flame.rotation.x = PI * 0.5
		_light_finish(flame, Color("#56caff"), 2.5)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jets.hide()
	return jets


static func _light_finish(mesh: MeshInstance3D, color: Color, energy: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	mesh.material_override = material
