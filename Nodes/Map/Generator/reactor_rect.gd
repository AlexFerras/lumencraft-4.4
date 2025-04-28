@tool
extends "res://Nodes/Map/Generator/rect_generator.gd"

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
	generator.current_object_rect =null
	
	generator.create_object("Building", "Reactor",  position + size*0.5, {radius= 150})
	
	var storage_pos: Vector2
	if owner.starting_resources > 0:
		storage_pos = position + size * 0.5 + Vector2.RIGHT * 108
		generator.create_object("Building", "Storage Container", storage_pos, {lumen = owner.starting_resources, scrap = owner.starting_resources})
	
	var data={items = [{id = Const.ItemIDs.MAGNUM, amount=1},{id = Const.ItemIDs.AMMO, data=Const.Ammo.BULLETS, amount=200}]}
	
	var chest_pos: Vector2
	for i in 1000:
		chest_pos = position + size * 0.5 + Vector2(0, 120).rotated(randf() * TAU)
		
		if storage_pos == Vector2() or chest_pos.distance_squared_to(storage_pos) > 900.0:
			break
	
	generator.create_object("Object", "Chest", chest_pos, data)
