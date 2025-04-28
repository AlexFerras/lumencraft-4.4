extends GenericStateEnemy

# handles
@onready var splat := $Splat as Sprite2D

func _init() -> void:
	default_state = "state_idle"

#func _ready() -> void:
#	._ready()
	
#	hp = sprite.scale.x * enemy_data.hp
#	max_hp = sprite.scale.x * enemy_data.hp

### States

func state_global(delta: float):
	super.state_global(delta)
	if is_walking:
		sprite.rotation = lerp_angle(sprite.rotation, angle, 0.05)

func state_follow_target(delta: float) -> void:
	if enter_state:
		is_attacking = false
		is_custom_animation_playing = false
		set_desired_speed(walk_speed)
		Utils.game.start_battle()
#		do_audio_feedback()

	if not is_attacking:
		if targeting.has_target:
			if targeting.target_is_visible:
				process_availible_target_attacks()
			else:
				if targeting.has_primary_target:
					set_state("state_follow_path")
				else:
					set_state("state_idle")
					
			if not targeting.target_is_building:
				if targeting.target.global_position.distance_squared_to(spawn_position) > max_distance_from_spawn_position:
					set_state("state_follow_path_to_spawn_position")
		else:
			set_state("state_idle")
			path_waypoint = global_position

#func do_audio_feedback():
#	if randi()%2:
#		animator.play("roar")
#		play_roar()
#		animator.playback_speed = 60
#		yield(animator, "animation_finished")

func state_die(delta: float):
	if enter_state:
		walking_audio.stop()
		collider.queue_free()
		attack_shape.queue_free()
		set_process(false)
		set_physics_process(false)
		splat.frame = randi()%16
		splat.visible = true
		splat.rotation = randf_range( 0, TAU )
		z_index = ZIndexer.Indexes.FLAKI
		if is_overkill():
			spawn_flaki()
			sprite.visible = false
		else:
			Utils.play_sample(Utils.random_sound("res://SFX/Enemies/Small monster Death"), self)
		animator.play("death")
		await animator.animation_finished
		animator.play("die")
		await animator.animation_finished
		queue_free()
		
func state_attack(delta: float):
	if enter_state:
		set_desired_speed(0.0)
		current_speed *= 0.5
		
		is_attacking = true
		is_custom_animation_playing = true
		
		animator.play("bite")
		await animator.animation_finished
		set_state("state_follow_target")
		return

#func state_intercept(delta: float) -> void:
#	if enter_state:
#		set_desired_speed(walk_speed)
#		Utils.game.start_battle()
#		targeting.target_was_visible = false
#		targeting.pick_target(delta)
#
#	if not is_instance_valid(targeting.target) or not targeting.target.is_inside_tree():
#		return
#
#	targeting.update_target_data(targeting.target.global_position)
#
#	if timer >= 0.1:
#		if randi() % 20 == 0:
#			animator.play("roar")
#			play_roar()
#			animator.playback_speed = 60
#			yield(animator, "animation_finished")
#		timer = 0
#		if targeting.is_target_visible_in_range(steering.sight_range): # save last seen target position
#			targeting.target_was_visible = true
#			targeting.target_last_position = targeting.target.global_position
#		else:
#			if targeting.target_was_visible: # if lost target line of sight go to last position
#				set_state("state_idle", {destination = targeting.target_last_position, angle = targeting.target_last_rotation})
#			else: # if lost target line of sight and do not know where target was
#				set_state("state_follow_path")
#
#	if targeting.target_distance < attack_distance: # when close then transition to attack
#		set_state("state_attack")
#
#	var target_velocity: Vector2
#	if targeting.target is Player:
#		target_velocity = targeting.target.linear_velocity
#
#	var intercept_offset = 0.0
#	if current_speed > 0:
#		intercept_offset = (targeting.target_distance / current_speed) * abs( heading.cross( Vector2.RIGHT.rotated(targeting.target.rotation) ) )
#		intercept_offset *= min(targeting.target_vector.project(heading).length(), current_speed) / current_speed
#	var intercept_position = targeting.target.global_position + targeting.target_velocity * intercept_offset
#	targeting.update_target_data(intercept_position)

#
#func state_dig(delta: float):
#	var dig_ray := Utils.game.map.physics.raycast(global_position, global_position + heading * waypoint_radius)
#	if dig_ray:
#		Utils.explode_circle(dig_ray.position, avoid_range, 100, 5)
#
#	if timer >= 0.25:
#		timer = 0
#
#		if not dig_ray:
#			search_path_to(targeting.target.global_position)
#			if path:
#				set_state("idle")
#
#		if targeting.is_target_visible_in_range(150.0):
#			set_state("chase")

func state_roar(delta: float):
	if enter_state:
		animator.play("roar")
		play_roar()
		animator.playback_speed = 60
		await animator.animation_finished
	set_state("state_follow_target")

func spawn_flaki():
	Utils.game.map.blood_spawner.add_splat(position, velocity_killed, radius)
	Utils.game.map.pixel_map.flesh_manager.spawn_in_position(global_position, 40, velocity_killed * 0.25)
	
func play_roar():
	if not audio_player.playing:
		Utils.play_sample(Utils.random_sound("res://SFX/Enemies/Small monster Growls"), audio_player)

func do_attack_sound():
	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/Medium monster attack"), self, false, 1.1)

func on_hit(data:Dictionary)->void:
	super.on_hit(data)
	if timer > 0.5:
		current_speed *= 0.8
		timer = 0.0
