extends "res://Nodes/Player/Pets/Pet.gd"

const ATTACK_RANGE = 150
const AVOID_RANGE = 50
const DISTANCE_TO_PLAYER = 40
const DISTANCE_TO_PLAYER_IF_MONSTER = 10
const VISION_RANGE = 1000

var distance_to_p :float

var prev_position: Vector2

var target_enemy = null
var swarm = null
var target_position: Vector2
var walk_to_position: Vector2
var target_prev_position: Vector2
var walk_to_position_distance: float 
var distance_to_target: float
var static_time: float
var speed_max := 100.0
var speed_min := 20.0
var speed_current := 0.0

var shoot_timer := 0.0
var shoot_cooldown := 1.0

var move := Vector2.ZERO
var angle := 0.0
var heading := Vector2.ZERO

var is_path_found: bool
var is_path_through_terrain: bool
var is_state_pathing: bool
var is_stuck :bool
var path_data:PathfindingResultData
var path: Array
var path_index: int
var path_waypoint: Vector2
var path_resolution := 11 # 13 - 1x1px, 12 - 2x2px, 11 - 4x4px, 10 - 8x8, 9 - 16x16, 8 - 32x32,  etc. 

@onready var animator := $PetBody/AnimationPlayer
@onready var walk_audio = $WalkAudio

func _ready() -> void:
	add_to_group("pets")
	prev_position = global_position
#	new_target()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if Utils.is_pixel_buried(global_position):
		state.linear_velocity = Vector2.ZERO
		is_stuck = true
	else:
		pixel_map_physics(state, Utils.walkable_collision_mask)
		is_stuck = false

func _physics_process(delta: float) -> void:
	if is_pushed:
		if get_colliding_bodies():
			walk_to_position = global_position + heading * radius
		else:
			is_pushed = false

	move = global_position.direction_to(walk_to_position)
	distance_to_target = global_position.distance_to(walk_to_position)
	var arrival_distance := radius

	if shoot_timer < shoot_cooldown:
		shoot_timer += delta

	if distance_to_target > arrival_distance or is_pushed:
		static_time = 0
		animator.play("walk")
		if not walk_audio.playing:
			walk_audio.play()
		var velocity = global_position.distance_to(prev_position)
		animator.playback_speed = 60 * velocity
		if is_path_found:
			speed_current = speed_max
			$"%AngryLight".modulate = Color(0.0,3.0,0.0,1.0)
		else:
			if state == ATTACK:
				speed_current = global_position.distance_to(walk_to_position) * 4.0 + 10.0
				$"%AngryLight".modulate = Color(3.0,0.0,0.0,1.0)
			else:
				speed_current = global_position.distance_to(walk_to_position) * 2.0 + 1.0

		
		if not is_stuck:
			linear_velocity = lerp(linear_velocity, move * clamp(speed_current, speed_min, speed_max), 0.2)
			angle = lerp_angle(angle, (global_position - prev_position).angle(), 0.1)
			walk_audio.volume_db = linear_to_db(velocity * 0.8)
			walk_audio.pitch_scale = 0.3 + velocity * 1.6
#		prints(speed_current/speed_max, velocity)
	else:
		if walk_audio.playing:
			walk_audio.stop()

		static_time += delta
		animator.play("idle")
		animator.playback_speed = 30
		angle = lerp_angle(angle, move.angle(), 0.25)
		linear_velocity = Vector2.ZERO

	$PetBody.rotation = angle
	heading = Vector2.RIGHT.rotated(angle)
	prev_position = global_position
	
#	if not is_instance_valid(target_enemy) or not target_enemy.is_dead:
	update_follow_position()

#	update()

func _follow_player(delta: float):
	$Label.text = "follow"
	distance_to_p = DISTANCE_TO_PLAYER
	var is_player_visible = is_position_visible(player.global_position, VISION_RANGE, true)
#	print(private_find_new_target())
	if not private_find_new_target() == null:
		$Label.text = "Aaghhhh"
		private_update_target_data()
		if player.global_position.distance_to(target_position) <= ATTACK_RANGE:
			if is_position_visible(target_position, ATTACK_RANGE):
				distance_to_p = DISTANCE_TO_PLAYER_IF_MONSTER
#update_avoid_position()
				if shoot_timer > shoot_cooldown:
					state = SHOOTING
					Utils.play_sample(Utils.random_sound("res://SFX/Pets/PetNotice"), self, false, 1.4)
	#				state = ATTACK

	if is_player_visible:
#		walk_to_position = player.global_position
#		if static_time > 0:
#			state = IDLE
		is_path_found = false
	else:
		walk_to_position = player.global_position
		process_pathing()

func process_pathing():
	if is_path_found:
		path_waypoint = path_data.get_virtual_point_on_closest_segment(global_position + heading * radius , radius*2) 
		walk_to_position = path_waypoint

		if path_data.get_closest_segment_idx(global_position + heading * radius) == path_data.get_path_nr_of_segments() - 2:
			get_path()
	else:
		get_path()
		if not is_path_found:
#			_die()
#			state = IDLE
			pass

func _idle(delta: float):
	$Label.text = "idle"
	distance_to_p = DISTANCE_TO_PLAYER
	if global_position.distance_to(player.global_position) > distance_to_p + radius:
		state = FOLLOW_PLAYER

#	if private_find_new_target():
#		private_update_target_data()
#		if is_position_visible(target_position, ATTACK_RANGE):
#			state = ATTACK

#func _attack(delta: float):
#	$Label.text = "attack"
#	if not is_instance_valid(target_enemy) or target_enemy.is_dead:
#		target_enemy = null
#		state = FOLLOW_PLAYER
#		return
#
#	if player.global_position.distance_to(target_enemy.global_position) > ATTACK_RANGE:
#		target_enemy = null
#		state = FOLLOW_PLAYER
#		return
#
#	update_avoid_position()
#	if shoot_timer > shoot_cooldown:
#		state = SHOOTING
#		Utils.play_sample(Utils.random_sound("res://SFX/Pets/PetNotice"), self, false, 1.4)
#		walk_to_position = global_position + global_position.direction_to(target_enemy.global_position)
#		if is_looking_at_target():
#			angle = (target_position - global_position).angle()
#			shoot_timer = 0.0
#			shooting_at_things()
#	else:
#		update_avoid_position()
#	walk_to_position = global_position + global_position.direction_to(target_enemy.global_position)

func _shoot(delta: float):
	$Label.text = "shoot"
#	if target_enemy is int
	private_update_target_data()
	if target_enemy and target_enemy is BaseEnemy:
		if not is_instance_valid(target_enemy) or target_enemy.is_dead:
			target_enemy = null
			state = FOLLOW_PLAYER
			return

	walk_to_position = global_position + global_position.direction_to(target_position)
	if is_looking_at_target():
		shoot_timer = 0.0
		shooting_at_things()
		state = FOLLOW_PLAYER

#func update_avoid_position():
#	private_update_target_data()
#	walk_to_position = target_position + (walk_to_position - target_position).normalized() * clamp((global_position - target_position).length(), AVOID_RANGE, ATTACK_RANGE)

func update_follow_position():
	var target: Node2D = player
	walk_to_position_distance = distance_to_p
#	if target_enemy:
#		target = target_enemy
#		walk_to_position_distance = ATTACK_RANGE
#		private_update_target_data()
#
##		walk_to_position = target_position + (walk_to_position - target_position).limit_length(walk_to_position_distance) 
#	else:
	walk_to_position = target.global_position + (walk_to_position - target.global_position).limit_length(walk_to_position_distance)

func _die():
	super._die()
	explode()

func explode():
	var explosion := Const.EXPLOSION.instantiate() as Node2D
	explosion.type = explosion.NEUTRAL
	explosion.scale = Vector2.ONE * 0.1
	explosion.position = global_position
	Utils.game.map.add_child(explosion)

func shooting_at_things():
	var bullet := preload("res://Nodes/Player/Weapons/Ranged/MagnumBullet.tscn").instantiate() as Node2D
	bullet.position = $PetBody/ShootPoint.global_position
	bullet.rotation = angle
	Utils.game.map.add_child( bullet )
	bullet.get_meta("data").damage = 10.0

func is_looking_at_target(minimal_angle := 0.035) -> bool:
	return abs(heading.angle_to(target_position - global_position)) < minimal_angle

func get_path():
	path_data = PathFinding.get_path_from_params(global_position, player.global_position, ~Utils.walkable_collision_mask, PathFinding.material_cost, path_resolution, false)
	if path_data:
		is_path_found = true
		path = path_data.get_path()
		path_index = 0
	else:
		is_path_found = false

func private_update_target_data():
	if target_enemy is int:
		if swarm:
			var pos = swarm.getUnitPosition(target_enemy)
			if not is_nan(pos.x):
				target_position = pos
				return
	elif target_enemy and target_enemy is BaseEnemy:
		target_position = target_enemy.global_position
		return

	target_enemy = null
	swarm = null
	target_position = Vector2(-1, -1)
#	target_velocity = Vector2.ZERO
#
#func refresh_target_data():
#	if target_enemy is int:
#		if swarm and is_instance_valid(swarm):
#			target_position = swarm.getUnitPosition(target)
#			if not is_nan(target_position.x):
#				var target_hp = swarm.getUnitHP(target)
#				if  target_hp > 0:
#					var to_target = target_position - global_position
#					var to_target_len = to_target.length()
#					var target_radius = swarm.getUnitRadius()
#					if to_target_len - target_radius <= max_range:
#						if to_target_len > radius + target_radius:
#							var dir = to_target/to_target_len
#							var ray_cast_result = Utils.game.map.pixel_map.rayCastQTDistance(global_position + dir*radius, dir, to_target_len - radius - target_radius, Utils.turret_bullet_collision_mask, true)
#							if not ray_cast_result:
#								target_velocity = swarm.getUnitVelocity(target) if enable_accurate_targeting else Vector2.ZERO
#								return
#						else:
#							target_velocity = swarm.getUnitVelocity(target) if enable_accurate_targeting else Vector2.ZERO
#							return
#	elif target and is_instance_valid(target) and target is BaseEnemy and target.is_inside_tree() and not target.is_dead:
#		target_position = target.global_position
#		var to_target = target_position - global_position
#		var to_target_len = to_target.length()
#		if to_target_len - target.radius <= max_range:
#			if to_target_len > radius + target.radius:
#				var dir = to_target/to_target_len
#				var ray_cast_result = Utils.game.map.pixel_map.rayCastQTDistance(global_position + dir*radius, dir, to_target_len - radius - target.radius, Utils.turret_bullet_collision_mask, true)
#				if not ray_cast_result:
#					target_velocity = target.velocity if enable_accurate_targeting and "velocity" in target else Vector2.ZERO
#					return
#			else:
#				target_velocity = target.velocity if enable_accurate_targeting and "velocity" in target else Vector2.ZERO
#				return
#
#	target_enemy = null
#	swarm = null
#
#	private_update_target_data()


func get_closest_target():
	target_enemy = Utils.game.map.enemy_tracker.getClosestTrackingNode2DInCircle(player.global_position, ATTACK_RANGE, true)
	return target_enemy

#var target = null

func private_find_new_node_target():
	target_enemy = Utils.game.map.enemies_group.get_closest_tracking_node2d_in_circle_that_pass_raycast_test_on_pixel_map(global_position, ATTACK_RANGE, true, Utils.game.map.pixel_map, Utils.turret_bullet_collision_mask, true, radius)
	swarm = null

func private_find_new_swarm_target():
	var found_target_data_result = Utils.game.map.enemies_group.get_closest_swarm_unit_in_circle_that_pass_raycast_test_on_pixel_map(global_position, ATTACK_RANGE, true, true, Utils.turret_bullet_collision_mask, true, radius)
	if found_target_data_result:
		var swarm_unit_id = found_target_data_result.swarm_unit_id
		if swarm_unit_id != -1:
			swarm = found_target_data_result.node
			target_enemy = swarm_unit_id
			return

	target_enemy = null
	swarm = null

func private_find_new_target():
	var new_target = null
	private_find_new_node_target()
	if target_enemy:
		new_target = target_enemy
		private_find_new_swarm_target()
		private_update_target_data()
		if target_enemy == null:
			target_enemy = new_target
		else:
			if global_position.distance_squared_to(new_target.global_position) < global_position.distance_squared_to(target_position):
				target_enemy = new_target
	else:
		private_find_new_swarm_target()

	return target_enemy



#func new_target():
#	target_position = Vector2()
#	var target: Node2D = player
#	if target_enemy:
#		target = target_enemy
#
#	for i in 1000:
#		if target_position == Vector2() or Utils.game.map.pixel_map.is_pixel_solid(target_position):
#			target_position = target.global_position + Vector2.RIGHT.rotated(randf() * TAU) * rand_range(25, 50)
#			target_position_distance = (target_position - target.global_position).length()

func is_position_visible(pos: Vector2, view_range: float = INF, is_bool:= false) -> bool:
	var distance  := global_position.distance_to(pos)
	var direction := global_position.direction_to(pos)
	
	var col:RayCastResultData
	var col_normal: PixelMapNormalData
	
	if distance <= view_range:
		col = Utils.game.map.pixel_map.rayCastQTDistance(global_position, direction, distance, Utils.walkable_collision_mask, is_bool)
		if col:
			return false
	else:
		return false
	
	return true
	
func _draw():
	draw_circle(walk_to_position - global_position, 2, Color.WHITE)
	draw_pathing()

func on_pushed():
	is_pushed = true
	$"%AngryLight".modulate = Color(3.0,3.0,0.0,1.0)

func draw_pathing():
	if is_path_found: 
		var color = Color(1,1,1)

		draw_rect( Rect2(path_waypoint - global_position, Vector2.ONE), Color.CYAN )
		if path.size() == 0:
			return
#		draw_line( Vector2.ZERO, path_waypoint - global_position , Color(1,1,1,0.7), 2 )
		for i in range( path.size() - 1 ):
			draw_rect( Rect2(path[i] - global_position, Vector2.ONE), color - Color(0,0,0,float(i)/(path.size()+1)) )
			draw_line( path[i] - global_position ,  path[i+1] - global_position , color - Color(0,0,0,float(i)/(path.size()+1)), 1.0 )
		draw_line( Vector2.ZERO , path[ path_index ] - global_position, Color(0,1,0,0.5), 1.0 )
		draw_rect( Rect2(path[ path_index ] - global_position, Vector2.ONE), Color(0,1,0,0.5) )

