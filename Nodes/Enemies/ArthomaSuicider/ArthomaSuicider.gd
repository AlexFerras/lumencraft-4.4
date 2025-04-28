extends GenericStateEnemy
class_name ArthomaSuiciderEnemy

# handles
#onready var smoke := $Sprite/Smoke as Particles2D
 
var explode_damage = 24.0
var type := 0

func _init() -> void:
	default_state = "state_idle"

func _ready() -> void:
	if not is_initialized:
		walk_speed *= randf_range(1.0,1.25)
		is_initialized = true
	$Sprite2D.material = $Sprite2D.material.duplicate()
	$Explode.material = $Sprite2D.material
	set_type(0)
		
#	yield(get_parent(),"ready")
#	yield(get_tree(),"idle_frame")
#	targeting.set_primary_target(Utils.game.players[0])
	
func state_global(delta: float):
	super.state_global(delta)
	if is_walking:
		sprite.rotation = lerp_angle(sprite.rotation, angle, 0.05)

### States
func state_attack(delta: float):
	if enter_state:
		_killed()
		set_state("state_die")

func state_die(delta: float):
	if enter_state:
		set_desired_speed(0.0)
		is_custom_animation_playing = true
		is_attacking = true
		$Explode.rotation = sprite.rotation
		if type:
			animator.play("explode_acid")
		else:
			animator.play("explode")
		
		await animator.animation_finished
		z_index = ZIndexer.Indexes.FLAKI
		if type:
			explode_acid()
		else:
			explode()
			spawn_flaki()
			
		is_attacking = false
		is_custom_animation_playing = false
		set_process(false)
		set_physics_process(false)
		collider.queue_free()
		attack_shape.queue_free()
		walking_audio.stop()
		
		emit_signal("died")
		queue_free()

func process_availible_attack_on_building_in_front() -> bool:
	destination = front_ray_hit_position
	if global_position.distance_to(destination) < attack_distance:
		set_state("state_attack")
	return false
	
func process_availible_target_attacks():
	if targeting.target_distance < attack_distance:
		set_state("state_attack")

func set_type(new_type:int = 0):
	type = new_type
	if type:
		$Sprite2D.material.set_shader_parameter("hue", -0.6)
		$Explode.material.set_shader_parameter("hue", -0.6)
	else:
		$Sprite2D.material.set_shader_parameter("hue", -0.4)
		$Explode.material.set_shader_parameter("hue", -0.4)

func explode_acid():
	for i in 12:
		var angle = randf()*TAU
		var bullet := preload("res://Nodes/Enemies/ArthomaAcid/AcidBullet.tscn").instantiate() as Node2D
		bullet.damage = damage / 2
		bullet.rotation = angle
		bullet.global_position = global_position
		bullet.dir = Vector2.RIGHT.rotated(angle)
		Utils.game.map.add_child(bullet)
		bullet.max_range = abs(randf()+randf() -1.0) * explode_damage
	
func explode():
	var explosion := Const.EXPLOSION.instantiate() as Node2D
	explosion.dmg = round(damage * 2.5)
	explosion.type = explosion.ENEMY
	explosion.scale = Vector2.ONE * (explode_damage / 120.0)
	explosion.position = global_position
	explosion.modulate = Color.MAGENTA
	Utils.game.map.add_child(explosion)
	explosion.get_meta("data")["fortified"] = 2.5
