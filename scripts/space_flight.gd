extends Node3D

const World = preload("res://scripts/vesper_world.gd")
const HUD = preload("res://scripts/space_flight_hud.gd")
const Epilogue = preload("res://scripts/vesper_epilogue.gd")
const TRANSFER := 3050.0
const GRAVITY := 6.4
const THRUST := 14.0
const MAX_TILT := 0.35
const MAX_OFFSET := 3.2
const MAX_DRIFT := 1.85
const MAX_DESCENT := 3.4
const MAX_TOUCHDOWN_TILT := 0.125

signal failed(reason: String)
signal landed
signal epilogue_started

enum Phase { CRUISE, DESCENT, TOUCHDOWN, LOST, EPILOGUE }

class Rock:
	var mesh: MeshInstance3D
	var origin: Vector3
	var radius: float
	var drift: Vector2
	var spin: float
	var orbit: float

var world := World.new()
var hud := HUD.new()
var epilogue: Epilogue
var phase := Phase.CRUISE
var landing_start := false
var landed_start := false
var hull := 100
var fuel := 100.0
var throttle := 0.59
var flight_velocity := Vector3(0, 0, -84.0)
var attitude := Vector2.ZERO
var _camera: Camera3D
var _rocks: Array[Rock] = []
var _clock := 0.0
var _phase_clock := 0.0
var _impact_time := 0.0
var _line := -1
var _flight_enabled := true
var _collision_course := false
var _environment := Environment.new()

const TRANSFER_LINES := [
	["Pilot", "Erik, you've got the controls. Use the side thrusters to dodge the rocks."],
	["Erik", "I can see a gap. Keep calling out the rocks while I line up."],
	["Princess", "Elena made it to the evacuation train. Erik, those lights on Vesper are a base."],
	["Friend", "We're through the worst of it. That landing pad looks a lot smaller from here."],
]
const LANDING_LINES := [
	["Pilot", "Erik, keep the rocket upright. Forty-six percent thrust is enough to hover."],
	["Princess", "The ring of blue lights marks the pad. Aim for its center."],
	["Erik", "I'm watching the vertical speed. I'll brake the drift before touchdown."],
	["Friend", "Level the legs and bring her down slowly. We've only got one shot at this."],
]
const SUCCESS_LINES := [
	["Friend", "All four feet are down. Erik, you actually landed it."],
	["Erik", "Leave the engines on standby. Let's see who's running this base."],
	["Princess", "I'll get the hatch. We've got a long way home."],
	["Pilot", "Outpost Seven, this is Erik's crew. Requesting clearance to open the hatch."],
]


func _ready() -> void:
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("#080f20")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#91a5c3")
	_environment.ambient_light_energy = 0.63
	add_child(world)
	_camera = Camera3D.new()
	_camera.far = 7000.0
	_camera.environment = _environment
	add_child(_camera)
	_camera.make_current()
	add_child(hud)
	_build_field()
	world.ship.rotation.x = -PI * 0.5
	if landing_start or landed_start:
		_begin_descent()
	if landed_start:
		world.ship.position = Vector3.UP * World.PAD_Y
		world.update_pad(world.ship.position, true)
		_touchdown()
		finish_touchdown()
	else:
		_update_camera(0.0)


func set_active(active: bool) -> void:
	_flight_enabled = active
	hud.pause_voice(not active)
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	hud.visible = active and phase != Phase.EPILOGUE
	if is_instance_valid(epilogue):
		epilogue.set_active(active)


func retry_at_landing() -> bool:
	return landing_start


func _physics_process(delta: float) -> void:
	if not _flight_enabled or phase in [Phase.LOST, Phase.EPILOGUE]:
		return
	_clock += delta
	_phase_clock += delta
	_impact_time = maxf(0.0, _impact_time - delta)
	match phase:
		Phase.CRUISE:
			_fly_transfer(delta)
			if phase == Phase.CRUISE:
				_talk(TRANSFER_LINES)
		Phase.DESCENT:
			_fly_descent(delta)
			if phase == Phase.DESCENT:
				_talk(LANDING_LINES)
		Phase.TOUCHDOWN:
			_talk(SUCCESS_LINES, 5.0)
			if _phase_clock >= 20.0:
				finish_touchdown()
	world.flame.visible = phase == Phase.CRUISE or (phase == Phase.DESCENT and fuel > 0.0 and throttle > 0.02)
	world.flame.scale = Vector3(0.84 + throttle * 0.22, 0.32 + throttle * 1.1, 0.84 + throttle * 0.22)
	_update_camera(delta)


func _fly_transfer(delta: float) -> void:
	var steer := _steer()
	steer.y = -steer.y
	_adjust_throttle(delta, 0.36)
	var brake := Input.is_action_pressed(&"handbrake")
	var lateral := Vector2(flight_velocity.x, flight_velocity.y)
	lateral = lateral.move_toward(steer * (21.0 if brake else 32.0), delta * (39.0 if brake else 24.0))
	var speed := move_toward(-flight_velocity.z, 36.0 if brake else lerpf(51.0, 119.0, throttle), delta * 23.0)
	flight_velocity = Vector3(lateral.x, lateral.y, -speed)
	var previous := world.ship.position
	world.ship.position += flight_velocity * delta
	world.ship.position.x = clampf(world.ship.position.x, -50.0, 50.0)
	world.ship.position.y = clampf(world.ship.position.y, -26.0, 26.0)
	world.ship.rotation = Vector3(-PI * 0.5 + lateral.y * 0.009, lateral.x * -0.012, lateral.x * -0.013)
	_check_field(previous)
	if phase == Phase.LOST:
		return
	var left := TRANSFER + world.ship.position.z
	hud.show_cruise(hull, throttle, speed, maxf(left, 0.0), _collision_course)
	if left <= 0.0:
		_begin_descent()


func _fly_descent(delta: float) -> void:
	_adjust_throttle(delta, 0.26)
	var steer := _steer()
	attitude = attitude.move_toward(steer * MAX_TILT, delta * 0.75)
	world.ship.rotation = Vector3(attitude.y, 0, -attitude.x)
	var powered := fuel > 0.0
	var brake := Input.is_action_pressed(&"handbrake") and powered
	var thrust := THRUST * throttle if powered else 0.0
	var acceleration := world.ship.basis.y * thrust - Vector3.UP * GRAVITY
	flight_velocity += acceleration * delta
	var drift := Vector2(flight_velocity.x, flight_velocity.z)
	drift = drift.move_toward(Vector2.ZERO, delta * (3.8 if brake else 0.055 * drift.length()))
	flight_velocity.x = drift.x
	flight_velocity.z = drift.y
	world.ship.position += flight_velocity * delta
	fuel = maxf(0.0, fuel - delta * (throttle * 1.4 + (1.15 if brake else 0.0)))
	var offset := Vector2(world.ship.position.x, world.ship.position.z)
	var deck := _deck(offset)
	var height := world.ship.position.y - deck
	var ready := _safe_touchdown(offset)
	world.update_pad(world.ship.position, ready)
	hud.show_landing(hull, throttle, fuel, maxf(height, 0.0), flight_velocity, offset.length(),
		rad_to_deg(attitude.length()), offset, ready)
	if height <= 0.0:
		world.ship.position.y = deck
		if ready:
			_touchdown()
		else:
			_fail("Missed the pad" if offset.length() > MAX_OFFSET else "Hard landing. Reduce descent, drift and tilt.")
	elif offset.length() > 152.0 or height > 310.0:
		_fail("Vesper approach corridor lost")


func _safe_touchdown(offset: Vector2) -> bool:
	return offset.length() <= MAX_OFFSET and absf(flight_velocity.y) <= MAX_DESCENT and (
		Vector2(flight_velocity.x, flight_velocity.z).length() <= MAX_DRIFT) and attitude.length() <= MAX_TOUCHDOWN_TILT


func _deck(offset: Vector2) -> float:
	return World.PAD_Y if offset.length() <= World.PAD_RADIUS else World.surface_height(offset.x, offset.y)


func _begin_descent() -> void:
	phase = Phase.DESCENT
	_phase_clock = 0.0
	_line = -1
	landing_start = true
	fuel = 100.0
	throttle = 0.42
	attitude = Vector2.ZERO
	flight_velocity = Vector3(1.15, -11.5, -1.4)
	world.ship.position = Vector3(-15, 144, 18)
	world.ship.rotation = Vector3.ZERO
	world.set_landing(true)
	_environment.background_color = Color("#30283d")
	_environment.ambient_light_color = Color("#cec0d5")
	_update_camera(0.0)


func _touchdown() -> void:
	phase = Phase.TOUCHDOWN
	_phase_clock = 0.0
	_line = -1
	flight_velocity = Vector3.ZERO
	world.ship.rotation = Vector3.ZERO
	hud.show_landed()


func finish_touchdown() -> void:
	if phase != Phase.TOUCHDOWN or not _flight_enabled:
		return
	phase = Phase.EPILOGUE
	world.flame.hide()
	epilogue_started.emit()
	hud.pause_voice(true)
	hud.hide()
	epilogue = Epilogue.new()
	add_child(epilogue)
	epilogue.finished.connect(_finish_epilogue)
	epilogue.begin(world, _environment)


func _finish_epilogue() -> void:
	set_active(false)
	landed.emit()


func _fail(reason: String) -> void:
	phase = Phase.LOST
	world.flame.hide()
	set_active(false)
	failed.emit(reason)


func _steer() -> Vector2:
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) -
		float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))).limit_length(1.0)


func _adjust_throttle(delta: float, rate: float) -> void:
	var change := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	throttle = clampf(throttle + change * delta * rate, 0.0, 1.0)


func _build_field() -> void:
	if landing_start or landed_start:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 6219
	for wave in 17:
		var gap := [Vector2(23, -9), Vector2(-22, 8), Vector2(11, 19), Vector2(-12, -18)][wave % 4] as Vector2
		for column in 6:
			for row in 3:
				var at := Vector2(-48.0 + column * 19.2, -24.0 + row * 24.0)
				at += Vector2(rng.randf_range(-4.7, 4.7), rng.randf_range(-4.0, 4.0))
				if at.distance_to(gap) < 18.0 or rng.randf() < 0.12:
					continue
				var rock := Rock.new()
				rock.radius = rng.randf_range(5.0, 9.9)
				rock.origin = Vector3(at.x, at.y, -205.0 - wave * 161.0 + rng.randf_range(-18, 18))
				rock.drift = Vector2(rng.randf_range(-7, 7), rng.randf_range(-4, 4))
				rock.spin = rng.randf_range(-0.5, 0.5)
				rock.orbit = column * 0.77 + row * 1.29 + wave * 0.54
				rock.mesh = world.asteroid(rock.radius, (column + wave + row) % 3)
				rock.mesh.position = rock.origin
				rock.mesh.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())
				_rocks.append(rock)


func _check_field(previous: Vector3) -> void:
	var now := world.ship.position
	_collision_course = false
	for index in range(_rocks.size() - 1, -1, -1):
		var rock := _rocks[index]
		var separation := rock.origin.z - now.z
		if separation > 42.0:
			rock.mesh.queue_free()
			_rocks.remove_at(index)
			continue
		if separation < -650.0:
			continue
		var drift := rock.drift * sin(_clock * 0.48 + rock.orbit)
		var at := rock.origin + Vector3(drift.x, drift.y, 0)
		rock.mesh.position = at
		rock.mesh.rotation.z = _clock * rock.spin
		if separation < -7.0 and separation > -145.0:
			var time := separation / flight_velocity.z
			var predicted := now + flight_velocity * time
			_collision_course = _collision_course or predicted.distance_squared_to(at) < pow(rock.radius + 4.0, 2)
		var nearest := Geometry3D.get_closest_point_to_segment(at, previous, now)
		if nearest.distance_squared_to(at) > pow(rock.radius * 0.80 + 1.32, 2):
			continue
		hull = maxi(0, hull - 34)
		_impact_time = 0.65
		flight_velocity.z *= 0.72
		rock.mesh.queue_free()
		_rocks.remove_at(index)
		if hull == 0:
			_fail("Hull destroyed in the asteroid field")
			return
		hud.say("Pilot", "Hull hit, Erik. Stay clear of the next cluster.", 3.0)


func _talk(lines: Array, interval: float = 6.7) -> void:
	var line := int(_phase_clock / interval)
	if line == _line or line >= lines.size():
		return
	_line = line
	var group := "transfer" if phase == Phase.CRUISE else ("landing" if phase == Phase.DESCENT else "success")
	hud.say(lines[line][0], lines[line][1], interval - 0.22, "%s_%02d" % [group, line])


func _update_camera(delta: float) -> void:
	var ship_at := world.ship.position
	var eye := ship_at + Vector3(4.8, 5.8, 15.0)
	var aim := ship_at + Vector3(0, 1.2, -23.0)
	if phase == Phase.DESCENT:
		var high := smoothstep(10.0, 142.0, ship_at.y)
		eye = ship_at + Vector3(12, 13 + high * 27, 19 + high * 35)
		aim = Vector3(ship_at.x * 0.68, ship_at.y * (0.49 + (1.0 - high) * 0.19) + 2.0, ship_at.z * 0.68)
	elif phase == Phase.TOUCHDOWN:
		var angle := lerpf(0.62, -0.68, smoothstep(0.0, 20.0, _phase_clock))
		eye = ship_at + Vector3(sin(angle) * 24.0, 10.2, cos(angle) * 24.0)
		aim = ship_at + Vector3.UP * 3.8
	eye.x += sin(_clock * 64.0) * _impact_time * 1.1
	var blend := 1.0 if delta == 0.0 else (1.0 - exp(-delta * 5.5))
	_camera.position = _camera.position.lerp(eye, blend)
	_camera.look_at(aim)
