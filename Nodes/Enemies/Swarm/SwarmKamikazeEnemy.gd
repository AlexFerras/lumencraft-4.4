extends SwarmEnemy
class_name SwarmKamikazeEnemy

@onready var blinker = $Sprite2D/Sprite3

func attack_wall():
	_killed()

func on_dead():
	var explosion = Const.EXPLOSION.instantiate()
	explosion.position = global_position
	explosion.type = explosion.PLAYER
	explosion.scale = Vector2.ONE * 0.2
	Utils.game.map.call_deferred("add_child", explosion)
	
	blinker.queue_free()
	super.on_dead()
