@tool
extends "res://Nodes/Map/Generator/rect_generator.gd"

@export var lava_source_id=0: set = set_lava_source_id
@export var lava_radius=0




func rect_placed_randomizer():
	pass

func set_lava_source_id(new_id):
	if !is_inside_tree():
		return
	lava_source_id=new_id

	$preview/lava_source_lava.blue_channel=new_id+1
	$preview/lava.blue_channel=new_id+1





func place_objects_impl(whatever):
	if not whatever:
		return

	var generator = $"%GeneratedMapBase"
	generator.current_object_rect =null

	var source_position = Rect2(position, size).get_center()
	generator.create_object("Object", "Lava Source",  source_position, {radius= lava_radius, id=lava_source_id})
	
	var pixel_map = $"%NotPixelMap"
	var rng: RandomNumberGenerator = generator.rng
	
	var power = generator.get_distance_from_reactor(source_position)
	
	
	
	var treasure = load("res://Scripts/TreasureGenerator.gd").new().generate_treasure(3000 * owner.item_multiplier, rng)

	generator.create_object("Object", "Chest" if Engine.is_editor_hint() else "Chest", source_position+Vector2(10,0).rotated(rng.randf() * TAU), {items = treasure}, rng.randf() * TAU)

	
	
	
