extends RefCounted

const VERSION = 4

var pixel_data: Image
var floor_data: Image
var floor_data2: Image
var fog_data: Image
var savegame_data: Dictionary
var map_data: Dictionary

func save_to_file(path: String):
	var file := File.new()
	var open = Utils.safe_open(file, path, File.WRITE)
	assert(open, "Can't open file: " + path)
	
	file.store_32(VERSION)
	
	var pixel_buffer: PackedByteArray
	if pixel_data:
		pixel_buffer = pixel_data.save_png_to_buffer()
		file.store_32(pixel_buffer.size())
		file.store_buffer(pixel_buffer)
	else:
		file.store_32(0)
	
	if floor_data:
		pixel_buffer = floor_data.save_png_to_buffer()
		file.store_32(pixel_buffer.size())
		file.store_buffer(pixel_buffer)
	else:
		file.store_32(0)
	
	if floor_data2:
		pixel_buffer = floor_data2.save_png_to_buffer()
		file.store_32(pixel_buffer.size())
		file.store_buffer(pixel_buffer)
	else:
		file.store_32(0)
	
	if fog_data:
		pixel_buffer = fog_data.save_png_to_buffer()
		file.store_32(pixel_buffer.size())
		file.store_buffer(pixel_buffer)
	else:
		file.store_32(0)
	
	savegame_data.save = Save._get_save_data()
	savegame_data.game = Utils.game._get_save_data()
	savegame_data.achievements = SteamAPI.achievements._get_save_data()
	
	file.store_var(savegame_data, true)
	file.store_var(map_data, true)

	file.close()

func load_from_file(path: String):
	var file := File.new()
	var open = Utils.safe_open(file, path, file.READ)
	assert(open)
	
	var version := file.get_32()
	if version < VERSION:
		upgrade_save(version, file)
	
	var size := file.get_32()
	if size > 0:
		pixel_data = Image.new()
		pixel_data.load_png_from_buffer(file.get_buffer(size))
	
	size = file.get_32()
	if size > 0:
		floor_data = Image.new()
		floor_data.load_png_from_buffer(file.get_buffer(size))
	
	size = file.get_32()
	if size > 0:
		floor_data2 = Image.new()
		floor_data2.load_png_from_buffer(file.get_buffer(size))
	
	size = file.get_32()
	if size > 0:
		fog_data = Image.new()
		fog_data.load_png_from_buffer(file.get_buffer(size))
	
	savegame_data = file.get_var(true)
	map_data = file.get_var(true)
	
	if version < 3: # compat
		savegame_data.save.score = 0
	
	file.close()

func load_metadata(path: String):
	var file := File.new()
	file.open(path, file.READ)
	
	var version := file.get_32()
	
	file.close()

func upgrade_save(from_version: int, file: File):
	if from_version < 3:
		Utils.game.connect("map_pre_instance", Callable(self, "hack_buildings_compat"))

func hack_buildings_compat(map: Map): # compat
	var pixmap: PixelMap = map.get_node("PixelMap")
	await pixmap.ready
	var data := pixmap.get_pixel_data()
	for i in data.size() / 4:
		if data[i * 4 + 1] == Const.Materials.STOP:
			data[i * 4] = 0
			data[i * 4 + 1] = 0
			data[i * 4 + 2] = 0
			data[i * 4 + 3] = 0
	pixmap.set_pixel_data(data, pixmap.get_texture().get_size())

### Deserialize map

var _node_map: Dictionary

func load_map_node(map: Map, node_name: String):
	var data: Dictionary = map_data[node_name]
	var node: Node
	
	if data.has("filename"):
		node = load(data.filename).instantiate()
	else:
		node = ClassDB.instantiate(data.type)
	
	node.name = node_name.get_slice("/", 1)
	
	var parent: Node = map
	for property in data:
		match property:
			"__node_id":
				_node_map[data.__node_id] = node
			"__event_id":
				if data.__event_id > -1:
					map.event_object_list[data.__event_id] = node
			"__parent_id":
				parent = _node_map[data.__parent_id]
			"__parent_path":
				parent = map.get_node(data.__parent_path)
			"__save_data":
				node._set_save_data(data.__save_data)
			"__groups":
				for group in data.__groups:
					node.add_to_group(group)
			_:
				var value = data[property]
				if value is Dictionary:
					if "ResourcePath" in value:
						value = load(value.ResourcePath)
				
				node.set(property, value)
	
	parent.add_child(node)
	node.owner = map

### Serialize map

const SKIP_PROPERTIES = ["script", "material", "process_mode", "_import_path", "process_priority", "show_behind_parent", "light_mask", "use_parent_material", "z_as_relative", "__meta__", "angle"]
const ADDITIONAL_PROPERTIES = ["data", "frame_this_cycle"]
var SKIP_TYPES = ["PixelMap", "Nodes2DTrackerMultiLvl", "WorldEnvironment"]
var SKIP_NODES = []

func fetch_properties() -> void:
	for property in ClassDB.class_get_property_list("Area2D", true):
		SKIP_PROPERTIES.append(property.name)
	
	for property in ClassDB.class_get_property_list("RigidBody2D", true):
		SKIP_PROPERTIES.append(property.name)
	
	for property in ClassDB.class_get_property_list("CollisionObject2D", true):
		SKIP_PROPERTIES.append(property.name)
	
	for property in ClassDB.class_get_property_list("StaticBody2D", true):
		SKIP_PROPERTIES.append(property.name)

var _node_id: int
var _connections: Array
var _map: Map

func store_map(map: Map):
	if Save.is_hub():
		return
	
#	Utils.start_time_tracking("store_map")
	fetch_properties()
#	Utils.print_time_tracking_checkpoint("store_map", "fetch properties")
	_map = map
	
	pixel_data = map.pixel_map.get_texture().get_data()
#	Utils.print_time_tracking_checkpoint("store_map", "pixel map")
	if is_instance_valid(map.floor_surface) and map.floor_surface.get_texture():
		floor_data = map.floor_surface.get_texture().get_data()
	else:
		floor_data = Image.new()
		floor_data.create(1, 1, false, Image.FORMAT_RGBA8)
#	Utils.print_time_tracking_checkpoint("store_map", "floor")
	if is_instance_valid(map.floor_surface2) and map.floor_surface2.get_texture():
		floor_data2 = map.floor_surface2.get_texture().get_data()
	else:
		floor_data2 = Image.new()
		floor_data2.create(1, 1, false, Image.FORMAT_RGBA8)
#	Utils.print_time_tracking_checkpoint("store_map", "floor 2")
	
	if is_instance_valid(map.pixel_map.fog_of_war) and map.pixel_map.fog_of_war.viewport_handle.get_texture():
		fog_data = map.pixel_map.fog_of_war.viewport_handle.get_texture().get_data()
		fog_data.flip_y()
	else:
		fog_data = Image.new()
		fog_data.create(1, 1, false, Image.FORMAT_RGBA8)
#	Utils.print_time_tracking_checkpoint("store_map", "fog")
	
#	Utils.print_time_tracking_checkpoint("store_map", "tracker")
	
	var pickables: Array
	var pickable_ids: PackedInt32Array
	
	for id in map.pickables.get_premium_pickables_in_range(Vector2(), 9999999):
		pickable_ids.append(id)
		pickables.append({type = map.pickables.get_pickable_type(id), position = map.pickables.get_pickable_position(id), velocity = map.pickables.get_pickable_velocity(id), pointed = true})
	
	for id in map.pickables.get_pickables_in_range(Vector2(), 9999999):
		if id in pickable_ids:
			continue
		pickables.append({type = map.pickables.get_pickable_type(id), position = map.pickables.get_pickable_position(id), velocity = map.pickables.get_pickable_velocity(id), pointed = false})
#	Utils.print_time_tracking_checkpoint("store_map", "pickables")
	
#	Utils.push_time_tracking_checkpoint("store_map")
#	map.force_tracker_focus()
	
	var nodes_to_store := map.get_children()
	nodes_to_store.append_array(map.get_tree().get_nodes_in_group("additional_save"))
	nodes_to_store.append_array(map.get_tracker_nodes())
	
	Utils.setup_store_node(self)
	Utils.store_nodes(nodes_to_store, map_data)
	
#	map.store_tracker_nodes(self)
##
#	for node in map.get_children():
#		store_node(node, -1)
#
#	for node in map.get_tree().get_nodes_in_group("additional_save"):
#		store_node(node, -1)
#	Utils.print_time_tracking_checkpoint("store_map", "store nodes")
	
	map.exit_time = Save.game_time
	
	map_data._exit_time = map.exit_time
	if is_instance_valid(map.darkness):
		map_data._darkness_color = map.darkness.ambient_color
	map_data._enable_fow = is_instance_valid(map.pixel_map.fog_of_war) and map.pixel_map.fog_of_war.visible
	map_data._global_swarm_data = map.swarm_manager._get_save_data()
	map_data._connections = _connections
	map_data._pickables = pickables
	map_data._wave_data = Utils.game.map.wave_manager._get_save_data()
#	Utils.print_time_tracking_checkpoint("store_map", "data1")
	
	var dbd = map.pixel_map.get_node_or_null("DarknessByDistance")
	if dbd:
		map_data._darkness_by_distance_data = dbd._get_save_data()
	
	if not Utils.game.building_queue.is_empty() or not map.get_tree().get_nodes_in_group("build_drone").is_empty():
		map_data._building_queue = Utils.game.save_building_queue()
	
	if Utils.game.ui.objective.visible:
		map_data._objective = {text = Utils.game.ui.objective_text, id = Utils.game.ui.objective_id}
#	Utils.print_time_tracking_checkpoint("store_map", "data2")
	
	map_data._pixel_map_terrains = map.pixel_map._get_save_data()
	map_data._pixel_map_floors = map.floor_surface._get_save_data()
	map_data._pixel_map_floors2 = map.floor_surface2._get_save_data()
	map_data._event_object_count = map.event_object_list.size()
#	Utils.print_time_tracking_checkpoint("store_map", "data3")

func store_node(node: Node, parent: int):
#	Utils.store_node(node, parent, map_data)
#	return
	
	if node.is_in_group("dont_save"):
		return
	
	for type in SKIP_TYPES:
		if node.is_class(type):
			return
	
	if node.name in SKIP_NODES:
		return
	
	if node.has_method("_should_save") and not node._should_save():
		return
	
	var node_data: Dictionary
	map_data[str(_node_id, "/", node.name)] = node_data
	
	node_data.__node_id = _node_id
	node_data.__event_id = _map.event_object_list.find(node)
	_node_id += 1
	
	if parent > -1:
		node_data.__parent_id = parent
	
	if node.is_in_group("additional_save"):
		node_data.__parent_path = _map.get_path_to(node.get_parent())
	
	if node.filename:
		node_data.filename = node.filename
	else:
		node_data.type = node.get_class()
	
	node_data.merge(get_savable_properties(node))
	
	var groups: Array
	for group in node.get_groups():
		if group.begins_with("__") or group == "additional_save":
			groups.append(group)
	
	if not groups.is_empty():
		node_data.__groups = groups
	
	if node.has_method("_get_save_data"):
		node_data.__save_data = node._get_save_data()
	
	if node.filename.is_empty():
		for node2 in node.get_children():
			store_node(node2, node_data.__node_id)
	else:
		for node2 in node.get_children():
			if node2.owner != node:
				store_node(node2, node_data.__node_id)
	
	for sig in node.get_signal_list():
		for connection in node.get_signal_connection_list(sig.name):
			if not connection.target is Node:
				continue
			
			if node.filename and (node.is_ancestor_of(connection.target) or node == connection.target):
				continue
			
			if (connection.flags & CONNECT_PERSIST) == 0:
				continue
			
			connection.erase("binds") ## Uuuuu
			connection.source = _map.get_path_to(connection.source)
			connection.target = _map.get_path_to(connection.target)
			
			_connections.append(connection)

static func get_savable_properties(node: Node) -> Dictionary:
	var properties: Dictionary
	
	for property in node.get_property_list():
		if property.name in SKIP_PROPERTIES or (not property.usage & PROPERTY_USAGE_STORAGE and not property.name in ADDITIONAL_PROPERTIES):
			var serialize: bool

			if property.name == "script":
				var script: Script = node.get(property.name)
				if script and node.filename.is_empty():
					serialize = true

			if not serialize:
				continue
		
		var value = node.get(property.name)
		if value is PackedScene or value is Texture2D:
			value = {"ResourcePath": value.resource_path}
		elif value is Script and not (value.resource_path.is_empty() or value.resource_path.find("::") != -1):
			value = {"ResourcePath": value.resource_path}
		
		properties[property.name] = value
	
	return properties

func store_nodes(nodes: Array):
	for node in nodes:
		store_node(node, -1)
