extends Node3D

const Actor = preload("res://scripts/finale_actor.gd")
const Player = preload("res://scripts/skydive_player.gd")
const Region = preload("res://scripts/region_terrain.gd")
const Signals = preload("res://scripts/city_signals.gd")
const Events = preload("res://scripts/city_events.gd")
const Vehicle = preload("res://scripts/street_vehicle.gd")
const Places = preload("res://scripts/city_places.gd")
const Shapes = preload("res://scripts/vehicle_visual.gd")
const Target = preload("res://scripts/city_target.gd")
const TINTS: Array[Color] = [Color("#b9836d"), Color("#628b8c"), Color("#a39bb4"), Color("#7c9874"), Color("#c6a072")]
signal shout

enum State { WALK, CROSSING_WAIT, BENCH, BUS_WAIT, BUS_RIDE, VENUE_APPROACH, INSIDE, TERRACE, CHAT, PANIC, CALLING }

class Walker:
	var body: Target
	var actor: Actor
	var agent: NavigationAgent3D
	var goal: Vector3
	var wait := 0.0
	var panic := 0.0
	var panic_from: Vector3
	var idle_mode := 0
	var boarded := false
	var walk_phase := 0.0
	var bench := Vector3.INF
	var boarding_tween: Tween
	var venue_tween: Tween
	var dead := false
	var state: State = State.WALK
	var venue: Places.Venue
	var prop: MeshInstance3D
	var active := true

var _events: Events
var player: Player
var signals: Signals
var places: Places
var _walkers: Array[Walker] = []
var _passengers: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _look_timer := 0.0
var _warmup := 0.1
var _targeted: Walker
var _shout_delay := 0.0
var _cell_timer := 0.0
var _report_delay := 0.0
var _cells: Dictionary = {}


func build(target: Player, junctions: Signals, destinations: Places) -> void:
	player = target
	_events = get_node("/root/CityEvents") as Events
	signals = junctions
	places = destinations
	_rng.seed = 8303
	_events.hazard.connect(_panic_near)
	for city in [0.0, Region.CITY_DISTANCE]:
		_navigation(city)
		for index in 144:
			var side := 6.55 if index % 2 == 0 else -6.55
			var road_x := float(index % 7 - 3) * 40.0 + side
			var road_z := float((index * 3 + floori(index / 7.0)) % 7 - 3) * 40.0 + _rng.randf_range(-16.0, 16.0)
			_add_walker(Vector3(city + road_x, 0.10, road_z), index)
		for stop in Signals.BUS_SHELTERS:
			for index in 3:
				var walker := _add_walker(Vector3(city, 0, 0) + stop + Vector3((index - 1) * 1.15, 0.03, 0.45), index)
				walker.idle_mode = 2
				walker.state = State.BUS_WAIT
				walker.wait = 22.0 + index * 3.0


func _navigation(city: float) -> void:
	var mesh := NavigationMesh.new()
	var vertices := PackedVector3Array()
	const SIDE := 129
	for z in SIDE:
		for x in SIDE:
			vertices.append(Vector3(city - 160.0 + x * 2.5, 0.10, -160.0 + z * 2.5))
	mesh.set_vertices(vertices)
	for z in SIDE - 1:
		for x in SIDE - 1:
			var local_x := (x + 0.5) * 2.5
			var local_z := (z + 0.5) * 2.5
			var dx := absf(local_x - snappedf(local_x, 40.0))
			var dz := absf(local_z - snappedf(local_z, 40.0))
			if (dx < 5.0 or dx >= 7.5) and (dz < 5.0 or dz >= 7.5):
				continue
			var at := z * SIDE + x
			mesh.add_polygon(PackedInt32Array([at, at + 1, at + SIDE + 1, at + SIDE]))
	var region := NavigationRegion3D.new()
	region.navigation_mesh = mesh
	add_child(region)


func _add_walker(point: Vector3, index: int) -> Walker:
	var walker := Walker.new()
	walker.body = Target.new()
	add_child(walker.body)
	walker.body.position = point
	walker.actor = Actor.new()
	walker.body.add_child(walker.actor)
	walker.actor.build(Actor.Role.DRIVER, TINTS[index % TINTS.size()])
	walker.actor.scale = Vector3.ONE * _rng.randf_range(0.83, 0.99)
	for mesh: MeshInstance3D in walker.actor.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = 114.0
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow := Shapes.box(walker.actor, Vector3(0.72, 1.79, 0.47), Vector3.UP * 0.99, Color.WHITE)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow.visibility_range_end = 62.0
	walker.body.bind(walker.actor, Target.CIVILIAN, Vector3(0.65, 1.78, 0.56))
	walker.body.health.died.connect(_remove_walker.bind(walker))
	walker.agent = NavigationAgent3D.new()
	walker.agent.path_desired_distance = 0.66
	walker.agent.target_desired_distance = 0.85
	walker.body.add_child(walker.agent)
	walker.goal = point
	walker.idle_mode = 1 if index % 11 == 0 else 0
	_walkers.append(walker)
	return walker


func _remove_walker(_at: Vector3, _impulse: Vector3, walker: Walker) -> void:
	walker.dead = true
	for motion: Tween in [walker.boarding_tween, walker.venue_tween]:
		if is_instance_valid(motion):
			motion.kill()
	for passengers: Array in _passengers.values():
		passengers.erase(walker)
	if _targeted == walker:
		_targeted = null
	_walkers.erase(walker)


func _physics_process(delta: float) -> void:
	_shout_delay = maxf(0.0, _shout_delay - delta)
	_warmup -= delta
	if _warmup > 0.0:
		return
	_look_timer -= delta
	_report_delay = maxf(0.0, _report_delay - delta)
	_cell_timer -= delta
	if _cell_timer <= 0.0:
		_cell_timer = 0.14
		_index_active()
	if _look_timer <= 0.0:
		_look_timer = 0.30
		_check_aim()
	for walker in _walkers:
		if walker.boarded or not walker.active:
			continue
		_advance(walker, delta)


func _index_active() -> void:
	_cells.clear()
	var center := Vector2(player.position.x, player.position.z)
	for walker in _walkers:
		if walker.boarded:
			continue
		var point := walker.body.position
		var active := Vector2(point.x, point.z).distance_squared_to(center) < 152.0 * 152.0
		if active != walker.active:
			walker.active = active
			walker.body.visible = active
			walker.body.set_targetable(active)
		if active:
			var cell := _cell(point)
			if not _cells.has(cell):
				_cells[cell] = []
			_cells[cell].append(walker)


func _cell(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / 12.0), floori(at.z / 12.0))


func _advance(walker: Walker, delta: float) -> void:
	if walker.state == State.INSIDE:
		return
	var point := walker.body.position
	walker.panic = maxf(0.0, walker.panic - delta)
	if walker.wait > 0.0:
		walker.wait -= delta
		if walker.state == State.TERRACE:
			walker.actor.right_arm.rotation.x = 0.67 + sin(walker.wait * 2.2) * 0.50
		return
	if walker.state == State.CALLING:
		_events.police_called.emit(walker.body.position)
		walker.actor.right_arm.rotation.x = 0.0
		_choose_goal(walker)
		return
	if walker.state == State.CHAT:
		walker.state = State.WALK
		walker.actor.right_arm.rotation.x = 0.0
	if point.distance_squared_to(walker.goal) < 1.7 or walker.agent.is_navigation_finished():
		if walker.state == State.VENUE_APPROACH and walker.venue and point.distance_squared_to(walker.goal) < 7.0:
			_arrive_at_venue(walker)
			return
		_choose_goal(walker)
		return
	var next := walker.agent.get_next_path_position()
	var motion := Vector3(next.x - point.x, 0.0, next.z - point.z)
	if motion.length_squared() < 0.002:
		return
	var forward := motion.normalized()
	var road_x := snappedf(point.x, 40.0)
	var road_z := snappedf(point.z, 40.0)
	var entering_x := absf(point.x - road_x) >= 5.0 and absf(point.x + forward.x * 0.85 - road_x) < 5.0
	var entering_z := absf(point.z - road_z) >= 5.0 and absf(point.z + forward.z * 0.85 - road_z) < 5.0
	if walker.panic <= 0.0 and (entering_x or entering_z) and signals.phase(Vector3(road_x, 0, road_z)) != 2:
		if walker.state == State.WALK:
			walker.state = State.CROSSING_WAIT
		return
	if walker.state == State.CROSSING_WAIT:
		walker.state = State.WALK
	var pace := 5.4 if walker.panic > 0.0 else 1.8
	walker.body.position += forward * minf(motion.length(), pace * delta)
	walker.actor.face(forward)
	walker.walk_phase += delta * pace
	walker.actor.stride(walker.walk_phase, walker.panic > 0.0)


func _choose_goal(walker: Walker) -> void:
	var point := walker.body.position
	var origin := Region.CITY_DISTANCE if point.x > Region.CITY_DISTANCE * 0.5 else 0.0
	if walker.idle_mode == 2 and walker.panic <= 0.0:
		walker.state = State.BUS_WAIT
		walker.wait = 5.0
		return
	_clear_prop(walker)
	walker.actor.stand_pose()
	walker.state = State.PANIC if walker.panic > 0.0 else State.WALK
	if walker.idle_mode == 1 and walker.panic <= 0.0:
		if walker.bench != Vector3.INF and point.distance_squared_to(walker.bench) < 2.1:
			walker.body.position = walker.bench
			walker.bench = Vector3.INF
			walker.wait = 4.0
			walker.state = State.BENCH
			walker.actor.rotation.y = 0.0
			walker.actor.sit_pose()
			walker.prop = Shapes.box(walker.actor.right_arm, Vector3(0.18, 0.08, 0.26), Vector3(0.03, -0.48, -0.11), Color("#e4d9ba"))
			return
		if _rng.randf() < 0.25:
			var block_x := clampf(floorf((point.x - origin) / 40.0), -4.0, 3.0) * 40.0
			var block_z := clampf(floorf(point.z / 40.0), -4.0, 3.0) * 40.0
			walker.bench = Vector3(origin + block_x + 11.0, 0.03, block_z + 6.85)
			walker.goal = walker.bench
			walker.agent.target_position = walker.goal
			return
	var venue := places.nearest(point)
	if venue and ((walker.panic <= 0.0 and _rng.randf() < 0.15) or (walker.panic > 0.0 and _rng.randf() < 0.34)):
		walker.venue = venue
		walker.state = State.VENUE_APPROACH
		walker.goal = venue.approach
		walker.agent.target_position = walker.goal
		return
	if walker.panic <= 0.0 and _rng.randf() < 0.09:
		for partner: Walker in _cells.get(_cell(point), []):
			if partner != walker and partner.state == State.WALK and partner.panic <= 0.0 and partner.body.position.distance_squared_to(point) < 11.0:
				walker.state = State.CHAT
				partner.state = State.CHAT
				walker.wait = 2.5
				partner.wait = 2.5
				walker.actor.face(partner.body.position - point)
				partner.actor.face(point - partner.body.position)
				walker.actor.right_arm.rotation.x = 0.67
				return
	var destination := point + Vector3(_rng.randf_range(-58, 58), 0, _rng.randf_range(-58, 58))
	if walker.panic > 0.0:
		var away := point - walker.panic_from
		away.y = 0.0
		destination = point + away.normalized() * 58.0 + Vector3(_rng.randf_range(-7, 7), 0, _rng.randf_range(-7, 7))
	var x := clampf(snappedf(destination.x - origin, 40.0) + 6.3, -153.7, 153.7)
	var z := clampf(destination.z, -152.0, 152.0)
	walker.goal = Vector3(origin + x, 0.10, z)
	walker.agent.target_position = walker.goal


func _arrive_at_venue(walker: Walker) -> void:
	var venue := walker.venue
	if venue.cafe and walker.panic <= 0.0 and _rng.randf() < 0.50:
		walker.body.position = venue.terrace + Vector3(0, 0, 0.71)
		walker.actor.rotation.y = 0.0
		walker.actor.sit_pose()
		walker.state = State.TERRACE
		walker.wait = 5.5
		walker.prop = Shapes.box(walker.actor.right_arm, Vector3(0.11, 0.14, 0.11), Vector3(0.02, -0.52, -0.10), Color("#eee6ca"))
		return
	walker.state = State.INSIDE
	walker.actor.face(Vector3.FORWARD)
	venue.door.open_for(10.0)
	var visit := create_tween()
	walker.venue_tween = visit
	visit.tween_property(walker.body, "position", venue.threshold, 0.84)
	visit.tween_property(walker.body, "position", venue.inside, 1.02)
	visit.tween_interval(4.0 if walker.panic > 0.0 else 2.7)
	visit.tween_callback(walker.actor.face.bind(Vector3.BACK))
	visit.tween_property(walker.body, "position", venue.threshold, 0.9)
	visit.tween_property(walker.body, "position", venue.approach, 0.84)
	await visit.finished
	walker.panic = 0.0
	_choose_goal(walker)


func _clear_prop(walker: Walker) -> void:
	if is_instance_valid(walker.prop):
		walker.prop.queue_free()
		walker.prop = null
	walker.actor.right_arm.rotation.x = 0.0


func crossing_ahead(at: Vector3, forward: Vector3, length: float) -> bool:
	var cell := _cell(at)
	for x in range(-1, 2):
		for z in range(-1, 2):
			for walker: Walker in _cells.get(cell + Vector2i(x, z), []):
				if walker.boarded or walker.dead:
					continue
				var offset := walker.body.position - at
				var ahead := offset.dot(forward)
				if ahead > 0.0 and ahead < length * 0.5 + 5.5 and absf(offset.cross(forward).y) < 1.38:
					return true
	return false


func _panic_near(at: Vector3, radius: float) -> void:
	for walker in _walkers:
		if not walker.boarded and walker.body.position.distance_squared_to(at) < radius * radius:
			_start_panic(walker, at)


func _start_panic(walker: Walker, at: Vector3) -> void:
	if walker.state == State.INSIDE or walker.state == State.CALLING:
		return
	if walker.panic <= 0.0 and _shout_delay <= 0.0 and walker.body.position.distance_squared_to(player.position) < 625.0:
		_shout_delay = 2.8
		shout.emit()
	walker.panic = 6.5
	walker.panic_from = at
	walker.wait = 0.0
	walker.bench = Vector3.INF
	if _report_delay <= 0.0 and walker.body.position.distance_squared_to(player.position) < 1000.0 and _rng.randf() < 0.12:
		_report_delay = 34.0
		_clear_prop(walker)
		walker.actor.stand_pose()
		walker.actor.right_arm.rotation.x = 2.15
		walker.prop = Shapes.box(walker.actor.right_arm, Vector3(0.09, 0.14, 0.04), Vector3(0.0, -0.55, -0.13), Color("#3f4d55"))
		walker.state = State.CALLING
		walker.wait = 1.45
		return
	_choose_goal(walker)


func is_targeting_pedestrian() -> bool:
	return _targeted != null


func _check_aim() -> void:
	_targeted = null
	if player.phase != Player.Phase.GROUND or player.mounted:
		return
	var start := player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(start, start - player.camera.global_basis.z * 22.0,
		Target.PEOPLE | Player.WORLD_LAYER | Player.VEHICLE_LAYER)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	for walker in _walkers:
		if not walker.boarded and walker.body == hit.collider:
			_targeted = walker
			if walker.panic <= 0.0:
				_start_panic(walker, player.global_position)
			return


func bus_arrived(bus: Vehicle) -> void:
	_bus_alight(bus)
	var drop := bus.to_global(Vector3(1.65, 0.04, -2.2))
	var boarding: Array[Walker] = []
	for walker in _walkers:
		if walker.idle_mode == 2 and not walker.boarded and walker.panic <= 0.0 and walker.body.position.distance_squared_to(drop) < 54.0:
			walker.boarded = true
			walker.state = State.BUS_RIDE
			walker.actor.face((drop - walker.body.position).normalized())
			var board := create_tween()
			walker.boarding_tween = board
			board.tween_property(walker.body, "global_position", drop, 0.74).set_delay(1.10 + boarding.size() * 0.45)
			board.tween_property(walker.body, "global_position", bus.to_global(Vector3(0.55, 0.05, -2.2)), 0.45)
			board.tween_callback(walker.body.hide)
			board.tween_callback(walker.body.set_targetable.bind(false))
			boarding.append(walker)
			if boarding.size() == 2:
				break
	_passengers[bus] = boarding


func _bus_alight(bus: Vehicle) -> void:
	var drop := bus.to_global(Vector3(1.65, 0.04, -2.2))
	var previous: Array = _passengers.get(bus, [])
	_passengers.erase(bus)
	for walker: Walker in previous:
		if is_instance_valid(walker.boarding_tween):
			walker.boarding_tween.kill()
		walker.boarded = false
		walker.state = State.WALK
		walker.body.set_targetable(true)
		walker.body.position = bus.to_global(Vector3(0.52, 0.05, -2.2))
		walker.body.show()
		walker.idle_mode = 0
		walker.wait = 1.10
		var exit := create_tween()
		walker.boarding_tween = exit
		exit.tween_property(walker.body, "global_position", drop, 0.6).set_delay(0.4)
