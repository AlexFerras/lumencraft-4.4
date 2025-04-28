extends GenericStateEnemy

var growl_audio : AudioStreamPlayer2D

@export var charge_attack_speed_factor := 2.5
@export var attack_distance_minimal := 40
@export var charge_delay := 1.0
var charge_attack_speed_ease := 0.0
var charge_target_position := Vector2.ZERO

@onready var smoke := $Sprite2D/Smoke as GPUParticles2D
var is_stunned = false
var is_hit_on_building = false
func _init() -> void:
	default_state = "state_idle"

func _ready() -> void:
	if not is_initialized:
		walk_speed *= randf_range(0.8,1.25)
		is_initialized = true
	growl_audio.set_meta("ignore_warning", true)
	walking_audio.set_meta("ignore_warning", true)

func initialize_audio_players():
	growl_audio = AudioStreamPlayer2D.new()
	growl_audio.bus = "SFX"
	growl_audio.attenuation = 2.0
	growl_audio.max_distance = 500
	add_child(growl_audio)
	growl_audio.owner = self
	
	walking_audio = AudioStreamPlayer2D.new()
	walking_audio.bus = "SFX"
	walking_audio.attenuation = 2.0
	walking_audio.max_distance = 500
	walking_audio.stream = get_walking_sound()
	add_child(walking_audio)
	walking_audio.owner = self

func area_has_collided():
	is_hit_on_building = true

func state_global(delta: float):
	super.state_global(delta)
	if not is_stunned and is_walking:
		sprite.rotation = lerp_angle(sprite.rotation, angle, 0.05)

func state_follow_target(delta: float) -> void:
	if enter_state:
		set_desired_speed(walk_speed)
		Utils.game.start_battle()

	if is_front_ray_colliding_with_building:
		if process_availible_attack_on_building_in_front():
			return

	if targeting.has_target:
		if targeting.target_is_visible:
			process_availible_target_attacks()
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
		
	is_attacking = false
	is_custom_animation_playing = false

func state_prepare_charge(delta: float):
	if enter_state:
		set_desired_speed( walk_speed * 0.1 )
		is_attacking = false
		is_custom_animation_playing = false
		if state_data.has("destination"):
			charge_target_position = state_data.destination
	
	if timer > 0.3:
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
					set_state("state_charge", {destination = charge_target_position})
			else:
				set_state("state_charge", {destination = charge_target_position})
	destination = charge_target_position
	angle = (destination - global_position).angle()

func state_charge(delta: float):
	if enter_state:
		attack_shape.disabled = false
		set_desired_speed(walk_speed * charge_attack_speed_factor)
		smoke.emitting = true
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
			Utils.play_sample("res://SFX/Enemies/Arthoma/artoma-long_attack03.wav", self, true, 1.1)
		else:
			Utils.play_sample(Utils.random_sound("res://SFX/Enemies/Arthoma/artoma-attack"), self, true, 1.1)

#		var tween = create_tween()
#		tween.tween_interval(0.2)
#		if not state_data.has("destination"):
#			tween.tween_callback(self, "policz pozycje targetu")
#		tween.tween_property(self, "charge_attack_speed_ease", 1.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
#		tween.tween_interval(0.8)
#		tween.tween_property(self, "charge_attack_speed_ease", 0.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

	destination = state_data.destination

	if is_front_ray_colliding:
		if is_front_ray_colliding_with_building or is_hit_on_building:
			attack_shape.disabled = true
			set_state("state_stun")
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
		set_state("state_idle")
		attack_shape.disabled = true
		is_navigation_dissabled = false
		is_rotation_dissabled = false
	
	is_attacking = false
	is_custom_animation_playing = false

func state_stun(delta: float):
	if enter_state:
		set_desired_speed(0.0)
		current_speed  = 0.0
		is_stunned = true
		is_attacking = false
		is_custom_animation_playing = true
		animator.play("stun")

#		destination = global_position + heading * 2.0
		await animator.animation_finished
		is_stunned = false
		#DEBUG MUCH
		if heading.length() >1:
			print ("head to long")
		#DEBUG MUCH
		
		set_state("state_idle", { destination = global_position - heading * (radius+2), idle_time = charge_delay })
		
	if current_speed <= 1.0:
		smoke.emitting = false

func process_availible_attack_on_building_in_front() -> bool:
	set_state("state_charge", {destination = front_ray_hit_position})
#	set_state("state_charge", {destination = global_position - heading * attack_distance_minimal - heading * radius })
	return false

	
func process_availible_target_attacks():
	destination = targeting.target.global_position - targeting.target_direction * attack_distance_minimal
	if targeting.target_distance < attack_distance:
		var dot = heading.dot(targeting.target_direction)
		var in_fornt = max(dot, 0) * max(0.0, -(targeting.target_distance - attack_distance_minimal) / (attack_distance - attack_distance_minimal) )
		var in_back = max(-dot, 0) * min(1.0,  (attack_distance - targeting.target_distance ) / (attack_distance - attack_distance_minimal) )
		desired_speed = in_fornt + in_back
#		desired_speed += max(heading.dot(-targeting.target_direction), 0) * min(1.0, (attack_distance - targeting.target_distance ) / (attack_distance - attack_distance_minimal) )
		desired_speed *= walk_speed
		if targeting.target_distance > attack_distance_minimal - dot  or targeting.target_is_building:
#		if targeting.target_distance > attack_distance_minimal:
			if targeting.is_looking_at_target(0.05):
				set_state("state_prepare_charge", {destination = targeting.target.global_position})
			else:
				set_state("state_rotate_to_target", {destination = targeting.target.global_position})
		else:
			destination = targeting.target.global_position - targeting.target_direction * attack_distance

func do_walk_audio():
	pass
	
func step():
#	Utils.play_sample("res://SFX/Enemies/Arthoma/artoma-footstep01.wav", walking_audio, false, 1.1)
	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/Arthoma/artoma-footstep"), walking_audio, false, 1.2, 0.8)

