@tool
extends "res://Nodes/Map/Generator/rect_generator.gd"

@export var mine_metal_count_power=1.0

func rect_placed_randomizer():
	
	var generator = $"%GeneratedMapBase"
	var metal_type= get_suggested_metal_material(position+size*0.5)
	$"preview/mine_in_metal".material_type=metal_type



func place_objects_impl(whatever):
	if not whatever:
		return
	
	var objects=get_node_or_null("Objects")
	if !objects:
		objects=Node2D.new()
		objects.name="Objects"
		add_child(objects)
		objects.owner=owner
	
	for node in objects.get_children():
		node.queue_free()
	
	var generator = $"%GeneratedMapBase"
	generator.current_object_rect = null
	var mine_local_pos= Vector2(randf_range(size.x*0.25, size.x*0.65), randf_range(0.25*size.y, 0.75*size.y))
	
	var dict: Dictionary
	if owner.endless:
		dict= {metal_count=99_999_999}
	else:
		dict= {metal_count=mine_metal_count_power*snapped(200+generator.get_distance_from_reactor(position+mine_local_pos)*randf_range(0.5,1.5),50)}
	generator.create_object("Object", "Metal Vein",position+mine_local_pos,dict)
	var blob=load("res://Resources/Textures/blob_mask128.png").get_data()
	$"%NotPixelMap".update_material_mask_rotated(position+mine_local_pos+Vector2(50,0),blob,get_suggested_metal_material(position+size*0.5),Vector3(1.0,1.0,randf()*TAU),1<<Const.Materials.ROCK,-1,true)
