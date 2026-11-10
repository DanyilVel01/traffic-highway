extends Node3D

const Set = preload("res://scripts/intro_set.gd")
const Actor = preload("res://scripts/finale_actor.gd")
const PlayerCar = preload("res://scripts/player_car.gd")
const DIALOGUE: Array[String] = [
	"See this road? It drops straight into Crystal Cavern.",
	"And the beetles have the right of way. Got it.",
	"Back on the highway, take the right-hand ramp at five kilometers.",
	"Through the clouds, past the chariots. Then the castle.",
	"At ten kilometers, we park. I take the left stairs.",
	"I'll take the right. We meet at the double doors.",
	"We grab the princess from the throne room, then back to the car.",
	"All three seats. One way out. Let's go.",
]
const VOICES: Array[AudioStream] = [
	preload("res://assets/intro/line_01.wav"),
	preload("res://assets/intro/line_02.wav"),
	preload("res://assets/intro/line_03.wav"),
	preload("res://assets/intro/line_04.wav"),
	preload("res://assets/intro/line_05.wav"),
	preload("res://assets/intro/line_06.wav"),
	preload("res://assets/intro/line_07.wav"),
	preload("res://assets/intro/line_08.wav"),
]
const LINE_DURATION: float = 4.5

signal subtitle_changed(speaker: String, text: String)
signal engine_started
signal finished

var _set: Set
var _camera: Camera3D
var _driver: Actor
var _friend: Actor
var _car: PlayerCar
var _doors: Array[Node3D]
var _voice: AudioStreamPlayer


func play(car_index: int, chase_camera: Camera3D) -> void:
	_set = Set.new()
	add_child(_set)
	_set.build()
	_car = PlayerCar.new()
	add_child(_car)
	_car.position = Set.PARK
	_car.build(car_index)
	_doors = _car.install_cinematic_doors()
	_driver = _actor(Vector3(2.38, 0, 0.43), Color("#306c77"))
	_friend = _actor(Vector3(5.12, 0, -0.64), Color("#bd773b"))
	_driver.face(_friend.position)
	_friend.face(_driver.position)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.make_current()
	_voice = AudioStreamPlayer.new()
	_voice.bus = &"Effects"
	_voice.volume_db = -4.0
	add_child(_voice)

	_frame(Vector3(-5.0, 3.65, 5.2), Vector3(2.25, 1.05, -0.25), 61.0)
	await _camera_move(Vector3(-4.1, 3.3, 4.4), Vector3(2.4, 1.1, -0.2), 1.8).finished
	for index in DIALOGUE.size():
		await _speak(index)
	subtitle_changed.emit("", "")
	await _board_car()
	engine_started.emit()
	var drive := create_tween()
	drive.tween_method(_drive.bind(chase_camera.position, chase_camera.quaternion, chase_camera.fov), 0.0, 1.0, 8.0)
	await drive.finished
	finished.emit()


func stop() -> void:
	_voice.stop()
	hide()


func _actor(offset: Vector3, color: Color) -> Actor:
	var actor := Actor.new()
	add_child(actor)
	actor.position = Set.PARK + offset
	actor.build(Actor.Role.DRIVER, color)
	return actor


func _speak(index: int) -> void:
	var driver_speaks := index % 2 == 0
	var speaker := _driver if driver_speaks else _friend
	var voice := VOICES[index]
	subtitle_changed.emit("DRIVER" if driver_speaks else "PARTNER", DIALOGUE[index])
	var eye := Vector3(5.78, 2.62, 3.35) if driver_speaks else Vector3(1.18, 2.52, -3.30)
	var focus := Vector3(3.45, 1.42, -0.03)
	if index == 2 or index == 4:
		eye = Vector3(2.30, 4.30, 2.18)
		focus = Vector3(3.73, 1.12, 0.08)
	_frame(eye, focus, 55.0)
	var shot := _camera_move(eye.lerp(focus, 0.12), focus, LINE_DURATION)
	var spoken_duration := minf(voice.get_length(), LINE_DURATION)
	shot.parallel().tween_method(_gesture.bind(speaker), 0.0, spoken_duration, spoken_duration)
	if DisplayServer.get_name() != "headless":
		_voice.stream = voice
		_voice.play()
	await shot.finished
	speaker.speak_pose(0.0, 0.0)


func _gesture(elapsed: float, speaker: Actor) -> void:
	var motion := absf(sin(elapsed * 21.0)) * (0.55 + 0.45 * sin(elapsed * 8.0))
	speaker.speak_pose(motion, 0.50 + sin(elapsed * 3.1) * 0.36)


func _board_car() -> void:
	_frame(Vector3(-5.4, 3.65, 5.8), Vector3(0.7, 0.95, 0.12), 61.0)
	var leave_table := _camera_move(Vector3(-4.8, 3.32, 4.9), Vector3(0.42, 1.1, 0.27), 1.25)
	_walk(leave_table, _driver, Vector3(1.66, 0, 2.57), 1.25)
	_walk(leave_table, _friend, Vector3(1.65, 0, -0.52), 1.12)
	await leave_table.finished
	var cross := create_tween().set_parallel()
	_walk(cross, _driver, Vector3(-1.66, 0, 2.57), 1.15)
	_walk(cross, _friend, Vector3(1.63, 0, 0), 0.26)
	cross.tween_property(_doors[1], "rotation:y", 1.06, 0.29)
	await cross.finished
	var enter := create_tween().set_parallel()
	_walk(enter, _driver, Vector3(-1.61, 0, 0), 0.80)
	_walk(enter, _friend, Vector3(0.34, 0.55, 0.1), 0.62)
	enter.tween_callback(_friend.hide).set_delay(0.62)
	enter.tween_property(_doors[0], "rotation:y", -1.06, 0.30).set_delay(0.48)
	await enter.finished
	var ready := create_tween().set_parallel()
	_walk(ready, _driver, Vector3(-0.34, 0.55, 0.1), 0.62)
	ready.tween_callback(_driver.hide).set_delay(0.62)
	ready.tween_property(_doors[0], "rotation:y", 0.0, 0.30).set_delay(0.68)
	ready.tween_property(_doors[1], "rotation:y", 0.0, 0.30)
	ready.tween_property(_set.shutter, "scale:y", 0.045, 1.0).set_trans(Tween.TRANS_QUAD)
	await ready.finished


func _walk(tween: Tween, actor: Actor, offset: Vector3, duration: float) -> void:
	var destination := Set.PARK + offset
	actor.face(destination)
	tween.parallel().tween_method(actor.walk.bind(actor.position, destination), 0.0, 1.0, duration)


func _drive(t: float, chase_offset: Vector3, chase_angle: Quaternion, chase_fov: float) -> void:
	# Starts at rest and reaches the gameplay starting speed at the camera handoff.
	var z := Set.PARK.z - t * t * (282.0 - 140.0 * t)
	var destination := Vector3(Set.street_x(z), 0.0, z)
	var travel := _car.position.distance_to(destination)
	_car.position = destination
	_car.rotation.y = atan2(Set.street_x(z + 1.0) - Set.street_x(z - 1.0), 2.0)
	for wheel in _car.wheels:
		wheel.rotate_x(travel / 0.36)
	var blend := smoothstep(0.26, 0.92, t)
	var side := lerpf(1.35, 4.65, smoothstep(0.20, 0.40, t))
	_camera.position = destination + Vector3(side, 2.85, -7.6).lerp(chase_offset, blend)
	var view := Basis.looking_at(destination + Vector3.UP * 0.95 - _camera.position).get_rotation_quaternion()
	_camera.quaternion = view.slerp(chase_angle, smoothstep(0.74, 0.96, t))
	_camera.fov = lerpf(61.0, chase_fov, blend)


func _frame(eye: Vector3, focus: Vector3, fov: float) -> void:
	_camera.position = Set.PARK + eye
	_camera.look_at(Set.PARK + focus)
	_camera.fov = fov


func _camera_move(eye: Vector3, focus: Vector3, duration: float) -> Tween:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "position", Set.PARK + eye, duration)
	tween.tween_property(_camera, "rotation", Basis.looking_at(focus - eye).get_euler(), duration)
	return tween
