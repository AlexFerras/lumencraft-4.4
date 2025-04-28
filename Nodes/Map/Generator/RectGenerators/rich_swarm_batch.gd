@tool
extends "res://Nodes/Map/Generator/rect_generator.gd"

func place_objects_impl(whatever):
	if not whatever:
		return
	
	var generator = $"%GeneratedMapBase"
	var pixel_map = $"%NotPixelMap"
#	13 = 1
#	12 = 2
#	11 = 4
#	10 = 8
	var rect = Rect2(position, size)
	#var empty_rects=pixel_map.getEmptyRegions(10,rect)

	generator.create_object("Object", "Light3D", rect.get_center(), {color = Color(0.8,0.1,0.4), radius=0.5*0.5*(size.x+size.y)+50})
	
	var possible = utils.HexPoints.get_hex_arranged_points_in_rectangle(rect, 8)
	possible.shuffle()
	
	var to_place: int = (5+50 * generator.get_distance_from_reactor_normalized(rect.position + rect.size / 2)) * owner.enemy_multiplier
	for i in possible.size():
		var point: Vector2 = possible[i]
		if pixel_map.isCircleEmpty(point, 5, utils.walkable_collision_mask):
			generator.spawn_swarm_in_position(point,"Lumen Spider Swarm",10)
			
			to_place -= 1
		
		if to_place == 0:
			break
