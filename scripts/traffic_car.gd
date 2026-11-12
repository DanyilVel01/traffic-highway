extends Area3D

const VehicleVisual = preload("res://scripts/vehicle_visual.gd")
const InsectVisual = preload("res://scripts/insect_visual.gd")
const ChariotVisual = preload("res://scripts/chariot_visual.gd")
const PlayerCar = preload("res://scripts/player_car.gd")
const LENGTHS: Array[float] = [3.7, 5.0, 6.2]
const HEIGHTS: Array[float] = [1.2, 2.0, 2.6]
const WIDTH: float = 1.8
enum Style { CAR, INSECT, CHARIOT }

var style: Style
var relative_speed: float
var length: float
var passed: bool
var near_miss: bool
var wheels: Array[Node3D] = []
var insect: InsectVisual
var pursuit_gap: int = 0


func build(kind: int, color: Color, factor: float, traffic_style: Style = Style.CAR) -> void:
	name = "Traffic"
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	relative_speed = factor
	style = traffic_style
	length = LENGTHS[kind]
	var height := HEIGHTS[kind]
	if style == Style.CHARIOT:
		height = maxf(height, 1.9)
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, height, length)
	var hitbox := CollisionShape3D.new()
	hitbox.shape = shape
	hitbox.position.y = height * 0.5 + 0.25
	add_child(hitbox)
	match style:
		Style.INSECT:
			insect = InsectVisual.new()
			add_child(insect)
			insect.build(length, height, color)
		Style.CHARIOT:
			wheels = ChariotVisual.create(self, length, height, color)
		Style.CAR:
			var visual := VehicleVisual.create(self, kind, color)
			wheels = VehicleVisual.find_wheels(visual)


func advance(travel: float, player_x: float, oncoming_travel: float = 0.0) -> int:
	position.z += travel * relative_speed
	for wheel in wheels:
		wheel.rotate_x((travel * (1.0 - relative_speed) + oncoming_travel) / 0.36)
	if insect:
		insect.step(travel * (1.0 - relative_speed))
	if passed:
		return 0
	if absf(position.z) < (length + PlayerCar.LENGTH) * 0.5:
		var clearance := absf(position.x - player_x) - (WIDTH + PlayerCar.WIDTH) * 0.5
		near_miss = near_miss or (clearance >= 0.0 and clearance < 1.2)
	if position.z > 5.5:
		passed = true
		return 35 if near_miss else 25
	return 0

