extends Area2D

var dir: Vector2
var max_range := 0.0
var current_range := 0.0
var speed := 180
var destroyed: bool
@export var damage: int = 5

func _ready() -> void:
	$Particles2D2.queue_free()
#	$Particles2D2.rotation = dir.angle()
	max_range += randf_range(0.0, 10.0)
	Utils.init_enemy_projectile(self, self, {damage = damage, keep = false})
#	Utils.play_sample(Utils.random_sound("res://SFX/Weapons/gun_revolver_pistol_shot"), self).pitch_scale = 1.5
	pass

func on_hit() -> void:
	if not destroyed:
		destroy()
#		position -= dir * speed * get_physics_process_delta_time()

func _physics_process(delta: float) -> void:
#	$Particles2D2.rotation = dir.angle()
	var ray := Utils.game.map.pixel_map.rayCastQTDistance(global_position,  dir, speed * delta, Utils.turret_bullet_collision_mask ^  1<<Const.Materials.LAVA )
	if ray:
#		prints(global_position,  dir, speed)
#		Utils.explode_circle(ray.hit_position, 15, 1000, 100, 5)
		Utils.explode_circle(ray.hit_position, 18, 800, 4, 8, Utils.player_bullet_collision_mask ^ 1<<Const.Materials.LAVA)
#		Utils.explode_circle_no_debris(global_position, 21, 20, 4, 255, Utils.player_bullet_collision_mask ^ 1<<Const.Materials.LAVA , true)
		Utils.play_sample(Utils.get_material_hit_sound(ray.hit_position), self)
		destroy()
	else:
		global_position += dir * speed * delta
		current_range += speed * delta
		if current_range >= max_range:
			Utils.explode_circle(global_position, 18, 800, 4, 8, Utils.player_bullet_collision_mask ^ 1<<Const.Materials.LAVA)
#			Utils.explode_circle(global_position, 3, 1000, 100, 5)
#			Utils.play_sample(Utils.get_material_hit_sound(ray.hit_position), self)
			destroy()

func destroy():
	var trace := preload("res://Nodes/Enemies/ArthomaAcid/Bouble.tscn").instantiate()
	trace.position = global_position
	Utils.game.map.call_deferred("add_child", trace)
	$GPUParticles2D.emitting = false
#	$Particles2D2.emitting = false

	set_physics_process(false)
	get_tree().create_timer(1.5).connect("timeout", Callable(self, "free").bind(), CONNECT_DEFERRED)
