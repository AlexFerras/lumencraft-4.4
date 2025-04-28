extends Swarm
class_name SwarmHelper

@export var max_hp: int = 100

@export var max_speed = 64
@export var max_angular_speed = PI

@export var radius = 5

@export var attack_range = 10
@export var attack_delay = 1.0

@export var walk_sound_manager= "swarm_walk"
@export var attack_sound_manager= "swarm_attack"
@export var dead_sound_manager= "swarm_dead"

var shoot_attack_range := 100.0
var shoot_attack_cooldown := 2.0

var spawn_unit_on_materials_mask = 1 << Const.Materials.DIRT | 1 << Const.Materials.LAVA | 1 << Const.Materials.TAR | 1 << Const.Materials.WATER | Utils.walls_mask | 1 << Const.Materials.FOAM| 1 << Const.Materials.FOAM2 | 1 << Const.Materials.STOP
var unit_collision_mask = 0xFFFFFFFF ^ (1 << Const.Materials.LAVA | 1 << Const.Materials.TAR | 1 << Const.Materials.WATER)
var unit_avoidance_mask = 0xFFFFFFFF ^ (Utils.walls_mask | 1 << Const.Materials.GATE| 1 << Const.Materials.LOW_BUILDING| 1 << Const.Materials.FOAM| 1 << Const.Materials.FOAM2 |1 << Const.Materials.TAR)
#var unit_go_through_mask = 1 << Const.Materials.TAR | Utils.walls_mask | 1 << Const.Materials.GATE | 1 << Const.Materials.LOW_BUILDING |  1 << Const.Materials.DIRT | 1 << Const.Materials.FOAM| 1 << Const.Materials.FOAM2
var unit_go_through_mask = 1 << Const.Materials.TAR |  1 << Const.Materials.DIRT

var helper_data: Dictionary

var data_to_load: PackedByteArray

var position_offset_from_player := Vector2.ZERO

func getPFMaterialsCosts():
	var user_materials_cost=PathFinding.material_cost
	user_materials_cost[Const.Materials.DIRT] = user_materials_cost[Const.Materials.DIRT] * 2

	return user_materials_cost

func get_pathfinding_params():
	return [unit_go_through_mask, getPFMaterialsCosts(), Utils.game.map.pixel_map.getOptimalPFLvlResolution(radius) ]

func _ready():
	add_to_group("config_observers")


	await get_tree().physics_frame

	init(Utils.game.map.pixel_map, radius, max_speed, max_hp, 1, spawn_unit_on_materials_mask, unit_collision_mask, unit_avoidance_mask, unit_go_through_mask)
	setUnitMaxAngularSpeed(max_angular_speed)

	setWalkAnimationMinSpeedFract(0.00)

	var sprite = Utils.get_node_by_type(self, Sprite2D)
	if sprite:
		sprite.visible=false

	var user_materials_cost = getPFMaterialsCosts()
	setMaterialsPathfindingCost(user_materials_cost, 1.0)

	setDrawHealthBars(Save.config.show_enemy_health)

	setUnitsDrawDistance(Utils.game.screen_diagonal_radius_scaled)

	var sound_distance = 192.0
	
#	addNewAttack(attack_range, attack_delay, self, "terrain_attack", sound_distance, false, true, true)
	addNewAttack(shoot_attack_range, shoot_attack_cooldown, self, "shoot_attack", 0, false, false, true)
	
#	addNewAttack(attack_range, attack_delay, self, "terrain_attack", sound_distance, false, true, true)
	setOnDamageCallback(self, "on_damage_callback", sound_distance)
	setWalkingUnitsCallback(self, "walking_units_callback", 0.2, 200, true)
	
	addEvadeObjectsTracker(Utils.game.map.enemy_tracker)
	setEvadeMaxDistance(20)

	addPursuitAndAttackEnemiesTracker(Utils.game.map.enemy_tracker)
#	setEnemyMaxPursuitDistance(radius + 120.0)
	setUserMaterialDamageToUnits(Const.Materials.LAVA, 5.0, 1.0)
	
	Utils.subscribe_tech(self, "sticky_napalm")
	
	for i in 1:
		spawn_unit_in_direction(Vector2.DOWN, 0.0)
	add_to_group("MegaSwarm")

func shoot_attack(attack_id: int, position: Vector2, heading: Vector2, target: Node, in_distance_from_focus_check: bool):
	var bullet = preload ("res://Nodes/Player/Pets/ShootingPetBlaster.tscn").instantiate() as Node2D
#	bullet.damage = 1
	bullet.rotation = position.direction_to(target.global_position).angle()
	bullet.position = position + heading * radius
#	bullet.dir = position.direction_to(target.global_position)
#	bullet.max_range = shoot_attack_range

	Utils.game.map.add_child(bullet)
	
func update_config():
	setDrawHealthBars(Save.config.show_enemy_health)

func _tech_unlocked(tech: String):
	if tech == "sticky_napalm":
		setUserMaterialUsitsSpeedMultiplier(Const.Materials.TAR, 0.5)


var timer := 3.0
func _physics_process(delta):
	if is_nan(Utils.game.camera.get_camera_screen_center().y):
		return
	updateFocusCircle(Utils.game.camera.get_camera_screen_center(), 10000.0)
	timer -= delta


#	if !triggered and spawn_trigger_radius>=0:
#		if Utils.game.map.player_tracker.getClosestTrackingNode2DInCircle(global_position,spawn_trigger_radius,true):
#			triggered=true

func _process(delta):
	setUnitsDrawDistance(Utils.game.screen_diagonal_radius_scaled)

#func _draw():
#	drawDebug(true)
#	drawDebug(true, true, true, true, true)
#	pass
#
#func terrain_attack(attack_id: int, position: Vector2, heading: Vector2, target: Node, in_distance_from_focus_check: bool):
#	var dmg_position = position + heading * (unit_radius)
#	#Utils.explode_circle(position, terrain_attack_radius, terrain_attack_damage, terrain_attack_hardness, 9)
#	Utils.explode_circle(dmg_position, terrain_attack_radius, terrain_attack_damage, terrain_attack_hardness, 9)
#
#	var damager=preload("res://Nodes/Enemies/MegaSwarm/Damager.tscn").instance()
#	damager.scale=Vector2.ONE*other_attack_radius
#	Utils.init_enemy_projectile(damager,damager, {damage=other_attack_damage})
#	add_child(damager)
#	damager.global_position = dmg_position
#	if in_distance_from_focus_check:
#		Utils.get_audio_manager(attack_sound_manager).play(position)

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

	var current_damaged_hp = getUnitHP(unit_id)

	var damage := BaseEnemy.handle_damage(self, {evade_heavy = true, miss_chance = 98}, data)
	var hp_left := damageUnit(unit_id, damage)
	Utils.get_audio_manager("gore_hit").play(position)
	data.ids[computed_id] = Utils.game.frame_from_start

#	if hp_left <= 0:
#		Utils.game.map.pickables.spawn_premium_pickable_nice(position, Const.ItemIDs.LUMEN)
#		Utils.game.map.pickables.spawn_premium_pickable_nice(position, Const.ItemIDs.METAL_SCRAP)

#func on_damage_number(number: Node2D):
#	number.global_position = current_damaged_position

func walking_units_callback(units_positions: PackedVector2Array, units_ids: PackedInt32Array, num_of_units_in_distance_from_focus_check: int, average_speed: float, max_speed_in_range: float, max_speed_unit_id: int):
	#getUnitVelocity(max_speed_unit_id)
	
	
	if timer <0:
		timer = 5
		position_offset_from_player = (Vector2.RIGHT * 10).rotated(randf() * TAU)
	
	
	var distance_to_player = units_positions[0].distance_to(Utils.game.main_player.global_position + position_offset_from_player)

	if distance_to_player < 10.0:
		wander_force_multiplier = 0.0
		follow_path_force_multiplier = max(distance_to_player-10, 0) / 40.0
	else:
		wander_force_multiplier = 0.1
		follow_path_force_multiplier = 1.0
#	prints (distance_to_player, follow_path_force_multiplier, wander_force_multiplier)

	setMainTargetPosition(Utils.game.main_player.global_position + position_offset_from_player)

	

	var man = Utils.get_audio_manager(walk_sound_manager)
	#avarage speed sound
	var volume_ratio=clamp(max_speed_in_range/max_speed,0.0,1.0)
	volume_ratio = 0
	man.play(getUnitPosition(max_speed_unit_id), linear_to_db(volume_ratio))

	for idx in range(0,num_of_units_in_distance_from_focus_check,4):
		if man.overplayed():
			break
		volume_ratio=clamp(getUnitVelocity(idx).length()/max_speed,0.0,1.0)
		volume_ratio = 0
		man.play(units_positions[idx], linear_to_db(volume_ratio))

func is_kill_damage(dmg):
	return false

func _get_save_data() -> Dictionary:
	return {swarm_data = getUnitsStateBinaryData()}

func _set_save_data(data: Dictionary):
	data_to_load = data.swarm_data
