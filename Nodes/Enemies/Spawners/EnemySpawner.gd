@tool
extends Marker2D

@export var threat: int = 500
@export var radius := 150.0: set = set_radius
@export var nest: bool

var nest_instance: BaseEnemy

func _ready() -> void:
	if not Engine.is_editor_hint():
		if nest:
			nest_instance = preload("res://Nodes/Enemies/Spawners/Nest.tscn").instance()
			nest_instance.size = radius
			nest_instance.connect("died", Callable(self, "queue_free"))
			nest_instance.position = position
			get_parent().call_deferred("add_child", nest_instance)
		else:
			queue_free()
		spawn()

func set_radius(r: float):
	radius = r
	
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2(), radius, 0, TAU, 64, Color.RED, 2)

func spawn():
	var pixel_map: PixelMap = Utils.game.map.pixel_map
	for i in threat:
		var enemy := get_next_enemy()
		if not enemy:
			break
		assert(enemy.position == Vector2())
		
		while not enemy.position or pixel_map.is_pixel_solid(enemy.position, Utils.walkable_collision_mask):
			enemy.position = global_position + Utils.random_point_in_circle(radius)
		
		Utils.game.map.call_deferred("add_child", enemy)
		if nest:
			enemy.connect("died", Callable(self, "enemy_died").bind(enemy))
			nest_instance.add_enemy(enemy)

func enemy_died(enemy: BaseEnemy):
	threat += enemy.threat
	spawn()

func get_next_enemy() -> BaseEnemy:
	var possible_enemies: Array
	
	for enemy in Const.Enemies.values():
		if enemy.threat > 0 and enemy.threat <= threat:
			possible_enemies.append(enemy)
	
	if possible_enemies:
		var enemy: Dictionary = possible_enemies[randi() % possible_enemies.size()]
		threat -= enemy.threat
		return load(enemy.scene).instantiate() as BaseEnemy
	
	return null
