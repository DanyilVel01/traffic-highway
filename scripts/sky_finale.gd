extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const PlayerCar = preload("res://scripts/player_car.gd")
const Actor = preload("res://scripts/finale_actor.gd")
const Palace = preload("res://scripts/finale_palace.gd")
const Police = preload("res://scripts/chase_police.gd")
const TrafficCar = preload("res://scripts/traffic_car.gd")
const PARK: Vector3 = Vector3(0, 0, -6)
const DRIVER_DOOR: Vector3 = Vector3(-1.6, 0, -6)
const PASSENGER_DOOR: Vector3 = Vector3(1.6, 0, -6)
const TURN_RADIUS: float = 1.48

signal finished
signal cue(name: String)

var _car: PlayerCar
var _camera: Camera3D
var _driver: Actor
var _friend: Actor
var _princess: Actor
var _palace: Palace
var _outside_guards: Array[Actor] = []
var _inside_guards: Array[Actor] = []
var _doors: Array[Node3D] = []
var pursuit: Array[Police] = []
var oncoming: Array[TrafficCar] = []
var _lane_width: float
var _tweens: Array[Tween] = []
var _effects := Node3D.new()


func build(lane_width: float) -> void:
	_lane_width = lane_width
	_palace = Palace.new()
	add_child(_palace)
	_palace.build(lane_width)
	_add_guards(_outside_guards, [-15.8, -20.6, -26.0], Color("#a34558"))
	_add_guards(_inside_guards, [-34.0, -39.4, -45.6], Color("#654b93"))
	_princess = _actor(Actor.Role.PRINCESS, Color("#c464ae"), _floor_point(1.15, -48.85))
	_princess.face(PARK)
	for side in [-1.0, 1.0]:
		var bay_x: float = side * (lane_width * 1.5 + 1.85)
		Shapes.box(self, Vector3(4.5, 0.5, 22), Vector3(bay_x, -0.27, -20.0), Color("#a698bc"))
		Shapes.box(self, Vector3(3.5, 0.44, 4.6), Vector3(bay_x, 2.54, -24.0), Color("#c9b8e4"))
		for edge in [-1.55, 1.55]:
			Shapes.box(self, Vector3(0.32, 2.65, 4.6), Vector3(bay_x + edge, 1.32, -24.0), Color("#b3a2c8"))


func play(car: PlayerCar) -> void:
	_car = car
	add_child(_effects)
	_driver = _actor(Actor.Role.DRIVER, Color("#306c77"), PARK)
	_friend = _actor(Actor.Role.DRIVER, Color("#bd773b"), PARK)
	_driver.hide()
	_friend.hide()
	_doors = _car.install_cinematic_doors()
	_camera = Camera3D.new()
	_camera.fov = 56.0
	add_child(_camera)
	_frame(Vector3(10.5, 6.3, 13.2), Vector3(0, 4.8, -18.5))
	_camera.make_current()

	await _arrive_and_exit()
	await _fight(_outside_guards, [-12.6, -17.65, -22.65], false)
	await _open_palace()
	await _fight(_inside_guards, [-31.3, -36.6, -42.1], true)
	await _take_princess()
	await _escape_palace()
	await _board_car()
	await _drive_away()
	_tweens.clear()
	finished.emit()


func skip() -> void:
	for tween in _tweens:
		tween.kill()
	_tweens.clear()
	_effects.hide()
	_effects.queue_free()
	_driver.hide()
	_friend.hide()
	_princess.hide()
	for door in _doors:
		door.rotation.y = 0.0
	_palace.doors[0].rotation.y = 1.50
	_palace.doors[1].rotation.y = -1.50
	for guard in _outside_guards + _inside_guards:
		guard.hide()
	cue.emit("depart")
	_turn_car(PI)
	_spawn_pursuit()
	_escape_pursuit(1.0)
	finished.emit()


func _animation_tween() -> Tween:
	var tween := create_tween()
	_tweens.append(tween)
	return tween


func _arrive_and_exit() -> void:
	var arrival := _camera_move(Vector3(7.9, 5.25, 3.8), Vector3(0, 4.75, -17), 1.25)
	_drive(arrival, PARK, 1.25, Tween.EASE_OUT)
	arrival.parallel().tween_property(_car, "rotation:y", 0.0, 0.4)
	await arrival.finished
	cue.emit("parked")

	_frame(Vector3(0, 4.75, 0.1), Vector3(0, 1.35, -9.3))
	var open := _animation_tween().set_parallel()
	_set_car_doors(open, 1.06, 0.30)
	await open.finished
	_driver.position = PARK + Vector3(-0.42, 0.55, 0.12)
	_friend.position = PARK + Vector3(0.42, 0.55, 0.12)
	_driver.show()
	_friend.show()
	var exit_car := _animation_tween().set_parallel()
	_walk(exit_car, _driver, DRIVER_DOOR, 0.62)
	_walk(exit_car, _friend, PASSENGER_DOOR, 0.62)
	await exit_car.finished
	var close := _animation_tween().set_parallel()
	_set_car_doors(close, 0.0, 0.32)


func _fight(guards: Array[Actor], positions: Array[float], indoors: bool) -> void:
	for index in positions.size():
		var z := positions[index]
		var target_z := guards[index * 2].position.z
		var side := -1.0 if index % 2 == 1 else 1.0
		var start_z := maxf(_driver.position.z, _friend.position.z)
		var height := Palace.floor_height(z)
		var eye := Vector3(side * 6.1, height + 4.0, z + 4.6)
		var start_eye := Vector3(side * 6.1, Palace.floor_height(start_z) + 4.0, start_z + 4.6)
		if indoors:
			eye = Vector3(side * 4.85, height + 3.0, z + 1.65)
			start_eye = Vector3(side * 4.85, height + 3.0, minf(start_z + 1.65, Palace.DOOR_Z - 0.7))
		_frame(start_eye, _floor_point(0.0, lerpf(start_z, target_z, 0.38)) + Vector3.UP * 1.05)
		var advance := _camera_move(eye, _floor_point(0.0, (z + target_z) * 0.5) + Vector3.UP * 1.05, 0.97)
		var spread := 1.55 if indoors and index == 0 else 3.15
		_walk(advance, _driver, _floor_point(-spread, z), 0.90, true)
		_walk(advance, _friend, _floor_point(spread, z + 0.40), 0.97, true)
		await advance.finished
		var left := guards[index * 2]
		var right := guards[index * 2 + 1]
		_ready_shot(_driver, left)
		_ready_shot(_friend, right)
		await _hold(0.20)
		await _fire(_driver, left)
		await _fire(_friend, right)
		_driver.lower_weapon()
		_friend.lower_weapon()


func _open_palace() -> void:
	_frame(Vector3(4.6, 6.25, -23.4), Vector3(0, 4.35, Palace.DOOR_Z))
	var approach := _animation_tween().set_parallel()
	_walk(approach, _driver, _floor_point(-1.15, Palace.DOOR_Z + 1.05), 1.10, true)
	_walk(approach, _friend, _floor_point(1.15, Palace.DOOR_Z + 1.05), 1.18, true)
	await approach.finished
	_driver.face(_floor_point(-0.55, Palace.DOOR_Z))
	_friend.face(_floor_point(0.55, Palace.DOOR_Z))
	_driver.right_arm.rotation.x = 1.40
	_friend.left_arm.rotation.x = 1.40
	var open := _animation_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	open.tween_property(_palace.doors[0], "rotation:y", 1.50, 0.82)
	open.tween_property(_palace.doors[1], "rotation:y", -1.50, 0.82)
	await open.finished


func _take_princess() -> void:
	_frame(Vector3(4.75, 6.45, -45.0), Vector3(0.35, 4.2, -48.0))
	var approach := _animation_tween().set_parallel()
	_walk(approach, _driver, _floor_point(2.05, -47.75), 1.32, true)
	_walk(approach, _friend, _floor_point(-1.90, -47.25), 1.08, true)
	_walk(approach, _princess, _floor_point(0.9, -48.35), 0.62, true)
	await approach.finished
	_driver.face(_princess.position)
	_driver.right_arm.rotation.x = 1.38
	_princess.face(_driver.position)
	_princess.right_arm.rotation.x = 1.35
	await _hold(0.30)


func _escape_palace() -> void:
	_frame(Vector3(-4.7, 6.1, -42.9), Vector3(0.0, 4.14, -47.0))
	var hall := _camera_move(Vector3(-4.6, 6.1, -30.8), Vector3(0.0, 4.1, -34.4), 2.10)
	_escort(hall, 1.30, -31.0, -1.45, 2.10)
	await hall.finished
	_frame(Vector3(-6.1, 7.1, -22.5), Vector3(0, 4.2, -28.3))
	var descent := _camera_move(Vector3(-6.75, 4.3, -4.0), Vector3(0.9, 1.1, -10.1), 3.10)
	_escort(descent, 2.48, -7.15, -1.9, 3.10)
	await descent.finished
	_driver.right_arm.rotation = Vector3.ZERO
	_princess.left_arm.rotation = Vector3.ZERO


func _board_car() -> void:
	_frame(Vector3(6.1, 3.6, -2.20), Vector3(0.15, 0.95, -6.7))
	var position_for_boarding := _animation_tween().set_parallel()
	_walk(position_for_boarding, _driver, Vector3(2.0, 0, -3.75), 0.70)
	_walk(position_for_boarding, _friend, DRIVER_DOOR, 0.58)
	_walk(position_for_boarding, _princess, PASSENGER_DOOR, 0.66)
	_set_car_doors(position_for_boarding, 1.06, 0.31)
	await position_for_boarding.finished
	var cross := _animation_tween().set_parallel()
	_walk(cross, _driver, Vector3(-1.64, 0, -3.75), 0.82)
	_walk(cross, _friend, PARK + Vector3(-0.35, 0.55, 0.37), 0.48)
	_walk(cross, _princess, PARK + Vector3(0.34, 0.55, 0.18), 0.48)
	cross.tween_callback(_friend.hide).set_delay(0.48)
	cross.tween_callback(_princess.hide).set_delay(0.48)
	await cross.finished
	var get_to_door := _animation_tween().set_parallel()
	_walk(get_to_door, _driver, DRIVER_DOOR, 0.47)
	get_to_door.tween_property(_doors[1], "rotation:y", 0.0, 0.32)
	await get_to_door.finished
	var get_in := _animation_tween()
	_walk(get_in, _driver, PARK + Vector3(-0.34, 0.55, 0.08), 0.49)
	await get_in.finished
	_driver.hide()
	var close := _animation_tween().set_parallel()
	_set_car_doors(close, 0.0, 0.25)
	await close.finished


func _drive_away() -> void:
	_frame(Vector3(-5.25, 4.5, -8.7), Vector3(0.7, 0.9, -5.9))
	cue.emit("depart")
	var turn := _animation_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn.tween_method(_turn_car, 0.0, PI, 1.22)
	await turn.finished
	_spawn_pursuit()
	var chase := _animation_tween()
	chase.tween_method(_escape_pursuit, 0.0, 1.0, 4.8)
	for index in 3:
		chase.parallel().tween_callback(_pursuit_shot.bind(index % 2)).set_delay(2.75 + index * 0.59)
	await chase.finished


func _spawn_pursuit() -> void:
	if not pursuit.is_empty():
		return
	for side in [-1.0, 1.0]:
		var police := Police.new()
		add_child(police)
		police.build()
		police.rotation.y = PI
		police.position = Vector3(side * 6.65, 0, -25)
		pursuit.append(police)
	for lane in [-1, 0]:
		var vehicle := TrafficCar.new()
		vehicle.build(0, Color("#766dad"), 1.0, TrafficCar.Style.CHARIOT)
		add_child(vehicle)
		vehicle.position = Vector3(lane * _lane_width, 0, 132.4)
		oncoming.append(vehicle)


func _escape_pursuit(t: float) -> void:
	var car_z := PARK.z + t * t * (78.0 + 5.0 * t)
	_roll_car(to_global(Vector3(TURN_RADIUS * 2.0, 0, car_z)))
	for vehicle in oncoming:
		vehicle.position.z = lerpf(132.4, 94.0, t)
	for index in pursuit.size():
		var police := pursuit[index]
		var side := -1.0 if index == 0 else 1.0
		var z := car_z - 19.0 + (10.5 - float(index) * 4.5) * t
		var x := side * lerpf(6.65, 2.85, smoothstep(-13.5, -6.0, z))
		var next_position := Vector3(x, 0, z)
		police.animate(get_process_delta_time(), police.position.distance_to(next_position))
		police.rotation.y = PI + atan2(next_position.x - police.position.x, maxf(0.01, z - police.position.z))
		police.position = next_position
	if t < 0.40:
		_frame(Vector3(10.0, 4.2, -8.0), Vector3(0, 0.95, -16.0))
	elif t < 0.77:
		_frame(Vector3(-7.8, 3.65, car_z - 3.0), Vector3(0, 0.8, car_z - 9.0))
	else:
		var blend := smoothstep(0.77, 1.0, t)
		var eye := Vector3(-7.8, 3.65, car_z - 3.0).lerp(Vector3(1.04, 6.3, car_z - 21.0), blend)
		_frame(eye, Vector3(0, 0.8, car_z + 7.0))
		_camera.rotation.x = lerpf(_camera.rotation.x, deg_to_rad(-15.5), blend)
		_camera.rotation.y = lerp_angle(_camera.rotation.y, PI, blend)
		_camera.fov = lerpf(56.0, 64.0, blend)


func _pursuit_shot(index: int) -> void:
	pursuit[index].fire_at(_car.global_position + Vector3(-0.85, 0.75, 2.4))
	cue.emit("shot")


func _actor(role: Actor.Role, color: Color, center: Vector3) -> Actor:
	var actor := Actor.new()
	add_child(actor)
	actor.position = center
	actor.build(role, color)
	return actor


func _add_guards(group: Array[Actor], rows: Array[float], color: Color) -> void:
	for z in rows:
		for side in [-1.0, 1.0]:
			var guard := _actor(Actor.Role.GUARD, color, _floor_point(side * 1.65, z))
			guard.face(PARK)
			group.append(guard)


func _floor_point(x: float, z: float) -> Vector3:
	return Vector3(x, Palace.floor_height(z), z)


func _set_car_doors(tween: Tween, angle: float, duration: float) -> void:
	tween.parallel().tween_property(_doors[0], "rotation:y", -angle, duration)
	tween.parallel().tween_property(_doors[1], "rotation:y", angle, duration)


func _ready_shot(shooter: Actor, guard: Actor) -> void:
	guard.face(shooter.position)
	guard.left_arm.rotation.x = 0.72
	shooter.aim(guard.position)


func _fire(shooter: Actor, guard: Actor) -> void:
	var from := to_local(shooter.muzzle.global_position)
	var target := guard.position + Vector3.UP * 1.3
	var offset := target - from
	var beam := Shapes.box(_effects, Vector3(0.046, 0.046, offset.length()), (from + target) * 0.5, Color("#fff3a5"))
	beam.basis = Basis.looking_at(offset)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var burst := Shapes.box(_effects, Vector3(0.26, 0.26, 0.26), from, Color("#ffbb69"))
	burst.rotation = Vector3(0.4, 0.55, 0.6)
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cue.emit("shot")
	var recoil := _animation_tween().set_parallel().set_trans(Tween.TRANS_QUAD)
	recoil.tween_property(shooter.right_arm, "rotation:x", shooter.right_arm.rotation.x + 0.26, 0.07)
	var fall := guard.position + Vector3(0, 0.0, -0.63)
	fall.y = Palace.floor_height(fall.z) + 0.23
	var stair_drop := Palace.floor_height(fall.z) - Palace.floor_height(fall.z + 1.65)
	recoil.tween_property(guard, "rotation:x", -PI * 0.5 - atan2(stair_drop, 1.65), 0.42)
	recoil.tween_property(guard, "position", fall, 0.42)
	recoil.tween_callback(beam.queue_free).set_delay(0.075)
	recoil.tween_callback(burst.queue_free).set_delay(0.11)
	await recoil.finished


func _walk(tween: Tween, actor: Actor, target: Vector3, duration: float, on_floor: bool = false) -> void:
	actor.face(target)
	tween.parallel().tween_method(_step.bind(actor, actor.position, target, on_floor), 0.0, 1.0, duration)


func _step(t: float, actor: Actor, start: Vector3, target: Vector3, on_floor: bool) -> void:
	actor.walk(t, start, target)
	if on_floor:
		actor.position.y = Palace.floor_height(actor.position.z)


func _escort(tween: Tween, driver_x: float, z: float, friend_x: float, duration: float) -> void:
	_walk(tween, _driver, _floor_point(driver_x, z), duration, true)
	_walk(tween, _princess, _floor_point(driver_x - 0.83, z - 0.55), duration, true)
	_walk(tween, _friend, _floor_point(friend_x, z - 1.23), duration, true)
	tween.parallel().tween_method(_escort_pose, 0.0, 1.0, duration)


func _escort_pose(_time: float) -> void:
	_driver.right_arm.rotation = Vector3(-0.55, 0.0, 0.67)
	_princess.left_arm.rotation = Vector3(0.59, 0.0, -0.67)


func _drive(tween: Tween, target: Vector3, duration: float, easing: Tween.EaseType) -> void:
	tween.parallel().tween_method(_roll_car, _car.global_position, to_global(target), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(easing)


func _turn_car(angle: float) -> void:
	_car.rotation.y = -angle
	var offset := Vector3(TURN_RADIUS * (1.0 - cos(angle)), 0, -TURN_RADIUS * sin(angle))
	_roll_car(to_global(PARK + offset))


func _roll_car(target: Vector3) -> void:
	var travel := _car.global_position.distance_to(target)
	_car.global_position = target
	for wheel in _car.wheels:
		wheel.rotate_x(travel / 0.36)


func _frame(eye: Vector3, focus: Vector3) -> void:
	_camera.position = eye
	_camera.look_at(to_global(focus))


func _camera_move(eye: Vector3, focus: Vector3, duration: float) -> Tween:
	var tween := _animation_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "position", eye, duration)
	var angle := Basis.looking_at(focus - eye).get_euler()
	tween.tween_property(_camera, "rotation", angle, duration)
	return tween


func _hold(duration: float) -> Signal:
	var tween := _animation_tween()
	tween.tween_interval(duration)
	return tween.finished
