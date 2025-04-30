extends Node2D

var target_distance: float
var speed: float
var power: float
var damage: int
var cluster=0


const AIR_TIME = 1.0

func _ready() -> void:
	speed = 100.0
	var seq := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	seq.tween_property(self, "scale", Vector2.ONE * 2, target_distance * 0.5/speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	seq.tween_property(self, "scale", Vector2.ONE, target_distance * 0.5/speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	seq.tween_callback(Callable(self, "explode"))
	

func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

func explode():
	var explosion := Const.EXPLOSION.instantiate() as Node2D
	explosion.scale = Vector2.ONE * power
	explosion.position = position
	explosion.dmg = damage
	explosion.fortified=0
	explosion.drops_shadow = false
	explosion.terrain_explosion_dmg = damage*100
	explosion.no_smoke=cluster==0
	get_parent().add_child(explosion)
	

	for i in cluster:
		var bullet = load(scene_file_path).instantiate()
		bullet.cluster=0
		bullet.rotation = randf()*TAU
		bullet.position = global_position
		#var forward_vec=Vector2.RIGHT.rotated(shoot_point.global_rotation)
		#Utils.game.map.pixel_map.smoke_manager.spawn_in_position(shoot_point.global_position, 10,forward_vec*5.0,Color(0.7,0.7,0.7,0.5))
		#Utils.game.map.pixel_map.fire_manager.spawn_in_position(shoot_point.global_position, 20,forward_vec*20.0,Color(0.2,0.2,0.2,1.0))
		bullet.target_distance = randf_range(10,50)
		bullet.power = power*0.5
		bullet.damage = damage*0.5
		bullet.modulate=Color(4.0,5.0,5.0)
		bullet.z_index=ZIndexer.Indexes.SMOKE+1
		Utils.game.map.add_child(bullet)
		
	
	
	
	queue_free()
