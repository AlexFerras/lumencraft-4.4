extends RefCounted

var map_file: MapFile

signal map_generated

func generate():
	map_file = MapFile.new()
	
	var terrain_generator = preload("res://Nodes/Map/Generator/AdvancedTerrainGenerator.gd").new()
	terrain_generator.generate(Vector2(4, 4), 20)
	terrain_generator.bake_terrain(Const.Materials.CLAY)
	
	await terrain_generator.bake_finished
	
#	terrain_generator.final_texture.get_data().save_png("generated.png")
	map_file.pixel_data = terrain_generator.final_texture.get_data()
	
	var floor_data := Image.new()
	floor_data.create(1024, 1024, false, Image.FORMAT_RGBA8)
	floor_data.fill(Color.RED)
	map_file.floor_data = floor_data
	
	floor_data = Image.new()
	floor_data.create(1024, 1024, false, Image.FORMAT_RGBA8)
	floor_data.fill(Color(0, 0, 0, 0))
	map_file.floor_data2 = floor_data
	
	map_file.terrain_config = Const.game_data.DEFAULT_TERRAIN_CONFIG.DEFAULT_TERRAIN_CONFIG
	
	var start_point = preload("res://Nodes/Editor/Buildings/EditorReactor.gd").new()
	start_point.object_name = "Reactor"
	start_point.object_type = "Building"
	start_point.init_data({})
	start_point.position = terrain_generator.pieces.front().get_center()
	map_file.objects.append(start_point.get_dict())
	
	for i in 100:
		var enemy = preload("res://Nodes/Editor/Enemies/EditorEnemy.gd").new()
		enemy.object_name = "Pider"
		enemy.object_type = "Enemy"
		enemy.init_data({})
		var piece = terrain_generator.pieces[randi() % terrain_generator.pieces.size()]
		enemy.position = piece.get_center() + Utils.random_point_in_circle(100)
		map_file.objects.append(enemy.get_dict())
	
	emit_signal("map_generated")
