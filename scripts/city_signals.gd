extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const Region = preload("res://scripts/region_terrain.gd")
const RED := Color("#ed5053")
const GREEN := Color("#65df90")
const BUS_SHELTERS: Array[Vector3] = [Vector3(22, 0, 7), Vector3(-58, 0, 33)]
var _lamps: Array[Dictionary] = []
var _clock := 0.0
var _update := 0.0


func build() -> void:
	var posts: Array[Transform3D] = []
	for city in [0.0, Region.CITY_DISTANCE]:
		for x in range(-3, 4):
			for z in range(-3, 4):
				var point := Vector3(city + x * 40.0, 0, z * 40.0)
				var post := point + Vector3(6.15, 0, 6.12)
				posts.append(Transform3D(Basis.from_scale(Vector3(0.12, 4.1, 0.12)), post + Vector3.UP * 2.05))
				var east := Shapes.box(self, Vector3(0.26, 0.32, 0.30), post + Vector3(-0.2, 3.91, 0), RED)
				var north := Shapes.box(self, Vector3(0.26, 0.32, 0.30), post + Vector3(0.0, 3.91, -0.22), RED)
				_lamps.append({"point": point, "east": east, "north": north})
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#47565d")
	var mesh := BoxMesh.new()
	mesh.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = posts.size()
	for index in posts.size():
		batch.set_instance_transform(index, posts[index])
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = batch
	add_child(visual)


func _process(delta: float) -> void:
	_clock += delta
	_update -= delta
	if _update > 0.0:
		return
	_update = 0.24
	for lamp in _lamps:
		var state := phase(lamp.point)
		var east: MeshInstance3D = lamp.east
		var north: MeshInstance3D = lamp.north
		east.material_override = _color_material(GREEN if state == 0 else RED)
		north.material_override = _color_material(GREEN if state == 1 else RED)


func _color_material(color: Color) -> Material:
	if not Shapes.materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		Shapes.materials[color] = material
	return Shapes.materials[color]


func phase(point: Vector3) -> int:
	var offset := (roundi(point.x / 40.0) + roundi(point.z / 40.0)) * 1.6
	var cycle := fposmod(_clock + offset, 20.0)
	return 0 if cycle < 7.0 else (1 if cycle < 14.0 else 2)


func red_ahead(at: Vector3, forward: Vector3, speed: float) -> bool:
	if at.x > 155.0 and at.x < Region.CITY_DISTANCE - 155.0:
		return false
	var distance_needed := maxf(10.3, speed * speed / 22.0 + 5.0)
	var probe := at + forward * minf(distance_needed * 0.65, 18.0)
	var junction := Vector3(snappedf(probe.x, 40.0), 0, snappedf(probe.z, 40.0))
	var distance := (junction - at).dot(forward)
	var lateral := absf((junction - at).cross(forward).y)
	var axis := 0 if absf(forward.x) > absf(forward.z) else 1
	return distance > 1.4 and distance < distance_needed and lateral < 4.4 and phase(junction) != axis
