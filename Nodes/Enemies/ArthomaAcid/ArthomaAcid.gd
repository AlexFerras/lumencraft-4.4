extends GenericStateEnemy

var shooting_target:Node2D

func _init() -> void:
	default_state = "state_idle"

func _ready() -> void:
	if not is_initialized:
		walk_speed *= randf_range(1.0,1.25)
		is_initialized = true

func state_global(delta: float):
	super.state_global(delta)
	if is_walking:
		sprite.rotation = lerp_angle(sprite.rotation, angle, 0.05)
	if is_attacking:
		sprite.rotation = lerp_angle(sprite.rotation, angle, 0.03)
		
func process_availible_attack_on_building_in_front() -> bool:
#	var collided_node = Utils.game.map.player_tracker.getClosestTrackingNode2DInCircle( destination, 1 true)
	destination = front_ray_hit_position
	var shoot_distane = global_position.distance_to(destination)
	if global_position.distance_to(destination) < attack_distance:
		set_state("state_attack_shoot", {distance = shoot_distane})
	return false
	
func process_availible_target_attacks():
	if targeting.is_looking_at_target(0.05):
		shooting_target = targeting.target
		if targeting.target_distance < attack_distance:
			set_state("state_attack_shoot")

func state_attack_shoot(delta: float):
	if enter_state:
		set_desired_speed(0)
		is_attacking = true
		is_custom_animation_playing = true
		animator.play("shoot")
		await animator.animation_finished
		set_state("state_follow_target")
		return

func state_attack(delta: float):
	if enter_state:
		set_desired_speed(0)
		current_speed *= 0.5
		is_attacking = true
		is_custom_animation_playing = true
		animator.play("attack")
		await animator.animation_finished
		set_state("state_follow_target")
		return

	if not attack_shape.disabled:
		Utils.explode_circle((attack_shape.global_position + global_position) * 0.5, radius*2, 20, 4, 10)


func shoot_bullet():
	var bullet := preload("res://Nodes/Enemies/ArthomaAcid/AcidBullet.tscn").instantiate() as Node2D
	bullet.damage = damage / 2
	bullet.rotation = rotation
	bullet.position = global_position
	
		
	if is_instance_valid(shooting_target) and shooting_target.is_inside_tree():
		bullet.dir = (heading + global_position.direction_to(shooting_target.global_position)) * 0.5
	else:
		bullet.dir = heading
		
	if state_data.has("distance"):
		bullet.max_range = state_data.distance
	else:
		bullet.max_range = attack_distance
	Utils.game.map.add_child(bullet)
