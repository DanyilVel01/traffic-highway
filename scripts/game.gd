extends Node3D

const VehicleVisual = preload("res://scripts/vehicle_visual.gd")
const RoadGenerator = preload("res://scripts/road_generator.gd")
const TrafficSpawner = preload("res://scripts/traffic_spawner.gd")
const PlayerCar = preload("res://scripts/player_car.gd")
const TrafficCar = preload("res://scripts/traffic_car.gd")
const CameraController = preload("res://scripts/camera_controller.gd")
const ScoreManager = preload("res://scripts/score_manager.gd")
const SkyFinale = preload("res://scripts/sky_finale.gd")
const Police = preload("res://scripts/chase_police.gd")
const SkyRescue = preload("res://scripts/sky_rescue.gd")
const TRAFFIC_PAINTS: Array[Color] = [Color("#e76e57"), Color("#e6d4a2"), Color("#668abb"), Color("#abbd9a")]
const INSECT_SHELLS: Array[Color] = [Color("#f48842"), Color("#d98ae4"), Color("#89ce60")]
const START_SPEED: float = 18.0
const TOP_SPEED: float = 250.0 / 3.6
const ACCELERATION: float = 12.0
const BRAKE_DECELERATION: float = 24.0
const HANDBRAKE_DECELERATION: float = 5.0
const LAUNCH_SPEED: float = 150.0 / 3.6
const SURFACE_FOG: Color = Color("#c2dedc")
const CAVE_FOG: Color = Color("#342b49")
const CLOUD_FOG: Color = Color("#edf3ff")
const SKY_FOG: Color = Color("#bac9f3")
const LAUNCH_CLEARANCE: float = 75.0
const FINALE_DISTANCE: float = 10000.0
const FINALE_APPROACH: float = 140.0
const CHASE_LENGTH: float = 800.0
const ONCOMING_SPEED: float = 8.0
const PURSUIT_ORIGIN: float = FINALE_DISTANCE - 77.0

enum Chapter { HIGHWAY, CAVERN, SKYWAY, CASTLE, PURSUIT, RESCUE, HELICOPTER }

signal stats_changed(distance: float, score: int, coins: int, speed: float)
signal run_ended(distance: float, score: int, coins: int)
signal finale_started
signal finale_cue(cue: String)
signal pursuit_started
signal rescue_started
signal rescue_subtitle(speaker: String, line: String)
signal city_started

@export_range(2.8, 3.6) var lane_width: float = 3.2
@export_range(8.0, 14.0) var lane_change_speed: float = 9.0
@export var random_seed: int = -1
@export_range(80.0, 160.0) var spawn_distance: float = 100.0

var playing: bool = false:
	set(value):
		playing = value
		if not value and is_instance_valid(_player):
			_player.set_drift_smoke(false)
var speed: float = START_SPEED
var progress := ScoreManager.new()
var _spawner := TrafficSpawner.new()
var _rng := RandomNumberGenerator.new()
var _player: PlayerCar
var _camera := CameraController.new()
var _road := RoadGenerator.new()
var _traffic: Array[TrafficCar] = []
var _coins: Array[Area3D] = []
var _world: Node3D
var _lighting: Environment
var _sky_route: bool = false
var _finale: SkyFinale
var _pursuing: bool = false
var _return_origin: float
var _closing_distance: float
var _pursuit_time: float
var _next_shot: float
var _police: Array[Police] = []
var _rescue: SkyRescue


func _ready() -> void:
	_build_world()
	if get_parent() is Window:
		start_run(0)


func show_backdrop(car_index: int) -> void:
	playing = false
	_reset_world(car_index)


func prepare_intro() -> Camera3D:
	playing = false
	_player.hide()
	return _camera


func prepare_city() -> void:
	playing = false
	_update_atmosphere(0.0)
	_lighting.fog_density = 0.0018
	_world.hide()
	_world.process_mode = Node.PROCESS_MODE_DISABLED


func start_run(car_index: int, chapter: Chapter = Chapter.HIGHWAY) -> void:
	_spawner.reset(random_seed, spawn_distance)
	_rng.seed = _spawner.rng.seed
	_reset_world(car_index)
	progress.reset()
	speed = START_SPEED
	playing = true
	match chapter:
		Chapter.CAVERN:
			_start_at(RoadGenerator.RAMP_END + 50.0, false)
		Chapter.SKYWAY:
			_start_at(RoadGenerator.SKY_LANDING + 20.0, true)
		Chapter.CASTLE:
			_start_at(FINALE_DISTANCE, true)
			_position_finale()
			_begin_finale()
			return
		Chapter.PURSUIT:
			_start_at(FINALE_DISTANCE, true)
			_position_finale()
			_finale.rotation.y = PI
			_finale.position.z = FINALE_DISTANCE - PURSUIT_ORIGIN
			_spawn_chapter_police()
			_player.position.x = -lane_width
			for lane in [1, 2]:
				_spawn_oncoming(lane, 17.0, 0)
			_configure_pursuit(PURSUIT_ORIGIN)
			return
		Chapter.RESCUE, Chapter.HELICOPTER:
			_start_at(FINALE_DISTANCE + CHASE_LENGTH, true)
			_return_origin = PURSUIT_ORIGIN
			_road.update_position(_return_origin - CHASE_LENGTH, true, true)
			_spawn_chapter_police()
			_player.install_cinematic_doors()
			_start_rescue(chapter == Chapter.HELICOPTER)
			return
	_emit_stats()


func _start_at(distance: float, sky: bool) -> void:
	progress.distance = distance
	_sky_route = sky
	_spawner.next_arrival = distance + spawn_distance
	_player.position.y = RoadGenerator.height_at(distance, sky)
	_camera.position.y = _player.position.y + 5.0
	_update_atmosphere(_player.position.y)
	_road.update_position(distance, sky)


func _spawn_chapter_police() -> void:
	for side in [-1.0, 1.0]:
		var police := Police.new()
		_world.add_child(police)
		police.build()
		police.position = Vector3(side * lane_width, RoadGenerator.SKY_HEIGHT, 11.0 + side * 2.25)
		_police.append(police)


func resume_run() -> void:
	playing = true
	var overlapping := _player.get_overlapping_areas()
	for area in overlapping:
		if area is TrafficCar and area in _traffic:
			_on_player_area_entered(area, _player)
			return
	for area in overlapping:
		if area in _coins:
			_on_player_area_entered(area, _player)


func _unhandled_input(event: InputEvent) -> void:
	if playing and not _is_launching():
		_player.handle_input(event)


func _physics_process(delta: float) -> void:
	if not playing:
		return
	if _pursuing:
		_advance_pursuit(delta)
		return
	var handbrake := Input.is_action_pressed(&"handbrake")
	if not _is_launching():
		_update_speed(delta, handbrake)
	var travel := speed * delta
	var previous_distance := progress.distance
	progress.distance += travel
	if _sky_route:
		progress.distance = minf(progress.distance, FINALE_DISTANCE)
	if previous_distance < RoadGenerator.LAUNCH_START and progress.distance >= RoadGenerator.LAUNCH_START:
		_sky_route = _player.position.x >= lane_width * 0.62
		if _sky_route:
			_player.lane = 2
			_spawner.safe_lane = 2
			speed = maxf(speed, LAUNCH_SPEED)
	if not _sky_route and progress.distance >= RoadGenerator.LAUNCH_START and progress.distance < RoadGenerator.LAUNCH_LIP:
		_player.lane = mini(_player.lane, 1)
	var difficulty := clampf(progress.distance / 2100.0, 0.0, 1.0)
	_player.advance(delta, travel, lane_width, lane_change_speed, handbrake and not _is_launching())
	_player.position.y = RoadGenerator.height_at(progress.distance, _sky_route)
	_player.visual.rotation.x = RoadGenerator.pitch_at(progress.distance, PlayerCar.LENGTH, _sky_route)
	var camera_distance := progress.distance - _camera.position.z
	var camera_road_height := RoadGenerator.height_at(camera_distance)
	var camera_pitch := RoadGenerator.pitch_at(progress.distance, 12.0, _sky_route)
	if _sky_route:
		camera_road_height = _player.position.y
		camera_pitch *= 0.30
	_camera.follow(delta, _player.position.x, difficulty, camera_road_height, camera_pitch)
	_update_atmosphere(camera_road_height)
	_road.update_position(progress.distance, _sky_route)
	if _sky_route and progress.distance >= FINALE_DISTANCE - FINALE_APPROACH:
		_position_finale()
		if progress.distance >= FINALE_DISTANCE:
			_begin_finale()
			return
	for index in range(_traffic.size() - 1, -1, -1):
		var vehicle := _traffic[index]
		progress.bonus += vehicle.advance(travel, _player.position.x)
		_place_traffic_on_road(vehicle)
		if vehicle.position.z > 24.0:
			_traffic.remove_at(index)
			vehicle.queue_free()
	for index in range(_coins.size() - 1, -1, -1):
		var coin := _coins[index]
		coin.position.z += travel
		coin.rotate_y(delta * 3.0)
		if coin.position.z > 24.0:
			_coins.remove_at(index)
			coin.queue_free()
	while _spawner.next_arrival <= progress.distance + spawn_distance:
		# Wait for the lane choice before scheduling traffic beyond the fork.
		if progress.distance < RoadGenerator.LAUNCH_START and _spawner.next_arrival >= RoadGenerator.LAUNCH_START + LAUNCH_CLEARANCE:
			break
		_spawn_wave(difficulty)
	_emit_stats()


func _is_launching() -> bool:
	return _sky_route and progress.distance < RoadGenerator.SKY_LANDING


func _update_speed(delta: float, handbrake: bool) -> void:
	var rate := ACCELERATION * Input.get_action_strength(&"accelerate")
	if Input.is_action_pressed(&"brake"):
		rate = -BRAKE_DECELERATION
	if handbrake:
		rate -= HANDBRAKE_DECELERATION
	speed = clampf(speed + rate * delta, 0.0, TOP_SPEED)


func _emit_stats() -> void:
	stats_changed.emit(progress.distance, progress.score, progress.coins, speed)


func _reset_world(car_index: int) -> void:
	_world.show()
	_world.process_mode = Node.PROCESS_MODE_INHERIT
	_sky_route = false
	_pursuing = false
	if is_instance_valid(_rescue):
		_world.remove_child(_rescue)
		_rescue.queue_free()
		_rescue = null
	for police in _police:
		police.hide()
		police.queue_free()
	_police.clear()
	_clear_obstacles()
	if is_instance_valid(_finale):
		_world.remove_child(_finale)
		_finale.queue_free()
		_finale = null
	if is_instance_valid(_player):
		_player.hide()
		_player.queue_free()
	_player = PlayerCar.new()
	_player.build(car_index)
	_world.add_child(_player)
	_player.area_entered.connect(_on_player_area_entered.bind(_player))
	_road.reset()
	_camera.reset()
	_camera.make_current()
	_update_atmosphere(0.0)


func _clear_obstacles() -> void:
	for vehicle in _traffic:
		vehicle.hide()
		vehicle.queue_free()
	for coin in _coins:
		coin.hide()
		coin.queue_free()
	_traffic.clear()
	_coins.clear()


func _position_finale() -> void:
	if not is_instance_valid(_finale):
		_finale = SkyFinale.new()
		_finale.name = "SkyFinale"
		_world.add_child(_finale)
		_finale.build(lane_width)
	_finale.position = Vector3(0, RoadGenerator.SKY_HEIGHT, progress.distance - FINALE_DISTANCE)


func _begin_finale() -> void:
	playing = false
	speed = 0.0
	_clear_obstacles()
	_emit_stats()
	finale_started.emit()
	_finale.cue.connect(_on_finale_cue)
	_finale.finished.connect(_start_pursuit, CONNECT_ONE_SHOT)
	_finale.play(_player)


func _on_finale_cue(cue: String) -> void:
	if cue == "depart":
		_road.update_position(FINALE_DISTANCE, true, false, true)
	finale_cue.emit(cue)


func _start_pursuit() -> void:
	var departure := _player.position
	_player.position = Vector3(-departure.x, RoadGenerator.SKY_HEIGHT, 0)
	_player.rotation = Vector3.ZERO
	for police in _finale.pursuit:
		var old := police.global_position
		police.reparent(_world)
		police.position = Vector3(-old.x, RoadGenerator.SKY_HEIGHT, departure.z - old.z)
		police.rotation.y = 0.0
		_police.append(police)
	for vehicle in _finale.oncoming:
		var old := vehicle.global_position
		vehicle.reparent(_world)
		vehicle.position = Vector3(-old.x, RoadGenerator.SKY_HEIGHT, departure.z - old.z)
		vehicle.rotation.y = PI
		_traffic.append(vehicle)
	_finale.rotation.y = PI
	_finale.position.z = departure.z
	_configure_pursuit(FINALE_DISTANCE - departure.z)


func _configure_pursuit(origin: float) -> void:
	_return_origin = origin
	_player.lane = 0
	_pursuing = true
	_closing_distance = 0.0
	_pursuit_time = 0.0
	_next_shot = 0.8
	_spawner.reset(random_seed, 83.0)
	_spawner.safe_lane = 0
	_road.update_position(_return_origin, true, true)
	_camera.position = Vector3(_player.position.x * 0.35, RoadGenerator.SKY_HEIGHT + 6.3, 21.0)
	_camera.rotation_degrees = Vector3(-15.5, 0, 0)
	_camera.fov = 64.0
	_camera.make_current()
	speed = 35.625
	playing = true
	pursuit_started.emit()
	_emit_stats()


func _advance_pursuit(delta: float) -> void:
	var handbrake := Input.is_action_pressed(&"handbrake")
	_update_speed(delta, handbrake)
	var travel := speed * delta
	progress.distance = minf(progress.distance + travel, FINALE_DISTANCE + CHASE_LENGTH)
	var escaped := progress.distance - FINALE_DISTANCE
	_player.advance(delta, travel, lane_width, lane_change_speed, handbrake)
	_road.update_position(_return_origin - escaped, true, true)
	if escaped >= CHASE_LENGTH:
		_start_rescue()
		return
	_finale.position.z = FINALE_DISTANCE - _return_origin + escaped
	_pursuit_time += delta
	var reveal := smoothstep(0.35, 0.90, cos(_pursuit_time * TAU / 7.5))
	_camera.follow(delta, _player.position.x, 1.0, RoadGenerator.SKY_HEIGHT, 0.0)
	_camera.position.z = lerpf(12.2, 21.0, reveal)
	_camera.position.y += lerpf(0.6, 1.3, reveal)
	for police in _police:
		_steer_police(police, delta)
		police.animate(delta, travel)
	if _pursuit_time >= _next_shot:
		var police := _police[floori(_pursuit_time / 2.4) % _police.size()]
		police.fire_at(_player.global_position + Vector3(1.35, 0.55, -4.5))
		finale_cue.emit("shot")
		_next_shot += 2.4
	var oncoming_travel := ONCOMING_SPEED * delta
	var closing_travel := travel + oncoming_travel
	_closing_distance += closing_travel
	for index in range(_traffic.size() - 1, -1, -1):
		var vehicle := _traffic[index]
		progress.bonus += vehicle.advance(closing_travel, _player.position.x, oncoming_travel)
		if vehicle.position.z > 27.0:
			_traffic.remove_at(index)
			vehicle.queue_free()
	while _spawner.next_arrival <= _closing_distance + 100.0:
		var previous_gap := _spawner.safe_lane
		var wave := _spawner.next_wave(0.45)
		var lead := float(wave.arrival) - _closing_distance
		if lead >= _return_origin - escaped - RoadGenerator.CHASE_EDGE - 4.0:
			_spawner.safe_lane = previous_gap
			continue
		for lane: int in wave.lanes:
			_spawn_oncoming(lane, lead, int(wave.safe_lane))
	_emit_stats()


func _spawn_oncoming(lane: int, lead: float, gap: int) -> void:
	_spawn_vehicle(lane, lead, 1.0, TrafficCar.Style.CHARIOT)
	var vehicle := _traffic.back() as TrafficCar
	vehicle.position.y = RoadGenerator.SKY_HEIGHT
	vehicle.rotation.y = PI
	vehicle.pursuit_gap = gap


func _steer_police(police: Police, delta: float) -> void:
	var wave_z := -INF
	var target := police.position.x
	for vehicle in _traffic:
		if vehicle.position.z > wave_z and vehicle.position.z <= police.position.z + 5.5:
			wave_z = vehicle.position.z
			target = (vehicle.pursuit_gap - 1) * lane_width
	police.position.x = move_toward(police.position.x, target, 24.0 * delta)


func _start_rescue(aboard: bool = false) -> void:
	playing = false
	speed = 0.0
	_clear_obstacles()
	_emit_stats()
	_rescue = SkyRescue.new()
	_rescue.position.y = RoadGenerator.SKY_HEIGHT
	_world.add_child(_rescue)
	_rescue.subtitle_changed.connect(rescue_subtitle.emit)
	_rescue.shot.connect(finale_cue.emit.bind("shot"))
	_rescue.finished.connect(_finish_rescue, CONNECT_ONE_SHOT)
	rescue_started.emit()
	var edge_z := RoadGenerator.CHASE_EDGE - (_return_origin - CHASE_LENGTH)
	_rescue.play(_player, _police, edge_z, aboard)


func _finish_rescue() -> void:
	city_started.emit()


func _update_atmosphere(road_height: float) -> void:
	var descent := clampf(-road_height / RoadGenerator.CAVE_DEPTH, 0.0, 1.0)
	var cloud := 1.0 - smoothstep(9.0, 29.0, absf(road_height - 65.0))
	var altitude := smoothstep(25.0, RoadGenerator.SKY_HEIGHT, road_height)
	_lighting.fog_light_color = SURFACE_FOG.lerp(CAVE_FOG, descent).lerp(SKY_FOG, altitude).lerp(CLOUD_FOG, cloud)
	_lighting.fog_density = lerpf(0.0038, 0.016, descent) + cloud * 0.038
	_lighting.background_mode = Environment.BG_COLOR if descent >= 1.0 else Environment.BG_SKY


func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	_lighting = env
	env.background_color = CAVE_FOG
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#4699d0")
	sky_material.sky_horizon_color = Color("#d7f1f1")
	sky_material.ground_bottom_color = Color("#81a991")
	sky_material.ground_horizon_color = Color("#d7f1f1")
	sky.sky_material = sky_material
	env.sky = sky
	env.fog_enabled = true
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c9e1ee")
	env.ambient_light_energy = 0.42
	environment.environment = env
	_world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_color = Color("#ffefdb")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 86.0
	_world.add_child(sun)
	_world.add_child(_camera)
	_world.add_child(_road)
	_road.build(lane_width)


func _spawn_wave(difficulty: float) -> void:
	var previous_safe_lane := _spawner.safe_lane
	var wave := _spawner.next_wave(difficulty)
	var arrival := float(wave.arrival)
	var lead := arrival - progress.distance
	var factor := float(wave.relative_speed)
	var clearance := spawn_distance * (1.0 - factor) + 5.0
	if _in_transition(arrival, clearance):
		# Skipped waves must not move the next visible gap away from the reachable lane.
		_spawner.safe_lane = previous_safe_lane
		return
	var style := TrafficCar.Style.CAR
	if arrival >= RoadGenerator.RAMP_END and arrival < RoadGenerator.CAVE_EXIT_START:
		style = TrafficCar.Style.INSECT
	elif _sky_route:
		style = TrafficCar.Style.CHARIOT
	for lane: int in wave.lanes:
		_spawn_vehicle(lane, lead * factor, factor, style)
	for offset in [-3.5, 0.0, 3.5]:
		_spawn_coin(int(wave.safe_lane), lead + offset)


func _in_transition(arrival: float, clearance: float) -> bool:
	# Obstacles spawn behind their scheduled arrival point, so allow space for their visible approach.
	var entering_cave := arrival >= RoadGenerator.RAMP_START - 12.0 and arrival < RoadGenerator.RAMP_END + clearance
	var leaving_cave := arrival >= RoadGenerator.CAVE_EXIT_START - 12.0 and arrival < RoadGenerator.CAVE_EXIT_END + clearance
	var near_launch := absf(arrival - RoadGenerator.LAUNCH_START) < LAUNCH_CLEARANCE
	var landing := _sky_route and arrival < RoadGenerator.SKY_LANDING + clearance + 30.0
	var finale := _sky_route and arrival >= FINALE_DISTANCE - 65.0
	return entering_cave or leaving_cave or near_launch or landing or finale


func _spawn_vehicle(lane: int, lead: float, factor: float, style: TrafficCar.Style) -> void:
	var kind := _rng.randi_range(0, 2)
	var color := TRAFFIC_PAINTS[_rng.randi_range(0, TRAFFIC_PAINTS.size() - 1)]
	if style == TrafficCar.Style.INSECT:
		color = INSECT_SHELLS[kind]
	var vehicle := TrafficCar.new()
	vehicle.position = Vector3(float(lane - 1) * lane_width, 0, -lead)
	vehicle.build(kind, color, factor, style)
	_place_traffic_on_road(vehicle)
	_world.add_child(vehicle)
	_traffic.append(vehicle)


func _place_traffic_on_road(vehicle: TrafficCar) -> void:
	var distance := progress.distance - vehicle.position.z
	var sky := vehicle.style == TrafficCar.Style.CHARIOT
	vehicle.position.y = RoadGenerator.height_at(distance, sky)
	vehicle.rotation.x = RoadGenerator.pitch_at(distance, vehicle.length, sky)


func _spawn_coin(lane: int, lead: float) -> void:
	var coin := Area3D.new()
	coin.name = "Coin"
	coin.collision_layer = 4
	coin.collision_mask = 0
	coin.monitoring = false
	coin.position = Vector3(float(lane - 1) * lane_width,
		1.1 + RoadGenerator.height_at(progress.distance + lead, _sky_route), -lead)
	_world.add_child(coin)
	var shape := SphereShape3D.new()
	shape.radius = 0.85
	var collision := CollisionShape3D.new()
	collision.shape = shape
	coin.add_child(collision)
	_coin_face(coin, 0.50, 0.17, Color("#e7a333"))
	_coin_face(coin, 0.38, 0.19, Color("#ffdb63"))
	_coins.append(coin)


func _coin_face(coin: Area3D, radius: float, depth: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	mesh.radial_segments = 12
	var visual := VehicleVisual.attach(coin, mesh, Vector3.ZERO, color)
	visual.rotation_degrees.x = 90.0


func _on_player_area_entered(area: Area3D, player: PlayerCar) -> void:
	if not playing or player != _player:
		return
	if area in _coins:
		_coins.erase(area)
		area.queue_free()
		progress.collect_coin()
		_emit_stats()
	elif area is TrafficCar and area in _traffic:
		playing = false
		run_ended.emit(progress.distance, progress.score, progress.coins)
