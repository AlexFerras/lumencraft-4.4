extends Area2D

@onready var physics: PixelMapPhysics = Utils.game.map.physics

var direction: Vector2
var speed := 300.0
var lifetime: float

var size: int
var wave_offset: float
var dig: int
var bounce: int
var explosion: int

func _ready() -> void:
	Utils.init_player_projectile(self, self, {damage = 5, velocity = direction * 100})
	scale = Vector2.ONE * (0.5 + size * 0.25)
	
	var light := $LightSprite as Node2D
	var seq := light.create_tween().set_loops()
	seq.tween_property(light, "scale", Vector2.ONE * 0.4, 0.1).set_trans(Tween.TRANS_SINE)
	seq.tween_property(light, "scale", Vector2.ONE * 0.3, 0.1).set_trans(Tween.TRANS_SINE)

func _physics_process(delta: float) -> void:
	lifetime += delta
	if wave_offset:
		position += direction.rotated(PI/2) * sin(lifetime * 20 + wave_offset) * 2
	
	var ray := physics.raycast(global_position, global_position + direction * speed * delta)
	if ray:
		var bounced: bool
		if bounce > 0:
			var normal := physics.get_collision_normal(ray.position, 8)
			if normal:
				direction = direction.bounce(normal.normal)
				bounced = true
		
		if bounce == 0 or explosion > 0:
			Utils.explode_circle(ray.position, 6 + dig / 5 + size / 4 + explosion * 10, 100 + explosion * 20, 1 + explosion, 5 + explosion * 50)
			if dig > 0:
				dig -= 1
				position += direction * ray.travel
			elif bounce == 0:
				queue_free()
		
		if explosion > 0:
			var explosion_instance := preload("res://Nodes/Effects/Explosion/NeutronExplosion.tscn").instance() as Node2D
			explosion_instance.scale = Vector2.ONE * (0.1 + explosion * 0.05)
			explosion_instance.position = position
			get_parent().add_child(explosion_instance)
		
		if bounced:
			bounce -= 1
	else:
		position += direction * speed * delta
