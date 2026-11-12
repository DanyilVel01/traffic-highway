extends CanvasLayer

const Player = preload("res://scripts/skydive_player.gd")
const Blur = preload("res://scripts/drop_blur.gdshader")
const Traffic = preload("res://scripts/city_traffic.gd")
const Crowd = preload("res://scripts/city_crowd.gd")
const Places = preload("res://scripts/city_places.gd")
const Region = preload("res://scripts/region_terrain.gd")
const Story = preload("res://scripts/city_story.gd")

var player: Player
var traffic: Traffic
var crowd: Crowd
var places: Places
var story: Story
var _objective: Label
var _countdown: Label
var _dialogue: Label
var _dialogue_time := 0.0
var _health: Label
var _cinema_bars: Array[ColorRect] = []
var _telemetry: Label
var _controls: Label
var _alert: Label
var _reticle: Label
var _blur: ShaderMaterial
var _alert_time := 0.0
var _hit_time := 0.0
var _lethal := false


func _ready() -> void:
	layer = 2
	var blur := ColorRect.new()
	add_child(blur)
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur = ShaderMaterial.new()
	_blur.shader = Blur
	blur.material = _blur
	_telemetry = _line(20)
	_telemetry.position = Vector2(26, 24)
	_controls = _line(19)
	_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_controls.offset_top = -65
	_controls.offset_bottom = -25
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert = _line(22)
	_alert.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_alert.offset_top = 84
	_alert.offset_bottom = 112
	_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert.modulate = Color("#ffd285")
	_reticle = _line(24)
	_reticle.text = "+"
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective = _line(17)
	_objective.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_objective.offset_top = 20
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown = _line(31)
	_countdown.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_countdown.offset_left = -112
	_countdown.offset_top = 16
	_countdown.modulate = Color("#ff9c73")
	_dialogue = _line(21)
	_dialogue.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dialogue.offset_left = 45
	_dialogue.offset_right = -45
	_dialogue.offset_top = -129
	_dialogue.offset_bottom = -76
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health = _line(19)
	_health.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_health.offset_left = 26
	_health.offset_top = -97
	_health.offset_bottom = -73
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color("#0c1321")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = 0 if top else -68
		bar.offset_bottom = 63 if top else 0
		bar.z_index = -1
		_cinema_bars.append(bar)


func say(line: String) -> void:
	_dialogue.text = line
	_dialogue_time = clampf(line.length() * 0.052, 3.0, 6.3)


func notify(message: String) -> void:
	_alert.text = message
	_alert_time = 2.8


func confirm_hit(lethal: bool) -> void:
	_hit_time = 0.31
	_lethal = lethal


func _process(delta: float) -> void:
	_dialogue_time = maxf(_dialogue_time - delta, 0.0)
	_dialogue.visible = _dialogue_time > 0.0
	_objective.text = story.objective
	if story.stage > Story.Stage.LANDING and story.stage < Story.Stage.LAUNCH:
		_objective.text += "\n%d m" % roundi(player.position.distance_to(story.destination))
	var escape := story.stage == Story.Stage.ESCAPE
	var seconds := ceili(story.remaining)
	_countdown.visible = escape and not story.cinematic
	_countdown.text = "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
	var cinematic := story.cinematic
	if cinematic:
		_objective.text = story.cinema.title if story.cinema.active else ""
		if story.ignition_pending:
			_objective.text = "ERIK  /  HOLD W TO IGNITE\nLAUNCH THRUST  %02d%% / 70%%" % floori(story.launch_throttle * 100.0)
	for bar in _cinema_bars:
		bar.visible = cinematic
	_telemetry.visible = not cinematic
	_controls.visible = not cinematic
	_health.visible = not cinematic and player.phase == Player.Phase.GROUND
	_health.text = "HP  %03d / %d" % [ceili(player.damage.hp), int(player.damage.MAX_HP)]
	_health.modulate = Color("#ff8772") if player.damage.hp < 65 else Color("#97e6c0")
	_hit_time = maxf(0.0, _hit_time - delta)
	_alert_time = maxf(0.0, _alert_time - delta)
	_alert.visible = _alert_time > 0.0 and not cinematic
	var fall := maxf(0.0, -player.velocity.y)
	var grounded := player.phase == Player.Phase.GROUND
	var horizontal := Vector2(player.velocity.x, player.velocity.z).length()
	_reticle.visible = grounded and not player.mounted and not cinematic
	_reticle.text = "×" if _hit_time > 0.0 else "+"
	_reticle.modulate = (Color("#ff807e") if _lethal else Color.WHITE) if _hit_time > 0.0 else (
		Color("#80e6b9") if is_instance_valid(traffic.nearby) or is_instance_valid(places.nearby) else (
			Color("#ffc77c") if crowd.is_targeting_pedestrian() else Color.WHITE))
	_blur.set_shader_parameter("amount", 0.0 if grounded else smoothstep(12.0, 82.0, fall))
	_blur.set_shader_parameter("moisture", player.moisture)
	if grounded:
		var district := "COASTAL CITY" if player.position.x < 175.0 else ("RIDGE CITY" if player.position.x > Region.CITY_DISTANCE - 175.0 else "RIDGE HIGHWAY")
		_telemetry.text = district
		if is_instance_valid(traffic.driven):
			_telemetry.text += "\n%03d km/h" % roundi(absf(traffic.driven.speed) * 3.6)
			_controls.text = "WASD  Drive   ·   SPACE  Handbrake   ·   F  Exit vehicle"
		elif story.can_interact():
			match story.stage:
				Story.Stage.CAFE:
					_controls.text = "E  Talk to the princess"
				Story.Stage.BUS:
					_controls.text = "E  Talk to your friend"
				Story.Stage.WRECK:
					_controls.text = "E  Help the pilot"
				Story.Stage.RADIO:
					_controls.text = "E  Start broadcast"
				Story.Stage.ESCAPE:
					_controls.text = "E  Board rocket"
		elif is_instance_valid(traffic.nearby):
			_controls.text = "F  Hijack " + traffic.nearby.TYPES[traffic.nearby.type_index]
		elif is_instance_valid(places.nearby):
			_controls.text = "E  Close door" if places.nearby.opened else "E  Open door"
		else:
			_controls.text = "SPACE  Drop again" if player.drop_available else "WASD  Move   ·   SHIFT  Sprint   ·   SPACE  Jump   ·   LMB  Shoot   ·   ESC  Pause"
	else:
		var phase := "PARACHUTE" if player.phase == Player.Phase.PARACHUTE else "FREEFALL"
		_telemetry.text = "%s\nAGL  %03d m    ·    VERTICAL  %03d km/h    ·    HORIZONTAL  %03d km/h" % [
			phase, roundi(player.altitude_agl), roundi(fall * 3.6), roundi(horizontal * 3.6)]
		_controls.text = "WASD  Lean and steer   ·   MOUSE  Look"
		if player.phase == Player.Phase.FREEFALL:
			_controls.text += "   ·   SPACE  Deploy parachute"
		_controls.text += "   ·   ESC  Pause"


func _line(font_size: int) -> Label:
	var line := Label.new()
	line.add_theme_font_size_override("font_size", font_size)
	line.add_theme_color_override("font_color", Color("#f3fff9"))
	line.add_theme_color_override("font_outline_color", Color("#132632"))
	line.add_theme_constant_override("outline_size", 7)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	return line
