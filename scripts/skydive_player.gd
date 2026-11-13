extends CharacterBody3D

const DropCamera = preload("res://scripts/drop_camera.gd")
const Damage = preload("res://scripts/city_damage.gd")
const WORLD_LAYER := 8
const PLAYER_LAYER := 16
const VEHICLE_LAYER := 64
const DROP_HEIGHT := 285.0
const DIVE_LIMIT := 82.0
const CANOPY_OPEN_TIME := 1.5

signal fired(origin: Vector3, direction: Vector3)
signal vehicle_requested
signal door_requested

enum Phase { FREEFALL, PARACHUTE, GROUND }

var phase := Phase.FREEFALL
var camera := DropCamera.new()
var damage := Damage.new()
var drop_available := false
var mounted := false
var altitude_agl := DROP_HEIGHT
var moisture := 0.0
var _enabled := true
var _vehicle_transition := false
var _canopy_timer := CANOPY_OPEN_TIME
var _opening_velocity := Vector3.ZERO
var _hit_lock := 0.0
var _fire_cooldown := 0.0


func _ready() -> void:
	collision_layer = PLAYER_LAYER
	collision_mask = WORLD_LAYER | VEHICLE_LAYER
	floor_snap_length = 0.25
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.36
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	add_child(damage)
	damage.hurt.connect(func() -> void: camera.bump(0.4))
	add_child(camera)
	camera.position.y = 1.62
	camera.make_current()
	camera.look(Vector2(0, 265))


func set_enabled(value: bool) -> void:
	_enabled = value
	_update_mouse_mode()


func set_vehicle_transition(active: bool) -> void:
	_vehicle_transition = active
	_update_mouse_mode()


func _update_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _enabled and not _vehicle_transition else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or _vehicle_transition or not damage.alive:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		vehicle_requested.emit()
		return
	if mounted:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E and phase == Phase.GROUND:
		door_requested.emit()
		return
	if event is InputEventMouseMotion:
		camera.look(event.relative)
	elif (event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"handbrake")) and not event.is_echo():
		_use_space()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and phase == Phase.GROUND and _fire_cooldown <= 0.0:
		fired.emit(camera.global_position, -camera.global_basis.z)
		camera.recoil()
		_fire_cooldown = 0.22


func struck_by_vehicle(direction: Vector3, impact_speed: float) -> bool:
	if not damage.alive or mounted or phase != Phase.GROUND or _hit_lock > 0.0:
		return false
	_hit_lock = 0.55
	var push := clampf(impact_speed * 0.68, 3.0, 11.0)
	velocity = direction.normalized() * push + Vector3.UP * clampf(impact_speed * 0.16, 1.5, 3.3)
	camera.bump(clampf(impact_speed / 18.0, 0.3, 1.0))
	return true


func _use_space() -> void:
	if phase == Phase.FREEFALL:
		_deploy()
	elif phase == Phase.GROUND and drop_available:
		position.y = DROP_HEIGHT * 0.65
		velocity = Vector3(0, -12, 0)
		phase = Phase.FREEFALL
	elif phase == Phase.GROUND and is_on_floor():
		velocity.y = 6.4
	elif phase == Phase.GROUND and position.y > 20.0 and velocity.y < -2.0:
		_deploy()


func _deploy() -> void:
	_opening_velocity = velocity
	_canopy_timer = 0.0
	phase = Phase.PARACHUTE


func _pressed(key: Key) -> float:
	return float(Input.is_physical_key_pressed(key))


func _physics_process(delta: float) -> void:
	if not _enabled or not damage.alive or mounted:
		return
	_hit_lock = maxf(0.0, _hit_lock - delta)
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	var steer := Vector2(_pressed(KEY_D) - _pressed(KEY_A), _pressed(KEY_W) - _pressed(KEY_S))
	var wish := (global_basis.x * steer.x - global_basis.z * steer.y).limit_length(1.0)
	if phase == Phase.GROUND:
		var pace := 9.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 5.8
		var control := 7.0 if _hit_lock > 0.0 else 35.0
		velocity.x = move_toward(velocity.x, wish.x * pace, delta * control)
		velocity.z = move_toward(velocity.z, wish.z * pace, delta * control)
		velocity.y -= 19.0 * delta
	else:
		var open := phase == Phase.PARACHUTE
		var terminal := 56.0 + (DIVE_LIMIT - 56.0) * maxf(steer.y, 0.0) + 19.0 * minf(steer.y, 0.0)
		var glide := (wish - global_basis.z * (0.22 if open else 0.27 - steer.y * 0.15)).limit_length(1.0)
		var horizontal := glide * (15.0 if open else 29.0)
		if open:
			_canopy_timer = minf(_canopy_timer + delta, CANOPY_OPEN_TIME)
			var target := Vector3(horizontal.x, -clampf(5.1 + steer.y * 1.35, 3.75, 6.45), horizontal.z)
			if _canopy_timer < CANOPY_OPEN_TIME:
				velocity = _opening_velocity.lerp(target, smoothstep(0.0, CANOPY_OPEN_TIME, _canopy_timer))
			else:
				velocity = velocity.lerp(target, 1.0 - exp(-delta * 4.0))
		else:
			velocity = velocity.lerp(Vector3(horizontal.x, -terminal, horizontal.z), 1.0 - exp(-delta * 0.95))
	var impact_velocity := velocity
	move_and_slide()
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision.get_collider() is CollisionObject3D and collision.get_collider().get_collision_layer() == VEHICLE_LAYER:
			continue
		var impact := -impact_velocity.dot(collision.get_normal())
		if impact > 15.0 or (phase == Phase.FREEFALL and collision.get_normal().y > 0.60):
			damage.fatal("Killed in Action: High-Speed Impact")
			return
	if phase == Phase.PARACHUTE and is_on_floor():
		phase = Phase.GROUND
	if phase != Phase.GROUND:
		var query := PhysicsRayQueryParameters3D.create(global_position, global_position - Vector3.UP * 520.0, WORLD_LAYER)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		altitude_agl = maxf(0.0, global_position.y - (Vector3(hit.position).y if not hit.is_empty() else 0.0))
	camera.animate(delta, maxf(0.0, -velocity.y), steer if phase != Phase.GROUND else Vector2.ZERO,
		phase == Phase.GROUND, phase == Phase.GROUND and wish.length_squared() > 0.1)
