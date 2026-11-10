extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const GOLD: Color = Color("#ce984f")
const STONE: Color = Color("#b3a2c8")
const TRIM: Color = Color("#e0cfe8")
const VELVET: Color = Color("#73374f")
const STAIR_START: float = -12.0
const STAIR_END: float = -25.5
const FLOOR_HEIGHT: float = 3.0
const DOOR_Z: float = -29.0
const HALL_END: float = -51.0

var doors: Array[Node3D] = []


static func floor_height(z: float) -> float:
	return FLOOR_HEIGHT * clampf(inverse_lerp(STAIR_START, STAIR_END, z), 0.0, 1.0)


func build(lane_width: float) -> void:
	var stair_width := lane_width * 3.0 + 1.30
	var tread := (STAIR_START - STAIR_END) / 10.0
	for index in range(10):
		var height := FLOOR_HEIGHT * float(index + 1) / 10.0
		var z := STAIR_START - (float(index) + 0.5) * tread
		Shapes.box(self, Vector3(stair_width, height, tread + 0.02), Vector3(0, height * 0.5, z), STONE)
		Shapes.box(self, Vector3(stair_width + 0.07, 0.11, 0.16),
			Vector3(0, height - 0.055, z + tread * 0.43), TRIM)
		Shapes.box(self, Vector3(2.6, 0.018, tread - 0.04), Vector3(0, height + 0.01, z), VELVET)
	var half_width := maxf(stair_width * 0.5 + 0.56, 5.9)
	var hall_depth := DOOR_Z - HALL_END
	var hall_center := (DOOR_Z + HALL_END) * 0.5
	Shapes.box(self, Vector3(half_width * 2.0, FLOOR_HEIGHT, STAIR_END - HALL_END),
		Vector3(0, FLOOR_HEIGHT * 0.5, (STAIR_END + HALL_END) * 0.5), STONE)
	Shapes.box(self, Vector3(2.65, 0.04, STAIR_END - HALL_END - 0.15),
		Vector3(0, FLOOR_HEIGHT + 0.022, (STAIR_END + HALL_END) * 0.5), VELVET)
	Shapes.box(self, Vector3(half_width * 2.0 + 0.6, 0.65, hall_depth + 0.65),
		Vector3(0, 10.15, hall_center), STONE)
	Shapes.box(self, Vector3(half_width * 2.0, 6.9, 0.55),
		Vector3(0, 6.48, HALL_END), STONE.darkened(0.22))
	for side in [-1.0, 1.0]:
		var x: float = side * half_width
		Shapes.box(self, Vector3(0.42, 6.9, hall_depth), Vector3(x, 6.48, hall_center), STONE.darkened(0.25))
		Shapes.box(self, Vector3(half_width - 2.55, 6.75, 0.72),
			Vector3(side * (half_width + 2.55) * 0.5, 6.39, DOOR_Z), STONE)
		_tower(Vector3(x - side * 0.55, FLOOR_HEIGHT, DOOR_Z + 0.40))
		for z in [-33.0, -39.0, -45.0, -49.0]:
			var pillar := Vector3(x - side * 0.43, FLOOR_HEIGHT, z)
			Shapes.box(self, Vector3(0.64, 5.8, 0.72), pillar + Vector3(0, 2.9, 0), TRIM)
			Shapes.box(self, Vector3(0.92, 0.29, 0.91), pillar + Vector3(0, 5.7, 0), GOLD)
			_lantern(pillar + Vector3(-side * 0.53, 2.66, 0.1))
		_build_door(side)
	Shapes.box(self, Vector3(5.55, 2.25, 0.9), Vector3(0, 8.64, DOOR_Z), TRIM)
	Shapes.box(self, Vector3(half_width * 2.0 + 0.3, 0.30, 1.08), Vector3(0, 9.75, DOOR_Z + 0.1), GOLD)
	for index in range(9):
		var x := (float(index) - 4.0) * half_width / 5.0
		Shapes.box(self, Vector3(0.56, 0.52, 0.67), Vector3(x, 10.73, DOOR_Z), TRIM)
	var crest := Shapes.box(self, Vector3(1.12, 1.12, 0.18), Vector3(0, 8.68, DOOR_Z + 0.55), GOLD)
	crest.rotation.z = PI * 0.25
	_throne()


func _tower(base: Vector3) -> void:
	Shapes.box(self, Vector3(2.1, 0.38, 2.25), base + Vector3(0, 0.19, 0), TRIM)
	Shapes.box(self, Vector3(1.44, 8.58, 1.55), base + Vector3(0, 4.45, 0), TRIM)
	Shapes.box(self, Vector3(1.78, 0.42, 1.91), base + Vector3(0, 8.72, 0), GOLD)
	for x in [-0.53, 0.53]:
		Shapes.box(self, Vector3(0.43, 0.63, 1.55), base + Vector3(x, 9.24, 0), TRIM)
	var banner := Shapes.box(self, Vector3(0.98, 3.30, 0.10), base + Vector3(0, 4.54, 0.84), VELVET)
	Shapes.box(banner, Vector3(0.76, 0.15, 0.12), Vector3(0, -1.38, 0.04), GOLD)


func _build_door(side: float) -> void:
	var door := Node3D.new()
	door.position = Vector3(side * 2.54, FLOOR_HEIGHT, DOOR_Z + 0.21)
	add_child(door)
	doors.append(door)
	var middle := Vector3(-side * 1.255, 2.26, 0)
	Shapes.box(door, Vector3(2.51, 4.52, 0.23), middle, Color("#52435c"))
	for y in [0.53, 2.40, 4.05]:
		Shapes.box(door, Vector3(2.48, 0.13, 0.28), Vector3(middle.x, y, 0), GOLD)
	Shapes.box(door, Vector3(0.18, 0.39, 0.19), Vector3(-side * 2.16, 1.91, 0.18), GOLD)


func _lantern(center: Vector3) -> void:
	Shapes.box(self, Vector3(0.36, 0.41, 0.41), center, GOLD)
	var light := OmniLight3D.new()
	light.position = center
	light.light_color = Color("#ffc484")
	light.light_energy = 2.15
	light.omni_range = 7.2
	add_child(light)


func _throne() -> void:
	var z := HALL_END + 1.35
	Shapes.box(self, Vector3(3.95, 0.26, 2.02), Vector3(0, FLOOR_HEIGHT + 0.13, z), TRIM)
	Shapes.box(self, Vector3(1.58, 0.45, 0.88), Vector3(0, FLOOR_HEIGHT + 0.50, z - 0.20), GOLD)
	Shapes.box(self, Vector3(1.54, 1.95, 0.24), Vector3(0, FLOOR_HEIGHT + 1.35, z - 0.58), VELVET)
	Shapes.box(self, Vector3(1.66, 0.19, 0.31), Vector3(0, FLOOR_HEIGHT + 2.39, z - 0.58), GOLD)
	_lantern(Vector3(-2.5, FLOOR_HEIGHT + 2.4, z + 0.3))
	_lantern(Vector3(2.5, FLOOR_HEIGHT + 2.4, z + 0.3))
