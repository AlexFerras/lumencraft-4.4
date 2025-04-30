@tool
extends Node2D
class_name Map

const WAVE_MANAGER = preload("res://Nodes/Map/WaveManager.gd")
const SWARM_MANAGER = preload("res://Nodes/Map/SwarmManager.gd")

@onready var events = get_node_or_null("MapEvents")
@onready var blood_spawner = $"%BloodSpawner"

var ResourceSpawnRateModifier = {
	Const.Materials.LUMEN: 1.0,
	Const.Materials.WEAK_SCRAP: 1.0,
	Const.Materials.STRONG_SCRAP: 1.0,
	Const.Materials.ULTRA_SCRAP: 1.0,
}

@export var disable_darkness: bool: set = set_disable_darkness
@export var disable_fog_of_war: bool: set = set_disable_fog_of_war

@export var wave_file_path: String # (String, FILE, "*.cfg")

var bedrock_texture: Texture2D

var pixel_map: PixelMap
var pixel_map_size: Vector2
var wave_manager := WAVE_MANAGER.new()
var swarm_manager: SWARM_MANAGER

var pixel_data_override: Image
var floor_data_override: Image
var floor_data2_override: Image
var fog_data_override: Image

var enemy_tracker: Nodes2DTrackerMultiLvl
var pickup_tracker: Nodes2DTrackerMultiLvl
var player_tracker: Nodes2DTrackerMultiLvl
var pet_tracker: Nodes2DTrackerMultiLvl

var common_buildings_tracker: Nodes2DTrackerMultiLvl
var gate_buildings_tracker: Nodes2DTrackerMultiLvl
var power_expander_buildings_tracker: Nodes2DTrackerMultiLvl
var turret_buildings_tracker: Nodes2DTrackerMultiLvl
var mine_buildings_tracker: Nodes2DTrackerMultiLvl
var passive_buildings_tracker: Nodes2DTrackerMultiLvl
var lights_tracker: Nodes2DTrackerMultiLvl
var flares_tracker: Nodes2DTrackerMultiLvl
var danger_tracker: Nodes2DTrackerMultiLvl

var strategic_buildings_group: Nodes2DTrackersSwarmsGroup
var enemies_group: Nodes2DTrackersSwarmsGroup

var floor_surface: PixelMap
var floor_surface2: PixelMap
var pickables: PixelMapPickables
var physics: PixelMapPhysics

var darkness: Node2D
var post_process: Sprite2D

var from_save: bool
var started: bool
var exit_time: int
var start_config: Dictionary
var event_object_list: Array
var blocked_technology: Array
var loaded_building_queue: Array
var cheap_range: CanvasItem

var material_occlusion_mask: int
var materials_lava_smoke_counters : PackedInt32Array

var remainig_lumen:int = 0
var loaded_swarm_data: Dictionary

var scoring_rules := {_clear_bonus = 25, time = 0, enemies_slain = 5, lumen_collected = 10, metal_collected = 5}

signal pickables_spawned(mat, amount)
signal initialized

func initialize_pixel_map(pxm: PixelMap):
	pixel_map = pxm
	if pixel_data_override:
		pixel_map.set_pixel_data(pixel_data_override.get_data(), pixel_data_override.get_size())
		pixel_data_override = null
	
	pickables = pixel_map.get_node_or_null("PixelMapPickables")
	if not pickables:
		pickables = preload("res://Nodes/Map/PixelMapPickables.tscn").instantiate()
		pixel_map.add_child(pickables)

#	pickables.set_pickables_draw_distance(Save.config.screen_diagonal/2/4)
#	pickables.set_pickables_draw_distance((Const.RESOLUTION/2/4).length())

	physics = pixel_map.get_addon("PixelMapPhysics")
	assert(physics)
	
	restore_pickable_callback()

	pixel_map.set_burning_destruction_callback(30, self, "pixels_burned")

	pixel_map.set_fluids_destruction_callback(3, self, "pixels_destroyed_by_fluid")
	var nr_of_user_defined_materials = 32
	materials_lava_smoke_counters.resize(nr_of_user_defined_materials)
	for i in materials_lava_smoke_counters.size():
		materials_lava_smoke_counters[i] = 0
	
	material_occlusion_mask = Utils.walkable_collision_mask
	for i in 4:
		var mat_id: int = Const.SwappableMaterials[i]
		var mat_res: TerrainMaterial = pixel_map.custom_materials[i]
		
		if mat_res and mat_res.transparent:
			material_occlusion_mask &= ~(1 << mat_id)
	
	queue_redraw()

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	enemy_tracker = Nodes2DTrackerMultiLvl.new()
	add_child(enemy_tracker)
	pickup_tracker = Nodes2DTrackerMultiLvl.new()
	add_child(pickup_tracker)
	player_tracker = Nodes2DTrackerMultiLvl.new()
	add_child(player_tracker)
	pet_tracker = Nodes2DTrackerMultiLvl.new()
	add_child(pet_tracker)
	common_buildings_tracker = Nodes2DTrackerMultiLvl.new()
	add_child(common_buildings_tracker)
	gate_buildings_tracker = Nodes2DTrackerMultiLvl.new()
	add_child(gate_buildings_tracker)
	power_expander_buildings_tracker = Nodes2DTrackerMultiLvl.new()
	add_child(power_expander_buildings_tracker)
	turret_buildings_tracker = Nodes2DTrackerMultiLvl.new()
	add_child(turret_buildings_tracker)
	mine_buildings_tracker = Nodes2DTrackerMultiLvl.new()
	add_child(mine_buildings_tracker)
	passive_buildings_tracker = Nodes2DTrackerMultiLvl.new()
	add_child(passive_buildings_tracker)
	lights_tracker = Nodes2DTrackerMultiLvl.new()
	add_child(lights_tracker)
	flares_tracker = Nodes2DTrackerMultiLvl.new()
	add_child(flares_tracker)
	danger_tracker = Nodes2DTrackerMultiLvl.new()
	add_child(danger_tracker)

	strategic_buildings_group = Nodes2DTrackersSwarmsGroup.new()
	strategic_buildings_group.add(common_buildings_tracker)
	strategic_buildings_group.add(power_expander_buildings_tracker)
	strategic_buildings_group.add(turret_buildings_tracker)
	strategic_buildings_group.add(mine_buildings_tracker)
	enemies_group = Nodes2DTrackersSwarmsGroup.new()
	enemies_group.add(enemy_tracker)

	swarm_manager = SWARM_MANAGER.new()
	add_child(swarm_manager)
	
	if loaded_swarm_data:
		swarm_manager._set_save_data(loaded_swarm_data)
		loaded_swarm_data = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if Music.is_switch_build():
		cheap_range = load("res://Scripts/CheapRange.gd").new()
		add_child(cheap_range)
	
	if not Save.is_hub():
		bedrock_texture = ImageTexture.new()
		bedrock_texture.create_from_image(preload("res://Resources/Terrain/Images/WallBedrock.png"))
		var border_drawer := Node2D.new()
		border_drawer.scale = Vector2.ONE * 0.125
		border_drawer.z_index = 4040
		border_drawer.connect("draw", Callable(self, "draw_border").bind(border_drawer))
		add_child(border_drawer)
	
	assert(pixel_map, "No PixelMap in the map! Are you missing MapPixelMap.gd?")
	pixel_map.registerEnemiesTracker(enemy_tracker)
	move_child(swarm_manager, pixel_map.get_index() + 1)
	
	floor_surface = get_node_or_null("Floor")
	floor_surface2 = get_node_or_null("Floor2")
	if not floor_surface or not floor_surface2:
		push_warning("No floor or floor2 PixelMap.")
	
	if floor_data_override:
		floor_surface.set_pixel_data(floor_data_override.get_data(), floor_data_override.get_size())
		floor_data_override = null
	if floor_data2_override:
		floor_surface2.set_pixel_data(floor_data2_override.get_data(), floor_data2_override.get_size())
		floor_data2_override = null
	
	if fog_data_override:
		pixel_map.fog_of_war.draw_node.load_fog = ImageTexture.create_from_image(fog_data_override)
		fog_data_override = null
	
	darkness = pixel_map.get_node_or_null("MapDarkness")
	if Music.is_switch_build():
		if darkness:
			darkness.queue_free()
			darkness = null
	else:
		if not darkness:
			darkness = preload("res://Nodes/Map/MapDarkness.tscn").instantiate()
			pixel_map.add_child(darkness)
	
	post_process = get_node_or_null("PostProcessManager")
	if not post_process:
		post_process = preload("res://Nodes/Effects/PostProcessManager.tscn").instantiate()
		add_child(post_process)
	
	wave_manager.setup_spawners(get_tree().get_nodes_in_group("wave_spawners"))
	if not wave_file_path.is_empty():
		wave_manager.set_data_from_file(wave_file_path)
#	else:
#		wave_manager.set_custom_data(WaveGenerator.new().generate_all_waves(32))
	
	pixel_map_size = pixel_map.get_texture().get_size()
	
	if not from_save:
		for turret in get_tree().get_nodes_in_group("defense_tower"):
			if turret.increase_limit_on_start:
				Utils.game.extra_turrets += 1
	
	if events and not from_save:
		#SteamAPI.achievements.start_map()
		events._enter_map()
		events._config_map(start_config)
	
	if not start_config.is_empty():
		if not start_config.get("include_default", true):
			Utils.game.set_meta("skip_default", true)
		
		call_deferred("apply_start")
	else:
#		started = true
		emit_signal("initialized")
	
	for building in loaded_building_queue:
		Utils.game.callv("place_building", building)
	
	if Utils.get_meta("hide_textures", false):
		pixel_map.use_parent_material = true
		material = null
	
	dmg_numbers.resize(dmg_numbers_max_count)
	for i in dmg_numbers_max_count:
		dmg_numbers[i] = dmg.instantiate()
	
	if Save.current_map == "res://Maps/TrueBeginningMap.tscn" and not $"%Goal".is_connected("goal_entered", Callable(events, "exit_reached")): ## usunąć kiedyś
		$"%Goal".connect("goal_entered", Callable(events, "exit_reached"))

@onready var MATERIALS_TO_CHECK = [Const.Materials.LUMEN, Const.Materials.DEAD_LUMEN, Const.Materials.CLAY, Const.Materials.DIRT, Const.Materials.STRONG_SCRAP, Const.Materials.WEAK_SCRAP, Const.Materials.ULTRA_SCRAP]

func _exit_tree():
	if Engine.is_editor_hint():
		return
	if is_instance_valid(post_process):
		post_process.stop_build_mode(Vector2(0.0,0.0))
	var material_histogram = pixel_map.get_materials_histogram(false)
	
	var cleared = true
	for mat in MATERIALS_TO_CHECK:
		if material_histogram[mat] > 1:
			cleared = false
			break

	if cleared:
		SteamAPI.unlock_achievement("RIP")
	
	if SteamAPI.singleton:
		SteamAPI.singleton.storeStats()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_nan(Utils.game.camera.get_camera_screen_center().y):
		return
	if not started:
		started = true
	pickables.set_pickables_draw_distance(Utils.game.screen_diagonal_radius_scaled)
#	pickables.set_pickables_draw_distance(Save.config.screen_diagonal/2/4)
	wave_manager.process(delta)

	pickables.update_focus_circle(Utils.game.camera.get_camera_screen_center(), 9999)
	
#	if Input.is_action_just_pressed("p1_build"):
#		$"%endgame".endgame_start()

func apply_player_start(player):
	for stat in start_config.get("stats", {}):
		if stat != "clones":
			player.set(stat, start_config.stats[stat])
	
	for item in start_config.get("inventory", []):
		player.add_item(Const.ItemIDs.keys().find(item.id), item.amount, item.get("data"), false)
	
	player.heal(10000)
	player.expend_stamina(-10000)

func apply_start():
	for upgrade in start_config.get("upgrades", {}):
		for i in Const.PLAYER_LIMIT:
			Save.set_unlocked_tech(str("player", i, upgrade), start_config.upgrades[upgrade])
	
	var stats: Dictionary = start_config.get("stats", {})
	if "clones" in stats:
		Save.clones = stats.clones
	
	for upgrade in start_config.get("weapon_upgrades", []):
		Save.set_unlocked_tech(upgrade, start_config.weapon_upgrades[upgrade])
	
	for tech in start_config.get("technology", {}):
		if start_config.technology[tech] == 1:
			Save.unlock_tech(tech)
		elif start_config.technology[tech] == 2:
			blocked_technology.append(tech)
	
	for player in Utils.game.players:
		apply_player_start(player)
	
#	started = true
	emit_signal("initialized")

func restore_pickable_callback():
	pixel_map.set_destruction_callback(400, self, "pixels_destroyed")

const PICKABLE_VEL = 150.0
func pixels_destroyed(pos: Vector2, mat: int, value: int):
	if not mat in Const.MaterialResources:
		return
	var amount := 1

	pickables.spawn_premium_pickable_nice(pos, Const.MaterialResources[mat])
	emit_signal("pickables_spawned", Const.MaterialResources[mat], amount)
	if mat == Const.Materials.LUMEN:
		remainig_lumen -= value

func test_OCD():
	if Utils.explosion_accum.has(Const.Materials.LUMEN):
		if remainig_lumen <= Utils.explosion_accum[Const.Materials.LUMEN]:
			SteamAPI.unlock_achievement("OCD") 

const LAVA_FX_THRESHOLD = 1

func pixels_destroyed_by_fluid(pos: Vector2, mat: int, value: int):
	if mat >= materials_lava_smoke_counters.size():
		return

	materials_lava_smoke_counters[mat] += value
	if materials_lava_smoke_counters[mat] >= LAVA_FX_THRESHOLD:
		var col=Color(1.0,0.6,0.4)*randf()
		col.a=0.8
		pixel_map.smoke_manager.spawn_in_position(pos, 2,Vector2(),col)
		Utils.get_audio_manager("burn_audio").play(pos)
		materials_lava_smoke_counters[mat] -= LAVA_FX_THRESHOLD


func pixels_burned(pos: Vector2, mat: int, new_mat: int, value: int):
	pixel_map.fire_manager.spawn_in_position(pos, 1)
	var damager=preload("res://Nodes/Effects/Smoke/FireDamage.tscn").instantiate()
	Utils.init_player_projectile(damager,damager, {damage=2})
	damager.global_position=pos
	add_child(damager)
	var fire_man=Utils.get_audio_manager("fire_audio")
	if !fire_man._playing:
		Utils.play_sample("res://SFX/Lava/fire_ignite.wav")
	fire_man.play(pos)

func force_tracker_focus():
	var update_pos := Vector2()
	var update_size := 99999999.0
	enemy_tracker.updateFocusCircle(update_pos, update_size)
	enemy_tracker.updateTracker()
	pickup_tracker.updateFocusCircle(update_pos, update_size)
	pickup_tracker.updateTracker()
	player_tracker.updateFocusCircle(update_pos, update_size)
	player_tracker.updateTracker()
	pet_tracker.updateFocusCircle(update_pos, update_size)
	pet_tracker.updateTracker()
	common_buildings_tracker.updateFocusCircle(update_pos, update_size)
	common_buildings_tracker.updateTracker()
	gate_buildings_tracker.updateFocusCircle(update_pos, update_size)
	gate_buildings_tracker.updateTracker()
	power_expander_buildings_tracker.updateFocusCircle(update_pos, update_size)
	power_expander_buildings_tracker.updateTracker()
	turret_buildings_tracker.updateFocusCircle(update_pos, update_size)
	turret_buildings_tracker.updateTracker()
	mine_buildings_tracker.updateFocusCircle(update_pos, update_size)
	mine_buildings_tracker.updateTracker()
	passive_buildings_tracker.updateFocusCircle(update_pos, update_size)
	passive_buildings_tracker.updateTracker()
	lights_tracker.updateFocusCircle(update_pos, update_size)
	lights_tracker.updateTracker()
	flares_tracker.updateFocusCircle(update_pos, update_size)
	flares_tracker.updateTracker()
	danger_tracker.updateFocusCircle(update_pos, update_size)
	danger_tracker.updateTracker()

func store_tracker_nodes(save_file):
	for node in enemy_tracker.getAllNotFocusedTrackingNodes2D():
		save_file.store_node(node, -1)
	
	for node in pickup_tracker.getAllNotFocusedTrackingNodes2D():
		save_file.store_node(node, -1)
	
	for node in player_tracker.getAllNotFocusedTrackingNodes2D():
		save_file.store_node(node, -1)
	
	for node in pet_tracker.getAllNotFocusedTrackingNodes2D():
		save_file.store_node(node, -1)
	
	for node in common_buildings_tracker.getAllNotFocusedTrackingNodes2D():
		save_file.store_node(node, -1)
	
	for node in gate_buildings_tracker.getAllNotFocusedTrackingNodes2D():
		save_file.store_node(node, -1)
	
	for node in power_expander_buildings_tracker.getAllNotFocusedTrackingNodes2D():
		save_file.store_node(node, -1)
	
	for node in turret_buildings_tracker.getAllNotFocusedTrackingNodes2D():
		save_file.store_node(node, -1)
	
	for node in mine_buildings_tracker.getAllNotFocusedTrackingNodes2D():
		save_file.store_node(node, -1)
	
	for node in passive_buildings_tracker.getAllNotFocusedTrackingNodes2D():
		save_file.store_node(node, -1)
	
	for node in lights_tracker.getAllNotFocusedTrackingNodes2D():
		save_file.store_node(node, -1)
	
	for node in flares_tracker.getAllNotFocusedTrackingNodes2D():
		save_file.store_node(node, -1)
	
	for node in danger_tracker.getAllNotFocusedTrackingNodes2D():
		save_file.store_node(node, -1)

func get_tracker_nodes() -> Array:
	var ret: Array
	ret.append_array(enemy_tracker.getAllNotFocusedTrackingNodes2D())
	ret.append_array(pickup_tracker.getAllNotFocusedTrackingNodes2D())
	ret.append_array(player_tracker.getAllNotFocusedTrackingNodes2D())
	ret.append_array(pet_tracker.getAllNotFocusedTrackingNodes2D())
	ret.append_array(common_buildings_tracker.getAllNotFocusedTrackingNodes2D())
	ret.append_array(gate_buildings_tracker.getAllNotFocusedTrackingNodes2D())
	ret.append_array(power_expander_buildings_tracker.getAllNotFocusedTrackingNodes2D())
	ret.append_array(turret_buildings_tracker.getAllNotFocusedTrackingNodes2D())
	ret.append_array(mine_buildings_tracker.getAllNotFocusedTrackingNodes2D())
	ret.append_array(passive_buildings_tracker.getAllNotFocusedTrackingNodes2D())
	ret.append_array(lights_tracker.getAllNotFocusedTrackingNodes2D())
	ret.append_array(flares_tracker.getAllNotFocusedTrackingNodes2D())
	ret.append_array(danger_tracker.getAllNotFocusedTrackingNodes2D())
	return ret

func set_disable_darkness(d: bool):
	disable_darkness = d
	
	if not is_inside_tree():
		await self.ready
	
	$PixelMap/MapDarkness/Darkness.visible = not disable_darkness

func set_disable_fog_of_war(d: bool):
	disable_fog_of_war = d
	
	if Engine.is_editor_hint():
		return
	
	if not is_inside_tree():
		await self.ready
	
	get_tree().call_group("fog_of_war", "set_visible", not disable_fog_of_war)

func try_exit() -> bool:
	if events:
		return events._try_exit()
	else:
		return true

func get_material_occlusion_mask(on_stand: bool) -> int:
	var mask: int = material_occlusion_mask
	if on_stand:
		mask &= Utils.turret_bullet_collision_mask
	return mask

func register_event_object(node: Node):
#	prints(event_object_list.size(), node.get_script().resource_path)
	node.set_meta("event_id", event_object_list.size())
	node.add_to_group("event_objects")
	event_object_list.append(node)

func get_event_object(id: int) -> Node:
	if not is_instance_valid(event_object_list[id]):
		return null
	return event_object_list[id]

func add_editor_object(object: Node):
	if object == null:
		event_object_list.append(null)
		return
	
	add_child(object, true)
	register_event_object(object)

var dmg_numbers = []
var dmg_numbers_max_count := 100
var dmg_numbers_idx := 0
@onready var dmg = preload("res://Nodes/UI/DamageNumber.tscn")

func add_dmg_number():
#	if not Save.config.show_damage_numbers:
#		return
#	if is_instance_valid(dmg_numbers[dmg_numbers_idx]):
#		dmg_numbers[dmg_numbers_idx].queue_free()
#	var dmg_inst = dmg.instance()
#	dmg_numbers[dmg_numbers_idx] = dmg_inst
	dmg_numbers_idx = (dmg_numbers_idx+1) % dmg_numbers_max_count
	if not dmg_numbers[dmg_numbers_idx].is_inside_tree():
		add_child(dmg_numbers[dmg_numbers_idx])
	return dmg_numbers[dmg_numbers_idx]

func draw_border(drawer: CanvasItem) -> void:
	var pixise := pixel_map.get_texture().get_size()
	drawer.draw_texture_rect(preload("res://Resources/Terrain/MapBorder.png"), Rect2(-800, 0, 100000, 49), true) # góra
	drawer.draw_rect(Rect2(-800, -10000, 100000, 10001), Color.BLACK)
	drawer.draw_texture_rect(preload("res://Resources/Terrain/MapBorder.png"), Rect2(pixise.x * 8 - 49, -800, -100000, -49), true, Color.WHITE, true) # prawo
	drawer.draw_rect(Rect2(pixise.x * 8 - 1, -800, 10001, 100000), Color.BLACK)
	drawer.draw_texture_rect(preload("res://Resources/Terrain/MapBorder.png"), Rect2(-800, pixise.y * 8 - 49, 100000, -49), true) # dół
	drawer.draw_rect(Rect2(-800, pixise.y * 8 - 1, 100000, 10000), Color.BLACK)
	drawer.draw_texture_rect(preload("res://Resources/Terrain/MapBorder.png"), Rect2(-750, 0, 100000, 799), true, Color.WHITE, true) # lewo
	drawer.draw_rect(Rect2(-10000, -800, 10001, 100000), Color.BLACK)
