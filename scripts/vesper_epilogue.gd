extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const Actor = preload("res://scripts/finale_actor.gd")
const SupplyRun = preload("res://scripts/vesper_supply_run.gd")
const World = preload("res://scripts/vesper_world.gd")
const NAMES := ["Erik", "Princess", "Danyil", "Pilot"]
const COLORS := [Color("#306c77"), Color("#c464ae"), Color("#bd773b"), Color("#84909c")]
const RACK := Vector3(2.1, 0, -2.7)
const HATCH := Vector3(0, 0, -5.2)
const DURATIONS := [5.0, 22.0, 24.0, 5.0, 5.0, 5.0, 6.0, 15.0, 55.0]
const WALK_ORDER: Array[int] = [0, 3, 1, 2]
const CRACK := 0.16
const CHOICE_TIME := 0.27
const AIRLOCK := Vector3(28, 0, -22.2)
const TRANSFER := 0.81
const RAMP_TOP := Vector3(0, 2.15, 1.05)
const RAMP_FOOT := Vector3(0, 0, 5.45)
const RAMP_THICKNESS := 0.14
const BOOT_CLEARANCE := 0.025
const CREDITS := """TRAFFIC DODGE 3D

MAIN CAST
Erik
The Princess
Danyil · Erik's friend

SUPPORTING CAST
The Pilot
Ridge City Police
Palace Guards
Erik's Family

Created by Codex
Written by Danyil
Tested by Erik
Second Tester · Antti

Thank you for playing."""

signal finished

var _world: World
var _cabin := Node3D.new()
var _surface := Node3D.new()
var _memory: Node3D
var _cosmos := Node3D.new()
var _camera := Camera3D.new()
var _actors: Array[Actor] = []
var _helmets: Array[Node3D] = []
var _gear: Array[Node3D] = []
var _crew_start: Array[Vector3] = []
var _rack_display: Node3D
var _doors: Array[Node3D] = []
var _shards: Array[MeshInstance3D] = []
var _space_objects: Array[Node3D] = []
var _layer := CanvasLayer.new()
var _caption := Label.new()
var _objective := Label.new()
var _black := ColorRect.new()
var _credits := Label.new()
var _walker := Vector3(0, 0, 3.8)
var _yaw := 0.0
var _pitch := 0.0
var _suited := false
var _suiting := -1.0
var _beat := -1
var _elapsed := 0.0
enum RescueChoice { UNDECIDED, SACRIFICE, RUN }
var _rescue_choice := RescueChoice.UNDECIDED
var _choice_panel: PanelContainer
var _risk_succeeded := false
var _supply_run: SupplyRun
var _supply_stage := 0
var _departure_ship: Node3D
var _outpost_medic: Actor
var _antidote: MeshInstance3D
var _airlock: Node3D
var _airlock_door: MeshInstance3D
var _capsule_lid: MeshInstance3D
const CAPSULE := Vector3(0.75, 1.14, -9.4)
var _done := false
var _erik_eyes: MeshInstance3D
var _erik_smile: MeshInstance3D
var _score: AudioStreamPlayer


func begin(world: World, environment: Environment) -> void:
	_world = world
	_world.hide()
	for set in [_cabin, _surface, _cosmos]:
		add_child(set)
	_surface.position = world.ship.position
	_cosmos.hide()
	_camera.environment = environment.duplicate() as Environment
	_camera.far = 9000.0
	add_child(_camera)
	_camera.make_current()
	_build_cabin()
	_build_overlay()
	_update_first_person()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func can_skip() -> bool:
	return _beat >= 0 and not _done and not _choice_pending() and not is_instance_valid(_supply_run)


func skip() -> void:
	if not can_skip():
		return
	if _beat == 2 and _rescue_choice == RescueChoice.UNDECIDED:
		_elapsed = DURATIONS[2] * CHOICE_TIME
		_render_beat(CHOICE_TIME)
		_show_rescue_choice()
	else:
		_advance()


func set_active(active: bool) -> void:
	_layer.visible = active and not _done
	if is_instance_valid(_score):
		_score.stream_paused = not active
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if active and _beat < 0 else Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	if _beat < 0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if _beat >= 0:
		return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * 0.0024
		_pitch = clampf(_pitch - event.relative.y * 0.0024, -1.2, 1.2)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if not _suited and _suiting < 0 and _walker.distance_to(RACK) < 1.8:
			_suiting = 0.0
			_gear[0].show()
			_rack_display.hide()
		elif _suited and _walker.distance_to(HATCH) < 1.65:
			_advance()


func _process(delta: float) -> void:
	if _done:
		return
	if _beat < 0:
		_walk_cabin(delta)
		return
	if _choice_pending() or is_instance_valid(_supply_run):
		return
	_elapsed += delta
	if _beat == 2 and _rescue_choice == RescueChoice.UNDECIDED and _elapsed >= DURATIONS[2] * CHOICE_TIME:
		_elapsed = DURATIONS[2] * CHOICE_TIME
		_render_beat(CHOICE_TIME)
		_show_rescue_choice()
		return
	_render_beat(clampf(_elapsed / _beat_duration(), 0.0, 1.0))
	if _elapsed >= _beat_duration():
		_advance()


func _walk_cabin(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "accelerate", "brake")
	_walker += Vector3(input.x, 0, input.y).rotated(Vector3.UP, _yaw) * delta * 3.2
	_walker.x = clampf(_walker.x, -2.55, 2.55)
	_walker.z = clampf(_walker.z, -5.45, 4.6)
	_update_first_person()
	if _suiting >= 0.0 and not _suited:
		_suiting += delta
		for index in range(1, _actors.size()):
			var progress := clampf((_suiting - (index - 1) * 0.65) / 1.4, 0.0, 1.0)
			_actors[index].walk(progress, _crew_start[index], RACK + Vector3(-1.2 - index * 0.95, 0, 0.3))
			if progress >= 1.0:
				_gear[index].show()
		if _suiting >= 2.85:
			_suited = true
			_caption.text = "Pilot  /  Four seals confirmed. You're clear to open the hatch."
	if _suited:
		_objective.text = "E  ·  OPEN HATCH" if _walker.distance_to(HATCH) < 1.65 else "Walk to the forward hatch   ·   WASD / Mouse"
	elif _suiting >= 0.0:
		_objective.text = "Crew is sealing their suits"
	else:
		_objective.text = "E  ·  PUT ON SPACESUIT" if _walker.distance_to(RACK) < 1.8 else "Walk to the lit suit rack   ·   WASD / Mouse"


func _update_first_person() -> void:
	_camera.position = _walker + Vector3.UP * 1.68
	_camera.rotation = Vector3(_pitch, _yaw, 0)


func _build_cabin() -> void:
	var steel := Color("#344459")
	var trim := Color("#8ea4b2")
	Shapes.box(_cabin, Vector3(6, 0.22, 12), Vector3(0, -0.11, -0.6), steel)
	Shapes.box(_cabin, Vector3(6, 0.22, 12), Vector3(0, 3.15, -0.6), steel)
	for side in [-1, 1]:
		Shapes.box(_cabin, Vector3(0.22, 3.2, 12), Vector3(side * 3, 1.55, -0.6), steel)
		for z in [-4.8, -2.4, 0.0, 2.4, 4.8]:
			Shapes.box(_cabin, Vector3(0.18, 3.1, 0.14), Vector3(side * 2.86, 1.52, z), trim)
			Shapes.box(_cabin, Vector3(0.12, 0.08, 1.55), Vector3(side * 2.77, 2.67, z), Color("#8af0ea")).material_override = _emissive(Color("#8af0ea"))
	Shapes.box(_cabin, Vector3(6, 3.2, 0.22), Vector3(0, 1.55, 5.35), steel)
	for x in [-2.05, 2.05]:
		Shapes.box(_cabin, Vector3(1.9, 3.1, 0.24), Vector3(x, 1.5, -5.9), steel)
		_doors.append(Shapes.box(_cabin, Vector3(1.12, 2.65, 0.19), Vector3(signf(x) * 0.56, 1.325, -5.9), trim))
	Shapes.box(_cabin, Vector3(0.95, 2.55, 1.95), RACK + Vector3(0.33, 1.27, 0), Color("#284854"))
	Shapes.box(_cabin, Vector3(0.72, 0.08, 2.3), RACK + Vector3(0.18, 2.61, 0), Color("#71e6cc")).material_override = _emissive(Color("#71e6cc"))
	_light(_cabin, Vector3(0, 2.68, -2.5), Color("#b9e8f5"), 2.8, 9.0)
	_light(_cabin, Vector3(0, 2.7, 3), Color("#ffd8b2"), 2.1, 7.0)
	for index in NAMES.size():
		var actor := _actor(_cabin, index, Vector3(-1.6 + index * 0.68, 0, 0.5 - index * 0.42))
		actor.face(RACK)
		_actors.append(actor)
		_crew_start.append(actor.position)
		var gear := Node3D.new()
		actor.add_child(gear)
		_gear.append(gear)
		_build_suit(gear, COLORS[index])
		gear.hide()
	_actors[0].hide()
	_rack_display = Node3D.new()
	_cabin.add_child(_rack_display)
	_rack_display.position = RACK + Vector3(0, 0, 0.35)
	_build_suit(_rack_display, COLORS[0])


func _build_suit(gear: Node3D, accent: Color) -> void:
	Shapes.box(gear, Vector3(0.73, 0.76, 0.48), Vector3(0, 1.25, 0), Color("#d5ddd9"))
	Shapes.box(gear, Vector3(0.56, 0.74, 0.29), Vector3(0, 1.24, 0.34), Color("#657686"))
	Shapes.box(gear, Vector3(0.54, 0.1, 0.03), Vector3(0, 1.42, -0.25), accent)
	var helmet := Node3D.new()
	gear.add_child(helmet)
	helmet.position.y = 1.87
	var shell := TorusMesh.new()
	shell.inner_radius = 0.29
	shell.outer_radius = 0.37
	Shapes.attach(helmet, shell, Vector3.DOWN * 0.25, Color("#e2e6df"))
	var visor := _sphere(helmet, Vector3.ZERO, 0.38, Color.WHITE)
	visor.scale.y = 1.13
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.55, 0.83, 0.9, 0.23)
	glass.metallic = 0.46
	glass.roughness = 0.12
	visor.material_override = glass
	if gear != _rack_display:
		_helmets.append(helmet)


func _build_overlay() -> void:
	add_child(_layer)
	_layer.layer = 3
	_black.color = Color.BLACK
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.modulate.a = 0.0
	_label(_objective, 20)
	_objective.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_objective.position.y -= 115
	_label(_caption, 25)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.position.y -= 62
	_caption.text = "Pilot  /  Pressure outside is near zero. Suits first."
	_label(_credits, 19)
	_credits.text = CREDITS
	_credits.hide()


func _label(label: Label, font_size: int) -> void:
	_layer.add_child(label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color("#070c15"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _advance() -> void:
	if _rescue_choice == RescueChoice.RUN and _beat == 3:
		if _supply_stage < 3:
			_advance_supply()
			return
		_beat = 8
	else:
		_beat += 1
	_elapsed = 0.0
	_caption.text = ""
	_black.modulate.a = 0.0
	if _beat >= DURATIONS.size():
		_done = true
		_layer.hide()
		_credits.hide()
		if is_instance_valid(_score):
			_score.stop()
		finished.emit()
		return
	match _beat:
		0:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_objective.hide()
			_start_music()
		1:
			_enter_surface()
		2:
			for actor in _actors:
				actor.show()
			_helmets[1].show()
			_shatter_visor()
		3, 4, 5, 6:
			if _rescue_choice == RescueChoice.RUN:
				_build_airlock()
			else:
				_build_memory(_beat - 3)
		7:
			_memory.hide()
			_world.show()
			_surface.show()
			_set_sacrifice_pose()
		8:
			if is_instance_valid(_airlock):
				_airlock.hide()
			_build_cosmos()
			_credits.show()
	_render_beat(0.0)


func _render_beat(t: float) -> void:
	var eased := smoothstep(0.0, 1.0, t)
	match _beat:
		0:
			for index in _doors.size():
				_doors[index].position.x = (-1.0 if index == 0 else 1.0) * (0.56 + eased * 1.15)
			_shot(Vector3(0, 1.68, -3.9 - eased * 1.3), Vector3(0, 1.45, -8))
			_caption.text = "Danyil  /  Whatever's out there, we go together."
		1:
			_render_departure(t)
		2:
			_render_rescue(t * 0.65 if _rescue_choice == RescueChoice.RUN else t)
		3, 4, 5, 6:
			if _rescue_choice == RescueChoice.RUN:
				if _supply_stage == 0:
					_render_airlock_run(t)
				else:
					_render_supply_scene(t)
			else:
				_render_memory(t)
		7:
			var fall := smoothstep(0.10, 0.62, t)
			_actors[0].rotation = Vector3(0, 0, fall * 1.50)
			var site := _crew_ground(1)
			_actors[0].position = _grounded(site + Vector3(-0.90 - fall * 0.6, 0, 0.40)) + Vector3.UP * (fall * 0.25)
			for index in [1, 2]:
				var actor := _actors[index]
				actor.rotation.x = 0.30 + sin(t * 60.0 + index) * 0.038
				actor.position = _grounded(actor.position)
				actor.right_arm.rotation.x = -1.05
			var rise := smoothstep(0.45, 1.0, t)
			var eye := Vector3(-2.9, 1.75, 3.2).lerp(Vector3(0, 185.0, 42.0), rise)
			_shot(_surface.position + site + eye, _surface.position + site + Vector3.UP * 0.65)
			_caption.text = "Danyil  /  Erik? Come on, look at me." if t < 0.55 else "Princess  /  [Sobbing] Stay with us."
			if t > 0.81:
				_caption.text = ""
			_black.modulate.a = maxf(1.0 - smoothstep(0, 0.12, t), smoothstep(0.89, 1.0, t))
		8:
			_render_cosmos(t)

			var viewport_size := get_viewport().get_visible_rect().size
			_credits.size.x = viewport_size.x
			_credits.position = Vector2(0, lerpf(viewport_size.y * 0.83, -_credits.size.y, t))
			_credits.modulate.a = minf(smoothstep(0, 0.06, t), 1.0 - smoothstep(0.94, 1.0, t))
			if is_instance_valid(_score):
				_score.volume_db = lerpf(-10.0, -42.0, smoothstep(0.86, 1.0, t))


func _render_departure(t: float) -> void:
	for index in _actors.size():
		var delay := WALK_ORDER[index] * 0.055
		var progress := clampf((t - delay) / (0.72 if index == 1 else 0.79), 0.0, 1.0)
		var at := _exit_path(index, progress)
		var next := _exit_path(index, minf(progress + 0.02, 1.0))
		var actor := _actors[index]
		actor.visible = t >= delay
		actor.position = at
		if at.distance_squared_to(next) > 0.0001:
			actor.face(next)
		actor.stride(progress * (21.0 if index == 1 else 39.0), false)
		if progress >= 1.0:
			actor.stride(0.0, false)
	var focus := _actors[0].position.lerp(_actors[1].position, smoothstep(0.50, 0.92, t) * 0.7)
	var wide := smoothstep(0.20, 0.75, t)
	var offset := Vector3(7.2, 3.2, 7.5).lerp(Vector3(15.0, 6.5, 5.0), wide)
	_shot(_surface.position + focus + offset, _surface.position + focus + Vector3.UP * 1.3)
	if t < 0.25:
		_caption.text = "Pilot  /  One at a time. Watch the ramp."
	elif t > 0.45 and t < 0.66:
		_caption.text = "Danyil  /  The outpost lights are just past the pad."
	elif t > 0.78:
		_caption.text = "Princess  /  Wait… something's wrong with my visor."
	else:
		_caption.text = ""


func _exit_path(index: int, progress: float) -> Vector3:
	var foot := _ramp_foot()
	var turn := Vector3(5.6, 0, 5.75)
	if progress < 0.16:
		return RAMP_TOP.lerp(foot, progress / 0.16) + Vector3.UP * BOOT_CLEARANCE
	if progress < 0.34:
		return _grounded(foot.lerp(turn, (progress - 0.16) / 0.18))
	return _grounded(turn.lerp(_crew_ground(index), (progress - 0.34) / 0.66))


func _ramp_foot() -> Vector3:
	var foot := _grounded(RAMP_FOOT)
	foot.y -= BOOT_CLEARANCE
	return foot


func _grounded(at: Vector3) -> Vector3:
	var world_at := _surface.position + at
	var distance := Vector2(world_at.x, world_at.z).length()
	var terrain := World.ground_height(world_at.x, world_at.z)
	var pad_bottom_radius := World.PAD_RADIUS + World.PAD_BEVEL
	var bevel := clampf((pad_bottom_radius - distance) / World.PAD_BEVEL, 0.0, 1.0)
	var height := maxf(terrain, World.PAD_Y * bevel) if distance < pad_bottom_radius else terrain
	at.y = height - _surface.position.y + BOOT_CLEARANCE
	return at

func _render_rescue(t: float) -> void:
	var princess := _actors[1]
	var erik := _actors[0]
	var breach := maxf(0.0, t - CRACK)
	if t >= CRACK and _helmets[1].visible:
		_helmets[1].hide()
		_play_breach()
	var distress := smoothstep(CRACK, 0.44, t)
	princess.position = _crew_ground(1)
	princess.rotation = Vector3(0.32 * distress, PI, 0)
	princess.speak_pose(distress * (0.48 + 0.22 * sin(t * 120.0)) * (1.0 - smoothstep(TRANSFER, 0.93, t)),
		-1.8 * distress * (1.0 - smoothstep(0.72, 0.87, t)))
	for index in _shards.size():
		var angle := TAU * index / _shards.size()
		var shard := _shards[index]
		shard.position = _crew_ground(1) + Vector3.UP * 1.87 + Vector3(cos(angle), sin(angle), 0.7) * breach * 32.0
		shard.rotation = Vector3(3.0, 5.0, 2.0) * (breach * 6.0 + index)
		shard.visible = t >= CRACK and breach < 0.10
	var run := smoothstep(0.30, 0.65, t)
	var rescue_position := _crew_ground(1) + Vector3(-0.90, 0, 0.40)
	erik.position = _grounded(_crew_ground(0).lerp(rescue_position, run))
	erik.face(_crew_ground(1))
	if t < 0.65:
		erik.stride(run * _crew_ground(0).distance_to(rescue_position), true)
		erik.rotation.x = sin(run * PI) * -0.19
		erik.position.y += absf(sin(run * 29.0)) * sin(run * PI) * 0.15
	else:
		erik.stride(0.0, false)
		erik.rotation.x = -smoothstep(0.65, 0.75, t) * 0.14
		erik.left_arm.rotation.x = -1.5 * smoothstep(0.73, TRANSFER, t)
		erik.right_arm.rotation.x = erik.left_arm.rotation.x
		erik.rotation.y = lerp_angle(erik.rotation.y, PI, smoothstep(0.86, 0.94, t))
	for index in [2, 3]:
		var actor := _actors[index]
		var support := smoothstep(0.35 + index * 0.04, 0.87, t)
		var end := _crew_ground(1) + Vector3(1.7 + (index - 2) * 1.5, 0, -0.5 - index)
		actor.position = _grounded(_crew_ground(index).lerp(end, support))
		actor.face(_crew_ground(1))
		actor.stride(support * _crew_ground(index).distance_to(end), true)
	if t >= TRANSFER and _gear[0].get_parent() == erik:
		_transfer_suit()
	var focus := princess.position
	var eye := focus + Vector3(4.0, 2.35, 4.8)
	if t >= 0.27 and t < 0.66:
		focus = erik.position.lerp(princess.position, 0.27)
		eye = focus + Vector3(7.4 - run * 2.6, 1.85, -3.4 + run * 6.8)
	elif t >= 0.66:
		eye = focus + Vector3(3.3, 1.9, 4.8).lerp(Vector3(-0.25, 1.5, 3.1), smoothstep(0.66, 1.0, t))
	_shot(_surface.position + eye, _surface.position + focus + Vector3.UP * 1.35)
	if t < CRACK:
		_caption.text = ""
	elif t < 0.29:
		_caption.text = "[The visor cracks. Air rushes out.]"
	elif t < 0.61:
		_caption.text = "Erik  /  Princess!"
	elif t < 0.75:
		_caption.text = "Pilot  /  The seal is gone. Hold her steady."
	elif t < 0.88:
		_caption.text = "Erik  /  Take mine. Come on. Breathe."
	else:
		_caption.text = "Princess  /  Erik…"
		_erik_eyes.visible = t >= 0.94
		_black.modulate.a = smoothstep(0.96, 1.0, t)


func _enter_surface() -> void:
	_cabin.hide()
	_world.show()
	for index in _actors.size():
		var actor := _actors[index]
		actor.reparent(_surface, false)
		actor.position = Vector3(0, 2.15, 0.85)
		actor.rotation = Vector3(0, PI, 0)
		actor.hide()
	var portal := _emissive(Color("#142c40"))
	Shapes.box(_surface, Vector3(1.36, 2.15, 0.11), Vector3(0, 3.17, 0.87), Color.WHITE).material_override = portal
	for side in [-1, 1]:
		Shapes.box(_surface, Vector3(0.44, 2.10, 0.09), Vector3(side * 0.77, 3.17, 1.16), Color("#758d9a"))
	var foot := _ramp_foot()
	var direction := foot - RAMP_TOP
	var angle := atan2(-direction.y, direction.z)
	var normal := Vector3.UP.rotated(Vector3.RIGHT, angle)
	var top_center := RAMP_TOP.lerp(foot, 0.5)
	var gangway := Shapes.box(_surface, Vector3(2.45, RAMP_THICKNESS, direction.length()),
		top_center - normal * RAMP_THICKNESS * 0.5, Color("#6e8292"))
	gangway.rotation.x = angle
	for side in [-1, 1]:
		var rail := Shapes.box(_surface, Vector3(0.075, 0.08, direction.length()),
			top_center + Vector3(side * 1.13, 0.56, 0), Color("#a7becd"))
		rail.rotation.x = angle
	for index in range(1, 9):
		var grip := Shapes.box(_surface, Vector3(2.14, 0.025, 0.075),
			RAMP_TOP.lerp(foot, index / 9.0) + normal * 0.0125, Color("#435767"))
		grip.rotation.x = angle
	for side in [-1, 1]:
		Shapes.box(_surface, Vector3(0.10, 2.35, 0.18), Vector3(side * 0.78, 3.17, 1.1), Color("#8eb3c5"))
	_light(_surface, Vector3(0, 3.1, 2.0), Color("#a9ddff"), 3.4, 10.0)
	_erik_eyes = Shapes.box(_actors[0], Vector3(0.28, 0.045, 0.025), Vector3(0, 1.865, -0.232), Actor.SKIN)
	_erik_smile = Shapes.box(_actors[0], Vector3(0.15, 0.025, 0.024), Vector3(0, 1.73, -0.233), Color("#623936"))
	for side in [-1, 1]:
		var corner := Shapes.box(_erik_smile, Vector3(0.038, 0.024, 0.022), Vector3(side * 0.07, 0.012, 0), Color("#623936"))
		corner.rotation.z = side * 0.55
	_erik_eyes.hide()
	_erik_smile.hide()


func _crew_ground(index: int) -> Vector3:
	return _grounded([Vector3(15, 0, -12.5), Vector3(9, 0, 0.8), Vector3(18, 0, -16.5), Vector3(21, 0, -18.8)][index])


func _shatter_visor() -> void:
	for index in 17:
		var fragment := PrismMesh.new()
		fragment.size = Vector3(0.05 + (index % 4) * 0.019, 0.09, 0.012)
		var shard := Shapes.attach(_surface, fragment, Vector3.ZERO, Color("#a2e8ee"))
		shard.material_override = _emissive(Color("#a2e8ee"))
		_shards.append(shard)


func _transfer_suit() -> void:
	_gear[1].hide()
	_gear[0].reparent(_actors[1], false)
	_gear[0].position = Vector3.ZERO
	_erik_smile.show()


func _set_sacrifice_pose() -> void:
	if _gear[0].get_parent() == _actors[0]:
		_transfer_suit()
	for shard in _shards:
		shard.hide()
	for index in _actors.size():
		_actors[index].position = _crew_ground(index)
		_actors[index].rotation = Vector3.ZERO
		if index != 0:
			_actors[index].position = _grounded(_crew_ground(1) + Vector3(0.35 + (index - 1) * 1.22, 0, -0.5 - (index - 1) * 1.1))
			_actors[index].face(_crew_ground(1) + Vector3.LEFT)
	_erik_eyes.show()
	_erik_smile.show()


func _shot(eye: Vector3, target: Vector3) -> void:
	_camera.position = eye
	_camera.look_at(target)


func _actor(parent: Node3D, index: int, at: Vector3) -> Actor:
	var actor := Actor.new()
	parent.add_child(actor)
	actor.position = at
	actor.build(Actor.Role.PRINCESS if index == 1 else Actor.Role.DRIVER, COLORS[index])
	return actor


func _light(parent: Node3D, at: Vector3, color: Color, energy: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	parent.add_child(lamp)
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach


func _sphere(parent: Node3D, at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 36
	mesh.rings = 18
	return Shapes.attach(parent, mesh, at, color)


func _emissive(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _build_memory(index: int) -> void:
	if is_instance_valid(_memory):
		_memory.hide()
		_memory.queue_free()
	_surface.hide()
	_world.hide()
	_memory = Node3D.new()
	add_child(_memory)
	_memory.position.y = 180.0
	var ground_colors := [Color("#566449"), Color("#736070"), Color("#80644e"), Color("#657278")]
	Shapes.box(_memory, Vector3(26, 0.3, 26), Vector3.DOWN * 0.16, ground_colors[index])
	_light(_memory, Vector3(-3, 5, 2), Color("#ffcf8c"), 4.4, 19.0)
	for x in [-9, -6, -4, 5, 7, 10]:
		if index in [0, 1]:
			Shapes.box(_memory, Vector3(0.42, 3.7, 0.45), Vector3(x, 1.85, -4.8), Color("#775248"))
			_sphere(_memory, Vector3(x, 4.0, -4.8), 1.65, Color("#9b7650"))
		else:
			Shapes.box(_memory, Vector3(3, 3.7, 0.4), Vector3(x, 1.85, -4.8), Color("#b38a68") if index == 2 else Color("#586574"))
	var erik := _actor(_memory, 0, Vector3(-0.85, 0, 0))
	var companion := _actor(_memory, [2, 1, 3, 2][index], Vector3(0.85, 0, 0))
	if index == 2:
		Shapes.box(_memory, Vector3(3.5, 0.14, 1.65), Vector3(0, 0.95, -0.95), Color("#74503a"))
		_actor(_memory, 3, Vector3(0, 0, -2.08)).rotation.y = PI
		for x in [-1.0, 0, 1.0]:
			_sphere(_memory, Vector3(x, 1.03, -0.9), 0.12, Color("#edc078"))
	if index == 3:
		for x in [-0.7, 0.8]:
			_actor(_memory, 3, Vector3(x, 0, -2.75)).rotation.y = PI
		for index_stone in 3:
			var stone := _sphere(_memory, Vector3.ZERO, 0.10 + index_stone * 0.015, Color("#aab3b2"))
			stone.name = "Stone%d" % index_stone
		erik.scale *= 0.76
		companion.scale *= 0.78
	erik.name = "Erik"
	companion.name = "Companion"
	erik.face(companion.position)
	companion.face(erik.position)


func _render_memory(t: float) -> void:
	var index := _beat - 3
	var erik := _memory.get_node("Erik") as Actor
	var companion := _memory.get_node("Companion") as Actor
	if index == 3:
		for index_stone in 3:
			var stone := _memory.get_node("Stone%d" % index_stone) as Node3D
			var delay := index_stone * 0.10
			var throw_progress := smoothstep(0.08 + delay, 0.46 + delay, t)
			stone.visible = t >= 0.08 + delay
			stone.position = Vector3(0.65 - index_stone * 0.55, 1.15, -2.6).lerp(
				Vector3(-0.66 - index_stone * 0.18, 0.1, 0.28 + index_stone * 0.17), throw_progress)
			stone.position.y += sin(throw_progress * PI) * 0.68
		erik.rotation.z = -smoothstep(0.28, 0.46, t) * 0.23
		companion.walk(smoothstep(0.40, 0.77, t), Vector3(0.85, 0, 0), Vector3(-0.63, 0, -0.85))
		companion.face(Vector3(0, 0, -2.6))
		companion.left_arm.rotation.x = -smoothstep(0.58, 0.75, t) * 1.65
	else:
		var wave := sin(t * TAU)
		if index == 0:
			erik.walk(t, Vector3(-1.7, 0, -1.8), Vector3(-0.75, 0, 1.0))
			companion.walk(t, Vector3(0.85, 0, -2.1), Vector3(1.2, 0, 0.6))
			erik.rotation.y = PI - 0.35
			companion.rotation.y = PI + 0.35
		else:
			erik.position.y = absf(wave) * 0.025
		erik.speak_pose(absf(wave) * 0.45, -0.65 - wave * 0.25)
		companion.speak_pose(absf(cos(t * TAU)) * 0.42, -0.7 + wave * 0.19)
	_shot(_memory.position + Vector3(2.5 - t * 3.4, 1.85, 5.0 - t * 1.2), _memory.position + Vector3(0, 1.25, -0.2))
	_caption.text = [
		"Danyil  /  Last one to the garage buys breakfast!",
		"Princess  /  When this is over, let's come back here. Just us.",
		"Erik's family  /  There'll always be a place for you at this table.",
		DANYIL_MEMORY if t > 0.57 else "[A stone strikes the pavement beside Erik.]",
	][index]
	_black.modulate.a = maxf(1.0 - smoothstep(0, 0.17, t), smoothstep(0.84, 1.0, t))


const DANYIL_MEMORY := "Danyil  /  Leave him alone. Erik, stand behind me."


func _build_cosmos() -> void:
	_world.hide()
	_surface.hide()
	_cosmos.show()
	_camera.environment.background_color = Color("#040716")
	_camera.environment.ambient_light_energy = 0.45
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var stars := MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	var point := SphereMesh.new()
	point.radial_segments = 5
	point.rings = 2
	point.material = _emissive(Color("#c4d8ff"))
	stars.mesh = point
	stars.instance_count = 920
	for index in stars.instance_count:
		var position := Vector3(rng.randf_range(-4100, 4100), rng.randf_range(-2900, 3100), rng.randf_range(-7000, -220))
		stars.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.8, 4.2)), position))
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = stars
	_cosmos.add_child(batch)
	var vesper := _new_space_object()
	var globe := _sphere(vesper, Vector3.ZERO, 180, Color.WHITE)
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://scripts/vesper_globe.gdshader")
	globe.material_override = shader
	globe.rotation.z = -0.24
	var saturn := _new_space_object()
	_banded_planet(saturn, 140.0, Color("#c29c72"), Color("#efddae"))
	for index in 8:
		var radius := 159.0 + index * 12.5
		_ring(saturn, radius, radius + 10.0, Color("#d8c5a6").lerp(Color("#776374"), index / 10.0), 0.2)
	saturn.rotation = Vector3(0.32, 0, 0.27)
	_banded_planet(_new_space_object(), 169.0, Color("#305388"), Color("#83b6c9"))
	_banded_planet(_new_space_object(), 138.0, Color("#92455a"), Color("#f1b887"))
	for hole_index in 2:
		var hole := _new_space_object()
		_sphere(hole, Vector3.ZERO, 115, Color.BLACK).material_override = _emissive(Color.BLACK)
		var outer := Color("#ad385a") if hole_index == 0 else Color("#6754c8")
		for index in 11:
			var radius := 119.0 + index * 13.0
			_ring(hole, radius, radius + 11.0, Color("#ffefc4").lerp(outer, index / 10.0), 0.05)
		hole.rotation = Vector3(0.31 + hole_index * 0.12, 0, -0.23 + hole_index * 0.5)


func _new_space_object() -> Node3D:
	var object := Node3D.new()
	_cosmos.add_child(object)
	var index := _space_objects.size()
	object.position = Vector3(sin(index * 1.7) * 440.0, index * 56.0, -index * 770.0)
	_space_objects.append(object)
	object.hide()
	return object


func _banded_planet(parent: Node3D, radius: float, dark: Color, light: Color) -> void:
	var planet := _sphere(parent, Vector3.ZERO, radius, Color.WHITE)
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/epilogue_planet.gdshader")
	material.set_shader_parameter("dark_band", dark)
	material.set_shader_parameter("light_band", light)
	planet.material_override = material


func _ring(parent: Node3D, inner: float, outer: float, color: Color, tilt: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = inner
	ring.outer_radius = outer
	ring.rings = 80
	ring.ring_segments = 12
	var mesh := Shapes.attach(parent, ring, Vector3.ZERO, color)
	mesh.scale.y = 0.14
	mesh.rotation.x = tilt
	mesh.material_override = _emissive(color)


func _render_cosmos(t: float) -> void:
	var sequence := t * _space_objects.size()
	var index := mini(int(sequence), _space_objects.size() - 1)
	var progress := sequence - index
	for object_index in _space_objects.size():
		_space_objects[object_index].visible = object_index == index
	var object := _space_objects[index]
	var offset := Vector3(95.0 - progress * 190.0, 38.0 + progress * 140.0, 610.0 - progress * 155.0)
	if index == 0:
		offset = Vector3(24, 45, 206).lerp(Vector3(-118, 185, 690), smoothstep(0, 1, progress))
	_shot(object.position + offset, object.position + Vector3(0, 18, 0))
	var fade_in := 1.0 - smoothstep(0.0, 0.14, progress)
	var fade_out := smoothstep(0.87, 1.0, progress)
	_black.modulate.a = maxf(fade_in, fade_out)

func _start_music() -> void:
	if DisplayServer.get_name() == "headless":
		return
	const RATE := 16000
	const SECONDS := 16
	var data := PackedByteArray()
	data.resize(RATE * SECONDS * 2)
	var chords := [[130.81, 155.56, 196.0], [103.83, 130.81, 155.56], [116.54, 146.83, 174.61], [98.0, 130.81, 146.83]]
	for sample in RATE * SECONDS:
		var time := float(sample) / RATE
		var beat_time := fmod(time, 4.0)
		var chord: Array = chords[mini(floori(time / 4.0), 3)]
		var envelope := smoothstep(0.0, 1.2, beat_time) * (1.0 - smoothstep(2.2, 4.0, beat_time))
		var value := 0.0
		for frequency: float in chord:
			value += sin(TAU * frequency * time) * 0.065 + sin(TAU * frequency * 0.5 * time) * 0.032
		data.encode_s16(sample * 2, int(value * envelope * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = RATE * SECONDS
	stream.data = data
	_score = AudioStreamPlayer.new()
	add_child(_score)
	_score.bus = &"Music"
	_score.volume_db = -10.0
	_score.stream = stream
	_score.play()


func _play_breach() -> void:
	if DisplayServer.get_name() == "headless":
		return
	const RATE := 16000
	var rng := RandomNumberGenerator.new()
	rng.seed = 503
	var data := PackedByteArray()
	data.resize(RATE * 2)
	var filtered := 0.0
	for sample in RATE:
		var time := float(sample) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.28)
		var crack := noise * exp(-time * 48.0) * 0.72
		var hiss := (noise - filtered) * smoothstep(0.015, 0.08, time) * (1.0 - time) * 0.23
		data.encode_s16(sample * 2, int((crack + hiss) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	var effect := AudioStreamPlayer.new()
	add_child(effect)
	effect.bus = &"Effects"
	effect.stream = stream
	effect.finished.connect(effect.queue_free)
	effect.play()


func _beat_duration() -> float:
	if _rescue_choice == RescueChoice.RUN:
		if _beat == 2:
			return DURATIONS[2] * 0.65
		if _beat == 3:
			return 30.0 if _supply_stage == 0 else (14.0 if _supply_stage == 1 else 8.0)
	return DURATIONS[_beat]


func _choice_pending() -> bool:
	return is_instance_valid(_choice_panel) and _choice_panel.visible


func _show_rescue_choice() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var erik := _actors[0]
	erik.face(_actors[1].position)
	var focus := _surface.position + erik.position + Vector3.UP * 1.65
	_shot(focus - erik.basis.z * 2.65 + erik.basis.x * 0.62, focus)
	_caption.text = ""
	_choice_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0c1927f5")
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_choice_panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(_choice_panel)
	_choice_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_choice_panel.offset_left = -270
	_choice_panel.offset_right = 270
	_choice_panel.offset_top = -182
	_choice_panel.offset_bottom = -26
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 8)
	_choice_panel.add_child(options)
	var title := Label.new()
	title.text = "THE PRINCESS IS LOSING AIR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options.add_child(title)
	for choice in [RescueChoice.SACRIFICE, RescueChoice.RUN]:
		var button := Button.new()
		button.custom_minimum_size.y = 46
		button.text = "Save the Princess · 100% — Give her your suit" if choice == RescueChoice.SACRIFICE else "Take the risk · 50/50 — Carry her to the station"
		button.pressed.connect(_choose_rescue.bind(choice))
		options.add_child(button)


func _choose_rescue(choice: RescueChoice) -> void:
	if not _choice_pending():
		return
	_rescue_choice = choice
	_risk_succeeded = choice == RescueChoice.RUN and randf() < 0.5
	_choice_panel.hide()


func _build_airlock() -> void:
	_render_rescue(0.65)
	_airlock = Node3D.new()
	add_child(_airlock)
	_airlock.position = AIRLOCK
	Shapes.box(_airlock, Vector3(4.2, 0.20, 4), Vector3(0, 0.1, 1.2), Color("#536879"))
	_airlock_door = Shapes.box(_airlock, Vector3(2.8, 2.82, 0.20), Vector3(0, 1.48, 3.22), Color("#273f53"))
	for side in [-1, 1]:
		Shapes.box(_airlock, Vector3(0.24, 3.2, 4), Vector3(side * 2, 1.6, 1.2), Color("#536879"))
	Shapes.box(_airlock, Vector3(4.2, 0.20, 4), Vector3(0, 3.17, 1.2), Color("#536879"))
	Shapes.box(_airlock, Vector3(2.65, 0.13, 0.24), Vector3(0, 2.94, 3.25), Color.WHITE).material_override = _emissive(Color("#76e6de"))
	_light(_airlock, Vector3(0, 2.8, 1), Color("#8adeee"), 4.0, 8.0)
	_build_medbay()


func _render_airlock_run(t: float) -> void:
	var erik := _actors[0]
	var princess := _actors[1]
	var pickup := smoothstep(0.0, 0.12, t)
	var run := smoothstep(0.10, 0.55, t)
	var start := _crew_ground(1) + Vector3(-0.9, 0, 0.4)
	var entrance := AIRLOCK - _surface.position + Vector3(0, 0, 1.5)
	var inside := smoothstep(0.55, 0.76, t)
	var bedside := AIRLOCK - _surface.position + Vector3(-0.92, 0, -8.45)
	var corridor := entrance.lerp(bedside, 0.38)
	var place := smoothstep(0.76, 0.88, t)
	var open := smoothstep(0.21, 0.35, t) * (1.0 - smoothstep(0.68, 0.75, t))
	_airlock_door.position.y = 1.48 + 2.9 * open
	var outside := _approach_airlock(start, entrance, run)
	erik.position = _airlock_floor(outside.lerp(bedside, inside))
	erik.rotation = Vector3.ZERO
	var heading := start.direction_to(entrance).lerp(Vector3.FORWARD, smoothstep(0.42, 0.57, t))
	erik.face(erik.position + heading)
	erik.rotation.y = lerp_angle(erik.rotation.y, -PI * 0.5, smoothstep(0.70, 0.76, t))
	erik.stride(run * start.distance_to(entrance) + inside * 10.0, t < 0.55)
	var carry_basis := erik.basis * Basis(Vector3.FORWARD, -PI * 0.5)
	var carry_center := erik.position + erik.basis * Vector3(0, 1.16, -0.51)
	var carry_origin := carry_center - carry_basis.y * 0.96
	var bed := AIRLOCK - _surface.position + CAPSULE
	var bed_basis := Basis(Vector3.RIGHT, PI * 0.5)
	var carried := _crew_ground(1).lerp(carry_origin, pickup)
	var over_bed := bed + Vector3.UP * 0.52
	var reach := smoothstep(0.0, 0.55, place)
	var lower := smoothstep(0.55, 1.0, place)
	carried.y = lerpf(carried.y, maxf(carried.y, over_bed.y), reach)
	princess.position = carried.lerp(over_bed, reach).lerp(bed, lower)
	princess.basis = Basis(Vector3.UP, PI).slerp(carry_basis, pickup).slerp(bed_basis, place)
	princess.stride(0.0, false)
	for arm in [erik.left_arm, erik.right_arm]:
		var side := signf(arm.position.x)
		var support_point := princess.position + princess.basis * Vector3(0, 0.96 + side * 0.47, 0.17)
		var direction: Vector3 = (erik.to_local(_surface.to_global(support_point)) - arm.position).normalized()
		arm.quaternion = arm.quaternion.slerp(Quaternion(Vector3.DOWN, direction), pickup * (1.0 - lower))
	for index in [2, 3]:
		var support := _actors[index]
		var follow := smoothstep(0.19 + index * 0.02, 0.59, t)
		var enter := smoothstep(0.59, 0.80 + index * 0.015, t)
		var station := corridor + Vector3(-0.80 + (index - 2) * 2.0, 0, index * 0.25)
		support.position = _airlock_floor(_approach_airlock(_crew_ground(index), entrance, follow).lerp(station, enter))
		support.face(bed)
		support.stride(follow * 24.0 + enter * 10.0, t < 0.59)
	var focus := _surface.position + erik.position.lerp(princess.position, 0.45) + Vector3.UP * 0.82
	var offset := Vector3(3.4, 1.4, 4.4)
	_world.medical_building.visible = t < 0.55
	if t >= 0.55:
		offset = Vector3(-2.7, 1.35, 2.8)
	_shot(focus + offset, focus)
	_capsule_lid.position.y = lerpf(2.72, 1.51, smoothstep(0.89, 0.97, t))
	if t < 0.26:
		_caption.text = "Erik  /  Stay with me. I'm getting you inside."
	elif t < 0.57:
		_caption.text = "Pilot  /  Straight ahead. The medical bay is through the airlock."
	elif t < 0.77:
		_caption.text = "Danyil  /  She's not responding. Get the capsule ready."
	elif t < 0.90:
		_caption.text = "Pilot  /  Set her down gently. I'm starting life support."
	elif _risk_succeeded:
		_caption.text = "Pilot  /  Her pulse is stable. She's in a coma. The capsule will keep her alive."
	else:
		_caption.text = "Pilot  /  The capsule restored her pulse, but she's still critical. We need that antidote now."
	_black.modulate.a = smoothstep(0.97, 1.0, t)


func _build_medbay() -> void:
	var alloy := Color("#52697b")
	var ceramic := Color("#bccbd1")
	var dark := Color("#172d40")
	var cyan := _emissive(Color("#80dedb"))
	Shapes.box(_airlock, Vector3(8.0, 0.20, 13), Vector3(0, 0.10, -7.25), alloy)
	Shapes.box(_airlock, Vector3(8.0, 0.21, 13), Vector3(0, 3.8, -7.25), dark)
	Shapes.box(_airlock, Vector3(8.0, 3.8, 0.25), Vector3(0, 1.9, -13.75), dark)
	for side in [-1, 1]:
		Shapes.box(_airlock, Vector3(0.22, 3.8, 13), Vector3(side * 4, 1.9, -7.25), dark)
		for row in 5:
			var z := -2.0 - row * 2.6
			Shapes.box(_airlock, Vector3(0.15, 2.40, 2.45), Vector3(side * 3.86, 1.70, z), ceramic)
			Shapes.box(_airlock, Vector3(0.12, 0.23, 2.45), Vector3(side * 3.77, 1.28, z), alloy)
			Shapes.box(_airlock, Vector3(0.08, 0.045, 2.38), Vector3(side * 3.72, 2.65, z), Color.WHITE).material_override = cyan
			Shapes.box(_airlock, Vector3(0.055, 0.014, 2.45), Vector3(side * 1.45, 0.206, z), Color.WHITE).material_override = cyan
		for z in [-4.0, -8.0, -11.8]:
			var x: float = side * 3.03
			Shapes.box(_airlock, Vector3(1.3, 0.82, 1.64), Vector3(x, 0.64, z), alloy)
			Shapes.box(_airlock, Vector3(1.46, 0.10, 1.76), Vector3(x, 1.10, z), ceramic)
			for drawer in 3:
				Shapes.box(_airlock, Vector3(0.05, 0.04, 0.48), Vector3(x - side * 0.68, 0.47 + drawer * 0.21, z), dark)
			Shapes.box(_airlock, Vector3(0.15, 0.62, 1.06), Vector3(x + side * 0.36, 1.61, z), dark)
			for line in 4:
				Shapes.box(_airlock, Vector3(0.02, 0.035, 0.40 + line * 0.09),
					Vector3(x + side * 0.275, 1.42 + line * 0.115, z), Color.WHITE).material_override = cyan
			Shapes.box(_airlock, Vector3(0.54, 0.11, 0.48), Vector3(x - side * 0.96, 0.71, z + 0.65), Color("#366575"))
			Shapes.box(_airlock, Vector3(0.12, 0.47, 0.12), Vector3(x - side * 0.96, 0.44, z + 0.65), alloy)
	for z in [-3.6, -7.3, -11.4]:
		Shapes.box(_airlock, Vector3(4.7, 0.055, 0.25), Vector3(0, 3.65, z), Color.WHITE).material_override = cyan
		_light(_airlock, Vector3(0, 3.4, z), Color("#d3efff"), 2.5, 7)
	Shapes.box(_airlock, Vector3(1.32, 0.71, 2.72), CAPSULE + Vector3(0, -0.40, 0.9), alloy)
	Shapes.box(_airlock, Vector3(1.18, 0.13, 2.52), CAPSULE + Vector3(0, -0.07, 0.9), Color("#d4e9e7"))
	_capsule_lid = _sphere(_airlock, Vector3(CAPSULE.x, 2.72, CAPSULE.z + 0.9), 1.0, Color.WHITE)
	_capsule_lid.scale = Vector3(0.76, 0.53, 1.52)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.38, 0.87, 0.94, 0.24)
	glass.roughness = 0.17
	_capsule_lid.material_override = glass
	_capsule_lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _airlock_floor(at: Vector3) -> Vector3:
	at = _grounded(at)
	var relative := _surface.position + at - AIRLOCK
	if absf(relative.x) <= 3.9 and relative.z >= -13.7 and relative.z <= 3.2:
		at.y = AIRLOCK.y + 0.20 - _surface.position.y + BOOT_CLEARANCE
	return at


func _approach_airlock(start: Vector3, entrance: Vector3, progress: float) -> Vector3:
	var threshold := entrance + Vector3.BACK * 2.9
	if progress < 0.76:
		return start.lerp(threshold, progress / 0.76)
	return threshold.lerp(entrance, (progress - 0.76) / 0.24)

func _advance_supply() -> void:
	_supply_stage += 1
	_elapsed = 0.0
	_black.modulate.a = 0.0
	if _supply_stage == 1:
		_departure_ship = SupplyRun.build_skimmer(_world.surface)
		_departure_ship.position = Vector3(18, 0.68, -17)
		_render_supply_scene(0.0)
	elif _supply_stage == 2:
		_layer.hide()
		_world.hide()
		_surface.hide()
		_airlock.hide()
		_supply_run = SupplyRun.new()
		add_child(_supply_run)
		_supply_run.arrived.connect(_on_supply_arrived, CONNECT_DEFERRED)


func _on_supply_arrived() -> void:
	_supply_run.hide()
	_supply_run.queue_free()
	_supply_run = null
	_supply_stage = 3
	_elapsed = 0.0
	_camera.make_current()
	_layer.show()
	_world.show()
	_world.medical_building.show()
	_surface.show()
	_actors[1].hide()
	_actors[3].hide()
	_outpost_medic = _actor(_world.surface, 3, Vector3(-25, 0, -20))
	_antidote = Shapes.box(_world.surface, Vector3(0.18, 0.26, 0.17), Vector3.ZERO, Color.WHITE)
	_antidote.material_override = _emissive(Color("#a7ffe0"))
	_render_supply_scene(0.0)


func _render_supply_scene(t: float) -> void:
	_black.modulate.a = maxf(1.0 - smoothstep(0.0, 0.09, t), smoothstep(0.91, 1.0, t))
	if _supply_stage == 3:
		_departure_ship.position = Vector3(-24, 0.72, -15)
		var erik := _actors[0]
		var danyil := _actors[2]
		erik.show()
		danyil.show()
		var approach := smoothstep(0.04, 0.49, t)
		erik.position = Vector3(-24, 0, -16.5).lerp(Vector3(-25, 0, -18.8), approach) - _surface.position
		danyil.position = Vector3(-23.4, 0, -17.2) - _surface.position
		erik.rotation = Vector3.ZERO
		danyil.rotation = Vector3.ZERO
		erik.stride(approach * 2.3, false)
		_outpost_medic.rotation.y = PI
		var handoff := smoothstep(0.49, 0.69, t)
		_outpost_medic.right_arm.rotation.x = -1.25 * (1.0 - smoothstep(0.69, 0.90, t))
		erik.right_arm.rotation.x = -1.15 * smoothstep(0.43, 0.64, t)
		_antidote.position = Vector3(-25, 1.37, -19.43).lerp(Vector3(-24.57, 1.36, -19.24), handoff)
		_shot(Vector3(-20.0 - t * 1.9, 2.65, -15.1), Vector3(-24.7, 1.20, -19.0))
		_caption.text = "Outpost medic  /  One dose. Keep it cold until you get back." if t < 0.73 else "Erik  /  We've got it. Pilot, tell her we're coming home."
		return
	if t < 0.60:
		_shot(AIRLOCK + Vector3(-2.2 + t, 2.0, -5.4), AIRLOCK + CAPSULE)
		if t < 0.24:
			_caption.text = "Pilot  /  Outpost Twelve, she's in a coma. We need a dose of your antidote."
		elif t < 0.46:
			_caption.text = "Outpost Twelve  /  We have one. The canyon relay road is still open."
		else:
			_caption.text = "Erik  /  Keep her on life support. Danyil, you're with me."
		return
	_world.medical_building.show()
	var boarding := smoothstep(0.60, 0.85, t)
	var skimmer := _departure_ship.position
	for index in [0, 2]:
		var actor := _actors[index]
		actor.position = _grounded(skimmer - _surface.position + Vector3(index - 1.0, 0, 4.5 - boarding * 4.5))
		actor.rotation = Vector3(0, 0, 0)
		actor.stride(boarding * 5.0, false)
		actor.visible = boarding < 0.92
	_departure_ship.position.y = 0.68 + smoothstep(0.84, 1.0, t) * 1.35
	_shot(skimmer + Vector3(6.2, 3.4, 7.5), skimmer + Vector3.UP * 0.8)
	_caption.text = "Danyil  /  I'll read the relay markers. You fly."
