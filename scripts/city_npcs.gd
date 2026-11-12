extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const Actor = preload("res://scripts/finale_actor.gd")
const Player = preload("res://scripts/skydive_player.gd")
const Events = preload("res://scripts/city_events.gd")
const Region = preload("res://scripts/region_terrain.gd")
const Ballistics = preload("res://scripts/city_ballistics.gd")
const Target = preload("res://scripts/city_target.gd")
const TEAM_ZONES: Array[Vector3] = [
	Vector3(-140, 0, -140), Vector3(-60, 0, 140), Vector3(100, 0, -100), Vector3(140, 0, 140),
	Vector3(378, 0, -196), Vector3(498, 0, 150),
]

signal alert(text: String)
signal shot(at: Vector3)
signal hit_confirmed(lethal: bool)

var _events: Events
var player: Player
var _elapsed := 0.0
var _ground_time := 0.0
var _teammates: Array[Actor] = []
var _drop_allies: Array[Target] = []
var _canopies: Array[Node3D] = []
var _zones: Array[Vector3] = []
var _guards: Array[Target] = []
var ballistics := Ballistics.new()
var _shooter: Target
var _aim_time := 0.0
var _cooldown := 1.0
var _pressure := 0
var _sweep := 0.0
var _volley := 0.0
var _rng := RandomNumberGenerator.new()
var _patrols: Array[Target] = []
var _patrol_timer: Dictionary = {}
var _cinematic := false


func set_cinematic(value: bool) -> void:
	_cinematic = value
	ballistics.active = not value
	if value:
		ballistics.clear_projectiles()


func set_pressure(level: int) -> void:
	_pressure = level
	_sweep = 0.4
	_volley = 1.8
	alert.emit("Police reinforcements inbound")


func fire_from_cruiser(at: Vector3) -> void:
	if not _cinematic and player.damage.alive:
		ballistics.fire_hostile(at, _target_point() + Vector3(0, _rng.randf_range(0.0, 0.3), _rng.randf_range(-0.9, 0.9)))


func build(target: Player, use_drop_allies: bool) -> void:
	player = target
	_events = get_node("/root/CityEvents") as Events
	_events.police_called.connect(_respond_to_report)
	add_child(ballistics)
	ballistics.bind_player(player)
	ballistics.hit_confirmed.connect(hit_confirmed.emit)
	ballistics.shot.connect(_on_shot)
	var zones := TEAM_ZONES.duplicate()
	zones.shuffle()
	for index in (2 if use_drop_allies else 0):
		var destination: Vector3 = zones[index]
		if destination.x > 175.0:
			destination.y = Region.height_at(destination.x, destination.z)
		_zones.append(destination)
		var ally := Target.new()
		add_child(ally)
		var teammate := Actor.new()
		ally.add_child(teammate)
		teammate.build(Actor.Role.DRIVER if index == 0 else Actor.Role.PRINCESS,
			Color("#bd773b") if index == 0 else Color("#c464ae"))
		ally.bind(teammate, Target.ALLY, Vector3(0.9, 2.2, 0.8))
		_drop_allies.append(ally)
		_teammates.append(teammate)
		_canopies.append(_make_canopy(teammate, index))
	for point in [Vector3(5.1, 0, -31), Vector3(-5.1, 0, 44), Vector3(-85.3, 0, 0)]:
		_add_guard(point)
		_add_guard(point + Vector3.RIGHT * Region.CITY_DISTANCE)
	_add_guard(Vector3(1130, 0, 7.8))
	_add_guard(Vector3(1760, 0, -8.1))


func _respond_to_report(at: Vector3) -> void:
	if _guards.size() >= 11 or not player.damage.alive:
		return
	var dispatch := create_tween()
	dispatch.tween_interval(2.5)
	await dispatch.finished
	if not player.damage.alive or _cinematic or _guards.size() >= 11:
		return
	var z := clampf(at.z + (26.0 if at.z < 110.0 else -26.0), -145.0, 145.0)
	_add_guard(Vector3(snappedf(at.x, 40.0) + 4.5, 0.05, z))
	alert.emit("Police responding · stay out of sight")


func _physics_process(delta: float) -> void:
	if not player.damage.alive:
		return
	_elapsed += delta
	_move_teammates()
	if player.phase != Player.Phase.GROUND:
		return
	_ground_time += delta
	if _ground_time > 2.5:
		_aim_guard(delta)
	if _pressure > 0:
		_update_patrols(delta)


func _move_teammates() -> void:
	for index in _teammates.size():
		var actor := _teammates[index]
		var start := Vector3(-3.0 if index == 0 else 3.0, Player.DROP_HEIGHT - 4.0, 5.0)
		var destination := _zones[index]
		var duration := 30.0 + Vector2(destination.x, destination.z).length() * 0.027
		var t := minf(_elapsed / duration, 1.0)
		var radial := -36.0 if index == 0 else 36.0
		_drop_allies[index].position = start.lerp(destination, t) + Vector3(radial, -78.0, 37.0) * sin(t * PI)
		actor.face(Vector3.FORWARD)
		actor.rotation.x = -0.85 if _elapsed < 6.0 else 0.0
		_canopies[index].visible = _elapsed >= 6.0 and t < 1.0


func dismiss_drop_allies() -> void:
	for ally in _drop_allies:
		ally.set_targetable(false)
		ally.queue_free()
	_drop_allies.clear()
	_teammates.clear()
	_canopies.clear()
	_zones.clear()


func _make_canopy(actor: Actor, index: int) -> Node3D:
	var canopy := Node3D.new()
	actor.add_child(canopy)
	canopy.position.y = 2.1
	var dome := SphereMesh.new()
	dome.is_hemisphere = true
	dome.radial_segments = 12
	dome.rings = 5
	Shapes.attach(canopy, dome, Vector3.UP * 2.4,
		Color("#eeae63") if index == 0 else Color("#e294c5")).scale = Vector3(6.0, 2.6, 5.0)
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			var tip := Vector3(side * 2.1, 2.4, depth * 1.45)
			Shapes.box(canopy, Vector3(0.027, 0.027, tip.length()), tip * 0.5, Color.WHITE).basis = Basis.looking_at(tip)
	return canopy


func _add_guard(point: Vector3) -> Target:
	var guard := Target.new()
	add_child(guard)
	guard.position = point
	var actor := Actor.new()
	guard.add_child(actor)
	actor.build(Actor.Role.DRIVER, Color("#4e3a59"))
	guard.bind(actor, Target.HOSTILE, Vector3(0.9, 2.2, 0.8))
	guard.health.hit.connect(_react_to_hit.bind(guard))
	guard.health.died.connect(_drop_guard.bind(guard))
	_guards.append(guard)
	return guard


func _on_shot(at: Vector3) -> void:
	shot.emit(at)
	_events.hazard.emit(at, 48.0)


func _react_to_hit(_at: Vector3, _impulse: Vector3, guard: Target) -> void:
	if _shooter == guard:
		_aim_time += 0.40


func _drop_guard(_at: Vector3, _impulse: Vector3, guard: Target) -> void:
	_guards.erase(guard)
	_patrols.erase(guard)
	_patrol_timer.erase(guard)
	if _pressure > 0:
		player.damage.heal(7.0)
	if _shooter == guard:
		_shooter = null
		_cooldown = 1.55
	guard.actor.lower_weapon()
	alert.emit("Pursuer down")


func _update_patrols(delta: float) -> void:
	_sweep -= delta
	_volley -= delta
	var center := player.global_position
	for index in range(_patrols.size() - 1, -1, -1):
		var officer := _patrols[index]
		var offset := center - officer.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 115.0:
			_patrols.remove_at(index)
			_guards.erase(officer)
			_patrol_timer.erase(officer)
			officer.queue_free()
			continue
		var actor := officer.actor
		if distance > 13.0 and distance < 69.0:
			var step := offset.normalized() * delta * 5.4
			var chest := officer.global_position + Vector3.UP
			if ballistics.cast(chest, chest + step * 9.0, Player.WORLD_LAYER | Player.VEHICLE_LAYER).is_empty():
				var next := officer.global_position + step
				var floor_hit := ballistics.cast(next + Vector3.UP * 0.8, next - Vector3.UP * 1.35, Player.WORLD_LAYER)
				if not floor_hit.is_empty() and floor_hit.normal.y > 0.6:
					officer.global_position = floor_hit.position
					actor.face(offset)
					actor.stride(_elapsed * 5.4 + index, true)
		var ready: float = _patrol_timer[officer]
		if distance < 48.0 and _sees_player(officer):
			actor.aim(officer.to_local(center))
			ready -= delta
			if ready <= 0.0 and _volley <= 0.0:
				var spread := Vector3(_rng.randf_range(-1.25, 1.25), _rng.randf_range(-0.18, 0.5), _rng.randf_range(-1.25, 1.25))
				ballistics.fire_hostile(actor.muzzle.global_position, _target_point() + spread)
				_volley = 0.31
				ready = _rng.randf_range(1.45, 2.6)
		else:
			actor.lower_weapon()
			ready = maxf(ready, 0.72)
		_patrol_timer[officer] = ready
	if _sweep > 0.0:
		return
	_sweep = 2.6
	var capacity := [0, 7, 13, 19][_pressure] as int
	for index in mini(capacity - _patrols.size(), 5):
		_spawn_patrol(center, index)


func _spawn_patrol(center: Vector3, index: int) -> void:
	for attempt in 6:
		var angle := index * TAU / 5.0 + _rng.randf_range(-0.52, 0.52)
		var ring := Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(18.0, 39.0)
		var spot := center + ring
		var ground := ballistics.cast(spot + Vector3.UP * 4.0, spot - Vector3.UP * 7.0, Player.WORLD_LAYER)
		if ground.is_empty() or ground.normal.y < 0.73 or absf(ground.position.y - center.y) > 2.8:
			continue
		var officer := _add_guard(ground.position)
		_patrols.append(officer)
		_patrol_timer[officer] = _rng.randf_range(1.25, 2.4)
		return


func _aim_guard(delta: float) -> void:
	_cooldown -= delta
	if not is_instance_valid(_shooter):
		if _cooldown > 0.0:
			return
		for guard in _guards:
			if guard not in _patrols and guard.position.distance_to(player.position) < 43.0 and _sees_player(guard):
				_shooter = guard
				_aim_time = 1.55
				alert.emit("Pursuer aiming · move behind cover")
				break
		return
	var actor := _shooter.actor
	actor.aim(_shooter.to_local(player.global_position))
	_aim_time -= delta
	if _aim_time > 0.0:
		return
	if _sees_player(_shooter):
		var start := actor.muzzle.global_position
		var target := _target_point()
		ballistics.fire_hostile(start, target)
	actor.lower_weapon()
	_shooter = null
	_cooldown = 2.2


func _sees_player(guard: Target) -> bool:
	var from := guard.global_position + Vector3.UP * 1.54
	var target: Node = player.camera.get_parent() if player.mounted else player
	return ballistics.cast(from, _target_point(), Ballistics.COVER_MASK | Player.PLAYER_LAYER | Target.ALLY).get("collider") == target


func _target_point() -> Vector3:
	return player.global_position + Vector3.UP * (0.38 if player.mounted else 1.15)
