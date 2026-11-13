extends Node

const GAME: PackedScene = preload("res://scenes/game.tscn")
const GameRules = preload("res://scripts/game.gd")
const CityPhase = preload("res://scripts/city_phase.gd")
const CityStory = preload("res://scripts/city_story.gd")
const SpaceFlight = preload("res://scripts/space_flight.gd")
const VehicleVisual = preload("res://scripts/vehicle_visual.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const AudioManager = preload("res://scripts/audio_manager.gd")
const GarageIntro = preload("res://scripts/garage_intro.gd")
const INK: Color = Color("#0d1822")
const PAPER: Color = Color("#f1f7f8")
const MUTED: Color = Color("#a6bac6")
const MINT: Color = Color("#70f5ce")
const GOLD: Color = Color("#ffd288")
const Catalog = preload("res://scripts/garage_catalog.gd")
const PAINT = Catalog.PAINTS
const DRIVE_CONTROLS: String = "A / D  or  ← / →   STEER    ·    W / ↑   GAS    ·    S / ↓   BRAKE    ·    SPACE   DRIFT    ·    ESC   PAUSE"

enum State { MENU, PLAYING, PAUSED, GAME_OVER, GARAGE, SETTINGS, INTRO, FINALE, CHAPTERS, CITY, CITY_PAUSED, CITY_OVER, SPACE, SPACE_PAUSED, SPACE_OVER, SPACE_COMPLETE }

var state: State = State.MENU
var settings_return: State = State.MENU
var profile := SaveManager.new()
var audio := AudioManager.new()
var game: Node3D
var overlay: Control
var screen: Control
var hud_values: Array[Label] = []
var _nitro_label: Label
var current_score: int = 0
var current_distance: float = 0.0
var current_coins: int = 0
var run_saved: bool = true
var garage_index: int = 0
var ui_theme: Theme
var _intro: GarageIntro
var _subtitle_panel: PanelContainer
var _subtitle_speaker: Label
var _subtitle_text: Label
var _chapter: GameRules.Chapter = GameRules.Chapter.HIGHWAY
var _city: CityPhase
var _space: SpaceFlight
var _skip_button: Button


func _ready() -> void:
	get_window().min_size = Vector2i(640, 360)
	add_child(profile)
	profile.load_data()
	add_child(audio)
	audio.apply(profile.data)
	game = GAME.instantiate() as Node3D
	add_child(game)
	game.connect(&"stats_changed", _update_stats)
	game.connect(&"run_ended", _on_run_ended)
	game.connect(&"finale_started", _show_finale)
	game.connect(&"finale_cue", _on_finale_cue)
	game.connect(&"pursuit_started", _show_pursuit)
	game.connect(&"rescue_started", _show_rescue)
	game.connect(&"rescue_subtitle", _show_intro_subtitle)
	game.connect(&"city_started", _start_city)
	_apply_shadows()
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.theme = _make_theme()
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show_menu()


func _process(_delta: float) -> void:
	if is_instance_valid(_skip_button):
		_skip_button.visible = _skip_action().is_valid()
	if is_instance_valid(_nitro_label):
		_update_nitro_hud()


func _skip_action() -> Callable:
	match state:
		State.INTRO:
			return _finish_intro
		State.FINALE:
			return game.skip_cutscene
		State.CITY:
			if is_instance_valid(_city) and _city.story.cinema.active:
				return _skip_city_clip
			if is_instance_valid(_city) and _city.story.can_skip_launch():
				return _city.story.skip_launch
			if is_instance_valid(_city) and _city.traffic.can_skip_transition():
				return _city.traffic.skip_transition
		State.SPACE:
			if is_instance_valid(_space):
				if _space.phase == SpaceFlight.Phase.TOUCHDOWN:
					return _space.finish_touchdown
				if is_instance_valid(_space.epilogue) and _space.epilogue.can_skip():
					return _space.epilogue.skip
	return Callable()


func _skip_city_clip() -> void:
	_city.hud.say("")
	_city.story.cinema.finish_clip()


func _skip_animation() -> void:
	var action := _skip_action()
	if action.is_valid():
		action.call()


func _add_skip_button() -> void:
	_skip_button = _button(screen, "Skip", _skip_animation)
	_skip_button.name = "Skip"
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_skip_button.offset_left = -128
	_skip_button.offset_right = -20
	_skip_button.offset_top = 12
	_skip_button.offset_bottom = 57
	_skip_button.visible = _skip_action().is_valid()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel") or event.is_echo():
		return
	var skip := _skip_action()
	if skip.is_valid():
		get_viewport().set_input_as_handled()
		skip.call()
		return
	match state:
		State.PLAYING:
			_pause()
		State.PAUSED:
			_resume()
		State.CITY:
			_pause_city()
		State.CITY_PAUSED:
			_resume_city()
		State.SPACE:
			_pause_space()
		State.SPACE_PAUSED:
			_resume_space()
		State.GARAGE, State.GAME_OVER, State.CHAPTERS, State.CITY_OVER, State.SPACE_OVER, State.SPACE_COMPLETE:
			_show_menu()
		State.SETTINGS:
			_close_settings()
		_:
			return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(profile) and is_instance_valid(game):
		_commit_run()
		profile.save_data()


func _show_menu() -> void:
	audio.music.stream_paused = false
	_commit_run()
	_remove_city()
	_remove_space()
	game.call(&"show_backdrop", int(profile.data.selected))
	audio.set_driving(false)
	_new_screen(State.MENU)
	_shade(false)
	var stack := _left_stack(510.0)
	_label(stack, "ENDLESS HIGHWAY  /  ARCADE", 16, MINT)
	_label(stack, "TRAFFIC\nDODGE 3D", 68, PAPER)
	_label(stack, "Three lanes. One more run.", 24, MUTED)
	_gap(stack, 16)
	var play := _button(stack, "Play", _start_intro, true)
	_button(stack, "Chapters", _show_chapters)
	_button(stack, "Garage", _open_garage)
	_button(stack, "Settings", _open_settings)
	_button(stack, "Quit", get_tree().quit)
	_gap(stack, 12)
	_label(stack, "BEST  %07d     /     COINS  %d" % [profile.data.best_score, profile.data.balance], 16, GOLD)
	play.grab_focus()
	_footer(DRIVE_CONTROLS)


func _show_chapters() -> void:
	_new_screen(State.CHAPTERS)
	var stack := _dialog("START FROM A SCENE", "Chapters")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	stack.add_child(grid)
	_button(grid, "Garage prologue", _start_intro, true).grab_focus()
	_button(grid, "Coastal highway", _start_run.bind(GameRules.Chapter.HIGHWAY))
	_button(grid, "Crystal Cavern", _start_run.bind(GameRules.Chapter.CAVERN))
	_button(grid, "Skyway", _start_run.bind(GameRules.Chapter.SKYWAY))
	_button(grid, "Castle raid", _start_run.bind(GameRules.Chapter.CASTLE))
	_button(grid, "Police pursuit", _start_run.bind(GameRules.Chapter.PURSUIT))
	_button(grid, "Edge of the Skyway", _start_run.bind(GameRules.Chapter.RESCUE))
	_button(grid, "Helicopter escape", _start_run.bind(GameRules.Chapter.HELICOPTER))
	_button(grid, "Skydive and city", _start_city)
	_button(grid, "Helicopter Wreck", _start_city.bind(CityStory.Start.WRECK))
	_button(grid, "Two Minutes to Impact", _start_city.bind(CityStory.Start.ESCAPE))
	_button(grid, "Vesper Flight", _start_space)
	_button(grid, "After Touchdown", _start_space.bind(true, true))
	for button: Button in grid.get_children():
		button.custom_minimum_size.x = 232
	_button(stack, "Back", _show_menu)


func _start_intro() -> void:
	_new_screen(State.INTRO)
	_add_letterbox()
	var title := _label(screen, "COASTAL MOTOR WORKS  /  PROLOGUE", 14, MINT)
	title.position = Vector2(26, 8)
	_add_skip_button()
	_build_subtitles()

	_intro = GarageIntro.new()
	game.add_child(_intro)
	_intro.subtitle_changed.connect(_show_intro_subtitle)
	_intro.engine_started.connect(audio.set_driving.bind(true))
	_intro.finished.connect(_finish_intro, CONNECT_ONE_SHOT)
	_intro.play(int(profile.data.selected), game.prepare_intro())


func _build_subtitles() -> void:
	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_panel.add_theme_stylebox_override("panel", _style(Color("#0d1822e8"), Color("#506979"), 8, 10))
	screen.add_child(_subtitle_panel)
	_subtitle_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle_panel.offset_left = 230
	_subtitle_panel.offset_right = -230
	_subtitle_panel.offset_top = -128
	_subtitle_panel.offset_bottom = -43
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	_subtitle_panel.add_child(lines)
	_subtitle_speaker = _label(lines, "", 14, MINT)
	_subtitle_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_text = _label(lines, "", 23, PAPER)
	_subtitle_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_panel.hide()

func _show_intro_subtitle(speaker: String, line: String) -> void:
	_subtitle_speaker.text = speaker
	_subtitle_text.text = line
	_subtitle_panel.visible = not line.is_empty()


func _finish_intro() -> void:
	if state != State.INTRO:
		return
	_intro.stop()
	_intro.queue_free()
	_intro = null
	_start_run()


func _start_run(chapter: GameRules.Chapter = GameRules.Chapter.HIGHWAY) -> void:
	_chapter = chapter
	current_score = 0
	current_distance = 0.0
	current_coins = 0
	run_saved = chapter != GameRules.Chapter.HIGHWAY
	_new_screen(State.PLAYING)
	_build_hud()
	audio.set_driving(true)
	game.call(&"start_run", int(profile.data.selected), chapter)


func _pause() -> void:
	game.set(&"playing", false)
	audio.set_driving(false)
	_new_screen(State.PAUSED)
	var stack := _dialog("RUN ON HOLD", "Paused")
	_label(stack, "%d points    ·    %d coins" % [current_score, current_coins], 22, MUTED)
	_gap(stack, 12)
	_button(stack, "Resume", _resume, true).grab_focus()
	_button(stack, "Restart", _restart)
	_button(stack, "Settings", _open_settings)
	_button(stack, "Main Menu", _show_menu)


func _resume() -> void:
	_new_screen(State.PLAYING)
	_build_hud()
	_update_stats(current_distance, current_score, current_coins, float(game.get(&"speed")))
	audio.set_driving(true)
	game.call(&"resume_run")


func _restart() -> void:
	_commit_run()
	_start_run(_chapter)


func _on_run_ended(distance: float, score: int, coins: int) -> void:
	if state != State.PLAYING:
		return
	_show_results(distance, score, coins)


func _start_city(start: CityStory.Start = CityStory.Start.DROP) -> void:
	_commit_run()
	_remove_city()
	game.prepare_city()
	audio.set_driving(false)
	_new_screen(State.CITY)
	_city = CityPhase.new()
	_city.start = start
	_city.died.connect(_show_city_death)
	_city.escaped.connect(_start_space, CONNECT_DEFERRED)
	_city.story.launched.connect(audio.set_driving.bind(false))
	_city.shot.connect(audio.play_shot_at)
	_city.horn.connect(audio.play_cue.bind("horn"))
	_city.shout.connect(audio.play_cue.bind("panic"))
	_city.siren.connect(audio.play_cue.bind("siren"))
	_city.traffic.engine_speed.connect(_update_city_engine)
	add_child(_city)


func _remove_city() -> void:
	if is_instance_valid(_city):
		_city.set_active(false)
		remove_child(_city)
		_city.queue_free()
		_city = null


func _pause_city() -> void:
	if _city.story.cinematic:
		return
	audio.set_driving(false)
	_city.set_active(false)
	_new_screen(State.CITY_PAUSED)
	var stack := _dialog("CITY DISTRICT", "Paused")
	_button(stack, "Resume", _resume_city, true).grab_focus()
	_add_city_restart(stack)
	_button(stack, "Main Menu", _show_menu)


func _resume_city() -> void:
	_new_screen(State.CITY)
	_city.set_active(true)


func _show_city_death(reason: String) -> void:
	audio.set_driving(false)
	audio.play_cue("crash")
	_new_screen(State.CITY_OVER)
	var stack := _dialog("CITY DISTRICT", "Game Over")
	_label(stack, reason, 22, MUTED)
	_add_city_restart(stack, true)
	_button(stack, "Main Menu", _show_menu)


func _add_city_restart(stack: VBoxContainer, primary: bool = false) -> void:
	var checkpoint := _city.start
	if _city.story.stage >= CityStory.Stage.ESCAPE:
		checkpoint = CityStory.Start.ESCAPE
	var labels: Array[String] = ["Restart drop", "Restart at wreck", "Restart escape"]
	var button := _button(stack, labels[checkpoint], _start_city.bind(checkpoint), primary)
	if primary:
		button.grab_focus()


func _start_space(landing_start: bool = false, landed_start: bool = false) -> void:
	_remove_city()
	_remove_space()
	game.prepare_city()
	audio.set_driving(false)
	_new_screen(State.SPACE)
	_space = SpaceFlight.new()
	_space.landing_start = landing_start
	_space.landed_start = landed_start
	audio.music.stream_paused = false
	_space.epilogue_started.connect(func() -> void: audio.music.stream_paused = true)
	_space.failed.connect(_show_space_failure)
	_space.landed.connect(_show_space_success)
	add_child(_space)


func _remove_space() -> void:
	if is_instance_valid(_space):
		_space.set_active(false)
		remove_child(_space)
		_space.queue_free()
		_space = null


func _pause_space() -> void:
	_space.set_active(false)
	_new_screen(State.SPACE_PAUSED)
	var stack := _dialog("VESPER TRANSFER", "Paused")
	_button(stack, "Resume", _resume_space, true).grab_focus()
	_button(stack, "Restart checkpoint", _start_space.bind(_space.retry_at_landing(), _space.landed_start))
	_button(stack, "Main Menu", _show_menu)


func _resume_space() -> void:
	_new_screen(State.SPACE)
	_space.set_active(true)


func _show_space_failure(reason: String) -> void:
	_new_screen(State.SPACE_OVER)
	audio.play_cue("crash")
	var stack := _dialog("VESPER TRANSFER", "Flight lost")
	_label(stack, reason, 21, MUTED)
	_button(stack, "Retry landing" if _space.retry_at_landing() else "Retry flight",
		_start_space.bind(_space.retry_at_landing(), _space.landed_start), true).grab_focus()
	_button(stack, "Main Menu", _show_menu)


func _show_space_success() -> void:
	_new_screen(State.SPACE_COMPLETE)
	var stack := _dialog("MISSION COMPLETE", "Vesper Outpost 07")
	_button(stack, "Replay ending", _start_space.bind(true, true), true).grab_focus()
	_button(stack, "Replay landing", _start_space.bind(true))
	_button(stack, "Main Menu", _show_menu)


func _update_city_engine(kmh: float) -> void:
	audio.set_driving(kmh >= 0.0)
	if kmh >= 0.0:
		audio.set_speed(kmh)


func _show_pursuit() -> void:
	_new_screen(State.PLAYING)
	_build_hud()
	var objective := _label(screen, "POLICE PURSUIT  /  WATCH FOR ONCOMING TRAFFIC", 18, GOLD)
	objective.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	objective.offset_top = 104
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fade := objective.create_tween()
	fade.tween_property(objective, "modulate:a", 0.0, 0.7).set_delay(4.0)
	fade.tween_callback(objective.queue_free)


func _show_finale() -> void:
	_new_screen(State.FINALE)
	_add_letterbox()
	_add_skip_button()


func _show_rescue() -> void:
	audio.set_driving(false)
	_show_finale()
	_build_subtitles()


func _add_letterbox() -> void:
	for anchor in [0.0, 1.0]:
		var bar := ColorRect.new()
		bar.color = INK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(bar)
		bar.anchor_top = anchor
		bar.anchor_bottom = anchor
		bar.anchor_right = 1.0
		bar.offset_top = -36.0 * anchor
		bar.offset_bottom = 36.0 * (1.0 - anchor)


func _on_finale_cue(cue: String) -> void:
	match cue:
		"parked":
			audio.set_driving(false)
		"shot":
			audio.play_cue("shot")
		"depart":
			audio.set_speed(140.0)
			audio.set_driving(true)


func _show_results(distance: float, score: int, coins: int) -> void:
	var new_record := not run_saved and score > int(profile.data.best_score)
	_update_stats(distance, score, coins, 0.0)
	_commit_run()
	audio.set_driving(false)
	_new_screen(State.GAME_OVER)
	var eyebrow := "NEW HIGH SCORE" if new_record else "RUN COMPLETE"
	var stack := _dialog(eyebrow, "Game Over")
	_label(stack, "%07d" % score, 48, GOLD)
	_label(stack, "%s traveled    ·    %d coins" % [_distance_text(distance), coins], 21, MUTED)
	_label(stack, "Best score  %07d" % profile.data.best_score, 20, MUTED)
	_gap(stack, 14)
	_button(stack, "Restart", _restart, true).grab_focus()
	_button(stack, "Main Menu", _show_menu)
	audio.play_cue("crash")
	_crash_flash()


func _crash_flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color("#ff694c66")
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.28)
	tween.tween_callback(flash.queue_free)


func _commit_run() -> void:
	if run_saved:
		return
	run_saved = true
	profile.data.best_score = maxi(int(profile.data.best_score), current_score)
	profile.data.best_distance = maxi(int(profile.data.best_distance), int(current_distance))
	profile.data.balance = int(profile.data.balance) + current_coins
	profile.save_data()


func _build_hud() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_top = 24
	top.offset_right = -28
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	screen.add_child(top)
	for title in ["SCORE", "DISTANCE", "SPEED", "COINS"]:
		var card := PanelContainer.new()
		card.custom_minimum_size.x = 132
		card.add_theme_stylebox_override("panel", _style(Color("#0d1822e8"), Color("#354d58"), 12, 12))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(card)
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_theme_constant_override("separation", 2)
		card.add_child(stack)
		_label(stack, title, 13, MUTED)
		hud_values.append(_label(stack, "0", 26, GOLD if title == "COINS" else PAPER))
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var pause_button := _button(top, "Pause", _pause)
	pause_button.custom_minimum_size.x = 120
	pause_button.focus_mode = Control.FOCUS_NONE
	_footer(DRIVE_CONTROLS)
	_nitro_label = _label(screen, "", 19, MINT)
	_nitro_label.position = Vector2(28, 98)
	_update_nitro_hud()


func _update_nitro_hud() -> void:
	_nitro_label.visible = game.nitro_duration() > 0.0
	if game.nitro_left > 0.0:
		_nitro_label.text = "NITRO  %.1fs" % game.nitro_left
	elif game.nitro_cooldown > 0.0:
		_nitro_label.text = "NITRO RECHARGING  %.0fs" % ceilf(game.nitro_cooldown)
	else:
		_nitro_label.text = "R  ·  NITRO READY"


func _update_stats(distance: float, score: int, coins: int, speed: float) -> void:
	if coins > current_coins and state == State.PLAYING:
		audio.play_cue("coin")
	current_distance = distance
	current_score = score
	current_coins = coins
	audio.set_speed(speed * 3.6)
	if hud_values.size() == 4:
		hud_values[0].text = "%07d" % score
		hud_values[1].text = _distance_text(distance)
		hud_values[2].text = "%d km/h" % roundi(speed * 3.6)
		hud_values[3].text = str(coins)


func _distance_text(distance: float) -> String:
	if distance < 1000.0:
		return "%d m" % int(distance)
	return "%.2f km" % (distance / 1000.0)


func _open_garage() -> void:
	garage_index = int(profile.data.selected)
	_show_garage()


func _show_garage() -> void:
	_new_screen(State.GARAGE)
	var stack := _dialog("WORKSHOP  /  %d COINS" % profile.data.balance, "Garage")
	var options := HBoxContainer.new()
	stack.add_child(options)
	for index in PAINT.size():
		var pick := _button(options, "%02d" % (index + 1), _preview_car.bind(index), index == garage_index)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.add_theme_color_override("font_color", INK if index == garage_index else PAINT[index])
	_garage_preview(stack)
	_label(stack, Catalog.NAMES[garage_index], 28, PAINT[garage_index])
	var nitro := Catalog.NITRO_SECONDS[garage_index]
	var specs := "%s  ·  %d km/h" % [Catalog.CLASSES[garage_index], Catalog.SPEED_KMH[garage_index]]
	if nitro > 0:
		specs += "  ·  R Nitro %ds" % int(nitro)
	_label(stack, specs, 18, MUTED)
	var active := int(profile.data.selected) == garage_index
	var owned: bool = profile.data.unlocked[garage_index]
	var price: int = Catalog.PRICES[garage_index]
	if active:
		_label(stack, "Free starter car  ·  Selected" if price == 0 else "Selected for your next run", 20, MUTED)
	elif owned:
		_button(stack, "Select vehicle", _select_car, true)
	else:
		var purchase := _button(stack, "Unlock  /  %d coins" % price, _select_car, true)
		purchase.disabled = int(profile.data.balance) < price
		if purchase.disabled:
			_label(stack, "Collect %d more coins" % (price - int(profile.data.balance)), 19, MUTED)
	_button(stack, "Back", _show_menu)
	options.get_child(garage_index).grab_focus()


func _garage_preview(stack: VBoxContainer) -> void:
	var frame := SubViewportContainer.new()
	frame.custom_minimum_size.y = 165.0
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(frame)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var lighting := Environment.new()
	lighting.background_mode = Environment.BG_COLOR
	lighting.background_color = Color("#203343")
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color = Color("#e2f7ff")
	lighting.ambient_light_energy = 0.85
	environment.environment = lighting
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43, -36, 0)
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(4.6, 2.45, -5.5)
	camera.fov = 36.0
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.72, 0))
	VehicleVisual.box(world, Vector3(5.8, 0.16, 5.8), Vector3.DOWN * 0.10, Color("#172531"))
	var model := VehicleVisual.create_player(world, garage_index)
	if DisplayServer.get_name() != "headless":
		var spin := frame.create_tween().set_loops()
		spin.tween_property(model, "rotation:y", TAU, 16.0).from(0.0)


func _preview_car(index: int) -> void:
	garage_index = index
	_show_garage()


func _select_car() -> void:
	if not profile.data.unlocked[garage_index]:
		var price: int = Catalog.PRICES[garage_index]
		if int(profile.data.balance) < price:
			return
		profile.data.balance = int(profile.data.balance) - price
		profile.data.unlocked[garage_index] = true
	profile.data.selected = garage_index
	profile.save_data()
	_show_garage()


func _open_settings() -> void:
	settings_return = state
	_new_screen(State.SETTINGS)
	var stack := _dialog("PREFERENCES", "Settings")
	for setting in ["master", "music", "effects"]:
		var row := HBoxContainer.new()
		stack.add_child(row)
		var name_label := _label(row, String(setting).capitalize() + " volume", 20, PAPER)
		name_label.custom_minimum_size.x = 170
		var slider := HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(profile.data[setting])
		slider.value_changed.connect(_change_volume.bind(setting))
		row.add_child(slider)
		var amount := _label(row, "%d%%" % roundi(slider.value * 100.0), 18, MUTED)
		amount.custom_minimum_size.x = 58
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slider.value_changed.connect(func(value: float) -> void: amount.text = "%d%%" % roundi(value * 100.0))
	var shadows := CheckButton.new()
	shadows.text = "Cast shadows"
	shadows.button_pressed = bool(profile.data.shadows)
	shadows.toggled.connect(_change_shadows)
	stack.add_child(shadows)
	_gap(stack, 12)
	_button(stack, "Back", _close_settings).grab_focus()


func _change_volume(value: float, setting: String) -> void:
	profile.data[setting] = value
	audio.apply(profile.data)


func _change_shadows(enabled: bool) -> void:
	profile.data.shadows = enabled
	_apply_shadows()


func _apply_shadows() -> void:
	for light_node in game.find_children("*", "DirectionalLight3D", true, false):
		var light := light_node as DirectionalLight3D
		light.shadow_enabled = bool(profile.data.shadows)


func _close_settings() -> void:
	profile.save_data()
	if settings_return == State.PAUSED:
		_pause()
	else:
		_show_menu()


func _new_screen(next: State) -> void:
	state = next
	hud_values.clear()
	_nitro_label = null
	if is_instance_valid(screen):
		screen.hide()
		screen.queue_free()
	screen = Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skip_button = null
	if next in [State.CITY, State.SPACE]:
		_add_skip_button()


func _shade(centered: bool) -> void:
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	if centered:
		gradient.colors = PackedColorArray([Color("#0a151ec9"), Color("#12222aa6")])
	else:
		gradient.colors = PackedColorArray([Color("#0a151ef7"), Color("#0a151eac"), Color("#0a151e18")])
		gradient.offsets = PackedFloat32Array([0.0, 0.43, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 1
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _left_stack(width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	center.offset_left = 64.0
	center.offset_right = 64.0 + width
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.custom_minimum_size.x = width
	center.add_child(stack)
	return stack

func _dialog(eyebrow: String, title: String) -> VBoxContainer:
	_shade(true)
	var center := CenterContainer.new()
	screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 480.0
	panel.add_theme_stylebox_override("panel", _style(Color("#0d1822fa"), Color("#365461"), 22, 32))
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	_label(stack, eyebrow, 15, MINT)
	_label(stack, title, 48, PAPER)
	return stack


func _footer(content: String) -> void:
	var line := Label.new()
	line.text = content
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 15)
	line.add_theme_color_override("font_color", PAPER)
	line.add_theme_color_override("font_shadow_color", INK)
	line.add_theme_constant_override("shadow_offset_y", 2)
	screen.add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -44
	line.offset_bottom = -14


func _label(parent: Control, content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _gap(parent: Control, height: float) -> void:
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size.y = height
	parent.add_child(gap)


func _button(parent: Control, content: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = content
	button.custom_minimum_size.y = 45.0
	if primary:
		button.add_theme_stylebox_override("normal", _style(MINT, MINT, 10, 10))
		button.add_theme_stylebox_override("hover", _style(Color("#a0fbe2"), MINT, 10, 10))
		button.add_theme_stylebox_override("pressed", _style(Color("#52c8a5"), MINT, 10, 10))
		for slot in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(slot, INK)
	button.pressed.connect(func() -> void:
		audio.play_cue("click")
		action.call()
	)
	parent.add_child(button)
	return button


func _make_theme() -> Theme:
	ui_theme = Theme.new()
	ui_theme.default_font_size = 20
	ui_theme.set_stylebox("normal", "Button", _style(Color("#172a36"), Color("#3c5665"), 10, 10))
	ui_theme.set_stylebox("hover", "Button", _style(Color("#243d4d"), Color("#658d9f"), 10, 10))
	ui_theme.set_stylebox("pressed", "Button", _style(Color("#11202b"), MINT, 10, 10))
	ui_theme.set_stylebox("disabled", "Button", _style(Color("#101c24"), Color("#243640"), 10, 10))
	ui_theme.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, GOLD, 10, 0))
	return ui_theme


func _style(fill: Color, outline: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = outline
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box
