@tool
extends "res://Nodes/Map/Generator/rect_generator.gd"

func place_objects_impl(whatever):
	if not whatever:
		return
	
	var generator = $"%GeneratedMapBase"
	generator.create_object("Object", "Light3D", Rect2(position,size).get_center(), {color = Color(0.6,0.0,0.1), radius=0.5*0.5*(size.x+size.y)+50})
	generator.create_object("Object", "Wave Spawner", position + size*0.5, {radius=min(size.x,size.y)*0.75*0.5})
#	var pixel_map = $"%NotPixelMap"
#	var rect = Rect2(position, size)
#	var possible = utils.HexPoints.get_hex_arranged_points_in_rectangle(rect, 15)
#	possible.shuffle()
#
#	for i in possible.size():
#		var point: Vector2 = possible[i]
#		if pixel_map.isCircleEmpty(point, 150, utils.walkable_collision_mask):
#			generator.create_object("Object", "Wave Spawner", point)
#			break
