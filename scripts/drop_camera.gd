extends Camera3D

const Shapes = preload("res://scripts/vehicle_visual.gd")

var _pitch := 0.0
var _time := 0.0
var _weapon := Node3D.new()
var _recoil := 0.0
var _wind_noise := FastNoiseLite.new()
var _muzzle: Marker3D
var _flash: MeshInstance3D
var _flash_timer := 0.0
var _bump := 0.0


func _ready() -> void:
	_wind_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_wind_noise.frequency = 0.71
	add_child(_weapon)
	_weapon.hide()
	for part in [
		Shapes.box(_weapon, Vector3(0.16, 0.16, 0.45), Vector3(0, 0, -0.04), Color("#303944")),
		Shapes.box(_weapon, Vector3(0.12, 0.18, 0.16), Vector3(0, -0.09, 0.07), Color("#272c36")),
		Shapes.box(_weapon, Vector3(0.17, 0.16, 0.20), Vector3(0, -0.14, 0.18), Color("#c69778")),
		Shapes.box(_weapon, Vector3(0.19, 0.19, 0.36), Vector3(0, -0.19, 0.33), Color("#306c77")),
	]:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle = Marker3D.new()
	_muzzle.position = Vector3(0, 0.02, -0.32)
	_weapon.add_child(_muzzle)
	_flash = Shapes.box(_muzzle, Vector3(0.14, 0.14, 0.26), Vector3.ZERO, Color("#ffc060"))
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := _flash.material_override.duplicate() as StandardMaterial3D
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.emission_enabled = true
	glow.emission = Color("#ffbb6b")
	_flash.material_override = glow
	_flash.hide()


func recoil() -> void:
	_recoil = 1.0
	_flash_timer = 0.062
	_flash.show()


func muzzle_position() -> Vector3:
	return _muzzle.global_position


func bump(amount: float) -> void:
	_bump = maxf(_bump, amount)


func set_driving() -> void:
	_pitch = 0.0
	_bump = 0.0
	_weapon.hide()


func animate_driving(delta: float) -> void:
	_bump = move_toward(_bump, 0.0, delta * 2.9)
	rotation.z = lerpf(rotation.z, -_bump * 0.12, 1.0 - exp(-delta * 14.0))


func look(relative: Vector2) -> void:
	get_parent().rotate_y(-relative.x * 0.0025)
	_pitch = clampf(_pitch - relative.y * 0.0025, -1.53, 1.53)


func animate(delta: float, fall_speed: float, steer: Vector2, grounded: bool, moving: bool) -> void:
	_time += delta
	_flash_timer = maxf(0.0, _flash_timer - delta)
	_flash.visible = _flash_timer > 0.0
	_bump = move_toward(_bump, 0.0, delta * 2.9)
	var wind := smoothstep(12.0, 82.0, fall_speed)
	var blend := 1.0 - exp(-delta * 9.0)
	position.x = _wind_noise.get_noise_1d(_time * 19.0) * wind * 0.085
	position.y = 1.62 + _wind_noise.get_noise_1d(_time * 20.0 + 80.0) * wind * 0.095
	position.y += sin(_time * 11.0) * (0.025 if moving else 0.0)
	rotation.x = lerpf(rotation.x, clampf(_pitch - steer.y * (0.05 + wind * 0.14), -1.54, 1.54), blend)
	rotation.z = lerpf(rotation.z, -steer.x * (0.09 + wind * 0.19) + _wind_noise.get_noise_1d(_time * 24.0) * wind * 0.035 - _bump * 0.26, blend)
	var dive_fov := lerpf(75.0, 110.0, smoothstep(56.0, 82.0, fall_speed))
	var tuck := maxf(0.0, steer.y) * 5.0 * (1.0 - smoothstep(65.0, 82.0, fall_speed))
	fov = lerpf(fov, 73.0 if grounded else dive_fov - tuck, blend)
	_recoil = move_toward(_recoil, 0.0, delta * 7.0)
	_weapon.visible = grounded
	_weapon.position = Vector3(0.37, -0.32 + sin(_time * 11.0) * (0.013 if moving else 0.004),
		-0.59 + _recoil * 0.11)
	_weapon.rotation.x = _recoil * 0.22


func fall_on_death() -> void:
	_weapon.hide()
	var fall := create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fall.tween_property(self, "position:y", 0.24, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(self, "rotation:z", -0.91, 0.44)
	fall.tween_property(self, "rotation:x", -0.27, 0.44)
