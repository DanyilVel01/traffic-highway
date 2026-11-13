extends SceneTree

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const GameScene: PackedScene = preload("res://scenes/game.tscn")
const RoadGenerator = preload("res://scripts/road_generator.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const TrafficCar = preload("res://scripts/traffic_car.gd")
const TrafficSpawner = preload("res://scripts/traffic_spawner.gd")
var failures: int = 0
var endings: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("traffic-dodge-smoke-"):
		_check(false, "use an isolated traffic-dodge-smoke-* data directory")
		_finish()
		return
	if "--check-save" in OS.get_cmdline_user_args():
		var saved := SaveManager.new()
		root.add_child(saved)
		saved.load_data()
		_check(int(saved.data.best_score) > 0, "best score persists across processes")
		_check(int(saved.data.selected) == 1 and bool(saved.data.unlocked[1]), "garage unlock and selection persist")
		_check(is_equal_approx(float(saved.data.music), 0.25) and not bool(saved.data.shadows), "settings persist")
		_finish()
		return

	var app := MainScene.instantiate()
	root.add_child(app)
	_check(app.state == app.State.MENU, "main scene starts at the menu")
	_check(InputMap.event_is_action(_key(KEY_LEFT), &"move_left"), "Left Arrow is mapped")
	_check(InputMap.event_is_action(_key(KEY_RIGHT), &"move_right"), "Right Arrow is mapped")
	_check(InputMap.event_is_action(_key(KEY_A), &"move_left"), "A is mapped")
	_check(InputMap.event_is_action(_key(KEY_D), &"move_right"), "D is mapped")
	_check(InputMap.event_is_action(_key(KEY_W), &"accelerate"), "W is mapped")
	_check(InputMap.event_is_action(_key(KEY_DOWN), &"brake"), "Down Arrow is mapped")
	_check_waves()
	app.game.random_seed = 873
	app.game.run_ended.connect(func(_distance: float, _score: int, _coins: int) -> void: endings += 1)
	await _check_intro(app)
	_check(app.state == app.State.PLAYING and app.game._player.lane == 1, "Play starts in the middle lane")
	for index in 5:
		_send_key(KEY_LEFT)
	await _frames(28)
	_check(app.game._player.lane == 0 and is_equal_approx(app.game._player.position.x, -app.game.lane_width), "left lane clamps")
	_send_key(KEY_D, true)
	_check(app.game._player.lane == 0, "held key does not repeat")
	for index in 5:
		_send_key(KEY_D)
	await _frames(50)
	_check(app.game._player.lane == 2 and is_equal_approx(app.game._player.position.x, app.game.lane_width), "right lane clamps")
	_press(app, "Pause")
	var frozen := float(app.game.progress.distance)
	await _frames(30)
	_check(is_equal_approx(float(app.game.progress.distance), frozen), "pause freezes travel")
	_press(app, "Settings")
	_check(app.state == app.State.SETTINGS, "settings opens from pause")
	var sliders: Array[Node] = app.screen.find_children("*", "HSlider", true, false)
	sliders[1].value = 0.25
	var shadow_toggle: CheckButton = app.screen.find_children("*", "CheckButton", true, false)[0]
	shadow_toggle.set_pressed_no_signal(false)
	shadow_toggle.toggled.emit(false)
	_press(app, "Back")
	_press(app, "Resume")
	await _frames(3)
	_check(app.state == app.State.PLAYING and float(app.game.progress.distance) > frozen, "resume continues travel")
	_check(not app.game.find_children("*", "DirectionalLight3D", true, false)[0].shadow_enabled, "shadow option applies in game")

	if app.game._traffic.is_empty():
		_check(false, "first wave spawned")
		_finish()
		return
	var target: Area3D = app.game._traffic[0]
	var lane := 1 + roundi(target.position.x / app.game.lane_width)
	_move_to_lane(app.game, lane)
	for index in 420:
		if app.state == app.State.GAME_OVER:
			break
		await physics_frame
	_check(app.state == app.State.GAME_OVER, "real Area3D contact triggers game over")
	_check(endings == 1 and int(app.profile.data.best_score) > 0, "one crash signal and saved best score")
	await _frames(25)
	_check(endings == 1, "crash remains latched")
	_press(app, "Restart")
	_check(app.game._player.lane == 1 and float(app.game.progress.distance) < 1.0, "restart clears run state")
	var peak_traffic: int = 0
	var peak_coins: int = 0
	var saw_descent: bool = false
	var saw_cave_traffic: bool = false
	var saw_surface_traffic: bool = false
	var peak_height: float = 0.0
	var saw_chariots: bool = false
	_send_key(KEY_W)
	for index in 10000:
		await physics_frame
		if app.state != app.State.PLAYING:
			_check(false, "following the seeded route survives all waves")
			break
		var distance := float(app.game.progress.distance)
		if distance >= app.game.FINALE_DISTANCE - app.game.FINALE_APPROACH:
			break
		if distance >= RoadGenerator.LAUNCH_START - 65.0 and distance < RoadGenerator.LAUNCH_START:
			_move_to_lane(app.game, 2)
		else:
			for token: Area3D in app.game._coins:
				if token.position.z < -15.0 and token.position.z > -20.0:
					_move_to_lane(app.game, 1 + roundi(token.position.x / app.game.lane_width))
					break
		peak_traffic = maxi(peak_traffic, app.game._traffic.size())
		peak_coins = maxi(peak_coins, app.game._coins.size())
		peak_height = maxf(peak_height, app.game._player.position.y)
		if distance > RoadGenerator.RAMP_START and distance < RoadGenerator.RAMP_END:
			saw_descent = saw_descent or (app.game._player.position.y < 0.0
				and app.game._player.visual.rotation.x < 0.0 and app.game._camera.position.y < 5.0)
		elif distance > RoadGenerator.RAMP_END + 60.0 and not saw_cave_traffic:
			saw_cave_traffic = not app.game._traffic.is_empty()
			for obstacle in app.game._traffic:
				if not is_instance_valid(obstacle.insect) or not is_equal_approx(obstacle.position.y, -RoadGenerator.CAVE_DEPTH):
					_check(false, "underground traffic uses insects at cave road height")
					break
		if distance > RoadGenerator.CAVE_EXIT_END + 60.0 and distance < RoadGenerator.LAUNCH_START - 150.0:
			for obstacle: TrafficCar in app.game._traffic:
				saw_surface_traffic = saw_surface_traffic or (obstacle.style == TrafficCar.Style.CAR
					and is_zero_approx(obstacle.position.y) and is_zero_approx(app.game._player.position.y))
		if distance > RoadGenerator.SKY_LANDING + 60.0:
			for obstacle: TrafficCar in app.game._traffic:
				saw_chariots = saw_chariots or (obstacle.style == TrafficCar.Style.CHARIOT
					and is_equal_approx(obstacle.position.y, RoadGenerator.SKY_HEIGHT))
	_send_key(KEY_W, false, false)
	_check(saw_descent and saw_cave_traffic, "the run descends into the cave and continues with traffic")
	_check(saw_surface_traffic, "the cave exit returns to surface traffic")
	_check(peak_height > RoadGenerator.SKY_HEIGHT + 5.0 and saw_chariots
		and is_equal_approx(app.game._player.position.y, RoadGenerator.SKY_HEIGHT),
		"the right lane launches above the skyway and lands among chariots")
	_check(peak_traffic <= 12 and peak_coins <= 16 and app.game._road.segments.size() == 4, "world object counts remain bounded")
	_check(app.game.progress.distance > 3500.0 and app.game.progress.coins >= 30 and app.game.progress.score > int(app.game.progress.distance), "distance, coins and overtake score advance")
	_press(app, "Pause")
	_press(app, "Main Menu")
	_check(is_zero_approx(app.game._player.position.y) and is_equal_approx(app.game._camera.position.y, 5.0),
		"leaving the skyway resets the road and camera to the surface")
	_press(app, "Garage")
	_press(app, "02")
	_press(app, "Unlock  /  30 coins")
	_check(app.profile.data.selected == 1 and app.profile.data.unlocked[1], "garage purchase unlocks and selects the vehicle")
	_press(app, "Back")
	await _check_driving_controls_and_ground_route()
	await _check_finale(app)
	_check_chapters(app)
	_finish()


func _check_intro(app: Node) -> void:
	_press(app, "Play")
	_check(app.state == app.State.INTRO and not app.game.playing, "the garage prologue starts before gameplay")
	if app.state != app.State.INTRO:
		return
	var spoken_lines: Array[String] = []
	app._intro.subtitle_changed.connect(func(_speaker: String, line: String) -> void:
		if not line.is_empty():
			spoken_lines.append(line)
	)
	var elapsed_frames := 0
	while app.state == app.State.INTRO and elapsed_frames < 3100:
		await physics_frame
		elapsed_frames += 1
	_check(elapsed_frames >= 2990 and elapsed_frames <= 3040 and spoken_lines.size() == 8,
		"the eight subtitle lines play during a 50-second prologue")
	_check(app.state == app.State.PLAYING and app.game._camera.current and app.game._player.visible
		and is_zero_approx(app.game.progress.distance), "the prologue hands the highway camera and controls to the player")


func _check_finale(app: Node) -> void:
	_press(app, "Play")
	_send_key(KEY_ESCAPE)
	_send_key(KEY_ESCAPE, false, false)
	_check(app.state == app.State.PLAYING, "Escape skips the prologue and starts the run")
	var game = app.game
	var finish_distance := 10000.0
	game.progress.distance = finish_distance - 0.2
	game._spawner.next_arrival = finish_distance + 100.0
	await _frames(4)
	_check(app.state == app.State.PLAYING and not is_instance_valid(game._finale),
		"the highway stays open at 10 km")
	game.progress.distance = finish_distance - 0.2
	game._sky_route = true
	var cues: Array[String] = []
	game.finale_cue.connect(func(cue: String) -> void: cues.append(cue))
	await _frames(4)
	_check(app.state == app.State.FINALE and not game.playing and is_equal_approx(game.progress.distance, finish_distance),
		"reaching 10 km on the skyway starts the finale at the exact distance")
	for index in 2400:
		if app.state != app.State.FINALE:
			break
		await physics_frame
	_check(cues.size() == 17 and cues.front() == "parked" and cues.count("shot") == 15 and cues[13] == "depart",
		"the castle raid and police gunfire play in sequence")
	_check(app.state == app.State.PLAYING and game.playing and game._pursuing and game._camera.current
		and game._police.size() == 2, "the police chase hands control back to the player")
	if app.state != app.State.PLAYING or not game._pursuing:
		return
	var finale = game._finale
	_check(absf(finale._palace.doors[0].rotation.y) > 1.0 and absf(finale._palace.doors[1].rotation.y) > 1.0,
		"both palace doors swing open before the characters enter")
	_check(not finale._driver.visible and not finale._friend.visible and not finale._princess.visible
		and game._player.lane == 0, "all three board and the car starts the chase on the return route")
	var incoming: TrafficCar = game._traffic[0]
	var before := incoming.position.z
	await _frames(4)
	_check(incoming.position.z > before and is_equal_approx(incoming.rotation.y, PI),
		"oncoming traffic faces and drives toward the player")
	var rescue_lines: Array[String] = []
	game.rescue_subtitle.connect(func(_speaker: String, line: String) -> void:
		if not line.is_empty():
			rescue_lines.append(line)
	)
	var traffic_clear := true
	_send_key(KEY_W)
	for frame in 1600:
		await physics_frame
		if app.state != app.State.PLAYING:
			break
		var nearest_z := -INF
		var safe_lane := int(game._player.lane)
		for vehicle: TrafficCar in game._traffic:
			if vehicle.position.z > nearest_z and vehicle.position.z <= 5.5:
				nearest_z = vehicle.position.z
				safe_lane = vehicle.pursuit_gap
			for police in game._police:
				if absf(police.position.z - vehicle.position.z) < (3.7 + vehicle.length) * 0.5:
					traffic_clear = traffic_clear and absf(police.position.x - vehicle.position.x) > TrafficCar.WIDTH
		_move_to_lane(game, safe_lane)
	_send_key(KEY_W, false, false)
	_check(traffic_clear, "the two police cars avoid oncoming traffic for the full chase")
	_check(app.state == app.State.FINALE and not game.playing and is_instance_valid(game._rescue),
		"reaching the edge triggers the helicopter rescue")
	var rescue_frames := 0
	while app.state == app.State.FINALE and rescue_frames < 6000:
		await physics_frame
		rescue_frames += 1
	_check(rescue_frames >= 2700 and rescue_lines.size() == 13, "the rescue and helicopter escape play their full dialogue")
	if app.state == app.State.CITY:
		_check(not game._rescue._broken_blade.visible and game._rescue._jumpers.size() == 2
			and app._city.player.camera.current, "the two passengers jump and control passes to the driver's first-person camera")
	_check(app.state == app.State.CITY and app.run_saved
		and int(app.profile.data.best_distance) == int(game.FINALE_DISTANCE + game.CHASE_LENGTH),
		"the helicopter escape saves the driving distance and starts the city phase")
	if app.state == app.State.CITY:
		await _check_city(app)
	app._show_menu()
	_check(not is_instance_valid(app._city) and game._camera.current, "the menu restores the road camera")


func _check_city(app: Node) -> void:
	var city = app._city
	var player = city.player
	player.position = Vector3(20, 22, 22)
	player.velocity = Vector3(0, -12, 0)
	_send_key(KEY_SPACE)
	_send_key(KEY_SPACE, false, false)
	for frame in 360:
		if player.phase == player.Phase.GROUND or app.state != app.State.CITY:
			break
		await physics_frame
	_check(app.state == app.State.CITY and player.phase == player.Phase.GROUND and player.damage.alive,
		"deploying a parachute lands safely and enables first-person ground movement")
	if app.state == app.State.CITY:
		await _frames(2)
		await _wait_city_cinematic(city.story)
		var landed: Vector3 = player.position
		_send_key(KEY_W)
		await _frames(25)
		_send_key(KEY_W, false, false)
		_check(player.position.z < landed.z - 0.5, "W walks forward on the ground")
		_send_key(KEY_SPACE)
		_send_key(KEY_SPACE, false, false)
		await _frames(12)
		_check(player.position.y > landed.y + 0.35, "Space jumps on the ground")
	app._start_city()
	player = app._city.player
	player.position = Vector3(20, 6, 20)
	player.velocity = Vector3(0, -45, 0)
	await _frames(30)
	_check(app.state == app.State.CITY_OVER, "an impact without a parachute is fatal")
	if app.state != app.State.CITY_OVER:
		return
	_press(app, "Restart drop")
	player = app._city.player
	app._city.story.stage = app._city.story.Stage.CAFE
	var car: CharacterBody3D = app._city.traffic.vehicles[0]
	player.phase = player.Phase.GROUND
	player.position = car.position - car.basis.z * 2.45
	var before_impact: Vector3 = player.position
	player.velocity = Vector3.ZERO
	await _frames(30)
	_check(app.state == app.State.CITY and player.damage.alive and player.position.distance_to(before_impact) > 0.45,
		"a moving car knocks the player back without ending the run")
	app._start_city()
	player = app._city.player
	app._city.story.stage = app._city.story.Stage.CAFE
	player.phase = player.Phase.GROUND
	player.position = Vector3(0, 0.05, -23)
	player.velocity = Vector3.ZERO
	await _frames(330)
	_check(app.state == app.State.CITY and player.damage.hp > 0 and player.damage.hp < player.damage.MAX_HP,
		"enemy bullets drain the player's health without killing in one hit")
	await _check_city_interactions(app)
	await _check_city_vehicles(app)
	await _check_city_story(app)


func _check_city_interactions(app: Node) -> void:
	app._start_city()
	var city = app._city
	var player = city.player
	city.story.stage = city.story.Stage.CAFE
	player.phase = player.Phase.GROUND
	player.position = Vector3(5.1, 0.10, -22.0)
	player.velocity = Vector3.ZERO
	player.camera.look(Vector2(0, -243))
	await _frames(27)
	var guard: Area3D = city.npcs._guards[0]
	_fire_pistol()
	await _frames(8)
	_check(is_instance_valid(guard) and guard.get_node("Health").current_health < 100.0 and city.hud._hit_time > 0.0,
		"left click fires through the sights and damages the guard")
	await _frames(10)
	_fire_pistol()
	await _frames(6)
	_check(not is_instance_valid(guard) and city.hud._lethal, "a second body hit disables and drops the guard")

	app._start_city()
	city = app._city
	city.story.stage = city.story.Stage.CAFE
	player = city.player
	var venue = city.places.venues[0]
	player.phase = player.Phase.GROUND
	player.position = venue.threshold + Vector3(0, 0.02, 1.45)
	player.velocity = Vector3.ZERO
	await _frames(5)
	_send_key(KEY_E)
	_send_key(KEY_E, false, false)
	await _frames(27)
	_check(venue.door.opened, "E opens the cafe's physical door")
	_send_key(KEY_W)
	await _frames(38)
	_send_key(KEY_W, false, false)
	_check(player.position.z < venue.threshold.z - 0.45, "the cafe interior can be entered on foot")


func _fire_pistol() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check_city_story(app: Node) -> void:
	app._start_city()
	var city = app._city
	var player = city.player
	var story = city.story
	var durations: Array[float] = []
	var titles: Array[String] = []
	var camera_changes: Array[bool] = []
	story.cinematic_changed.connect(func(active: bool) -> void: camera_changes.append(active))
	story.cinema.clip_finished.connect(func() -> void:
		durations.append(story.cinema._elapsed)
		titles.append(story.cinema.title))
	player.phase = player.Phase.GROUND
	player.position = city.places.venues[0].inside
	player.velocity = Vector3.ZERO
	player.rotation.y = -PI * 0.5
	player.camera.look(Vector2(0, -265))
	await _frames(14)
	_check(story.cinematic and not player.camera.current, "landing switches to an animated camera")
	await _wait_city_cinematic(story)
	_check(story.stage == story.Stage.CAFE, "landing starts the reunion at the cafe")
	var ally: Area3D = story._allies[0]
	_fire_pistol()
	await _frames(5)
	_check(is_instance_valid(ally) and ally.visible and city.hud._hit_time <= 0.0
		and city.hud._alert.text == "Ally · hold your fire", "a shot into the princess is blocked without damage")
	_send_key(KEY_E)
	_send_key(KEY_E, false, false)
	await _frames(18)
	var driver: Node3D = story.cinema._cast[0]
	var princess: Node3D = story.cinema._cast[1]
	var toward: Vector3 = driver.position.direction_to(princess.position)
	_check((-driver.basis.z).dot(toward) > 0.98 and (-princess.basis.z).dot(-toward) > 0.98,
		"the two speakers in the cafe face each other")
	await _wait_city_cinematic(story)
	_check(camera_changes == [true, false, true, false] and player.camera.current,
		"the three cafe shots keep control locked and restore the first-person camera once")
	_check(story.stage == story.Stage.BUS and story._bus_moving, "the cafe reunion starts the bus route")
	story._bus.route.queue_free()
	story._bus.route = null
	await _frames(3)
	await _wait_city_cinematic(story)
	_check(not story._bus_moving and story._allies[1].visible, "the friend gets out even if the bus is stopped early")
	for next_stage in [story.Stage.WRECK, story.Stage.RADIO, story.Stage.ESCAPE]:
		player.position = story.destination
		player.velocity = Vector3.ZERO
		await _frames(2)
		_send_key(KEY_E)
		_send_key(KEY_E, false, false)
		await _wait_city_cinematic(story)
		_check(story.stage == next_stage, "the reunion, rescue, and broadcast advance the story")
	var getaway = city.traffic.vehicles.back()
	player.position = getaway.to_global(Vector3(-2.0, 0.04, 0))
	await _frames(3)
	_send_key(KEY_F)
	_send_key(KEY_F, false, false)
	await _frames(90)
	getaway.position = Vector3(2189, 0.02, -2.6)
	await _frames(6)
	var freeze: float = story.remaining
	await _frames(90)
	_check(story.cinematic and is_equal_approx(story.remaining, freeze), "the highway chase animation freezes the countdown")
	await _wait_city_cinematic(story)
	await _frames(3)
	_check(city.npcs._patrols.is_empty(), "the pursuit does not spawn officers beside the moving player")
	var responding_cruiser: Node3D
	for unit in city.traffic._police:
		if unit.driver and unit.position.distance_to(player.position) < 350.0:
			responding_cruiser = unit
			break
	_check(is_instance_valid(responding_cruiser), "the escape dispatches a physical police cruiser")
	if is_instance_valid(responding_cruiser):
		var before := responding_cruiser.position
		await _frames(24)
		_check(responding_cruiser.position.distance_to(before) > 1.0,
			"the cruiser drives through the world while pursuing the player")
		_check(city.npcs._patrols.is_empty(), "police remain in their cars during the pursuit")

	app._start_city()
	city = app._city
	city.story.stage = city.story.Stage.CAFE
	player = city.player
	player.phase = player.Phase.GROUND
	player.position = Vector3(160, 0.10, 151)
	player.velocity = Vector3.ZERO
	player.camera.look(Vector2(0, -265))
	var witness = city.crowd._walkers[0]
	await _frames(16)
	witness.body.position = player.position + Vector3(0, 0, -3.5)
	witness.wait = 20.0
	witness.active = true
	witness.body.show()
	witness.body.set_targetable(true)
	await _frames(3)
	_fire_pistol()
	await _frames(6)
	_check(witness.dead and witness not in city.crowd._walkers and city.hud._lethal,
		"a pedestrian dies from a headshot and leaves the active crowd")
	var parked = city.traffic.park_vehicle(0, Color.SLATE_GRAY, Vector3(161, 0, 149), 0.0)
	player.position = parked.to_global(Vector3(-4.0, 0.0, parked.seat().z))
	player.rotation.y = -PI * 0.5
	player.camera.look(Vector2(0, 43))
	await _frames(24)
	_fire_pistol()
	await _frames(17)
	_check(parked.driver_target and parked.driver_target.health.current_health < 100.0,
		"a pistol shot through the side window damages the driver")
	_fire_pistol()
	await _frames(6)
	_check(parked.driver == null and city.hud._lethal, "a second shot kills the driver")

	app._start_city(city.story.Start.ESCAPE)
	city = app._city
	story = city.story
	_check(story.stage == story.Stage.ESCAPE and is_equal_approx(story.remaining, 120.0),
		"the final chapter starts a two-minute countdown")
	app._pause_city()
	await _frames(10)
	_check(is_equal_approx(story.remaining, 120.0), "pausing freezes the escape countdown")
	app._resume_city()
	story.remaining = 0.03
	await _frames(10)
	_check(app.state == app.State.CITY_OVER, "missing the launch deadline fails the mission")
	_press(app, "Restart escape")
	city = app._city
	story = city.story
	player = city.player
	story.cinema.clip_finished.connect(func() -> void:
		durations.append(story.cinema._elapsed)
		titles.append(story.cinema.title))
	player.position = story.HATCH
	await _frames(4)
	_send_key(KEY_E)
	_send_key(KEY_E, false, false)
	for frame in 1260:
		if story.ignition_pending:
			break
		await physics_frame
	_check(story.ignition_pending and is_zero_approx(story.launch_throttle),
		"Erik has to raise the launch thrust from inside the rocket")
	_send_key(KEY_W)
	await _wait_city_cinematic(story)
	_send_key(KEY_W, false, false)
	await _frames(2)
	_check(app.state == app.State.SPACE and is_instance_valid(app._space),
		"boarding the rocket before impact hands over flight controls to Erik")
	_check(titles.size() == 15 and titles.size() == durations.size() and durations.min() >= 20.0,
		"all fifteen city cutscenes run for at least twenty seconds before launch")
	if app.state == app.State.SPACE:
		await _check_space_flight(app)


func _check_space_flight(app: Node) -> void:
	var flight = app._space
	var speed: float = -flight.flight_velocity.z
	for code in [KEY_A, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SPACE]:
		_send_key(code, false, false)
	_send_key(KEY_D)
	_send_key(KEY_W)
	await _frames(43)
	_send_key(KEY_D, false, false)
	_send_key(KEY_W, false, false)
	_check(flight.world.ship.position.x > 2.0 and -flight.flight_velocity.z > speed,
		"Erik steers and adjusts rocket throttle using keyboard input")
	var rock = flight._rocks.back()
	rock.origin = flight.world.ship.position - Vector3(0, 0, 3.0)
	rock.drift = Vector2.ZERO
	await _frames(5)
	_check(flight.hull == 66, "an asteroid hit damages the hull once")
	flight.world.ship.position.z = -flight.TRANSFER + 0.2
	await _frames(4)
	_check(flight.phase == flight.Phase.DESCENT and flight.world.surface.visible,
		"clearing the asteroid field starts descent to the Vesper base")
	flight.world.ship.position = Vector3(0, 0.90, 0)
	flight.flight_velocity = Vector3(0, -8.0, 0)
	await _frames(4)
	_check(app.state == app.State.SPACE_OVER, "a fast touchdown fails even in the center of the pad")
	_press(app, "Retry landing")
	flight = app._space
	_check(flight.phase == flight.Phase.DESCENT, "landing can be retried without repeating the asteroid field")
	flight.world.ship.position = Vector3(0.55, 0.87, 0.65)
	flight.flight_velocity = Vector3(0, -1.2, 0)
	await _frames(10)
	_check(flight.phase == flight.Phase.TOUCHDOWN and flight.hud._speaker == 3,
		"a centered gentle landing plays the crew's animated touchdown conversation")
	await _frames(1210)
	_check(flight.phase == flight.Phase.EPILOGUE and app.state == app.State.SPACE,
		"landing opens the playable first-person cabin")
	if flight.phase != flight.Phase.EPILOGUE:
		return
	var epilogue = flight.epilogue
	epilogue._walker = epilogue.HATCH
	var interact := _key(KEY_E)
	epilogue._unhandled_input(interact)
	_check(epilogue._beat == -1, "the hatch stays closed until everyone has sealed their suit")
	epilogue._walker = epilogue.RACK
	epilogue._unhandled_input(interact)
	await _frames(180)
	_check(epilogue._suited and epilogue._gear.all(func(gear: Node3D) -> bool: return gear.visible),
		"Erik and the crew equip their suits")
	epilogue._walker = epilogue.HATCH
	epilogue._unhandled_input(interact)
	_check(epilogue._beat == 0 and epilogue.can_skip(), "the hatch starts the skippable ending")
	for beat in epilogue.DURATIONS.size():
		if beat == 1:
			epilogue._render_beat(1.0)
			_check(epilogue._helmets[1].visible and epilogue._actors[0].position.distance_to(epilogue._actors[1].position) > 10.0,
				"the princess falls behind the crew before the visor breaks")
		elif beat == 2:
			epilogue.skip()
			_check(epilogue._choice_pending() and not epilogue.can_skip(), "the rescue choice pauses the cinematic and cannot be skipped")
			epilogue._choose_rescue(epilogue.RescueChoice.SACRIFICE)
			epilogue._render_beat(0.68)
			_check(not epilogue._helmets[1].visible and epilogue._gear[0].get_parent() == epilogue._actors[0],
				"Erik reaches the princess before transferring his suit")
			epilogue._render_beat(0.95)
			_check(epilogue._gear[0].get_parent() == epilogue._actors[1], "Erik gives his suit to the princess")
		elif beat == 8:
			epilogue._render_beat(0.06)
			_check(epilogue._credits.visible and epilogue._space_objects[0].visible,
				"credits begin over the Vesper reveal")
			epilogue._render_beat(0.25)
			_check(not epilogue._space_objects[0].visible and epilogue._space_objects[1].visible,
				"Saturn follows Vesper in a separate shot")
		else:
			epilogue._render_beat(0.95)
		epilogue.skip()
	_check(app.state == app.State.SPACE_COMPLETE, "the mission completes after the credits")


func _wait_city_cinematic(story: Node) -> void:
	for frame in 5300:
		if not is_instance_valid(story) or not story.cinematic:
			break
		await physics_frame


func _check_city_vehicles(app: Node) -> void:
	app._start_city()
	var city = app._city
	var player = city.player
	city.story.stage = city.story.Stage.CAFE
	var vehicle: CharacterBody3D = city.traffic.vehicles[0]
	vehicle.route.queue_free()
	vehicle.route = null
	vehicle.position = Vector3(10, 0, 2.8)
	vehicle.rotation.y = -PI * 0.5
	vehicle.speed = 0.0
	player.phase = player.Phase.GROUND
	player.position = vehicle.to_global(Vector3(-2.06, 0.04, 0.05))
	player.velocity = Vector3.ZERO
	await _frames(5)
	_check(city.traffic.nearby == vehicle, "a nearby driver's door offers the hijack prompt")
	_send_key(KEY_F)
	_send_key(KEY_F, false, false)
	await _frames(92)
	_check(player.mounted and city.traffic.driven == vehicle and player.camera.get_parent() == vehicle
		and vehicle.driver == null and vehicle.dashboard.visible, "hijacking ejects the driver and puts the player at the dashboard")
	_send_key(KEY_W)
	await _frames(35)
	_send_key(KEY_W, false, false)
	_check(vehicle.speed > 3.0, "W accelerates the hijacked vehicle")
	vehicle.position = Vector3(19.0, 0.02, 3.0)
	vehicle.rotation.y = PI
	vehicle.velocity = Vector3.ZERO
	vehicle.speed = 0.0
	_send_key(KEY_W)
	await _frames(68)
	_send_key(KEY_W, false, false)
	_check(vehicle.position.z > 6.5 and player.damage.alive, "the suspension crosses the bevelled curb onto the park sidewalk")
	_send_key(KEY_F)
	_send_key(KEY_F, false, false)
	await _frames(28)
	_check(not player.mounted and player.camera.get_parent() == player, "F returns control to the pedestrian")

	app._start_city()
	city = app._city
	var bus: CharacterBody3D
	for candidate in city.traffic.vehicles:
		if candidate.type_index == 5:
			bus = candidate
			break
	var route := bus.route.get_parent() as Path3D
	bus.route.progress = route.curve.get_closest_offset(bus.bus_stops[0]) - 7.0
	bus.position = bus.route.global_position
	bus.rotation.y = -PI * 0.5
	bus.speed = 7.0
	city.player.set_enabled(false)
	var starts: Array[Vector3] = []
	for walker in city.crowd._walkers:
		starts.append(walker.body.position)
	await _frames(160)
	_check(bus.dwell > 0.0 and not city.crowd._passengers.get(bus, []).is_empty(),
		"the bus stops at the shelter and boards waiting pedestrians")
	await _frames(250)
	var walkers_moving := 0
	for index in city.crowd._walkers.size():
		var walker = city.crowd._walkers[index]
		if walker.idle_mode == 0 and walker.body.position.distance_to(starts[index]) > 0.10:
			walkers_moving += 1
	_check(walkers_moving > 5, "navigation agents move along the sidewalks")


func _check_chapters(app: Node) -> void:
	app._show_menu()
	_press(app, "Chapters")
	_press(app, "Crystal Cavern")
	_check(app.state == app.State.PLAYING and app.game.progress.distance > RoadGenerator.RAMP_END
		and app.game._player.position.y == -RoadGenerator.CAVE_DEPTH and app.run_saved, "the cavern chapter opens in the cave")
	app._show_menu()
	_press(app, "Chapters")
	_press(app, "Police pursuit")
	_check(app.state == app.State.PLAYING and app.game._pursuing and app.game._police.size() == 2,
		"the pursuit chapter starts with the police behind the player")
	app._show_menu()
	_press(app, "Chapters")
	_press(app, "Helicopter escape")
	_check(app.state == app.State.FINALE and app.game._rescue._crew.size() == 3,
		"the helicopter chapter opens with all three passengers aboard")
	app._show_menu()
	_press(app, "Chapters")
	_press(app, "Skydive and city")
	_check(app.state == app.State.CITY and app._city.player.camera.current, "the drop can be started from Chapters")
	_check(app._city.npcs._guards.size() == 8, "the city starts with eight fixed police officers")
	app._show_menu()
	_press(app, "Chapters")
	_press(app, "Helicopter Wreck")
	var wreck = app._city
	_check(app.state == app.State.CITY and wreck.story.stage == wreck.story.Stage.WRECK
		and wreck.player.phase == wreck.player.Phase.GROUND and wreck.player.damage.alive
		and wreck.player.position.distance_to(wreck.story.destination) < 10.0
		and wreck.player.camera.current, "the wreck chapter starts beside the crash with control of Erik")
	app._pause_city()
	_press(app, "Restart at wreck")
	wreck = app._city
	_check(wreck.story.stage == wreck.story.Stage.WRECK, "restarting keeps the wreck checkpoint")
	app._show_menu()


func _check_driving_controls_and_ground_route() -> void:
	var game := GameScene.instantiate()
	game.random_seed = 873
	root.add_child(game)
	game._spawner.next_arrival = 1000.0
	var starting_speed := float(game.speed)
	_send_key(KEY_UP)
	await _frames(30)
	_send_key(KEY_UP, false, false)
	var cruising_speed := float(game.speed)
	await _frames(10)
	_check(cruising_speed > starting_speed and is_equal_approx(game.speed, cruising_speed),
		"holding Up accelerates and releasing it maintains speed")
	_send_key(KEY_S)
	await _frames(80)
	_send_key(KEY_S, false, false)
	var stopped_at := float(game.progress.distance)
	await _frames(10)
	_check(is_zero_approx(game.speed) and is_equal_approx(game.progress.distance, stopped_at),
		"holding S can bring the car to a full stop")
	_send_key(KEY_W)
	await _frames(360)
	_send_key(KEY_W, false, false)
	_check(is_equal_approx(game.speed * 3.6, 250.0), "W accelerates from rest to the speed cap")
	_send_key(KEY_DOWN)
	await _frames(12)
	_send_key(KEY_DOWN, false, false)
	var speed_before_drift := float(game.speed)
	_check(speed_before_drift * 3.6 < 250.0, "Down Arrow brakes")
	_send_key(KEY_SPACE)
	_send_key(KEY_D)
	await _frames(10)
	_check(game._player.rotation.y < -0.15 and game._player._tire_smoke[0].emitting and game.speed < speed_before_drift,
		"the handbrake slows the car, rotates it into a drift, and emits tire smoke")
	_send_key(KEY_SPACE, false, false)
	await _frames(60)
	_check(absf(game._player.rotation.y) < 0.01 and not game._player._tire_smoke[0].emitting
		and is_equal_approx(game._player.position.x, game.lane_width), "the car straightens in its lane after drifting")
	game.start_run(0)
	game.progress.distance = RoadGenerator.LAUNCH_START - 2.0
	game._spawner.next_arrival = RoadGenerator.LAUNCH_START + 90.0
	while game.playing and game.progress.distance < RoadGenerator.LAUNCH_LIP + 18.0:
		await physics_frame
	_check(game.playing and not game._sky_route and is_zero_approx(game._player.position.y),
		"the middle lane bypasses the launch on the highway")
	_check(not game._traffic.is_empty() and game._traffic[0].style == TrafficCar.Style.CAR,
		"highway traffic continues past the launch")
	game.start_run(0)
	game.progress.distance = RoadGenerator.LAUNCH_START - 1.0
	game._spawner.next_arrival = RoadGenerator.SKY_LANDING + 100.0
	game._player.lane = 2
	game._player.position.x = game.lane_width
	await _frames(12)
	var launch_speed := float(game.speed)
	_send_key(KEY_S)
	await _frames(65)
	_send_key(KEY_S, false, false)
	_check(game._sky_route and game._player.position.y > 30.0 and is_equal_approx(game.speed, launch_speed),
		"a slow approach still launches and braking in the air cannot stall the jump")
	game.queue_free()


func _check_waves() -> void:
	var spawner := TrafficSpawner.new()
	for seed_value in range(100):
		spawner.reset(seed_value, 100.0)
		var prior_lane: int = 1
		var prior_arrival: float = 0.0
		for index in range(100):
			var wave := spawner.next_wave(1.0)
			if wave.safe_lane in wave.lanes or absi(wave.safe_lane - prior_lane) > 1 or wave.arrival - prior_arrival < 42.99:
				_check(false, "fair wave spacing and reachable open lane")
				return
			prior_lane = wave.safe_lane
			prior_arrival = wave.arrival
	print("Checked 10,000 seeded waves.")


func _frames(count: int) -> void:
	for index in count:
		await physics_frame


func _move_to_lane(game: Node, lane: int) -> void:
	for index in absi(int(game._player.lane) - lane):
		_send_key(KEY_A if lane < int(game._player.lane) else KEY_D)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	if code == KEY_ESCAPE:
		event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _send_key(code: Key, echo: bool = false, pressed: bool = true) -> void:
	var event := _key(code)
	event.echo = echo
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _press(app: Node, title: String) -> void:
	for button: Button in app.screen.find_children("*", "Button", true, false):
		if button.text == title and not button.disabled:
			button.pressed.emit()
			return
	_check(false, "available button: " + title)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func _finish() -> void:
	print("Traffic Dodge smoke failures: ", failures)
	quit(0 if failures == 0 else 1)

