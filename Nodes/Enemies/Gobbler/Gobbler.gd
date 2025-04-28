extends GenericStateEnemy

@export var charge_attack_speed_factor := 2.5
@export var attack_distance_minimal := 40
@export var charge_delay := 1.0
var charge_target_position := Vector2.ZERO


@onready var charge_cooldown_timer = $ChargeCooldownTimer
var can_charge = true
@export var charge_attack_distance := 100

@onready var smoke := $Sprite2D/Smoke as GPUParticles2D
var is_hit_on_building = false
func _init() -> void:
	default_state = "state_idle"

func _ready() -> void:
	if not is_initialized:
		walk_speed *= randf_range(0.8,1.25)
		is_initialized = true
#	growl_audio.set_meta("ignore_warning", true)
	walking_audio.set_meta("ignore_warning", true)
	charge_cooldown_timer.connect("timeout", Callable(self, "_reset_cooldown"))

func area_has_collided():
	is_hit_on_building = true

func state_global(delta: float):
	super.state_global(delta)
	if state == "state_prepare_charge":
		sprite.rotation = lerp_angle(sprite.rotation, angle, 0.5)
	if state == "state_attack":
		sprite.rotation = lerp_angle(sprite.rotation, angle, 0.25)
	if is_walking:
		if state == "state_charge":
			sprite.rotation = lerp_angle(sprite.rotation, angle, 0.5)
		else:
			sprite.rotation = lerp_angle(sprite.rotation, angle, 0.05)
	if smoke:
		if is_walking or state == "state_prepare_charge":
			smoke.emitting = true
		else:
			smoke.emitting = false


func state_attack(delta: float):
	super.state_attack(delta)
	if enter_state:
		is_walking = false
		base_playback_speed = 64
		Utils.play_sample("res://SFX/Enemies/Gobbler/gobbler_attack.wav", audio_player, false, 1.3, 1)
	if await animator.animation_finished:
		base_playback_speed = 16

func state_follow_target(delta: float) -> void:
	if enter_state:
		set_desired_speed(walk_speed)
		Utils.game.start_battle()
		is_attacking = false
		is_custom_animation_playing = false

	if is_front_ray_colliding_with_building:
		if can_charge and !is_attacking:
			if process_availible_attack_on_building_in_front():
				return
		else:
			if super.process_availible_attack_on_building_in_front():
				return
	if targeting.has_target:
		if targeting.target_is_visible:
			if can_charge and !is_attacking:
				process_availible_target_attacks()
			else:
				super.process_availible_target_attacks()
		else:
			if targeting.has_primary_target:
				set_state("state_follow_path")
			else:
				set_state("state_follow_path")
#				set_state("state_idle")

		if not targeting.target_is_building:
			if targeting.target.global_position.distance_squared_to(spawn_position) > max_distance_from_spawn_position:
				set_state("state_follow_path_to_spawn_position")
	else:
		set_state("state_idle", { destination = global_position - heading * (radius+2) })

func state_prepare_charge(delta: float):
	if enter_state:
		walking_audio.stop()
		base_playback_speed = 64
		is_custom_animation_playing = true
		is_attacking = false
		animator.play("preparation")
		set_desired_speed( walk_speed * 0.1 )
		if state_data.has("destination"):
			charge_target_position = state_data.destination

#	if yield(animator, "animation_finished"):
	if timer > animator.current_animation_length/base_playback_speed:
		base_playback_speed = 16
		set_state("state_charge", {destination = charge_target_position})
	else:
		if targeting.has_target and not targeting.target_is_building:
			if targeting.target_is_visible:
				charge_target_position = targeting.target.global_position
				var intercept_offset = 0.0
				intercept_offset = (targeting.target_distance / (walk_speed * charge_attack_speed_factor)) * abs( heading.cross( targeting.target.linear_velocity.normalized() ) ) * 2.0
				intercept_offset *= min(targeting.target_distance, walk_speed * charge_attack_speed_factor) / (walk_speed * charge_attack_speed_factor)
				charge_target_position = targeting.target.global_position + targeting.target.linear_velocity * intercept_offset

				var col = pixelmap.rayCastQTFromTo(global_position, charge_target_position, Utils.walkable_collision_mask)
				if col:
					base_playback_speed = 16
					set_state("state_charge", {destination = charge_target_position})
			else:
				base_playback_speed = 16
				set_state("state_charge", {destination = charge_target_position})
	destination = charge_target_position
	angle = (destination - global_position).angle()

func state_end_charge(delta: float):
	if enter_state:
		walking_audio.stop()
		attack_shape.disabled = true
		base_playback_speed = 64
		is_custom_animation_playing = true
		is_walking = false
		animator.play("preparation_backwards")
	if animator.current_animation == "preparation_backwards" and await animator.animation_finished:
#		walking_audio.stop()
		base_playback_speed = 16
		set_state("state_follow_target")


func state_charge(delta: float):
	if enter_state:
		can_charge = false
		charge_cooldown_timer.start()
		is_custom_movement_playing = true
		animator.play("roll")
		attack_shape.disabled = false
		set_desired_speed(walk_speed * charge_attack_speed_factor)
		is_hit_on_building = false
		is_navigation_dissabled = true
		is_rotation_dissabled = true

		if state_data.has("destination"):
			var col = pixelmap.rayCastQTFromTo(global_position, state_data.destination, Utils.walkable_collision_mask)
			if col :
				state_data.destination = col.hit_position + heading * radius * 4
			else:
				state_data.destination = state_data.destination + heading * radius * 4
		else:
			if targeting.has_target:
				state_data.destination = global_position + (targeting.target_vector).project(heading) + heading * radius * 4
			else:
				state_data.destination = global_position + heading * radius * 4
			var col = pixelmap.rayCastQTFromTo(global_position, state_data.destination, Utils.walkable_collision_mask)
			if col :
				state_data.destination = col.hit_position + heading * radius * 4

		# 0.9 magic number depends strongly on min max attack distance and desired_speed
		if global_position.distance_to(state_data.destination) / desired_speed  > 0.9:
			pass#Utils.play_sample("res://SFX/Enemies/Arthoma/artoma-long_attack03.wav", self, true, 1.1)
		else:
			pass#Utils.play_sample(Utils.random_sound("res://SFX/Enemies/Arthoma/artoma-attack"), self, true, 1.1)

	destination = state_data.destination

	if is_front_ray_colliding:
		if is_front_ray_colliding_with_building or is_hit_on_building:
			attack_shape.disabled = true
			is_custom_movement_playing = false
			animator.playback_speed = 64
			set_state("state_attack")
			#animator.playback_speed = 16
			current_speed *= 0.2
			is_navigation_dissabled = false
			is_rotation_dissabled = false
		else:
			set_desired_speed( max(desired_speed-0.1, walk_speed) )
			timer += delta * 2
		Utils.explode_circle(attack_shape.global_position, 15, 400, 3, 10)
	else:
		if not Utils.game.map.pixel_map.isCircleEmpty(attack_shape.global_position, 10):
			Utils.explode_circle(attack_shape.global_position, 10, 30, 3, 10)
			current_speed *= 0.80

	if global_position.distance_to(destination) <= collision_radius or timer >= 1.5:
		is_custom_movement_playing = false
		set_state("state_end_charge")
		#set_state("state_idle")
		attack_shape.disabled = true
		is_navigation_dissabled = false
		is_rotation_dissabled = false

	is_attacking = false
	is_custom_animation_playing = false

func process_availible_attack_on_building_in_front() -> bool:
	set_state("state_charge", {destination = front_ray_hit_position})
#	set_state("state_charge", {destination = global_position - heading * attack_distance_minimal - heading * radius })
	return false

func process_availible_target_attacks():
	destination = targeting.target.global_position - targeting.target_direction * attack_distance_minimal
	if targeting.target_distance < charge_attack_distance:
		var dot = heading.dot(targeting.target_direction)
		var in_fornt = max(dot, 0) * max(0.0, -(targeting.target_distance - attack_distance_minimal) / (charge_attack_distance - attack_distance_minimal) )
		var in_back = max(-dot, 0) * min(1.0,  (charge_attack_distance - targeting.target_distance ) / (charge_attack_distance - attack_distance_minimal) )
		desired_speed = in_fornt + in_back
#		desired_speed += max(heading.dot(-targeting.target_direction), 0) * min(1.0, (attack_distance - targeting.target_distance ) / (attack_distance - attack_distance_minimal) )
		desired_speed *= walk_speed
		if targeting.target_distance > attack_distance_minimal - dot:
#		if targeting.target_distance > attack_distance_minimal:
			if targeting.is_looking_at_target(0.05): #and state!="state_prepare_charge":
				set_state("state_prepare_charge", {destination = targeting.target.global_position})
			else:
				set_state("state_rotate_to_target", {destination = targeting.target.global_position})
		else:
			destination = targeting.target.global_position - targeting.target_direction * charge_attack_distance

func do_walk_audio():
	if !walking_audio.playing:
		step()

func step():
	#Utils.play_sample("res://SFX/Enemies/Arthoma/artoma-footstep01.wav", walking_audio, false, 1.1)
	#Utils.play_sample(Utils.random_sound("res://SFX/Enemies/Arthoma/artoma-footstep"), walking_audio, false, 1.2, 0.8)
	if is_custom_movement_playing:
		Utils.play_sample("res://SFX/Enemies/Gobbler/gobbler_roll.wav", walking_audio, false, 1.2, 0.5)
	else:
		#Utils.play_sample("res://SFX/Enemies/spider_short_walk/walk5.wav", walking_audio, false, 0.6)
		Utils.play_sample("res://SFX/Enemies/Gobbler/gobbler_walk_new.wav", walking_audio, false, 1.2, 0.68)

func _reset_cooldown():
	can_charge = true
