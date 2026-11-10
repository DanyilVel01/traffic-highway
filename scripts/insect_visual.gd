extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const CHITIN: Color = Color("#44334c")
const EYE: Color = Color("#ffe69b")

var _legs: Array[Node3D] = []
var _stride: float = 0.0


func build(length: float, height: float, color: Color) -> void:
	_body_part(Vector3(0, height * 0.60, length * 0.15), Vector3(1.35, height * 0.85, length * 0.67), color)
	_body_part(Vector3(0, height * 0.53, -length * 0.24), Vector3(0.91, height * 0.52, length * 0.30), CHITIN)
	for side in [-1.0, 1.0]:
		_body_part(Vector3(side * 0.30, height * 0.70, length * 0.15),
			Vector3(0.63, height * 0.70, length * 0.61), color.lightened(0.12))
		_body_part(Vector3(side * 0.36, height * 0.64, -length * 0.32), Vector3(0.24, 0.23, 0.24), EYE)
		_link(self, Vector3(side * 0.25, height * 0.67, -length * 0.35),
			Vector3(side * 0.64, height * 0.94, -length * 0.50), 0.10, CHITIN)
		for row in range(3):
			var leg := Node3D.new()
			leg.position = Vector3(side * 0.47, height * 0.43, (float(row) - 1.0) * length * 0.23)
			add_child(leg)
			_legs.append(leg)
			var knee := Vector3(side * 0.30, height * 0.06, (float(row) - 1.0) * 0.35)
			_link(leg, Vector3.ZERO, knee, 0.15, color.darkened(0.25))
			_link(leg, knee, knee + Vector3(side * 0.12, -height * 0.48, 0.17), 0.11, CHITIN)


func step(travel: float) -> void:
	_stride = fposmod(_stride + travel * 4.0, TAU)
	for index in _legs.size():
		_legs[index].rotation.y = sin(_stride + float(index % 2) * PI) * 0.43


func _body_part(center: Vector3, size: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	Shapes.attach(self, mesh, center, color).scale = size


func _link(parent: Node3D, start: Vector3, finish: Vector3, width: float, color: Color) -> void:
	var offset := finish - start
	var part := Shapes.box(parent, Vector3(width, width, offset.length()), (start + finish) * 0.5, color)
	part.basis = Basis.looking_at(offset)
