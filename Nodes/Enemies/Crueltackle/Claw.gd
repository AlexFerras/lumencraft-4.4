extends Area2D

var damage_radius := 1.0

func _ready() -> void:
	Utils.init_enemy_projectile(self, self, {damage = 5, keep = true})
	$Sprite2D.frame = randi()%5
	$Sprite2D.rotation = randf() * TAU

func _on_animation_finished(anim_name):
	queue_free()

func spawn_debris():
	Utils.game.map.pixel_map.particle_manager.spawn_particles(PackedVector2Array([position]), PackedColorArray([Color(0.1,0.1,0.1,1.0)]), Vector2.ZERO)
	Utils.explode_circle(position, damage_radius * scale.x, 100, 3, 10)
#	damage_radius += 1.0
#func explode_circle(position: Vector2, radius: float, dmg: int, hardness: float, threshold := 255):
