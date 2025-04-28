extends Resource
class_name PlayerData

@export var finished_maps: Array
@export var frogs_found: Array

func add_completed_map(map: String):
	if not map in finished_maps:
		finished_maps.append(map)
		save()

func is_map_completed(map: String) -> bool:
	return map in finished_maps

func set_frog_found(map: String) -> int:
	assert(not map in frogs_found)
	assert(map in Const.FROG_MAPS)
	frogs_found.append(map)
	save()
	return frogs_found.size()

func is_frog_found(map: String):
	return map in frogs_found

func save():
	ResourceSaver.save(resource_path, self)
