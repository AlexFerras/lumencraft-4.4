@tool
extends "res://Nodes/Map/Generator/rect_generator.gd"

func place_objects_impl(whatever):
	if not whatever:
		return
	
	var generator = $"%GeneratedMapBase"
	generator.current_object_rect = null
	var mine_local_pos= Vector2(size.x*0.5, size.x*0.5)
	
	var dict: Dictionary
	if owner.endless:
		dict= {metal_count=99_999_999}
	else:
		dict= {metal_count=1.0*snapped(1000+generator.get_distance_from_reactor(position+mine_local_pos)*randf_range(0.5,1.5),50)}
	generator.create_object("Object", "Metal Vein",position+mine_local_pos,dict)
	var blob=load("res://Resources/Textures/blob_mask128.png").get_data()
	$"%NotPixelMap".update_material_mask_rotated(position+mine_local_pos+Vector2(50,0),blob,get_suggested_metal_material(position+size*0.5),Vector3(1.0,1.0,randf()*TAU),1<<Const.Materials.ROCK,-1,true)
