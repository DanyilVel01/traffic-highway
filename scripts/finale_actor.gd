extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const GOLD: Color = Color("#efb95d")
const SKIN: Color = Color("#d79c75")
const BOOTS: Color = Color("#25283b")
const METAL: Color = Color("#44495f")

enum Role { DRIVER, GUARD, PRINCESS }

var left_arm: Node3D
var right_arm: Node3D
var muzzle: Marker3D
var _legs: Array[Node3D] = []
var _gun: Node3D
var _mouth: MeshInstance3D


func build(role: Role, outfit: Color) -> void:
	Shapes.box(self, Vector3(0.67, 0.69, 0.38), Vector3(0, 1.25, 0), outfit)
	Shapes.box(self, Vector3(0.46, 0.46, 0.42), Vector3(0, 1.82, 0), SKIN)
	Shapes.box(self, Vector3(0.46, 0.12, 0.43), Vector3(0, 2.03, 0), METAL if role == Role.GUARD else BOOTS)
	Shapes.box(self, Vector3(0.31, 0.073, 0.023), Vector3(0, 1.87, -0.217), BOOTS)
	_mouth = Shapes.box(self, Vector3(0.13, 0.025, 0.015), Vector3(0, 1.72, -0.214), Color("#633d3b"))
	for side in [-1.0, 1.0]:
		var leg := _joint(Vector3(side * 0.19, 0.91, 0))
		_legs.append(leg)
		Shapes.box(leg, Vector3(0.26, 0.66, 0.28), Vector3(0, -0.36, 0), BOOTS)
		Shapes.box(leg, Vector3(0.27, 0.19, 0.40), Vector3(0, -0.80, -0.06), BOOTS)
	left_arm = _arm(-0.44, outfit)
	right_arm = _arm(0.44, outfit)
	match role:
		Role.DRIVER:
			_gun = Node3D.new()
			_gun.position = Vector3(0.035, -0.58, 0)
			right_arm.add_child(_gun)
			Shapes.box(_gun, Vector3(0.14, 0.34, 0.15), Vector3(0, -0.12, 0), METAL)
			muzzle = Marker3D.new()
			muzzle.position.y = -0.30
			_gun.add_child(muzzle)
			_gun.hide()
		Role.GUARD:
			Shapes.box(self, Vector3(0.52, 0.14, 0.47), Vector3(0, 2.06, 0), GOLD)
			Shapes.box(self, Vector3(0.09, 0.23, 0.30), Vector3(0, 2.21, 0), outfit)
			Shapes.box(left_arm, Vector3(0.49, 0.60, 0.12), Vector3(0, -0.39, -0.19), GOLD)
			Shapes.box(left_arm, Vector3(0.34, 0.43, 0.13), Vector3(0, -0.38, -0.22), outfit)
		Role.PRINCESS:
			Shapes.box(self, Vector3(0.78, 0.53, 0.54), Vector3(0, 0.81, 0.04), outfit)
			Shapes.box(self, Vector3(0.48, 0.43, 0.17), Vector3(0, 1.72, 0.21), Color("#7f4e37"))
			Shapes.box(self, Vector3(0.47, 0.10, 0.43), Vector3(0, 2.09, 0), GOLD)
			for x in [-0.17, 0.0, 0.17]:
				Shapes.box(self, Vector3(0.09, 0.15, 0.11), Vector3(x, 2.19, -0.14), GOLD)


func face(target: Vector3) -> void:
	var direction := target - position
	rotation.y = atan2(-direction.x, -direction.z)


func walk(t: float, start: Vector3, target: Vector3) -> void:
	position = start.lerp(target, t)
	var swing := sin(t * start.distance_to(target) * TAU / 1.65) * sin(t * PI) * 0.56
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	left_arm.rotation.x = -swing * 0.72
	right_arm.rotation.x = swing * 0.72


func aim(target: Vector3) -> void:
	face(target)
	var offset := target - position
	right_arm.rotation.x = PI * 0.5 + atan2(offset.y - 0.25, Vector2(offset.x, offset.z).length())
	_gun.show()


func lower_weapon() -> void:
	right_arm.rotation.x = 0.0
	_gun.hide()


func speak_pose(amount: float, gesture: float) -> void:
	_mouth.scale.y = 1.0 + amount * 2.6
	right_arm.rotation.x = gesture


func _joint(center: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.position = center
	add_child(joint)
	return joint


func _arm(x: float, outfit: Color) -> Node3D:
	var joint := _joint(Vector3(x, 1.55, 0))
	Shapes.box(joint, Vector3(0.22, 0.43, 0.25), Vector3(0, -0.23, 0), outfit)
	Shapes.box(joint, Vector3(0.19, 0.19, 0.19), Vector3(0, -0.53, 0), SKIN)
	return joint
