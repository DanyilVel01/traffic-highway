extends RefCounted

const Shapes = preload("res://scripts/vehicle_visual.gd")
const GOLD: Color = Color("#e8b353")
const BRONZE: Color = Color("#8a512e")
const IVORY: Color = Color("#f7e6ce")
const ROBE: Color = Color("#59327b")


static func create(parent: Node3D, length: float, height: float, color: Color) -> Array[Node3D]:
	var wheels: Array[Node3D] = []
	var carriage_z := length * 0.24
	var carriage_length := length * 0.47
	Shapes.box(parent, Vector3(1.38, 0.22, carriage_length), Vector3(0, 0.52, carriage_z), BRONZE)
	Shapes.box(parent, Vector3(1.37, 0.62, 0.13), Vector3(0, 0.89, length * 0.47), ROBE)
	Shapes.box(parent, Vector3(1.45, 0.11, 0.19), Vector3(0, 1.22, length * 0.47), GOLD)
	var emblem := Shapes.box(parent, Vector3(0.34, 0.34, 0.06), Vector3(0, 0.9, length * 0.47 + 0.08), GOLD)
	emblem.rotation.z = PI * 0.25
	Shapes.box(parent, Vector3(0.55, height * 0.42, 0.39), Vector3(0, height * 0.62, carriage_z), color)
	Shapes.box(parent, Vector3(0.33, 0.30, 0.33), Vector3(0, height * 0.94, carriage_z), GOLD)
	Shapes.box(parent, Vector3(0.09, 0.19, 0.28), Vector3(0, height * 1.05, carriage_z + 0.01), ROBE)
	for side in [-1.0, 1.0]:
		Shapes.box(parent, Vector3(0.10, 0.45, carriage_length), Vector3(side * 0.63, 0.81, carriage_z), ROBE)
		Shapes.box(parent, Vector3(0.14, 0.09, carriage_length), Vector3(side * 0.63, 1.07, carriage_z), GOLD)
		Shapes.box(parent, Vector3(0.07, 0.08, length * 0.55), Vector3(side * 0.26, 0.72, 0), GOLD)
		wheels.append(_wheel(parent, Vector3(side * 0.81, 0.39, carriage_z)))
	_pegasus(parent, length, height)
	return wheels


static func _wheel(parent: Node3D, center: Vector3) -> Node3D:
	var wheel := Node3D.new()
	wheel.position = center
	parent.add_child(wheel)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.31
	rim.outer_radius = 0.40
	rim.rings = 12
	rim.ring_segments = 8
	Shapes.attach(wheel, rim, Vector3.ZERO, GOLD).rotation.z = PI * 0.5
	for index in range(3):
		var spoke := Shapes.box(wheel, Vector3(0.05, 0.69, 0.065), Vector3.ZERO, GOLD)
		spoke.rotation.x = float(index) * PI / 3.0
	Shapes.box(wheel, Vector3(0.16, 0.15, 0.15), Vector3.ZERO, BRONZE)
	return wheel


static func _pegasus(parent: Node3D, length: float, height: float) -> void:
	var body_z := -length * 0.24
	Shapes.box(parent, Vector3(0.58, height * 0.25, length * 0.34), Vector3(0, height * 0.52, body_z), IVORY)
	var neck := Shapes.box(parent, Vector3(0.33, height * 0.37, 0.35), Vector3(0, height * 0.71, -length * 0.35), IVORY)
	neck.rotation.x = -0.42
	Shapes.box(parent, Vector3(0.36, 0.29, length * 0.13), Vector3(0, height * 0.87, -length * 0.42), IVORY)
	for side in [-1.0, 1.0]:
		Shapes.box(parent, Vector3(0.10, 0.18, 0.13), Vector3(side * 0.11, height * 0.98, -length * 0.39), IVORY)
		Shapes.box(parent, Vector3(0.035, 0.08, 0.10), Vector3(side * 0.18, height * 0.88, -length * 0.42), BRONZE)
		for row in [-1.0, 1.0]:
			var leg := Shapes.box(parent, Vector3(0.13, height * 0.38, 0.15),
				Vector3(side * 0.22, height * 0.27, body_z + row * length * 0.11), IVORY)
			leg.rotation.x = row * side * 0.29
		for index in range(3):
			var wing := Shapes.box(parent, Vector3(0.16, 0.38 - float(index) * 0.05, 0.43),
				Vector3(side * (0.39 + float(index) * 0.13), height * 0.66 + float(index) * 0.11,
					body_z + float(index) * 0.18), IVORY)
			wing.rotation.z = side * -0.76
