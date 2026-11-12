extends RefCounted

enum Type { ASPHALT, CURB, DIRT, GRASS }
const GRIP: Array[float] = [1.0, 0.88, 0.69, 0.58]
static var _materials: Dictionary = {}


static func set_surface(body: StaticBody3D, type: Type) -> void:
	if not _materials.has(type):
		var material := PhysicsMaterial.new()
		material.friction = GRIP[type]
		material.rough = true
		_materials[type] = material
	body.physics_material_override = _materials[type]
	body.set_meta(&"grip", GRIP[type])


static func bevel(width: float, length: float, bottom: float, top: float, shoulder: float) -> ConvexPolygonShape3D:
	var points := PackedVector3Array()
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			points.append(Vector3(x * width * 0.5, bottom, z * length * 0.5))
			points.append(Vector3(x * (width * 0.5 - shoulder), top, z * (length * 0.5 - shoulder)))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	shape.margin = 0.016
	return shape
