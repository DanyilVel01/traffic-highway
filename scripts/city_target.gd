extends Area3D

const Health = preload("res://scripts/health_component.gd")
const Actor = preload("res://scripts/finale_actor.gd")
const HOSTILE := 32
const CIVILIAN := 128
const ALLY := 256
const PEOPLE := HOSTILE | CIVILIAN | ALLY

var actor: Actor
var health: Health
var _faction: int
var _flinch: Tween


func bind(model: Actor, faction: int, size: Vector3) -> void:
	actor = model
	_faction = faction
	collision_layer = faction
	collision_mask = 0
	monitoring = false
	monitorable = false
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position.y = size.y * 0.5
	add_child(collider)
	if faction == ALLY:
		return
	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.hit.connect(_react)
	health.died.connect(_fall)


func set_targetable(active: bool) -> void:
	collision_layer = _faction if active else 0


func strike(at: Vector3, direction: Vector3) -> bool:
	if not health:
		return false
	var amount := 100.0 if at.y - global_position.y >= (1.60 if _faction == HOSTILE else 1.42) else 58.0
	health.take_damage(amount, at, direction * 3.6)
	return health.current_health <= 0.0


func _react(_at: Vector3, _impulse: Vector3) -> void:
	if is_instance_valid(_flinch):
		_flinch.kill()
	_flinch = create_tween()
	_flinch.tween_property(actor, "rotation:z", -0.20, 0.075)
	_flinch.tween_property(actor, "rotation:z", 0.0, 0.19)


func _fall(_at: Vector3, impulse: Vector3) -> void:
	collision_layer = 0
	if is_instance_valid(_flinch):
		_flinch.kill()
	if not actor.visible:
		actor.queue_free()
		queue_free()
		return
	var corpse := Node3D.new()
	get_parent().add_child(corpse)
	corpse.global_position = global_position
	actor.reparent(corpse)
	var collapse := corpse.create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var axis := Vector3.UP.cross(impulse).normalized()
	collapse.tween_property(corpse, "quaternion", Quaternion(axis if axis != Vector3.ZERO else Vector3.RIGHT, 1.48), 0.42)
	collapse.tween_property(corpse, "global_position", corpse.global_position + impulse * 0.16 + Vector3.UP * 0.18, 0.42)
	collapse.chain().tween_callback(corpse.queue_free).set_delay(8.0)
	queue_free()
