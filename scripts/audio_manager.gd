extends Node

const RATE: int = 22050
const BEAT: float = 0.375
const MUSIC: StringName = &"Music"
const EFFECTS: StringName = &"Effects"

var music: AudioStreamPlayer
var engine: AudioStreamPlayer
var cues: Dictionary = {}


func _ready() -> void:
	_create_bus(MUSIC)
	_create_bus(EFFECTS)
	music = _player(MUSIC, -20.0)
	engine = _player(EFFECTS, -25.0)
	music.stream = _make_wave("music", BEAT * 32.0, true)
	engine.stream = _make_wave("engine", 0.25, true)
	cues = {
		"click": _make_wave("click", 0.09),
		"coin": _make_wave("coin", 0.27),
		"crash": _make_wave("crash", 0.44),
		"shot": _make_wave("shot", 0.18),
		"horn": _make_wave("horn", 0.37),
		"siren": _make_wave("siren", 2.5),
		"panic": preload("res://assets/city/look_out.wav"),
	}
	if DisplayServer.get_name() != "headless":
		music.play()


func apply(settings: Dictionary) -> void:
	_volume(&"Master", float(settings.master))
	_volume(MUSIC, float(settings.music))
	_volume(EFFECTS, float(settings.effects))


func set_driving(active: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if active and not engine.playing:
		engine.play()
	elif not active:
		engine.stop()


func set_speed(speed: float) -> void:
	engine.pitch_scale = clampf(0.65 + speed / 105.0, 0.65, 1.85)


func play_cue(cue: String) -> void:
	if DisplayServer.get_name() == "headless" or not cues.has(cue):
		return
	var player := _player(EFFECTS, -11.0)
	player.stream = cues[cue]
	player.finished.connect(player.queue_free)
	player.play()


func play_shot_at(at: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var report := AudioStreamPlayer3D.new()
	report.bus = EFFECTS
	report.stream = cues["shot"]
	report.volume_db = -11.0
	report.pitch_scale = randf_range(0.94, 1.08)
	report.unit_size = 6.0
	report.max_distance = 85.0
	add_child(report)
	report.global_position = at
	report.finished.connect(report.queue_free)
	report.play()


func _create_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _volume(bus_name: StringName, level: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(bus_index, level <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(0.0001, level)))


func _player(bus_name: StringName, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	player.volume_db = volume
	add_child(player)
	return player


func _make_wave(kind: String, seconds: float, looped: bool = false) -> AudioStreamWAV:
	var sample_count := roundi(seconds * RATE)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 3728
	var bass: Array[float] = [110.0, 87.31, 130.81, 98.0]
	var melody: Array[float] = [2.0, 3.0, 4.0, 2.0, 2.5, 3.0, 1.5, 3.0]
	for index in sample_count:
		var time := float(index) / RATE
		var sample: float
		match kind:
			"music":
				var beat_index := int(time / BEAT)
				var beat_time := fmod(time, BEAT)
				var root := bass[int(beat_index / 8.0) % bass.size()]
				var envelope := minf(beat_time * 120.0, 1.0) * exp(-beat_time * 10.0)
				sample = (sin(TAU * root * beat_time) * 0.46 + sin(TAU * root * melody[beat_index % 8] * beat_time) * 0.18) * envelope
			"engine":
				sample = sin(TAU * 64.0 * time) * 0.54 + sin(TAU * 128.0 * time) * 0.17 + sin(TAU * 192.0 * time) * 0.08
			"coin":
				sample = sin(TAU * (550.0 * time + 1100.0 * time * time)) * exp(-time * 10.0)
			"crash":
				sample = (noise.randf_range(-1.0, 1.0) * 0.48 + sin(TAU * (88.0 * time - 58.0 * time * time)) * 0.6) * exp(-time * 10.0)
			"shot":
				sample = (noise.randf_range(-1.0, 1.0) * 0.64 + sin(TAU * 138.0 * time) * 0.36) * exp(-time * 29.0)
			"horn":
				sample = (sin(TAU * 338.0 * time) + sin(TAU * 427.0 * time) * 0.7) * 0.28 * exp(-time * 2.3)
			"siren":
				var modulation := 18.0 * sin(TAU * time / 1.22)
				sample = sin(TAU * 632.0 * time + modulation) * 0.21 * sin(PI * time / seconds)
			_:
				sample = sin(TAU * 420.0 * time) * exp(-time * 45.0)
		if not looped:
			sample *= minf(time * 180.0, 1.0) * minf((seconds - time) * 100.0, 1.0)
		samples.encode_s16(index * 2, roundi(clampf(sample, -1.0, 1.0) * 32767.0))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = RATE
	wave.data = samples
	if looped:
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_end = sample_count
	return wave

