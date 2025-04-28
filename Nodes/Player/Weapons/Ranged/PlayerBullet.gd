extends Area2D

@export var speed: float

@onready var physics: PixelMapPhysics = Utils.game.map.physics
var collider= null
var weapon_id: int
var dir: Vector2
var player: Player
@export var max_distance:float =INF
var distance_traveled=0.0
var minimal_distance_to_flip_z_index: = 15.0

func _ready() -> void:
	collider=get_node_or_null("CollisionShape2D")
	dir = Vector2.RIGHT.rotated(rotation)
	
	if weapon_id:
		Player.init_weapon(self, self, weapon_id)
	else:
		Utils.init_player_projectile(self, self, get_damage_data())
	get_meta("data").velocity = dir * speed

func set_player(p: Player):
	player = p

func on_hit():
	var data=get_meta("data")
	if not data.get("destroyed") and not get_meta("data").get("keep"):
		
		destroy(data.get("blood",true))
		position -= dir * speed * get_physics_process_delta_time()

func destroy(blood: bool):
#	get_meta("data").destroyed = true
	var spark: Node2D
	if blood:
		spark = preload("res://Nodes/Effects/Impact/BulletBlood.tscn").instantiate()
		spark.rotation = rotation
	else:
		spark = preload("res://Nodes/Effects/Impact/BulletSpark.tscn").instantiate()
		var normal = physics.get_collision_normal(position,4)
		if normal and normal.normal_valid:
			spark.rotation = dir.bounce(normal.normal).angle()
		else:
			spark.rotation = (-dir).angle()
	spark.position = position
	get_parent().add_child(spark)
	if collider: #todo wyrzucic bo tak nie bylo
		collider.call_deferred("set_disabled",true)
	set_physics_process(false)

	get_tree().create_timer(0.1).connect("timeout", Callable(self, "free").bind(), CONNECT_DEFERRED)

func get_damage_data() -> Dictionary:
	return {}

func queue_destroy():
	set_physics_process(false)
	get_tree().connect("physics_frame", Callable(self, "destroy").bind(false), CONNECT_ONE_SHOT)
