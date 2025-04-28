@tool
extends Node2D

@export var enemy_scene: PackedScene

@export var editor_spawn: bool: set = spawn_in_editor

func _ready() -> void:
	if Engine.is_editor_hint() or not visible:
		return
	
	while get_child_count() < 2000:
		spawn_enemies()

func spawn_in_editor(s):
	if not s:
		return
	
	spawn_enemies()

func spawn_enemies():
	var pixel_map: PixelMap = get_tree().get_nodes_in_group("PixelMap").front()
	
	var amount := 3 + randi() % 16
	var center: Vector2
	
	for i in amount:
		var enemy := enemy_scene.instantiate() as Node2D
		if not center:
			for j in 10000:
				center = Vector2(randf_range(0, pixel_map.get_texture().get_width()), randf_range(0, pixel_map.get_texture().get_height()))
				if center.distance_squared_to(pixel_map.get_texture().get_size() / 2) > 1000000 and not pixel_map.is_pixel_solid(center, Utils.walkable_collision_mask):
					break
		
		var spawn_point: Vector2
		for j in 10000:
			spawn_point = center + Utils.random_point_in_circle(200)
			if not pixel_map.is_pixel_solid(spawn_point, Utils.walkable_collision_mask):
				break
		
		add_child(enemy)
		enemy.global_position = spawn_point
		enemy.owner = owner
