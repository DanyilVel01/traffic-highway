extends Node

signal health_changed(current: float, maximum: float)
signal hit(hit_position: Vector3, impulse: Vector3)
signal died(hit_position: Vector3, impulse: Vector3)

@export_range(1.0, 500.0) var max_health: float = 100.0
var current_health: float


func _ready() -> void:
	current_health = max_health


func take_damage(amount: float, hit_position: Vector3, impulse: Vector3) -> void:
	if current_health <= 0.0 or amount <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit(hit_position, impulse)
	else:
		hit.emit(hit_position, impulse)
