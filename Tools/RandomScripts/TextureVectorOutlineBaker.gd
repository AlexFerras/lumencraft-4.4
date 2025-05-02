@tool
extends EditorScript

func _run() -> void:
	bake_scene(get_scene())

func bake_scene(scene: Node):
	var sprite: Sprite2D = scene.get_node_or_null("Sprite2D")
	if not sprite:
		sprite = scene as Sprite2D
	
	var texture := sprite.texture
	var scale := sprite.scale as Vector2
	
	var mask := PackedVector2Array()
	var image := texture.get_data()
	if image.is_compressed():
		image.decompress()
	false # image.lock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
	
	var scaled_size := texture.get_size() * scale
	for y in int(scaled_size.y):
		for x in int(scaled_size.x):
			if image.get_pixelv(Vector2(x, y) / scale).a > 0.5:
				mask.append(Vector2(x, y) + sprite.position - scaled_size * 0.5)
	
	var file := ConfigFile.new()
	file.set_value("mask", "data", mask)
	file.save(str("res://Nodes/Buildings/Common/Masks/", texture.resource_path.get_file(), ".cfg"))
