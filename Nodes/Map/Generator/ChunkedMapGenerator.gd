@tool
extends RefCounted

enum { PLACE_RANDOM, PLACE_NEIGHBOR, PLACE_MAX }
enum { OBJECTIVE_WAVES, OBJECTIVE_GOAL, OBJECTIVE_MAX }

const OBJECTIVE_SCRIPT = preload("res://Nodes/Map/CustomObjective.gd")

const CHUNK_GENERATORS = []

var map_file: MapFile
var rng := RandomNumberGenerator.new()

var map_size: Vector2 = Vector2(2048, 2048)
var placed_generators: Dictionary
var raw_terrain: Texture2D
var soft_material: int

var has_reactor: bool
var need_goal: int

signal terrain_generated
signal map_generated

func _init() -> void:
	if not CHUNK_GENERATORS.is_empty():
		return
	
#	register_generator(load("res://Nodes/Map/Generator/ChunkGenerators/NoiseChunk.tscn"), Vector2(128, 128), Vector2(512, 512))
	register_generator(load("res://Nodes/Map/Generator/ChunkGenerators/BlobChunk.tscn"), Vector2(128, 128), Vector2(512, 512))
	register_generator(load("res://Nodes/Map/Generator/ChunkGenerators/TunnelChunk.tscn"), Vector2(100, 100), Vector2(768, 768))
#	register_generator(load("res://Nodes/Map/Generator/ChunkGenerators/WhiteBlob.tscn"), Vector2(100, 100), Vector2(768, 768))

func generate():
	map_file = MapFile.new()
	map_file.terrain_config = Const.game_data.DEFAULT_TERRAIN_CONFIG.duplicate()
	
	rng.seed = randi()
	seed(rng.seed) ## ;_;
	map_file.map_name = "Random Map <seed %s>" % rng.seed
	print("Generator seed: ", rng.seed)
	
	var biome = [load("res://Nodes/Map/Generator/Biomes/Cave.tres"), load("res://Nodes/Map/Generator/Biomes/Desert.tres"), load("res://Nodes/Map/Generator/Biomes/Forest.tres"), load("res://Nodes/Map/Generator/Biomes/Tundra.tres")][rng.randi() % 4]
	set_biome(biome)
	
	var pixel_map: PixelMap
	generate_terrain()
	await self.terrain_generated
	
	var zero_pass := raw_terrain
	
	remove_white(raw_terrain)
	await self.terrain_generated
	
	var first_pass:Image = raw_terrain.get_image()
	
	# Second pass.
	
	print("Second pass generation")
	
	pixel_map = PixelMap.new()
	pixel_map.hide()
	pixel_map.set_pixel_data(first_pass.get_data(), first_pass.get_size())
	Utils.add_child(pixel_map)

	await Utils.get_tree().process_frame
	await Utils.get_tree().process_frame

	var rectangles: Array = pixel_map.getEmptyRegions(6, ~(1 << Const.Materials.DIRT | 1 << Const.Materials.LUMEN | 1 << Const.Materials.WEAK_SCRAP | 1 << Const.SwappableMaterials[0]), true)
	pixel_map.free()
	
	generate_terrain(rectangles)
	await self.terrain_generated
	
	remove_black(raw_terrain)
	await self.terrain_generated
	
	var baker = preload("res://Scripts/TextureBaker.gd").create(map_size)
	baker.add_target(zero_pass, Vector2())
	baker.add_target(raw_terrain, Vector2())
	await baker.finished
	
	remove_white(baker.texture)
	await self.terrain_generated
	
	# Final texture + floors.
	
	map_file.pixel_data = raw_terrain.get_data()
	
	baker = preload("res://Scripts/TextureBaker.gd").create(Vector2(1024, 1024))
	baker.add_target(preload("res://Nodes/Map/Generator/Floor1_generator.tscn").instantiate())
	
	await baker.finished
	
	map_file.floor_data = baker.texture.get_data()
#	map_file.floor_data.save_png("dupa.png")
	
	print("Creating floor")
	
	baker = preload("res://Scripts/TextureBaker.gd").create(Vector2(1024, 1024))
	baker.add_target(preload("res://Nodes/Map/Generator/Floor2_generator.tscn").instantiate())
	
	await baker.finished
	
	map_file.floor_data2 = baker.texture.get_data()
	
	pixel_map = PixelMap.new()
	pixel_map.hide()
	pixel_map.set_pixel_data(map_file.pixel_data.get_data(), map_file.pixel_data.get_size())
	Utils.add_child(pixel_map)
	
	await Utils.get_tree().process_frame
	await Utils.get_tree().process_frame
	
	print("Placing objects")
	
	generate_objective()
	
	for map_rect in placed_generators.values():
		for generator in map_rect.values():
			map_file.objects.append_array(generator.create_content(self, pixel_map))
			generator.free()
	
	pixel_map.queue_free()
	
	map_file.terrain_config.alt_floor = true
	map_file.start_config = {inventory = [{id = ("MAGNUM" if rng.randi() % 2 == 0 else "MACHINE_GUN"), amount = 1}, {id = "AMMO", amount = rng.randi_range(50, 150), data = Const.Ammo.BULLETS}], technology = {}}
	
	emit_signal("map_generated")
	
	randomize() ## ;___;

func generate_terrain(available_rectangles := []):
	if available_rectangles.is_empty():
		available_rectangles = [Rect2(Vector2(), map_size)]
	
	print_in_editor("Starting generation")
	if not has_reactor:
		var reactor_generator = load("res://Nodes/Map/Generator/ChunkGenerators/ReactorChunk.tscn").instantiate()
		reactor_generator.rng = rng
		place_generator(available_rectangles, reactor_generator, {min_size = Vector2(256, 256), max_size = Vector2(256, 256)})
		has_reactor = true
	
	var fails: int
	while fails < 30:
		var generator_data: Dictionary = CHUNK_GENERATORS[rng.randi() % CHUNK_GENERATORS.size()]
		
		var generator: CanvasItem
		if generator_data.generator is Script:
			generator = generator_data.generator.new()
		elif generator_data.generator is PackedScene:
			generator = generator_data.generator.instantiate()
		generator.rng = rng
		
		if not place_generator(available_rectangles, generator, generator_data):
			fails += 1
	
	for available_rect in available_rectangles:
		for rect in placed_generators.get(available_rect, []):
			placed_generators[available_rect][rect].generate(rect.size)
	
	var all_ready: bool
	while not all_ready:
		all_ready = true
		
		for generators in placed_generators.values():
			for generator in generators.values():
				if not generator.ready:
					all_ready = false
					break
		
		if not all_ready:
			await Const.get_tree().process_frame
	
	var baker = preload("res://Scripts/TextureBaker.gd").create(map_size)
	var terrain = ColorRect.new()
	terrain.color = Color.BLACK
	terrain.size = map_size
	baker.add_target(terrain)
	
	for available_rect in available_rectangles:
		for rect in placed_generators.get(available_rect, []):
			baker.add_target(placed_generators[available_rect][rect], rect.position, true)
			placed_generators[available_rect][rect].propagate_call("set_texture", [null])
	
	await baker.finished
	
	raw_terrain = baker.texture
	emit_signal("terrain_generated")

func place_generator(available_rectangles: Array, generator: CanvasItem, data: Dictionary) -> bool:
	var available_rect: Rect2 = available_rectangles[rng.randi() % available_rectangles.size()]
	if not available_rect in placed_generators:
		placed_generators[available_rect] = {}
	
	var rect: Rect2
	rect.size = Vector2(rng.randi_range(data.min_size.x, min(data.max_size.x, available_rect.size.x)), rng.randi_range(data.min_size.y, min(data.max_size.y, available_rect.size.y)))
	
	var can_place: bool
	
	for i in 10:
		for j in 100:
			rect.position = randomize_rect(available_rect, rect)
			if not available_rect.encloses(rect):
				continue
			
			var ok := true
			
			for rect2 in placed_generators[available_rect]:
				if rect.intersects(rect2):
					ok = false
			
			if ok:
				can_place = true
				break
		
		if can_place:
			break
		elif rect.size.x >= data.min_size.x + 10 and rect.size.y >= data.min_size.y + 10:
			rect = rect.grow(-10)
		
		available_rect = available_rectangles[rng.randi() % available_rectangles.size()]
		rect.size = Vector2(rng.randi_range(data.min_size.x, min(data.max_size.x, available_rect.size.x)), rng.randi_range(data.min_size.y, min(data.max_size.y, available_rect.size.y)))
		if not available_rect in placed_generators:
			placed_generators[available_rect] = {}
	
	if not can_place:
		return false
	
	placed_generators[available_rect][rect] = generator
	
	return true

func register_generator(generator: Object, min_size: Vector2, max_size: Vector2):
	assert(generator is PackedScene or generator is Script)
	CHUNK_GENERATORS.append({generator = generator, min_size = min_size, max_size = max_size})

func randomize_rect(available_rect: Rect2, rect: Rect2) -> Vector2:
	var position: Vector2
	
	var placement := rng.randi() % PLACE_MAX
	if placement == PLACE_NEIGHBOR and placed_generators[available_rect].is_empty():
		placement = PLACE_RANDOM
	
	match placement:
		PLACE_RANDOM:
			position.x = rng.randi_range(available_rect.position.x, available_rect.position.x + available_rect.size.x - rect.size.x)
			position.y = rng.randi_range(available_rect.position.y, available_rect.position.y + available_rect.size.y - rect.size.y)
		PLACE_NEIGHBOR:
			var neighbor: Rect2 = placed_generators[available_rect].keys()[rng.randi() % placed_generators[available_rect].size()]
			var side := rng.randi() % 4
			
			match side:
				0:
					position.x = neighbor.position.x + rng.randi_range(-rect.size.x, neighbor.size.x)
					position.y = neighbor.position.y - rect.size.y
				1:
					position.x = neighbor.position.x + rng.randi_range(-rect.size.x, neighbor.size.x)
					position.y = neighbor.position.y + neighbor.size.y
				2:
					position.x = neighbor.position.x - rect.size.x
					position.y = neighbor.position.y + rng.randi_range(-rect.size.y, neighbor.size.y)
				3:
					position.x = neighbor.position.x + neighbor.size.x
					position.y = neighbor.position.y + rng.randi_range(-rect.size.y, neighbor.size.y)
	
	return position

func generate_objective():
	var objective: int = OBJECTIVE_GOAL#rng.randi() % OBJECTIVE_MAX
	
	match objective:
		OBJECTIVE_GOAL:
			need_goal = rng.randi_range(1, 4)
			map_file.objective_data.win = {type = "finish", goal_type = OBJECTIVE_SCRIPT.GoalType.ANY if need_goal == 1 else OBJECTIVE_SCRIPT.GoalType.ALL}

func print_in_editor(message: String):
	if Engine.is_editor_hint():
		print(message)

func set_biome(biome: Resource):
	var mat = Const.Materials.keys().find(biome.soft_wall_material)
	if mat > -1:
		soft_material = mat
	else:
		soft_material = Const.SwappableMaterials[0]
		map_file.terrain_config.terrain[0] = biome.soft_wall_material
	
	map_file.terrain_config.lower_floor = biome.lower_floor_textures
	map_file.terrain_config.upper_floor = biome.upper_floor_textures

func remove_white(texture: Texture2D):
	var second_pass := TextureRect.new()
	second_pass.texture = texture
	second_pass.modulate = Color.RED
	second_pass.modulate.g8 = soft_material
	second_pass.material = preload("res://Nodes/Map/Generator/RemoveWhite.material")
	
	var baker = preload("res://Scripts/TextureBaker.gd").create(map_size)
	baker.add_target(second_pass)
	
	await baker.finished
	
	raw_terrain = baker.texture
	emit_signal("terrain_generated")

func remove_black(texture: Texture2D):
	var second_pass := TextureRect.new()
	second_pass.texture = texture
	second_pass.modulate = Color.RED
	second_pass.modulate.g8 = soft_material
	second_pass.material = preload("res://Nodes/Map/Generator/RemoveBlack.material")
	
	var baker = preload("res://Scripts/TextureBaker.gd").create(map_size)
	baker.add_target(second_pass)
	
	await baker.finished
	
	raw_terrain = baker.texture
	emit_signal("terrain_generated")
