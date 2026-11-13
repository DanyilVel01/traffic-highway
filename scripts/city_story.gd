extends Node3D

const Actor = preload("res://scripts/finale_actor.gd")
const Target = preload("res://scripts/city_target.gd")
const Shapes = preload("res://scripts/vehicle_visual.gd")
const Traffic = preload("res://scripts/city_traffic.gd")
const Vehicle = preload("res://scripts/street_vehicle.gd")
const Player = preload("res://scripts/skydive_player.gd")
const Places = preload("res://scripts/city_places.gd")
const Region = preload("res://scripts/region_terrain.gd")
const Cinema = preload("res://scripts/city_cinematics.gd")

signal dialogue(line: String)
signal landed
signal launched
signal finished
signal cinematic_changed(active: bool)
signal police_pressure(level: int)
signal cinematic_shot(at: Vector3)

enum Stage { LANDING, CAFE, BUS, WRECK, RADIO, ESCAPE, LAUNCH, LOST }
enum Start { DROP, WRECK, ESCAPE }
const LIMIT := 120.0
const RADIO := Vector3(2369, 0.10, 7.0)
const CAR := Vector3(2369, 0.02, -2.6)
const PAD := Vector3(1510, 0.26, -18)
const HATCH := PAD + Vector3(8, 0.22, 4)
const BUS_STOP := Vector3(101, 0.02, 3.6)
const ACCENT := Color("#ff9e63")

var stage := Stage.LANDING
var remaining := LIMIT
var objective := ""
var destination := Vector3.ZERO
var player: Player
var cinema := Cinema.new()
var cinematic := false
var _launch_tween: Tween
var _launch_finished := false
var ignition_pending := false
var launch_throttle := 0.0
var _traffic: Traffic
var _allies: Array[Target] = []
var _bus: Vehicle
var _bus_moving := false
var _marker: Label3D
var _plane: Node3D
var _rocket: Node3D
var _flame: MeshInstance3D
var _cut_camera: Camera3D
var _flash: ColorRect
var _crew_in_car := false
var _chase_shown := false
var _light_materials: Dictionary = {}


func build(target: Player, traffic: Traffic, places: Places, start: Start) -> void:
	player = target
	_traffic = traffic
	add_child(cinema)
	cinema.subtitle.connect(dialogue.emit)
	cinema.fired.connect(cinematic_shot.emit)
	_marker = _sign("", Vector3.ZERO)
	_marker.hide()
	var cafe := places.venues[0].inside + Vector3(1.1, 0, 0)
	_ally(cafe, Actor.Role.PRINCESS, Color("#bd65a7"))
	_ally(BUS_STOP + Vector3(2.9, 0.08, 3.7), Actor.Role.DRIVER, Color("#bd773b"))
	var crash := Vector3(1250, Region.mesh_height(1250, 15), 15)
	_ally(crash + Vector3(2.5, 0.1, 2.0), Actor.Role.DRIVER, Color("#8baa91"))
	_hide_ally(0)
	_hide_ally(1)
	_build_wreck(crash)
	_build_radio()
	_build_rocket()
	match start:
		Start.WRECK:
			var approach := crash + Vector3(7.5, 0, -2.8)
			approach.y = Region.mesh_height(approach.x, approach.z) + 0.06
			_start_on_foot(approach)
			var pilot := _allies[2].position
			player.rotation.y = atan2(approach.x - pilot.x, approach.z - pilot.z)
			_destination(Stage.WRECK, "Find the pilot at the helicopter wreck", pilot)
		Start.ESCAPE:
			_start_on_foot(RADIO + Vector3(0, 0, -2.4))
			_begin_escape()
		Start.DROP:
			_destination(Stage.LANDING, "Deploy the parachute and land", Vector3.ZERO)


func _start_on_foot(at: Vector3) -> void:
	player.phase = Player.Phase.GROUND
	player.position = at
	player.velocity = Vector3.ZERO
	player.camera.look(Vector2(0, -265))


func _physics_process(delta: float) -> void:
	if not player.damage.alive or cinematic:
		return
	match stage:
		Stage.LANDING:
			if player.phase == Player.Phase.GROUND:
				landed.emit()
				_allies[0].show()
				_allies[0].set_targetable(true)
				_set_cinematic(true)
				await _scene(Cinema.Shot.LANDING, player.position)
				_destination(Stage.CAFE, "Meet the princess at Ridge & Roast", _allies[0].position)
				_finish_cinematic()
		Stage.BUS:
			if _bus_moving:
				if _bus.position.x >= BUS_STOP.x or not is_instance_valid(_bus.route):
					_stop_bus()
				else:
					destination = _bus.position
					_marker.position = destination + Vector3.UP * 4.5
		Stage.ESCAPE:
			if not _chase_shown and player.mounted and player.position.x < 2200 and player.position.x > 1750:
				_chase_shown = true
				_set_cinematic(true)
				await _scene(Cinema.Shot.PURSUIT, Vector3(player.position.x, 0, player.position.z), player.camera.get_parent().rotation.y)
				_finish_cinematic()
				return
			_follow_crew(delta)
			remaining = maxf(remaining - delta, 0)
			_plane.position.x = RADIO.x + 2500.0 * remaining / LIMIT
			if remaining <= 0.0:
				stage = Stage.LOST
				_show_flash(1.0)
				player.damage.fatal("Ridge City was hit. The rocket never launched.")


func can_interact() -> bool:
	if cinematic or player.mounted or player.phase != Player.Phase.GROUND:
		return false
	if stage == Stage.BUS and _bus_moving:
		return false
	var reach := 2.6 if stage == Stage.CAFE else 4.0
	return stage >= Stage.CAFE and stage <= Stage.ESCAPE and player.position.distance_squared_to(destination) < reach * reach


func interact() -> void:
	if not can_interact():
		return
	_set_cinematic(true)
	match stage:
		Stage.CAFE:
			var cafe := _allies[0].position + Vector3.LEFT * 0.8
			_hide_ally(0)
			await _scene(Cinema.Shot.CAFE, cafe)
			await _scene(Cinema.Shot.LEDGER, cafe)
			await _scene(Cinema.Shot.STREET, Vector3(-54, 0.09, 77))
			police_pressure.emit(1)
			_start_bus()
		Stage.BUS:
			var stop := _allies[1].position
			_hide_ally(1)
			await _scene(Cinema.Shot.REUNION, stop)
			await _scene(Cinema.Shot.AMBUSH, stop + Vector3(8, 0, -5))
			police_pressure.emit(2)
			_destination(Stage.WRECK, "Find the pilot at the helicopter wreck", _allies[2].position)
		Stage.WRECK:
			var wreck := _allies[2].position
			_hide_ally(2)
			await _scene(Cinema.Shot.WRECK, wreck)
			await _scene(Cinema.Shot.RESCUE, wreck)
			police_pressure.emit(2)
			_destination(Stage.RADIO, "Broadcast the ledger at Ridge Radio", RADIO)
		Stage.RADIO:
			var studio := RADIO + Vector3(0, 0, 3.1)
			await _scene(Cinema.Shot.RADIO_ARRIVAL, studio)
			await _scene(Cinema.Shot.BROADCAST, studio)
			await _scene(Cinema.Shot.BREACH, RADIO + Vector3(0, 0, -4))
			await _scene(Cinema.Shot.BOMBER, RADIO + Vector3(350, 155, 0))
			_begin_escape()
		Stage.ESCAPE:
			await _scene(Cinema.Shot.BOARD, HATCH)
			_launch()
			return
	_finish_cinematic()


func _start_bus() -> void:
	var route := _traffic._route([Vector3(-28, 0.02, 3.6), BUS_STOP + Vector3(4, 0, 0)])
	_bus = _traffic._add_vehicle(route, 5, 0.0)
	_bus.cruise_speed = 9.8
	_bus_moving = true
	_hide_ally(1)
	_destination(Stage.BUS, "Catch the Ridge City bus", _bus.position)


func _stop_bus() -> void:
	if is_instance_valid(_bus.route):
		_bus.route.queue_free()
		_bus.route = null
		_bus.speed = 0.0
	_bus_moving = false
	_bus.passenger_door.rotation.y = 1.2
	_allies[1].position = Vector3(_bus.position.x + 2.9, 0.10, 7.1)
	_set_cinematic(true)
	await _scene(Cinema.Shot.BUS, _allies[1].position)
	_allies[1].show()
	_allies[1].set_targetable(true)
	_destination(Stage.BUS, "Meet your friend beside the bus", _allies[1].position)
	_finish_cinematic()


func _begin_escape() -> void:
	remaining = LIMIT
	_traffic.park_vehicle(2, Color("#42b7a7"), CAR, PI * 0.5)
	for index in _allies.size():
		_allies[index].position = CAR + Vector3((index - 1) * 1.35, 0.04, 2.7)
		_allies[index].show()
		_allies[index].set_targetable(true)
	_destination(Stage.ESCAPE, "Drive west to the rocket, then board at the tower", HATCH)
	_plane.show()
	police_pressure.emit(3)
	player.damage.heal(player.damage.MAX_HP)
	dialogue.emit("Ridge Radio / A bomber is inbound. Nuclear drop in two minutes. Take shelter now.")


func _scene(shot: Cinema.Shot, at: Vector3, heading: float = PI * 0.5) -> void:
	await cinema.play(shot, at, heading)


func _finish_cinematic() -> void:
	player.camera.make_current()
	_set_cinematic(false)


func _set_cinematic(value: bool) -> void:
	if cinematic == value:
		return
	cinematic = value
	player.set_enabled(not value)
	if value:
		player.velocity = Vector3.ZERO
	cinematic_changed.emit(value)


func _follow_crew(delta: float) -> void:
	if player.mounted != _crew_in_car:
		_crew_in_car = player.mounted
		for index in _allies.size():
			var ally := _allies[index]
			ally.visible = not _crew_in_car
			ally.set_targetable(not _crew_in_car)
			if not _crew_in_car:
				ally.position = player.position + Vector3(index - 1, 0, 2.2)
	if _crew_in_car:
		return
	for index in _allies.size():
		var ally := _allies[index]
		var goal := player.position + Vector3((index - 1) * 1.9, 0, 2.2)
		if ally.position.distance_squared_to(goal) > 144.0:
			ally.position = goal
		elif ally.position.distance_squared_to(goal) > 0.18:
			ally.actor.face(goal - ally.position)
			ally.actor.stride((LIMIT - remaining) * 5.8, true)
			ally.position = ally.position.move_toward(goal, delta * 7.2)
		else:
			ally.actor.stand_pose()


func _destination(next: Stage, prompt: String, at: Vector3) -> void:
	stage = next
	objective = prompt
	destination = at
	_marker.position = at + Vector3.UP * 3.5
	_marker.text = "◆"
	_marker.visible = next != Stage.LANDING


func _ally(at: Vector3, role: Actor.Role, outfit: Color) -> void:
	var ally := Target.new()
	add_child(ally)
	ally.position = at
	var model := Actor.new()
	ally.add_child(model)
	model.build(role, outfit)
	model.rotation.y = PI
	ally.bind(model, Target.ALLY, Vector3(0.88, 2.22, 0.72))
	_allies.append(ally)


func _hide_ally(index: int) -> void:
	_allies[index].hide()
	_allies[index].set_targetable(false)


func _build_wreck(at: Vector3) -> void:
	var wreck := Node3D.new()
	add_child(wreck)
	wreck.position = at
	wreck.rotation.z = -0.42
	Shapes.box(wreck, Vector3(4.9, 1.45, 2.3), Vector3.UP * 0.70, Color("#a5554f"))
	Shapes.box(wreck, Vector3(1.55, 0.7, 2.0), Vector3(1.68, 1.32, 0), Color("#46616c"))
	Shapes.box(wreck, Vector3(3.6, 0.31, 0.36), Vector3(-4.04, 0.57, 0), Color("#a5554f"))
	Shapes.box(wreck, Vector3(4.8, 0.12, 0.26), Vector3(0.0, 1.85, 0.0), Color("#333b46")).rotation.z = -0.43
	var smoke := CPUParticles3D.new()
	wreck.add_child(smoke)
	smoke.position = Vector3(0, 1.48, 0)
	smoke.amount = 22
	smoke.lifetime = 3.5
	smoke.direction = Vector3.UP
	smoke.gravity = Vector3(0.7, 1.0, 0)
	smoke.initial_velocity_min = 1.2
	smoke.initial_velocity_max = 2.4
	smoke.scale_amount_min = 0.65
	smoke.scale_amount_max = 1.85
	smoke.mesh = SphereMesh.new()
	var soot := StandardMaterial3D.new()
	soot.albedo_color = Color("#414954")
	smoke.material_override = soot


func _build_radio() -> void:
	for side in [-1.0, 1.0]:
		_solid(Vector3(0.24, 3.3, 7.2), RADIO + Vector3(side * 3.8, 1.65, 4.0), Color("#586b76"))
	_solid(Vector3(7.6, 3.3, 0.24), RADIO + Vector3(0, 1.65, 7.6), Color("#495a64"))
	_solid(Vector3(7.8, 0.22, 7.4), RADIO + Vector3(0, 3.3, 4.0), Color("#586b76"))
	Shapes.box(self, Vector3(7.45, 0.035, 7.05), RADIO + Vector3(0, 0.02, 4.0), Color("#6e7479"))
	Shapes.box(self, Vector3(1.5, 0.12, 0.58), RADIO + Vector3(0, 3.15, 3.1), Color("#ffe0a8"))
	var light := OmniLight3D.new()
	add_child(light)
	light.position = RADIO + Vector3(0, 2.9, 4.0)
	light.light_color = Color("#ffcfa8")
	light.light_energy = 1.75
	light.omni_range = 8.5
	Shapes.box(self, Vector3(0.14, 7.2, 0.14), RADIO + Vector3(2.3, 6.3, 4.2), Color("#d3d1bc"))
	Shapes.box(self, Vector3(2.8, 0.13, 0.13), RADIO + Vector3(2.3, 9.4, 4.2), ACCENT)
	_sign("RIDGE RADIO", RADIO + Vector3(0, 3.55, 0.40))


func _build_rocket() -> void:
	var tower := Node3D.new()
	add_child(tower)
	_solid(Vector3(25, 0.36, 15), PAD + Vector3.DOWN * 0.18, Color("#555f6b"))
	Shapes.box(self, Vector3(7.4, 0.04, 6.0), PAD + Vector3(8, -0.21, 9), Color("#687d83"))
	for x in [6.5, 10.4]:
		for z in [-2.0, 1.7]:
			Shapes.box(tower, Vector3(0.24, 14, 0.24), PAD + Vector3(x, 7, z), Color("#94a6a5"))
	for height in [0.2, 4.5, 9.1, 13.5]:
		Shapes.box(tower, Vector3(4.6, 0.26, 4.5), PAD + Vector3(8.4, height, -0.15), Color("#52636c"))
	_sign("BOARDING LIFT", HATCH + Vector3.UP * 2.6)
	_rocket = Node3D.new()
	add_child(_rocket)
	_rocket.position = PAD
	_cylinder(_rocket, 1.45, 1.45, 12.8, Vector3.UP * 7.7, Color("#e8e6d8"))
	_cylinder(_rocket, 0.08, 1.45, 3.5, Vector3.UP * 15.7, Color("#eef4f2"))
	_cylinder(_rocket, 1.48, 1.48, 0.65, Vector3.UP * 4.25, ACCENT)
	_cylinder(_rocket, 0.72, 0.96, 1.55, Vector3.UP * 0.85, Color("#495c68"))
	for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
		var fin := Shapes.box(_rocket, Vector3(1.02, 2.3, 0.20), Vector3(cos(yaw) * 1.72, 1.95, sin(yaw) * 1.72), Color("#c26850"))
		fin.rotation.y = -yaw
	_flame = _cylinder(_rocket, 0.85, 0.02, 9, Vector3.DOWN * 4.0, ACCENT)
	_flame.material_override = _unlit(ACCENT)
	_flame.hide()
	_plane = Node3D.new()
	add_child(_plane)
	_plane.position = Vector3(RADIO.x + 2500, 190, 130)
	Shapes.box(_plane, Vector3(26, 2.3, 3.2), Vector3.ZERO, Color("#a1aeb7"))
	Shapes.box(_plane, Vector3(9, 0.68, 31), Vector3(1, 0, 0), Color("#9da8b3"))
	Shapes.box(_plane, Vector3(5, 3.2, 0.62), Vector3(10, 1.8, 0), Color("#8b99a5"))
	_plane.hide()
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_flash = ColorRect.new()
	layer.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 0.79, 0.51, 0)


func _launch() -> void:
	stage = Stage.LAUNCH
	_set_cinematic(true)
	objective = ""
	_marker.hide()
	for index in _allies.size():
		_hide_ally(index)
	player.set_enabled(false)
	launched.emit()
	_cut_camera = Camera3D.new()
	add_child(_cut_camera)
	_cut_camera.position = PAD + Vector3(27, 8, 23)
	_cut_camera.look_at(PAD + Vector3.UP * 8.2)
	_cut_camera.make_current()
	dialogue.emit("Pilot / Erik, you're in control. Bring the engines up to seventy percent.")
	ignition_pending = true
	while not _launch_finished and launch_throttle < 0.70:
		await get_tree().physics_frame
		var input := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
		launch_throttle = clampf(launch_throttle + input * get_physics_process_delta_time() * 0.49, 0.0, 1.0)
	if _launch_finished:
		return
	ignition_pending = false
	dialogue.emit("Pilot / Ignition. Hold her steady.")
	await get_tree().create_timer(1.1, false).timeout
	if _launch_finished:
		return
	_flame.show()
	var lift := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lift.tween_property(_rocket, "position:y", 230.0, 17.5)
	lift.tween_property(_cut_camera, "position:y", 189.0, 17.5)
	lift.tween_method(_track_rocket, 0.0, 1.0, 17.5)
	_launch_tween = lift
	await lift.finished
	_cut_camera.look_at(RADIO + Vector3.UP * 45.0)
	var blast := Shapes.attach(self, SphereMesh.new(), RADIO + Vector3.UP * 11.0, ACCENT)
	blast.material_override = _unlit(Color("#ffc87a"))
	var bloom := create_tween()
	bloom.tween_property(blast, "scale", Vector3.ONE * 240.0, 1.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_show_flash(0.86)
	_launch_tween = bloom
	await bloom.finished
	blast.queue_free()
	_finish_launch()


func can_skip_launch() -> bool:
	return stage == Stage.LAUNCH and not _launch_finished


func skip_launch() -> void:
	if not can_skip_launch():
		return
	if _launch_tween and _launch_tween.is_valid():
		_launch_tween.kill()
	_finish_launch()


func _finish_launch() -> void:
	_launch_finished = true
	ignition_pending = false
	dialogue.emit("Pilot / Erik, take the controls. Vesper is straight ahead.")
	finished.emit()


func _track_rocket(_progress: float) -> void:
	_cut_camera.look_at(_rocket.position + Vector3.UP * 8.5)


func _show_flash(intensity: float) -> void:
	_flash.color.a = intensity
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(_flash, "color:a", 0.0, 0.95)


func _sign(words: String, at: Vector3) -> Label3D:
	var sign := Label3D.new()
	add_child(sign)
	sign.position = at
	sign.text = words
	sign.font_size = 48
	sign.pixel_size = 0.012
	sign.modulate = Color("#ffd6a2")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return sign


func _solid(size: Vector3, at: Vector3, paint: Color) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = at
	body.collision_layer = Player.WORLD_LAYER
	body.collision_mask = 0
	Shapes.box(body, size, Vector3.ZERO, paint)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)


func _cylinder(parent: Node3D, top: float, bottom: float, height: float, at: Vector3, paint: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	return Shapes.attach(parent, mesh, at, paint)


func _unlit(paint: Color) -> StandardMaterial3D:
	if not _light_materials.has(paint):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = paint
		_light_materials[paint] = material
	return _light_materials[paint]
