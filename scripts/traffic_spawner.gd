extends RefCounted

# Schedule passes by distance so later, faster waves cannot cut off earlier ones.
const MIN_GAP: float = 43.0
const MAX_GAP: float = 65.0
var next_arrival: float
var safe_lane: int
var rng := RandomNumberGenerator.new()


func reset(seed_value: int, sight_distance: float) -> void:
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	next_arrival = sight_distance
	safe_lane = 1


func next_wave(difficulty: float) -> Dictionary:
	var adjacent: Array[int] = []
	for lane in range(maxi(0, safe_lane - 1), mini(2, safe_lane + 1) + 1):
		adjacent.append(lane)
	safe_lane = adjacent[rng.randi_range(0, adjacent.size() - 1)]
	var lanes: Array[int] = []
	for lane in range(3):
		if lane != safe_lane:
			lanes.append(lane)
	if rng.randf() >= lerpf(0.22, 0.96, difficulty):
		lanes.remove_at(rng.randi_range(0, 1))
	var wave := {
		"arrival": next_arrival,
		"lanes": lanes,
		"safe_lane": safe_lane,
		"relative_speed": rng.randf_range(0.68, 0.85),
	}
	next_arrival += lerpf(MAX_GAP, MIN_GAP, difficulty) + rng.randf_range(0.0, 8.0)
	return wave

