extends BaseBuilding

#onready var swarm: SwarmEnemies = Utils.game.map.pixel_map.get_addon("SwarmEnemies")
@onready var computer := get_node_or_null("TurretComputer")
@onready var attack_range_visual := get_node_or_null("attack_range_visual")
@onready var attack_range_upgrade_visual := get_node_or_null("attack_range_upgrade_visual")

@export var enable_accurate_targeting: bool
var max_range: float

@export var base_max_range: float

var target = null
var target_position: Vector2
var target_velocity: Vector2
var swarm: Swarm = null
var prioritize_swarm_as_target: bool = false

var start_upgrades: Dictionary
var increase_limit_on_start := true

@onready var private_timer_refresh_target_tick_30 = randi()%30

signal upgraded

func _init() -> void:
	add_to_group("defense_tower")

func _ready() -> void:
	max_range = base_max_range
	
	if attack_range_visual:
		attack_range_visual.set_meta("range_expander_color", 2)
		attack_range_visual.add_to_group("range_draw")
		attack_range_visual.set_meta("range_expander_radius", max_range)
		attack_range_visual.visible=false
		attack_range_visual.circle_radius= max_range
	
	if attack_range_upgrade_visual:
		attack_range_upgrade_visual.set_meta("range_expander_color", 3)
		attack_range_upgrade_visual.add_to_group("range_draw")
		attack_range_upgrade_visual.set_meta("range_expander_radius", max_range+30)
		attack_range_upgrade_visual.visible=false
		attack_range_upgrade_visual.circle_radius= max_range
	
	
	if hack:
		return
	
	look_for_enemy()

func add_to_tracker():
	Utils.add_to_tracker(self, Utils.game.map.turret_buildings_tracker, radius, 999999)

func build():
	super.build()
	
	if not get_tree().paused: # Nie pokazuj podczas wczytywania mapy
		SteamAPI.increment_stat("TurretsBuilt")
		SteamAPI.fail_achievement("WIN_NO_TURRETS")
	
	if not computer:
		await self.ready
	computer.detector.can_interact = true

func private_update_target_data():
	if target is int:
		if swarm:
			var pos = swarm.getUnitPosition(target)
			if not is_nan(pos.x):
				target_position = pos
				target_velocity = swarm.getUnitVelocity(target) if enable_accurate_targeting else Vector2.ZERO
				return
	elif target and target is BaseEnemy:
		target_position = target.global_position
		var vel = target.get("velocity") if enable_accurate_targeting else Vector2.ZERO
		target_velocity = vel if vel else Vector2.ZERO
		return

	target = null
	swarm = null
	target_position = Vector2(-1, -1)
	target_velocity = Vector2.ZERO

func private_find_new_node_target():
	target = Utils.game.map.enemies_group.get_closest_tracking_node2d_in_circle_that_pass_raycast_test_on_pixel_map(global_position, max_range, true, Utils.game.map.pixel_map, Utils.turret_bullet_collision_mask, true, radius)
	swarm = null

func private_find_new_swarm_target():
	var found_target_data_result = Utils.game.map.enemies_group.get_closest_swarm_unit_in_circle_that_pass_raycast_test_on_pixel_map(global_position, max_range, true, true, Utils.turret_bullet_collision_mask, true, radius)
	if found_target_data_result:
		var swarm_unit_id = found_target_data_result.swarm_unit_id
		if swarm_unit_id != -1:
			swarm = found_target_data_result.node
			target = swarm_unit_id
			return

	target = null
	swarm = null

func private_find_new_target():
	if prioritize_swarm_as_target:
		private_find_new_swarm_target()
		if not (target is int):
			private_find_new_node_target()
	else:
		private_find_new_node_target()
		if not target:
			private_find_new_swarm_target()

func refresh_target_data(look_for_new_target = true):
	private_timer_refresh_target_tick_30 += 1
	if private_timer_refresh_target_tick_30 >= 30:
		private_timer_refresh_target_tick_30 -= 30

	if target is int:
		if swarm and is_instance_valid(swarm):
			target_position = swarm.getUnitPosition(target)
			if not is_nan(target_position.x):
				var target_hp := swarm.getUnitHP(target)
				if  target_hp > 0:
					var to_target := target_position - global_position
					var to_target_len := to_target.length()
					var target_radius := swarm.getUnitRadius()
					if to_target_len - target_radius <= max_range:
						if to_target_len > radius + target_radius:
							var dir := to_target/to_target_len
							var ray_cast_result := Utils.game.map.pixel_map.rayCastQTDistance(global_position + dir*radius, dir, to_target_len - radius - target_radius, Utils.turret_bullet_collision_mask, true)
							if not ray_cast_result:
								target_velocity = swarm.getUnitVelocity(target) if enable_accurate_targeting else Vector2.ZERO
								return
						else:
							target_velocity = swarm.getUnitVelocity(target) if enable_accurate_targeting else Vector2.ZERO
							return
	elif target and is_instance_valid(target) and target is BaseEnemy and target.is_inside_tree() and not target.is_dead:
		target_position = target.global_position
		var to_target := target_position - global_position
		var to_target_len := to_target.length()
		var target_radius: float = target.radius
		if to_target_len - target_radius <= max_range:
			if to_target_len > radius + target_radius:
				var dir := to_target/to_target_len
				var ray_cast_result := Utils.game.map.pixel_map.rayCastQTDistance(global_position + dir*radius, dir, to_target_len - radius - target_radius, Utils.turret_bullet_collision_mask, true)
				if not ray_cast_result:
					target_velocity = target.velocity if enable_accurate_targeting and "velocity" in target else Vector2.ZERO
					return
			else:
				target_velocity = target.velocity if enable_accurate_targeting and "velocity" in target else Vector2.ZERO
				return

	target = null
	swarm = null

	if look_for_new_target:
		private_find_new_target()

	private_update_target_data()

func look_for_enemy():
	pass

func stop_looking():
	pass

var angle_to_target := 0.0
var distance_to_target := 0.0
var has_target_solution = false

func update_targeting_solution(projectile_velocity: float):
	has_target_solution = false
	var vector_to_target := target_position - global_position
	
	if target_velocity == Vector2():
		has_target_solution = true
		angle_to_target = global_position.direction_to(target_position).angle()
		distance_to_target = vector_to_target.length()
	
	var a := target_velocity.length_squared() - pow(projectile_velocity, 2)
	var b := 2.0 * target_velocity.dot( vector_to_target )
	var c := vector_to_target.length_squared()
	var discriminant := b * b - 4.0 * a * c
	
	if discriminant >= 0: # if discriminant <0 then NO
		var distance = sqrt( discriminant )
		var time_1 = (-b - distance) / (2.0 * a)
		var time_2 = (-b + distance) / (2.0 * a)

		if time_1 < 0.0 or time_2 < time_1 and time_2 >= 0.0:
			time_1 = time_2
		
		if time_1 >= 0.0:
			angle_to_target = (vector_to_target + target_velocity * time_1).angle()
			has_target_solution = true

func get_angle() -> float:
	return 0.0

func set_disabled(disabled: bool, force := false):
	super.set_disabled(disabled, force)
	if computer and not computer.full:
		computer.set_disabled(disabled)

func _get_save_data() -> Dictionary:
	return Utils.merge_dicts(super._get_save_data(), {start_upgrades = computer.get_upgrade_dict()})

func _set_save_data(data: Dictionary):
	super._set_save_data(data)
	start_upgrades = data.start_upgrades

#func can_connect() -> bool:
#	return BaseBuilding.get_turret_count() < BaseBuilding.get_max_turrets()
