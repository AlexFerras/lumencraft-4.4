extends RefCounted
class_name MapFile

const VERSION = 11

var error: String
var loaded_version: int
var loaded_path: String

var map_name: String
var map_description: String
var workshop_id: int = -1
var uid: String
var validated: bool

var pixel_data: Image
var floor_data: Image
var floor_data2: Image
var terrain_config: Dictionary
var objects: Array

var darkness_color: Color
var enable_fog: bool = true
var buildings_drop_resources: bool = true
var extra_turret_limit: int
var resource_rate: float = 1.0
var wave_data: Array
var start_config: Dictionary
var objective_data: Dictionary
var events: Array

const FLOOR_RENAMES = {"AltDirt": "CoarseDirt", "Dirt": "LightDirt", "WormBiomass": "WormNest"}

func save_to_file(path: String):
	if uid.is_empty():
		uid = generate_uid()
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	
	file.store_32(VERSION)
	
	var header := {}
	header.map_name = map_name
	header.map_description = map_description
	header.workshop_id = workshop_id
	header.uid = uid
	header.validated = validated
	file.store_var(header)
	
	var pixel_buffer := pixel_data.save_png_to_buffer()
	file.store_32(pixel_buffer.size())
	file.store_buffer(pixel_buffer)
	
	pixel_buffer = floor_data.save_png_to_buffer()
	file.store_32(pixel_buffer.size())
	file.store_buffer(pixel_buffer)
	
	pixel_buffer = floor_data2.save_png_to_buffer()
	file.store_32(pixel_buffer.size())
	file.store_buffer(pixel_buffer)
	
	file.store_var(objects)
	
	var settings := {}
	settings.terrain_config = terrain_config
	settings.darkness_color = darkness_color
	settings.extra_turret_limit = extra_turret_limit
	settings.resource_rate = resource_rate
	settings.enable_fog = enable_fog
	settings.buildings_drop_resources = buildings_drop_resources
	settings.wave_data = wave_data
	settings.start_config = start_config
	settings.objective_data = objective_data
	settings.events = events
	file.store_var(settings)
	
	file.close()

func load_from_file(path: String):
	loaded_path = path
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		error = "Can't open map file"
		return
	
	var version: int = get_file_value(file, "get_32", 9999)
	loaded_version = version
	
	if version < VERSION:
		upgrade_map(version, file)
	elif version > VERSION:
		error = "Map comes from newer version"
		return
	
	if version < 10:
		map_name = get_file_value(file, "get_pascal_string", "")
		map_description = get_file_value(file, "get_pascal_string", "")
		workshop_id = get_file_value(file, "get_64", -1)
		uid = get_file_value(file, "get_pascal_string", "")
	else:
		var header: Dictionary = get_file_value(file, "get_var", {})
		map_name = header.map_name
		map_description = header.map_description
		workshop_id = header.workshop_id
		uid = header.uid
		validated = header.get("validated", false)
	
	var size: int = get_file_value(file, "get_32", -1)
	if size > 0:
		pixel_data = Image.new()
		pixel_data.load_png_from_buffer(file.get_buffer(size))
	
	size = get_file_value(file, "get_32", -1)
	if size > 0:
		floor_data = Image.new()
		floor_data.load_png_from_buffer(file.get_buffer(size))
	
	size = get_file_value(file, "get_32", -1)
	if size > 0:
		floor_data2 = Image.new()
		floor_data2.load_png_from_buffer(file.get_buffer(size))
	
	objects = get_file_value(file, "get_var", [])
	
	var settings: Dictionary = get_file_value(file, "get_var", {})
	darkness_color = settings.get("darkness_color", Color.BLACK)
	enable_fog = settings.get("enable_fog", true)
	buildings_drop_resources = settings.get("buildings_drop_resources", true)
	extra_turret_limit = settings.get("extra_turret_limit", 0)
	resource_rate = settings.get("resource_rate", 1.0)
	wave_data = settings.get("wave_data", [])
	start_config = settings.get("start_config", {})
	objective_data = settings.get("objective_data", {})
	terrain_config = settings.get("terrain_config", Const.game_data.DEFAULT_TERRAIN_CONFIG.duplicate(true))
	events = settings.get("events", [])
	
	file.close()
	
	if version < 7: # compat
		if terrain_config.terrain[1] != "Bedrock":
			terrain_config.bedrock_compat = terrain_config.terrain[1]
		terrain_config.terrain[1] = terrain_config.terrain[2]
		terrain_config.terrain[2] = terrain_config.terrain[3]
		terrain_config.terrain[3] = "Ice"
		terrain_config.terrain.append("Sandstone")
		terrain_config.terrain.append("Granite")
	
	if version < 8: # compat
		for item in start_config.get("inventory"):
			item.id = SaveData.CompatIDs.keys()[item.id]
	
	if version < 9: # compat
		for i in terrain_config.upper_floor.size():
			terrain_config.upper_floor[i] = FLOOR_RENAMES.get(terrain_config.upper_floor[i], terrain_config.upper_floor[i])
		
		for i in terrain_config.lower_floor.size():
			terrain_config.lower_floor[i] = FLOOR_RENAMES.get(terrain_config.lower_floor[i], terrain_config.lower_floor[i])
	
	if version < 10: # compat
		var tech_data: Dictionary
		for tech in start_config.get("unlocked_technology", []):
			tech_data[tech] = 1
		start_config.technology = tech_data
		start_config.erase("unlocked_technology")
	
	if version < 11: # compat
		for object in objects:
			if object.name == "Interactive Light3D":
				object.type = "Object"
				object.data.offset *= 0.5
				object.data.duration = 0.5
				object.data.pattern = [true, false, false, false, false, false]
	
	var has_start: bool
	for object in objects:
		if object.name == "Reactor" or object.name == "Start Point":
			has_start = true
			break
	
	if not has_start and not Utils.editor:
		error = "Map doesn't have a valid start point"

func load_metadata(path: String):
	var file =  FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	
	var version := file.get_32()
	
	if version < 10:
		map_name = file.get_pascal_string()
		map_description = file.get_pascal_string()
		workshop_id = get_file_value(file, "get_64", -1)
		uid = get_file_value(file, "get_pascal_string", "")
	else:
		var header: Dictionary = get_file_value(file, "get_var", {})
		map_name = header.map_name
		map_description = header.map_description
		workshop_id = header.workshop_id
		uid = header.uid
		validated = header.get("validated", false)
	
	file.close()

func get_file_value(file: FileAccess, method: String, default):
	var value = file.call(method)
	if file.eof_reached():
		error = "Map file invalid or corrupted"
	
	if value == null:
		return default
	
	return value

func upgrade_map(from_version: int, file: FileAccess):
	if error:
		return

func generate_uid() -> String:
	var available_chars: Array
	available_chars.append_array(range(48, 58))
	available_chars.append_array(range(65, 91))
	available_chars.append_array(range(97, 123))
	
	var result: PackedStringArray
	
	for i in 9:
		result.append(char(available_chars[randi() % available_chars.size()]))
	
	return "".join(result)
