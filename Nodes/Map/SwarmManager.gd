extends Node2D

var swarm_map: Dictionary

func _init() -> void:
	name = "SwarmManager"
	add_to_group("dont_save")

func request_swarm(swarm: String, data = null, no_wander := false) -> Swarm:
	var swarm_key := swarm
	if no_wander and not swarm.ends_with(".nw"):
		swarm_key += ".nw"
	
	if swarm_key in swarm_map:
		var swarm_instance = swarm_map[swarm_key]
		if data:
			if data is Dictionary:
				swarm_instance.just_wander = not data.no_wander
				swarm_instance.prioritize_player = swarm_instance.just_wander
				swarm_instance.loadUnitsStateFromBinaryData(data.binary)
			else: # compat
				swarm_instance.loadUnitsStateFromBinaryData(data)
		return swarm_map[swarm_key]
	else:
		var swarm_instance: Swarm = load(swarm.trim_suffix(".nw")).instantiate()
		swarm_instance.add_to_group("MegaSwarm")
		
		if not no_wander:
			swarm_instance.just_wander = true
			swarm_instance.prioritize_player = true
		
		swarm_instance.wall_avoidance_force_multiplier = 1.0
		swarm_instance.attacks_terrain = true
		swarm_instance.how_many = 0
		swarm_instance.spawn_radius = 0
		swarm_instance._infinity = true
		swarm_instance.auto_remove = false
		swarm_instance.spawn_only_on_empty = true
		swarm_instance.connect("tree_exited", Callable(self, "remove_swarm").bind(swarm))
		if data:
			if data is Dictionary:
				swarm_instance.just_wander = not data.no_wander
				swarm_instance.prioritize_player = swarm_instance.just_wander
				swarm_instance.data_to_load = data.binary
			else:
				swarm_instance.data_to_load = data
		
		add_child(swarm_instance)
		swarm_map[swarm_key] = swarm_instance
		return swarm_instance

func remove_swarm(swarm: String):
	swarm_map.erase(swarm)

func _get_save_data() -> Dictionary:
	var data: Dictionary
	
	for swarm in swarm_map:
		data[swarm] = {binary = swarm_map[swarm].getUnitsStateBinaryData(), no_wander = not swarm_map[swarm].just_wander}
	
	return data

func _set_save_data(data: Dictionary):
	for swarm in data:
		var swarm_instance := request_swarm(swarm, data[swarm])
