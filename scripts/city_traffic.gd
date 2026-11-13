extends Node3D

const Vehicle = preload("res://scripts/street_vehicle.gd")
const Player = preload("res://scripts/skydive_player.gd")
const Region = preload("res://scripts/region_terrain.gd")
const Events = preload("res://scripts/city_events.gd")
const Signals = preload("res://scripts/city_signals.gd")
const Target = preload("res://scripts/city_target.gd")
const Shapes = preload("res://scripts/vehicle_visual.gd")
const Actor = preload("res://scripts/finale_actor.gd")
const CRUISER_SPEED := 49.0
const DISPATCH_DISTANCE := 105.0
const CRUISER_LIMITS := [0, 3, 5, 8]
const REPORT_CRUISER_LIMIT := 3
const CRUISER_DISPATCH_INTERVAL := 2.0

signal horn
signal bus_arrived(bus: Vehicle)
signal bus_taken(bus: Vehicle)
signal engine_speed(kmh: float)
signal officer_exited(actor: Actor)
signal siren

var vehicles: Array[Vehicle] = []
var _events: Events
var player: Player
var signals := Signals.new()
var nearby: Vehicle
var driven: Vehicle
var crowd: Node3D
var _transition := false
var _skip_transition := false
var _transition_tween: Tween
var _ejected: Array[Target] = []
var _cells: Dictionary = {}
var cinematic := false
var _police_pressure := 0
var _report_time := 0.0
var _dispatch_delay := 0.0
var _police_routes: Array[Path3D] = []
class Cruiser:
	var red: MeshInstance3D
	var blue: MeshInstance3D
	var travel := 0.0
	var exit_time := 0.0
	var exit_start := Vector3.ZERO
	var exit_end := Vector3.ZERO


var _police: Array[Vehicle] = []
var _cruisers: Dictionary[Vehicle, Cruiser] = {}
var _siren_time := 0.0
var _siren_delay := 0.0


func set_pressure(level: int) -> void:
	_police_pressure = level
	_dispatch_delay = minf(_dispatch_delay, 0.5)


func build(target: Player) -> void:
	player = target
	_events = get_node("/root/CityEvents") as Events
	_events.police_called.connect(_report_crime)
	player.vehicle_requested.connect(_interact)
	add_child(signals)
	signals.build()
	for origin in [0.0, Region.CITY_DISTANCE]:
		for index in 4:
			var wide := 40.0 * minf(index + 1, 3.0)
			var deep := 80.0 if index == 2 else wide
			var points := [Vector3(origin - wide + 2.7, 0, -deep + 2.7), Vector3(origin + wide - 2.7, 0, -deep + 2.7),
				Vector3(origin + wide - 2.7, 0, deep - 2.7), Vector3(origin - wide + 2.7, 0, deep - 2.7),
				Vector3(origin - wide + 2.7, 0, -deep + 2.7)]
			var path := _route(points)
			_police_routes.append(path)
			for slot in 6:
				_add_vehicle(path, (index * 2 + slot) % 5, (slot + 0.5) / 6.0)
		var bus_path := _route([Vector3(origin - 77.2, 0, 2.8), Vector3(origin + 13, 0, 2.8),
			Vector3(origin + 19, 0, 4.35), Vector3(origin + 25, 0, 4.35), Vector3(origin + 32, 0, 2.8),
			Vector3(origin + 77.2, 0, 2.8), Vector3(origin + 77.2, 0, 37.2),
			Vector3(origin - 48, 0, 37.2), Vector3(origin - 55, 0, 35.65),
			Vector3(origin - 61, 0, 35.65), Vector3(origin - 69, 0, 37.2),
			Vector3(origin - 77.2, 0, 37.2), Vector3(origin - 77.2, 0, 2.8)])
		var bus := _add_vehicle(bus_path, 5, 0.12)
		bus.bus_stops = [Vector3(origin + 22, 0, 4.35), Vector3(origin - 58, 0, 35.65)]
		var second_bus := _add_vehicle(bus_path, 5, 0.62)
		second_bus.bus_stops = bus.bus_stops.duplicate()
		second_bus.next_stop = 1
	var interstate := _route([Vector3(-82.8, 0, 3.1), Vector3(Region.CITY_DISTANCE + 82.8, 0, 3.1),
		Vector3(Region.CITY_DISTANCE + 82.8, 0, -42.8), Vector3(Region.CITY_DISTANCE - 82.8, 0, -42.8),
		Vector3(Region.CITY_DISTANCE - 82.8, 0, -3.1), Vector3(-82.8, 0, -3.1),
		Vector3(-82.8, 0, 3.1)])
	_police_routes.append(interstate)
	for index in 18:
		var commuter := _add_vehicle(interstate, index % 5, (index + 0.5) / 18.0)
		commuter.cruise_speed += 9.0
	var outer := _route([Vector3(37.2, 0, 2.8), Vector3(173, 0, 2.8), Vector3(228, 0, 7.25),
		Vector3(2172, 0, 7.25), Vector3(2235, 0, 3.1), Vector3(Region.CITY_DISTANCE + 42.8, 0, 3.1),
		Vector3(Region.CITY_DISTANCE + 42.8, 0, -42.8), Vector3(Region.CITY_DISTANCE - 42.8, 0, -42.8),
		Vector3(Region.CITY_DISTANCE - 42.8, 0, -3.1), Vector3(2235, 0, -3.1), Vector3(2172, 0, -7.25),
		Vector3(228, 0, -7.25), Vector3(173, 0, -3.1), Vector3(37.2, 0, -3.1), Vector3(37.2, 0, 2.8)])
	_police_routes.append(outer)
	for index in 16:
		var commuter := _add_vehicle(outer, (index + 1) % 5, (index + 0.4) / 16.0)
		commuter.cruise_speed += 12.0


func _route(points: Array) -> Path3D:
	var path := Path3D.new()
	var curve := Curve3D.new()
	curve.bake_interval = 0.55
	for index in points.size():
		var point: Vector3 = points[index]
		if index == 0 or index == points.size() - 1:
			curve.add_point(point)
			continue
		var incoming: Vector3 = (points[index - 1] - point).normalized()
		var outgoing: Vector3 = (points[index + 1] - point).normalized()
		var radius := minf(3.5, minf(point.distance_to(points[index - 1]), point.distance_to(points[index + 1])) * 0.40)
		curve.add_point(point + incoming * radius, Vector3.ZERO, -incoming * radius * 0.48)
		curve.add_point(point + outgoing * radius, -outgoing * radius * 0.48, Vector3.ZERO)
	if points.front() != points.back():
		curve.add_point(points.front())
	path.curve = curve
	add_child(path)
	return path


func _add_vehicle(path: Path3D, type: int, offset: float) -> Vehicle:
	var follower := PathFollow3D.new()
	follower.rotation_mode = PathFollow3D.ROTATION_NONE
	path.add_child(follower)
	follower.progress_ratio = offset
	var vehicle := Vehicle.new()
	add_child(vehicle)
	var colors: Array[Color] = [Color("#ba714f"), Color("#708d9c"), Color("#ccaa61"), Color("#b2aaa0"), Color("#71947e"), Color("#5395a1")]
	vehicle.build(type, colors[type])
	vehicle.route = follower
	vehicle.position = follower.position
	vehicle.speed = vehicle.cruise_speed
	var forward := path.curve.sample_baked(follower.progress + 0.8) - follower.position
	vehicle.rotation.y = atan2(-forward.x, -forward.z)
	vehicle.impact.body_entered.connect(_impact.bind(vehicle))
	vehicles.append(vehicle)
	return vehicle


func park_vehicle(type: int, paint: Color, at: Vector3, heading: float) -> Vehicle:
	var vehicle := Vehicle.new()
	add_child(vehicle)
	vehicle.build(type, paint)
	vehicle.position = at
	vehicle.rotation.y = heading
	vehicles.append(vehicle)
	return vehicle


func _physics_process(delta: float) -> void:
	if not player.damage.alive:
		return
	_update_nearby()
	_index_vehicles()
	if not cinematic and player.phase == Player.Phase.GROUND:
		_update_pursuit(delta)
	for vehicle in vehicles:
		if vehicle == driven:
			if not _transition and not cinematic:
				var collision := vehicle.drive(delta)
				engine_speed.emit(absf(vehicle.speed) * 3.6)
				player.position = vehicle.position + Vector3.UP * 0.52
				if collision > 5.0:
					_events.hazard.emit(vehicle.global_position, 48.0)
				if collision > 8.0:
					player.camera.bump(clampf(collision / 22.0, 0.35, 1.0))
				player.camera.animate_driving(delta)
			continue
		if not is_instance_valid(vehicle.route):
			continue
		vehicle.follow_route(delta, _target_speed(vehicle, delta))
		if not player.mounted and vehicle.position.distance_squared_to(player.position) < 144.0 and vehicle.impact.overlaps_body(player):
			_impact(player, vehicle)
	for index in range(_ejected.size() - 1, -1, -1):
		var target := _ejected[index]
		if not is_instance_valid(target):
			_ejected.remove_at(index)
			continue
		target.position += -target.actor.basis.z * 5.4 * delta
		target.actor.stride(Time.get_ticks_msec() * 0.0054, true)
		if target.position.distance_squared_to(player.position) > 95.0 * 95.0:
			_ejected.remove_at(index)
			target.queue_free()


func _index_vehicles() -> void:
	_cells.clear()
	for vehicle in vehicles:
		var cell := _cell(vehicle.position)
		if not _cells.has(cell):
			_cells[cell] = []
		_cells[cell].append(vehicle)


func _cell(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / 40.0), floori(at.z / 40.0))


func _target_speed(vehicle: Vehicle, delta: float) -> float:
	vehicle.stop_cooldown -= delta
	if vehicle.dwell > 0.0:
		vehicle.dwell -= delta
		if vehicle.dwell <= 0.0:
			create_tween().tween_property(vehicle.passenger_door, "rotation:y", 0.0, 0.35)
			vehicle.next_stop = (vehicle.next_stop + 1) % vehicle.bus_stops.size()
		return 0.0
	if not vehicle.bus_stops.is_empty() and vehicle.stop_cooldown <= 0.0 and vehicle.position.distance_squared_to(vehicle.bus_stops[vehicle.next_stop]) < 16.0:
		if vehicle.speed < 0.55:
			vehicle.dwell = 4.5
			vehicle.stop_cooldown = 7.0
			create_tween().tween_property(vehicle.passenger_door, "rotation:y", 1.28, 0.45)
			bus_arrived.emit(vehicle)
		return 0.0
	var forward := -vehicle.basis.z
	var desired := 0.0 if signals.red_ahead(vehicle.position, forward, vehicle.speed) else vehicle.cruise_speed
	if is_instance_valid(crowd) and crowd.crossing_ahead(vehicle.position, forward, vehicle.length):
		desired = 0.0
	var cell := _cell(vehicle.position)
	var lookahead := clampf(vehicle.speed * vehicle.speed / 20.0 + 3.1, 17.5, 34.0)
	for x in range(-1, 2):
		for z in range(-1, 2):
			for other: Vehicle in _cells.get(cell + Vector2i(x, z), []):
				if other == vehicle:
					continue
				var offset := other.position - vehicle.position
				var distance := offset.dot(forward)
				var gap := distance - (vehicle.length + other.length) * 0.5
				if distance > 0.0 and gap < lookahead and absf(offset.cross(forward).y) < 1.86 and absf(offset.y) < 1.6:
					var same_direction := maxf(0.0, forward.dot(-other.basis.z))
					var lead_speed := other.speed * same_direction
					var braking_speed := sqrt(maxf(0.0, lead_speed * lead_speed + (gap - 2.5) * 18.0))
					var following_speed := maxf(0.0, lead_speed + (gap - 3.1) * 1.38)
					desired = minf(desired, minf(braking_speed, following_speed))
	if desired < 0.5 and vehicle.speed < 0.5:
		vehicle.blocked_time += delta
		if vehicle.blocked_time > 6.0:
			vehicle.blocked_time = 0.0
			if vehicle.position.distance_squared_to(player.position) < 2500.0:
				horn.emit()
	else:
		vehicle.blocked_time = 0.0
	return desired


func _update_nearby() -> void:
	nearby = null
	if player.mounted or player.phase != Player.Phase.GROUND:
		return
	var nearest := 3.2 * 3.2
	for vehicle in vehicles:
		if vehicle in _cruisers and is_instance_valid(vehicle.driver):
			continue
		var distance := vehicle.door.global_position.distance_squared_to(player.global_position + Vector3.UP * 0.55)
		if distance < nearest:
			nearest = distance
			nearby = vehicle


func _impact(body: Node3D, vehicle: Vehicle) -> void:
	if not cinematic and body == player and player.damage.alive and not player.mounted and absf(vehicle.speed) > 15.0 / 3.6:
		var away := player.global_position - vehicle.global_position
		away.y = 0.0
		var forward := -vehicle.global_basis.z * signf(vehicle.speed)
		var direction := (away.normalized() + forward * 0.45).normalized()
		if player.struck_by_vehicle(direction, absf(vehicle.speed)):
			_events.hazard.emit(vehicle.global_position, 50.0)


func _report_crime(_at: Vector3) -> void:
	if _report_time <= 0.0:
		_dispatch_delay = maxf(_dispatch_delay, 2.5)
	_report_time = 35.0


func _update_pursuit(delta: float) -> void:
	_siren_time += delta
	_siren_delay -= delta
	_dispatch_delay -= delta
	_report_time = maxf(0.0, _report_time - delta)
	var limit := maxi(CRUISER_LIMITS[_police_pressure], REPORT_CRUISER_LIMIT if _report_time > 0.0 else 0)
	if limit > 0 and _police.size() < limit and _dispatch_delay <= 0.0:
		_dispatch_delay = CRUISER_DISPATCH_INTERVAL if _dispatch_cruiser() else 1.0
	for index in range(_police.size() - 1, -1, -1):
		var unit := _police[index]
		if unit == driven:
			_police.remove_at(index)
			_cruisers.erase(unit)
			continue
		var distance := unit.position.distance_to(player.position)
		var abandoned := not is_instance_valid(unit.driver) and distance > 150.0
		if distance > 360.0 or (abandoned and not player.camera.is_position_in_frustum(unit.position + Vector3.UP)):
			_police.remove_at(index)
			_cruisers.erase(unit)
			vehicles.erase(unit)
			unit.queue_free()
			continue
		var patrol: Cruiser = _cruisers[unit]
		var red := fmod(_siren_time * 4.0 + index * 0.33, 1.0) < 0.5
		patrol.red.visible = red
		patrol.blue.visible = not red
		if distance < 70.0 and _siren_delay <= 0.0:
			siren.emit()
			_siren_delay = 4.2
		if patrol.exit_time > 0.0 and is_instance_valid(unit.driver):
			_update_officer_exit(unit, patrol, delta)
		elif is_instance_valid(unit.driver):
			_drive_cruiser(unit, patrol, delta)


func _dispatch_cruiser() -> bool:
	var center := player.position
	var heading := -player.camera.global_basis.z
	if is_instance_valid(driven) and absf(driven.speed) > 2.0:
		heading = -driven.basis.z * signf(driven.speed)
	heading.y = 0.0
	heading = heading.normalized()
	var best := INF
	var spawn := Vector3.ZERO
	var direction := Vector3.ZERO
	for path in _police_routes:
		var length := path.curve.get_baked_length()
		var closest := path.curve.get_closest_offset(center)
		for gap in [-310.0, -230.0, -165.0, -115.0, 115.0, 165.0, 230.0, 310.0]:
			var progress := fposmod(closest + gap, length)
			var point := path.curve.sample_baked(progress)
			var offset := point - center
			var distance := offset.length()
			if distance < DISPATCH_DISTANCE or distance > 335.0:
				continue
			var forward := point.direction_to(path.curve.sample_baked(fposmod(progress + 2.0, length)))
			var score := absf(distance - 125.0) + maxf(0.0, offset.dot(heading)) * 1.5
			if score >= best or not _road_spawn_clear(point):
				continue
			best = score
			spawn = point
			direction = forward
	if best == INF:
		return false
	var unit := park_vehicle(1, Color("#d6e4ed"), spawn + Vector3.UP * 0.05, atan2(-direction.x, -direction.z))
	unit.speed = 16.0
	unit.driver.show()
	unit.driver.sit_pose()
	var patrol := Cruiser.new()
	patrol.red = Shapes.box(unit, Vector3(0.42, 0.16, 0.21), Vector3(-0.26, 1.78, 0.08), Color("#ff4359"))
	patrol.blue = Shapes.box(unit, Vector3(0.42, 0.16, 0.21), Vector3(0.26, 1.78, 0.08), Color("#4689ff"))
	_cruisers[unit] = patrol
	_police.append(unit)
	return true


func _road_spawn_clear(point: Vector3) -> bool:
	var cell := _cell(point)
	for x in range(-1, 2):
		for z in range(-1, 2):
			for vehicle: Vehicle in _cells.get(cell + Vector2i(x, z), []):
				if vehicle.position.distance_squared_to(point) < 64.0:
					return false
	if player.camera.is_position_in_frustum(point + Vector3.UP) and point.distance_to(player.position) < 315.0:
		var view := PhysicsRayQueryParameters3D.create(player.camera.global_position, point + Vector3.UP, Player.WORLD_LAYER)
		if get_world_3d().direct_space_state.intersect_ray(view).is_empty():
			return false
	return true


func _drive_cruiser(unit: Vehicle, patrol: Cruiser, delta: float) -> void:
	var target := player.position
	var target_speed := absf(driven.speed) if is_instance_valid(driven) else 0.0
	var highway := unit.position.x > 165.0 and unit.position.x < Region.CITY_DISTANCE - 165.0
	if highway:
		target.z = clampf(target.z, -7.3, 7.3)
	var distance := unit.position.distance_to(target)
	var stopping := target_speed < 2.5 and distance < 21.0 and unit.position.distance_to(player.position) < 44.0 and patrol.travel > 35.0
	var waypoint := _cruiser_waypoint(unit, target, highway)
	var chase_speed := clampf(distance * 1.8 + target_speed, 8.0, CRUISER_SPEED)
	if highway and target_speed >= 2.5 and absf(driven.basis.z.x) > 0.65:
		var travel_sign := signf(-driven.basis.z.x * driven.speed)
		var gap := (target.x - unit.position.x) * travel_sign
		if gap >= -5.0 and (-unit.basis.z.x * travel_sign > 0.5 or gap > 12.0):
			waypoint = Vector3(unit.position.x + travel_sign * maxf(gap - 12.0, 18.0), 0, travel_sign * 7.2)
			chase_speed = clampf(target_speed + (gap - 12.0) * 1.2, 0.0, CRUISER_SPEED)
	var direction := waypoint - unit.position
	direction.y = 0.0
	var desired := 0.0
	if not stopping and direction.length_squared() > 0.25:
		var angle := atan2(-direction.x, -direction.z)
		var turn := absf(angle_difference(unit.rotation.y, angle))
		unit.rotation.y = rotate_toward(unit.rotation.y, angle, delta * (1.6 if highway else 2.2))
		desired = minf(chase_speed, lerpf(CRUISER_SPEED if highway else 30.0, 3.0, smoothstep(0.14, 1.2, turn)))
	unit.speed = move_toward(unit.speed, desired, delta * (23.0 if desired < unit.speed else 10.0))
	var before := unit.position
	unit.velocity = -unit.basis.z * unit.speed + Vector3.DOWN * 2.0
	unit.move_and_slide()
	var travel := Vector2(unit.position.x - before.x, unit.position.z - before.z).length()
	patrol.travel += travel
	unit._spin(travel)
	if unit.speed > 3.0 and travel < unit.speed * delta * 0.35:
		unit.speed *= 0.55
	if stopping and unit.speed < 0.6:
		_begin_officer_exit(unit, patrol)


func _cruiser_waypoint(unit: Vehicle, target: Vector3, highway: bool) -> Vector3:
	if highway:
		var offset := target.x - unit.position.x
		if absf(offset) > 16.0:
			return Vector3(target.x, 0.0, -7.2 if offset < 0.0 else 7.2)
		return target
	var city_x := Region.CITY_DISTANCE if unit.position.x > Region.CITY_DISTANCE * 0.5 else 0.0
	var local_x := unit.position.x - city_x
	var target_x := target.x - city_x
	if absf(target_x) > 170.0:
		target = Vector3(city_x + clampf(target_x, -185.0, 185.0), 0.0, 0.0)
	var street_x := city_x + clampf(snappedf(local_x, 40.0), -160.0, 160.0)
	var street_z := clampf(snappedf(unit.position.z, 40.0), -160.0, 160.0)
	var next_x := city_x + clampf(snappedf(target.x - city_x, 40.0), -160.0, 160.0)
	var next_z := clampf(snappedf(target.z, 40.0), -160.0, 160.0)
	if absf(unit.position.x - street_x) <= absf(unit.position.z - street_z):
		if absf(unit.position.z - next_z) > 3.0:
			return Vector3(street_x + (2.6 if next_z > unit.position.z else -2.6), 0, next_z)
	elif absf(unit.position.x - next_x) > 3.0:
		return Vector3(next_x, 0, street_z + (-2.6 if next_x > unit.position.x else 2.6))
	if absf(unit.position.x - next_x) > 3.0:
		return Vector3(next_x, 0, next_z)
	return Vector3(next_x, 0, next_z) if absf(target.x - next_x) > 5.5 and absf(target.z - next_z) > 5.5 else target


func _begin_officer_exit(unit: Vehicle, patrol: Cruiser) -> void:
	var step := unit.to_global(Vector3(-2.1, 0.0, unit.seat().z))
	var chest := step + Vector3.UP * 0.9
	var clearance := PhysicsRayQueryParameters3D.create(unit.global_position + Vector3.UP * 0.9, chest,
		Player.WORLD_LAYER | Vehicle.VEHICLE_LAYER, [unit.get_rid()])
	var space := get_world_3d().direct_space_state
	if not space.intersect_ray(clearance).is_empty():
		return
	var floor_query := PhysicsRayQueryParameters3D.create(chest, step - Vector3.UP * 0.65, Player.WORLD_LAYER)
	var floor_hit := space.intersect_ray(floor_query)
	if floor_hit.is_empty() or floor_hit.normal.y < 0.65:
		return
	patrol.exit_start = unit.driver.position
	patrol.exit_end = unit.to_local(floor_hit.position)
	patrol.exit_time = 0.01
	unit.speed = 0.0


func _update_officer_exit(unit: Vehicle, patrol: Cruiser, delta: float) -> void:
	patrol.exit_time += delta
	unit.door.rotation.y = -1.12 * smoothstep(0.0, 0.22, patrol.exit_time)
	var progress := smoothstep(0.20, 0.82, patrol.exit_time)
	unit.driver.face(patrol.exit_end)
	unit.driver.walk(progress, patrol.exit_start, patrol.exit_end)
	unit.driver.scale = Vector3.ONE * lerpf(0.68, 1.0, progress)
	if patrol.exit_time < 0.82:
		return
	var officer := unit.driver
	unit.driver = null
	if is_instance_valid(unit.driver_target):
		unit.driver_target.queue_free()
	unit.driver_target = null
	patrol.exit_time = 0.0
	officer_exited.emit(officer)
	create_tween().tween_property(unit.door, "rotation:y", 0.0, 0.30)


func _interact() -> void:
	if _transition or player.phase != Player.Phase.GROUND:
		return
	if is_instance_valid(driven):
		_exit_vehicle()
	elif is_instance_valid(nearby):
		_enter_vehicle(nearby)


func can_skip_transition() -> bool:
	return _transition and not _skip_transition and not cinematic


func skip_transition() -> void:
	if can_skip_transition():
		_skip_transition = true
		_transition_tween.custom_step(2.0)


func _wait_transition(tween: Tween) -> void:
	_transition_tween = tween
	if _skip_transition:
		tween.custom_step(2.0)
	else:
		await tween.finished


func _set_transition(active: bool) -> void:
	_transition = active
	_skip_transition = false
	if not active:
		_transition_tween = null
	player.set_vehicle_transition(active)


func _enter_vehicle(vehicle: Vehicle) -> void:
	_set_transition(true)
	player.mounted = true
	player.collision_layer = 0
	player.collision_mask = 0
	driven = vehicle
	vehicle.speed = 0.0
	if is_instance_valid(vehicle.route):
		vehicle.route.queue_free()
		vehicle.route = null
	if vehicle.passenger_door:
		vehicle.passenger_door.rotation.y = 0.0
		bus_taken.emit(vehicle)
	player.camera.reparent(vehicle)
	var swing := create_tween()
	swing.tween_property(vehicle.door, "rotation:y", -1.12, 0.26)
	await _wait_transition(swing)
	if is_instance_valid(vehicle.driver):
		await _eject_driver(vehicle)
	vehicle.set_driven(true)
	var enter := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	enter.tween_property(player.camera, "position", vehicle.seat(), 0.44)
	enter.tween_property(player.camera, "rotation", Vector3.ZERO, 0.44)
	enter.tween_property(player.camera, "fov", 76.0, 0.44)
	await _wait_transition(enter)
	vehicle.door.rotation.y = 0.0
	player.camera.set_driving()
	_set_transition(false)


func _eject_driver(vehicle: Vehicle) -> void:
	var driver := vehicle.driver
	vehicle.driver = null
	var health := vehicle.driver_target.health.current_health
	vehicle.driver_target.queue_free()
	vehicle.driver_target = null
	driver.reparent(self)
	driver.show()
	_events.hazard.emit(vehicle.global_position, 28.0)
	var pavement := vehicle.to_global(Vector3(-2.05, 0.0, vehicle.door.position.z + 0.50))
	var pull := create_tween().set_parallel()
	pull.tween_property(driver, "global_position", pavement, 0.35)
	pull.tween_property(driver, "rotation:z", -1.1, 0.35)
	await _wait_transition(pull)
	var fall := create_tween()
	fall.tween_interval(0.21)
	await _wait_transition(fall)
	driver.rotation.z = 0.0
	driver.face(pavement - vehicle.global_basis.x * 12.0)
	var target := Target.new()
	add_child(target)
	target.global_position = driver.global_position
	driver.reparent(target)
	driver.scale = Vector3.ONE
	target.bind(driver, Target.CIVILIAN, Vector3(0.8, 2.1, 0.65))
	target.health.current_health = health
	_ejected.append(target)


func _exit_vehicle() -> void:
	var vehicle := driven
	var exit := vehicle.to_global(Vector3(-1.68, 0.05, vehicle.door.position.z + 0.5))
	var query := PhysicsRayQueryParameters3D.create(vehicle.global_position + Vector3.UP * 0.75,
		exit + Vector3.UP * 0.75, Player.WORLD_LAYER | Vehicle.VEHICLE_LAYER, [vehicle.get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	_set_transition(true)
	vehicle.speed = 0.0
	vehicle.set_driven(false)
	vehicle.door.rotation.y = -1.05
	player.global_position = exit
	player.rotation.y = vehicle.rotation.y
	player.camera.reparent(player)
	player.camera.position = Vector3(0, 1.62, 0)
	player.camera.rotation = Vector3.ZERO
	player.camera.set_driving()
	var close := create_tween()
	close.tween_property(vehicle.door, "rotation:y", 0.0, 0.30)
	await _wait_transition(close)
	driven = null
	engine_speed.emit(-1.0)
	player.velocity = Vector3.ZERO
	player.collision_layer = Player.PLAYER_LAYER
	player.collision_mask = Player.WORLD_LAYER | Player.VEHICLE_LAYER
	player.mounted = false
	_set_transition(false)
