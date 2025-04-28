extends Node2D

@export var forced_seed := -1
@export var map_size := 4096
@export var map_biome := -1
@export var objective := -1
@export var wave_count := 30

@export var enemy_multiplier := 1.0
@export var wave_multiplier := 1.0
@export var wave_time_multiplier := 1.0
@export var item_multiplier := 1.0
@export var objective_difficulty := 1.0
@export var resource_rate := 1.0
@export var starting_resources := 0
@export var endless := false

var static_treasure

var map_file: MapFile

signal external_configure(map)
signal finished
signal status

func _ready() -> void:
	static_treasure = preload("res://Scripts/TreasureGenerator.gd")
	if Music.is_switch_build():
		map_size = min(map_size, 3328)
	
	hide()
	$"%GeneratedMapBase".scale = Vector2.ONE * map_size
	
	await send_status("Generating seed").completed
	
	var seeed := forced_seed
	if seeed == -1:
		seeed = randi()
	
	var map_info := str(map_size, wave_count, "/",
		"%02d" % (objective + 1),
		"%02d" % int(enemy_multiplier * 10),
		"%02d" % int(wave_multiplier * 10),
		"%02d" % int(wave_time_multiplier * 10),
		"%02d" % int(item_multiplier * 10),
		"%03d" % int(objective_difficulty * 20),
		"%02d" % int(resource_rate * 10),
		"%02d" % int(map_biome + 1),
		"%04d" % int(starting_resources),
		"/", seeed)
	print("Generating map: " + map_info)
	
	seed(seeed)
	$"%GeneratedMapBase".my_seed = seeed
	
	if map_biome == -1:
		if Utils.get_meta("extra_biomes", false):
			var rng = RandomNumberGenerator.new()
			rng.seed = seeed
			map_biome = rng.randi() % 4
		else:
			map_biome = randi() % 2
	
	if map_biome > 0:
		$"%GeneratedMapBase".soft_material = Const.Materials.SANDSTONE
		$"%GeneratedMapBase".hard_material = Const.Materials.GRANITE
	else:
		$"%GeneratedMapBase".soft_material = Const.Materials.DIRT
		$"%GeneratedMapBase".hard_material = Const.Materials.CLAY
	
	await send_status("Generating tunnels").completed
	
	$"%caves_gen".my_seed = seeed
	
	await send_status("Generating base terrain").completed
	
	$"%GeneratedMapBase".render = true
	await $"%GeneratedMapBase".render_done
	
	await send_status("Creating pixels").completed
	
	$"%GeneratedMapBase".create_pixelmap = true
	
	await send_status("Generating areas of interest").completed
	
	$"%GeneratedMapBase".generate_rects = true
	
	await send_status("Applying area pixels").completed
	
	$"%GeneratedMapBase".render_rects_pixelmap = true
	await $"%GeneratedMapBase".pass_finished
	
	await send_status("Creating map file").completed
	
	map_file = MapFile.new()

	# config
	
	await send_status("Configuring map").completed
	
	var biome = ["Cave", "Tundra", "Desert", "Forest"][map_biome]
	biome = load("res://Nodes/Map/Generator/Biomes/%s.tres" % biome)
#	biome = load("res://Nodes/Map/Generator/Biomes/Desert.tres")
	
	map_file.map_name = "Random Map <%s>" % map_info
	map_file.terrain_config = Const.game_data.DEFAULT_TERRAIN_CONFIG.duplicate()
	map_file.terrain_config.lower_floor = biome.lower_floor_textures
	map_file.terrain_config.upper_floor = biome.upper_floor_textures
	map_file.terrain_config.terrain[4] = biome.soft_wall_material
	map_file.terrain_config.terrain[5] = biome.hard_wall_material
	map_file.terrain_config.alt_floor = true
	map_file.start_config = {inventory = [], technology = {}, upgrades = {}, weapon_upgrades = {}, disabled_buildings = []}
	map_file.darkness_color = Color(0.3,0.1,0.7)
	map_file.start_config.stats = {clones=3}
	map_file.enable_fog = true
	map_file.resource_rate = resource_rate
	
	# objects
	
	await send_status("Creating objects").completed
	
	$"%GeneratedMapBase".map_file = map_file
	$"%GeneratedMapBase".create_objects = true
	
	for i in $"%swarm_batchs".get_children():
		map_file.objects.append({type = "Custom", name = "Swarm Scene", scene = i.filename, data = i.getUnitsStateBinaryData()})
	
	var terrain := Image.new()
	terrain.create_from_data(map_size, map_size, false, Image.FORMAT_RGBA8, $"%NotPixelMap".get_pixel_data())
	map_file.pixel_data = terrain
	
	# waves/objective
	
	await send_status("Creating objective").completed
	
	generate_objective()
	
	await send_status("Randomizing waves").completed
	
	var spawners: int
	for object in map_file.objects:
		if object.name == "Wave Spawner":
			spawners += 1
	
	if objective == 0:
		wave_count = max(wave_count, 1)
	
	if endless:
		wave_count = 99
	
	if wave_count > 0:
		var waves_gen = CustomizableWavesGenerator.new()
		waves_gen.set_default_waves_ememies(wave_time_multiplier, wave_multiplier)
		map_file.wave_data = waves_gen.generate_map_waves(seeed, spawners, wave_count, wave_multiplier, true)
	
	if endless:
		var last_wave: Dictionary = map_file.wave_data[map_file.wave_data.size() - 1]
		last_wave.repeat = -1
		last_wave.multiplier = 1.01
	
	# floor
	
	await send_status("Generating floor").completed
	
	var baker = preload("res://Scripts/TextureBaker.gd").create(Vector2(1024, 1024))
	baker.add_target(preload("res://Nodes/Map/Generator/Floor1_generator.tscn").instantiate())
	
	await baker.finished
	
	map_file.floor_data = baker.texture.get_data()
	
	baker = preload("res://Scripts/TextureBaker.gd").create(Vector2(1024, 1024))
	baker.add_target(preload("res://Nodes/Map/Generator/Floor2_generator.tscn").instantiate())
	
	await baker.finished
	
	map_file.floor_data2 = baker.texture.get_data()
	
	#CLEAR ALPHA FOR BLOOD
	
	map_file.floor_data2.convert(Image.FORMAT_RGBA8)
	
	var image_data=map_file.floor_data2.get_data()
	var i =3
	while i< image_data.size():
		image_data[i]=0
		i+=4
	
	map_file.floor_data2.create_from_data(map_file.floor_data2.get_width(),map_file.floor_data2.get_height(),false,Image.FORMAT_RGBA8,image_data)
	emit_signal("external_configure", map_file)
	
	randomize()
	emit_signal("finished")

func generate_objective():
	var pixel_map: PixelMap = $"%NotPixelMap"
	var generator = $"%GeneratedMapBase"
	var rng: RandomNumberGenerator = generator.rng
	
	if objective == -1:
		objective = rng.randi_range(0, 5)
	
	if endless:
		objective = 6
	
	match objective:
		0: # survive waves
			if Save.campaign:
				map_file.objective_data.win = {type = "waves"}
				map_file.objective_data.auto_finish = true
				return
			
			map_file.objective_data.win = {type = "custom", message = tr("Survive %d waves") % wave_count}
			
			map_file.events.append({
				conditions = [{
					id = -1,
					type = "wave_defeated",
					data = {number = wave_count},
				}],
				actions = [{
					id = -1,
					type = "win",
					data = {instant = false},
				}],
				any = false
			})
		1: # collect resource
			var res := rng.randi() % Const.RESOURCE_COUNT
			var total := 0
			
			var histogram := pixel_map.get_materials_histogram()
			match res:
				Const.ItemIDs.METAL_SCRAP:
					total += histogram[Const.Materials.WEAK_SCRAP] / Const.ResourceSpawnRate[Const.Materials.WEAK_SCRAP] * resource_rate
					total += histogram[Const.Materials.STRONG_SCRAP] / Const.ResourceSpawnRate[Const.Materials.STRONG_SCRAP] * resource_rate
					total += histogram[Const.Materials.ULTRA_SCRAP] / Const.ResourceSpawnRate[Const.Materials.ULTRA_SCRAP] * resource_rate
				Const.ItemIDs.LUMEN:
					total += histogram[Const.Materials.LUMEN] / Const.ResourceSpawnRate[Const.Materials.LUMEN] * resource_rate
			
			var needed: int = total * objective_difficulty * 0.2 * (0.7 + randf() * 0.1)
			map_file.objective_data.win = {type = "item", id = res, amount = needed}
		2: # collect item
			var type := rng.randi() % Const.ARTIFACT_NAMES.size()
			var needed := rng.randi_range(1, int(4 * (objective_difficulty + 0.3)))
			map_file.objective_data.win = {type = "item", id = Const.ItemIDs.ARTIFACT, data = type, amount = needed}
			
			var possible_containers: Array = generator.item_containers.duplicate()
			generator.sort_position = $"%caves_gen".get_reactor_position()
			possible_containers.sort_custom(Callable(generator, "sort_by_distance"))
			possible_containers.invert()
			
			while needed > 0:
				for container in possible_containers:
					if rng.randi() % 5 == 1:
						container.data.items.append({id = "ARTIFACT", data = type, amount = 1})
						needed -= 1
					
					if needed == 0:
						break
		3: # reach destination
			map_file.objective_data.win = {type = "finish", goal_type = 0}
			
			var empty := pixel_map.getEmptyRegions(9)
			generator.sort_position = $"%caves_gen".get_reactor_position()
			empty.sort_custom(Callable(generator, "sort_by_distance_of_center"))
			empty.invert()
			
			for space in empty:
				if rng.randi() % int(6 - objective_difficulty) == 1:
					generator.create_object("Object", "Goal Point", space.get_center())
					break
		4: # kill enemy
#			var enemies: Array
			var possible: Array
			
			for object in map_file.objects:
				if object.type == "Enemy" and object.name in Const.BOSS_ENEMIES:
					possible.append(object.name)
#					enemies.append(object)
#			
#			generator.sort_position = $"%caves_gen".get_reactor_position() # <- to jest fajne dla zabijania konkretnego wroga
#			enemies.sort_custom(generator, "sort_by_distance_of_center")
#			enemies.invert()
			
			var enemy: String = possible[rng.randi() % possible.size()]
			map_file.objective_data.win = {type = "enemy", target_enemy = enemy, amount = rng.randi_range(1, min(possible.count(enemy), int(3 + objective_difficulty)))}
		5: # get crystal
			map_file.objective_data.win = {type = "custom", message = "Deliver a Lumen Chunk to the reactor."}
			map_file.start_config.inventory.append({id = "HOOK", amount = 1})
			
			var reactor_idx: int
			for object in map_file.objects:
				if object.name == "Reactor":
					object.data.chunk_slots = 1
					break
				
				reactor_idx += 1
			
			map_file.events.append({
				conditions = [{
					id = reactor_idx,
					type = "lumen_chunk_delivered",
				}],
				actions = [{
					id = -1,
					type = "win",
					data = {instant = false},
				}],
				any = false
			})
			
			var empty := pixel_map.getEmptyRegions(9)
			generator.sort_position = $"%caves_gen".get_reactor_position()
			empty.sort_custom(Callable(generator, "sort_by_distance_of_center"))
			empty.invert()
			
			var placed: bool
			for space in empty:
				if rng.randi() % int(6 - objective_difficulty) == 1:
					placed = true
					generator.create_object("Object", "Lumen Chunk", space.get_center(), {marker_radius = 200 * objective_difficulty})
					break
			
			if not placed:
				var space = empty.front()
				generator.create_object("Object", "Lumen Chunk", space.get_center(), {marker_radius = 200 * objective_difficulty})
		6:
			map_file.objective_data.win = {type = "none"}

func send_status(status: String):
	emit_signal("status", status)
	await get_tree().idle_frame
