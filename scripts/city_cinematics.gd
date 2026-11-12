extends Node3D

const Actor = preload("res://scripts/finale_actor.gd")
const Shapes = preload("res://scripts/vehicle_visual.gd")
const DURATION := 20.0

signal subtitle(line: String)
signal clip_finished
signal fired(at: Vector3)
signal siren

enum Shot { LANDING, CAFE, LEDGER, STREET, BUS, REUNION, AMBUSH, WRECK, RESCUE, RADIO_ARRIVAL, BROADCAST, BREACH, BOMBER, PURSUIT, BOARD }

const CLIPS := [
	["Landing", ["Erik / Can anyone hear me?", "Pilot / I survived the crash. I can see a river.", "Friend / My chute pulled me toward the city.", "Princess / Meet me at Ridge & Roast. I still have the ledger."]],
	["At the cafe", ["Erik / You chose the cafe before we jumped?", "Princess / I chose it before you ever entered the castle.", "Erik / You were the one who sent the plans.", "Princess / Sit down. There is something I need you to see."]],
	["The ledger", ["Princess / Every name in this book belongs to someone taken from the ground.", "Erik / These are railway transfers.", "Princess / The pilot's sister is on the last page.", "Erik / Then we get him back and put those names on the air."]],
	["The first cordon", ["Dispatch / Seal the east exits. Keep the buses running.", "Officer / What about the people on the sidewalk?", "Dispatch / Let them through. We're looking for the crew from the castle.", "Officer / Copy. Moving the first cars into position."]],
	["The bus pulls in", ["Friend / Erik, I'm on the Ridge City bus.", "Bus driver / This is our last stop. The road is blocked ahead.", "Friend / Can you open the side door?", "Bus driver / Stay behind the shelter until those cars pass."]],
	["Reunion at the bus", ["Erik / You took public transport in the middle of a manhunt?", "Friend / I left my car several thousand feet above us.", "Princess / We heard the pilot. The river is our best lead.", "Friend / Show me where. I'll come with you."]],
	["Police ambush", ["Officer / Visual confirmed. Send the second unit.", "Dispatch / Flank through the next street. More cars are coming.", "Friend / They saw us. Get behind the bus.", "Erik / When I move, head for the highway."]],
	["The wreck", ["Pilot / Over here! I can't see past the smoke.", "Erik / Keep talking. We're on the bank.", "Pilot / The tail broke off when I hit the ground.", "Friend / I see him. Give me a hand with the door."]],
	["Rescuing the pilot", ["Friend / On three. One, two, three.", "Pilot / Wait. Did you get the ledger?", "Princess / Your sister's name is in it. She's still alive.", "Pilot / Take me to Ridge Radio. They can reach both cities."]],
	["Ridge Radio", ["Erik / The transmitter is still on.", "Friend / I'll watch the door. You take the microphone.", "Pilot / Set the frequency to the emergency channel.", "Princess / Leave it open. Someone might answer."]],
	["Live broadcast", ["Princess / This is Ridge Radio. If someone in your family went missing, listen closely.", "Princess / The palace kept a record of every prisoner transferred to the old station.", "Pilot / Elena. Your name is here. If you can hear me, find the tunnel beneath platform two.", "Voice on radio / I hear you. There are dozens of us down here."]],
	["The station is surrounded", ["Dispatch / All cars to the radio station. Cover both exits.", "Officer / The rear team is in position. Take the stairs.", "Friend / They have the street and the back door.", "Erik / We make a run for the car when the lights go out."]],
	["The warning", ["Dispatcher / Unidentified bomber approaching Ridge City.", "Pilot / That is an emergency strike code. Two minutes to the drop.", "Princess / Ridge City, take shelter. Anyone at the station, get into the tunnels.", "Pilot / The test rocket is ready. Get to the car. I'll start the launch sequence."]],
	["Highway pursuit", ["Dispatch / Convoy, target is westbound. Send more units to the launch road.", "Friend / Two on the right. More coming up behind us.", "Pilot / Keep west. The rocket is on the left beyond the overpass.", "Princess / The lift is our way in. We'll cover each other."]],
	["Boarding tower", ["Pilot / Lift is up. Take the ladder to the platform.", "Friend / There are police coming through the gate.", "Erik / Princess, go first. I'll close the hatch.", "Pilot / Everyone strap in. We're launching now."]],
]

var active := false
var title := ""
var _camera: Camera3D
var _set: Node3D
var _cast: Array[Actor] = []
var _roles: Array[String] = []
var _start: Array[Vector3] = []
var _vehicles: Array[Node3D] = []
var _focus: Vector3
var _shot: Shot
var _elapsed := 0.0
var _line := -1
var _last_shot := 0
var _lift: Node3D
var _chute: MeshInstance3D


func play(shot: Shot, at: Vector3, car_heading: float = PI * 0.5) -> void:
	active = true
	_shot = shot
	title = CLIPS[shot][0]
	_focus = at
	_elapsed = 0.0
	_line = -1
	_last_shot = -1
	_lift = null
	_chute = null
	_set = Node3D.new()
	add_child(_set)
	_set.position = at
	_set.rotation.y = car_heading - PI * 0.5 if shot == Shot.PURSUIT else 0.0
	_camera = Camera3D.new()
	_set.add_child(_camera)
	_camera.fov = 62.0
	_camera.make_current()
	_stage()
	_play_voice(shot)
	_update(0.0, 0.0)
	await clip_finished


func _physics_process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	_update(minf(_elapsed / DURATION, 1.0), delta)
	if _elapsed >= DURATION:
		active = false
		_set.queue_free()
		_cast.clear()
		_roles.clear()
		_start.clear()
		_vehicles.clear()
		clip_finished.emit()


func _stage() -> void:
	match _shot:
		Shot.STREET, Shot.BREACH, Shot.AMBUSH:
			for index in 6:
				_actor(Actor.Role.DRIVER, Color("#2b4059"), Vector3((index % 3 - 1) * 1.55, 0, index / 3.0 * 2.1),
					"Officer" if index == 0 else "")
			for index in 3:
				_car(Vector3((index - 1) * 4.2, 0, 5 + index * 2), true)
		Shot.PURSUIT:
			_car(Vector3(-1.0, 0, 0), false)
			for index in 8:
				_car(Vector3(4 + index * 2.4, 0, (index % 3 - 1) * 3.7), true)
		Shot.BOMBER:
			var plane := Node3D.new()
			_set.add_child(plane)
			_vehicles.append(plane)
			Shapes.box(plane, Vector3(26, 2.3, 3.2), Vector3.ZERO, Color("#b8c4c7"))
			Shapes.box(plane, Vector3(9, 0.68, 31), Vector3(1, 0, 0), Color("#99a8b5"))
			Shapes.box(plane, Vector3(5, 3.2, 0.62), Vector3(10, 1.8, 0), Color("#8b99a5"))
		_:
			_actor(Actor.Role.DRIVER, Color("#3e777c"), Vector3(-0.78, 0, 0.35),
				"Bus driver" if _shot == Shot.BUS else "Erik")
			if _shot == Shot.LANDING:
				var chute := SphereMesh.new()
				chute.is_hemisphere = true
				chute.radius = 1.6
				chute.height = 3.2
				_chute = Shapes.attach(_cast[0], chute, Vector3(0, 3.1, 0), Color("#da8963"))
				_chute.scale.y = 0.62
				return
			var princess := _shot in [Shot.CAFE, Shot.LEDGER, Shot.REUNION, Shot.RADIO_ARRIVAL, Shot.BROADCAST, Shot.BOARD]
			var partner := "Princess" if princess else ("Pilot" if _shot in [Shot.WRECK, Shot.RESCUE] else "Friend")
			_actor(Actor.Role.PRINCESS if princess else Actor.Role.DRIVER,
				Color("#b65da0") if princess else Color("#b37b4b"), Vector3(0.78, 0, -0.30), partner)
			if _shot in [Shot.REUNION, Shot.RESCUE, Shot.RADIO_ARRIVAL, Shot.BROADCAST, Shot.BOARD]:
				if _shot != Shot.REUNION:
					_actor(Actor.Role.PRINCESS if _shot == Shot.RESCUE else Actor.Role.DRIVER,
						Color("#b65da0") if _shot == Shot.RESCUE else Color("#7d9982"), Vector3(-1.35, 0, -0.72),
						"Princess" if _shot == Shot.RESCUE else "Pilot")
				_actor(Actor.Role.DRIVER, Color("#bd773b"), Vector3(1.35, 0, -0.88), "Friend")
			if _shot == Shot.BROADCAST:
				Shapes.box(_set, Vector3(2.3, 0.95, 0.52), Vector3(0.45, 0.48, 0.52), Color("#415461"))
				Shapes.box(_set, Vector3(0.07, 0.50, 0.07), Vector3(0.76, 1.18, 0.47), Color("#20292d"))
				Shapes.box(_set, Vector3(0.22, 0.11, 0.10), Vector3(0.76, 1.44, 0.44), Color("#cf9d62"))
				var live := Label3D.new()
				_set.add_child(live)
				live.position = Vector3(0.46, 0.72, 0.80)
				live.text = "ON AIR"
				live.modulate = Color("#ff715c")
				live.font_size = 36
				live.pixel_size = 0.009
			elif _shot == Shot.LEDGER:
				Shapes.box(_cast[1].right_arm, Vector3(0.23, 0.09, 0.28), Vector3(0, -0.49, -0.07), Color("#774b3c"))
			elif _shot == Shot.WRECK or _shot == Shot.RESCUE:
				_cast[1].sit_pose()
			elif _shot == Shot.BOARD:
				_lift = Shapes.box(_set, Vector3(3.55, 0.16, 2.7), Vector3(0, -0.10, -0.35), Color("#758891"))


func _actor(role: Actor.Role, tint: Color, at: Vector3, speaker: String) -> void:
	var body := Actor.new()
	_set.add_child(body)
	body.position = at
	body.build(role, tint)
	_cast.append(body)
	_roles.append(speaker)
	_start.append(at)


func _car(at: Vector3, police: bool) -> void:
	var car := Node3D.new()
	_set.add_child(car)
	car.position = at
	car.rotation.y = PI * 0.5
	Shapes.create(car, 0, Color("#c9d9e4") if police else Color("#39a99b"))
	if police:
		Shapes.box(car, Vector3(0.42, 0.14, 0.19), Vector3(-0.27, 1.48, 0.08), Color("#ff4c4e"))
		Shapes.box(car, Vector3(0.42, 0.14, 0.19), Vector3(0.27, 1.48, 0.08), Color("#408dff"))
	_vehicles.append(car)


func _update(t: float, delta: float) -> void:
	var beat := mini(int(_elapsed / 5.0), 3)
	if beat != _line:
		_line = beat
		subtitle.emit(CLIPS[_shot][1][beat])
		if beat % 2 == 0 and _shot in [Shot.STREET, Shot.AMBUSH, Shot.BREACH, Shot.PURSUIT]:
			siren.emit()
	var part := fmod(_elapsed, 5.0) / 5.0
	var words: String = CLIPS[_shot][1][beat]
	var speaker := words.get_slice(" / ", 0)
	if _shot == Shot.PURSUIT:
		_set.position.x = _focus.x - 170.0 * t
		for index in _vehicles.size():
			var base_x := -1.0 if index == 0 else 4.0 + (index - 1) * 2.4
			_vehicles[index].position.x = base_x - sin(t * PI) * (0.3 + index * 0.32)
		var lead := _vehicles[0].position
		_cinematic_shot(_vehicles[beat * 2].position + Vector3(-2.2, 1.23, 0), lead + Vector3.UP, 1.08)
		_view(lead + Vector3(8 - beat * 4, 3.3, 6 + part * 2), lead.lerp(_vehicles[beat * 2].position, 0.53))
		return
	if _shot == Shot.BOMBER:
		_vehicles[0].position = Vector3(58 - t * 130, 0, 0)
		_view(_vehicles[0].position + Vector3(18 - beat * 12, 9, 28 - part * 8), _vehicles[0].position)
		return
	var speaker_index := _roles.find(speaker)
	var police := _shot in [Shot.STREET, Shot.AMBUSH, Shot.BREACH]
	_pose_cast(t, part, speaker_index, police, beat, delta)
	for index in _vehicles.size():
		var car := _vehicles[index]
		car.position.x = (index - 1) * 4.2 + (1.0 - t) * 13.0
		car.get_child(1).visible = fmod(_elapsed * 3.1 + index, 1.0) < 0.55
		car.get_child(2).visible = not car.get_child(1).visible
	var close_shot := _shot in [Shot.CAFE, Shot.LEDGER, Shot.BROADCAST]
	var side := -1.0 if beat % 2 == 0 else 1.0
	if beat >= 2 and _shot in [Shot.AMBUSH, Shot.BREACH]:
		_cinematic_shot(_set.to_local(_cast[beat].muzzle.global_position), _police_aim(beat), 1.34)
	var rise := _cast[0].position.y if _lift else 0.0
	if _lift:
		_lift.position.y = rise - 0.10
	var focus := Vector3(side * 0.40, 1.32 + rise, 0)
	var distance := (2.7 if close_shot else 5.4) - part * 0.55
	if _shot in [Shot.BUS, Shot.REUNION]:
		distance = -distance
	if _shot == Shot.BROADCAST and beat < 2:
		_view(Vector3(0.5 + side * 0.48, 1.64 + 0.10 * part, distance), Vector3(0.78, 1.45, -0.25))
		return
	if _shot in [Shot.CAFE, Shot.LEDGER, Shot.BUS, Shot.REUNION, Shot.WRECK, Shot.RESCUE] and speaker_index >= 0:
		var subject := _cast[speaker_index].position
		var listener := _cast[_listener_for(speaker_index)].position
		var eye := subject + Vector3.UP * 1.50
		var shoulder := subject.direction_to(listener)
		shoulder.y = 0.0
		var flank := Vector3(-shoulder.z, 0, shoulder.x).normalized()
		if flank.z * distance < 0.0:
			flank = -flank
		_view(eye + shoulder * (1.25 - part * 0.15) + flank * (2.35 if close_shot else 3.4) + Vector3.UP * 0.15,
			eye.lerp(listener + Vector3.UP * 1.48, 0.24))
		return
	_view(Vector3(side * (1.45 + 0.38 * part), 1.58 + beat * 0.12 + rise, distance), focus)


func _pose_cast(t: float, part: float, speaker: int, police: bool, beat: int, delta: float) -> void:
	var walks := police or _shot in [Shot.BUS, Shot.RADIO_ARRIVAL, Shot.BOARD]
	var travel := smoothstep(0.0, 0.18, t) * 1.25 if walks else 0.0
	var step := sin(travel * TAU / 1.6) * 0.54 * (1.0 - smoothstep(0.13, 0.18, t))
	var rise := 11.0 * smoothstep(0.42, 0.94, t) if _lift else 0.0
	var seat := 1.0 - smoothstep(0.30, 0.86, t)
	for index in _cast.size():
		var body := _cast[index]
		body.position = _start[index] + Vector3(0, rise, 1.25 - travel if walks else 0.0)
		if _shot in [Shot.RESCUE, Shot.WRECK] and index == 1:
			body.position += Vector3((1.0 - seat) * 0.47, -0.32 * seat, 0)
		if _chute:
			body.position.y = 3.1 * (1.0 - smoothstep(0.0, 0.30, t))
			_chute.visible = t < 0.35
	var turn := 1.0 - exp(-delta * 8.0) if delta > 0.0 else 1.0
	for index in _cast.size():
		var body := _cast[index]
		var speaking := speaker == index
		var envelope := smoothstep(0.018, 0.11, part) * (1.0 - smoothstep(0.79, 0.98, part)) if speaking else 0.0
		var speech := envelope * absf(sin(_elapsed * 15.0))
		var gesture := envelope * (0.32 + sin(_elapsed * 3.3) * 0.17)
		if _shot == Shot.RESCUE and index == 0:
			gesture = 1.20 * sin(t * PI)
		body.cinematic_pose(step, seat if index == 1 and _shot in [Shot.RESCUE, Shot.WRECK] else 0.0, speech, gesture)
		if police and beat >= 2:
			body.aim(_police_aim(index))
			continue
		var gaze := body.position + Vector3.FORWARD
		if _shot == Shot.BROADCAST and speaking and index == 1:
			gaze = Vector3(0.76, 1.44, 0.44)
		elif walks and t < 0.14:
			gaze = body.position + Vector3.FORWARD
		elif _cast.size() > 1:
			var listener := speaker if speaker >= 0 and not speaking else _listener_for(index)
			gaze = _cast[listener].position
		var direction := gaze - body.position
		if Vector2(direction.x, direction.z).length_squared() > 0.001:
			body.rotation.y = lerp_angle(body.rotation.y, atan2(-direction.x, -direction.z), turn)


func _listener_for(index: int) -> int:
	if _shot == Shot.REUNION and index != _roles.find("Friend"):
		return _roles.find("Friend")
	if _shot == Shot.BROADCAST and index != 1:
		return 1
	return 1 if index == 0 else 0


func _police_aim(index: int) -> Vector3:
	return Vector3(-2 + index * 0.65, 1.55, -8)


func _cinematic_shot(from: Vector3, to: Vector3, interval: float) -> void:
	var tick := floori(_elapsed / interval)
	if _elapsed < 8.0 or tick == _last_shot:
		return
	_last_shot = tick
	var direction := to - from
	var trace := Shapes.box(_set, Vector3(0.025, 0.025, direction.length()), (from + to) * 0.5, Color("#ffd278"))
	trace.basis = Basis.looking_at(direction)
	fired.emit(_set.to_global(from))
	create_tween().tween_callback(trace.queue_free).set_delay(0.075)


func _view(from: Vector3, toward: Vector3) -> void:
	_camera.position = from
	_camera.look_at(_set.to_global(toward))


func _play_voice(shot: Shot) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var path := "res://assets/city/dialogue/%02d.wav" % shot
	if not ResourceLoader.exists(path):
		return
	var voice := AudioStreamPlayer.new()
	_set.add_child(voice)
	voice.bus = &"Effects"
	voice.stream = load(path) as AudioStream
	voice.volume_db = -3.0
	voice.play()
