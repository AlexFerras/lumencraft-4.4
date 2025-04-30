extends RefCounted

enum {SAME_AS_WAVE, AUTO, PLAYER}

var spawners: Array
var wave_timer_label: Control
var wave_counter_label: Control

var wave_data: Array

var current_wave: int
var current_repeat: int
var current_wave_multiplier: float = 1.0
var current_wave_number: int
var active_wave_number: int

var wave_to_launch: Dictionary
var wave_countdown: float
var spawn_queue: Array

var is_spawning: bool
var started_spawning: bool
var prev_living: int

var wave_started_time: int
var spawner_markers_visible: bool
var marker_wave: int
var enemy_locator: Node

var countdown_disabled: bool

signal wave_starting
signal wave_started
signal spawn_fininished
signal wave_defeated

func setup_spawners(spw: Array):
	spawners = spw

func setup_ui(wave_timer: Control, wave_counter: Control):
	wave_timer_label = wave_timer
	wave_counter_label = wave_counter
	wave_timer_label.set_meta("text", wave_timer_label.text)
	wave_counter_label.set_meta("text", wave_counter_label.text)
	wave_counter_label.set_meta("alt_text", "Wave %s - Enemies remaining %s")

func set_custom_data(data: Array):
	wave_data = data
	next_wave()

func set_data_from_file(file: String):
	var storage := WaveStorage.new()
	storage.load_from_path(file)
	wave_data = storage.get_array()
	next_wave()

func next_wave():
	if current_wave >= wave_data.size():
		return
	
	var wave: Dictionary = wave_data[current_wave]
	launch_wave(wave)

func launch_wave(wave: Dictionary):
	SteamAPI.satisfy_achievement("WAVE_NO_ACTION")
	SteamAPI.try_achievement("WAVE_STAY_IN_BASE")
	
	current_wave_number += 1
	if current_repeat > 0:
		current_wave_multiplier *= wave.multiplier
	
	var reset_multiplier: bool
	if wave.repeat > 0 and current_repeat < wave.repeat or wave.repeat == -1:
		current_repeat += 1
	else:
		current_wave += 1
		current_repeat = 0
		reset_multiplier = true
	
	var old_wave := wave_to_launch
	wave_to_launch = wave.duplicate(true)
	
	for enemy_group in wave_to_launch.enemies:
		enemy_group.count = round(enemy_group.count * current_wave_multiplier)
	
	if not old_wave.is_empty():
		for enemy in old_wave.enemies:
			wave_to_launch.enemies.append(enemy)
	
	wave_countdown = max(wave_to_launch.wait_time, 0.0001) * (1.1 if Save.is_tech_unlocked("wave_delay_upgrade") else 1.0)
	
	if reset_multiplier:
		current_wave_multiplier = 1.0



var C=1.04413
var D=1.17200
var G5=0.78221
var E=1.31552
var G=1.56442
var F=1.39374
var B5=0.98553
var A5=0.878

var current_note=0                                                                                                               
var notes=[C, D, G5, D, E, G, F, E, C, D, B5, G5, A5, C, C, D, G5, D, E, G, F, E, C, D, B5, C, C]
var tim=[ 1.5, 1.5, 1, 1.5, 1.5, 0.25, 0.25, 0.5, 1.5, 2.5, 2.0+0.5, 0.5, 0.25, 0.75, 1.5, 1.5, 1, 1.5, 1.5, 0.25, 0.25, 0.5, 1.5, 2.5, 0.5, 0.5, 1+2]
var tempo=0.526
var tim_las=0.0
var tim_er=0.0
var last_sonar=0

func show_path_from_all_info_centers(selected_path: int) -> Vector2:
	var info_centers=Utils.get_tree().get_nodes_in_group("info_center")
	var make_shockwave=false
	if last_sonar+50<Utils.game.frame_from_start:
		last_sonar=Utils.game.frame_from_start
		make_shockwave=true
		
	var timing=float(Utils.game.frame_from_start-tim_las)/60
	
	if timing>2:
		current_note=0
		tim_er=0
	
	if current_note > 0:
		var tic=tim[current_note]*tempo-timing
		tim_er+=abs(tic)
	tim_las=Utils.game.frame_from_start

	#blink from all info centers
	for cen in info_centers:
		Utils.play_sample("res://SFX/Building/path_sonar.wav",cen,false,1.0,notes[current_note]*0.7)
		
		if make_shockwave:
			Utils.game.map.post_process.add_shockwave(cen.global_position, cen.max_range, Color(0,1,1.0,1.1))

	current_note+=1
	if current_note>=notes.size():
		current_note=0
		tim_er=0
	
	if current_note>10:
		if tim_er<3:
			SteamAPI.unlock_achievement("RICK_ROLL")
			tim_er=0
		else:
			current_note=0
			tim_er=0
		
	var enemy_group = wave_to_launch.enemies[selected_path]

#	var previous_paths = enemy_group.get("paths")
#	if previous_paths:
#		for i in previous_paths:
#			if is_instance_valid(i):
#				i.queue_free()
	
	Utils.get_tree().call_group("path_minimap", "deselect")
	
	var spawner_idx: int = enemy_group.get("spawner", -1)
	if spawner_idx == -1:
		if spawners.size() == 1:
			spawner_idx = 0
		else:
			return Vector2()

	var enemy_is_swarm = false
	var what_to_instance: String
	if enemy_group.name.begins_with("Swarm"):
		enemy_is_swarm = true
		what_to_instance = Const.Enemies[enemy_group.name.get_slice("/", 1)].scene
	else:
		what_to_instance = Const.Enemies[enemy_group.name].scene
	
	var enemy_or_swarm = Utils.temp_instance(load(what_to_instance))
	if !enemy_or_swarm.has_method("get_pathfinding_params"):
		return Vector2()
	
	var mob_radius=10.0
	if enemy_or_swarm.has_method("get_enemy_radius"):
		mob_radius=enemy_or_swarm.get_enemy_radius()
	var mob_radius_minimap=min(mob_radius*5.0,30.0)
		
	var from = spawners[spawner_idx].global_position
	var to_target = Utils.game.main_player.global_position if enemy_group.get("target", AUTO) == PLAYER or not is_instance_valid(Utils.game.core) else Utils.game.core.global_position
	var params: Array = enemy_or_swarm.get_pathfinding_params()
	params.append(from)
	var path: PathfindingResultData
	if enemy_is_swarm:
		path = PathFinding.get_path_from_params(to_target, from, params[0],params[1], params[2])
	else:
		path =PathFinding.get_path_any_from_to_position(from,to_target, params[2],false)
		#path = PathFinding.get_path_from_params(from, to_target, params[0],params[1], params[2])
	if !path:
		return from
	var array := path.get_path()
	if enemy_is_swarm:
		array.reverse()

	var acc_paths=[]
	enemy_group["paths"]=acc_paths
	for cen in info_centers:
		#small minimap
		var line2d: Line2D = preload("res://Nodes/Map/MapMarker/path_minimap.tscn").instantiate()
		line2d.setup(cen.global_position,to_target,cen.max_range, mob_radius_minimap, Utils.game.ui.minimap.get_view_scale()*Vector2.ONE,array)
		Utils.game.ui.minimap.add_child(line2d)
		
		#large minimap
		var line2d2=line2d.duplicate()
		line2d2.setup(cen.global_position,to_target,cen.max_range, mob_radius_minimap,Utils.game.ui.full_map.minimap.get_view_scale()*Vector2.ONE,array)
		Utils.game.ui.full_map.minimap.add_child(line2d2)
		
		#world
		var line2d3=preload("res://Nodes/Map/MapMarker/path_world.tscn").instantiate()
		line2d3.setup(cen.global_position,to_target,cen.max_range,mob_radius, Vector2.ONE,array)
		Utils.game.map.add_child(line2d3)


		acc_paths.append_array([line2d,line2d2,line2d3])

	return from


func show_all_paths_from_all_info_centers():
	var info_centers=Utils.get_tree().get_nodes_in_group("info_center")
	
	#blink from all info centers
	for cen in info_centers:
		Utils.play_sample("res://SFX/Building/path_sonar.wav",cen,false,1.2)
		Utils.game.map.post_process.add_shockwave(cen.global_position, cen.max_range, Color(0,1,1.0,1.1))
	
	Utils.get_tree().call_group("path_minimap", "deselect")
	for enemy_group in wave_to_launch.enemies:
		

		var spawner_idx: int = enemy_group.get("spawner", -1)
		if spawner_idx == -1:
			if spawners.size() == 1:
				spawner_idx = 0
			else:
				return
		
		var enemy_is_swarm = false
		var what_to_instance: String
		if enemy_group.name.begins_with("Swarm"):
			enemy_is_swarm = true
			what_to_instance = Const.Enemies[enemy_group.name.get_slice("/", 1)].scene
		else:
			what_to_instance = Const.Enemies[enemy_group.name].scene
		var enemy_or_swarm = Utils.temp_instance(load(what_to_instance))
		if !enemy_or_swarm.has_method("get_pathfinding_params"):
			return
		
		var mob_radius=10.0
		if enemy_or_swarm.has_method("get_enemy_radius"):
			mob_radius = enemy_or_swarm.get_enemy_radius()
		
		var mob_radius_minimap = min(mob_radius*5.0,30.0)
		var from = spawners[spawner_idx].global_position
		var to_target = Utils.game.main_player.global_position if enemy_group.get("target", AUTO) == PLAYER or not is_instance_valid(Utils.game.core) else Utils.game.core.global_position
		var params: Array = enemy_or_swarm.get_pathfinding_params()
		params.append(from)
		var path: PathfindingResultData
		if enemy_is_swarm:
			path = PathFinding.get_path_from_params(to_target, from, params[0],params[1], params[2])
		else:
			path =PathFinding.get_path_any_from_to_position(from,to_target, params[2],false)
			#path = PathFinding.get_path_from_params(from, to_target, params[0],params[1], params[2])
		if !path:
			continue
		var array := path.get_path()
		if enemy_is_swarm:
			array.reverse()
		
		var acc_paths=[]
		enemy_group["paths"]=acc_paths
		for cen in info_centers:
			#small minimap
			var line2d: Line2D = preload("res://Nodes/Map/MapMarker/path_minimap.tscn").instantiate()
			line2d.setup(cen.global_position,to_target,cen.max_range,mob_radius_minimap, Utils.game.ui.minimap.get_view_scale()*Vector2.ONE,array,false)
			Utils.game.ui.minimap.add_child(line2d)
			
			#large minimap
			var line2d2=line2d.duplicate()
			line2d2.setup(cen.global_position,to_target,cen.max_range,mob_radius_minimap, Utils.game.ui.full_map.minimap.get_view_scale()*Vector2.ONE,array,false)
			Utils.game.ui.full_map.minimap.add_child(line2d2)
			
			#world
			var line2d3=preload("res://Nodes/Map/MapMarker/path_world.tscn").instantiate()
			line2d3.setup(cen.global_position,to_target,cen.max_range,mob_radius, Vector2.ONE,array,false)
			Utils.game.map.add_child(line2d3)
			
			acc_paths.append_array([line2d,line2d2,line2d3])

func process(delta: float):

	var living := get_living_enemy_count()
	if living != prev_living:
		wave_counter_label.visible = living > 0
		var total_waves := get_total_wave_count()
		if total_waves > 0:
			wave_counter_label.text = tr(wave_counter_label.get_meta("text")) % [active_wave_number, total_waves, living]
		else:
			wave_counter_label.text = tr(wave_counter_label.get_meta("alt_text")) % [active_wave_number, living]
		
		if not has_active_wave():
			if Utils.game.battle_timer.is_stopped():
				Utils.game.stop_battle()
			
			Utils.get_tree().create_timer(0.1).connect("timeout", Callable(self, "emit_signal").bind("wave_defeated"))
			
			var wave_notify := current_wave_number
			if not is_finished():
				wave_notify -= 1
			Utils.notify_event("wave_defeated", wave_notify)
			
			Utils.log_message("Wave defeated")
			SteamAPI.try_achievement("WAVE_NO_ACTION")
			
			
			if spawner_markers_visible:
				hide_markers()
			
			if enemy_locator:
				enemy_locator.queue_free()
				enemy_locator = null
	
	if living > 0:
		if not enemy_locator and living <= 100 and Time.get_unix_time_from_system() - wave_started_time > 60:
			enemy_locator = preload("res://Nodes/Objects/Helper/EnemyLocator.tscn").instantiate()
			enemy_locator.wave_only = true
			Utils.game.map.add_child(enemy_locator)
	
	if is_spawning and started_spawning:
		is_spawning = false
		
		for spawner in Utils.get_tree().get_nodes_in_group("wave_spawners"):
			if spawner.is_spawning():
				is_spawning = true
				break
		
		if not is_spawning:
			free_save()
			started_spawning = false
			emit_signal("spawn_fininished") ## czemu to się wysyła zaraz po wczytaniu ???
			SteamAPI.satisfy_achievement("WAVE_STAY_IN_BASE")
			
	prev_living = living
	if wave_to_launch.is_empty():
		if spawner_markers_visible and Time.get_unix_time_from_system() - wave_started_time > 60:
			hide_markers()
		
		return
	
	if not spawner_markers_visible:
		show_markers()
	
	if wave_countdown > 0:
		wave_timer_label.visible = wave_countdown > 0 and not Utils.game.ui.is_ui_hidden() and not countdown_disabled
		if not Utils.get_tree().paused and wave_timer_label.is_visible_in_tree():
			var seconds :int= ceil(wave_countdown)
			
			if not countdown_disabled:
				wave_countdown -= delta
			
			if wave_countdown < 60:
				wave_timer_label.modulate.g = wave_countdown * 0.0166667
				wave_timer_label.modulate.b = wave_countdown * 0.0166667
			else:
				wave_timer_label.modulate = Color.WHITE
			
			wave_timer_label.text = tr(wave_timer_label.get_meta("text")) % [current_wave_number, int(ceil(wave_countdown) / 60), fmod(seconds, 60)]
			if wave_countdown <= 10 and ceil(wave_countdown) < seconds:
				Utils.play_sample(preload("res://SFX/UI/Countdown.wav")).volume_db = -10
			
			if seconds == 60 and ceil(wave_countdown) < seconds:
				Utils.game.ui.evil_notify("Enemy wave arrives soon", 5, Color.RED)
			elif seconds == 7 and ceil(wave_countdown) < seconds:
				Utils.game.shake(2,10)
#				Utils.game.shake(4)
				Utils.play_sample("res://SFX/Environmnent/earthquake.wav",null,false,1.3)
			
			if wave_countdown <= 0:
				Utils.log_message("Wave %s started" % current_wave_number)
				wave_timer_label.hide()
				
				emit_signal("wave_starting")
				Utils.game.ui.evil_notify("Enemies approaching!")
				is_spawning = true
				Save.block_save_by("spawning")
				Utils.get_tree().create_timer(10.0, false).connect("timeout", Callable(self, "free_save"))
				if not Utils.game.disable_music:
					Music.swap_track("wave")
				
				wave_started_time = Time.get_unix_time_from_system()
				
				if current_repeat < 2 and not wave_to_launch.get("wave_name", "").is_empty():
					Utils.game.ui.display_wave_name(current_wave_number, wave_to_launch.wave_name)
			
			if spawner_markers_visible and marker_wave < current_wave_number and seconds <= wave_to_launch.wait_time * 0.75:
				hide_markers()
	else:
		active_wave_number = current_wave_number
		var stop_spawn := true
		
		for enemy_group in wave_to_launch.enemies:
			if enemy_group.get("delay", 0.0) > 0:
				enemy_group.delay -= delta
				stop_spawn = false
				continue
			
			if enemy_group.count > 0:
				queue_spawn(enemy_group)
				stop_spawn = false
				break
		
		if stop_spawn:
			emit_signal("wave_started")
			wave_to_launch = {}
			
			next_wave()
	
	for spawn_data in spawn_queue:
		if do_spawn(spawn_data):
			spawn_queue.erase(spawn_data)
			break

func queue_spawn(group: Dictionary):
	started_spawning = true
	var spawn_data: Dictionary
	
	if group.name.begins_with("Swarm"):
		spawn_data.swarm = true
		spawn_data.scene = Const.Enemies[group.name.get_slice("/", 1)].scene
		spawn_data.count = group.count
		var spawn_resource_rand_mod = group.get("spawn_resource_rand_mod")
		if spawn_resource_rand_mod is int:
			spawn_data.spawn_resource_rand_mod = spawn_resource_rand_mod
		group.count = 0
	else:
		spawn_data.scene = Const.Enemies[group.name].scene
		var spawn_resource_rand_mod = group.get("spawn_resource_rand_mod")
		if spawn_resource_rand_mod is int:
			spawn_data.spawn_resource_rand_mod = spawn_resource_rand_mod
		group.count -= 1
	
	var spawner_idx: int = group.get("spawner", -1)
	if spawner_idx == -1:
		spawner_idx = randi() % spawners.size()
	spawn_data.spawner = spawner_idx
	
	spawn_data.target = group.get("target", AUTO)
	spawn_queue.append(spawn_data)

func do_spawn(spawn_data: Dictionary) -> bool:
	if not spawners[spawn_data.spawner].can_spawn():
		return false
	
	if spawn_data.get("swarm"):
		var swarm := load(spawn_data.scene).instantiate() as Swarm
		
		swarm.how_many = spawn_data.count
		swarm.prioritize_player = spawn_data.target == PLAYER

		var spawn_resource_rand_mod = spawn_data.get("spawn_resource_rand_mod")
		if spawn_resource_rand_mod is int:
			swarm.probability_spawn_resource = spawn_resource_rand_mod
		
		var spawner = spawners[spawn_data.spawner]
		spawner.spawn_swarm(swarm)
	else:
		var enemy: Node2D = load(spawn_data.scene).instantiate()
		
		enemy.set_meta("_wave_target_", spawn_data.target)
		
		var spawn_resource_rand_mod = spawn_data.get("spawn_resource_rand_mod")
		if spawn_resource_rand_mod is int:
			enemy.probability_spawn_resource = spawn_resource_rand_mod
		
		var spawner = spawners[spawn_data.spawner]
		spawner.spawn_enemy(enemy)
	
	return true

func has_active_wave() -> bool:
	return is_spawning or not spawn_queue.is_empty() or get_living_enemy_count() > 0

func should_play_wave_music() -> bool:
	return has_active_wave() and Time.get_unix_time_from_system() - wave_started_time < 60

func is_finished() -> bool:
	return current_wave >= wave_data.size() and not has_active_wave() and wave_to_launch.is_empty()

func get_current_wave() -> int:
	return current_wave_number

func skip_waves(how_many: int):
	for i in how_many:
		next_wave()

func get_living_enemy_count() -> int:
	var count: int
	
	for enemy in Utils.get_tree().get_nodes_in_group("__wave_enemies__"):
		if enemy is BaseEnemy and not enemy.is_dead:
			count += 1
		elif enemy is Swarm:
			count += enemy.getNumOfLivingUnits()
	
	return count

func get_total_wave_count() -> int:
	var total: int
	for wave in wave_data:
		if wave.repeat == -1:
			return -1
		else:
			total += wave.repeat + 1
	return total

func free_save():
	Save.block_save.erase("spawning")

func _get_save_data() -> Dictionary:
	var data: Dictionary
	if not wave_data.is_empty():
		data = Save.get_properties(self, ["is_spawning", "wave_data", "current_wave", "current_repeat", "current_wave_multiplier", "current_wave_number", "wave_to_launch", "wave_countdown", "spawn_queue", "active_wave_number"])
	return data

func _set_save_data(data: Dictionary):
	Save.set_properties(self, data)

func hide_markers():
	for spawner in spawners:
		spawner.marker.hide()
	spawner_markers_visible = false

func show_markers():
	spawner_markers_visible = true
	marker_wave = current_wave_number
	
	var known: Array
	var is_random: bool
	
	for encounter in wave_to_launch.enemies:
		if encounter.get("spawner", -1) >= 0:
			known.append(encounter.spawner)
		elif spawners.size() == 1:
			known.append(0)
		else:
			is_random = true
	
	if spawners.is_empty():
		await Utils.game.map_initialized
	
	for idx in spawners.size():
		var spawner = spawners[idx]
		var is_known: bool = idx in known
		spawner.set_random_marker(not is_known)
		spawner.marker.visible = is_random or is_known or spawners.size() == 1

class WaveStorage extends TextDatabase:
	func _initialize() -> void:
		add_mandatory_property("wait_time", TYPE_INT)
		add_mandatory_property("enemies", TYPE_ARRAY)
		add_valid_property("wave_name", TYPE_STRING)
		add_valid_property_with_default("target", 0)
		add_valid_property_with_default("repeat", 0)
		add_valid_property_with_default("multiplier", 1.0)

	func _postprocess_entry(entry: Dictionary) -> void:
		for enemy in entry.enemies:
			if enemy.name in Const.Enemies:
				continue
			
			if enemy.name.begins_with("Swarm/"):
				if enemy.name.get_slice("/", 1) in Const.Enemies:
					continue
			
			assert(false, "Nieprawidłowy wróg: " + enemy.name)
