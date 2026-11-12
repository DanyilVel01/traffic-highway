extends CharacterBody3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const Actor = preload("res://scripts/finale_actor.gd")
const Player = preload("res://scripts/skydive_player.gd")
const Surface = preload("res://scripts/road_surface.gd")
const Suspension = preload("res://scripts/vehicle_suspension.gd")
const Target = preload("res://scripts/city_target.gd")
const VEHICLE_LAYER := Player.VEHICLE_LAYER
const TYPES: Array[String] = ["Sedan", "SUV", "Sports car", "Delivery van", "Truck", "Bus"]

var type_index := 0
var speed := 0.0
var cruise_speed := 13.0
var length := 3.7
var route: PathFollow3D
var door := Node3D.new()
var passenger_door: Node3D
var dashboard := Node3D.new()
var visual: Node3D
var driver: Actor
var driver_target: Target
var bus_stops: Array[Vector3] = []
var next_stop := 0
var dwell := 0.0
var stop_cooldown := 0.0
var blocked_time := 0.0
var impact := Area3D.new()
var _wheels: Array[Node3D]
var _suspension := Suspension.new()


func build(index: int, paint: Color) -> void:
	type_index = index
	var kind := 0 if index < 3 else (1 if index == 3 or index == 5 else 2)
	length = [3.7, 4.2, 3.7, 5.0, 6.2, 8.0][index]
	cruise_speed = [13.0, 12.0, 16.0, 11.0, 10.5, 9.8][index]
	visual = Shapes.create(self, kind, paint)
	if index == 1:
		visual.scale = Vector3(1.07, 1.25, 1.13)
	elif index == 2:
		visual.scale.y = 0.78
	elif index == 5:
		visual.scale.z = 1.6
		Shapes.box(self, Vector3(1.78, 0.26, 0.10), Vector3(0, 2.06, -3.82), Color("#f4ca70"))
		passenger_door = Node3D.new()
		passenger_door.position = Vector3(0.94, 0.63, -2.94)
		add_child(passenger_door)
		Shapes.box(passenger_door, Vector3(0.1, 1.28, 0.95), Vector3(0, 0.57, 0.49), Color("#527580"))
		Shapes.box(passenger_door, Vector3(0.11, 0.71, 0.81), Vector3(0.018, 1.52, 0.48), Color("#2e4555"))
	_wheels = Shapes.find_wheels(visual)
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = 315.0
	collision_layer = VEHICLE_LAYER
	collision_mask = Player.WORLD_LAYER | VEHICLE_LAYER
	floor_snap_length = 0.38
	floor_max_angle = deg_to_rad(49.0)
	safe_margin = 0.025
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.85, 1.48 if index < 3 else 2.24, length - 0.13)
	var body_shape := CollisionShape3D.new()
	body_shape.shape = Surface.bevel(shape.size.x, shape.size.z, 0.052, shape.size.y, 0.015)
	add_child(body_shape)
	add_child(_suspension)
	_suspension.build(length, self, Player.WORLD_LAYER)
	impact.collision_layer = 0
	impact.collision_mask = Player.PLAYER_LAYER
	add_child(impact)
	var trigger := CollisionShape3D.new()
	var hit_volume := BoxShape3D.new()
	hit_volume.size = shape.size + Vector3(0.27, 0.03, 0.27)
	trigger.shape = hit_volume
	trigger.position.y = shape.size.y * 0.51
	impact.add_child(trigger)
	door.position = Vector3(-0.93, 0.63, -length * (0.40 if index >= 3 else 0.18))
	add_child(door)
	Shapes.box(door, Vector3(0.09, 0.46 if index < 3 else 1.08, 0.97), Vector3(0, 0.18, 0.49), paint)
	Shapes.box(door, Vector3(0.11, 0.065, 0.23), Vector3(-0.045, 0.25, 0.77), Color("#c8c9bc"))
	driver = Actor.new()
	add_child(driver)
	driver.position = Vector3(-0.39, 0.51, door.position.z + 0.54)
	driver.scale = Vector3.ONE * 0.68
	driver.build(Actor.Role.DRIVER, Color("#a69d82"))
	driver.hide()
	driver_target = Target.new()
	add_child(driver_target)
	driver_target.position = seat() - Vector3.UP * 0.59
	driver_target.bind(driver, Target.CIVILIAN, Vector3(0.51, 0.65, 0.52))
	driver_target.set_targetable(false)
	driver_target.health.died.connect(_driver_killed)
	_build_dashboard()


func driver_in_window(at: Vector3, from: Vector3, direction: Vector3) -> Target:
	if not is_instance_valid(driver_target):
		return null
	var local := to_local(at)
	if absf(local.z - seat().z) > (1.28 if type_index < 3 else 1.52):
		return null
	var low := 0.89 if type_index < 3 else 1.41
	var high := 1.39 if type_index < 3 else 2.17
	var toward_driver := from + direction * (from.distance_to(driver_target.global_position)) - driver_target.global_position
	if local.y < low or local.y > high or toward_driver.length_squared() > 0.44:
		return null
	return driver_target


func _driver_killed(_at: Vector3, _impulse: Vector3) -> void:
	driver = null
	driver_target = null
	speed = 0.0
	if is_instance_valid(route):
		route.queue_free()
		route = null


func seat() -> Vector3:
	return Vector3(-0.36, 1.36 if type_index < 3 else 1.90, door.position.z + 0.38)


func set_driven(value: bool) -> void:
	visual.visible = not value
	door.visible = not value
	dashboard.visible = value


func _build_dashboard() -> void:
	add_child(dashboard)
	dashboard.position = seat()
	dashboard.hide()
	Shapes.box(dashboard, Vector3(1.78, 0.22, 0.55), Vector3(0.34, -0.39, -0.72), Color("#263239"))
	Shapes.box(dashboard, Vector3(1.72, 0.09, 1.05), Vector3(0.34, -0.40, -1.13), Color("#465665"))
	Shapes.box(dashboard, Vector3(0.49, 0.20, 0.09), Vector3(0.0, -0.23, -0.69), Color("#17282c"))
	for x in [-0.16, 0.0, 0.16]:
		Shapes.box(dashboard, Vector3(0.092, 0.082, 0.012), Vector3(x, -0.23, -0.639), Color("#84d3b5"))
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.17
	wheel.outer_radius = 0.21
	wheel.rings = 12
	wheel.ring_segments = 8
	var rim := Shapes.attach(dashboard, wheel, Vector3(0, -0.29, -0.37), Color("#1b262d"))
	rim.rotation.x = PI * 0.44
	Shapes.box(dashboard, Vector3(0.31, 0.07, 0.06), Vector3(0, -0.29, -0.37), Color("#1b262d"))
	for side in [-0.57, 1.14]:
		var pillar := Shapes.box(dashboard, Vector3(0.075, 0.67, 0.09), Vector3(side, 0.03, -0.92), Color("#465665"))
		pillar.rotation.x = -0.37
	Shapes.box(dashboard, Vector3(1.78, 0.09, 0.13), Vector3(0.28, 0.34, -0.80), Color("#465665"))


func follow_route(delta: float, desired: float) -> void:
	speed = move_toward(speed, desired, delta * (11.0 if desired < speed else 4.5))
	var path := route.get_parent() as Path3D
	var ahead := path.curve.sample_baked(fposmod(route.progress + 0.55, path.curve.get_baked_length()))
	var forward := path.to_global(ahead) - route.global_position
	if forward.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(-forward.x, -forward.z), minf(1.0, delta * 13.0))
	route.progress += speed * delta
	global_position = route.global_position
	_spin(speed * delta)


func drive(delta: float) -> float:
	_suspension.sample()
	var throttle := Input.is_action_pressed(&"accelerate")
	var brake := Input.is_action_pressed(&"brake")
	var handbrake := Input.is_action_pressed(&"handbrake")
	var desired := 43.0 if throttle and not brake else (-9.0 if brake and speed <= 0.0 else 0.0)
	var acceleration := 35.0 if handbrake else (19.0 if brake else (9.0 if throttle else 2.0))
	speed = move_toward(speed, 0.0 if handbrake else desired, acceleration * delta * maxf(0.54, _suspension.grip))
	var steer := float(Input.is_action_pressed(&"move_right")) - float(Input.is_action_pressed(&"move_left"))
	rotation.y -= steer * signf(speed) * minf(absf(speed) * 0.28, 1.7) * delta * _suspension.grip
	var forward := -basis.z * speed
	var drift := Vector2(velocity.x, velocity.z).move_toward(Vector2(forward.x, forward.z), 58.0 * _suspension.grip * delta)
	velocity = Vector3(drift.x, _suspension.vertical_speed(global_position.y, velocity.y - 21.0 * delta), drift.y)
	var before := absf(speed)
	move_and_slide()
	_suspension.animate_body(visual, delta)
	_spin(speed * delta)
	for index in get_slide_collision_count():
		if absf(get_slide_collision(index).get_normal().y) < 0.55:
			speed *= 0.20
			return before
	return 0.0


func _spin(travel: float) -> void:
	for wheel in _wheels:
		wheel.rotate_x(travel / 0.36)
