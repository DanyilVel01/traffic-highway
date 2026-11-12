extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const SEGMENT_LENGTH: float = 60.0
const SEGMENT_COUNT: int = 4
const RAMP_START: float = 1800.0
const RAMP_END: float = RAMP_START + SEGMENT_LENGTH
const CAVE_DEPTH: float = 24.0
const CAVE_EXIT_START: float = 3960.0
const CAVE_EXIT_END: float = 4000.0
const LAUNCH_START: float = 5000.0
const LAUNCH_LIP: float = 5030.0
const LAUNCH_HEIGHT: float = 24.0
const SKY_LANDING: float = 5220.0
const SKY_HEIGHT: float = 115.0
const CHASE_EDGE: float = 9120.0
const STONE: Color = Color("#617a71")
const METAL: Color = Color("#879e9e")
const LINE: Color = Color("#f5f1d7")
const CAVE_ROCK: Color = Color("#352845")
const SKY_STONE: Color = Color("#e2daf7")
const SKY_PAVEMENT: Color = Color("#aaa2c9")
const SKY_GOLD: Color = Color("#dca853")
const CLOUD: Color = Color("#f1f5ff")
const CANOPY: Array[Color] = [Color("#397756"), Color("#4a8a58"), Color("#5b965f")]

var segments: Array[Node3D] = []
var _surface_sections: Array[Node3D] = []
var _left_shoulders: Array[Node3D] = []
var _cave_sections: Array[Node3D] = []
var _sky_sections: Array[Node3D] = []
var _ramp: Node3D
var _exit: Node3D
var _launch: Node3D


func build(lane_width: float) -> void:
	for index in SEGMENT_COUNT:
		var segment := Node3D.new()
		segment.name = "RoadSegment%d" % index
		add_child(segment)
		segments.append(segment)
		var surface := Node3D.new()
		segment.add_child(surface)
		_surface_sections.append(surface)
		_build_segment(surface, index, lane_width)
		var cave := Node3D.new()
		segment.add_child(cave)
		_cave_sections.append(cave)
		_build_cave(cave, index, lane_width)
		var sky := Node3D.new()
		sky.position.y = SKY_HEIGHT
		segment.add_child(sky)
		_sky_sections.append(sky)
		_build_sky(sky, index, lane_width)
	_ramp = Node3D.new()
	_ramp.name = "CaveRamp"
	add_child(_ramp)
	_build_ramp(lane_width)
	_exit = Node3D.new()
	_exit.name = "CaveExit"
	add_child(_exit)
	_build_exit(lane_width)
	_launch = Node3D.new()
	_launch.name = "SkywayRamp"
	add_child(_launch)
	_build_launch(lane_width)
	reset()


func reset() -> void:
	update_position(0.0)


func update_position(distance: float, sky_route: bool = false, reverse: bool = false, look_back: bool = false) -> void:
	var first_index := floori(distance / SEGMENT_LENGTH) - (2 if reverse or look_back else 1)
	var direction := -1.0 if reverse else 1.0
	for index in segments.size():
		var track_index := first_index + posmod(index - first_index, SEGMENT_COUNT)
		var start := float(track_index) * SEGMENT_LENGTH
		var underground := start >= RAMP_END and start < CAVE_EXIT_START
		var beyond_edge := reverse and start < CHASE_EDGE
		var sky_section := sky_route and start >= SKY_LANDING and not beyond_edge
		segments[index].position = Vector3(0, -CAVE_DEPTH if underground else 0.0,
			(distance - start - SEGMENT_LENGTH * 0.5) * direction)
		segments[index].rotation.y = PI if reverse else 0.0
		_surface_sections[index].visible = not beyond_edge and not sky_section and (start < RAMP_START or start >= CAVE_EXIT_START + SEGMENT_LENGTH)
		_left_shoulders[index].visible = track_index != -1
		_cave_sections[index].visible = underground
		_sky_sections[index].visible = sky_section
	_ramp.position.z = distance - (RAMP_START + RAMP_END) * 0.5
	_ramp.visible = absf(_ramp.position.z) < SEGMENT_LENGTH * 3.0
	_exit.position.z = distance - CAVE_EXIT_START
	_exit.visible = absf(_exit.position.z) < SEGMENT_LENGTH * 3.0
	_launch.position.z = distance - LAUNCH_START
	_launch.visible = distance >= LAUNCH_START - 210.0 and distance < SKY_LANDING + SEGMENT_LENGTH


static func height_at(distance: float, sky_route: bool = false) -> float:
	if sky_route and distance >= LAUNCH_START:
		if distance < LAUNCH_LIP:
			return LAUNCH_HEIGHT * inverse_lerp(LAUNCH_START, LAUNCH_LIP, distance)
		var t := clampf(inverse_lerp(LAUNCH_LIP, SKY_LANDING, distance), 0.0, 1.0)
		return lerpf(LAUNCH_HEIGHT, SKY_HEIGHT, t) + t * (1.0 - t) * lerpf(220.0, 165.0, t)
	if distance >= CAVE_EXIT_START:
		return -CAVE_DEPTH * (1.0 - clampf(inverse_lerp(CAVE_EXIT_START, CAVE_EXIT_END, distance), 0.0, 1.0))
	return -CAVE_DEPTH * clampf(inverse_lerp(RAMP_START, RAMP_END, distance), 0.0, 1.0)


static func pitch_at(distance: float, length: float, sky_route: bool = false) -> float:
	return atan2(height_at(distance + length * 0.5, sky_route) - height_at(distance - length * 0.5, sky_route), length)


func _build_lanes(section: Node3D, lane_width: float, length: float, pavement: Color, paint: Color) -> void:
	var shoulder := lane_width * 1.5
	Shapes.box(section, Vector3((shoulder + 0.62) * 2.0, 0.14, length), Vector3(0, -0.04, 0), pavement)
	for edge in [-shoulder, shoulder]:
		Shapes.box(section, Vector3(0.13, 0.022, length), Vector3(edge, 0.043, 0), paint)
	for x in [-lane_width / 2.0, lane_width / 2.0]:
		var count := maxi(1, roundi(length / 10.0))
		for index in range(count):
			var z := length * ((float(index) + 0.5) / float(count) - 0.5)
			Shapes.box(section, Vector3(0.12, 0.022, 4.3), Vector3(x, 0.043, z), paint)


func _build_exit(lane_width: float) -> void:
	var run := CAVE_EXIT_END - CAVE_EXIT_START
	var length := Vector2(run, CAVE_DEPTH).length()
	var deck := Node3D.new()
	deck.position = Vector3(0, -CAVE_DEPTH * 0.5, -run * 0.5)
	deck.rotation.x = atan2(CAVE_DEPTH, run)
	_exit.add_child(deck)
	_build_lanes(deck, lane_width, length, Color("#343045"), Color("#ffd497"))
	for side in [-1.0, 1.0]:
		var edge: float = side * (lane_width * 1.5 + 0.78)
		Shapes.box(deck, Vector3(0.46, 0.85, length), Vector3(edge, 0.25, 0), CAVE_ROCK)
		for index in range(4):
			var z := length * (float(index) - 1.5) / 4.0
			_crystal(deck, Vector3(edge + side * 1.1, 1.0, z), side * 0.24, 2.0, Color("#3ae3cc"))
		var width := 50.0 - absf(edge) - 1.4
		var bank_x: float = edge + side * (1.4 + width * 0.5)
		Shapes.box(_exit, Vector3(width, CAVE_DEPTH - 0.2, run), Vector3(bank_x, -CAVE_DEPTH * 0.5 - 0.1, -run * 0.5), CAVE_ROCK)
		Shapes.box(_exit, Vector3(width, 0.2, run), Vector3(bank_x, -0.1, -run * 0.5), Color("#749c64"))
	var surface := Node3D.new()
	var flat_length := SEGMENT_LENGTH - run
	surface.position.z = -run - flat_length * 0.5
	_exit.add_child(surface)
	Shapes.box(surface, Vector3(100, 0.2, flat_length), Vector3(0, -0.18, 0), Color("#749c64"))
	_build_lanes(surface, lane_width, flat_length, Color("#303b46"), LINE)


func _build_launch(lane_width: float) -> void:
	var run := LAUNCH_LIP - LAUNCH_START
	var length := Vector2(run, LAUNCH_HEIGHT).length()
	var deck := Node3D.new()
	deck.position = Vector3(lane_width, LAUNCH_HEIGHT * 0.5, -run * 0.5)
	deck.rotation.x = atan2(LAUNCH_HEIGHT, run)
	_launch.add_child(deck)
	Shapes.box(deck, Vector3(lane_width - 0.12, 0.34, length), Vector3(0, -0.13, 0), Color("#53516d"))
	var marker := Color("#ffcc68")
	for side in [-1.0, 1.0]:
		var x: float = side * (lane_width * 0.5 - 0.18)
		_glow(Shapes.box(deck, Vector3(0.18, 0.18, length), Vector3(x, 0.10, 0), marker), marker)
		for index in range(5):
			var z := length * (float(index) - 2.0) / 5.0
			var stripe := Shapes.box(deck, Vector3(0.16, 0.04, 1.45), Vector3(side * 0.48, 0.055, z), SKY_GOLD)
			stripe.rotation.y = side * deg_to_rad(42.0)
	var support_height := LAUNCH_HEIGHT - 1.5
	Shapes.box(_launch, Vector3(lane_width - 0.32, support_height, 1.3),
		Vector3(lane_width, support_height * 0.5, -run + 1.4), Color("#6f6883"))
	_sign(_launch, lane_width * 1.5 + 2.2, 77.0, "SKYWAY  >>")
	_sign(_launch, lane_width * 1.5 + 2.2, 28.0, "RIGHT LANE")
	for index in range(9):
		var side := -1.0 if index % 2 == 0 else 1.0
		_cloud(_launch, Vector3(side * (14.0 + float(index % 3) * 5.0),
			42.0 + float(index) * 6.5, -45.0 - float(index) * 19.0))


func _build_sky(section: Node3D, variant: int, lane_width: float) -> void:
	var edge := lane_width * 1.5 + 0.70
	Shapes.box(section, Vector3(edge * 2.0, 1.7, SEGMENT_LENGTH), Vector3(0, -0.9, 0), SKY_STONE.darkened(0.25))
	_build_lanes(section, lane_width, SEGMENT_LENGTH, SKY_PAVEMENT, Color("#8c591f"))
	for side in [-1.0, 1.0]:
		var x: float = side * edge
		Shapes.box(section, Vector3(0.22, 0.20, SEGMENT_LENGTH), Vector3(x, 0.56, 0), SKY_GOLD)
		for z in [-22.0, 0.0, 22.0]:
			Shapes.box(section, Vector3(0.35, 0.74, 0.35), Vector3(x, 0.34, z), SKY_STONE)
		_pillar(section, Vector3(side * (edge + 1.05), 0, -17.0))
		_cloud(section, Vector3(side * (15.0 + float(variant % 2) * 5.0), -7.5, 8.0 * side))
	if variant % 2 == 1:
		Shapes.box(section, Vector3((edge + 1.05) * 2.0 + 0.8, 0.50, 0.9),
			Vector3(0, 6.0, -17.0), SKY_STONE)
		Shapes.box(section, Vector3((edge + 1.05) * 2.0 + 0.9, 0.13, 0.96),
			Vector3(0, 6.31, -17.0), SKY_GOLD)
	_cloud(section, Vector3(float(variant - 2) * 15.0, -18.0, -15.0))


func _pillar(section: Node3D, center: Vector3) -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.31
	shaft.bottom_radius = 0.47
	shaft.height = 5.45
	shaft.radial_segments = 10
	Shapes.attach(section, shaft, center + Vector3(0, 3.0, 0), SKY_STONE)
	Shapes.box(section, Vector3(1.05, 0.42, 1.05), center + Vector3(0, 0.25, 0), SKY_STONE)
	Shapes.box(section, Vector3(0.97, 0.26, 0.97), center + Vector3(0, 5.73, 0), SKY_GOLD)


func _cloud(section: Node3D, center: Vector3) -> void:
	_foliage(section, center, Vector3(12.0, 3.3, 8.6), CLOUD)
	_foliage(section, center + Vector3(-6.0, 1.8, 2.0), Vector3(6.4, 4.2, 6.2), CLOUD)
	_foliage(section, center + Vector3(6.0, 1.2, -1.5), Vector3(8.0, 3.6, 5.8), CLOUD)


func _build_ramp(lane_width: float) -> void:
	var length := Vector2(SEGMENT_LENGTH, CAVE_DEPTH).length()
	_ramp.position.y = -CAVE_DEPTH * 0.5
	var deck := Node3D.new()
	_ramp.add_child(deck)
	deck.rotation.x = pitch_at((RAMP_START + RAMP_END) * 0.5, SEGMENT_LENGTH)
	_build_lanes(deck, lane_width, length, Color("#343045"), Color("#ffd497"))
	var portal_sign := Label3D.new()
	portal_sign.text = "CRYSTAL CAVERN"
	portal_sign.font_size = 64
	portal_sign.pixel_size = 0.007
	portal_sign.modulate = Color("#a8e1d1")
	portal_sign.position = Vector3(0, 4.0, -SEGMENT_LENGTH * 0.5 + 0.1)
	_ramp.add_child(portal_sign)
	for side in [-1.0, 1.0]:
		var edge: float = side * (lane_width * 1.5 + 0.78)
		var bank_width := 50.0 - absf(edge) - 1.4
		var bank_x: float = edge + side * (1.4 + bank_width * 0.5)
		Shapes.box(_ramp, Vector3(bank_width, CAVE_DEPTH - 0.2, SEGMENT_LENGTH), Vector3(bank_x, -0.1, 0), CAVE_ROCK)
		Shapes.box(_ramp, Vector3(bank_width, 0.2, SEGMENT_LENGTH),
			Vector3(bank_x, CAVE_DEPTH * 0.5 - 0.10, 0), Color("#749c64"))
		Shapes.box(deck, Vector3(0.46, 0.85, length), Vector3(edge, 0.25, 0), Color("#54445d"))
		var marker := Color("#ffb55c")
		for index in range(8):
			var z := length * (float(index) - 3.5) / 8.0
			_glow(Shapes.box(deck, Vector3(0.23, 0.12, 1.65), Vector3(edge, 0.72, z), marker), marker)
		for index in range(4):
			var depth_ratio := (float(index) + 1.0) / 5.0
			var ledge := Vector3(edge + side * 2.4, CAVE_DEPTH * (0.5 - depth_ratio) + 0.8,
				SEGMENT_LENGTH * (0.5 - depth_ratio))
			_foliage(_ramp, ledge, Vector3(1.65, 2.3, 4.5), CAVE_ROCK.lightened(0.08))


func _build_cave(section: Node3D, variant: int, lane_width: float) -> void:
	var edge := lane_width * 1.5 + 0.70
	var span := (edge + 7.5) * 2.0
	Shapes.box(section, Vector3(span, 0.4, SEGMENT_LENGTH), Vector3(0, -0.23, 0), CAVE_ROCK)
	Shapes.box(section, Vector3(span, CAVE_DEPTH - 11.0, SEGMENT_LENGTH),
		Vector3(0, (CAVE_DEPTH + 11.0) * 0.5, 0), CAVE_ROCK)
	_build_lanes(section, lane_width, SEGMENT_LENGTH, Color("#292637"), Color("#a8e1d1"))
	for side in [-1.0, 1.0]:
		Shapes.box(section, Vector3(4.5, 11.0, SEGMENT_LENGTH), Vector3(side * (edge + 5.2), 5.5, 0), CAVE_ROCK)
		for index in range(4):
			var z := -24.0 + float(index) * 15.0
			var x: float = side * (edge + 2.4 + float((index + variant) % 3) * 0.4)
			_foliage(section, Vector3(x + side * 1.8, 3.0, z), Vector3(2.9, 5.2, 6.9), CAVE_ROCK.lightened(0.10))
			_foliage(section, Vector3(x, 10.5, z - 4.0), Vector3(1.15, 2.5, 1.7), CAVE_ROCK.lightened(0.08))
			_crystal(section, Vector3(x, 1.2, z), side * 0.24, 2.8, Color("#3ae3cc"))
			_crystal(section, Vector3(x - side * 0.56, 0.65, z + 0.7), side * -0.35, 1.6, Color("#7c90ff"))
	for z in [-21.0, 0.0, 21.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(0, 5.0, z)
		light.light_color = Color("#a8e1ef")
		light.light_energy = 0.8
		light.omni_range = 15.0
		section.add_child(light)


func _crystal(parent: Node3D, center: Vector3, tilt: float, height: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 5
	mesh.top_radius = 0.0
	mesh.bottom_radius = height * 0.28
	mesh.height = height
	var crystal := Shapes.attach(parent, mesh, center, color)
	crystal.rotation.z = tilt
	_glow(crystal, color)


func _glow(part: MeshInstance3D, color: Color) -> void:
	var material := part.material_override as StandardMaterial3D
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.7


func _build_segment(segment: Node3D, variant: int, lane_width: float) -> void:
	var shoulder := lane_width * 1.5
	Shapes.box(segment, Vector3(100, 0.2, SEGMENT_LENGTH), Vector3(0, -0.18, 0), Color("#749c64"))
	_build_lanes(segment, lane_width, SEGMENT_LENGTH, Color("#303b46"), LINE)
	for side in [-1.0, 1.0]:
		var roadside := Node3D.new()
		segment.add_child(roadside)
		if side < 0:
			_left_shoulders.append(roadside)
		var rail_x: float = side * (shoulder + 0.94)
		Shapes.box(roadside, Vector3(0.15, 0.20, SEGMENT_LENGTH), Vector3(rail_x, 0.64, 0), METAL)
		for index in range(6):
			Shapes.box(roadside, Vector3(0.13, 0.7, 0.13), Vector3(rail_x, 0.35, -25.0 + index * 10.0), STONE)
		for index in range(4):
			var z := -24.0 + 14.0 * index + float(variant % 2) * 4.0
			var x: float = side * (shoulder + 3.1 + float((index + variant) % 3) * 1.6)
			_tree(roadside, Vector3(x, 0, z), (index + variant) % CANOPY.size())
			_foliage(roadside, Vector3(x + side * 2.4, 0.5, z - 6.0), Vector3(1.4, 0.65, 1.05), CANOPY[(index + 1) % CANOPY.size()])
		_foliage(roadside, Vector3(side * (shoulder + 18.0), -2.1, -8.0), Vector3(16.0, 8.0 + variant, 22.0), Color("#64916b"))
		var pole_x: float = side * (shoulder + 1.52)
		var pole_z: float = 13.0 if side > 0.0 else -12.0
		Shapes.box(roadside, Vector3(0.14, 5.6, 0.14), Vector3(pole_x, 2.8, pole_z), METAL)
		Shapes.box(roadside, Vector3(1.18, 0.17, 0.28), Vector3(pole_x - side * 0.52, 5.51, pole_z), METAL)
		Shapes.box(roadside, Vector3(0.52, 0.06, 0.21), Vector3(pole_x - side * 0.82, 5.39, pole_z), LINE)
	if variant % 2 == 0:
		_sign(segment, shoulder + 1.7, -22.0, "COASTAL ROUTE" if variant == 0 else "SCENIC HIGHWAY")


func _tree(parent: Node3D, position: Vector3, variant: int) -> void:
	Shapes.box(parent, Vector3(0.36, 2.5, 0.36), position + Vector3(0, 1.15, 0), Color("#664f41"))
	_foliage(parent, position + Vector3(0, 2.9, 0), Vector3(1.43, 1.77, 1.31), CANOPY[variant])
	_foliage(parent, position + Vector3(0.7, 2.62, 0.2), Vector3(0.85, 1.03, 0.85), CANOPY[variant].lightened(0.06))


func _foliage(parent: Node3D, position: Vector3, scale_factor: Vector3, color: Color) -> void:
	var shape := SphereMesh.new()
	shape.radial_segments = 7
	shape.rings = 3
	shape.radius = 1.0
	shape.height = 2.0
	var part := Shapes.attach(parent, shape, position, color)
	part.scale = scale_factor


func _sign(parent: Node3D, x: float, z: float, title: String) -> void:
	for post_x in [x - 0.75, x + 0.75]:
		Shapes.box(parent, Vector3(0.12, 2.85, 0.12), Vector3(post_x, 1.42, z), METAL)
	Shapes.box(parent, Vector3(2.60, 0.78, 0.12), Vector3(x, 2.83, z), Color("#d6ecdc"))
	Shapes.box(parent, Vector3(2.49, 0.67, 0.13), Vector3(x, 2.83, z + 0.008), Color("#195663"))
	var label := Label3D.new()
	label.text = title
	label.font_size = 44
	label.outline_size = 0
	label.pixel_size = 0.0035
	label.position = Vector3(x, 2.83, z + 0.085)
	parent.add_child(label)

