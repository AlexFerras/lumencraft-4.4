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
	if is_walking and not is_attacking:
		sprite.rotation = lerp_angle(sprite.rotation, angle, 0.05)

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
		
#func state_attack(delta: float):
#	if enter_state:
#		is_attacking = true
#		if targeting.target_distance < 12:
#			set_state("state_bite_attack")
#		else:
#			set_state("state_claw_attack")

func process_availible_attack_on_building_in_front() -> bool:
#	var collided_node = Utils.game.map.player_tracker.getClosestTrackingNode2DInCircle( destination, 1 true)
	destination = front_ray_hit_position
	if global_position.distance_to(destination) < attack_distance:
		set_state("state_bite_attack")
	return true
	
func process_availible_target_attacks():
	if targeting.is_looking_at_target(0.01):
		if targeting.target_distance < attack_distance:
			if targeting.target_distance < 12:
				set_state("state_bite_attack")
			else:
				set_state("state_claw_attack")

func state_claw_attack(delta: float):
	if enter_state:
		set_desired_speed(0.0)
		current_speed *= 0.5
		
		is_attacking = true
		is_custom_animation_playing = true
		animator.play("claw")

		await animator.animation_finished
		set_state("state_idle")
		
func state_bite_attack(delta: float):
	if enter_state:
		set_desired_speed(0.0)
		current_speed *= 0.5
		
		is_attacking = true
		is_custom_animation_playing = true
		animator.play("bite")
		
		await animator.animation_finished
		set_state("state_idle")

	if not attack_shape.disabled:
		Utils.explode_circle((attack_shape.global_position + global_position) * 0.5, radius*2, 20, 4,10)

func spawn_claw(id: int):
	var claw := preload("res://Nodes/Enemies/Crueltackle/Claw.tscn").instantiate() as Node2D
	claw.position = attack_shape.global_position + targeting.target_direction * id * 10 + targeting.target_direction.orthogonal() * randf_range(-4, 4)
	Utils.game.map.add_child(claw)

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
