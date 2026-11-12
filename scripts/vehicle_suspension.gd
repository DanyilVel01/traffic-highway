extends Node3D

var grip := 1.0
var _wheelbase := 2.6
var _contacts: Array[RayCast3D] = []
var _support: Array[float] = []
var _highest := -INF


func build(length: float, body: CollisionObject3D, road_layer: int) -> void:
	_wheelbase = length * 0.68
	for z in [-_wheelbase * 0.5, _wheelbase * 0.5]:
		for x in [-0.72, 0.72]:
			var ray := RayCast3D.new()
			ray.position = Vector3(x, 0.72, z)
			ray.target_position = Vector3.DOWN * 1.9
			ray.collision_mask = road_layer
			ray.add_exception(body)
			add_child(ray)
			_contacts.append(ray)


func sample() -> void:
	_highest = -INF
	_support.clear()
	var total_grip := 0.0
	var grounded := 0
	for ray in _contacts:
		ray.force_raycast_update()
		if ray.is_colliding() and ray.get_collision_normal().y > 0.52:
			var height := ray.get_collision_point().y
			_highest = maxf(_highest, height)
			_support.append(height)
			var surface := ray.get_collider() as CollisionObject3D
			total_grip += float(surface.get_meta(&"grip", 0.88)) if surface else 0.88
			grounded += 1
		else:
			_support.append(global_position.y)
	grip = total_grip / grounded if grounded > 0 else 0.30


func vertical_speed(body_y: float, gravity_speed: float) -> float:
	var rise := _highest - body_y
	if rise > 0.025 and rise < 0.43:
		return maxf(gravity_speed, minf(rise * 13.0, 3.9))
	return gravity_speed


func animate_body(visual: Node3D, delta: float) -> void:
	var pitch := atan2((_support[0] + _support[1] - _support[2] - _support[3]) * 0.5, _wheelbase)
	var roll := atan2((_support[1] + _support[3] - _support[0] - _support[2]) * 0.5, 1.44)
	var blend := 1.0 - exp(-delta * 9.0)
	visual.rotation.x = lerpf(visual.rotation.x, clampf(pitch, -0.23, 0.23), blend)
	visual.rotation.z = lerpf(visual.rotation.z, clampf(roll, -0.19, 0.19), blend)
