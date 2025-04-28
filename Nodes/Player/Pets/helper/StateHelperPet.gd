extends StateAndWalkEnemy
class_name GenericPet

# handles
@onready var attack_shape := $Sprite2D/AttackBox/AttackShape as CollisionShape2D
@onready var steering := $ContextController as ContextController
@onready var targeting := $TargetController as TargetController

@export var base_playback_speed := 30.0
@export var rotation_reaction_speed := 0.2

@export var max_distance_from_spawn_position := 60000.0

@export var is_initialized := false

@export var idle_time := 1.5
var custom_idle_time := 0.0
@export var spawn_position := Vector2.ZERO
var return_to_spawn_position_timer := 0.0
var distance_from_spawn_position := 0.0

var audio_player: AudioStreamPlayer2D
var walking_audio: AudioStreamPlayer2D

var stuck_ticks := 0
var stuck_ticks_limit_frames := 120
var stuck_ticks_limit_distance := 0.0
var stuck_previous_position := Vector2.ZERO

var random_wait_time := 0.0

var previous_position := Vector2.ZERO
var speed_for_animation_playback := 0.0
var pathing_method :int = 0

var front_ray :RayCastResultData
var is_front_ray_colliding := false
var is_front_ray_colliding_with_building := false
var front_ray_hit_position = Vector2.ZERO

@export var charge_cooldown := 5.0
var charge_timer := 5.0
@export var charge_duration := 2.0
var charge_duration_timer := 5.0
@export var charge_speed_multiplier_max := 1.2
var charge_speed_multiplier := 1.0


### DEBUG much -----------------------------------------------------------------------------
#var state_log := []
#var state_log_size := 6
#-------------------------------------------------------------------------------------------

func _init() -> void:
	default_state = "state_idle"

func _ready() -> void:
	Utils.init_enemy_projectile($Sprite2D/AttackBox, $Sprite2D/AttackBox, {damage = damage, keep = true})
	#Utils.init_enemy_projectile($Sprite/AttackBox, $Sprite/AttackBox, {damage = damage, keep = true})
	Utils.init_enemy_projectile(collider, collider, {damage = 1, keep = true})
	collider.collision_layer = Const.ENEMY_COLLISION_LAYER
	
	override_custom_stat("sight_range", steering, "sight_range")
	
#	pathing_method = randi()%2
	pathing_method = 1
	
	if not is_initialized:
		is_initialized = true
		spawn_position = global_position
		walk_speed *= randf_range(0.8,1.25)
		max_distance_from_spawn_position *= max_distance_from_spawn_position
	
	charge_timer = randf() * charge_cooldown
	
	initialize_animation_frame()
	initialize_heading()
	initialize_audio_players()
	
#	yield(get_parent(),"ready")
#	yield(get_tree(),"idle_frame")
#	targeting.set_primary_target(Utils.game.core)

func initialize_animation_frame():
	if sprite is AnimatedSprite2D:
		sprite.frame = randi()%sprite.frames.get_frame_count(sprite.animation)
	else:
		sprite.frame = randi()%(sprite.hframes * sprite.vframes)

func initialize_heading():
	angle = randf() * TAU - PI
	heading = Vector2.RIGHT.rotated(angle)
	selected_direction = heading

func initialize_audio_players():
	audio_player = AudioStreamPlayer2D.new()
	audio_player.bus = "SFX"
	audio_player.attenuation = 2.0
	audio_player.max_distance = 500
	add_child(audio_player)
	audio_player.owner = self
	
	walking_audio = AudioStreamPlayer2D.new()
	walking_audio.bus = "SFX"
	walking_audio.attenuation = 2.0
	walking_audio.max_distance = 500
	walking_audio.stream = get_walking_sound()
	add_child(walking_audio)
	walking_audio.owner = self

### States
func state_global(delta: float):
	if is_dead:
#		enter_state = true
		call("state_die", delta)
		return
	else:
		targeting.pick_target( delta )

		if targeting.has_target:
			set_focused_tracking()
			if targeting.target_is_visible:
				destination = targeting.target.global_position
			elif is_front_ray_colliding_with_building:
				destination = front_ray_hit_position
		
		call(state, delta)
		
		destination_direction = global_position.direction_to(destination)
		destination_distance  = global_position.distance_to(destination)

		if is_walking and not is_navigation_dissabled:
			if targeting.target_is_visible:
				steering.current_navigation_mask=~(Utils.monster_attack_mask | 1<<Const.Materials.TAR)
			else:
				steering.current_navigation_mask=~(Utils.monster_attack_mask)
			update_navigation()
		if not is_rotation_dissabled:
			update_angle(delta)

		update_velocity(delta)
		update_is_walking()
		
		update_ray_material_collision()
		
		if is_walking or is_attacking:
			update_movement(delta)
			do_walk_audio()

		match_animation_to_speed()

### DEBUG much -----------------------------------------------------------------------------
#func set_state(s: String, data := {}):
#	if has_meta("debug_label"):
#		state_log.append(str(state, " ",randi()%100))
#		if state_log.size() > state_log_size:
#			state_log.pop_front()
#	.set_state(s, data)
#-------------------------------------------------------------------------------------------

func state_transition(delta: float):
	if timer >= state_data.time:
		set_state(state_data.next_state)

func state_idle(delta: float):
	if enter_state:
		set_desired_speed(0.0)
		if current_speed > 1.0:
			is_custom_animation_playing = false
		else:
			is_custom_animation_playing = true
			animator.play("idle")
			
		return_to_spawn_position_timer = 0.0
		
		if state_data.has("destination"):
			destination = state_data.destination
		else:
#			angle = sprite.rotation
#			heading = Vector2.RIGHT.rotated(angle)
			destination = global_position + heading*collision_radius
			
		if state_data.has("idle_time"):
			custom_idle_time = state_data.idle_time
		else:
			custom_idle_time = idle_time
	
	if timer > custom_idle_time:
		if targeting.has_target:
			if targeting.target_is_visible:
				set_state("state_transition", {time = randf_range(0.2, 0.5), next_state = "state_follow_target"})
	#			set_state("state_follow_target")
			else:
	#			if distance_from_spawn_position < waypoint_radius:
				if destination_distance < waypoint_radius:
					set_state("state_wait")
				else:
					set_state("state_follow_path")
		else:
			if targeting.has_primary_target:
				set_state("state_follow_path")
			else:
				set_state("state_wait")
	else:
		if current_speed <= 1.0:
			angle = sprite.rotation
			is_custom_animation_playing = true
			animator.play("idle")
			set_desired_speed(0.0)

func state_wait(delta: float):
	if enter_state:
		set_desired_speed(0.0)
		is_custom_animation_playing = true
		animator.play("idle")
		random_wait_time = 2.0 + randf()*10.0
#		angle = sprite.rotation
#		heading = Vector2.RIGHT.rotated(angle)
	destination = global_position + heading*collision_radius
		
	if targeting.has_target:
		if targeting.target_is_visible:
			set_state("state_follow_target")
	
	if timer > random_wait_time:
		if targeting.has_primary_target:
			set_state("state_follow_path")
		else:
			set_state("state_transition", {time = randf_range(0.2, 0.5), next_state = "state_look_around"})

func state_look_around(delta: float):
	if enter_state:
		set_desired_speed(walk_speed*0.5)
		is_custom_animation_playing = false
		destination = global_position + heading.rotated( randf_range(-PI,PI) ) * (waypoint_radius + randf_range(1, 10))

	if timer >= 1 or position.distance_to(destination) <= waypoint_radius:
		set_state("state_idle")

func state_rotate_to_target(delta: float):
	if enter_state:
		set_desired_speed(walk_speed*0.1)
		
		is_custom_animation_playing = false

	if targeting.has_target:
		if targeting.target_is_visible:
			if targeting.target_distance > attack_distance:
#				set_state("state_transition", {time = rand_range(0.2, 0.5), next_state = "state_follow_target"})
				set_state("state_follow_target")
			if targeting.is_looking_at_target(0.01):
				set_state("state_follow_target")
		else:
			set_state("state_follow_path")
	else:
		set_state("state_idle")
	is_attacking = false
	is_custom_animation_playing = false

func state_die(delta: float):
	if enter_state:
		is_custom_animation_playing = false
		set_process(false)
		set_physics_process(false)
		collider.queue_free()
		attack_shape.queue_free()
		walking_audio.stop()

		z_index = ZIndexer.Indexes.FLAKI
		if is_overkill():
			spawn_flaki()
		else:
			spawn_flaki()
			is_custom_animation_playing = true
			animator.play("death")
			await animator.animation_finished
			animator.play("die")
			await animator.animation_finished
		queue_free()

func state_follow_target(delta: float) -> void:
	if enter_state:
		set_desired_speed(walk_speed)
		Utils.game.start_battle()
#		do_audio_feedback()

	if is_front_ray_colliding_with_building:
		if process_availible_attack_on_building_in_front():
			return

	if targeting.has_target:
		if targeting.target_is_visible:
			if process_availible_target_attacks():
				return
			else:
				destination = get_projected_target_position()
		else:
			set_state("state_follow_path")
#			if targeting.has_primary_target:
#				set_state("state_follow_path")
#			else:
#				set_state("state_follow_path")

		if not targeting.target_is_building:
			if targeting.target.global_position.distance_squared_to(spawn_position) > max_distance_from_spawn_position:
				set_state("state_follow_path_to_spawn_position")
	else:
		set_state("state_idle")
		path_waypoint = global_position
	is_attacking = false
	is_custom_animation_playing = false

func state_follow_path_to_spawn_position(delta: float) -> void:
	if enter_state:
		set_desired_speed(walk_speed * 1.2)
		return_to_spawn_position_timer = 5.0
		destination = spawn_position
		pathing_destination = spawn_position
		find_path_to_destination(pathing_destination)

		if is_path_found:
			if pathing_method:
				path_waypoint = path[path_index]
			else:
				path_waypoint = path_data.get_virtual_point_on_closest_segment( global_position+heading*radius, radius*radius ) 
		else:
			set_state("state_idle")
			path_waypoint = global_position
			
	if return_to_spawn_position_timer > 0:
		return_to_spawn_position_timer -= delta
	else:
		if targeting.has_target:
			if targeting.target_is_visible:
				set_state("state_transition", {time = randf_range(0.2, 0.5), next_state = "state_follow_target"})
				path_waypoint = targeting.target.global_position
		else:
			set_state("state_idle")
			path_waypoint = global_position
	
	if pathing_method:
		process_pathing()
	else:
		process_pathing_alt()

	is_attacking = false
	is_custom_animation_playing = false

func state_follow_path(delta: float) -> void:
	if enter_state:
		if targeting.has_primary_target:
			pathing_destination = targeting.primary_target.global_position
		else:
			pathing_destination = targeting.target.global_position
		find_path_to_destination(pathing_destination)
		
		if is_path_found:
			is_custom_animation_playing = false
			set_desired_speed(walk_speed)
			if pathing_method:
				path_waypoint = path[path_index]
			else:
				path_waypoint = path_data.get_virtual_point_on_closest_segment( global_position+heading*radius, radius*radius ) 
		else:
			set_state("state_follow_path")
			path_waypoint = global_position

	if is_front_ray_colliding_with_building:
		if global_position.distance_to(front_ray_hit_position) <= attack_distance:
			process_availible_attack_on_building_in_front()

	if targeting.has_target:
		if targeting.target_is_visible:
			set_state("state_transition", {time = randf_range(0.2, 0.5), next_state = "state_follow_target"})
			path_waypoint = targeting.target.global_position
		else:
			pathing_destination = targeting.target.global_position
			if not targeting.target_is_building:
				if pathing_destination.distance_squared_to(spawn_position) > max_distance_from_spawn_position:
					set_state("state_follow_path_to_spawn_position")

	elif not targeting.has_primary_target:
		set_state("state_idle")
		path_waypoint = global_position
	
	if pathing_method:
		process_pathing()

	else:
		process_pathing_alt()
	
	is_attacking = false
	is_custom_animation_playing = false
		
func process_pathing_alt():
	if is_path_found:
		path_waypoint = path_data.get_virtual_point_on_closest_segment( global_position + heading*radius, radius ) 
#		if path_data.get_closest_segment_idx(global_position+heading*radius) == (path.size() - 2):
		if path_data.get_closest_segment_idx(global_position+heading*radius) == path_data.get_path_nr_of_segments()-1:
#			pathing_destination = targeting.target.global_position
			if global_position.distance_to(pathing_destination) <= waypoint_radius:
				set_state("state_idle")
			else:
				find_path_to_destination(pathing_destination)
				if is_path_found:
					path_waypoint = path_data.get_virtual_point_on_closest_segment( global_position+heading*radius, radius*radius )  
				else:
					set_state("state_idle")
	else:
		set_state("state_idle")
		path_waypoint = global_position
	destination = path_waypoint
	
func process_pathing():
	if global_position.distance_to(get_projected_waypoint()) <= waypoint_radius:
		has_path_culling_line_of_sight = true
		if path_index + 1 < path.size():
			path_index += 1
			path_waypoint = path[path_index]
		else:
			if path_waypoint.distance_to(pathing_destination) <= waypoint_radius:
				set_state("state_idle")
			else:
				find_path_to_destination(pathing_destination)
				if is_path_found:
					path_waypoint = path[path_index]
				else:
					set_state("state_idle")
					path_waypoint = global_position
					
	if is_path_found and has_path_culling_line_of_sight: 
		cull_path()
		path_waypoint = path[path_index]
	destination = get_projected_waypoint()

func state_go_to(delta: float):
	if enter_state:
		set_desired_speed(walk_speed)
		is_custom_animation_playing = false
		is_attacking = false
		
		if state_data.has("destination"):
			destination = state_data.destination
	
	if targeting.has_target:
		if targeting.target_is_visible:
			set_state("state_follow_target")
		else:
			if destination_distance < waypoint_radius:
				set_state("state_idle")
			else:
				set_state("state_follow_path")
	elif targeting.has_primary_target:
		set_state("state_follow_path")
	else:
		if timer > 5:
			set_state("state_idle")

func state_attack(delta: float):
	if enter_state:
		set_desired_speed(0.0)
		current_speed *= 0.5
		
		is_attacking = true
		is_custom_animation_playing = true
		animator.play("attack")
		
		await animator.animation_finished
		set_state("state_follow_target")
		return

	if not attack_shape.disabled:
		Utils.explode_circle((attack_shape.global_position + global_position) * 0.5, radius*2, 20, 4,10)


func process_availible_attack_on_building_in_front()-> bool:
#	var collided_node = Utils.game.map.player_tracker.getClosestTrackingNode2DInCircle( destination, 1 true)
	destination = front_ray_hit_position
	if global_position.distance_to(destination) < attack_distance:
		set_state("state_attack")
		return true
	return false
	
func process_availible_target_attacks()-> bool:
	if targeting.is_looking_at_target(0.1):
		if targeting.target_distance < attack_distance:
			set_state("state_attack")
			return true
	return false

### Helper methods
func launch_attack(target: Node2D) -> void:
	targeting.set_primary_target(target)
#	set_state("state_follow_path")
	
func update_navigation() -> void:
	steering.navigate(false)
	selected_direction = steering.get_desired_heading()
#	selected_direction = steering.get_force_corrected_desired_heading()
	
func update_angle(delta: float = 0.016) -> void:
#	selected_direction = get_global_mouse_position() - global_position
	angular_velocity = angle
	if is_attacking:
		angle = lerp_angle(angle, destination_direction.angle(), 0.05)
	else:
		angle = lerp_angle(angle, selected_direction.angle(), rotation_reaction_speed)
		
	angular_velocity = abs(angular_velocity - angle)
	
	heading = Vector2.RIGHT.rotated(angle)
	
func update_velocity(delta: float = 0.016) -> void:
	if charge_timer > 0:
		charge_timer -= delta
	else:
		if charge_duration_timer > 0:
			charge_duration_timer -= delta
			charge_speed_multiplier = charge_speed_multiplier_max
		else:
			charge_duration_timer = charge_duration
			charge_timer = charge_cooldown
			charge_speed_multiplier = 1.0
	
	if destination_distance < collision_radius * 0.5:
#		current_speed = 0.0
		if current_speed < 1.0:
			current_speed = 0.0
		else:
			current_speed = lerp(current_speed, 0.0, 0.5)
	else:
		if destination_distance < collision_radius:
			current_speed = lerp(current_speed, desired_speed * terrain_speed_multiplier * charge_speed_multiplier * ((destination_distance - collision_radius) / collision_radius), 0.15)
		else:
			current_speed = lerp(current_speed, desired_speed * terrain_speed_multiplier * charge_speed_multiplier * ( abs(heading.dot(selected_direction)) ), 0.15)

#			current_speed = lerp(current_speed, desired_speed * ( 1.0 - abs(heading.angle_to(selected_direction)) ) , 0.15)
	
	velocity = heading * current_speed
#	velocity += steering.avoid_others_direction
	delta_v = velocity * delta
	
func update_ray_material_collision():
	is_front_ray_colliding = false
	is_front_ray_colliding_with_building = false
	front_ray = pixelmap.rayCastQTDistance(global_position, heading, avoid_range, Utils.walkable_collision_mask)
	if front_ray: 
		is_front_ray_colliding = true
		var material_hit = Utils.get_pixel_material(Utils.game.map.pixel_map.get_pixel_at(front_ray.hit_position-front_ray.hit_normal*0.5))
		if is_path_through_terrain:
			if Utils.monster_attack_mask & (1<<material_hit):
#			if material_hit == Const.Materials.WALL or material_hit == Const.Materials.STOP or material_hit == Const.Materials.GATE:
				is_front_ray_colliding_with_building = true
				front_ray_hit_position = front_ray.hit_position
		else:
			if Utils.monster_base_attack_mask & (1<<material_hit):
				is_front_ray_colliding_with_building = true
				front_ray_hit_position = front_ray.hit_position

func update_movement(delta: float = 0.016) -> void:
	previous_position = global_position
	if not is_front_ray_colliding: 
		# no collision in front
		var response := physics.custom_physics_step(global_position, delta_v, collision_radius, 1.0, Utils.walkable_collision_mask)
		global_position = response.position
		global_position += response.size
	else:
		# collision in front
		if is_front_ray_colliding_with_building:
			# collision with building in front
			var response := physics.custom_physics_step(global_position, delta_v, collision_radius, 1.0, Utils.walkable_collision_mask)
			global_position = response.position
			global_position += response.size
		else:
			# possible collision in front
#			var collision_normal = physics.get_collision_normal(front_ray.hit_position, collision_radius, Utils.walkable_collision_mask)
			var collision_normal = physics.get_collision_normal(front_ray.hit_position, 2, Utils.walkable_collision_mask)
			if collision_normal:
				if collision_normal.normal_valid:
					var response := physics.custom_physics_step(global_position, delta_v.slide(collision_normal.normal), avoid_range, 1.0, Utils.walkable_collision_mask)
					if front_ray.hit_distance <= collision_radius:
						response = physics.custom_physics_step(global_position, delta_v, collision_radius, 1.0,Utils.walkable_collision_mask)
						global_position = response.position
						global_position += response.size
					else:
						var foreward = delta_v * (front_ray.hit_distance) / avoid_range
						var repulsion = -delta_v.reflect(collision_normal.normal) * (avoid_range-front_ray.hit_distance) / collision_repulsion_radius
#						global_position = response.position
						global_position += foreward + repulsion
						
				elif collision_normal.is_stuck:
	#				assert(false, "Help me cousin, im stuck.") 
					Utils.explode_circle(global_position, collision_radius + 3, 255, 255, 10)
#					print("Help me cousin, im stuck.")
#					call_deferred("_killed")
				else:
					var response := physics.custom_physics_step(global_position, delta_v, collision_radius, 1.0,Utils.walkable_collision_mask)
					global_position = response.position
#					global_position += delta_v # why dis was here?
					global_position += response.size
			else:
				var response := physics.custom_physics_step(global_position, delta_v, collision_radius, 1.0,Utils.walkable_collision_mask)
				global_position = response.position
				global_position += response.size
	
	if current_speed > 0:
		speed_for_animation_playback = (previous_position - global_position).project(heading).length() / delta
	else:
		speed_for_animation_playback = 0.0
#		spped_for_animation_playback = global_position.distance_to(previous_position) /delta

	stuck_fixer(delta)

func update_is_walking()->void:
	is_walking = true
	if is_attacking or is_custom_animation_playing:
		is_walking = false
	else:
		if current_speed < 1.0:
			is_walking = false

	if is_walking:
		animator.play("walk",-1,1.0/scale.x)
		
func stuck_fixer(delta: float):
	if is_walking:
		stuck_ticks_limit_distance = current_speed * delta * stuck_ticks_limit_frames * 0.9
#		if global_position.distance_to(stuck_previous_position) < 13:
		if global_position.distance_to(stuck_previous_position) < stuck_ticks_limit_distance:
			stuck_ticks += 1
		else:
			stuck_ticks = 0
		
		if stuck_ticks > stuck_ticks_limit_frames:
			if not Utils.game.map.pixel_map.isCircleEmpty(global_position, collision_radius + 2):
				Utils.explode_circle(global_position, collision_radius + 3, 255, 255, 10)
			stuck_ticks = 0
			
		elif stuck_ticks == 0:
			stuck_previous_position = global_position
		
func match_animation_to_speed():
	if is_walking:
		animator.playback_speed = base_playback_speed * (speed_for_animation_playback / animation_travel_distance + angular_velocity * 10.0)
	else:
		animator.playback_speed = base_playback_speed

#func get_new_destination_in_range_front(max_range: float):
#	return global_position + heading.rotated( rand_range(-0.5,0.5)) * rand_range(10, max_range)
#
#func get_new_destination_in_range(max_range: float):
#	return global_position + heading.rotated(steering.heading_map[randi() % steering.heading_map_size]) * rand_range(10, max_range)


func find_path_to_destination(target_destination: Vector2):
	is_path_found = false
	if targeting.target_is_building:
		path_data = PathFinding.get_path_any_from_to_position(global_position, target_destination, get_optimal_pf_lvl_resolution(), true)
	else:
		path_data = PathFinding.get_path_any_from_to_position(global_position, target_destination, get_optimal_pf_lvl_resolution(), false)
	if path_data:
		is_path_through_terrain = path_data.path_goes_through_materials
		is_path_found = true
		path = path_data.get_path()
		path_index = 0


func get_optimal_pf_lvl_resolution():
	return min(Utils.game.map.pixel_map.getOptimalPFLvlResolution(radius)+1, 11)

func get_pathfinding_params():
	return [Utils.monster_path_mask, PathFinding.material_cost, get_optimal_pf_lvl_resolution() ]


func cull_path():
	if path_index + 1 < path.size():
		var col := pixelmap.rayCastQTFromTo(global_position, path[path_index+1], Utils.walkable_collision_mask)
		if col:
			has_path_culling_line_of_sight = false
		else:
			path_index += 1
	else:
		has_path_culling_line_of_sight = false

func get_projected_target_position() -> Vector2:

	if targeting.target_direction.dot(heading) > 0.2:
		var target_projected_position = global_position + targeting.target_vector.project(heading)
		var projected_distance = (target_projected_position - targeting.target.global_position).length()
		var projected_direction = targeting.target.global_position.direction_to(target_projected_position)
		return targeting.target.global_position + projected_direction * clamp(targeting.target_distance / attack_distance - 1.0, 0.0, 2.0 ) * attack_distance
	#	return targeting.target.global_position + projected_direction * lerp(attack_distance, projected_distance, clamp(targeting.target_distance / attack_distance, -1.0, 5.0  ) )
	else:
		return targeting.target.global_position

func get_projected_waypoint() -> Vector2:
	var path_direction = path_waypoint - global_position
	var path_projection = global_position + path_direction.project(heading)
	if (path_projection - path_waypoint).length() < waypoint_radius:
		return path_projection
	else:
		return path_waypoint
		
func get_waypoint_radius(p_velocity: Vector2) -> float:
	return clamp(waypoint_radius * p_velocity.length() / (current_speed * 0.5), 10, waypoint_radius)

func get_next_waypoint() -> Vector2:
	var next_waypoint: Vector2 = path[path_index]
	while global_position.distance_to(next_waypoint) < get_waypoint_radius(velocity):
		path_index += 1
		if path_index == path.size():
			path.clear()
			return next_waypoint
		else:
			next_waypoint = path[path_index]
	next_waypoint = cull_path()
	
	return next_waypoint

func get_walking_sound() -> AudioStream:
#	return preload("res://SFX/Enemies/Bugs running around 5.wav")
	return null

func do_audio_feedback(): 
	# sfx on notice player
	pass

func do_walk_audio():
	if not walking_audio.playing:
		if is_walking:
			walking_audio.play()
		else:
			walking_audio.stop()

	
func set_desired_speed(speed)->void:
	desired_speed = speed

func set_primary_target( new_target:Node2D )->void:
	targeting.set_primary_target(new_target)
	

func set_target( new_target:Node2D )->void:
	targeting.set_target(new_target)

func go_to_destination(new_destination:Vector2):
	set_state("state_go_to",{destination = new_destination})
	
func go_to_node(new_target:Node2D, focus_time:float = targeting.target_focus_timeout):
	set_target(new_target)
	targeting.target_focus_timer = focus_time
	set_state("state_follow_path")
	
func on_hit(data: Dictionary) -> void:
	super.on_hit(data)

	damaged = true
	if state in [ "state_idle", "state_look_around", "state_wait", "state_follow_path" ]:
		if data.has("owner"):
			if data.owner.get("player"):
				go_to_node(data.owner.player)
			else:
				var player = targeting.get_closest_player()
				if is_instance_valid(player):
					if global_position.distance_to(player.global_position) < 200:
						go_to_node(player)
				else:
					if data.has("velocity"):
						var new_destination = global_position - data.velocity.normalized() * 100
						go_to_destination(new_destination)
		else:
			go_to_node(Utils.game.core)

func on_dead():
	set_state("state_die")

#func _on_animation_finished(anim_name):
#	is_attacking = false

### DEBUG

func _debug_get_text():
	if not has_meta("debug_label"):
		_debug_enable()
	return get_meta("debug_label").text

func _debug_enable():
	if not has_meta("debug_label"):
		var debug_label = Label.new()
		debug_label.position = Vector2(-33, -14)
		debug_label.size  = Vector2(132, 14)
		debug_label.scale = Vector2(0.2, 0.2)
		debug_label.align  = Label.ALIGNMENT_CENTER
		debug_label.valign = Label.VALIGN_CENTER
		add_child(debug_label)
		set_meta("debug_label", debug_label)
	get_meta("debug_label").show() 

func _debug_disable():
	get_meta("debug_label").hide()

func _debug_process():
	if not has_meta("debug_label"):
		_debug_enable()
		_debug_disable()
	var debug_log: Label = get_meta("debug_label")
	
	debug_log.text = state
	if state_data.has("next_state"):
		debug_log.text += " next:  "+state_data.next_state
		
	debug_log.text += "\nFlags:" + (" is_walking" if is_walking else "") + (" is_attacking" if is_attacking else "") + (" is_custom_anim" if is_custom_animation_playing else "") + (" is_path_found" if is_path_found else "") + (" is_building_front" if is_front_ray_colliding_with_building else "")
	
	debug_log.text += "\nAnimation: "+animator.current_animation

	targeting.validate_target()
	if targeting.has_target:
		debug_log.text += "\nTargeting: " +targeting.target.name
		if targeting.target_is_visible:
			debug_log.text += "(visible)"
	debug_log.text += "\nPick target: "+str(round(targeting.target_persistance_timer*10)/10.0)+" Focus: "+str( round(targeting.target_focus_timer) )

	targeting.validate_primary_target()
	if targeting.has_primary_target:
		debug_log.text += "\nPrimary target: "+targeting.primary_target.name
		

#	debug_log.text += "Destination: " +str(destination.round())+" ("+str(round(global_position.distance_to(destination)*10) * 0.1)+")\n"
	debug_log.text += str("\nVelocity: ", velocity.round(), " ("+str(round(current_speed*10) * 0.1)+"/"+str(round(desired_speed))+")")

	if is_path_found:
		debug_log.text += "\nis_path_found ("+str(path_index,"/",path.size()) +")" 
		if is_path_through_terrain:
			debug_log.text += " through_terrain"

### DEBUG much -----------------------------------------------------------------------------
#	debug_log.text += "\nState hsitory:\n"
#	for i in state_log.size():
#		debug_log.text += state_log[i] +"\n"
#-------------------------------------------------------------------------------------------
func draw_fov():
	draw_arc(Vector2.ZERO, steering.sight_range*0.5, angle + deg_to_rad(steering.sight_fov)*0.5 ,angle - deg_to_rad(steering.sight_fov)*0.5, 16, Color(1,1,1,0.05), steering.sight_range)
	draw_arc(Vector2.ZERO, steering.sight_range, angle + deg_to_rad(steering.sight_fov)*0.5 ,angle - deg_to_rad(steering.sight_fov)*0.5, 16, Color(1,1,1,0.1), 1.2)
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(angle - deg_to_rad(steering.sight_fov)*0.5)*steering.sight_range, Color(1,0,0,0.6),1 )
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(angle + deg_to_rad(steering.sight_fov)*0.5)*steering.sight_range, Color(1,0,0,0.6),1 )

func draw_destination():
	draw_line(Vector2.ZERO, destination - global_position, Color(1,0,0,0.5), 1.0)
	draw_circle(destination - global_position, 3.5, Color(1,0,0,0.5))

func draw_target():
	if targeting.target_is_visible:
		draw_line(Vector2.ZERO, targeting.target_vector - targeting.target_direction*targeting.target.radius, Color(0,1,0,0.3),1.5)
		draw_circle(targeting.target_vector - targeting.target_direction*targeting.target.radius, 2, Color(0,1,0,0.3))

func draw_context():
	for i in steering.heading_map_resolution:
		var l_direction = heading.rotated(steering.heading_angle_map[i])
		draw_line(l_direction * radius, l_direction * radius + l_direction * steering.danger_map[i] * avoid_range * steering.ray_map[i]*3, Color.from_hsv( 0.2 - ( ( 1 - steering.danger_map[i] ) * 0.2 ) ,1 ,1, 0.7 ), 1.4 )
		if steering.danger_map[i] <= 0:
			draw_line(l_direction * radius, l_direction * radius + l_direction * steering.interest_map[i] * 10 , Color(0.0 ,1.0 ,1.0, 0.4 ), 1.3 )

func draw_pathing():
	if is_path_found: 
		var color = Color(1,1,1)
		if pathing_method:
			color = Color(0,1,1)
		draw_rect( Rect2(path_waypoint - global_position, Vector2.ONE), Color.CYAN )
		if path.size() == 0:
			return
#		draw_line( Vector2.ZERO, path_waypoint - global_position , Color(1,1,1,0.7), 2 )
		for i in range( path.size() - 1 ):
			draw_rect( Rect2(path[i] - global_position, Vector2.ONE), color - Color(0,0,0,float(i)/(path.size()+1)) )
			draw_line( path[i] - global_position ,  path[i+1] - global_position , color - Color(0,0,0,float(i)/(path.size()+1)), 1.0 )
		draw_line( Vector2.ZERO , path[ path_index ] - global_position, Color(0,1,0,0.5), 1.0 )
		draw_rect( Rect2(path[ path_index ] - global_position, Vector2.ONE), Color(0,1,0,0.5) )

func draw_collision_radius():
	draw_circle(Vector2.ZERO, collision_radius, Color(0.0,0.0,1.0,0.3) )
	draw_circle(Vector2.ZERO, radius, Color(1.0,1.0,0.0,0.3) )
	
func _debug_draw():
	draw_line(Vector2.ZERO, (radius+5) * Vector2.RIGHT.rotated(angle), Color(1.0,1.0,1.0,1.0), 0.5 )
	draw_line(Vector2.ZERO, (radius+5) * global_position.direction_to(destination), Color(1.0,1.0,1.0,1.0), 0.5 )
	draw_circle(Vector2.ZERO, waypoint_radius, Color(0.0,0.0,1.0,0.3) )
	
#	draw_line(selected_direction * radius, selected_direction * (30+radius) , Color(1,1,1,0.5), 2)
	
#	draw_fov()

#	draw_line(Vector2.ZERO, steering.avoid_others_direction * avoid_range, Color.orange, 1)

#	draw_target()
	
	draw_destination()
	
	draw_context()

	draw_pathing()
	
#	if state == "state_idle":
#		if is_instance_valid(targeting.target) and targeting.target.is_inside_tree():
#			draw_circle(targeting.target.global_position - global_position, 2, Color.green )

#func draw_repulsion():
#	if col:
#		draw_circle(col.hit_position - global_position, 3, Color.white)
#		draw_line(Vector2.ZERO, col.hit_position - global_position, Color.green, 1)
#		if col_normal:
#			draw_line(col.hit_position - global_position, col.hit_position - global_position + col_normal.normal * 20, Color.yellow, 1)
#		draw_line(col.hit_position - global_position, col.hit_position - global_position + repulsion  * 100 , Color.green, 1)
#		draw_line(Vector2.ZERO, (foreward + repulsion) *100 , Color.cyan, 1)
#		draw_line(Vector2.ZERO, foreward  * 10 , Color.blue, 1)
#	pass


