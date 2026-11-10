extends Node3D

const VehicleVisual = preload("res://scripts/vehicle_visual.gd")
const RoadGenerator = preload("res://scripts/road_generator.gd")
const TrafficSpawner = preload("res://scripts/traffic_spawner.gd")
const PlayerCar = preload("res://scripts/player_car.gd")
const TrafficCar = preload("res://scripts/traffic_car.gd")
const CameraController = preload("res://scripts/camera_controller.gd")
const ScoreManager = preload("res://scripts/score_manager.gd")
const SkyFinale = preload("res://scripts/sky_finale.gd")
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

signal stats_changed(distance: float, score: int, coins: int, speed: float)
signal run_ended(distance: float, score: int, coins: int)
signal finale_started
signal finale_cue(cue: String)
signal run_completed(distance: float, score: int, coins: int)

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


func start_run(car_index: int) -> void:
	_spawner.reset(random_seed, spawn_distance)
	_rng.seed = _spawner.rng.seed
	_reset_world(car_index)
	progress.reset()
	speed = START_SPEED
	playing = true
	_emit_stats()


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
	_sky_route = false
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
	_finale.cue.connect(finale_cue.emit)
	_finale.finished.connect(_complete_finale, CONNECT_ONE_SHOT)
	_finale.play(_player)


func _complete_finale() -> void:
	run_completed.emit(progress.distance, progress.score, progress.coins)


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
