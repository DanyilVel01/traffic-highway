extends Node

const SAVE_PATH: String = "user://save.json"
const PRICES: Array[int] = [0, 30, 75]
const CAR_NAMES: Array[String] = ["AQUA SPRINT", "SUNSET GT", "VIOLET SPORT"]
var data: Dictionary = {"best_score": 0, "best_distance": 0, "balance": 0, "selected": 0, "unlocked": [true, false, false], "master": 0.8, "music": 0.7, "effects": 0.8, "shadows": true}

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	for key in ["best_score", "best_distance", "balance"]:
		if parsed.get(key) is int or parsed.get(key) is float:
			data[key] = maxi(0, int(parsed[key]))
	for key in ["master", "music", "effects"]:
		if parsed.get(key) is int or parsed.get(key) is float:
			data[key] = clampf(float(parsed[key]), 0.0, 1.0)
	if parsed.get("shadows") is bool:
		data.shadows = parsed.shadows
	var unlocked: Variant = parsed.get("unlocked")
	if unlocked is Array and unlocked.size() == 3:
		data.unlocked = [true, unlocked[1] == true, unlocked[2] == true]
	var selected: Variant = parsed.get("selected")
	if (selected is int or selected is float) and int(selected) >= 0 and int(selected) < 3 and data.unlocked[int(selected)]:
		data.selected = int(selected)

func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save progress: " + str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data))
