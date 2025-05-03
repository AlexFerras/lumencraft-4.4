extends GenericStateEnemy

# handles
#onready var splat := $Splat as Sprite
@export var smash_attack_distance:= 30
var smash_audio : AudioStreamPlayer2D
var growl_audio : AudioStreamPlayer2D

@onready var terrain_damage :=  $Sprite2D/DeathTerrainDamage
@onready var fall_damage :=  $Sprite2D/FallDamage

var just_gave_up := false
var has_shrinked := false

func _init() -> void:
	default_state = "state_idle"

func _ready() -> void:
	smash_audio.set_meta("ignore_warning", true)
	growl_audio.set_meta("ignore_warning", true)
	walking_audio.set_meta("ignore_warning", true)

	stuck_ticks_limit_frames = 5
	Utils.init_enemy_projectile(collider, collider, {damage = 10, keep = true})
#	collider.collision_mask = Const.PLAYER_COLLISION_LAYER | Const.BUILDING_COLLISION_LAYER
	collider.collision_layer = Const.ENEMY_COLLISION_LAYER

	$Sprite2D/AttackBox.add_to_group("player_projectile")
	$Sprite2D/AttackBox.collision_mask = Const.ENEMY_COLLISION_LAYER | Const.PLAYER_COLLISION_LAYER | Const.BUILDING_COLLISION_LAYER
	$Sprite2D/AttackBox.get_meta("data")["fortified"]=2.5
	$Sprite2D/AttackBox.get_meta("data")["monster"] = true

	Utils.init_enemy_projectile(fall_damage, fall_damage, {damage = 30, keep = true})
	
	charge_timer = randf() * charge_cooldown
#	yield(get_parent(),"ready")
#	yield(get_tree(),"idle_frame")
#	targeting.set_primary_target(Utils.game.core)

func initialize_audio_players():
	walking_audio = AudioStreamPlayer2D.new()
	walking_audio.bus = "SFX"
	walking_audio.attenuation = 2.0
	walking_audio.max_distance = 1000
	add_child(walking_audio)
	walking_audio.owner = self
	
	smash_audio = AudioStreamPlayer2D.new()
	smash_audio.bus = "SFX"
	smash_audio.attenuation = 2.0
	smash_audio.max_distance = 1000
	add_child(smash_audio)
	smash_audio.owner = self

	growl_audio = AudioStreamPlayer2D.new()
	growl_audio.bus = "SFX"
	growl_audio.attenuation = 2.0
	growl_audio.max_distance = 1000
	add_child(growl_audio)
	growl_audio.owner = self
	
### States
func state_follow_path_to_spawn_position(delta: float) -> void:
	super.state_follow_path_to_spawn_position(delta)
	if enter_state:
		SteamAPI.unlock_achievement("BOSS_RETURN_TO_SPAWN")

func state_global(delta: float):
	if is_dead:
		if is_overkill():
			spawn_flaki()
			z_index = ZIndexer.Indexes.FLAKI
			Utils.remove_from_tracker(self)
			collider.queue_free()
			set_physics_process(false)
			queue_free()
		
#	if is_dead:
#		call(state, delta)

#	else:
#		targeting.pick_target( delta )
#
#		if targeting.has_target:
#			if targeting.target_is_visible:
#				destination = targeting.target.global_position
#			elif is_front_ray_colliding_with_building:
#				destination = front_ray_hit_position
#
#		call(state, delta)
#
#		destination_distance  = global_position.distance_to(destination)
#		destination_direction = global_position.direction_to(destination)
#
#		update_direction()
#		update_angle(delta)
#		update_velocity(delta)
#		update_ray_material_collision()
#		update_movement(delta)
#		match_animation_to_speed()
	if just_gave_up:
		call("state_give_up", delta)
	else:
		super.state_global(delta)
		
	sprite.rotation += 0.410152 # magic numbers bo grafika na sprite jest obrócona
	if is_attacking:
		sprite.rotation = lerp_angle(sprite.rotation, angle, sprite_attack_rotation_speed)
	else:
		sprite.rotation = lerp_angle(sprite.rotation, angle, sprite_rotation_speed)
	sprite.rotation -= 0.410152 # magic numbers bo grafika na sprite jest obrócona

func enter_the_area(area: Area2D) -> void:
	if is_invincible or area.owner == self:
		return
	take_damage(area)

func take_damage(source: Node2D):
	if not source.has_meta("data"):
		return
		
	var data=source.get_meta("data")
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
			if data.has("owner") and data.owner.has_meta("isFlare"):
				SteamAPI.unlock_achievement("KILL_FLARE_BOSS")
				SteamAPI.unlock_achievement("KILL_FLARE")
				
			SteamAPI.increment_stat("KilledBosses")
			_killed()
	else:
		Utils.game.start_battle()
		on_hit(data)

func state_attack(delta: float):
	if enter_state:
		var rand = randi()%3
		match rand:
			0:
				set_state("state_attack_punch")
			1:
				set_state("state_attack_swipe")
			2:
				set_state("state_attack_smash_AOE")

func state_attack_smash_AOE(delta: float):
	if enter_state:
		selected_direction = heading
		set_desired_speed(0)
		current_speed *= 0.5
		is_attacking = true
		is_custom_animation_playing = true
		animator.play("attack_smash_AOE")
		await animator.animation_finished
		set_state("state_follow_target")
#	if not attack_shape.disabled:
#		Utils.explode_circle(attack_shape.global_position, 20, 300, 4, 10) 
#		Utils.game.map.pixel_map.particle_manager.spawn_particles(PoolVector2Array([attack_shape.global_position]), PoolColorArray([Color(0.1,0.1,0.1)]), Vector2.ZERO)

func state_attack_smash(delta: float):
	if enter_state:
		selected_direction = heading
		set_desired_speed(0)
		current_speed *= 0.5
		is_attacking = true
		is_custom_animation_playing = true
		animator.play("attack_smash")
		await animator.animation_finished
		set_state("state_follow_target")

	if not attack_shape.disabled:
		Utils.explode_circle(attack_shape.global_position - (attack_shape.global_position-global_position )*0.25, 20, 60, 4, 10) 
		Utils.game.map.pixel_map.particle_manager.spawn_particles(PackedVector2Array([attack_shape.global_position]), PackedColorArray([Color(0.1,0.1,0.1)]), Vector2.ZERO)

func state_attack_punch(delta: float):
	if enter_state:
		selected_direction = heading
		set_desired_speed(0)
		is_attacking = true
		is_custom_animation_playing = true
		animator.play("attack_punch")
		await animator.animation_finished
		set_state("state_follow_target")
		return

	if not attack_shape.disabled:
		Utils.explode_circle(attack_shape.global_position - (attack_shape.global_position-global_position )*0.25, 20, 60, 4, 10)
		Utils.game.map.pixel_map.particle_manager.spawn_particles(PackedVector2Array([attack_shape.global_position]), PackedColorArray([Color(0.1,0.1,0.1)]), Vector2.ZERO)

func state_attack_swipe(delta: float):
	if enter_state:
		selected_direction = heading
		set_desired_speed(walk_speed * 0.5)
		is_attacking = true
		is_custom_animation_playing = true
		animator.play("attack_swipe")
		await animator.animation_finished
		set_state("state_follow_target")
		return

	if not attack_shape.disabled:
		Utils.explode_circle(attack_shape.global_position - (attack_shape.global_position-global_position )*0.25, 20, 60, 4, 10)
		Utils.game.map.pixel_map.particle_manager.spawn_particles(PackedVector2Array([attack_shape.global_position]), PackedColorArray([Color(0.1,0.1,0.1)]), Vector2.ZERO)

#		set_physics_process_internal(true)
#func _notification(what):
#	if what == NOTIFICATION_INTERNAL_PHYSICS_PROCESS:
#		pass

func state_die(delta: float):
	if enter_state:
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
#			collider.queue_free()
			set_physics_process(false)
			z_index = ZIndexer.Indexes.FLAKI
			animator.play("die")
			await animator.animation_finished
		queue_free()

func process_availible_attack_on_building_in_front() -> bool:
	destination = front_ray_hit_position
	if global_position.distance_to(destination) < attack_distance:
		match randi()%2:
			0:
				animator.play("attack_punch")
				set_state("state_attack_punch")
			1:
				animator.play("attack_swipe")
				set_state("state_attack_swipe")
		return true
	return false

func process_availible_target_attacks():
	if targeting.target_distance < smash_attack_distance:
		if not targeting.target_is_building and targeting.target.linear_velocity.dot(heading) < 0:
			animator.play("attack_smash_AOE")
			set_state("state_attack_smash_AOE")
		else:
			match randi()%2:
				0:
					animator.play("attack_punch")
					set_state("state_attack_punch")
				1:
					animator.play("attack_swipe")
					set_state("state_attack_swipe")

func get_optimal_pf_lvl_resolution():
	if has_shrinked:
		return path_resolution
		
	if is_instance_valid(targeting):
		if targeting.has_target:
			has_shrinked = true
			return path_resolution
		elif targeting.has_primary_target:
			return super.get_optimal_pf_lvl_resolution() + 1
		else:
			has_shrinked = true
			return path_resolution
	else:
		return super.get_optimal_pf_lvl_resolution() + 1
#	print (Utils.game.map.pixel_map.getOptimalPFLvlResolution(radius))
#	return min(Utils.game.map.pixel_map.getOptimalPFLvlResolution(radius)+2, 11)

#func state_intercept(delta: float) -> void:
#	if enter_state:
#		set_desired_speed(walk_speed)
#		Utils.game.start_battle()
#		targeting.target_was_visible = false
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
#				set_state("go_to_state", {destination = targeting.target_last_position, angle = targeting.target_last_rotation})
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

func spawn_cracks():
	Utils.game.shake_in_position(attack_shape.global_position, 1.0, 5.0)
	Utils.game.map.post_process.add_shockwave(attack_shape.global_position, 80.0,Color(2,2.1,1.0))
	var claw := preload("res://Nodes/Enemies/CrystalUrasectus/AOE_cracks.tscn").instantiate() as Node2D
	claw.smash_damage = damage + 35.0
	claw.position = attack_shape.global_position
	Utils.game.map.add_child(claw)

func spawn_claw(id: float):
	#Utils.game.shake(6.0-id)
	Utils.game.shake_in_position(attack_shape.global_position, 1.0 - float(id)/6.0, 1.0)
	#Utils.game.shake_in_direction(1.0 - float(id)/6.0, attack_shape.global_position.direction_to(Utils.game.camera.get_screen_center_position()), 1.0)
	#Utils.game.camera.get_screen_center_position()
	var claw := preload("res://Nodes/Enemies/Crueltackle/Claw.tscn").instantiate() as Node2D
	claw.scale = Vector2.ONE * 2.0
	claw.damage_radius = 3.0
	claw.position = (global_position + attack_shape.global_position)*0.5 + heading.rotated(id/6.0 *PI) * 40
	Utils.game.map.add_child(claw)
	if id > 0 and id < 6:
		claw = preload("res://Nodes/Enemies/Crueltackle/Claw.tscn").instantiate() as Node2D
		claw.scale = Vector2.ONE * 2.0
		claw.damage_radius = 3.0
		claw.position = (global_position + attack_shape.global_position) * 0.5 + heading.rotated(-id/6.0 * PI) * 40
		Utils.game.map.add_child(claw)

func spawn_flaki():
	Utils.game.map.blood_spawner.add_splat(position, velocity_killed, radius)
	Utils.game.map.pixel_map.flesh_manager.spawn_in_position(global_position, 400, velocity_killed * 0.05)
	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/GRUBAS/HeadExploding"), global_position).volume_db = 20.0
#	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/GRUBAS/HeadExploding"), walking_audio, false, 1.1)

func spawn_flaki_alot():
	Utils.game.map.blood_spawner.add_splat(position, velocity_killed, radius)
	Utils.game.map.pixel_map.flesh_manager.spawn_in_position(global_position, 4000, velocity_killed)
#	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/GRUBAS/HeadExploding"), global_position).volume_db = 60.0
	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/GRUBAS/HeadExploding"), global_position).volume_db = 20.0

func play_growl():
	if not growl_audio.playing:
		Utils.play_sample(Utils.random_sound("res://SFX/Enemies/GRUBAS/Attack_"), growl_audio, false, 1.1)

func play_attack_sound():
#	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/GRUBAS/Attack_"), growl_audio, false, 1.1)
	if not state == "attack_smash":
		Utils.play_sample(Utils.random_sound("res://SFX/Environmnent/rock_smashable_hit_impact_"), smash_audio, false, 1.1)
	else:
		Utils.play_sample(Utils.random_sound("res://SFX/Environmnent/rock_smashable_hit_impact_large_"), smash_audio, false, 1.1)

func on_hit(data: Dictionary)->void:
	super.on_hit(data)
	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/GRUBAS/Grunt"), growl_audio, false, 1.1)
	if timer > 0.5:
		current_speed *= 0.8
		timer = 0.0

func _killed():
	if is_dead:
		return
	is_dead = true

	Save.count_score("enemies_slain")
	get_tree().call_group("kill_observers", "enemy_killed", enemy_data.name)

	emit_signal("died")
	if probability_spawn_resource > 0:
		if not loot.is_empty(): ## TODO: nie powielać kodu jak debil
			for drop in loot:
				drop.spawn_items()
			emit_signal("resource_spawned")
	

		var what_to_spawn: int = randi() % probability_spawn_resource
		if what_to_spawn == 0:
			Utils.game.map.pickables.spawn_premium_pickable_nice(global_position, Const.ItemIDs.METAL_SCRAP)
			emit_signal("resource_spawned")
		elif what_to_spawn == 1:
			Utils.game.map.pickables.spawn_premium_pickable_nice(global_position, Const.ItemIDs.LUMEN)
			emit_signal("resource_spawned")
	
	on_dead()

func fallen():
	Utils.play_sample("res://SFX/Enemies/GRUBAS/Fall.wav", walking_audio, false, 1.1)
	Utils.explode_circle(terrain_damage.global_position, 40, 300, 4, 10)
	Utils.game.shake_in_direction(1.0, global_position.direction_to(Utils.game.main_player.global_position), 1.0)
	z_index = ZIndexer.Indexes.FLAKI
	Utils.remove_from_tracker(self)
	collider.queue_free()
	set_physics_process(false)

func do_walk_audio():
	pass
	
func step():
	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/GRUBAS/Footsteps"), walking_audio, false, 1.1)
	Utils.game.shake_in_position(global_position, 0.1, 5.0)
	
func dying_step():
	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/GRUBAS/Footsteps"), walking_audio, false, 1.1)
	Utils.game.shake_in_position(global_position, 2, 5.0)
	Utils.explode_circle(terrain_damage.global_position, 30, 300, 4, 10)

func state_give_up(delta: float):
	if enter_state:
		set_process(false)
		walking_audio.stop()
		attack_shape.queue_free()
		
#		Utils.play_sample(preload("res://SFX/Enemies/Small monster Growls 1.wav"), growl_audio,false ,1.0,0.6).volume_db = 30.0
		Utils.play_sample(preload("res://SFX/Enemies/Small monster Growls 1.wav"), growl_audio,false ,1.0,0.6)
		animator.play("give_up")
		animator.playback_speed = 30
		await animator.animation_finished
		spawn_flaki_alot()
		Utils.game.shake_in_position(global_position, 1.0, 5.0)
		Utils.game.map.post_process.add_shockwave(global_position, 280.0,Color(1,2.1,2.0))
		var claw := preload("res://Nodes/Enemies/CrystalUrasectus/AOE_cracks.tscn").instantiate() as Node2D
#		claw.smash_damage = damage + 235.0
		claw.smash_damage = damage + 55.0
		claw.position = global_position
		claw.scale *= 2.0
		Utils.game.map.add_child(claw)
		Utils.explode_circle(global_position, 60, 260, 255, 255) 
		sprite.visible = false
		z_index = ZIndexer.Indexes.FLAKI
		set_physics_process(false)
		queue_free()

func give_up():
	var prob = randi()%100
	
	if prob < 5:
		is_dead = true
		Save.count_score("enemies_slain")
		get_tree().call_group("kill_observers", "enemy_killed", enemy_data.name)
		emit_signal("died")
		just_gave_up = true
		set_state("state_give_up")
#	elif prob < 35:
#		if targeting.has_target:
#			global_position = targeting.target.global_position
#		else:
#			set_state("state_follow_path_to_spawn_position")
	else:
		set_state("state_follow_path_to_spawn_position")
