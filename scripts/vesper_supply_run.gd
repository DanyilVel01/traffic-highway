extends Node3D

signal arrived

const Shapes = preload("res://scripts/vehicle_visual.gd")
const LENGTH := 4200.0
const LANE_WIDTH := 4.1
const SEGMENT := 48.0
const ROCK := Color("#865968")
const CHARGE := Color("#6ff6e0")

var _skimmer: Node3D
var _camera := Camera3D.new()
var _hud := Label.new()
var _message := Label.new()
var _road: Array[Node3D] = []
var _waves: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _distance := 0.0
var _next_wave := 100.0
var _lane := 1
var _safe_lane := 1
var _shield := 3
var _hit_time := 0.0
var _failed := false
var _active := true
var _clock := 0.0


static func build_skimmer(parent: Node3D) -> Node3D:
	var ship := Node3D.new()
	parent.add_child(ship)
	var hull := PrismMesh.new()
	hull.size = Vector3(3.3, 0.58, 3.9)
	var shell := Shapes.attach(ship, hull, Vector3(0, 0.55, 0), Color("#c7dae3"))
	shell.rotation.x = PI * 0.5
	var canopy := SphereMesh.new()
	Shapes.attach(ship, canopy, Vector3(0, 0.85, -0.26), Color("#234762")).scale = Vector3(1.1, 0.52, 1.9)
	for side in [-1, 1]:
		var pod := TorusMesh.new()
		pod.inner_radius = 0.32
		pod.outer_radius = 0.62
		Shapes.attach(ship, pod, Vector3(side * 1.23, 0.42, 0.45), Color("#52657b"))
		_glow(Shapes.box(ship, Vector3(0.63, 0.09, 0.46), Vector3(side * 1.23, 0.40, 0.45), CHARGE), CHARGE)
	_glow(Shapes.box(ship, Vector3(1.1, 0.06, 0.22), Vector3(0, 0.52, 1.38), CHARGE), CHARGE)
	return ship


static func _glow(mesh: MeshInstance3D, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	mesh.material_override = material


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#29213d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c8b1d7")
	environment.ambient_light_energy = 0.8
	environment.fog_enabled = true
	environment.fog_light_color = Color("#765974")
	environment.fog_density = 0.008
	_camera.environment = environment
	add_child(_camera)
	_camera.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-44, -39, 0)
	sun.light_color = Color("#ffb197")
	sun.shadow_enabled = true
	add_child(sun)
	_skimmer = build_skimmer(self)
	for index in 9:
		var chunk := Node3D.new()
		add_child(chunk)
		_road.append(chunk)
		Shapes.box(chunk, Vector3(16, 0.55, SEGMENT), Vector3.DOWN * 0.28, Color("#473e59"))
		for side in [-1, 1]:
			for marker in 4:
				_glow(Shapes.box(chunk, Vector3(0.12, 0.05, 4), Vector3(side * 6.4, 0.04, -18 + marker * 12), CHARGE), CHARGE)
			var stone := SphereMesh.new()
			stone.radial_segments = 6
			stone.rings = 3
			var ridge := Shapes.attach(chunk, stone, Vector3(side * (17 + index % 4), 1.6, 2), ROCK)
			ridge.scale = Vector3(13 + index % 3, 8 + index % 5, 24)
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	layer.add_child(_hud)
	_hud.position = Vector2(28, 22)
	_hud.add_theme_font_size_override("font_size", 22)
	layer.add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_message.offset_top = -68
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 23)
	_reset()


func _reset() -> void:
	for wave in _waves:
		wave.queue_free()
	_waves.clear()
	_rng.seed = 7413
	_distance = 0.0
	_next_wave = 100.0
	_lane = 1
	_safe_lane = 1
	_shield = 3
	_hit_time = 0.0
	_failed = false
	_skimmer.position = Vector3.ZERO
	_message.text = "A / D  Steer     W  Boost     S  Brake     Collect turquoise shield cells"


func _unhandled_input(event: InputEvent) -> void:
	if not _active or event.is_echo():
		return
	if _failed:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
			_reset()
		return
	if event.is_action_pressed("move_left"):
		_lane = maxi(0, _lane - 1)
	elif event.is_action_pressed("move_right"):
		_lane = mini(2, _lane + 1)


func _physics_process(delta: float) -> void:
	if not _active or _failed:
		return
	_clock += delta
	_hit_time = maxf(0, _hit_time - delta)
	var speed := 37.0 + 6.0 * smoothstep(0, LENGTH, _distance)
	speed += 9.0 * Input.get_action_strength("accelerate") - 10.0 * Input.get_action_strength("brake")
	var previous := _distance
	_distance = minf(LENGTH, _distance + speed * delta)
	_skimmer.position.x = move_toward(_skimmer.position.x, (_lane - 1) * LANE_WIDTH, 13.5 * delta)
	_skimmer.position.y = 0.68 + sin(_clock * 6.0) * 0.09
	_skimmer.rotation.z = lerpf(_skimmer.rotation.z, -((_lane - 1) * LANE_WIDTH - _skimmer.position.x) * 0.08, delta * 8.0)
	_camera.position = Vector3(_skimmer.position.x * 0.37, 4.9, 10.2)
	_camera.look_at(Vector3(0, 0.75, -16))
	for index in _road.size():
		var span := SEGMENT * _road.size()
		_road[index].position.z = fposmod(_distance + index * SEGMENT + SEGMENT, span) - span + SEGMENT
	while _next_wave < minf(LENGTH - 25.0, _distance + 245.0):
		_spawn_wave()
	for index in range(_waves.size() - 1, -1, -1):
		var wave := _waves[index]
		var marker: float = wave.get_meta("distance")
		wave.position.z = _distance - marker
		if previous < marker and _distance >= marker:
			var lane := clampi(roundi(_skimmer.position.x / LANE_WIDTH) + 1, 0, 2)
			if lane in wave.get_meta("blocked") and _hit_time <= 0.0:
				_shield -= 1
				_hit_time = 0.85
			elif lane == wave.get_meta("charge"):
				_shield = mini(3, _shield + 1)
		if wave.position.z > 20.0:
			_waves.remove_at(index)
			wave.queue_free()
	_hud.text = "MEDICINE RUN   ·   %d m TO OUTPOST   ·   SHIELD %d / 3" % [ceili(LENGTH - _distance), _shield]
	_hud.modulate = Color("#ff8772") if _hit_time > 0.0 else Color.WHITE
	if _shield <= 0:
		_failed = true
		_message.text = "Skimmer disabled  ·  Press R to retry from the station"
	elif _distance >= LENGTH:
		_active = false
		arrived.emit()


func _spawn_wave() -> void:
	var wave := Node3D.new()
	add_child(wave)
	_waves.append(wave)
	_safe_lane = clampi(_safe_lane + _rng.randi_range(-1, 1), 0, 2)
	var blocked: Array[int] = []
	var charge := -1
	var difficult := _distance > 800.0 and _rng.randf() < 0.73
	for lane in 3:
		if lane == _safe_lane or (not difficult and blocked.size() == 1):
			continue
		blocked.append(lane)
		var rock := SphereMesh.new()
		rock.radial_segments = 6
		rock.rings = 3
		var debris := Shapes.attach(wave, rock, Vector3((lane - 1) * LANE_WIDTH, 1.0, 0), ROCK)
		debris.scale = Vector3(3.1, _rng.randf_range(2.0, 4.6), 3.8)
		debris.rotation.z = _rng.randf_range(-0.35, 0.35)
	if _rng.randf() < 0.27:
		charge = _safe_lane
		var cell := PrismMesh.new()
		cell.size = Vector3(0.57, 0.89, 0.55)
		_glow(Shapes.attach(wave, cell, Vector3((charge - 1) * LANE_WIDTH, 0.9, 0), CHARGE), CHARGE)
	wave.set_meta("distance", _next_wave)
	wave.set_meta("blocked", blocked)
	wave.set_meta("charge", charge)
	_next_wave += _rng.randf_range(39, 61) if _distance > 800.0 else _rng.randf_range(57, 77)
