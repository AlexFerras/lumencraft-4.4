@tool
extends "res://Nodes/Map/Generator/rect_generator.gd"

@export var rect_list # (Array, String)

var filtered_rects: Array
var picked_rect: String

func set_size(s: Vector2):
	if not has_node(@"preview"):
		return
	
	super.set_size(s)
	$preview/Blob.scale = Vector2.ONE / s
	
	for rect in rect_list:
		var image: Image = Constants.get_crafted_rect(rect).image
		
		if image.get_width() <= s.x and image.get_height() <= s.y:
			filtered_rects.append(rect)

func set_seed(newseed):
	if not has_node(@"preview"):
		return
	
	if filtered_rects.is_empty():
		$preview/Blob.texture = null
		picked_rect = ""
		return
	
	picked_rect = filtered_rects[randi() % filtered_rects.size()]
	$preview/Blob.set_rect(picked_rect)
	
	var image: Image = Constants.get_crafted_rect(picked_rect).image
	$preview/Blob.position = Vector2(randf_range(0, size.x - image.get_width()), randf_range(0, size.y - image.get_height())) * (Vector2.ONE / size)

func place_objects_impl(whatever):
	if not whatever or picked_rect.is_empty():
		return
	
	if Engine.is_editor_hint():
		var node = Constants.get_crafted_rect(picked_rect).scene.instantiate()
		node.position = position + $preview/Blob.position * size
		node.owner = get_tree().edited_scene_root
		$"%Objects".add_child(node)
	else:
		$"%GeneratedMapBase".create_object("Custom", "Crafted Rect", position + $preview/Blob.position * size, {rect = picked_rect})
