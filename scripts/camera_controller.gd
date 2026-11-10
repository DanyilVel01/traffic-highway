extends Camera3D


func _ready() -> void:
	current = true
	reset()


func reset() -> void:
	position = Vector3(0, 5.0, 10.2)
	rotation_degrees.x = -15.5
	fov = 58.0


func follow(delta: float, player_x: float, difficulty: float, road_height: float, road_pitch: float) -> void:
	position.x = lerpf(position.x, player_x * 0.35, 1.0 - exp(-delta * 3.0))
	position.y = 5.0 + road_height
	rotation.x = lerpf(rotation.x, deg_to_rad(-15.5) + road_pitch * 0.65, 1.0 - exp(-delta * 7.0))
	fov = lerpf(fov, 58.0 + 6.0 * difficulty, 1.0 - exp(-delta * 2.5))

