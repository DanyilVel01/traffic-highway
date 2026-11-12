extends CanvasLayer

const Actor = preload("res://scripts/finale_actor.gd")
const Shapes = preload("res://scripts/vehicle_visual.gd")
const MINT := Color("#83eadf")
const ALERT := Color("#ffaf80")

var _title: Label
var _telemetry: Label
var _target: Label
var _help: Label
var _subtitle: Label
var _frame: PanelContainer
var _feed: SubViewport
var _cast: Array[Actor] = []
var _names: Array[String] = ["Erik", "Pilot", "Princess", "Friend"]
var _speaker := -1
var _dialogue_time := 0.0
var _talk_time := 0.0
var _voice := AudioStreamPlayer.new()


func _ready() -> void:
	layer = 2
	_title = _label(27)
	_title.position = Vector2(28, 21)
	_title.modulate = MINT
	_telemetry = _label(19)
	_telemetry.position = Vector2(30, 64)
	_target = _label(21)
	_target.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_target.offset_left = -250
	_target.offset_right = 250
	_target.offset_top = 24
	_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help = _label(17)
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_help.offset_top = -60
	_help.offset_bottom = -23
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle = _label(23)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle.offset_left = 44
	_subtitle.offset_right = -44
	_subtitle.offset_top = -123
	_subtitle.offset_bottom = -66
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_feed()
	add_child(_voice)
	_voice.bus = &"Effects"
	_voice.volume_db = -3.0


func _label(font_size: int) -> Label:
	var label := Label.new()
	add_child(label)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#e8f7fb"))
	label.add_theme_color_override("font_outline_color", Color("#08121f"))
	label.add_theme_constant_override("outline_size", 7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func show_cruise(hull: int, throttle: float, speed: float, remaining: float, danger: bool) -> void:
	_title.text = "VESPER TRANSFER"
	_telemetry.text = "HULL  %03d%%\nTHRUST  %03d%%\nVELOCITY  %03d m/s" % [hull, roundi(throttle * 100.0), roundi(speed)]
	_target.text = "VESPER  ·  %04d m" % ceili(remaining)
	if danger:
		_target.text += "\nASTEROID ON COURSE"
	_target.modulate = ALERT if danger else MINT
	_help.text = "A/D  Strafe    ·    ↑/↓  Vertical thrust    ·    W/S  Throttle    ·    SPACE  Brake    ·    ESC  Pause"


func show_landing(hull: int, throttle: float, fuel: float, height: float, speed: Vector3, distance: float,
		angle: float, vector: Vector2, stable: bool) -> void:
	_title.text = "VESPER  /  OUTPOST 07"
	_telemetry.text = "HULL  %03d%%    FUEL  %03d%%\nTHROTTLE  %03d%%  /  HOVER  46%%\nALT  %05.1f m    VERT  %+.1f m/s\nDRIFT  %.1f m/s    TILT  %.0f°" % [
		hull, roundi(fuel), roundi(throttle * 100.0), height, speed.y, Vector2(speed.x, speed.z).length(), angle]
	_target.text = ("PAD LOCKED" if stable else "CENTER ON PAD") + "\n%.1f m  ·  X %+.1f   Z %+.1f" % [distance, vector.x, vector.y]
	_target.text += "\n≤3.2 m  ·  ≤3.4 m/s down  ·  ≤1.85 m/s drift  ·  ≤7° tilt"
	_target.modulate = MINT if stable else ALERT
	_help.text = "A/D  Roll    ·    ↑/↓  Pitch    ·    W/S  Throttle    ·    SPACE  Kill lateral drift    ·    ESC  Pause"


func show_landed() -> void:
	_title.text = "VESPER  /  OUTPOST 07"
	_telemetry.text = ""
	_target.text = "TOUCHDOWN CONFIRMED"
	_target.modulate = MINT
	_help.text = ""


func say(speaker: String, words: String, seconds: float = 5.0, recording: String = "") -> void:
	_speaker = _names.find(speaker)
	_dialogue_time = seconds
	_talk_time = 0.0
	_subtitle.text = "%s / %s" % [speaker, words]
	_voice.stop()
	if not recording.is_empty() and DisplayServer.get_name() != "headless":
		var path := "res://assets/space/dialogue/%s.wav" % recording
		if ResourceLoader.exists(path):
			_voice.stream = load(path) as AudioStream
			_voice.play()


func pause_voice(paused: bool) -> void:
	_voice.stream_paused = paused


func _exit_tree() -> void:
	_voice.stop()
	_voice.stream = null


func _process(delta: float) -> void:
	_dialogue_time = maxf(0.0, _dialogue_time - delta)
	_subtitle.visible = _dialogue_time > 0.0
	_frame.visible = _dialogue_time > 0.0 and _speaker >= 0
	if DisplayServer.get_name() != "headless":
		_feed.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if _frame.visible else SubViewport.UPDATE_DISABLED
	if not _frame.visible:
		return
	_talk_time += delta
	for index in _cast.size():
		var person := _cast[index]
		var speaking := index == _speaker
		var partner := (1 if index == 0 else 0) if speaking else _speaker
		var toward := _cast[partner].position - person.position
		toward.z += 0.55
		person.rotation.y = lerp_angle(person.rotation.y, atan2(-toward.x, -toward.z), 1.0 - exp(-delta * 7.0))
		var mouth := absf(sin(_talk_time * 14.0)) * smoothstep(0.0, 0.32, _dialogue_time) if speaking else 0.0
		person.cinematic_pose(0.0, 0.86, mouth, (0.37 + sin(_talk_time * 3.2) * 0.17) if speaking else 0.0)


func _build_feed() -> void:
	_frame = PanelContainer.new()
	add_child(_frame)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_frame.offset_left = -336
	_frame.offset_right = -26
	_frame.offset_top = 104
	_frame.offset_bottom = 282
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chrome := StyleBoxFlat.new()
	chrome.bg_color = Color("#102235")
	chrome.border_color = Color("#477d87")
	chrome.set_border_width_all(2)
	chrome.set_content_margin_all(4)
	_frame.add_theme_stylebox_override("panel", chrome)
	var image := SubViewportContainer.new()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.stretch = true
	_frame.add_child(image)
	_feed = SubViewport.new()
	image.add_child(_feed)
	_feed.own_world_3d = true
	_feed.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var cockpit := Node3D.new()
	_feed.add_child(cockpit)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#172a3b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#c7dff0")
	env.environment.ambient_light_energy = 0.58
	cockpit.add_child(env)
	var key := DirectionalLight3D.new()
	cockpit.add_child(key)
	key.rotation_degrees = Vector3(-41, 20, 0)
	key.light_color = Color("#a3e4ef")
	Shapes.box(cockpit, Vector3(6.2, 0.87, 0.66), Vector3(0, 0.38, 0.78), Color("#293b49"))
	for index in 4:
		var person := Actor.new()
		cockpit.add_child(person)
		person.build(Actor.Role.PRINCESS if index == 2 else Actor.Role.DRIVER,
			[Color("#48858b"), Color("#839b80"), Color("#be6eac"), Color("#c68755")][index])
		person.position = Vector3((index - 1.5) * 1.13, -0.26, 0)
		person.rotation.y = PI
		_cast.append(person)
	var camera := Camera3D.new()
	cockpit.add_child(camera)
	camera.position = Vector3(0, 1.52, 4.35)
	camera.look_at(Vector3(0, 1.21, 0))
	camera.fov = 34.0
	camera.make_current()
	_frame.hide()
