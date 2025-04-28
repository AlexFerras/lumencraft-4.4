extends Area2D

var speed = 150
var direction = Vector2.ZERO

var hit_effect_scene = preload("res://Nodes/Enemies/MegaSwarm/ShootingSwarm/ShootingSwarmProjectileHitEffect.tscn")

func _ready():
	Utils.init_enemy_projectile(self, self, {damage = 2, keep = true})
	Utils.play_sample("res://SFX/Bullets/spit.wav", self,false, 1.3,0.6)
	
func _physics_process(delta):
	var ray := Utils.game.map.pixel_map.rayCastQTDistance(global_position,  direction, speed * delta, Utils.turret_bullet_collision_mask ^  1<<Const.Materials.LAVA )
	if ray:
		Utils.explode_circle(ray.hit_position, 4, 300, 3, 9, Utils.player_bullet_collision_mask ^ 1<<Const.Materials.LAVA)
		spawn_hit_effect()
		#Utils.play_sample(Utils.get_material_hit_sound(ray.hit_position), self)
		queue_free()
	else:
		global_position += direction * speed * delta
	
func _on_Timer_timeout():
	spawn_hit_effect()
	queue_free()

func _on_ShootingSwarmProjectile_area_entered(area):
	spawn_hit_effect()
	queue_free()

func spawn_hit_effect():
	var hit_effect = hit_effect_scene.instantiate()
	hit_effect.global_position = global_position
	Utils.game.map.add_child(hit_effect)
