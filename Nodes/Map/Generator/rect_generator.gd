@tool
extends Node2D

const utils = preload("res://Scripts/Singleton/Utils.gd")

@export var my_seed =0: set = set_seed
@export var render_me=true
@export var min_size = Vector2(32,32) 
@export var all_dimensions=false
@export var variable_size=0.0
@export var max_size = Vector2(10000,10000) 
@export var size: Vector2 = min_size: set = set_size
@export var probability = 100
@export var remove_if_lava_rect = false
@export var min_distance_from_reactor = 0

@export var place_objects = false: set = place_objects_impl
@export var empty = false

@export var distance_requirements := [] # (Array, Vector3)


func set_seed(newseed):
	my_seed=newseed
	var rng = RandomNumberGenerator.new()
	rng.seed = my_seed
	var last_seed=rng.randi_range(-10000,10000)
	for j in get_children():
		for i in j.get_children():
			if i.material and i.material is ShaderMaterial:
				i.material=i.material.duplicate()
				if !i.get("use_same_seed"):
					last_seed=rng.randi_range(-10000,10000)
				if "my_seed" in i:
					i.my_seed=last_seed

func show_preview_rect(show_rects):
	$preview.self_modulate=(Color.CORNFLOWER_BLUE*Color(1.0,1.0,1.0,0.5)) if show_rects else Color.TRANSPARENT

func set_size(s: Vector2):
	size = s
	
	if not is_inside_tree():
		await self.ready
	
	$preview.scale = size

func rect_placed_randomizer():
	var texture_rect = get_node_or_null("preview/TextureRect")
	if texture_rect:
		texture_rect.size = size
		texture_rect.scale = Vector2.ONE / size
		texture_rect.rng = $"%GeneratedMapBase".rng
		texture_rect.generate(size)

func place_objects_impl(whatever):
	if not whatever:
		return
	return
	for node in get_children():
		node.queue_free()
	
	var generator = $"%GeneratedMapBase"
	generator.current_object_rect = self
	
	generator.create_object("Object", "Chest", position + Vector2(randf_range(0, size.x), randf_range(0, size.y)))

func get_angle_of_nearest_wall(position: Vector2, precision := 100.0) -> float:
	var pixel_map: PixelMap = $"%NotPixelMap"
	var generator = $"%GeneratedMapBase"
	var raycasts = []
	
	for i in 8:
		var raycast = pixel_map.rayCastQTDistance(position, Vector2.RIGHT.rotated(i * 0.785398), precision)
		if raycast:
			raycasts.append([raycast.hit_position, position.distance_to(raycast.hit_position)])
	
	if raycasts.is_empty():
		return generator.rng.randf() * TAU
	
	raycasts.sort_custom(Callable(self, "_sort_raycasts"))
	var normal := pixel_map.getCollistionNormal(raycasts.front()[0], 4)
	if normal and normal.get_normal_valid():
		return normal.get_normal().angle() + PI
	else:
		return generator.rng.randf() * TAU

func _sort_raycasts(raycast1, raycast2) -> bool:
	return raycast2[1] > raycast1[1]

func get_center() -> Vector2:
	return position + size * 0.5

var steps=[0.5,0.8]
func get_suggested_metal_material(pos):
	
	var generator = $"%GeneratedMapBase"
	var dist = generator.get_distance_from_reactor_normalized_4k(pos)
	if dist < steps[0] + randf_range(0.0,0.3):
		return Const.Materials.WEAK_SCRAP
	elif dist < steps[1] + randf_range(0.0,0.3):
		return Const.Materials.STRONG_SCRAP
	else:
		return Const.Materials.ULTRA_SCRAP

func can_be_placed_in_rect(some_size):
	if all_dimensions:
		if some_size.x < min_size.x:
			return false
		if some_size.y < min_size.y:
			return false
		if some_size.x > max_size.x:
			return false
		if some_size.y > max_size.y:
			return false
	elif some_size < min_size or some_size > max_size:
		return false
	
	return true


func is_smaller_than_size(some_size):
	if some_size.x > min_size.x:
		return true
	if some_size.y > min_size.y:
		return true
	
	return false
