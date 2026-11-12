extends Node3D

const Vehicle = preload("res://scripts/street_vehicle.gd")
const Player = preload("res://scripts/skydive_player.gd")
const Region = preload("res://scripts/region_terrain.gd")
const Events = preload("res://scripts/city_events.gd")
const Signals = preload("res://scripts/city_signals.gd")
const Target = preload("res://scripts/city_target.gd")
const Shapes = preload("res://scripts/vehicle_visual.gd")

signal horn
signal bus_arrived(bus: Vehicle)
signal bus_taken(bus: Vehicle)
signal engine_speed(kmh: float)
signal police_fire(at: Vector3)
signal siren

var vehicles: Array[Vehicle] = []
var _events: Events
var player: Player
var signals := Signals.new()
var nearby: Vehicle
var driven: Vehicle
var crowd: Node3D
var _transition := false
var _ejected: Array[Target] = []
var _cells: Dictionary = {}
var cinematic := false
var _escape_pursuit := false
var _deployed := false
var _police: Array[Vehicle] = []
var _siren_time := 0.0
var _police_fire_delay := 1.3
var _siren_delay := 0.0


func set_pressure(level: int) -> void:
	_escape_pursuit = level >= 3


func build(target: Player) -> void:
	player = target
	_events = get_node("/root/CityEvents") as Events
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
	for index in 18:
		var commuter := _add_vehicle(interstate, index % 5, (index + 0.5) / 18.0)
		commuter.cruise_speed += 9.0
	var outer := _route([Vector3(37.2, 0, 2.8), Vector3(173, 0, 2.8), Vector3(228, 0, 7.25),
		Vector3(2172, 0, 7.25), Vector3(2235, 0, 3.1), Vector3(Region.CITY_DISTANCE + 42.8, 0, 3.1),
		Vector3(Region.CITY_DISTANCE + 42.8, 0, -42.8), Vector3(Region.CITY_DISTANCE - 42.8, 0, -42.8),
		Vector3(Region.CITY_DISTANCE - 42.8, 0, -3.1), Vector3(2235, 0, -3.1), Vector3(2172, 0, -7.25),
		Vector3(228, 0, -7.25), Vector3(173, 0, -3.1), Vector3(37.2, 0, -3.1), Vector3(37.2, 0, 2.8)])
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
	if _escape_pursuit and not cinematic:
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


func _update_pursuit(delta: float) -> void:
	_siren_time += delta
	_siren_delay -= delta
	_police_fire_delay -= delta
	if not _deployed and player.mounted and player.position.x < 2225.0 and player.position.x > 1650.0:
		_deployed = true
		for index in 5:
			var z := -2.7 if index % 2 == 0 else -7.4
			var spawn := Vector3(player.position.x + 18.0 + index * 6.4, 0.02, z)
			var unit := park_vehicle(1, Color("#d6e4ed"), spawn, PI * 0.5)
			Shapes.box(unit, Vector3(0.42, 0.16, 0.21), Vector3(-0.26, 1.78, 0.08), Color("#ff4359"))
			Shapes.box(unit, Vector3(0.42, 0.16, 0.21), Vector3(0.26, 1.78, 0.08), Color("#4689ff"))
			_police.append(unit)
	for index in _police.size():
		var unit := _police[index]
		if unit == driven or not is_instance_valid(unit.driver):
			continue
		var red := fmod(_siren_time * 4.0 + index * 0.33, 1.0) < 0.5
		unit.get_child(unit.get_child_count() - 2).visible = red
		unit.get_child(unit.get_child_count() - 1).visible = not red
		var ahead := unit.position.x - player.position.x
		if absf(ahead) < 45.0 and _siren_delay <= 0.0:
			siren.emit()
			_siren_delay = 4.2
		if ahead < 4.0 or ahead > 155.0:
			unit.speed = move_toward(unit.speed, 0.0, delta * 19.0)
		else:
			unit.speed = move_toward(unit.speed, clampf(ahead * 1.4, 9.0, 39.0), delta * 9.0)
		unit.velocity = Vector3(-unit.speed, -1.0, 0)
		unit.move_and_slide()
		unit._spin(unit.speed * delta)
		if unit.get_slide_collision_count() > 0 and absf(unit.get_real_velocity().x) < unit.speed * 0.6:
			unit.speed *= 0.68
		if player.mounted and ahead > 7.0 and ahead < 38.0 and _police_fire_delay <= 0.0:
			police_fire.emit(unit.global_position + Vector3(-2.55, 1.36, 0))
			_police_fire_delay = 1.1


func _interact() -> void:
	if _transition or player.phase != Player.Phase.GROUND:
		return
	if is_instance_valid(driven):
		_exit_vehicle()
	elif is_instance_valid(nearby):
		_enter_vehicle(nearby)


func _enter_vehicle(vehicle: Vehicle) -> void:
	_transition = true
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
	await swing.finished
	if is_instance_valid(vehicle.driver):
		await _eject_driver(vehicle)
	vehicle.set_driven(true)
	var enter := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	enter.tween_property(player.camera, "position", vehicle.seat(), 0.44)
	enter.tween_property(player.camera, "rotation", Vector3.ZERO, 0.44)
	enter.tween_property(player.camera, "fov", 76.0, 0.44)
	await enter.finished
	vehicle.door.rotation.y = 0.0
	player.camera.set_driving()
	_transition = false


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
	await pull.finished
	var fall := create_tween()
	fall.tween_interval(0.21)
	await fall.finished
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
	_transition = true
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
	await close.finished
	driven = null
	engine_speed.emit(-1.0)
	player.velocity = Vector3.ZERO
	player.collision_layer = Player.PLAYER_LAYER
	player.collision_mask = Player.WORLD_LAYER | Player.VEHICLE_LAYER
	player.mounted = false
	_transition = false
