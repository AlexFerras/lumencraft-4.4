extends Node2D

@onready var body := $Body001 as Node2D
@onready var original_scale := body.scale

var hp := 8
var dead: bool
var bump: Tween

func _ready():
	$Area2D.collision_layer = Const.ENEMY_COLLISION_LAYER
	$Area2D.collision_mask = 0

func on_enter(area: Area2D) -> void:
	if dead:
		return
	
	if area.is_in_group("player_projectile"):
		Utils.get_audio_manager("gore_audio").play(self)
		Utils.on_hit(area)
		if bump:
			bump.kill()
		
		bump = create_tween()
		bump.tween_property(body, "scale", original_scale, 0.2).from(original_scale + Vector2.ONE * 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		
		var data: Dictionary = area.get_meta("data")
		hp -= 1
		
		if hp <= 0:
			dead = true
			body.queue_free()
			for node in get_children():
				if node.name.begins_with("Smoke"):
					node.queue_free()
			
			$GPUParticles2D.emitting = true
			bump.kill()
			bump = create_tween()
			bump.tween_property(self, "modulate:a", 0.0, 1).set_delay(9)
			bump.tween_callback(Callable(self, "queue_free"))
