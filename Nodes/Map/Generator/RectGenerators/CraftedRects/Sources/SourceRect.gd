@tool
extends Node2D

@export var export_data: bool: set = export_data_impl

func export_data_impl(e):
	if not e:
		return
	
	var scene_name = scene_file_path.get_file().get_basename()
	var pixel_map = $PixelMap
	var pixel_data = pixel_map.get_pixel_data()
	for i in pixel_data.size() / 4:
		var j: int = i * 4
		
		if pixel_data[j + 3] == 0:
			pixel_data[j] = 255
			pixel_data[j + 1] = 255
			pixel_data[j + 2] = 255
			pixel_data[j + 3] = 255
		else:
			pixel_data[j + 0] = 0
			pixel_data[j + 1] = 0
			pixel_data[j + 2] = 0
			pixel_data[j + 3] = 0
	
	var pixel_image = Image.new()
	pixel_image.create_from_data(pixel_map.get_texture().get_width(), pixel_map.get_texture().get_height(), false, Image.FORMAT_RGBA8, pixel_data)
	
	var f = FileAccess.open("res://Nodes/Map/Generator/RectGenerators/CraftedRects/" + scene_name + "_pixels.bin", FileAccess.WRITE)
	f.store_var(pixel_image, true)
	f.close()
	
	remove_child(pixel_map)
	
	var ps := PackedScene.new()
	ps.pack(self)
	
	f = FileAccess.open("res://Nodes/Map/Generator/RectGenerators/CraftedRects/" + scene_name + "_nodes.bin", FileAccess.WRITE)
	f.store_var(ps, true)
	f.close()
	
	add_child(pixel_map)
	move_child(pixel_map, 0)
	print("Export successful!")
