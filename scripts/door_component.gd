extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
signal changed(open: bool)

var opened := false
var _hinge := AnimatableBody3D.new()
var _animation: Tween
var _hold := 0.0


func build(paint: Color) -> void:
	add_child(_hinge)
	_hinge.collision_layer = 8
	_hinge.collision_mask = 0
	_hinge.sync_to_physics = false
	Shapes.box(_hinge, Vector3(1.36, 2.40, 0.13), Vector3(0.68, 1.20, 0), paint)
	Shapes.box(_hinge, Vector3(0.81, 0.92, 0.14), Vector3(0.68, 1.65, 0), Color("#7b9aa4"))
	Shapes.box(_hinge, Vector3(0.18, 0.08, 0.19), Vector3(1.12, 1.05, 0.08), Color("#e1c17f"))
	var hitbox := CollisionShape3D.new()
	var panel := BoxShape3D.new()
	panel.size = Vector3(1.36, 2.40, 0.14)
	hitbox.shape = panel
	hitbox.position = Vector3(0.68, 1.20, 0)
	_hinge.add_child(hitbox)


func interact() -> void:
	_hold = 0.0
	_set_open(not opened)


func open_for(seconds: float) -> void:
	_hold = maxf(_hold, seconds)
	_set_open(true)


func _physics_process(delta: float) -> void:
	if _hold <= 0.0:
		return
	_hold -= delta
	if _hold <= 0.0:
		_set_open(false)


func _set_open(value: bool) -> void:
	if opened == value:
		return
	opened = value
	if is_instance_valid(_animation):
		_animation.kill()
	_animation = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_trans(Tween.TRANS_SINE)
	_animation.tween_property(_hinge, "rotation:y", 1.49 if opened else 0.0, 0.38)
	changed.emit(opened)
