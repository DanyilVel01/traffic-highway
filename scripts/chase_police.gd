extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")

var _wheels: Array[Node3D] = []
var _beacons: Array[MeshInstance3D] = []
var _flash_time: float = 0.0
var driver_door: Node3D


func build() -> void:
	var body := Shapes.create(self, 0, Color("#202b49"))
	_wheels = Shapes.find_wheels(body)
	for side in [-1.0, 1.0]:
		Shapes.box(body, Vector3(0.05, 0.31, 1.42), Vector3(side * 0.925, 0.70, 0), Color("#e0edff"))
	driver_door = Node3D.new()
	driver_door.position = Vector3(-0.95, 0.72, -0.58)
	body.add_child(driver_door)
	Shapes.box(driver_door, Vector3(0.065, 0.33, 1.21), Vector3(0, 0, 0.58), Color("#e0edff"))
	Shapes.box(driver_door, Vector3(0.065, 0.29, 0.91), Vector3(0.02, 0.30, 0.55), Color("#29485c"))
	Shapes.box(body, Vector3(1.31, 0.11, 0.32), Vector3(0, 1.46, 0.12), Color("#14233a"))
	for color in [Color("#ff254b"), Color("#217bff")]:
		var x := -0.34 if _beacons.is_empty() else 0.34
		var beacon := Shapes.box(body, Vector3(0.60, 0.19, 0.29), Vector3(x, 1.58, 0.12), color)
		var material := beacon.material_override.duplicate() as StandardMaterial3D
		material.emission_enabled = true
		material.emission = color
		beacon.material_override = material
		_beacons.append(beacon)


func animate(delta: float, travel: float) -> void:
	_flash_time += delta
	var active := floori(_flash_time * 9.0) % 2
	for index in _beacons.size():
		var material := _beacons[index].material_override as StandardMaterial3D
		material.emission_energy_multiplier = 2.3 if index == active else 0.10
	for wheel in _wheels:
		wheel.rotate_x(travel / 0.36)


func fire_at(target: Vector3) -> void:
	var muzzle := Vector3(0.57, 0.90, -1.7)
	var end := to_local(target)
	var direction := end - muzzle
	var beam := Shapes.box(self, Vector3(0.041, 0.041, direction.length()), (muzzle + end) * 0.5, Color("#ffe68d"))
	beam.basis = Basis.looking_at(direction)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flash := Shapes.box(self, Vector3(0.27, 0.24, 0.30), muzzle, Color("#ffae58"))
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := create_tween().set_parallel()
	tween.tween_callback(beam.queue_free).set_delay(0.09)
	tween.tween_callback(flash.queue_free).set_delay(0.12)
