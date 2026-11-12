extends Node

signal died(reason: String)
signal hurt

const MAX_HP := 200.0

var alive := true
var hp := MAX_HP
var _cooldown := 0.0
var _quiet := 0.0


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_quiet += delta
	if alive and _quiet > 6.0 and hp < 80.0:
		hp = minf(80.0, hp + delta * 10.0)


func take_hit(amount: float) -> void:
	if not alive or _cooldown > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_cooldown = 0.18
	_quiet = 0.0
	hurt.emit()
	if hp <= 0.0:
		fatal("Ballistic Trauma")


func heal(amount: float) -> void:
	if alive:
		hp = minf(MAX_HP, hp + amount)


func fatal(reason: String) -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	died.emit(reason)
