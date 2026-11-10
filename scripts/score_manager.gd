extends RefCounted

var distance: float = 0.0
var coins: int = 0
var bonus: int = 0
var score: int:
	get:
		return int(distance) + bonus


func reset() -> void:
	distance = 0.0
	coins = 0
	bonus = 0


func collect_coin() -> void:
	coins += 1
	bonus += 10
