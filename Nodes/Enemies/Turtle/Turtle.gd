extends GenericStateEnemy

var smash_audio : AudioStreamPlayer2D
var growl_audio : AudioStreamPlayer2D

func _init() -> void:
	default_state = "state_idle"

func _ready() -> void:
	smash_audio.set_meta("ignore_warning", true)
	growl_audio.set_meta("ignore_warning", true)
	walking_audio.set_meta("ignore_warning", true)

	stuck_ticks_limit_frames = 10
	Utils.init_enemy_projectile( collider, collider, {damage = 5, keep = true} )
#	collider.collision_mask = Const.PLAYER_COLLISION_LAYER | Const.BUILDING_COLLISION_LAYER
	collider.collision_layer = Const.ENEMY_COLLISION_LAYER

	$Sprite2D/AttackBox.add_to_group("player_projectile")
	$Sprite2D/AttackBox.collision_mask = Const.ENEMY_COLLISION_LAYER | Const.PLAYER_COLLISION_LAYER | Const.BUILDING_COLLISION_LAYER
	$Sprite2D/AttackBox.get_meta("data")["fortified"] = 2.5
	$Sprite2D/AttackBox.get_meta("data")["monster"] = true
#	launch_attack()

func initialize_audio_players():
	walking_audio = AudioStreamPlayer2D.new()
	walking_audio.bus = "SFX"
	walking_audio.attenuation = 2.0
	walking_audio.max_distance = 1000
	add_child(walking_audio)
	
	smash_audio = AudioStreamPlayer2D.new()
	smash_audio.bus = "SFX"
	smash_audio.attenuation = 2.0
	smash_audio.max_distance = 1000
	add_child(smash_audio)

	growl_audio = AudioStreamPlayer2D.new()
	growl_audio.bus = "SFX"
	growl_audio.attenuation = 2.0
	growl_audio.max_distance = 1000
	add_child(growl_audio)
	
### States
func state_global(delta: float):
	if is_dead:
		if is_overkill():
			spawn_flaki()
			z_index = ZIndexer.Indexes.FLAKI
			collider.queue_free()
			set_physics_process(false)
			queue_free()

	if is_attacking:
		selected_direction = destination_direction
		
	super.state_global(delta)
	
	if is_attacking:
		sprite.rotation = lerp_angle(sprite.rotation, angle, sprite_attack_rotation_speed)
	else:
		sprite.rotation = lerp_angle(sprite.rotation, angle, sprite_rotation_speed)

func enter_the_area(area: Area2D) -> void:
	if is_invincible or area.owner == self:
		return
	take_damage(area)

func take_damage(source: Node2D):
	if not source.has_meta("data"):
		return

	var data = source.get_meta("data")
	if "falloff" in data:
		velocity_killed = (global_position-source.global_position).normalized()*source.get_falloff_damage()*20.0
	take_damage_raw(data)

func take_damage_raw(data: Dictionary):
	var dmg := handle_damage(self, enemy_data, data)
	if dmg != 0:
		hp -= dmg
		if not is_dead:
			emit_signal("hp_changed")
	if data.has("velocity"):
		velocity_killed = data.get("velocity", Vector2())
	if hp <= 0:
		if not is_dead:
			_killed()
	else:
		Utils.game.start_battle()
		on_hit(data)

func state_attack(delta: float):
	if enter_state:
		set_desired_speed(walk_speed * 0.2)
		current_speed *= 0.5
		is_attacking = true
		is_custom_animation_playing = true
		animator.play("attack")
		await animator.animation_finished
		set_state("state_follow_target")

func state_die(delta: float):
	if enter_state:
		SteamAPI.increment_stat("KilledBosses")
		set_process(false)
#		set_physics_process(false)
#		set_physics_process_internal(true)
		walking_audio.stop()
#		collider.queue_free()
		if is_instance_valid(attack_shape):
			attack_shape.queue_free()

		if is_overkill():
			spawn_flaki()
			sprite.visible = false
			z_index = ZIndexer.Indexes.FLAKI
		else:
			Utils.play_sample(preload("res://SFX/Enemies/GRUBAS/Death.wav"), growl_audio)
			animator.playback_speed = 30
			animator.play("death")
			await animator.animation_finished
			collider.queue_free()
			set_physics_process(false)
			z_index = ZIndexer.Indexes.FLAKI
			animator.play("die")
			await animator.animation_finished
		queue_free()

func process_availible_attack_on_building_in_front() -> bool:
	destination = front_ray_hit_position
	if global_position.distance_to(destination) < attack_distance:
		set_state("state_attack")
		return true
	return false
	
func process_availible_target_attacks() -> bool:
	if targeting.is_looking_at_target(0.1):
		if targeting.target_distance < attack_distance:
			set_state("state_attack")
			return true
	return false

func get_optimal_pf_lvl_resolution():
#	return min(Utils.game.map.pixel_map.getOptimalPFLvlResolution(radius)+2, 11)
	return path_resolution

func launch_attack(target: Node2D):
	jestem_z_faloo = bool(1)
	targeting.set_primary_target(target)
	add_light_tolerance(10000)
	add_rage(rage_max)
#	set_state("state_follow_path")

func spawn_cracks():
	Utils.game.shake(3.0)
	Utils.game.map.post_process.add_shockwave(attack_shape.global_position, 40.0, Color(20,2.1,1.0))
	var claw := preload("res://Nodes/Enemies/CrystalUrasectus/AOE_cracks.tscn").instantiate() as Node2D
	claw.smash_damage = 15.0
	claw.terrain_dmg_mul = 2.0
	claw.position = attack_shape.global_position
	Utils.game.map.add_child(claw)

func spawn_flaki():
	Utils.game.map.blood_spawner.add_splat(position, velocity_killed, radius)
	Utils.game.map.pixel_map.flesh_manager.spawn_in_position(global_position, 40, velocity_killed * 0.25)

func play_growl():
	if not growl_audio.playing:
		Utils.play_sample(Utils.random_sound("res://SFX/Enemies/Turtle/monster"), growl_audio, false, 1.1)

func play_attack_sound():
	Utils.play_sample(Utils.random_sound("res://SFX/Environmnent/rock_smashable_hit_impact_large_"), smash_audio, false, 1.1)
	spawn_cracks()

func on_hit(data: Dictionary)->void:
#	launch_attack()
	if targeting.has_primary_target:
		Utils.get_audio_manager("gore_hit").play(global_position)
		damaged = true
		return
	super.on_hit(data)
#	if targeting.has_primary_target:
#		go_to_node(targeting.primary_target,10.0)
		
	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/GRUBAS/Grunt"), growl_audio, false, 1.1)
	if timer > 0.5:
		current_speed *= 0.8
		timer = 0.0

#func fallen():
#	Utils.play_sample("res://SFX/Enemies/GRUBAS/Fall.wav", walking_audio, false, 1.1)
#	Utils.explode_circle(attack_shape.global_position, 40, 300, 4, 10)
#	Utils.game.shake_in_direction(1.0, global_position.direction_to(Utils.ca), 1.0)

func do_walk_audio():
	pass

func step():
	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/Turtle/monsterFoot"), walking_audio, false, 1.1, 1.0)
	Utils.game.shake_in_position(global_position, 0.1, 2.0)
