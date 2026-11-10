extends Node

const GAME: PackedScene = preload("res://scenes/game.tscn")
const VehicleVisual = preload("res://scripts/vehicle_visual.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const AudioManager = preload("res://scripts/audio_manager.gd")
const GarageIntro = preload("res://scripts/garage_intro.gd")
const INK: Color = Color("#0d1822")
const PAPER: Color = Color("#f1f7f8")
const MUTED: Color = Color("#a6bac6")
const MINT: Color = Color("#70f5ce")
const GOLD: Color = Color("#ffd288")
const PAINT = VehicleVisual.PLAYER_PAINTS
const DRIVE_CONTROLS: String = "A / D  or  ← / →   STEER    ·    W / ↑   GAS    ·    S / ↓   BRAKE    ·    SPACE   DRIFT    ·    ESC   PAUSE"

enum State { MENU, PLAYING, PAUSED, GAME_OVER, GARAGE, SETTINGS, INTRO, FINALE, COMPLETE }

var state: State = State.MENU
var settings_return: State = State.MENU
var profile := SaveManager.new()
var audio := AudioManager.new()
var game: Node3D
var overlay: Control
var screen: Control
var hud_values: Array[Label] = []
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
	game.connect(&"run_completed", _on_run_completed)
	_apply_shadows()
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.theme = _make_theme()
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show_menu()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel") or event.is_echo():
		return
	match state:
		State.INTRO:
			_finish_intro()
		State.PLAYING:
			_pause()
		State.PAUSED:
			_resume()
		State.GARAGE, State.GAME_OVER, State.COMPLETE:
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
	_commit_run()
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
	_button(stack, "Garage", _open_garage)
	_button(stack, "Settings", _open_settings)
	_button(stack, "Quit", get_tree().quit)
	_gap(stack, 12)
	_label(stack, "BEST  %07d     /     COINS  %d" % [profile.data.best_score, profile.data.balance], 16, GOLD)
	play.grab_focus()
	_footer(DRIVE_CONTROLS)


func _start_intro() -> void:
	_new_screen(State.INTRO)
	_add_letterbox()
	var title := _label(screen, "COASTAL MOTOR WORKS  /  PROLOGUE", 14, MINT)
	title.position = Vector2(26, 8)
	var hint := _label(screen, "ESC  SKIP", 14, MUTED)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_left = 26
	hint.offset_right = -26
	hint.offset_top = 8
	hint.offset_bottom = 30
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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

	_intro = GarageIntro.new()
	game.add_child(_intro)
	_intro.subtitle_changed.connect(_show_intro_subtitle)
	_intro.engine_started.connect(audio.set_driving.bind(true))
	_intro.finished.connect(_finish_intro, CONNECT_ONE_SHOT)
	_intro.play(int(profile.data.selected), game.prepare_intro())


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


func _start_run() -> void:
	current_score = 0
	current_distance = 0.0
	current_coins = 0
	run_saved = false
	_new_screen(State.PLAYING)
	_build_hud()
	game.call(&"start_run", int(profile.data.selected))
	audio.set_driving(true)


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
	_start_run()


func _on_run_ended(distance: float, score: int, coins: int) -> void:
	if state != State.PLAYING:
		return
	_show_results(distance, score, coins, false)


func _on_run_completed(distance: float, score: int, coins: int) -> void:
	if state == State.FINALE:
		_show_results(distance, score, coins, true)


func _show_finale() -> void:
	_new_screen(State.FINALE)
	_add_letterbox()


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


func _show_results(distance: float, score: int, coins: int, completed: bool) -> void:
	var new_record := score > int(profile.data.best_score)
	_update_stats(distance, score, coins, 0.0)
	_commit_run()
	audio.set_driving(false)
	_new_screen(State.COMPLETE if completed else State.GAME_OVER)
	var eyebrow := "NEW HIGH SCORE" if new_record else "RUN COMPLETE"
	var stack := _dialog(eyebrow, "Skyway Complete" if completed else "Game Over")
	_label(stack, "%07d" % score, 48, GOLD)
	_label(stack, "%s traveled    ·    %d coins" % [_distance_text(distance), coins], 21, MUTED)
	_label(stack, "Best score  %07d" % profile.data.best_score, 20, MUTED)
	_gap(stack, 14)
	_button(stack, "Restart", _start_run, true).grab_focus()
	_button(stack, "Main Menu", _show_menu)
	if not completed:
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
	_label(stack, SaveManager.CAR_NAMES[garage_index], 28, PAINT[garage_index])
	var active := int(profile.data.selected) == garage_index
	var owned: bool = profile.data.unlocked[garage_index]
	var price: int = SaveManager.PRICES[garage_index]
	if active:
		_label(stack, "Selected for your next run", 20, MUTED)
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
	camera.position = Vector3(4, 2.5, 4.3)
	camera.fov = 36.0
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.72, 0))
	VehicleVisual.create(world, 0, PAINT[garage_index], garage_index)


func _preview_car(index: int) -> void:
	garage_index = index
	_show_garage()


func _select_car() -> void:
	if not profile.data.unlocked[garage_index]:
		var price: int = SaveManager.PRICES[garage_index]
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
	if is_instance_valid(screen):
		screen.hide()
		screen.queue_free()
	screen = Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


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
