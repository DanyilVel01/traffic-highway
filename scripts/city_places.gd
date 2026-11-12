extends Node3D

const Door = preload("res://scripts/door_component.gd")
const Shapes = preload("res://scripts/vehicle_visual.gd")
const Player = preload("res://scripts/skydive_player.gd")
const Region = preload("res://scripts/region_terrain.gd")

class Venue:
	var door: Door
	var approach: Vector3
	var threshold: Vector3
	var inside: Vector3
	var terrace: Vector3
	var cafe: bool

var player: Player
var venues: Array[Venue] = []
var nearby: Door


func build(target: Player) -> void:
	player = target
	for city in [0.0, Region.CITY_DISTANCE]:
		_build_venue(Vector3(city - 60.0, 0.10, 65.0), true)
		_build_venue(Vector3(city + 100.0, 0.10, -95.0), false)


func _physics_process(_delta: float) -> void:
	nearby = null
	if player.mounted or player.phase != Player.Phase.GROUND:
		return
	var best := 3.0 * 3.0
	for venue in venues:
		var distance := player.global_position.distance_squared_to(venue.threshold)
		if distance < best:
			best = distance
			nearby = venue.door


func interact() -> void:
	if is_instance_valid(nearby):
		nearby.interact()


func nearest(at: Vector3) -> Venue:
	var best := 60.0 * 60.0
	var found: Venue
	for venue in venues:
		var distance := venue.approach.distance_squared_to(at)
		if distance < best:
			best = distance
			found = venue
	return found


func _build_venue(center: Vector3, cafe: bool) -> void:
	var walls := Color("#849494") if cafe else Color("#73868d")
	var accent := Color("#bd7761") if cafe else Color("#5b8794")
	var room := Node3D.new()
	add_child(room)
	room.position = center
	Shapes.box(room, Vector3(11.65, 0.04, 8.75), Vector3(0, 0.018, 0), Color("#af9878"))
	_solid(room, Vector3(12.15, 0.31, 9.2), Vector3(0, 3.56, 0), walls.darkened(0.25))
	_solid(room, Vector3(12.0, 3.47, 0.24), Vector3(0, 1.72, -4.45), walls)
	for side in [-1.0, 1.0]:
		_solid(room, Vector3(0.24, 3.47, 8.9), Vector3(side * 5.9, 1.72, 0), walls)
		_solid(room, Vector3(4.95, 0.78, 0.24), Vector3(side * 3.25, 0.39, 4.45), walls)
		var window := _solid(room, Vector3(4.95, 1.85, 0.15), Vector3(side * 3.25, 1.68, 4.45), Color("#b1d5d1"))
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.64, 0.82, 0.82, 0.22)
		glass.roughness = 0.25
		window.material_override = glass
		window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for trim in [0.91, 3.25, 5.62]:
			Shapes.box(room, Vector3(0.10, 1.85, 0.18), Vector3(side * trim, 1.68, 4.45), accent.darkened(0.3))
		Shapes.box(room, Vector3(4.95, 0.09, 0.23), Vector3(side * 3.25, 0.81, 4.45), accent.darkened(0.3))
		_solid(room, Vector3(4.95, 0.92, 0.26), Vector3(side * 3.25, 3.0, 4.45), accent)
	_solid(room, Vector3(1.61, 1.01, 0.25), Vector3(0, 2.93, 4.45), accent)
	Shapes.box(room, Vector3(11.55, 0.20, 1.51), Vector3(0, 2.98, 4.95), accent)
	var sign := Label3D.new()
	sign.text = "RIDGE & ROAST" if cafe else "VALLEY MARKET"
	sign.position = Vector3(0, 3.30, 5.20)
	sign.font_size = 40
	sign.pixel_size = 0.014
	sign.modulate = Color("#fff0c9")
	room.add_child(sign)
	var venue := Venue.new()
	venue.cafe = cafe
	venue.door = Door.new()
	room.add_child(venue.door)
	venue.door.position = Vector3(-0.68, 0, 4.45)
	venue.door.build(accent.darkened(0.31))
	venue.approach = center + Vector3(0, 0, 8.75)
	venue.threshold = center + Vector3(0, 0, 4.72)
	venue.inside = center + Vector3(0, 0, 1.4)
	venue.terrace = center + Vector3(2.78, 0, 7.80)
	venues.append(venue)
	_solid(room, Vector3(3.65, 1.04, 0.82), Vector3(-2.72, 0.52, -2.50), Color("#84644d"))
	Shapes.box(room, Vector3(3.78, 0.12, 0.97), Vector3(-2.72, 1.06, -2.50), Color("#c49c73"))
	Shapes.box(room, Vector3(0.43, 0.24, 0.33), Vector3(-3.96, 1.24, -2.50), Color("#37494b"))
	for x in [-3.55, 0.0, 3.55]:
		Shapes.box(room, Vector3(0.06, 0.43, 0.06), Vector3(x, 3.22, 0.4), Color("#57625f"))
		Shapes.box(room, Vector3(0.64, 0.14, 0.38), Vector3(x, 2.99, 0.4), Color("#ba8056"))
		var bulb := Shapes.box(room, Vector3(0.52, 0.05, 0.31), Vector3(x, 2.90, 0.4), Color("#fff0b8"))
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("#fff0b8")
		bulb.material_override = glow
	if cafe:
		for x in [-3.9, 2.78]:
			_table(room, Vector3(x, 0, 1.29))
		_table(room, Vector3(2.78, 0, 7.80))
		Shapes.box(room, Vector3(0.10, 2.34, 0.10), Vector3(2.78, 1.17, 7.80), Color("#57625f"))
		Shapes.box(room, Vector3(2.38, 0.13, 2.04), Vector3(2.78, 2.33, 7.80), Color("#d3a36a"))
		Shapes.box(room, Vector3(0.68, 0.53, 0.44), Vector3(-2.60, 1.38, -2.55), Color("#57625f"))
		_wall_board(room, "ESPRESSO  /  FILTER\nPASTRIES  /  TEA", Vector3(-2.6, 2.38, -4.26))
	else:
		for at in [Vector3(3.68, 0, -2.67), Vector3(3.68, 0, 0.13)]:
			_market_shelf(room, at)
		_wall_board(room, "PRODUCE  /  PANTRY", Vector3(2.0, 2.73, -4.26))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.8, 0)
	light.light_color = Color("#ffd49e")
	light.light_energy = 1.50
	light.omni_range = 11.0
	room.add_child(light)


func _table(room: Node3D, at: Vector3) -> void:
	_solid(room, Vector3(1.16, 0.11, 0.82), at + Vector3.UP * 0.78, Color("#a28463"))
	Shapes.box(room, Vector3(0.12, 0.77, 0.12), at + Vector3.UP * 0.38, Color("#57625f"))
	for z in [-0.70, 0.70]:
		Shapes.box(room, Vector3(0.52, 0.10, 0.50), at + Vector3(0, 0.45, z), Color("#81908b"))
		Shapes.box(room, Vector3(0.52, 0.46, 0.10), at + Vector3(0, 0.66, z * 1.32), Color("#81908b"))
	Shapes.box(room, Vector3(0.12, 0.16, 0.12), at + Vector3(0.22, 0.89, 0.07), Color("#f3dfc0"))


func _wall_board(room: Node3D, words: String, at: Vector3) -> void:
	Shapes.box(room, Vector3(2.6, 0.76, 0.08), at, Color("#3f5556"))
	var board := Label3D.new()
	board.text = words
	board.font_size = 32
	board.pixel_size = 0.008
	board.modulate = Color("#f5dfba")
	board.position = at + Vector3.BACK * 0.05
	room.add_child(board)


func _market_shelf(room: Node3D, at: Vector3) -> void:
	_solid(room, Vector3(2.8, 1.65, 0.13), at + Vector3(0, 0.82, -0.30), Color("#536866"))
	var labels: Array[Color] = [Color("#e0ab65"), Color("#829b69"), Color("#c88470")]
	for level in 3:
		var y := 0.34 + level * 0.53
		Shapes.box(room, Vector3(2.8, 0.10, 0.60), at + Vector3.UP * y, Color("#b39a78"))
		for row in 7:
			Shapes.box(room, Vector3(0.24, 0.21, 0.31), at + Vector3((row - 3) * 0.35, y + 0.16, 0), labels[(row + level) % labels.size()])


func _solid(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 8
	body.collision_mask = 0
	parent.add_child(body)
	var visual := Shapes.box(body, size, Vector3.ZERO, color)
	var hitbox := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	hitbox.shape = shape
	body.add_child(hitbox)
	return visual
