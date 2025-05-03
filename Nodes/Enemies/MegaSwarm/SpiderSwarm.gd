@tool
extends Swarm
class_name SwarmSpider
@export var probability_spawn_resource=20
@export var how_many: int = 100
@export var max_hp: int
@export var spawn_radius := 30.0
@export var custom_spawn_trigger_radius=-1
var spawn_trigger_radius=-1
@export var triggered=true
@export var max_speed=100
@export var max_angular_speed=PI
@export var unit_radius=5

@export var spawn_delay := 0.0
@export var spawn_velocity_multiplier := 1.0

@export var attack_range=10
@export var attack_delay=1.0

@export var terrain_attack_radius=8
@export var terrain_attack_damage=20
@export var terrain_attack_hardness=3


@export var other_attack_damage: int
@export var other_attack_radius=3

@export var auto_remove = true
@export var prioritize_player = false
@export var just_wander = false
@export var custom_reality_bubble_radius = -1.0
@export var spawn_only_on_empty = false
@export var attacks_terrain = true

@export var unit_direction_at_spawn : Vector2 = Vector2(0.0, 0.0)

@export var _killed: int
@export var _infinity: bool

@export var walk_sound_manager= "swarm_walk"
@export var attack_sound_manager= "swarm_attack"
@export var dead_sound_manager= "swarm_dead"

var spawn_unit_on_materials_mask = 1 << Const.Materials.DIRT | 1 << Const.Materials.LAVA | 1 << Const.Materials.TAR | 1 << Const.Materials.WATER | Utils.walls_mask | 1 << Const.Materials.FOAM | 1 << Const.Materials.FOAM2
var unit_collision_mask = Utils.walkable_collision_mask
var unit_avoidance_mask = 0xFFFFFFFF ^ (Utils.walls_and_gate_mask | 1 << Const.Materials.LOW_BUILDING | 1 << Const.Materials.FOAM | 1 << Const.Materials.FOAM2 | 1 << Const.Materials.TAR)
var unit_go_through_mask = Utils.monster_path_mask | 1 << Const.Materials.DIRT

var current_damaged_position: Vector2
var current_damaged_hp: float

var enemies_spawned: int
var enemies_killed: int
var spawn_timer: float
var player_target_timer: float = -1
var swarm_data: Dictionary

@export var mod_color:=Color.WHITE
var flying=0

signal finished
signal died
signal spawned_enemy
signal spawned_resource

var data_to_load: PackedByteArray

func get_enemy_radius():
	return unit_radius

func getPFMaterialsCosts():
	return PathFinding.material_cost

func get_pathfinding_params():
	return [unit_go_through_mask, getPFMaterialsCosts(), Utils.game.map.pixel_map.getOptimalPFLvlResolution(unit_radius) ]

func test_init(pixelmap):
	init(pixelmap,unit_radius, max_speed, max_hp, spawn_radius, 0, 0, 0, 0)

func pre_ready():
	pass

func _ready():
	pre_ready()
	if swarm_data.is_empty():
		for enemy in Const.Enemies.values():
			if enemy.is_swarm and enemy.scene == scene_file_path:
				swarm_data = enemy
				break
	
	if max_hp == 0:
		max_hp = swarm_data.hp
	
	if other_attack_damage == 0:
		other_attack_damage = swarm_data.damage
	
	if Engine.is_editor_hint():
		return
		
	if not Utils.game:
		set_physics_process(false)
		set_process(false)
		return
	
	add_to_group("config_observers")
	

	
	if modulate != Color.WHITE:
		mod_color=modulate
		modulate = Color.WHITE
	
	if mod_color != Color.WHITE:
		var spr=Utils.get_node_by_type(self, Sprite2D)
		if spr:
			spr.modulate = mod_color
	
	await get_tree().physics_frame

	if spawn_only_on_empty:
		spawn_unit_on_materials_mask = 1 << Const.Materials.EMPTY

	if !just_wander:
		unit_avoidance_mask &= 0xFFFFFFFF ^ (1 << Const.Materials.LAVA)

	init(Utils.game.map.pixel_map,unit_radius, max_speed, max_hp, spawn_radius, spawn_unit_on_materials_mask, unit_collision_mask, unit_avoidance_mask, unit_go_through_mask)
	setUnitMaxAngularSpeed(max_angular_speed)

	setWalkAnimationMinSpeedFract(0.1)

	var sprite=Utils.get_node_by_type(self, Sprite2D)
	if sprite:
		sprite.visible=false

	var user_materials_cost=getPFMaterialsCosts()
	setMaterialsPathfindingCost(user_materials_cost, 1.0)

	setDrawHealthBars(Save.config.show_enemy_health)

	setUnitsDrawDistance(Utils.game.screen_diagonal_radius_scaled*1.35)
	spawn_trigger_radius=192.0+spawn_radius
	if custom_spawn_trigger_radius>=0:
		spawn_trigger_radius=custom_spawn_trigger_radius

	if !just_wander:
		if not prioritize_player and Utils.game.core:
			setMainTargetPosition(Utils.game.core.global_position)
		else:
			player_target_timer = 0.001

	var sound_distance = 192.0;
	setup_attacks()
	#addNewAttack(attack_range, attack_delay, self, "terrain_attack", sound_distance, attacks_terrain, true, true)
	setOnDamageCallback(self, "on_damage_callback", sound_distance)
	setWalkingUnitsCallback(self, "walking_units_callback", 0.2, 200, true)
	#addEvadeObjectsTracker(Utils.game.map.enemy_tracker)
#	setEvadeMaxDistance(50)
	addPursuitAndAttackEnemiesTracker(Utils.game.map.player_tracker)
	setEnemyMaxPursuitDistance(unit_radius + (120.0 if just_wander else 60.0))
	addPursuitAndAttackEnemyBuildingsTracker(Utils.game.map.power_expander_buildings_tracker)
	addPursuitAndAttackEnemyBuildingsTracker(Utils.game.map.turret_buildings_tracker)
	addPursuitAndAttackEnemyBuildingsTracker(Utils.game.map.mine_buildings_tracker)
	addPursuitAndAttackEnemyBuildingsTracker(Utils.game.map.common_buildings_tracker)
	addLightsTracker(Utils.game.map.lights_tracker)
	addLightsTracker(Utils.game.map.flares_tracker)
	setLightsAvoidanceForceMultiplier(0.75)
	setEnemyBuildingMaxPursuitDistance(unit_radius + 18.0)
	setUserMaterialDamageToUnits(Const.Materials.LAVA, 5.0, 1.0)
	setUserMaterialUsitsSpeedMultiplier(Const.Materials.LAVA, 0.5)

	Utils.subscribe_tech(self, "sticky_napalm")
	
	if not _infinity:
		if _killed >= how_many and how_many > -1:
			queue_free()
		else:
			how_many -= _killed
			_killed = 0
	
	if data_to_load:
		loadUnitsStateFromBinaryData(data_to_load)
		enemies_spawned = getNumOfLivingUnits()
		
		if enemies_spawned > 0:
			add_to_group("MegaSwarm")
	additional_setup()

func _enter_tree():
	Utils.game.map.enemies_group.add(self)

func _exit_tree():
	Utils.game.map.enemies_group.remove(self)

func setup_attacks():
	var sound_distance = 192.0;
	addNewAttack(attack_range, attack_delay, self, "terrain_attack", sound_distance, attacks_terrain, true, true)

func additional_setup():
	pass

func update_config():
	setDrawHealthBars(Save.config.show_enemy_health)

func _tech_unlocked(tech: String):
	if tech == "sticky_napalm":
		setUserMaterialUsitsSpeedMultiplier(Const.Materials.TAR, 0.5);


func custom_spawn(where: Vector2, custom_velocity := -1.0, custom_radius := 0.0):
	global_position = Utils.clamp_to_pixel_map(where, Utils.game.map.pixel_map)
	setSpawnRadius(custom_radius)
	spawn_unit_in_direction(unit_direction_at_spawn, spawn_velocity_multiplier if custom_velocity < 0 else custom_velocity)

func spawn_in_radius_with_delay(pos: Vector2, radius: float, amount: int, delay: float, custom_velocity := -1.0) -> Tween:
	var tween := create_tween()
	for i in amount:
#		custom_spawn(pos, custom_velocity, radius)
		tween.tween_callback(Callable(self, "custom_spawn").bind(pos, custom_velocity, radius)).set_delay(delay)
	
	return tween

func _physics_process(delta):
	if Engine.is_editor_hint() or is_nan(Utils.game.camera.get_screen_center_position().y):
		return
	
	if just_wander:
		updateFocusCircle(Utils.game.camera.get_screen_center_position(), custom_reality_bubble_radius if custom_reality_bubble_radius>=0.0 else 350.0)
	else:
		updateFocusCircle(Utils.game.camera.get_screen_center_position(), custom_reality_bubble_radius if custom_reality_bubble_radius>=0.0 else 10000.0)
		if player_target_timer >= 0:
			player_target_timer -= delta
			if player_target_timer < 0:
				player_target_timer = 2
				setMainTargetPosition(Utils.game.players[randi() % Utils.game.players.size()].global_position)

	if !triggered and spawn_trigger_radius>=0:
		if Utils.game.map.player_tracker.getClosestTrackingNode2DInCircle(global_position,spawn_trigger_radius,true):
			triggered=true
	if triggered and enemies_spawned < how_many:
		spawn_timer += delta
		var possible_to_spawn=10 if spawn_delay==0.0 else int(min(spawn_timer/spawn_delay,10))

		add_to_group("MegaSwarm")
		
		for i in possible_to_spawn:
			if spawn_unit_in_direction(unit_direction_at_spawn, spawn_velocity_multiplier):
				spawn_timer -= spawn_delay
	
				emit_signal("spawned_enemy")
				enemies_spawned += 1
				if enemies_spawned == how_many:
					emit_signal("finished")
					return
			else:
				break

func _process(delta):
	if Engine.is_editor_hint():
		setUnitsDrawDistance(100000)	
	else:
		setUnitsDrawDistance(Utils.game.screen_diagonal_radius_scaled*1.35)

#func _draw():
#	drawDebug(true)
#	drawDebug(true, true, true, true, true)
#	pass

func terrain_attack(attack_id: int, position: Vector2, heading: Vector2, target: Node, attacker_unit_id: int, in_distance_from_focus_check: bool):
	var dmg_position = position + heading * (unit_radius)
	#Utils.explode_circle(position, terrain_attack_radius, terrain_attack_damage, terrain_attack_hardness, 9)
	Utils.explode_circle(dmg_position, terrain_attack_radius, terrain_attack_damage, terrain_attack_hardness, 9)

	var damager=preload("res://Nodes/Enemies/MegaSwarm/Damager.tscn").instantiate()
	damager.scale=Vector2.ONE*other_attack_radius
	Utils.init_enemy_projectile(damager,damager, {damage=other_attack_damage})
	add_child(damager)
	damager.global_position = dmg_position
	if in_distance_from_focus_check:
		Utils.get_audio_manager(attack_sound_manager).play(position)

func on_damage_callback(position: Vector2, damager: Node, unit_id: int, in_distance_from_focus_check: bool):
	var computed_id := (get_index() << 32) | unit_id
	
	var data: Dictionary = damager.get_meta("data")
	if data.get("destroyed", false):
		return
	
	if not "ids" in data:
		data.ids = {}
	
	var damage_timeout: float = data.get("damage_timeout", 20.0)
	if data.ids.get(computed_id, -1000000) >= Utils.game.frame_from_start - damage_timeout:
		return
	
	data.hit_swarm = true
	
	current_damaged_position = position
	current_damaged_hp = getUnitHP(unit_id)
	
	var damage := BaseEnemy.handle_damage(self, {evade_heavy = true, miss_chance = 98, id = unit_id, flying=flying}, data)
	var hp_left := damageUnit(unit_id, damage)
	Utils.get_audio_manager("gore_hit").play(position)
	data.ids[computed_id] = Utils.game.frame_from_start
	
	if hp_left <= 0:
		_killed += 1
		emit_signal("died")
		Save.count_score("enemies_slain")
		SteamAPI.increment_stat("KilledBugs")
		get_tree().call_group("kill_observers", "enemy_killed", swarm_data.name)
		
		var velocity_killed = data.get("velocity", Vector2())
		Utils.game.map.pixel_map.flesh_manager.spawn_in_position(position, 4,velocity_killed*0.2)
		if in_distance_from_focus_check:
			Utils.get_audio_manager(dead_sound_manager).play(position)
		Utils.game.map.blood_spawner.add_splat(position, velocity_killed)
		if probability_spawn_resource > 0:
			var what_to_spawn=randi()% probability_spawn_resource
			if what_to_spawn==0:
				Utils.game.map.pickables.spawn_premium_pickable_nice(position, Const.ItemIDs.LUMEN)
				emit_signal("spawned_resource")
			elif what_to_spawn==1:
				Utils.game.map.pickables.spawn_premium_pickable_nice(position, Const.ItemIDs.METAL_SCRAP)
				emit_signal("spawned_resource")
		
		enemies_killed += 1
		if auto_remove and enemies_killed == enemies_spawned:
			get_tree().create_timer(16).connect("timeout", Callable(self, "queue_free"))
	else:
		Utils.game.start_battle()

func is_kill_damage(damage: int) -> bool:
	return damage >= current_damaged_hp

func on_damage_number(number: Node2D):
	number.global_position = current_damaged_position

func walking_units_callback(units_positions: PackedVector2Array, units_ids: PackedInt32Array, num_of_units_in_distance_from_focus_check: int, average_speed: float, max_speed_in_range: float, max_speed_unit_id: int):
	#getUnitVelocity(max_speed_unit_id)

	var man=Utils.get_audio_manager(walk_sound_manager)
	#avarage speed sound
	var volume_ratio=clamp(max_speed_in_range/max_speed,0.0,1.0)
	man.play(getUnitPosition(max_speed_unit_id), linear_to_db(volume_ratio))

	for idx in range(0,num_of_units_in_distance_from_focus_check,4):
		if man.overplayed():
			break
		volume_ratio=clamp(getUnitVelocity(idx).length()/max_speed,0.0,1.0)
		man.play(units_positions[idx], linear_to_db(volume_ratio))

func _get_save_data() -> Dictionary:
	return {swarm_data = getUnitsStateBinaryData()}

func _set_save_data(data: Dictionary):
	data_to_load = data.swarm_data
