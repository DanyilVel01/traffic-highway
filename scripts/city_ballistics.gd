extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const Player = preload("res://scripts/skydive_player.gd")
const Target = preload("res://scripts/city_target.gd")
const Vehicle = preload("res://scripts/street_vehicle.gd")
const COVER_MASK := Player.WORLD_LAYER | Player.VEHICLE_LAYER

signal hit_confirmed(lethal: bool)
signal ally_blocked
signal shot(at: Vector3)

class Projectile:
	var body: MeshInstance3D
	var velocity: Vector3
	var remaining := 1.45

var player: Player
var active := true
var _rounds: Array[Projectile] = []
var _marks: Array[MeshInstance3D] = []
var _queued := false
var _eye: Vector3
var _aim: Vector3
var _muzzle: Vector3


func bind_player(target: Player) -> void:
	player = target
	player.fired.connect(_queue_shot)


func clear_projectiles() -> void:
	_queued = false
	for projectile in _rounds:
		projectile.body.queue_free()
	_rounds.clear()


func _queue_shot(origin: Vector3, direction: Vector3) -> void:
	_eye = origin
	_aim = direction.normalized()
	_muzzle = player.camera.muzzle_position()
	_queued = true


func cast(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	query.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func fire_hostile(origin: Vector3, target: Vector3) -> void:
	var projectile := Projectile.new()
	projectile.velocity = origin.direction_to(target) * 72.0
	projectile.body = Shapes.box(self, Vector3(0.026, 0.026, 0.66), origin, Color("#ffd486"))
	projectile.body.basis = Basis.looking_at(projectile.velocity)
	projectile.body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rounds.append(projectile)
	shot.emit(origin)


func _physics_process(delta: float) -> void:
	if not player.damage.alive or not active:
		return
	if _queued:
		_queued = false
		if not player.mounted:
			_fire_hitscan()
	for index in range(_rounds.size() - 1, -1, -1):
		var round := _rounds[index]
		var next := round.body.position + round.velocity * delta
		var hit := cast(round.body.position, next, COVER_MASK | Player.PLAYER_LAYER | Target.ALLY)
		if hit.get("collider") == player:
			_impact(hit.position, hit.normal, true, false)
			player.damage.take_hit(23.0)
		elif player.mounted and hit.get("collider") == player.camera.get_parent():
			player.damage.take_hit(6.0)
		elif not hit.is_empty() and not hit.collider is Target:
			_impact(hit.position, hit.normal, false, hit.collider is StaticBody3D)
		round.remaining -= delta
		if not hit.is_empty() or round.remaining <= 0.0:
			_rounds.remove_at(index)
			round.body.queue_free()
		else:
			round.body.position = next


func _fire_hitscan() -> void:
	var hit := cast(_eye, _eye + _aim * 110.0, COVER_MASK | Target.PEOPLE)
	var end := _eye + _aim * 110.0
	if not hit.is_empty():
		end = hit.position
	# The sight picks the target, but the muzzle cannot shoot through nearby cover.
	var blocked := cast(_muzzle, end, COVER_MASK | Target.ALLY)
	if not blocked.is_empty() and _muzzle.distance_squared_to(blocked.position) < _muzzle.distance_squared_to(end) - 0.01:
		hit = blocked
		end = hit.position
	shot.emit(_muzzle)
	var offset := end - _muzzle
	if offset.length_squared() > 0.01:
		var tracer := Shapes.box(self, Vector3(0.016, 0.016, offset.length()), (_muzzle + end) * 0.5, Color("#ffd486"))
		tracer.basis = Basis.looking_at(offset)
		tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		create_tween().tween_callback(tracer.queue_free).set_delay(0.055)
	if hit.is_empty():
		return
	var target := hit.collider as Target
	var vehicle := hit.collider as Vehicle
	if vehicle:
		target = vehicle.driver_in_window(end, _eye, _aim)
	if target and not target.health:
		ally_blocked.emit()
		return
	_impact(end, hit.normal, target != null, hit.collider is StaticBody3D)
	if target:
		var wound := end if not vehicle else target.global_position + Vector3.UP * 0.50
		hit_confirmed.emit(target.strike(wound, _aim))


func _impact(at: Vector3, normal: Vector3, flesh: bool, mark_surface: bool) -> void:
	var dirt := normal.y > 0.65 and (at.x > 175.0 and at.x < 2225.0) and absf(at.z) > 11.0
	var color := Color("#a6444e") if flesh else (Color("#aa8865") if dirt else Color("#c9c6b8"))
	var spread := create_tween().set_parallel()
	for index in 5:
		var fleck := Shapes.box(self, Vector3.ONE * (0.035 + index * 0.008), at + normal * 0.018, color)
		fleck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var drift := normal * (0.19 + index * 0.066) + Vector3(sin(index * 2.4), cos(index * 1.7), sin(index * 1.2)) * 0.22
		spread.tween_property(fleck, "position", at + drift, 0.24)
		spread.tween_property(fleck, "scale", Vector3.ZERO, 0.28)
		spread.tween_callback(fleck.queue_free).set_delay(0.29)
	if mark_surface:
		var mark := Shapes.box(self, Vector3(0.10, 0.10, 0.012), at + normal * 0.008, color.darkened(0.49))
		mark.basis = Basis.looking_at(normal, Vector3.RIGHT if absf(normal.y) > 0.9 else Vector3.UP)
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_marks.append(mark)
		if _marks.size() > 32:
			_marks.pop_front().queue_free()
