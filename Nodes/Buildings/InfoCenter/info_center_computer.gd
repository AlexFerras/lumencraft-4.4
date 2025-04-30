@tool
extends "res://Nodes/Buildings/Common/Computer/GenericComputer.gd"

@onready var info_center := get_parent() as BaseBuilding
@onready var radar = $"../Sprite2D/Sprite2D/InfoCenter002"
var target_zoom: Vector2

var releasing: bool
var no_waves: bool

var wave_id: int = -1
var current_path: int = -1

func _ready() -> void:
	Utils.game.map.wave_manager.connect("wave_started", Callable(self, "reload"))

func _make():
	if get_upcoming_wave().is_empty(): ## + inaczej to wyświetlać
		return
	
	current_path = (current_path + 1) % get_upcoming_wave().enemies.size()
	
	var from = Utils.game.map.wave_manager.show_path_from_all_info_centers(current_path)
	if from:
		var final_rot=global_position.angle_to_point(from)+ PI*0.5
		var tween = create_tween()
		tween.tween_property(radar, "global_rotation", randf_range(2.0,10.0), 1.0).set_trans(Tween.TRANS_SINE).as_relative()
		tween.tween_property(radar, "global_rotation",final_rot, 1.0).set_trans(Tween.TRANS_SINE)
		
	reload()

	#Utils.game.map.post_process.add_shockwave(info_center.global_position, sonar_range, Color(0,2,4.0,1.1))
	#Utils.play_sample("res://SFX/Building/path_sonar.wav",self,false,1.2)
	#Utils.game.map.wave_manager.show_next_path(info_center.global_position)

func _long_make():
	Utils.game.map.wave_manager.show_all_paths_from_all_info_centers()
	var tween = create_tween()
	tween.tween_property(radar, "global_rotation", randf_range(5.0,10.0), 1.0).set_trans(Tween.TRANS_SINE).as_relative()
	current_path = -1
	reload()

func _can_use() -> bool:
	return not no_waves

func _setup():
	var upcoming_wave := get_upcoming_wave()
	if upcoming_wave.is_empty():
		no_waves = true
		target_zoom = Vector2()
		
		screen.set_title("No Upcoming Waves")
		
		return
	else:
		no_waves = false
		if not Const.is_steam_deck:
			target_zoom = Vector2.ONE * 0.2
	
	if not active:
		return
	
	screen.set_display_progress(self)
	
	var new_wave_id := Utils.game.map.wave_manager.current_wave_number
	if new_wave_id != wave_id:
		wave_id = new_wave_id
		current_path = -1
	
	var encounter: Dictionary
	if current_path > -1:
		encounter = upcoming_wave.enemies[current_path]
	var description: PackedStringArray
	
	if encounter.is_empty():
		screen.set_title("No Enemy Selected")
	elif encounter.name.begins_with("Swarm"):
		var swarm: String = encounter.name.get_slice("/", 1)
		screen.set_icon(load(Const.Enemies[swarm].placeholder_sprite))
		screen.set_title(swarm)
		description.append(tr(Const.Enemies[swarm].description))
		description.append(str(tr("HP:"), " ", Const.Enemies[swarm].hp))
	else:
		screen.set_title(encounter.name)
		screen.set_icon(load(Const.Enemies[encounter.name].placeholder_sprite))
		description.append(tr(Const.Enemies[encounter.name].description))
		description.append(str(tr("HP:"), " ", Const.Enemies[encounter.name].hp))
	
	if not encounter.is_empty():
		description.append(str(tr("Count:"), " ", encounter.count))
		#screen."\n".join(set_description(description))
		screen.set_description("\n".join(description))
	
	screen.set_interact_action("Next Enemy")
	screen.set_long_action("Show All")

	if active and screen.active:
		var range_visual = info_center.range_visual
		if range_visual:
			range_visual.visible = true
			Utils.game.map.post_process.range_dirty = true
			Utils.game.map.post_process.start_build_mode(global_position)

func _uninstall():
	if screen.active:
		var range_visual=info_center.range_visual
		if range_visual:
			Utils.game.map.post_process.stop_build_mode(global_position)
			range_visual.visible = false
			Utils.game.map.post_process.range_dirty = true

func get_upcoming_wave() -> Dictionary:
	return Utils.game.map.wave_manager.wave_to_launch

func get_max_progress() -> float:
	return 0.0

func has_queue() -> bool:
	return true

func get_queue() -> Array:
	if get_upcoming_wave().is_empty():
		return []
	
	var q: Array = get_upcoming_wave().enemies.duplicate()
	if current_path > -1:
		q.erase(current_path)
	return q

func get_queue_icon(i: int) -> Texture2D:
	var q := get_queue()
	var enemy: String = q[(i + int(max(current_path, 0))) % q.size()].name
	
	if enemy.begins_with("Swarm"):
		return load(Const.Enemies[enemy.get_slice("/", 1)].placeholder_sprite) as Texture2D
	else:
		return load(Const.Enemies[enemy].placeholder_sprite) as Texture2D
