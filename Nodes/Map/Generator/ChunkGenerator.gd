@tool
extends TextureRect

var rng: RandomNumberGenerator
var is_ready: bool

@export var material_type= Const.Materials.DIRT # (Const.Materials)
@export var mask = ~(0) # (int, LAYERS_3D_PHYSICS)
@export var blue_channel: int = -1

func generate(max_size: Vector2) -> void:
	return

func create_content(generator, pixel_map: PixelMap) -> Array:
	return []

func create_object(type: String, object: String, position: Vector2, data := {}, rotation := 0.0) -> Dictionary:
	var obj := EditorObject.new()
	obj.set_script(preload("res://Nodes/Editor/EditorItem.gd").get_object_script(type, object))
	
	obj.object_type = type
	obj.object_name = object
	obj.init_data(data)
	
	obj.position = position + position
	obj.rotation = rotation
	obj.queue_free()
	
	return obj.get_dict()

func generic_create_content(generator, pixel_map: PixelMap) -> Array:
	var spots: Array
	var content: Array
	
	var available = Utils.HexPoints.get_hex_arranged_points_in_rectangle(Rect2(Vector2(), size), 16)
	for point in available:
		if pixel_map.isCircleEmpty(position + point, 12):
			spots.append(point)
	
	if spots.is_empty():
		return content
	spots.shuffle()
	
	if generator.need_goal > 0 and rng.randi() % 4 == 0:
		var spot: Vector2 = spots.pop_back()
		content.append(create_object("Object", "Goal Point", spot))
		generator.need_goal -= 1
	
	var threat := 100
	for i in min(rng.randi_range(2, 6), spots.size()):
		var spot: Vector2 = spots.pop_back()
		var enemy := create_enemy(spot, threat)
		if enemy.is_empty():
			break
		else:
			threat -= Const.Enemies[enemy.name].threat
			content.append(enemy)
	
	for spot in spots:
		if rng.randi() % 2 == 0:
			continue
		
		var items: Array
		add_random_item(items, Const.ItemIDs.LUMEN, 0, 5)
		add_random_item(items, Const.ItemIDs.METAL_SCRAP, 0, 5)
		add_random_item(items, [Const.ItemIDs.AMMO, Const.Ammo.BULLETS], 5, 20)
		content.append(create_chest(spot, items, align_to_nearest_wall(pixel_map, spot)))
		break
	
	return content

func create_chest(position: Vector2, contents: Array, rotation := 0.0) -> Dictionary:
	return create_object("Object", "Chest", position, {items = contents}, rotation)

func align_to_nearest_wall(pixel_map: PixelMap, position: Vector2) -> float:
	var raycasts = []
	
	for i in 8:
		var raycast = pixel_map.rayCastQTDistance(position, Vector2.RIGHT.rotated(i * 0.785398), 50)
		if raycast:
			raycasts.append([raycast.hit_position, position.distance_to(raycast.hit_position)])
	
	if raycasts.is_empty():
		return rng.randf() * TAU
	
	raycasts.sort_custom(Callable(self, "sort_raycasts"))
	var normal := pixel_map.getCollistionNormal(raycasts.front()[0], 4)
	if normal and normal.get_normal_valid():
		return normal.get_normal().angle() + PI
	else:
		return rng.randf() * TAU

func sort_raycasts(raycast1, raycast2) -> bool:
	return raycast2[1] > raycast1[1]

func add_random_item(container: Array, item, min_amount: int, max_amount: int):
	var amount = rng.randi_range(min_amount, max_amount)
	if amount > 0:
		if item is Array:
			container.append({id = item[0], data = item[1], amount = amount})
		else:
			container.append({id = item, amount = amount})

func create_enemy(position: Vector2, max_threat: int) -> Dictionary:
	var possible: Array
	for enemy in Const.Enemies.values():
		if enemy.get("hide_in_editor", false) or enemy.is_swarm or not "description" in enemy:
			continue
		
		if enemy.threat <= max_threat:
			possible.append(enemy)
	
	if possible.is_empty():
		return {}
	
	var enemy: Dictionary = possible[randi() % possible.size()]
	return create_object("Enemy", enemy.name, position)
