extends Node2D
class_name Game

@onready var ui := $UI as GameUI
@onready var ui2: GameUI
@onready var camera_target := $CameraTarget as Node2D
var second_viewport: SubViewport

var main_player: Player
var camera: Camera2D
var camera2: Camera2D
var core: BaseBuilding

var map_to_load
var sandbox_options: Dictionary

var respawn_point: Node2D
var stairs_id := -1

var map: Map
var map_cache: Dictionary
var camera_shakes: Array
var shindeiru: bool

var is_shaking :bool= false
@export var shake_curve: Curve

var pickable_destruction_queue: Array

var time_from_start: float = 0.0
var frame_from_start: int = 0
var frame_this_cycle: int = 0
const frame_cycle_length: int = 192 # this is for blinking lights

# play statistics
var fps_history := [0.0]
var fps_max := -INF
var fps_max_per_minute := -INF
var fps_min := INF
var fps_min_per_minute := INF
var scraps_history := [0]
var scraps_collected_per_second :float = 0.0
@export var scraps_collected_total :float = 0.0
var scraps_average_per_minute :float = 0.0

var lumens_history := [0]
var lumens_collected_per_second :float = 0.0 
@export var lumens_collected_total :float = 0.0 
var lumens_average_per_minute :float = 0.0
# play statistics -------------------------

#var enemy_test_stats # node to collect enemy power test data

# screen size ---------------------
var resolution_of_visible_rect := Vector2.ZERO
var screen_diagonal := 0.0
var screen_diagonal_radius := 0.0
var screen_diagonal_radius_scaled := 0.0
# ---------------------------------

var loading_counter := 0.0
var extra_turrets: int

var battle_timer: Timer
var last_base_attack_notify_time: int = -999999
var players: Array
var building_queue: Array ## TODO: powinno być w mapie raczej / wgl czy tu jest leak?
var cutscene: Cutscene
var near_base: bool: set = set_near_base

var lol_scale = 1.0 ## UI scaling
var disable_music: bool
var initialized: bool

signal map_pre_instance(map)
signal map_changed
signal map_initialized
signal game_overd
signal diagonal_changed

func _init() -> void:
	Utils.game = self
	
	if OS.has_feature("debug"):
		var debug = load("res://Tools/DebugPanel.tscn").instantiate()
		add_child(debug)
		
		if Utils.get_meta("show_quad_tree", false):
			debug.get_node("StaticCL/Drawer").draw_pm_qt = true

func _ready() -> void:
	get_viewport().connect("size_changed", Callable(self, "on_window_resized"))
	battle_timer = Timer.new()
	battle_timer.one_shot = true
	battle_timer.wait_time = 10
	battle_timer.connect("timeout", Callable(self, "stop_battle"))
	add_child(battle_timer)
	get_tree().set_auto_accept_quit(false)
	
	main_player = load("res://Nodes/Player/Player.tscn").instantiate()
	players.append(main_player)
	connect("map_changed", Callable(self, "finalize_main_player").bind(), CONNECT_ONE_SHOT)
	
	camera = GameCamera.new()
	add_child(camera)
	camera.target_zoom = Vector2.ONE / Const.CAMERA_ZOOM
	camera.zoom = Vector2.ONE / Const.CAMERA_ZOOM
	camera.current_zoom_index = 2
	
	second_viewport = get_node_or_null("Viewport2")
	if get_second_viewport():
		camera.set_target(main_player)
		
		camera2 = GameCamera.new()
		get_second_viewport().add_child(camera2)
		camera2.current = true
		camera2.target_zoom = Vector2.ONE / Const.CAMERA_ZOOM
		camera2.zoom = Vector2.ONE / Const.CAMERA_ZOOM
		camera2.current_zoom_index = 2
		
		ui2 = get_second_viewport().get_node("UI")
		ui2.get_player_ui(1).hide()
	else:
		camera.set_target(camera_target)
	
	ui.get_player_ui(1).get_node("Indicator").hide()
	
	if CustomRunner.is_custom_running():
		map_to_load = CustomRunner.get_variable("scene")
	
	if map_to_load:
		goto_map(map_to_load)
		map_to_load = ""
	
	RenderingServer.set_default_clear_color(Color.BLACK)

func on_window_resized():
	if is_nan(get_window().get_size().x) or is_nan(get_window().get_size().y):
		return
	update_screen_diagonal()

func update_screen_diagonal():
	resolution_of_visible_rect = get_viewport_rect().size
	screen_diagonal = resolution_of_visible_rect.length()
	screen_diagonal_radius = screen_diagonal / 2.0
	screen_diagonal_radius_scaled = screen_diagonal_radius * camera.zoom.x
	emit_signal("diagonal_changed")
	
#	prints(resolution_of_visible_rect, screen_diagonal, screen_diagonal_radius, screen_diagonal_radius_scaled)
	
#	prints(resolution_of_visible_rect, get_viewport().get_visible_rect().size)
	
#	Save.save_config()
	
func _physics_process(delta: float) -> void:
	if not map:
		return
	count_frame_and_game_time(delta)
	# DEBUG MUCH
	if not (frame_from_start % 3600):
		
		fps_history[fps_history.size()-1] /= 60.0
		
		Utils.log_message("FPS (avg:%s, min:%s, max:%s), Metal:%s(+%s), Lumen:%s(+%s)" % [floor(fps_history[fps_history.size()-1]),fps_min_per_minute, fps_max_per_minute, scraps_collected_total, floor(scraps_history[scraps_history.size()-1]), lumens_collected_total, floor(lumens_history[lumens_history.size()-1])  ])
#		Utils.log_message("Light nodes:%s (static:%s), Shadow nodes:%s (static:%s)" % [Utils.game.map.darkness.get_light_node_count(), Utils.game.map.darkness.get_static_light_node_count(), Utils.game.map.darkness.get_shadow_node_count(), Utils.game.map.darkness.get_static_shadow_node_count()])
		Utils.log_message("Light3D nodes:%s, Shadow nodes:%s" % [Utils.game.map.darkness.get_light_node_count(), Utils.game.map.darkness.get_shadow_node_count()])
		
		Utils.log_message("Nodes in light group:%s, Nodes in shadow group:%s" % [Utils.game.map.darkness.get_light_node_count_2(), Utils.game.map.darkness.get_shadow_node_count_2()])
		
		SteamAPI2.update_average_stat("AvgMetalPerHour", scraps_history[scraps_history.size()-1])
		SteamAPI2.update_average_stat("AvgLumenPerHour", lumens_history[lumens_history.size()-1])

		SteamAPI2.update_average_stat("AvgMetalPerMinute", scraps_history[scraps_history.size()-1], 1.0)
		SteamAPI2.update_average_stat("AvgLumenPerMinute", lumens_history[lumens_history.size()-1], 1.0)

		scraps_history.append(0)
		lumens_history.append(0)
		fps_history.append(0.0)
		fps_min_per_minute = INF
		fps_max_per_minute = -INF
		
		map.test_OCD()
		
	if not (frame_from_start % 60):
		update_resource_statistics()
	# DEBUG MUCH
	
	#map.pixel_map.fog_of_war.get_parent().transform = get_canvas_transform()
#	process_screen_shake(delta)
	if is_shaking:
		process_screen_shake_all(delta)
	
	var pickup_draw_distance = Utils.game.screen_diagonal_radius_scaled
#	var pickup_draw_distance = Save.config.screen_diagonal/2/4
#	var pickup_draw_distance = (Const.RESOLUTION / 2 / 4).length()
	if is_nan(Utils.game.camera.get_camera_screen_center().y):
		return
	Utils.game.map.pickup_tracker.updateFocusCircle(camera.get_camera_screen_center(), pickup_draw_distance)

#	Utils.game.map.pickup_tracker.updateFocusCircle(camera.get_camera_screen_center(), 1024)
	Utils.game.map.enemy_tracker.updateFocusCircle(camera.get_camera_screen_center(), 512)
	Utils.game.map.player_tracker.updateFocusCircle(camera.get_camera_screen_center(), 1024) # dodawane sa z 99999 radius wiec nie wypadna
	Utils.game.map.common_buildings_tracker.updateFocusCircle(camera.get_camera_screen_center(), 512)
	Utils.game.map.gate_buildings_tracker.updateFocusCircle(camera.get_camera_screen_center(), 512)
	Utils.game.map.power_expander_buildings_tracker.updateFocusCircle(camera.get_camera_screen_center(), 512)
	Utils.game.map.turret_buildings_tracker.updateFocusCircle(camera.get_camera_screen_center(), 512)
	Utils.game.map.mine_buildings_tracker.updateFocusCircle(camera.get_camera_screen_center(), 512)
	Utils.game.map.passive_buildings_tracker.updateFocusCircle(camera.get_camera_screen_center(), 512)
	Utils.game.map.lights_tracker.updateFocusCircle(camera.get_camera_screen_center(), 512)
	Utils.game.map.flares_tracker.updateFocusCircle(camera.get_camera_screen_center(), 512)
	Utils.game.map.danger_tracker.updateFocusCircle(camera.get_camera_screen_center(), 512)

	Utils.game.map.strategic_buildings_group.update()
	Utils.game.map.enemies_group.update()

	if not building_queue.is_empty():
		if not Save.is_tech_unlocked("many_drones") and not get_tree().get_nodes_in_group("build_drone").is_empty():
			return
		
		var data = building_queue.pop_front()
		if not is_instance_valid(data.blueprint):
			return # (╯°□°）╯︵ ┻━┻

		var closest_home = get_closest_drone_home(data.building.position)
		if closest_home.has_method("open_door"):
			closest_home.open_door()
		
		var drone := preload("res://Nodes/Objects/Helper/BuildDrone.tscn").instantiate() as Node2D
		drone.blueprint = data.blueprint
		drone.building = data.building
		drone.position = closest_home.global_position
		map.add_child(drone)
	
func _process(delta: float) -> void:
	if not map:
		return
	
	if not pickable_destruction_queue.is_empty(): #TODO: zmiana mapy może to zepsuć
		var pickable := pickable_destruction_queue.pop_back() as Pickup
		pickable.queue_free()

	# TEST ENEMY POWER
#	if Input.is_action_just_pressed("restart"):
#		if enemy_test_stats:
#			enemy_test_stats.process_test_stats()
#		else:
#			var enemy_test_stats_scene = load("res://Tools/EnemyTestStats.tscn")
#			enemy_test_stats = enemy_test_stats_scene.instance()
#			add_child(enemy_test_stats)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if not event.pressed:
			return
		
		## debug
		if event.keycode == KEY_KP_SUBTRACT:
#			var zoom = min(camera.target_zoom.x + 0.02, 0.75)
			camera.current_zoom_index = min(camera.zoom_levels.size()-6, camera.current_zoom_index + 2 )
			camera.target_zoom = Vector2.ONE * camera.zoom_levels[camera.current_zoom_index]
#			camera.target_zoom = Vector2.ONE * zoom
		elif event.keycode == KEY_KP_MULTIPLY:
			camera.current_zoom_index = max(0, camera.current_zoom_index - 2 )
			camera.target_zoom = Vector2.ONE * camera.zoom_levels[camera.current_zoom_index]
#			zoom_levels[current_zoom_index]
#			var zoom = max(camera.target_zoom.x - 0.02, 0.025)
#			camera.target_zoom = Vector2.ONE * zoom
		
#		if event.scancode == KEY_KP_SUBTRACT:
#			lol_scale -= 0.1
#			Utils.get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_DISABLED, SceneTree.STRETCH_ASPECT_EXPAND, Vector2(960, 540), lol_scale)
#			Utils.get_viewport().size = Save.config.resolution
#			set_camera_zoom(clamp(lol_scale/4.0, 0.05, 0.25))
#
#		elif event.scancode == KEY_KP_ADD:
#			lol_scale += 0.1
#			Utils.get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_DISABLED, SceneTree.STRETCH_ASPECT_EXPAND, Vector2(960, 540), lol_scale)
#			Utils.get_viewport().size = Save.config.resolution
#			set_camera_zoom(clamp(lol_scale/4.0, 0.05, 0.25))
		
		if Music.is_game_build() and not OS.has_feature("dev_build"):
			return
		
		if event.keycode == KEY_S and Input.is_key_pressed(KEY_CTRL):
			if Save.block_save.is_empty():
				Utils.log_message("Saving...")
				Save.save_game("debug")
			else:
				Utils.log_message("Saving blocked!!")
		
		if event.keycode == KEY_L and Input.is_key_pressed(KEY_CTRL):
			Save.current_map = ""
			Utils.log_message("Loading...")
			Save.load_game("debug")

func finalize_main_player():
#	map.swarm.set_player(main_player)
	ui.get_player_ui(1).set_player(main_player)
	if not Save.data.player_data[0]:
		set_starting_inventory(main_player)
	main_player.map = map
	add_child(main_player)

func after_save_loaded():
	frame_from_start = frame_this_cycle

func assign_core():
	core = map.get_node_or_null("Reactor")
	if not core:
		core = map.get_node_or_null("Core")
	
	if Save.start_point >= 0:
		respawn_point = map.get_node_or_null("Start%s" % Save.start_point)
		Save.start_point = -1
		
		if not respawn_point:
			push_warning("Nie znaleziono startu")
	
	var no_data := true
	for data in Save.data.player_data:
		if data:
			no_data = false
			break
	
	if Utils.has_meta("start_override"):
		main_player.position = Utils.get_meta("start_override")
		Utils.remove_meta("start_override")
	elif not Music.is_game_build() and CustomRunner.is_custom_running():
		main_player.position = CustomRunner.get_variable("mouse_pos")
	elif no_data or Save.campaign:
		move_to_start(main_player)
	
	camera_target.global_position = main_player.global_position
	camera.force_update()

func goto_map(map_name):
	if map_name is String and map_name == Save.current_map:
		return
	
	if map:
		map.exit_time = Save.game_time
	
	var old_map: String = Save.current_map
	if map_name is MapFile:
		Save.current_map = map_name.loaded_path
	else:
		Save.current_map = map_name
	# RECHECK
	#var map_file := File.new()
	
	loading_counter =  Time.get_ticks_msec()
	var loader := preload("res://Scenes/Game/MapLoading.tscn").instantiate()
	loader.connect("finished", Callable(self, "map_instance_loaded"))
	
	if map_name:
		loader.load_path = map_name
	else:
		print("ERROR")
	
	add_child(loader)
	
	await get_tree().idle_frame
	
	if map:
		Save.current_map = old_map
#		Save.save_game() ## TODO
		Save.current_map = map_name
		remove_child(map)
		map = null
	
	loader.set_process(true)
	await loader.tree_exited
	camera.current = true
	if Save.is_hub():
		Music.stop()
		disable_music = true
	else:
		Music.randomize_set()
		Music.crossfade(Music.current_set.normal)
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	
	if map.events:
		map.events._gameplay_start()
	
	if get_second_viewport():
		get_second_viewport().get_parent().show()

func map_instance_loaded(map_instance: Map):
	map_cache[Save.current_map] = map_instance #TODO: Trzeba zrobić zarządzanie mapami gdyby zużywały za dużo RAMu.
	if map_instance != map:
		change_map_to(map_instance)
	
	if map.events:
		map.events._game_start()
	
	fetch_stairs()
	assign_core()
	
	if sandbox_options.get("sandbox_mode", false) and not get_tree().get_nodes_in_group("wave_spawners").is_empty():
		var computer: Node2D = load("res://Nodes/Objects/Helper/SandboxComputer.tscn").instantiate()
		
		if core:
			computer.position = Vector2(64, 64)
			core.add_child(computer)
		else:
			computer.position = main_player.position + Vector2(64, 0)
			map.add_child(computer)
	
	emit_signal("map_initialized")
#	Utils.debug_count_nodes()

func change_map_to(map_instance: Map):
	Utils.log_message("\nMap started: %s, Loading time: %ssec." % [Save.campaign.current_map if Save.campaign else Save.current_map, (Time.get_ticks_msec() - loading_counter)/1000.0])
	
	Utils.log_message("Custom settings: %s" % Utils.game.sandbox_options)
	map = map_instance
	emit_signal("map_pre_instance", map)
	add_child(map)
	
	var material_histogram = map.pixel_map.get_materials_histogram(false)
	map.remainig_lumen = material_histogram[Const.Materials.LUMEN]
#	map.remaing_metal = material_histogram[Const.Materials.WEAK_SCRAP] + material_histogram[Const.Materials.STRONG_SCRAP] + material_histogram[Const.Materials.ULTRA_SCRAP]
	if map.remainig_lumen <=1:
		SteamAPI2.unlock_achievement("OCD")
	
	if has_meta("disabled_buildings"):
		map.start_config.disabled_buildings = get_meta("disabled_buildings")
	
	set_camera_limits(camera)
	if camera2:
		set_camera_limits(camera2)
	main_player.map = map
	
	if not sandbox_options.get("start_with_base", true):
		var destroy_timer := get_tree().create_timer(0.1) # AAAAAAAAAAAAAAAAA
		for node in get_tree().get_nodes_in_group("player_buildings"):
			if node.filename.find("Reactor.tscn") < 0:
				destroy_timer.connect("timeout", Callable(node, "destroy").bind(false))
	
	emit_signal("map_changed")
	update_screen_diagonal()
	
	if Save.data.difficulty != Const.Difficulty.NORMAL:
		for i in map.ResourceSpawnRateModifier:
			map.ResourceSpawnRateModifier[i] = Const.DIFFICULTY_RESOURCE_MULTIPLIERS[Save.data.difficulty]
	
	if Save.campaign and Save.campaign.coop:
		ui.get_node("%CoopSettings").call_deferred("refresh_controllers")
		ui.get_node("%CoopSettings").call_deferred("start")
	
	initialized = true

func fetch_stairs():
	if stairs_id == -1:
		return
	
	var id := stairs_id
	stairs_id = -1
	
	for stair in Utils.game.get_tree().get_nodes_in_group("stairs"):
		if stair != self and stair.id == id:
			Utils.game.main_player.force_position = stair.global_position
			camera.force_update()
			return
	assert(false, "Exit stairs with id " + str(id) + " not found.")


func get_all_running_storages():
	var storages: Array
	for storage in get_tree().get_nodes_in_group("storage"):
		if storage.is_running:
			storages.append(storage)
	return storages

func get_closest_drone_home(pos):
	var drone_homes=get_tree().get_nodes_in_group("build_drone_home")
	var distance=INF
	var closest=null
	for i in drone_homes:
		if !i.is_running:
			continue
		var dist=pos.distance_squared_to(i.global_position)
		if dist <distance:
			closest=i
			distance=dist
	
	if not closest:
		for i in Utils.game.players:
			var dist = pos.distance_squared_to(i.global_position)
			if dist < distance:
				closest = i
				distance = dist
	
	return closest

func place_building(building: Node2D, blueprint: Node2D):
	Utils.log_message("Building blueprint placed: %s" % building.name)
	if building is BaseBuilding:
		building.in_construction = true
		building.hack = true # ;_;
		map.add_child(building)
		map.remove_child(building)
		building.hack = false
	else:
		building.set_meta("built", true)
	
	blueprint.on_placed()
	if not map.is_ancestor_of(blueprint):
		blueprint.position = get_viewport().canvas_transform.affine_inverse() * (blueprint.global_position)
		blueprint.get_parent().remove_child(blueprint)
		map.add_child(blueprint)
		blueprint.scale = blueprint.scale * camera.zoom
		blueprint.modulate.a = 0.5
	
	building.position = blueprint.position
	blueprint.add_to_group("blueprints")
	# Tu można walnąć shader.
	
	building_queue.append({blueprint = blueprint, building = building})

func get_updated_average(average:float, input:float):
	var average_sample_size := 10.0
	average -= average / average_sample_size
	average += input / average_sample_size
	return average

func get_updated_average_opt(average:float, input:float):
	var average_sample_size = 0.1
	return (average_sample_size * input) + (1.0 - average_sample_size) * average

func update_resource_statistics():
	if scraps_collected_per_second > 0:
		SteamAPI2.increment_stat("MetalCollected", scraps_collected_per_second)
	scraps_history[scraps_history.size()-1] += scraps_collected_per_second
	scraps_average_per_minute = get_updated_average_opt(scraps_average_per_minute, scraps_collected_per_second*60)
	scraps_collected_total += scraps_collected_per_second
	scraps_collected_per_second = 0
	
	if lumens_collected_per_second > 0:
		SteamAPI2.increment_stat("LumenCollected", lumens_collected_per_second)
	lumens_history[scraps_history.size()-1] += lumens_collected_per_second
	lumens_average_per_minute = get_updated_average_opt(lumens_average_per_minute, lumens_collected_per_second*60)
	lumens_collected_total += lumens_collected_per_second
	lumens_collected_per_second = 0
	
	var fps = Engine.get_frames_per_second()
	if fps_max_per_minute < fps:
		fps_max_per_minute = fps
	elif fps < fps_min_per_minute:
		fps_min_per_minute = fps
		
	if fps_max < fps:
		fps_max = fps
	elif fps < fps_min:
		fps_min = fps
	fps_history[scraps_history.size()-1] += fps 

func get_global_lumens_average():
	var average := 0.0
	if  lumens_history.size()> 1:
		for i in lumens_history.size():
			average += lumens_history[i]
		
		return average / lumens_history.size()
	return average

func get_global_scraps_average():
	var average := 0.0
	if scraps_history.size()> 1:
		for i in scraps_history.size():
			average += scraps_history[i]
		
		return average / scraps_history.size()
	return average

func get_average_fps():
	var average := 0.0
	if fps_history.size()> 1:
			
		for i in fps_history.size()-1:
			average += fps_history[i]
		
		return average / (fps_history.size()-1)
	return average

func count_frame_and_game_time(delta: float):
	time_from_start += delta
	frame_from_start += 1
	frame_this_cycle += 1
	if frame_this_cycle > frame_cycle_length:
		frame_this_cycle = 0

func shake(attenuation: float, duration = 0.5, freqency:float= 30.0, randomness := 1.0):
	is_shaking = true
	
	var timer := 0.0
	var bounce_index :int= 0
	var bounce_number := int( duration * freqency )
	var direction := Vector2.RIGHT.rotated(randf()*TAU)
	var inital_shake := direction * attenuation
	
	camera_shakes.append([timer, bounce_index, bounce_number, attenuation, freqency, randomness, direction, inital_shake, Vector2.ZERO])
	Utils.vibrate(attenuation * 0.1, attenuation * 0.05, attenuation * 0.01)
	
func shake_in_direction(attenuation:float, direction:Vector2, duration:float = 0.5, freqency:float= 30.0, randomness:float = 1.0):
	is_shaking = true
	
	var timer := 0.0
	var bounce_index :int= 0
	var bounce_number := int( duration * freqency )
	var inital_shake := direction.rotated(randf()*randomness) * attenuation
	
	camera_shakes.append([timer, bounce_index, bounce_number, attenuation, freqency, randomness, direction, inital_shake, Vector2.ZERO])
	Utils.vibrate(attenuation * 0.1, attenuation * 0.05, attenuation * 0.01)
	
func shake_in_position(shake_source:Vector2, attenuation: float, duration:float = 0.5, freqency:float= 30.0, randomness:float = 1.0):
	if is_nan(Utils.game.camera.get_camera_screen_center().y) or is_nan(get_viewport_rect().size.y):
		return
	var distance  = (camera.get_camera_screen_center().distance_to(shake_source)) / (get_viewport_rect().size.x * camera.zoom.x * 0.5)
	if  distance <= 1:
		attenuation *= (1.0 - distance)
#		camera_shakes.append([power,0])
		shake_in_direction(attenuation, shake_source.direction_to(camera.get_camera_screen_center()) , duration, freqency, randomness)

func process_screen_shake_all(delta):
	if camera_shakes.size() <= 0:
		is_shaking = false
		camera.offset = Vector2.ZERO
		return
		
	camera.offset = Vector2.ZERO
	var i := 0
	while i < camera_shakes.size():
		process_screen_shake_single(i, delta)
		if camera_shakes[i][1] > camera_shakes[i][2]:
#			prints(camera_shakes[i][1], camera_shakes[i][2])
			camera_shakes.remove_at(i)
			i -= 1
		i += 1
		
func process_screen_shake_single(idx, delta):
	if camera_shakes[idx][0] < 1:
		camera_shakes[idx][0] += delta * camera_shakes[idx][4] * Save.config.screenshake
		if camera_shakes[idx][4] == 0:
			camera_shakes[idx][0] = 1

		camera.offset += camera_shakes[idx][8].lerp(camera_shakes[idx][7], camera_shakes[idx][0])
	else:
		camera_shakes[idx][0] = 0
		camera.offset += camera_shakes[idx][7]
		camera_shakes[idx][8] = camera_shakes[idx][7]
		camera_shakes[idx][1] += 1
		if camera_shakes[idx][1] > camera_shakes[idx][2]:
			return

		var random_vector = Vector2.RIGHT.rotated(randf()*TAU)
		var shake_progress = float(camera_shakes[idx][1]) / camera_shakes[idx][2]
		camera_shakes[idx][6] = - camera_shakes[idx][6] + camera_shakes[idx][5] * random_vector
		camera_shakes[idx][6] = camera_shakes[idx][6].normalized() * Save.config.screenshake * shake_curve.sample(shake_progress)
		var decay = 1.0 - shake_progress
		camera_shakes[idx][7] = decay * decay * camera_shakes[idx][3] * camera_shakes[idx][6]

func shake_old(power: float, duration=0.0):
	camera_shakes.append([power,duration])
	Utils.vibrate(power * 0.1, power * 0.05, power * 0.01)
		
func old_process_screen_shake(delta):
	camera.offset = Vector2()
	
	var i := 0
	while i < camera_shakes.size():
		camera.offset += Vector2.RIGHT.rotated(randf() * TAU) * camera_shakes[i][0] * Save.config.screenshake
		if camera_shakes[i][1]<=0.0:
			camera_shakes[i][0] -= 1
			if camera_shakes[i][0] <= 0:
				camera_shakes.remove_at(i)
				
			else:
				i += 1
		else:
			camera_shakes[i][1]-=delta
			i += 1

func add_new_player(control_id := 1, player_id := 1):
	var player: Player = load("res://Nodes/Player/Player.tscn").instantiate()
	player.position = main_player.position + Vector2.RIGHT * 16
	player.player_id = player_id
	player.control_id = control_id
	add_child(player)
	await get_tree().idle_frame
	if not Save.data.player_data[player_id]:
		set_starting_inventory(player)
		Utils.game.map.apply_player_start(player)
	else:
		var data = Save.data.player_data[player_id]
		data.erase("position")
		player._set_save_data(data)
	
	players.append(player)
	player.map = map
	
	player.torso.self_modulate = Const.PLAYER_COLORS[player_id]
	player.player_indicator.frame = player_id
	
	var player_ui := ui.get_player_ui(players.size())
	if player_id == 1 and get_second_viewport():
		player_ui = ui2.get_player_ui(players.size())
	
	if player_ui: ## nie powinno być potrzebne
		player_ui.set_player(player)
	Utils.log_message("Player %s joined. " % player_id)
	SteamAPI2.unlock_achievement("CO_OP_2")
	
	if player_id == 1 and camera2:
		camera2.set_target(player)
		player.get_node("CanvasLayer").custom_viewport = get_second_viewport()
		player.get_node("CanvasLayer/CursorLayer").custom_viewport = get_second_viewport()

func clear_coop_players():
	ui.get_player_ui(1).get_node("Indicator").hide()
	main_player.control_id = 1
	for i in players.size() - 1:
		var player_ui := ui.get_player_ui(players.size())
		if player_ui: ## nie powinno być potrzebne
			player_ui.set_player(null)
		players.pop_back().leave_coop()
	
	Utils.log_message("Co-op stoped.")
	Utils.emit_signal("coop_toggled", false)
	
	main_player.dead = false
	main_player.super_dead = false
	main_player.call_deferred("check_hp")

func set_starting_inventory(player: Player):
	if not has_meta("skip_default"):
		player.add_item(Const.ItemIDs.DRILL, 1, null, false)
		player.add_item(Const.ItemIDs.FLARE, 50, null, false)
		player.inventory_secondary = 1
		player.inventory_secondary_id = Const.ItemIDs.FLARE
#		player.inventory_quick[0] = 0
#		player.inventory_quick_id[0] = Const.ItemIDs.DRILL
#		player.inventory_quick[1] = 1
#		player.inventory_quick_id[1] = Const.ItemIDs.FLARE
	
	if not sandbox_options.is_empty():
		var ammo := -1
		if sandbox_options.get("starting_weapon", -1) > -1:
			player.add_item(sandbox_options.starting_weapon)
			ammo = Const.Items[sandbox_options.starting_weapon].get("ammo", -1)
		
		if sandbox_options.get("starting_resources", 0) > 0:
			var ratio: float = [0.3, 0.8, 1.4][sandbox_options.starting_resources - 1]
			player.add_item(Const.ItemIDs.METAL_SCRAP, Utils.get_stack_size(Const.ItemIDs.METAL_SCRAP, null) * ratio, null, false, true)
			player.add_item(Const.ItemIDs.LUMEN, Utils.get_stack_size(Const.ItemIDs.LUMEN, null) * ratio, null, false, true)
			
			if ammo > -1:
				player.add_item(Const.ItemIDs.AMMO, Utils.get_stack_size(Const.ItemIDs.AMMO, ammo) * ratio, ammo, false, true)

func set_camera_zoom(new_zoom:float = 1.0):
	if camera:
		camera.target_zoom = Vector2(new_zoom * 0.5, new_zoom * 0.5)
		camera.zoom = Vector2(new_zoom * 0.5, new_zoom * 0.5)
	

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		exit()
	
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		update_cursor_lock()
	
	if what == NOTIFICATION_PREDELETE:
		for m in map_cache.values():
			if is_instance_valid(m):
				m.free()

func endgame_log():
	if fps_max<0:
		fps_max = 0
	if fps_min > fps_max:
		fps_min = fps_max
	Utils.log_message("Map %s closed. " % Save.current_map)
	Utils.log_message("Average fps: %s" % get_average_fps(), false)
	Utils.log_message("Maximal fps: %s" % fps_max, false)
	Utils.log_message("Minimal fps: %s" % fps_min, false)
	Utils.log_message("Metal per minute: %s" % (get_global_scraps_average()), false)
	Utils.log_message("Collected metal: %s" % scraps_collected_total, false)
	Utils.log_message("Lumen per minute: %s" % (get_global_lumens_average()), false)
	Utils.log_message("Collected lumen: %s" % lumens_collected_total, false)

func exit(ultimate := true):
	if ultimate:
		get_tree().quit()
	elif Utils.editor:
		if Save.map_completed and Save.data.ranked:
			Utils.editor.set_validated()
			Utils.editor.call_deferred("try_save")
		Save.data = null
		Music.stop()
		get_tree().root.add_child(Utils.editor)
		get_tree().current_scene = Utils.editor
		get_tree().call_group("audio_sample", "queue_free")
		queue_free()
	elif Save.campaign and Save.current_map != "res://Maps/Campaign/Hub.tscn" and not has_meta("menu_quit"):
		var loading = preload("res://Scenes/Campaign/gnidaoLrotavelE.tscn").instantiate()
		Utils.add_child(loading)
		loading.start()
		Utils.set_meta("loading_background", loading)
		
		queue_free()
		Save.campaign_cleanup()
		
		var l = preload("res://Scenes/ScreenLoading.tscn").instantiate()
		Utils.add_child(l)
		RenderingServer.connect("frame_post_draw", Callable(l, "queue_free"))
		l.connect("tree_exited", Callable(get_script(), "start_map").bind("res://Maps/Campaign/Hub.tscn"))
	else:
		remove_meta("menu_quit")
		Utils.change_scene_with_loading(Const.TITLE_SCENE)

func win(message := "Map completed! Exit at any time to get score summary."):
	if Utils.game.sandbox_options.get("sandbox_mode", false):
		return
	
	if not message.is_empty():
		ui.set_objective(99999, message, false, true)
	Save.map_completed = true
	ui.menu.get_node("%Finish").show()
	
	if not get_tree().paused: # Nie pokazuj podczas wczytywania mapy
		SteamAPI2.increment_stat("GlobalGamesWon")
		SteamAPI2.increment_stat("GamesWon")

#	if enemy_test_stats:
#		enemy_test_stats.process_test_stats()

func delete_pickable(pickable: Pickup):
	pickable_destruction_queue.append(pickable)

func get_start() -> Node2D:
	var start := respawn_point
	if not start:
		start = map.get_node_or_null("Start")
	
	if not start and is_instance_valid(core):
		start = core.get_node("StartPoint")
	
	if not Music.is_game_build() and map.has_node("DebugStart") and map.get_node("DebugStart").visible:
		start = map.get_node("DebugStart")
	
	return start

func move_to_start(what: Node2D):
	if not is_instance_valid(what):
		return
	
	what.global_position = get_start().global_position

func start_battle():
	if map.wave_manager.should_play_wave_music() or disable_music:
		return
	if not Music.current_track == "battle":
		Music.swap_track("battle")
	battle_timer.start()

func stop_battle():
	if map.wave_manager.should_play_wave_music() or disable_music:
		return
	
	if near_base:
		if Music.current_track != "intense":
			Music.swap_track("intense")
	else:
		if Music.current_track != "normal":
			Music.swap_track("normal")

func set_near_base(nb: bool):
	near_base = nb
	if battle_timer.is_stopped():
		stop_battle()

func game_over(message: String):
	if shindeiru:
		return
	shindeiru = true
	
	emit_signal("game_overd")
	var result = ui.show_result(false)
	result.set_death_message(message)

	if not get_tree().paused: # Nie pokazuj podczas wczytywania mapy
		SteamAPI2.increment_stat("GlobalGamesLost")
		SteamAPI2.increment_stat("GamesLost")

#	if enemy_test_stats:
#		enemy_test_stats.process_test_stats()

static func start_map(path):
	if Utils.get_meta("split_screen", false):
		start_map_splitscreen(path)
		return
	
	var game := load("res://Scenes/Game/Game.tscn").instantiate() as Game
	game.map_to_load = path
	game.sandbox_options = Save.sandbox_options
	Utils.get_tree().root.call_deferred("add_child", game)
	await game.ready
	Utils.get_tree().current_scene = game

static func start_map_splitscreen(path: String):
	var game_parent = load("res://Scenes/Game/SplitScreenGame.tscn").instantiate()
	var game = Utils.game
	game.map_to_load = path
	game.sandbox_options = Save.sandbox_options
	Utils.get_tree().root.call_deferred("add_child", game_parent)
	await game.ready
	Utils.get_tree().current_scene = game_parent

func save_building_queue() -> Array:
	var queue: Array
	
	for building in building_queue:
		queue.append(building.blueprint._get_save_data())
	
	for drone in get_tree().get_nodes_in_group("build_drone"):
		if drone.blueprint:
			queue.append(drone.blueprint._get_save_data())
	
	return queue

func load_building_queue(bmap: Map, queue: Array):
	for building in queue:
		var instance = load("res://Nodes/Buildings/Icons/GenericPreview.gd")._instance_from_save(bmap, building)
		instance[1].target_building = instance[0]
		bmap.loaded_building_queue.append(instance)

func _exit_tree() -> void:
	Utils.game = null
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Save.campaign:
		Music.stop()

func update_cursor_lock():
	if get_tree().paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

func is_coop_active() -> bool:
	return players.size() > 1

func _get_save_data() -> Dictionary:
	var data = Save.get_properties(self, ["time_from_start", "frame_from_start", "frame_this_cycle", "extra_turrets"])
	data.disabled_buildings = map.start_config.get("disabled_buildings", [])
	return data

func _set_save_data(data: Dictionary):
	if "disabled_buildings" in data:
		set_meta("disabled_buildings", data.disabled_buildings)
	
	Save.set_properties(self, data)

func get_second_viewport() -> SubViewport:
	return second_viewport

func set_camera_limits(cam: Camera2D):
	var base_limit := 0.0 if Save.is_hub() else -100.0
	cam.limit_left = base_limit
	cam.limit_top = base_limit
	cam.limit_right = map.pixel_map.get_texture().get_width() - base_limit
	cam.limit_bottom = map.pixel_map.get_texture().get_height() - base_limit
