extends RefCounted

const PLAYER_PAINTS: Array[Color] = [Color("#1ee5d4"), Color("#ff9953"), Color("#ac83ff")]
const TIRE: Color = Color("#171f2b")
const GLASS: Color = Color("#29485c")
const CHROME: Color = Color("#92a3a9")
const LAMP: Color = Color("#fff0bb")
const TAIL: Color = Color("#ff4e52")

static var materials: Dictionary = {}


static func create(parent: Node3D, kind: int, color: Color, trim: int = -1) -> Node3D:
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
			if trim >= 0:
				var stripe_color := Color("#e5ffff") if trim != 2 else Color("#402d64")
				box(visual, Vector3(0.18, 0.015, 0.75), Vector3(-0.25, 0.855, -1.33), stripe_color)
				box(visual, Vector3(0.18, 0.015, 1.04), Vector3(-0.25, 1.423, 0.12), stripe_color)
				box(visual, Vector3(1.62, 0.11, 0.29), Vector3(0, 1.03, 1.58), color)
				for x in [-0.53, 0.53]:
					box(visual, Vector3(0.12, 0.23, 0.18), Vector3(x, 0.93, 1.60), TIRE)
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


static func _cylinder(parent: Node3D, radius: float, width: float, sides: int, position: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mesh.radial_segments = sides
	var part := attach(parent, mesh, position, color)
	part.rotation_degrees.z = 90.0


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

