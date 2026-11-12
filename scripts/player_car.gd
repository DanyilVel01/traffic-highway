extends Area3D

const VehicleVisual = preload("res://scripts/vehicle_visual.gd")
const WIDTH: float = 1.65
const LENGTH: float = 3.3
const MIN_DRIFT_SPEED: float = 50.0 / 3.6

var lane: int = 1
var visual: Node3D
var paint: Color
var wheels: Array[Node3D] = []
var _tire_smoke: Array[CPUParticles3D] = []


func build(car_index: int) -> void:
	name = "Player"
	collision_layer = 1
	collision_mask = 2 | 4
	monitoring = true
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, 1.2, LENGTH)
	var hitbox := CollisionShape3D.new()
	hitbox.shape = shape
	hitbox.position.y = 0.8
	add_child(hitbox)
	paint = VehicleVisual.PLAYER_PAINTS[car_index]
	visual = VehicleVisual.create(self, 0, paint, car_index)
	wheels = VehicleVisual.find_wheels(visual)
	_build_tire_smoke()


func handle_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"move_left"):
		lane = maxi(0, lane - 1)
	elif event.is_action_pressed(&"move_right"):
		lane = mini(2, lane + 1)


func install_cinematic_doors() -> Array[Node3D]:
	var doors: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var door := Node3D.new()
		door.position = Vector3(side * 0.923, 0.62, -0.60)
		visual.add_child(door)
		door.add_to_group(&"cinematic_door")
		doors.append(door)
		VehicleVisual.box(door, Vector3(0.075, 0.34, 1.14), Vector3(0, 0.02, 0.56), paint)
		VehicleVisual.box(door, Vector3(0.068, 0.33, 0.91), Vector3(-side * 0.03, 0.34, 0.57), Color("#29485c"))
		VehicleVisual.box(door, Vector3(0.10, 0.045, 0.20), Vector3(side * 0.031, 0.12, 0.88), Color("#d49d52"))
	return doors


func advance(delta: float, travel: float, lane_width: float, lane_speed: float, handbrake: bool) -> void:
	var target := float(lane - 1) * lane_width
	var offset := target - position.x
	var drifting := handbrake and travel >= MIN_DRIFT_SPEED * delta and absf(offset) > 0.10
	if drifting:
		lane_speed *= 0.78
	position.x = move_toward(position.x, target, lane_speed * delta)
	var yaw := -signf(offset) * 0.44 if drifting else 0.0
	rotation.y = lerpf(rotation.y, yaw, 1.0 - exp(-delta * 10.0))
	var tilt := clampf((position.x - target) * 0.09, -0.18, 0.18)
	visual.rotation.z = lerpf(visual.rotation.z, tilt, 1.0 - exp(-delta * 7.0))
	for wheel in wheels:
		wheel.rotate_x(travel / 0.36)
	set_drift_smoke(drifting)


func set_drift_smoke(active: bool) -> void:
	for emitter in _tire_smoke:
		emitter.emitting = active


func _build_tire_smoke() -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	var puff := SphereMesh.new()
	puff.radius = 0.32
	puff.height = 0.64
	puff.radial_segments = 6
	puff.rings = 3
	puff.material = material
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(0.83, 0.86, 0.90, 0.75), Color(0.83, 0.86, 0.90, 0.0)])
	for side in [-1.0, 1.0]:
		var emitter := CPUParticles3D.new()
		emitter.position = Vector3(side * 0.84, 0.18, LENGTH * 0.34)
		emitter.emitting = false
		emitter.amount = 20
		emitter.lifetime = 0.42
		emitter.mesh = puff
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		emitter.direction = Vector3(0, 0.22, 1)
		emitter.spread = 22.0
		emitter.gravity = Vector3(0, 1.4, 0)
		emitter.initial_velocity_min = 5.0
		emitter.initial_velocity_max = 10.0
		emitter.scale_amount_min = 0.65
		emitter.scale_amount_max = 1.45
		emitter.color_ramp = fade
		visual.add_child(emitter)
		_tire_smoke.append(emitter)

