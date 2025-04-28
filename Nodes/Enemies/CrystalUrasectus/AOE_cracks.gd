extends Area2D

var smash_damage := 1.0
var terrain_dmg_mul=1.0

func _ready() -> void:
	Utils.init_enemy_projectile(self, self, {damage = smash_damage, keep = true, fortified=2.5})
#	$Hole.frame = randi()%5
	$Hole.rotation = randf() * TAU

func _on_animation_finished(anim_name):
	queue_free()

func spawn_debris():
	Utils.game.map.pixel_map.particle_manager.spawn_particles(PackedVector2Array([position]), PackedColorArray([Color(0.1,0.1,0.1,1.0)]), Vector2.ZERO)
	Utils.explode_circle(position, 50.0 * scale.x, smash_damage*8*terrain_dmg_mul, 2, 10)
