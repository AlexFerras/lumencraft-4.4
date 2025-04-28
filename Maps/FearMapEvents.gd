extends "res://Scripts/MapEvents.gd"

var players_in_base: int
@export var wave_timer: float = 0
@export var wave_variation_timer: float = 1.0

var wave_data: Array
@export var wave_spawn_time_freeze:bool = false
@export var wave_base_spawn:int = 0
@export var wave_extra_spawn:float = 0.0

var is_fear:bool= false
var player_fear: Sprite2D

var is_inital_pause: bool = true

var stalker_swarm:SwarmSpider
@export var stalker_spawn_size:int
var stalker_spawn_limit:int = 10

var stored_player_positions:PackedVector2Array
var stored_player_positions_idx:int
var stored_player_positions_max = 10

var fuel: Node2D

@export var first_time := true
@export var first_objective: bool
@export var power_creep: float

func _ready() -> void:
	map.connect("pickables_spawned", Callable(self, "on_pickables"))
	map.wave_manager.connect("wave_defeated", Callable(self, "on_end_wave"))
	
	var wave_file = Utils.game.map.WAVE_MANAGER.WaveStorage.new()
	wave_file.load_from_path("res://Maps/FearMap.cfg")
	wave_data = wave_file.get_array()
	
	stored_player_positions.resize(stored_player_positions_max)
	
	map.pixel_map.material_data.set_material_durability(Const.Materials.WEAK_SCRAP, 3)
	
	map.ResourceSpawnRateModifier[Const.Materials.WEAK_SCRAP] = 3.0
	map.ResourceSpawnRateModifier[Const.Materials.STRONG_SCRAP] = 2.0
	map.ResourceSpawnRateModifier[Const.Materials.ULTRA_SCRAP] = 2.0
	map.ResourceSpawnRateModifier[Const.Materials.LUMEN] = 1.5
	map.wave_manager.connect("spawn_fininished", Callable(self, "wave_spawned"))
	map.wave_manager.connect("wave_defeated", Callable(self, "wave_defeated"))
	map.wave_manager.connect("wave_started", Callable(self, "wave_started"))

	player_fear =  preload("res://Nodes/Player/Fear.tscn").instantiate()
	Utils.game.main_player.add_child( player_fear )
	is_fear = true
	
	stalker_swarm = preload("res://Nodes/Unique/FearFastSpiderSwarm_lvl1.tscn").instantiate()
	stalker_swarm.name = "FearSwarm"
	stalker_swarm.how_many = -1
	stalker_swarm.auto_remove = false
	stalker_swarm.spawn_radius = 3
	stalker_swarm.just_wander = true
	stalker_swarm.spawn_delay = 0.1
	stalker_swarm.spawn_velocity_multiplier = 0.01
	map.call_deferred("add_child", stalker_swarm)
	
	Utils.game.ui.get_node("%FullMapViewportContainer").material.set_shader(preload("res://Scenes/Game/UI/MainMap_transparent_objective.gdshader"))
	
	#Utils.game.ui.minimap.get_child(0).replace_by(preload("res://Nodes/UI/SeismicMap/SeismicMap.tscn").instance())
	
	#Utils.game.ui.get_node("%FullMap/Minimap/SeismicMap").replace_by(preload("res://Nodes/UI/SeismicMap/SeismicMapMain.tscn").instance())
	
	if Music.is_game_build():
		set_process_input(false)
	
func _enter_map():
	Utils.game.ui.call_deferred("set_objective", 0, "Start the reactor.")

func _game_start():
	if first_time:
		Utils.game.ui.on_screen_message.add_message($MapInstructions.text)

func _gameplay_start():
	for i in stored_player_positions_max:
		stored_player_positions[i] = Utils.game.main_player.global_position
	wave_spawned()

func _config_map(config: Dictionary):
	config.include_default = false
	
	config.inventory = []
	config.inventory.append({id = "DRILL", amount = 1})
	config.inventory.append({id = "MAGNUM", amount = 1})
	config.inventory.append({id = "FLARE", amount = 20})
	config.inventory.append({id = "HOOK", amount = 1})
	
	config.technology = {}
	config.technology["building_regeneration"] = 2
	config.technology["lumen_stacking"] = 1
	config.technology["mineral_stacking"] = 1
	config.technology["infinite_gun"] = 1
	config.technology["many_drones"] = 1
	
	config.upgrades = {}
	config.upgrades["backpack_upgrade"] = 8
	
	config.weapon_upgrades = {}
	config.weapon_upgrades[str(Const.ItemIDs.DRILL, "drilling_power")] = 1

func on_pickables(type: int, amount: int):
	match type:
		Const.ItemIDs.LUMEN:
			wave_extra_spawn += amount * 0.1
			
		Const.ItemIDs.METAL_SCRAP:
			wave_extra_spawn += amount * 0.05
	
	if not map.wave_manager.wave_to_launch.is_empty() and map.wave_manager.wave_to_launch.enemies:
		map.wave_manager.wave_to_launch.enemies[0].count = wave_base_spawn + int(floor(wave_extra_spawn))

func _process(delta):
	if first_time:
		get_tree().paused = true
		first_time = false
	set_process(false)

var dupa: float

func _physics_process(delta: float) -> void:
	record_player_position()
	if not fuel:
		fuel = Utils.game.map.find_child("ReactorFuel")
#	$Label.text = str(wave_timer) + " " +str(current_wave) + "\n"
#	$Label.text += str(wave_variation_timer) + "\n" 
#	$Label.text += str(wave_base_spawn) + " " + str(wave_extra_spawn)
	
	if map.wave_manager.current_wave >= wave_data.size() and not map.wave_manager.has_active_wave() and map.wave_manager.wave_to_launch.is_empty():
		if fuel.powered_chambers.size() >= 3:
			return
		
		map.wave_manager.countdown_disabled = false
		if dupa <= 0 and (not map.wave_manager.has_active_wave() or map.wave_manager.wave_countdown > 0) and map.wave_manager.get_living_enemy_count() < 40 + int(power_creep):
			power_creep += 5
			map.wave_manager.launch_wave({repeat = 0, wait_time = 0.1, enemies = [{name = "Swarm/Strong Spider Swarm", count = int(50 + power_creep)}]})
			dupa = 1
			wave_timer = 0
			wave_variation_timer = 0
		else:
			dupa -= delta
		
		return
	
	if wave_spawn_time_freeze:
		return

	wave_timer -= delta
	if wave_timer <= 0 and players_in_base > 0:
		wave_variation_timer -= delta
		if wave_variation_timer <= 0:
			wave_trigger()

func record_player_position():
	if player_fear.is_in_light:
		if player_fear.in_fear_counter < 0.1 and stalker_spawn_size > 0:
			stalker_spawn_size = max(0, stalker_spawn_size - 1)
			player_fear.in_fear_counter = 2.0
	elif player_fear.in_fear_counter > 2:
		player_fear.in_fear_counter -= 2
#		prints("spawning", stalker_spawn_limit)
		stalker_spawn_size = min(stalker_spawn_size + 1, stalker_spawn_limit)
		if stalker_swarm.getNumOfLivingUnits() < stalker_spawn_limit:
			stored_player_positions[stored_player_positions_idx] = Utils.game.main_player.global_position
			stored_player_positions_idx += 1
			if stored_player_positions_idx >= stored_player_positions_max:
				stored_player_positions_idx = 0
			spawn_fear_enemies()
#	prints(player_fear.in_fear_counter, stalker_spawn_size, stalker_swarm.getNumOfLivingUnits())

func enter_base(player) -> void:
	players_in_base += 1

func exit_base(player) -> void:
	players_in_base -= 1
	if players_in_base <= 0:
		SteamAPI.fail_achievement("WAVE_STAY_IN_BASE")

func chunk_moved() -> void:
	Utils.play_sample(preload("res://SFX/Fear/voice_monster_roar_growl_groan_distant_01.wav"))
	Utils.game.shake(1, 5, 20)

func wave_trigger():
	map.wave_manager.countdown_disabled = false
	wave_spawn_time_freeze = true

func wave_spawned() -> void:
	if wave_timer > 0:
		map.wave_manager.countdown_disabled = true
		return
	
	if map.wave_manager.wave_to_launch.is_empty():
		wave_spawn_time_freeze = true
		return
	
	wave_timer = map.wave_manager.wave_to_launch.wait_time - 60
	map.wave_manager.wave_to_launch.wait_time = 60
	map.wave_manager.wave_countdown = 60
	wave_base_spawn = map.wave_manager.wave_to_launch.enemies[0].count
	map.wave_manager.countdown_disabled = true
	
	wave_variation_timer = randf_range(15, 60)
	wave_spawn_time_freeze = false
	
func wave_started() -> void:
	wave_extra_spawn -= floor(wave_extra_spawn)
	map.wave_manager.countdown_disabled = true

func wave_defeated() -> void:
	pass

func spawn_fear_enemies():
#	var available = Utils.HexPoints.get_hex_arranged_points_in_rectangle(Rect2(Vector2(), rect_size), 16)
	for i in range(stored_player_positions_idx, stored_player_positions_max):
		if Utils.game.map.pixel_map.isCircleEmpty(stored_player_positions[i], 4):
			if not check_is_in_light(stored_player_positions[i]):
				stalker_swarm.global_position = stored_player_positions[i]
				stalker_swarm.how_many += stalker_spawn_size
				stalker_spawn_size = 0
				return
				
	for i in stored_player_positions_idx:
		if Utils.game.map.pixel_map.isCircleEmpty(stored_player_positions[i], 4):
			if not check_is_in_light(stored_player_positions[i]):
				stalker_swarm.global_position = stored_player_positions[i]
				stalker_swarm.how_many += stalker_spawn_size
				stalker_spawn_size = 0
				return

func check_is_in_light(coordinates:Vector2):
	for flare in Utils.game.map.flares_tracker.getTrackingNodes2DInCircle(coordinates, 150, true):
		return true

	var dot :float = 0.0
	for cone_light in Utils.game.map.lights_tracker.getTrackingNodes2DInCircle(coordinates, 150, true):
		dot = Vector2.RIGHT.rotated(cone_light.global_rotation).dot( cone_light.global_position.direction_to(coordinates) )
		if dot > cone_light.fov_angle/PI:
			return true
	return false

func reactor_stated(reactor_mode) -> void:
	if not first_objective:
		Utils.game.ui.set_objective(1, "Collect 3 golden Lumen.")
		first_objective = true

func on_end_wave():
	if map.wave_manager.is_finished() and fuel and fuel.powered_chambers.size() >= 3:
		Utils.game.win()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_F5 and event.pressed:
			if map.wave_manager.current_wave < 8:
				map.wave_manager.skip_waves(8)
			
			wave_timer = 0.1
			wave_variation_timer = 0.1
			map.wave_manager.wave_countdown = 0.1
