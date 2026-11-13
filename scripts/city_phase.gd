extends Node3D

const Map = preload("res://scripts/drop_city_map.gd")
const Player = preload("res://scripts/skydive_player.gd")
const NPCs = preload("res://scripts/city_npcs.gd")
const HUD = preload("res://scripts/drop_hud.gd")
const Traffic = preload("res://scripts/city_traffic.gd")
const Crowd = preload("res://scripts/city_crowd.gd")
const Places = preload("res://scripts/city_places.gd")
const Story = preload("res://scripts/city_story.gd")

signal died(reason: String)
signal shot(at: Vector3)
signal horn
signal shout
signal escaped
signal siren

var player := Player.new()
var map := Map.new()
var npcs := NPCs.new()
var hud := HUD.new()
var traffic := Traffic.new()
var crowd := Crowd.new()
var places := Places.new()
var story := Story.new()
var start := Story.Start.DROP


func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("#fff0d7")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	add_child(map)
	map.build()
	get_viewport().use_occlusion_culling = true
	player.position = Vector3(0, Player.DROP_HEIGHT, 23)
	player.velocity.y = -17.0
	add_child(player)
	add_child(traffic)
	traffic.build(player)
	add_child(places)
	places.build(player)
	add_child(crowd)
	crowd.build(player, traffic.signals, places)
	traffic.crowd = crowd
	traffic.bus_arrived.connect(crowd.bus_arrived)
	traffic.bus_taken.connect(crowd._bus_alight)
	traffic.horn.connect(horn.emit)
	crowd.shout.connect(shout.emit)
	hud.player = player
	hud.traffic = traffic
	hud.crowd = crowd
	hud.places = places
	hud.story = story
	add_child(hud)
	add_child(npcs)
	npcs.build(player, start == Story.Start.DROP)
	npcs.alert.connect(hud.notify)
	npcs.hit_confirmed.connect(hud.confirm_hit)
	npcs.ballistics.ally_blocked.connect(hud.notify.bind("Ally · hold your fire"))
	npcs.shot.connect(shot.emit)
	add_child(story)
	story.dialogue.connect(hud.say)
	story.landed.connect(npcs.dismiss_drop_allies)
	story.launched.connect(_stop_city_combat)
	story.cinematic_changed.connect(npcs.set_cinematic)
	story.cinematic_changed.connect(_on_cinematic)
	story.police_pressure.connect(npcs.set_pressure)
	story.police_pressure.connect(traffic.set_pressure)
	story.cinematic_shot.connect(shot.emit)
	story.cinema.siren.connect(siren.emit)
	traffic.siren.connect(siren.emit)
	traffic.officer_exited.connect(npcs.deploy_officer)
	story.finished.connect(_on_escape)
	story.build(player, traffic, places, start)
	player.door_requested.connect(_interact)
	player.damage.died.connect(_on_death)
	set_active(true)


func set_active(active: bool) -> void:
	player.set_enabled(active)
	hud.visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _physics_process(_delta: float) -> void:
	if story.stage == Story.Stage.LAUNCH:
		return
	player.drop_available = map.near_drop_pad(player.position)
	player.moisture = move_toward(player.moisture, map.cloud_moisture(player.position), _delta * 1.55)
	if player.position.y < -16.0:
		player.damage.fatal("Fall beyond the city limits")


func _on_death(reason: String) -> void:
	_finish_death.call_deferred(reason)


func _finish_death(reason: String) -> void:
	player.camera.fall_on_death()
	set_active(false)
	died.emit(reason)


func _on_escape() -> void:
	set_active(false)
	escaped.emit()


func _stop_city_combat() -> void:
	npcs.process_mode = Node.PROCESS_MODE_DISABLED


func _on_cinematic(value: bool) -> void:
	traffic.cinematic = value


func _interact() -> void:
	if story.can_interact():
		story.interact()
	else:
		places.interact()
