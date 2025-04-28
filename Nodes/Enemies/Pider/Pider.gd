extends GenericStateEnemy
class_name PiderEnemy

# handles
@onready var splat := $Splat as Sprite2D

func _init() -> void:
	default_state = "state_idle"

### States

func state_global(delta: float):
	super.state_global(delta)
	if is_walking:
		sprite.rotation = lerp_angle(sprite.rotation, angle, 0.15)
	if is_attacking:
		sprite.rotation = lerp_angle(sprite.rotation, angle, 0.25)

func state_die(delta: float):
	if enter_state:
		walking_audio.stop()
		collider.queue_free()
		attack_shape.queue_free()
		set_process(false)
		set_physics_process(false)
		animator.playback_speed = 30
		splat.visible = true
		splat.frame = randi()%16
		splat.rotation = randf_range( 0, TAU )
		z_index = ZIndexer.Indexes.FLAKI
		if is_overkill():
			spawn_flaki()
			sprite.visible = false
		else:
			spawn_flaki()
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
		
		if targeting.target_distance < 8:
			animator.play("bite")
		else:
			animator.play("claw")

		await animator.animation_finished
		set_state("state_follow_target")
		return
		
	if not attack_shape.disabled:
		Utils.explode_circle((attack_shape.global_position + global_position) * 0.5, radius*2, 20, 4,10)


#func state_intercept(delta: float) -> void:
#	if enter_state:
#		set_desired_speed(walk_speed)
#		Utils.game.start_battle()
#		targeting.target_was_visible = false
#		targeting.pick_target()
#
#	if not is_instance_valid(targeting.target) or not targeting.target.is_inside_tree():
#		return
#
#	targeting.update_target_data(targeting.target.global_position)
#
#	if timer >= 0.1:
#		if randi() % 20 == 0:
#			growl()
#		timer = 0
#		if targeting.is_target_visible_in_range(steering.sight_range): # save last seen target position
#			targeting.target_was_visible = true
#			targeting.target_last_position = targeting.target.global_position
#		else:
#			if targeting.target_was_visible: # if lost target line of sight go to last position
#				set_state("state_go_to", {destination = targeting.target_last_position, angle = targeting.target_last_rotation})
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
#	var intercept_position = targeting.target.global_position + target_velocity * intercept_offset
#	targeting.update_target_data(intercept_position)

func growl():
	if not audio_player.playing:
		Utils.play_sample(Utils.random_sound("res://SFX/Enemies/Small monster Growls"), audio_player)

func do_attack_sound():
	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/Medium monster attack"), self, false, 1.1)

func on_hit(data:Dictionary) -> void:
	super.on_hit(data)
	if timer > 0.5:
		current_speed *= 0.8
		timer = 0.0
