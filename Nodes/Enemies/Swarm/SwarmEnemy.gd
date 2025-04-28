extends BaseEnemy
class_name SwarmEnemy

# handles
@onready var attack_shape := $Sprite2D/AttackBox/AttackShape as CollisionShape2D
@onready var sprite := get_node_or_null("Sprite2D")
@onready var animator: AnimationPlayer = get_node_or_null("AnimationPlayer")

# perception variables 
@export var walk_speed       := 32.0
@export var arrival_distance := 1.0
@export var bite_attack_distance := 4.0
@export var long_attack_distance := 8.0
@export var sight_range := 50.0
@export var animation_travel_distance := 20 # distance traveled by sprite using current sprite sheet and current scale
@export var path_resolution := 11 # 13 - 1x1px, 12 - 2x2px, 11 - 4x4px, 10 - 8x8, 9 - 16x16, 8 - 32x32,  etc. 
@export var wall_repulsion_radius := 10.0
@export var collision_radius := 5.0
@export var waypoint_radius := 6.0
@export var slow_down_radius := 10.0
@export var is_ignoring_buildings := false

var search_leader_distance = 8.0

var swarm_id := 1
var coll_repulsion_radius := 0.0

# targeting data
#var is_agro := false
var is_target_visible := false
var has_target   := false
var is_attacking := false
var can_attack_structure := false

var is_building_in_front := false
var is_wall_in_front := false
var is_terrain_in_front := false
var terrain_in_front_destination := Vector2.ZERO
var has_path_culling_line_of_sight := false

var leader  : Node2D
var primary_target   : Node2D
var attack_target    : Node2D
var target           : Node2D
var destination      := Vector2.ZERO
var target_direction := Vector2.ZERO
var target_vector    := Vector2.ZERO
var target_distance  := 0.0
var ignore_all_targets: bool

# stering variables
var previous_position := Vector2.ZERO
var timer:= 0.0
var avoid_others_direction := Vector2.ZERO
var angle := 0.0
var heading := Vector2.RIGHT
var selected_direction: Vector2
var current_speed := 0.0
var max_force := 1.0
var velocity: Vector2
var delta_v: Vector2
var stuck_ticks := 0
var stuck_ticks_limit := 100

var audio_player: AudioStreamPlayer2D
var walking_audio: AudioStreamPlayer2D

var is_path_found: bool
var is_path_through_terrain: bool
var path: Array
var path_index: int
var path_waypoint: Vector2

var foreward: Vector2
var repulsion: Vector2
var col:RayCastResultData
var col_normal: PixelMapNormalData

var tick_timer_20 := 0
var tick_timer_60 := 0
var can_attack := false


enum STATE { IDLE, ATTACK_WALL, IS_LEADER, FOLLOWING_LEADER, FOLLOWING_PATH }
var state_name = [ "IDLE", "ATTACK_WALL", "IS_LEADER", "FOLLOWING_LEADER", "PATHING" ]
var current_state = STATE.FOLLOWING_PATH

func _ready() -> void:
	var pider = preload("res://Nodes/Enemies/Pider/Pider.tscn").instantiate()
	pider.position = position
	pider.override_stats.hp = enemy_data.hp
	pider.override_stats.damage = enemy_data.damage
	get_parent().call_deferred("add_child", pider)
	queue_free()
	
	override_custom_stat("speed", self, "walk_speed")
	override_custom_stat("sight_range", self, "sight_range")
	
	coll_repulsion_radius = wall_repulsion_radius - collision_radius
	Utils.init_enemy_projectile($Sprite2D/AttackBox, $Sprite2D/AttackBox, {damage = damage, keep = true})
	pixelmap = Utils.game.map.pixel_map as PixelMap
	physics  = Utils.game.map.physics as PixelMapPhysics
	randomize_initial_animation_frame()
	randomize_initial_heading()
#	initialize_audio_players()
	animator.play("walk")
#	animator.playback_speed = 30

	destination = global_position
	previous_position = global_position

func set_primary_target(new_target:Node2D):
	primary_target = new_target

func randomize_initial_animation_frame():
	if sprite is AnimatedSprite2D:
		sprite.frame = randi()%sprite.frames.get_frame_count(sprite.animation)
	else:
		animator.seek(0.0)
		animator.advance(randf_range(0, animator.current_animation_length))

func initialize_heading(new_angle:float):
	angle = new_angle
	heading = Vector2.RIGHT.rotated(angle)
	selected_direction = heading

func randomize_initial_heading():
	initialize_heading(randf() * TAU - PI)

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


func make_leader():
	current_state = STATE.IS_LEADER
	avoid_others_direction = Vector2.ZERO

func _physics_process(delta: float):

	if has_path_culling_line_of_sight:
		cull_path()
		path_waypoint = path[path_index]
		path_waypoint = get_projected_waypoint()

	tick_timer_20 += 1
	if (tick_timer_20 >= 20):
		tick_timer_20 = 0

	tick_timer_60 += 1
	if (tick_timer_60 >= 60):
		tick_timer_60 = 0

	match current_state:
		STATE.IDLE:
#			sprite.modulate = Color.black

			if tick_timer_60 == 0:
				stuck_ticks = 0
				update_terrain_in_front()
				if is_building_in_front :
					destination = terrain_in_front_destination
					current_state = STATE.ATTACK_WALL
					return
				
				get_new_target()
				if validate_target():
					pick_leader()

				return
			if is_attacking:
				return
			if animator.current_animation == "walk":
#				destination = global_position + heading * rand_range(5, 15)
#				destination = global_position
				update_target_data(destination)
				selected_direction = target_direction
				walk()
				if current_speed == 0:
					
#					prints("pre", animator.current_animation_length)
					animator.play("idle")
#					prints("post", animator.current_animation_length)
#					randomize_initial_animation_frame()
			else:
				if not animator.current_animation == "idle":
#					prints("pre", sprite.texture)
					animator.play("idle")
#					prints("post", sprite.texture)
#					randomize_initial_animation_frame()
				return
				
		STATE.ATTACK_WALL:
#			sprite.modulate = Color.yellow
			if tick_timer_60 == 0:
				can_attack = true
				update_terrain_in_front()

			if is_terrain_in_front :
				destination = terrain_in_front_destination
				update_target_data(destination)
				selected_direction = target_direction
				if not is_attacking:
					if target_distance < long_attack_distance and can_attack:
						if target_distance < bite_attack_distance:
							animator.play("bite")
						else:
							animator.play("claw")
						is_attacking = true
						can_attack = false
					else:
						walk()
			else:
				current_state = STATE.IS_LEADER
				pick_leader()
				return
				
			update_movement(delta)
			sprite.rotation = angle
			
			
		STATE.IS_LEADER:
#			sprite.modulate = Color.green
			if tick_timer_60 == 0:
				can_attack = true
				update_terrain_in_front()
				if is_building_in_front:
					destination = terrain_in_front_destination
					current_state = STATE.ATTACK_WALL
					return
				else:
					pick_leader()
#			if tick_timer_20 == 0:
			avoid_others_direction = Utils.game.map.enemy_tracker.getAwayVectorFromOtherTrackingNodes(self, radius * 2.0)
				
			if not validate_target():
				get_new_target()
				if not validate_target(): #no target - should not happen if not game over
					current_state = STATE.IDLE
					avoid_others_direction = Vector2.ZERO
					return
			else:
				if not is_path_found:
					get_path()
			is_target_visible = is_position_visible(target.global_position, sight_range)
			
			if is_target_visible:
				destination = target.global_position
				update_target_data(target.global_position)
				selected_direction = target_direction
				if not target is BaseBuilding:
					target_distance = max(0,target_distance-target.radius - 2)
					Utils.game.start_battle()

				if not is_attacking:
					if target_distance < long_attack_distance and can_attack:
						if target_distance < bite_attack_distance:
							animator.play("bite")
						else:
							animator.play("claw")
							current_speed *= 3.0
						can_attack   = false
						is_attacking = true
					else:
						walk()
#				sprite.modulate = Color.green * 4
				update_movement(delta)
				
				sprite.rotation = angle
				return
			else:
				var player = get_closest_player()
				if is_instance_valid(player) and player.is_inside_tree():
					if is_node_visible_in_range(player, sight_range) and not player.dead:
						set_target(player)
						return
				update_target_data(destination)
				current_state = STATE.FOLLOWING_PATH
#
#				if is_position_visible(destination, sight_range):
#					selected_direction = target_direction
#					if global_position.distance_to(destination) < waypoint_radius:
#						if path_index + 1 < path.size():
#							path_index += 1
#							path_waypoint = path[path_index]
#							path_waypoint = get_projected_waypoint()
#						else:
#							get_path()
#							current_state = STATE.FOLLOWING_PATH
#						destination = path_waypoint
#				else:
#					get_path()
#					current_state = STATE.FOLLOWING_PATH
				walk()

		STATE.FOLLOWING_PATH:
#			sprite.modulate = Color.aqua
#			if not (Utils.game.frame_from_start+my_tick_20) % 20:
#				avoid_others_direction = Utils.game.map.enemy_tracker.getAwayVectorFromOtherTrackingNodes(self, radius * 2.0)
#
			if tick_timer_60 == 0:
				update_terrain_in_front()
				if is_terrain_in_front:
					if is_path_through_terrain:
						destination = terrain_in_front_destination
						current_state = STATE.ATTACK_WALL
					if is_building_in_front:
						destination = terrain_in_front_destination
						current_state = STATE.ATTACK_WALL
					pass
				else:
					pick_leader()
			
			if not validate_target():
				get_new_target()
				if not validate_target():
#					print ("no target - should not happen")
					#call_deferred("_killed")
					current_state = STATE.IDLE
					avoid_others_direction = Vector2.ZERO
					return
			is_target_visible = is_position_visible(target.global_position, sight_range)
			if is_target_visible:
				make_leader()
				destination = global_position
				#return
			if is_path_found:
				if global_position.distance_to(path_waypoint) < waypoint_radius:
					if path_index + 1 < path.size():
						path_index += 1
						path_waypoint = path[path_index]
						path_waypoint = get_projected_waypoint()
					else:
						get_path()
						# return
				destination = path_waypoint
				selected_direction = global_position.direction_to(path_waypoint)
				target_distance = global_position.distance_to(path_waypoint)
			else:
				current_state = STATE.IDLE
				avoid_others_direction = Vector2.ZERO
				target_distance = 1.0
				#return
#			target_distance = global_position.distance_to(path_waypoint)

			walk()

		STATE.FOLLOWING_LEADER:
#			sprite.modulate = Color.red
			if tick_timer_60 == 0:
				update_terrain_in_front()
				if is_building_in_front :
					destination = terrain_in_front_destination
					current_state = STATE.ATTACK_WALL
					return
				else:
					pick_leader()
				
			if not is_instance_valid(leader) or not leader.is_inside_tree():
				pick_leader()
				destination = global_position
				return

#			if tick_timer_20 == 0:
			
			avoid_others_direction = Utils.game.map.enemy_tracker.getAwayVectorFromOtherTrackingNodes(self, radius * 2.0)

			if target_distance > radius * search_leader_distance:
				pick_leader()
			else:
#				var dir_to_leader = (leader.global_position - global_position).normalized()
#				var dot = heading.dot(dir_to_leader)
				var dot = heading.dot(leader.heading)

				if dot >= 0.1:
	#				if not leader.is_path_found:
	#					make_leader()
	#					destination = heading * global_position.distance_to(leader.global_position)
	#				else:
					selected_direction = selected_direction.rotated( (dot - 0.3) * 0.015 * -sign( heading.cross(leader.heading) ))
#					selected_direction = selected_direction.rotated( (dot - 0.3) * 0.015 * -sign( heading.cross(dir_to_leader) ))

					### queuing support
					target_distance = max((leader.global_position - global_position).length() - radius, 0)

				else:
					pick_leader()
					destination = heading * global_position.distance_to(leader.global_position)
			walk()
		_:
			pass

	update_movement(delta)
	sprite.rotation = angle

func attack():
	if not is_attacking:
		if can_attack:
			if  target_distance < long_attack_distance:
				if target_distance < bite_attack_distance:
					animator.play("bite")
				else:
					animator.play("claw")
				is_attacking = true
				can_attack   = false
				return
			else:
				walk()
		walk()

func attack_wall():
	stuck_ticks = 0
	Utils.explode_circle(attack_shape.global_position, 8, 20, 3, 9)

func attack_finished():
	is_attacking = false

func play_attack_sound():
	Utils.get_audio_manager("swarm_attack").play(self)

func update_movement(delta: float = 0.016) -> void:
	var heading_dot := 0.0
	if not is_attacking:
		var angle_local = selected_direction.angle()
#		if selected_direction.dot(-avoid_others_direction):
		selected_direction = (selected_direction+avoid_others_direction).normalized()
		heading_dot	= abs(heading.dot(selected_direction))
		angle_local = lerp(angle_local, (selected_direction).angle(), 1.0-heading_dot )
		angle = lerp_angle(angle, angle_local, 0.1)
	else:
		angle = lerp_angle(angle, selected_direction.angle(), 0.02)
#		stalking AI avoid_others_direction set to radius *4
#		var angle_local = selected_direction.angle()
#		if selected_direction.dot(-avoid_others_direction):
#			selected_direction = (selected_direction+avoid_others_direction).normalized()
#		angle_local = lerp(angle_local, (selected_direction).angle(), 0.5)
#		angle = lerp_angle(angle, angle_local, 0.1)

	
	heading = Vector2.RIGHT.rotated(angle)
	if target_distance <= arrival_distance:
		current_speed = lerp(current_speed, 0.0, 0.25)
	else:
		if target_distance - arrival_distance <= slow_down_radius:
			current_speed = lerp(current_speed, walk_speed * ((target_distance - arrival_distance) / slow_down_radius), 0.15)
		else:
			current_speed = lerp(current_speed, walk_speed * heading_dot , 0.15)
				
	velocity = heading * current_speed
#	velocity += avoid_others_direction
	delta_v = velocity * delta
	
	if can_attack_structure:
		var response := physics.custom_physics_step(global_position, delta_v, collision_radius, 1.0, Utils.walkable_collision_mask)
		global_position = response.position
		global_position += response.size
		stuck_fixer()
		return

	col = pixelmap.rayCastQTDistance(global_position, heading, wall_repulsion_radius, Utils.walkable_collision_mask)
	if col :
		col_normal = physics.get_collision_normal(col.hit_position, collision_radius)
		if col_normal:
			if col_normal.normal_valid:
				if col.hit_distance <= collision_radius:
					var response = physics.custom_physics_step(global_position, delta_v, collision_radius, 1.0, Utils.walkable_collision_mask)
					global_position = response.position
					global_position += response.size
				else:
					foreward = delta_v * (col.hit_distance) / wall_repulsion_radius
					repulsion = -delta_v.reflect(col_normal.normal) * (wall_repulsion_radius-col.hit_distance) / coll_repulsion_radius
					current_speed = current_speed * (wall_repulsion_radius-col.hit_distance) / wall_repulsion_radius
					global_position += foreward + repulsion
			elif col_normal.is_stuck:
				print("Help. Im stuck.")
				call_deferred("_killed")
			else:
				var response := physics.custom_physics_step(global_position, delta_v, collision_radius, 1.0,Utils.walkable_collision_mask)
				global_position = response.position
				global_position += response.size
		else:
			var response := physics.custom_physics_step(global_position, delta_v, collision_radius, 1.0,Utils.walkable_collision_mask)
			global_position = response.position
			global_position += response.size
	else:
		var response := physics.custom_physics_step(global_position, delta_v, collision_radius, 1.0,Utils.walkable_collision_mask)
		global_position = response.position
		global_position += response.size
	
	
	stuck_fixer()

func stuck_fixer():
	if global_position.distance_to(previous_position) < 13:
		stuck_ticks += 1
	else:
		stuck_ticks = 0
	
	if stuck_ticks > stuck_ticks_limit:
		Utils.explode_circle(position, radius*2, 255, 255, 10)
		stuck_ticks = 0
		
	elif stuck_ticks == 0:
		previous_position = global_position

func walk():
	if not is_attacking:
		animator.play("walk")
		animator.playback_speed = 30 * current_speed / animation_travel_distance

func pick_leader():
	make_leader()
	var enemy_nodes_in_range = Utils.game.map.enemy_tracker.getTrackingNodes2DInCircle( global_position + heading * radius*3.025, radius*1.5, true )
	var min_angle = INF
	var min_dist = INF
	var max_dist = pow(radius*8, 2)
	var potential_leader:Node2D
	for node in enemy_nodes_in_range:
		if node.get("swarm_id"):
			if node.swarm_id == swarm_id:
				var dist = (node.global_position - global_position).length_squared() ## tu czasami error
				if dist < min_dist:
					min_dist = dist
					potential_leader = node

	if min_dist < max_dist:
		if heading.dot(potential_leader.heading) > 0.1:
#			if is_position_visible(potential_leader.global_position, min_dist):
				leader = potential_leader
				current_state = STATE.FOLLOWING_LEADER
#				avoid_others_direction = Vector2.ZERO
				return

func get_path():
	is_path_found = false
	var path_data:PathfindingResultData

#	if target is BaseBuilding:
#		path_data = PathFinding.get_path_no_dig_from_to_position(global_position, target.global_position,path_resolution, PathFinding.PATH_MODE.FULL_PATH_OR_CLOSEST_POINT)
#	else:

	path_data = PathFinding.get_path_no_dig_from_to_position(global_position, target.global_position, path_resolution, true)
#	path_data = null
	if path_data:
		is_path_through_terrain = path_data.path_goes_through_materials
		is_path_found = true
		path = path_data.get_path()
		path_index = 0
		has_path_culling_line_of_sight = true

func cull_path():
	if path_index + 1 < path.size():
		col = pixelmap.rayCastQTFromTo(global_position, path[path_index+1], Utils.walkable_collision_mask)
		if col:
			has_path_culling_line_of_sight = false
		else:
			path_index += 1
	else:
		has_path_culling_line_of_sight = false

func get_projected_waypoint() -> Vector2:
	var path_direction = path_waypoint - global_position
	var path_projection = global_position + path_direction.project(heading)
	if (path_projection - path_waypoint).length() < waypoint_radius:
		return path_projection
	else:
		return path_waypoint

func validate_target() -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree():
		target = null
	if target is Player and target.dead:
		target = null
	return target != null

func angle_difference( angle_1:float, angle_2:float ):
	var angle_diference = fmod( angle_2 - angle_1 + PI, TAU ) - PI
	if angle_diference < -PI:
		 angle_diference += TAU
	return angle_diference

### Helper methods
func get_closest_player()->Node2D:
	var closest_player:Node2D
#	if (not player or player.dead) and not Utils.game.players.empty():
	if not Utils.game.players.is_empty():
		var distance:= 0.0
		var min_distance:= INF
		for posiible_player_target in Utils.game.players:
			# czy moze się tu zdażyć, że (not player) = true ???
			if not posiible_player_target.dead:
				distance = (global_position - posiible_player_target.global_position).length_squared()
				if distance < min_distance:
					min_distance = distance
					closest_player = posiible_player_target
	return closest_player

func get_new_target() -> void:
	if ignore_all_targets:
		return
	
	var min_dist = INF
	is_target_visible = false
	if is_instance_valid(primary_target):
		set_target(primary_target)
		return
	var player = get_closest_player()
	if is_instance_valid(player) and is_node_visible_in_range(player, sight_range):
		min_dist = (player.global_position - global_position).length() - player.radius
		set_target(player)
		is_target_visible = true
	else:
		if is_instance_valid(Utils.game.core):
			set_target(Utils.game.core)
			min_dist = (Utils.game.core.global_position - global_position).length() - Utils.game.core.radius
#			if is_node_visible_in_range(Utils.game.core, sight_range):
#				is_target_visible = true

	min_dist = min(min_dist, sight_range)

	var building = Utils.game.map.common_buildings_tracker.getClosestTrackingNode2DInCircle(global_position, min_dist, true)
	if building:
		var building_dist = (building.global_position - global_position).length() - building.radius
		min_dist = max(building_dist, 0.0)
		set_target(building)

	building = Utils.game.map.power_expander_buildings_tracker.getClosestTrackingNode2DInCircle(global_position, min_dist, true)
	if building:
		var building_dist = (building.global_position - global_position).length() - building.radius
		min_dist = max(building_dist, 0.0)
		set_target(building)

	building = Utils.game.map.turret_buildings_tracker.getClosestTrackingNode2DInCircle(global_position, min_dist, true)
	if building:
		var building_dist = (building.global_position - global_position).length() - building.radius
		min_dist = max(building_dist, 0.0)
		set_target(building)

	building = Utils.game.map.mine_buildings_tracker.getClosestTrackingNode2DInCircle(global_position, min_dist, true)
	if building:
		var building_dist = (building.global_position - global_position).length() - building.radius
		min_dist = max(building_dist, 0.0)
		set_target(building)

func set_target( new_target:Node2D )->void:
	target = new_target
	attack_target = new_target
	has_target = true

func update_target_data(target_position: Vector2) -> void:
	target_vector = target_position - global_position
	target_distance = target_vector.length()
	target_direction = target_vector.normalized()

func update_terrain_in_front():
	col = pixelmap.rayCastQTDistance(global_position, heading, wall_repulsion_radius * 2.0, Utils.walkable_collision_mask)
	if col :
		var material_hit = Utils.get_pixel_material(pixelmap.get_pixel_at(col.hit_position-col.hit_normal*0.5))
#		if ( 1 << material_hit & Utils.monster_attack_mask):
		is_terrain_in_front = ( 1 << material_hit & Utils.monster_attack_mask)
#	if not is_ignoring_buildings:
		is_building_in_front = (1 << material_hit & Utils.monster_base_attack_mask)
		is_wall_in_front     = (1 << material_hit & Utils.walls_mask)
		terrain_in_front_destination = col.hit_position+col.hit_normal*0.5
#			destination = col.hit_position + col.hit_normal*0.5
	else:
		is_terrain_in_front = false
		is_building_in_front = false
		is_wall_in_front = false

func is_target_in_field_of_view() -> bool:
	if heading.dot(target_direction) > 0.5:
		return is_target_visible_in_range( sight_range )
	return false

func is_position_visible(pos: Vector2, view_range: float = INF) -> bool:
	var distance := global_position.distance_to(pos)
	var direction := global_position.direction_to(pos)
	
	if distance <= view_range:
		col = pixelmap.rayCastQTDistance(global_position, direction, distance, Utils.walkable_collision_mask, false)
		if col:
			return false
	else:
		return false
	
	return true

func is_node_visible_in_range(node: Node2D, view_range:float = INF) -> bool:
	return is_position_visible(node.global_position, view_range)

func is_target_visible_in_range(view_range:float = INF) -> bool:
	return is_position_visible(target_vector + global_position, view_range)

func on_dead():
	z_index = ZIndexer.Indexes.FLAKI
	collider.queue_free()
	attack_shape.queue_free()
#	walking_audio.stop()
#	if get_parent().has_method("swarm_died"):
#		get_parent().swarm_died()
	set_physics_process(false)
	
	if is_overkill():
		Utils.game.map.pixel_map.flesh_manager.spawn_in_position(global_position, 4, velocity_killed * 0.1)
	else:
		Utils.game.map.pixel_map.flesh_manager.spawn_in_position(global_position, 2, velocity_killed * 0.1)
		Utils.get_audio_manager("swarm_dead").play(self)
		animator.play("death")
		await animator.animation_finished
		animator.play("die")
		sprite.visible = false
		await animator.animation_finished
		
	queue_free()

func get_walking_sound() -> AudioStream:
	return preload("res://SFX/Enemies/Bugs running around 2.wav")

### DEBUG
func _debug_get_text():
	if not has_meta("debug_label"):
		_debug_enable()
	return get_meta("debug_label").text
	
func _debug_enable():
	if not has_meta("debug_label"):
		var debug_label = Label.new()
		debug_label.position = Vector2(-33, -14)
		debug_label.size = Vector2(132, 14)
		debug_label.scale = Vector2(0.2, 0.2)
		debug_label.align = Label.ALIGNMENT_CENTER
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
	debug_log.text = str("\nSTATE:",state_name[current_state])
	debug_log.text += str("\n",animator.current_animation)
	debug_log.text += "\nTarget Distance: "+str(round(target_distance))

	# print_flags
	if is_terrain_in_front:
		debug_log.text += "\nis_terrain_in_front"
#	if is_attackable_terrain_in_front:
#		debug_log.text += "\nis_attackable_terrain_in_front"
	if is_building_in_front:
		debug_log.text += "\nis_building_in_front"
	if is_wall_in_front:
		debug_log.text += "\nis_wall_in_front"
	if is_path_found:
		debug_log.text += "\nis_path_found ("+str(path_index,"/",path.size()) +")" 
		if is_path_through_terrain:
			debug_log.text += " through_terrain"
		
#	debug_log.text += str("\nIm speed: ", velocity.round())
	# print_target
	if target:
#		debug_log.text += "\nT: " +target.name
		if is_target_visible:
			 debug_log.text += "\nI see " +target.name
		else:
			 debug_log.text += "\nI no see " +target.name

	if attack_target:
		debug_log.text += "\nAtacking: " +attack_target.name
	if is_attacking:
		debug_log.text += "\nis_attacking"
#	if destination:
#		debug_log.text += str(destination.round())+"\n"
	update()


func _debug_draw():

#	draw_collisions()
#	draw_leader()
	draw_targeting()
	draw_path()

func draw_collisions():
	if col:
		draw_circle(col.hit_position - global_position, 1, Color.WHITE)
		draw_line(Vector2.ZERO, col.hit_position - global_position, Color.GREEN, 1)
		if col_normal:
			draw_line(col.hit_position - global_position, col.hit_position - global_position + col_normal.normal * 20, Color.YELLOW, 1)
		draw_line(col.hit_position - global_position, col.hit_position - global_position + repulsion  * 1000 , Color.GREEN, 2)
		draw_line(Vector2.ZERO, (foreward + repulsion) * 100 , Color.CYAN, 1)
		draw_line(Vector2.ZERO, foreward  * 10 , Color.BLUE, 1)
		draw_line(Vector2.ZERO, repulsion * 100, Color.RED, 1)
		
func draw_targeting():
	if is_target_visible:
		draw_line(Vector2.ZERO, target_vector, Color(0,1,1,0.5),1)
		draw_line(Vector2.ZERO, selected_direction*20, Color(1,1,1,0.5),1)
	else:
		draw_line(Vector2.ZERO, target_vector, Color(1,0,1,0.5),1)
		draw_line(Vector2.ZERO, selected_direction, Color(1,1,1,0.5),1)

func draw_leader():
	if current_state == STATE.FOLLOWING_LEADER and is_instance_valid(leader):
		draw_line(Vector2.ZERO, leader.global_position - global_position, Color.WHITE,1)
		draw_circle((leader.global_position - global_position)*0.9, 1, Color.BLUE)
		
func draw_path():
	if is_path_found:
		draw_circle( path_waypoint - global_position, 1, Color.GREEN )
		if current_state == STATE.FOLLOWING_PATH:
			for i in range( path.size() - 1 ):
				draw_line( path[i] - global_position , path[i+1] - global_position , Color(1.0,1.0,0.5,0.7), 1 )
				if has_target:
					draw_line( path[ path.size() - 1 ] - global_position , target.global_position - global_position , Color(1.0,1.0,0.5,0.7), 1 )

func set_rotation(r):
	pass
