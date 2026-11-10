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
	for index in 2000:
		if app.state != app.State.FINALE:
			break
		await physics_frame
	_check(cues.size() == 14 and cues.front() == "parked" and cues.count("shot") == 12 and cues.back() == "depart",
		"the pair shoots all twelve guards before the getaway")
	_check(app.state == app.State.COMPLETE and app.run_saved and int(app.profile.data.best_distance) == int(game.FINALE_DISTANCE),
		"the finale finishes the run and saves the distance")
	if app.state != app.State.COMPLETE:
		return
	var finale = game._finale
	_check(absf(finale._palace.doors[0].rotation.y) > 1.0 and absf(finale._palace.doors[1].rotation.y) > 1.0,
		"both palace doors swing open before the characters enter")
	_check(not finale._driver.visible and not finale._friend.visible and not finale._princess.visible
		and game._player.position.z > 70.0 and is_equal_approx(absf(game._player.rotation.y), PI),
		"all three board before the car turns and drives back down the road")
	_press(app, "Restart")
	_check(app.state == app.State.PLAYING and game.playing and not is_instance_valid(game._finale)
		and game._camera.current and is_zero_approx(game.progress.distance),
		"restarting after the finale restores the normal camera and highway")


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

