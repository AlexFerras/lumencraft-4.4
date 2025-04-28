@tool
extends "res://Nodes/Map/Generator/rect_generator.gd"

func place_objects_impl(whatever):
	if not whatever:
		return
	
	var generator = $"%GeneratedMapBase"
	var rng: RandomNumberGenerator = generator.rng
	var power = generator.get_distance_from_reactor(get_center()) * 2
	
	var key := [{id = Const.ItemIDs.KEY, data = rng.randi() % 4, amount = 1}]

	generator.create_object("Object", "Light3D", Rect2(position, size).get_center(), {color = Color(0.1,0.7,0.5), radius=0.5*0.5*(size.x+size.y)+50})
	
	var chest_rotation: float
	var rect: Rect2
	
	var dirs := []
	if position.y + size.y < generator.scale.y:
		dirs.append(0)
	if position.y > 0:
		dirs.append(1)
	if position.x + size.x < generator.scale.x:
		dirs.append(2)
	if position.x > 0:
		dirs.append(3)
	
	match dirs[rng.randi() % dirs.size()]:
		0:
			var pos := get_center() + Vector2(0, size.y * 0.45)
			generator.create_object("Object", "Stone Gate", pos, {items = key})
			rect = Rect2(pos, Vector2()).grow_individual(50, 60, 50, 60)
		1:
			var pos := get_center() + Vector2(0, -size.y * 0.45)
			generator.create_object("Object", "Stone Gate", pos, {items = key})
			rect = Rect2(pos, Vector2()).grow_individual(50, 60, 50, 60)
			chest_rotation = -PI
		2:
			var pos := get_center() + Vector2(size.x * 0.45, 0)
			generator.create_object("Object", "Stone Gate", pos, {items = key}, PI / 2)
			rect = Rect2(pos, Vector2()).grow_individual(60, 50, 60, 50)
			chest_rotation = -PI / 2
		3:
			var pos := get_center() + Vector2(-size.x * 0.45, 0)
			generator.create_object("Object", "Stone Gate", pos, {items = key}, PI / 2)
			rect = Rect2(pos, Vector2()).grow_individual(60, 50, 60, 50)
			chest_rotation = PI / 2
	
	var treasure = load("res://Scripts/TreasureGenerator.gd").new().generate_treasure(power * owner.item_multiplier, rng, {super_value = true})
	var chest = generator.create_object("Object", "Chest", get_center(), {items = treasure}, chest_rotation)
	generator.add_required_items(key, get_center(), [chest])
	
	var img = preload("res://Resources/Textures/1px.png").get_data()
#	$"%NotPixelMap".update_material_mask_rotated(rect.get_center(),img,Const.Materials.EMPTY,Vector3(rect.size.x, rect.size.y, 0),~(1<<Const.Materials.LUMEN),-1,false)
	$"%NotPixelMap".update_damage_circle(rect.get_center(),max(rect.size.x, rect.size.y)*0.5,10000000,1000,255,~(1<<Const.Materials.LUMEN))
	#$"%NotPixelMap".update_material_circle(rect.get_center(),max(rect.size.x, rect.size.y)*0.5,Const.Materials.EMPTY,~(1<<Const.Materials.LUMEN),false)
