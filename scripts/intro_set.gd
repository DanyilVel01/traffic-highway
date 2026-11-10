extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const PARK: Vector3 = Vector3(-12.0, 0, 142.0)
const ASPHALT: Color = Color("#303b46")
const WALL: Color = Color("#465166")
const STEEL: Color = Color("#566777")
const MINT: Color = Color("#64e2cf")
const AMBER: Color = Color("#ffcf84")

var shutter: Node3D


static func street_x(z: float) -> float:
	return PARK.x * smoothstep(34.0, 66.0, z)


func build() -> void:
	var garage := Node3D.new()
	garage.position = PARK
	add_child(garage)
	_build_garage(garage)
	_build_street()


func _build_garage(garage: Node3D) -> void:
	Shapes.box(garage, Vector3(15.2, 0.22, 17.8), Vector3(0, -0.13, 0), Color("#384351"))
	Shapes.box(garage, Vector3(15.8, 0.48, 18.5), Vector3(0, 5.62, -0.08), WALL)
	Shapes.box(garage, Vector3(15.2, 5.6, 0.36), Vector3(0, 2.80, 8.75), WALL)
	for side in [-1.0, 1.0]:
		Shapes.box(garage, Vector3(0.35, 5.65, 17.7), Vector3(side * 7.53, 2.81, 0), WALL)
		Shapes.box(garage, Vector3(4.92, 5.55, 0.46), Vector3(side * 5.14, 2.76, -8.75), WALL)
		Shapes.box(garage, Vector3(0.22, 4.59, 0.65), Vector3(side * 2.69, 2.28, -8.74), STEEL)
		Shapes.box(garage, Vector3(0.13, 0.028, 7.2), Vector3(side * 1.43, 0.018, 0.5), AMBER)
	Shapes.box(garage, Vector3(5.48, 1.06, 0.54), Vector3(0, 5.03, -8.75), WALL)
	_label(garage, "BAY 07", Vector3(0, 4.99, -9.03), PI, 0.017, AMBER)
	_label(garage, "COASTAL MOTOR WORKS", Vector3(0, 3.92, 8.53), PI, 0.013, MINT)
	shutter = Node3D.new()
	shutter.position = Vector3(0, 4.52, -8.69)
	garage.add_child(shutter)
	Shapes.box(shutter, Vector3(5.30, 4.50, 0.16), Vector3(0, -2.25, 0), Color("#536472"))
	for index in range(12):
		Shapes.box(shutter, Vector3(5.33, 0.08, 0.20), Vector3(0, -0.2 - float(index) * 0.365, 0), STEEL)
	for z in [-5.6, 0.0, 5.6]:
		Shapes.box(garage, Vector3(15.35, 0.32, 0.43), Vector3(0, 5.28, z), STEEL)
		Shapes.box(garage, Vector3(3.8, 0.08, 0.19), Vector3(-1.2, 5.03, z), MINT)
	_light(garage, Vector3(-2.9, 4.5, -2.0), Color("#8bd5f0"), 1.5, 12.0)
	_light(garage, Vector3(3.8, 3.35, -0.4), AMBER, 2.4, 8.0)
	_light(garage, Vector3(2.0, 3.65, 2.4), Color("#8dbcf2"), 1.5, 7.6)
	_light(garage, Vector3(0, 4.4, 5.8), Color("#b2d6f2"), 1.65, 10.0)
	_workbench(garage)
	_map_table(garage)


func _workbench(garage: Node3D) -> void:
	Shapes.box(garage, Vector3(5.55, 1.08, 1.14), Vector3(-2.95, 0.55, 7.91), Color("#476273"))
	Shapes.box(garage, Vector3(5.68, 0.12, 1.20), Vector3(-2.95, 1.13, 7.91), Color("#9c7f65"))
	Shapes.box(garage, Vector3(4.1, 1.16, 0.12), Vector3(-2.94, 2.04, 8.48), Color("#77808d"))
	for index in range(5):
		var x := -5.08 + float(index) * 1.04
		Shapes.box(garage, Vector3(0.67, 0.07, 0.06), Vector3(x, 0.70, 7.30), MINT)
		var tool := Shapes.box(garage, Vector3(0.12, 0.45, 0.09), Vector3(x + 0.22, 2.09, 8.38), STEEL)
		tool.rotation.z = 0.28 - float(index) * 0.15
	for index in range(3):
		Shapes.box(garage, Vector3(1.22, 0.12, 4.6), Vector3(6.68, 0.47 + float(index) * 0.92, 4.25), STEEL)
		for item in range(3):
			Shapes.box(garage, Vector3(0.70, 0.48, 0.58), Vector3(6.67, 0.77 + float(index) * 0.92, 2.75 + float(item) * 1.4),
				AMBER.darkened(float(index + item) * 0.10))
	var tire := TorusMesh.new()
	tire.inner_radius = 0.29
	tire.outer_radius = 0.53
	tire.rings = 12
	tire.ring_segments = 8
	for index in range(3):
		Shapes.attach(garage, tire, Vector3(-6.25, 0.21 + float(index) * 0.24, 5.4), Color("#232a37"))


func _map_table(garage: Node3D) -> void:
	var center := Vector3(3.75, 0.0, 0.05)
	Shapes.box(garage, Vector3(1.75, 0.12, 2.38), center + Vector3(0, 1.02, 0), Color("#967456"))
	for x in [-0.72, 0.72]:
		for z in [-0.98, 0.98]:
			Shapes.box(garage, Vector3(0.12, 1.0, 0.12), center + Vector3(x, 0.51, z), STEEL)
	Shapes.box(garage, Vector3(1.27, 0.019, 1.81), center + Vector3(0, 1.091, 0), Color("#b7c6c0"))
	for index in range(3):
		var x := -0.24 + float(index) * 0.23
		var z := 0.61 - float(index) * 0.57
		var route := Shapes.box(garage, Vector3(0.08, 0.016, 0.60), center + Vector3(x, 1.109, z - 0.19), Color("#287888"))
		route.rotation.y = -0.33
		Shapes.box(garage, Vector3(0.13, 0.075, 0.13), center + Vector3(x, 1.137, z), AMBER)
	Shapes.box(garage, Vector3(0.40, 0.045, 0.29), center + Vector3(-0.64, 1.114, 0.73), Color("#243647"))


func _build_street() -> void:
	Shapes.box(self, Vector3(43.0, 0.19, 84.0), Vector3(PARK.x, -0.18, 106), Color("#6c896d"))
	Shapes.box(self, Vector3(8.4, 0.12, 68.0), Vector3(PARK.x, -0.03, 99.9), ASPHALT)
	for side in [-1.0, 1.0]:
		var edge: float = PARK.x + side * 4.62
		Shapes.box(self, Vector3(0.8, 0.20, 65.0), Vector3(edge, 0.02, 98.4), Color("#aaa9a3"))
		for index in range(4):
			var z := 77.0 + float(index) * 14.5
			var x: float = PARK.x + side * (8.4 + float(index % 2) * 1.7)
			var height := 2.7 + float((index + 1) % 3) * 0.67
			var color := Color("#808f9e").lightened(float(index) * 0.06)
			Shapes.box(self, Vector3(5.3, height, 6.2), Vector3(x, height * 0.5, z), color)
			Shapes.box(self, Vector3(5.6, 0.24, 6.46), Vector3(x, height + 0.08, z), Color("#637989"))
			for window_z in [-1.47, 1.47]:
				Shapes.box(self, Vector3(0.07, 0.92, 1.05),
					Vector3(x - side * 2.68, height * 0.60, z + window_z), Color("#355b71"))
			var pole := Vector3(edge + side * 0.46, 0, z + 3.7)
			Shapes.box(self, Vector3(0.14, 3.85, 0.14), pole + Vector3(0, 1.925, 0), STEEL)
			Shapes.box(self, Vector3(0.68, 0.14, 0.22), pole + Vector3(-side * 0.27, 3.82, 0), AMBER)
	for index in range(7):
		Shapes.box(self, Vector3(0.11, 0.027, 3.30), Vector3(PARK.x, 0.047, 72.5 + float(index) * 9.0), AMBER)
	_build_merge()
	Shapes.box(self, Vector3(2.2, 0.72, 0.13), Vector3(-18.0, 2.45, 68.0), Color("#246375"))
	_label(self, "HIGHWAY", Vector3(-18.0, 2.45, 68.08), 0, 0.008, Color.WHITE)
	for x in [-18.82, -17.18]:
		Shapes.box(self, Vector3(0.12, 2.25, 0.12), Vector3(x, 1.13, 68.0), STEEL)


func _build_merge() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(16):
		var near := _merge_edges(66.0 - float(index) * 2.0)
		var far := _merge_edges(64.0 - float(index) * 2.0)
		for point in [near[0], far[1], near[1], near[0], far[0], far[1]]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(point)
	Shapes.attach(self, surface.commit(), Vector3.ZERO, ASPHALT)


func _merge_edges(z: float) -> Array[Vector3]:
	var x := street_x(z)
	var y := lerpf(0.028, 0.064, smoothstep(34.0, 57.0, z))
	var width := lerpf(2.4, 4.2, smoothstep(35.0, 63.0, z))
	return [Vector3(x - width, y, z), Vector3(x + width, y, z)]


func _label(parent: Node3D, title: String, center: Vector3, yaw: float, size: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = title
	label.position = center
	label.rotation.y = yaw
	label.font_size = 48
	label.pixel_size = size
	label.modulate = color
	label.outline_size = 2
	parent.add_child(label)


func _light(parent: Node3D, center: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = center
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	parent.add_child(light)
