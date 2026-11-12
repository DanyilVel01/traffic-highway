extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const Actor = preload("res://scripts/finale_actor.gd")
const PlayerCar = preload("res://scripts/player_car.gd")
const Police = preload("res://scripts/chase_police.gd")
const DIALOGUE: Array[String] = [
	"Guys, what do we do now? The road just ends.",
	"Look at those clouds. We're way too high to jump.",
	"The police are getting closer. We can't go back.",
	"Take my hands. Whatever happens, we stay together.",
	"Wait. Do you hear that?",
]
const VOICES: Array[AudioStream] = [
	preload("res://assets/rescue/line_01.wav"),
	preload("res://assets/rescue/line_02.wav"),
	preload("res://assets/rescue/line_03.wav"),
	preload("res://assets/rescue/line_04.wav"),
	preload("res://assets/rescue/line_05.wav"),
]
const SPEAKERS: Array[String] = ["Erik", "PARTNER", "PRINCESS", "Erik", "PARTNER"]
const SPEAKER_INDEX: Array[int] = [1, 0, 2, 1, 0]
const PILOT_REVEAL := preload("res://assets/rescue/line_06.wav")
const ESCAPE_VOICES: Array[AudioStream] = [
	preload("res://assets/escape/line_01.wav"),
	preload("res://assets/escape/line_02.wav"),
	preload("res://assets/escape/line_03.wav"),
	preload("res://assets/escape/line_04.wav"),
	preload("res://assets/escape/line_05.wav"),
	preload("res://assets/escape/line_06.wav"),
	preload("res://assets/escape/line_07.wav"),
]

signal subtitle_changed(speaker: String, line: String)
signal finished
signal shot

var _camera: Camera3D
var _crew: Array[Actor] = []
var _police: Array[Police] = []
var _helicopter: Node3D
var _rotor: Node3D
var _tail_rotor: Node3D
var _broken_blade: MeshInstance3D
var _pilot: Actor
var _parachutes: Array[MeshInstance3D] = []
var _jumpers: Array[Actor] = []
var _rotor_speed: float = 41.0
var _fall_time: float = 0.0
var _falling: bool = false
var _voice: AudioStreamPlayer
var _edge: float


func play(car: PlayerCar, police: Array[Police], edge_z: float, aboard: bool = false) -> void:
	_edge = edge_z
	_police = police
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.make_current()
	_voice = AudioStreamPlayer.new()
	_voice.bus = &"Effects"
	_voice.volume_db = -4.0
	add_child(_voice)
	_build_clouds()
	if aboard:
		_build_helicopter()
		_helicopter.position = Vector3(0, 0.18, _edge - 5.9)
		var colors: Array[Color] = [Color("#bd773b"), Color("#306c77"), Color("#c464ae")]
		for index in colors.size():
			var role := Actor.Role.PRINCESS if index == 2 else Actor.Role.DRIVER
			_add_actor(role, colors[index], _helicopter.position + Vector3((index - 1) * 0.81, 0.69, 0.66))
			_crew[index].reparent(_helicopter)
			_crew[index].scale.y = 0.78
		car.position = Vector3(1.8, car.position.y, _edge + 3.05)
	else:
		await _stop_and_exit(car)
		await _talk_at_edge()
		await _bring_helicopter()
		await _jump_to_helicopter()
	await _police_take_shot()
	await _escape_damaged_helicopter()
	finished.emit()


func _process(delta: float) -> void:
	for police in _police:
		if is_instance_valid(police):
			police.animate(delta, 0.0)
	if is_instance_valid(_rotor):
		_rotor.rotate_y(delta * _rotor_speed)
		_tail_rotor.rotate_x(delta * 53.0)
	if _falling:
		_fall_time += delta
		_helicopter.rotation = Vector3(sin(_fall_time * 2.4) * 0.24, _fall_time * 1.23,
			-0.22 + sin(_fall_time * 3.0) * 0.19)
		_helicopter.position += Vector3(0.68, -1.07 - _fall_time * 0.035, -0.82) * delta
	for actor in _jumpers:
		actor.position.y -= 3.0 * delta


func _stop_and_exit(car: PlayerCar) -> void:
	var parked := Vector3(1.8, 0, _edge + 3.05)
	_frame(Vector3(-5.2, 4.1, _edge + 8.4), Vector3(0, 1.0, _edge - 1.4))
	var stop := _dolly(Vector3(-4.4, 3.5, _edge + 6.4), Vector3(0.5, 0.95, _edge + 0.4), 2.4)
	stop.tween_property(car, "global_position", to_global(parked), 2.0)
	stop.tween_property(car, "rotation:y", 0.0, 0.65)
	await stop.finished
	var doors: Array[Node3D] = []
	for child in car.visual.get_children():
		if child.is_in_group(&"cinematic_door"):
			doors.append(child)
	var opening := create_tween().set_parallel()
	opening.tween_interval(0.75)
	for index in doors.size():
		opening.tween_property(doors[index], "rotation:y", -1.02 if index == 0 else 1.02, 0.55)
	await opening.finished
	_add_actor(Actor.Role.DRIVER, Color("#bd773b"), parked + Vector3(-0.5, 0.52, 0.62))
	_add_actor(Actor.Role.DRIVER, Color("#306c77"), parked + Vector3(-0.46, 0.52, 0.04))
	_add_actor(Actor.Role.PRINCESS, Color("#c464ae"), parked + Vector3(0.49, 0.52, 0.12))
	var exit_car := create_tween().set_parallel()
	_walk(exit_car, _crew[0], parked + Vector3(-1.55, 0, 0.72), 1.05)
	_walk(exit_car, _crew[1], parked + Vector3(-1.55, 0, -0.27), 1.20)
	_walk(exit_car, _crew[2], parked + Vector3(1.60, 0, -1.95), 1.15)
	await exit_car.finished
	var approach := _dolly(Vector3(-5.1, 3.35, _edge + 1.25), Vector3(0.0, 1.0, _edge + 0.65), 3.4)
	for index in _crew.size():
		_walk(approach, _crew[index], Vector3((index - 1) * 1.32, 0, _edge + 0.63), 2.95 + index * 0.16)
	for door in doors:
		approach.tween_property(door, "rotation:y", 0.0, 0.50)
	await approach.finished


func _talk_at_edge() -> void:
	for index in DIALOGUE.size():
		var speaker := _crew[SPEAKER_INDEX[index]]
		var other := _crew[2] if SPEAKER_INDEX[index] != 2 else _crew[1]
		speaker.face(other.position)
		other.face(speaker.position)
		var side := -1.0 if index % 2 == 0 else 1.0
		var eye := Vector3(side * 4.0, 2.5, _edge - 2.95)
		var focus := Vector3(speaker.position.x * 0.32, 1.1, _edge + 0.69)
		_frame(eye, focus)
		subtitle_changed.emit(SPEAKERS[index], DIALOGUE[index])
		var line := VOICES[index]
		var shot := _dolly(eye.lerp(focus, 0.14), focus, 4.0)
		shot.tween_method(_gesture.bind(speaker), 0.0, line.get_length(), line.get_length())
		_play_voice(line)
		await shot.finished
		speaker.speak_pose(0.0, 0.0)
	subtitle_changed.emit("", "")
	for actor in _crew:
		actor.rotation.y = 0.0
		actor.rotation.x = -0.12
	_crew[0].right_arm.rotation.z = 0.93
	_crew[1].left_arm.rotation.z = -0.93
	_crew[1].right_arm.rotation.z = 0.93
	_crew[2].left_arm.rotation.z = -0.93
	_frame(Vector3(1.1, 4.2, _edge + 2.7), Vector3(0.2, -7.3, _edge - 7.5))
	await _dolly(Vector3(0.4, 3.75, _edge + 1.8), Vector3(0, -10.5, _edge - 8.0), 3.8).finished
	for actor in _crew:
		actor.rotation.x = 0.0


func _bring_helicopter() -> void:
	_build_helicopter()
	var hover := Vector3(0, 0.18, _edge - 5.9)
	_helicopter.position = hover + Vector3(-38, -12, -21)
	_helicopter.rotation.z = -0.19
	_frame(Vector3(7.6, 3.5, _edge + 2.9), Vector3(-4.2, 0.25, _edge - 7.5))
	var arrival := _dolly(Vector3(7.1, 3.55, _edge + 3.8), Vector3(0, 1.1, _edge - 3.3), 5.15)
	arrival.tween_property(_helicopter, "position", hover, 4.85).set_ease(Tween.EASE_OUT)
	arrival.tween_property(_helicopter, "rotation:z", 0.0, 4.7)
	arrival.tween_callback(_announce_pilot).set_delay(2.2)
	await arrival.finished
	subtitle_changed.emit("", "")


func _announce_pilot() -> void:
	subtitle_changed.emit("Erik", "That's my friend! Go for the open door.")
	_play_voice(PILOT_REVEAL)


func _play_voice(clip: AudioStream) -> void:
	if DisplayServer.get_name() != "headless":
		_voice.stream = clip
		_voice.play()


func _jump_to_helicopter() -> void:
	var retreat := _dolly(Vector3(-6.5, 3.45, _edge + 3.6), Vector3(0, 1, _edge - 0.8), 2.6)
	for index in _crew.size():
		var actor := _crew[index]
		actor.left_arm.rotation.z = 0.0
		actor.right_arm.rotation.z = 0.0
		_walk(retreat, actor, Vector3(-2.7 + (index - 1) * 0.95, 0, _edge + 5.9), 2.6)
	await retreat.finished
	var run := _dolly(Vector3(-6.2, 3.0, _edge + 0.55), Vector3(0, 1.0, _edge - 1.0), 1.35)
	for index in _crew.size():
		_walk(run, _crew[index], Vector3((index - 1) * 1.02, 0, _edge + 0.09), 1.35)
	await run.finished
	_frame(Vector3(-7.5, 3.0, _edge - 1.1), Vector3(0, 1.0, _edge - 3.0))
	var leap := _dolly(Vector3(-6.0, 2.85, _edge - 3.4), Vector3(0, 1.0, _edge - 4.2), 4.5)
	for index in _crew.size():
		var actor := _crew[index]
		var seat := _helicopter.position + Vector3((index - 1) * 0.81, 0.69, 0.66)
		leap.tween_method(_leap.bind(actor, actor.position, seat), 0.0, 1.0, 3.85).set_delay(index * 0.22)
	await leap.finished
	for actor in _crew:
		actor.reparent(_helicopter)


func _police_take_shot() -> void:
	_frame(Vector3(6.9, 4.0, _edge + 2.1), Vector3(0, 1.35, _edge - 7.5))
	var lift := _dolly(Vector3(7.6, 4.8, _edge + 1.7), Vector3(2.0, 2.6, _edge - 10.0), 2.3)
	lift.tween_property(_helicopter, "position", Vector3(3.2, 2.25, _edge - 11.6), 2.3)
	for index in _police.size():
		lift.tween_property(_police[index], "position:x", -2.75 if index == 0 else 2.75, 1.3)
	await lift.finished
	var officers: Array[Actor] = []
	var exit_cars := create_tween().set_parallel()
	exit_cars.tween_interval(1.35)
	for index in _police.size():
		var police := _police[index]
		var parked := to_local(police.global_position)
		var officer := Actor.new()
		add_child(officer)
		officer.build(Actor.Role.DRIVER, Color("#303e68"))
		Shapes.box(officer, Vector3(0.50, 0.14, 0.48), Vector3(0, 2.06, 0), Color("#1a2846"))
		Shapes.box(officer, Vector3(0.13, 0.15, 0.022), Vector3(-0.14, 1.37, -0.20), Color("#e4b866"))
		officer.position = parked + Vector3(-0.47, 0.56, 0.1)
		officers.append(officer)
		exit_cars.tween_property(police.driver_door, "rotation:y", -1.07, 0.40)
		_walk(exit_cars, officer, parked + Vector3(-1.46, 0, -0.38), 1.15)
	if officers.is_empty():
		return
	var shooter := officers[0]
	_frame(shooter.position + Vector3(-5.6, 3.0, -4.2), shooter.position + Vector3(2.25, 1.05, 2.0))
	await exit_cars.finished
	for officer in officers:
		officer.face(_helicopter.position)
	_say("POLICE", "Get them! Don't let them get away!", 0)
	await _hold(2.25)
	shooter.aim(_helicopter.position + Vector3.UP * 3.5)
	await _hold(0.45)
	subtitle_changed.emit("", "")
	shot.emit()
	await _follow_bullet(to_local(shooter.muzzle.global_position))


func _follow_bullet(muzzle: Vector3) -> void:
	_rotor_speed = 0.0
	_rotor.rotation.y = 0.22
	var impact := to_local(_rotor.to_global(Vector3(3.2, 0, 0)))
	var direction := (impact - muzzle).normalized()
	var bullet := Node3D.new()
	add_child(bullet)
	bullet.position = muzzle
	bullet.basis = Basis.looking_at(direction)
	var tip := CapsuleMesh.new()
	tip.radius = 0.055
	tip.height = 0.36
	tip.radial_segments = 10
	tip.rings = 4
	Shapes.attach(bullet, tip, Vector3.ZERO, Color("#efb855")).rotation.x = PI * 0.5
	var trail := Shapes.box(bullet, Vector3(0.016, 0.016, 0.72), Vector3(0, 0, 0.49), Color("#ffdf92"))
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flight := create_tween()
	flight.tween_method(_bullet_view.bind(bullet, muzzle, impact, direction), 0.0, 1.0, 3.55)
	await flight.finished
	bullet.queue_free()
	_broken_blade.hide()
	var fragment := Shapes.box(self, Vector3(4.9, 0.09, 0.31), impact, Color("#28364e"))
	var burst := Shapes.box(self, Vector3(0.53, 0.53, 0.53), impact, Color("#ffd55b"))
	var spark := create_tween().set_parallel()
	spark.tween_property(fragment, "position", impact + Vector3(8, -10, -4), 1.0)
	spark.tween_property(fragment, "rotation", Vector3(2.0, 4.0, 1.5), 1.0)
	spark.tween_property(burst, "scale", Vector3.ZERO, 0.35)
	spark.tween_callback(fragment.queue_free).set_delay(1.0)
	spark.tween_callback(burst.queue_free).set_delay(0.36)
	_rotor_speed = 11.0
	_falling = true
	_frame(_helicopter.position + Vector3(8.0, 3.5, 7.2), _helicopter.position + Vector3.UP * 1.4)
	await _hold(1.8)


func _bullet_view(t: float, bullet: Node3D, muzzle: Vector3, impact: Vector3, direction: Vector3) -> void:
	bullet.position = muzzle.lerp(impact, t)
	var eye := bullet.position - direction * 1.8 + Vector3(0.62, 0.38, 0)
	_frame(eye, bullet.position + direction * 0.75)
	_camera.fov = 49.0


func _escape_damaged_helicopter() -> void:
	for actor in _crew:
		actor.left_arm.rotation.x = 0.96
		actor.right_arm.rotation.x = 0.65
	_cabin_view(Vector3(1.04, 2.29, -0.66), Vector3(-0.42, 1.53, 0.54))
	_say("Erik", "What was that? We're spinning!", 1)
	await _hold(2.4)
	_say("PRINCESS", "We're going to die!", 2)
	await _hold(1.7)
	_cabin_view(Vector3(-0.78, 2.23, -0.58), Vector3(1.66, 1.60, 0.33))
	_say("PILOT", "Grab the parachutes! Jump, one at a time!", 3)
	_pilot.speak_pose(1.0, 0.48)
	await _hold(3.05)
	_pilot.speak_pose(0.0, 0.0)
	var lines: Array[String] = ["I can't see the ground.", "I can't do this. I can't.", "Okay. Here I go."]
	var speakers: Array[String] = ["PARTNER", "PRINCESS", "Erik"]
	var order: Array[int] = [0, 2, 1]
	for index in order.size():
		await _parachute_jump(_crew[order[index]], index, speakers[index], lines[index])
	subtitle_changed.emit("", "")
	_falling = false


func _parachute_jump(actor: Actor, index: int, speaker: String, line: String) -> void:
	var door_x := -0.42 + (index - 1) * 0.45
	_cabin_view(Vector3(0.94, 2.20, -0.74), Vector3(door_x, 1.24, 0.69))
	actor.rotation.y = 0.0
	var reach := create_tween()
	reach.tween_property(actor.right_arm, "rotation:x", 1.23, 0.42)
	await reach.finished
	_parachutes[index].hide()
	Shapes.box(actor, Vector3(0.50, 0.66, 0.27), Vector3(0, 1.23, 0.30), Color("#526648"))
	actor.right_arm.rotation.x = 0.0
	actor.left_arm.rotation.x = 0.0
	var exit_path := create_tween()
	exit_path.tween_property(actor, "position", Vector3(door_x, 0.69, 0.86), 0.84)
	await exit_path.finished
	actor.rotation.y = PI
	actor.rotation.x = -0.17
	_say(speaker, line, index + 4)
	await _hold(1.45)
	_cabin_view(Vector3(door_x, 1.62, 1.27), Vector3(door_x, -8.0, 4.8))
	await _hold(0.70)
	subtitle_changed.emit("", "")
	if index == 2:
		# The camera and steering transfer to the player as the driver leaves the cabin.
		var takeoff := create_tween()
		takeoff.tween_property(actor, "position:z", 1.24, 0.17)
		await takeoff.finished
		return
	_camera.reparent(self)
	actor.reparent(self)
	var start := actor.position
	var target := start + Vector3((index - 1) * 3.8, -13.0, 4.1)
	var dive := create_tween()
	dive.tween_method(_dive_view.bind(actor, start, target), 0.0, 1.0, 2.45)
	await dive.finished
	actor.rotation = Vector3(0.0, PI, 0.0)
	_open_canopy(actor, index)
	await _hold(0.68)


func _dive_view(t: float, actor: Actor, start: Vector3, target: Vector3) -> void:
	actor.position = start.lerp(target, t * t)
	actor.rotation = Vector3(lerpf(-0.44, -PI, smoothstep(0.0, 0.80, t)), PI, 0.0)
	actor.left_arm.rotation.x = 1.22
	actor.right_arm.rotation.x = 1.22
	_frame(actor.position + Vector3(5.4, 2.4, 5.3), actor.position + Vector3(0, -0.80, 0))


func _open_canopy(actor: Actor, index: int) -> void:
	var canopy := Node3D.new()
	add_child(canopy)
	canopy.position = actor.position + Vector3.UP * 1.8
	var dome := SphereMesh.new()
	dome.is_hemisphere = true
	dome.radial_segments = 12
	dome.rings = 5
	var colors: Array[Color] = [Color("#f0a447"), Color("#d573b0"), Color("#66c9cc")]
	var top := Shapes.attach(canopy, dome, Vector3.UP * 2.6, colors[index])
	top.scale = Vector3(6.2, 2.55, 4.8)
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			var rim := Vector3(side * 2.35, 2.62, depth * 1.35)
			var rope := Shapes.box(canopy, Vector3(0.029, 0.029, rim.length()), rim * 0.5, Color("#f4f0df"))
			rope.basis = Basis.looking_at(rim)
	canopy.reparent(actor)
	canopy.scale *= 0.12
	create_tween().tween_property(canopy, "scale", Vector3.ONE / actor.scale, 0.54).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_jumpers.append(actor)


func _cabin_view(eye: Vector3, focus: Vector3) -> void:
	if _camera.get_parent() != _helicopter:
		_camera.reparent(_helicopter, false)
	_camera.position = eye
	_camera.look_at(_helicopter.to_global(focus), _helicopter.global_basis.y)
	_camera.fov = 69.0


func _say(speaker: String, line: String, clip: int) -> void:
	subtitle_changed.emit(speaker, line)
	_play_voice(ESCAPE_VOICES[clip])


func _hold(seconds: float) -> Signal:
	var tween := create_tween()
	tween.tween_interval(seconds)
	return tween.finished


func _build_helicopter() -> void:
	_helicopter = Node3D.new()
	add_child(_helicopter)
	var red := Color("#a23144")
	var white := Color("#f1dbc0")
	var dark := Color("#28364e")
	Shapes.box(_helicopter, Vector3(4.3, 0.34, 2.15), Vector3(0.12, 0.49, 0), red)
	Shapes.box(_helicopter, Vector3(4.2, 0.28, 2.03), Vector3(0.20, 2.63, 0), white)
	Shapes.box(_helicopter, Vector3(3.5, 2.0, 0.18), Vector3(-0.4, 1.57, -0.97), red)
	Shapes.box(_helicopter, Vector3(0.42, 2.06, 2.07), Vector3(-1.94, 1.57, 0), red)
	Shapes.box(_helicopter, Vector3(1.12, 0.73, 1.91), Vector3(1.73, 0.94, 0), dark)
	Shapes.box(_helicopter, Vector3(1.12, 1.35, 0.12), Vector3(1.73, 1.94, -0.94), Color("#77a3b7"))
	Shapes.box(_helicopter, Vector3(0.48, 1.0, 1.71), Vector3(2.42, 1.28, 0), red)
	Shapes.box(_helicopter, Vector3(0.15, 1.28, 0.16), Vector3(2.30, 1.98, 0.93), white)
	Shapes.box(_helicopter, Vector3(3.7, 0.39, 0.42), Vector3(-3.93, 1.75, 0), red)
	Shapes.box(_helicopter, Vector3(0.31, 1.03, 0.54), Vector3(-5.72, 2.09, 0), white)
	for side in [-1.0, 1.0]:
		Shapes.box(_helicopter, Vector3(4.6, 0.13, 0.15), Vector3(0.19, 0, side * 1.10), dark)
		for x in [-1.34, 1.31]:
			Shapes.box(_helicopter, Vector3(0.14, 0.53, 0.13), Vector3(x, 0.25, side * 1.10), dark)
	_pilot = Actor.new()
	_helicopter.add_child(_pilot)
	_pilot.position = Vector3(1.82, 0.63, 0.41)
	_pilot.scale = Vector3.ONE * 0.69
	_pilot.rotation.y = PI * 0.5
	_pilot.build(Actor.Role.DRIVER, Color("#8275b2"))
	for x in [-0.81, 0.81, 0.0]:
		var pack := Shapes.box(_helicopter, Vector3(0.48, 0.64, 0.25), Vector3(x, 1.35, -0.76), Color("#526648"))
		Shapes.box(pack, Vector3(0.40, 0.10, 0.05), Vector3(0, 0.12, 0.14), Color("#e1b562"))
		_parachutes.append(pack)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0.25, 3.73, 0)
	_helicopter.add_child(_rotor)
	Shapes.box(_helicopter, Vector3(0.19, 1.04, 0.19), Vector3(0.25, 3.24, 0), dark)
	Shapes.box(_rotor, Vector3(5.1, 0.06, 0.27), Vector3(-2.55, 0, 0), dark)
	_broken_blade = Shapes.box(_rotor, Vector3(5.1, 0.06, 0.27), Vector3(2.55, 0, 0), dark)
	Shapes.box(_rotor, Vector3(0.27, 0.06, 9.0), Vector3.ZERO, dark)
	_tail_rotor = Node3D.new()
	_tail_rotor.position = Vector3(-5.78, 2.16, 0.15)
	_helicopter.add_child(_tail_rotor)
	Shapes.box(_tail_rotor, Vector3(0.09, 1.72, 0.12), Vector3.ZERO, dark)
	Shapes.box(_tail_rotor, Vector3(0.09, 0.12, 1.62), Vector3.ZERO, dark)


func _build_clouds() -> void:
	var cloud := SphereMesh.new()
	cloud.radial_segments = 9
	cloud.rings = 4
	for index in 7:
		var center := Vector3((index - 3) * 13.0, -21.0 - float(index % 3) * 7.0, _edge - 27.0 - float(index % 2) * 14.0)
		var puff := Shapes.attach(self, cloud, center, Color("#eaf0ff"))
		puff.scale = Vector3(22.0, 7.0, 16.0)


func _add_actor(role: Actor.Role, color: Color, at: Vector3) -> void:
	var actor := Actor.new()
	add_child(actor)
	actor.position = at
	actor.build(role, color)
	_crew.append(actor)


func _walk(tween: Tween, actor: Actor, target: Vector3, duration: float) -> void:
	actor.face(target)
	tween.tween_method(actor.walk.bind(actor.position, target), 0.0, 1.0, duration)


func _leap(t: float, actor: Actor, start: Vector3, target: Vector3) -> void:
	actor.position = start.lerp(target, t) + Vector3.UP * (sin(PI * t) * 1.14)
	actor.rotation.x = -sin(PI * t) * 0.40
	actor.left_arm.rotation.x = sin(PI * t) * 1.55
	actor.right_arm.rotation.x = sin(PI * t) * 1.55
	actor.scale.y = lerpf(1.0, 0.78, smoothstep(0.66, 1.0, t))


func _gesture(t: float, actor: Actor) -> void:
	actor.speak_pose(absf(sin(t * 19.0)), 0.28 + 0.23 * sin(t * 4.3))


func _frame(eye: Vector3, target: Vector3) -> void:
	_camera.position = eye
	_camera.look_at(to_global(target))
	_camera.fov = 58.0


func _dolly(eye: Vector3, target: Vector3, seconds: float) -> Tween:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "position", eye, seconds)
	tween.tween_property(_camera, "rotation", Basis.looking_at(target - eye).get_euler(), seconds)
	return tween
