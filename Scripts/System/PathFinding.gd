extends Node

var material_cost: PackedFloat32Array

enum PATH_MODE { PATH_THROUGH_WALLS_AND_NON_USER_MATERIALS, FULL_PATH_OR_CLOSEST_POINT }

var pixel_map: PixelMap

func initialize(pix: PixelMap):
	pixel_map = pix
	material_cost = pixel_map.get_user_materials_durability()
	material_cost[Const.Materials.GATE] = 2.0
	for i in range(material_cost.size()):
		material_cost[i] = material_cost[i]*3 + 9
	material_cost[Const.Materials.LOW_BUILDING] = 1.0
	material_cost[Const.Materials.TAR] = 2.0
	material_cost[Const.Materials.LAVA] = 20.0

	pixel_map.connect("tree_exited", Callable(self, "reset"))

func reset():
	pixel_map = null
	material_cost = PackedFloat32Array()


func get_path_from_params(from_position: Vector2, to_position: Vector2, go_through_mask, pf_costs, resolution, is_true :bool= true):
	assert(is_instance_valid(pixel_map))
	assert(resolution is int)
	
	var path_data: PathfindingResultData = pixel_map.find_path_astar_through_materials(from_position, to_position, pf_costs, 1, go_through_mask, is_true, resolution)
	if path_data:
		if path_data.path_found: # || get_closest_if_not_full_path:
			return path_data
	return null

func get_path_no_dig_from_to_position(from_position: Vector2,to_position: Vector2, resolution, get_closest_if_not_full_path:bool):
	assert(is_instance_valid(pixel_map))
	assert(resolution is int)
	
	var path_data : PathfindingResultData = pixel_map.find_path_astar_opt(from_position, to_position, true, resolution)
	if path_data:
		if path_data.path_found || get_closest_if_not_full_path:
			return path_data
	return null

func get_path_dig_from_to_position(from_position: Vector2, to_position: Vector2, resolution, get_closest_if_not_full_path:bool):
	assert(is_instance_valid(pixel_map))
	assert(resolution is int)
	
	var path_data: PathfindingResultData = pixel_map.find_path_astar_through_materials(from_position, to_position, material_cost, 1, Utils.monster_path_mask, true, resolution)
	if path_data:
		if path_data.path_found || get_closest_if_not_full_path:
			return path_data
	return null
	
func get_path_any_from_to_position(from_position: Vector2,to_position: Vector2, resolution, get_closest_if_not_full_path:bool):
	assert(resolution is int)
	var path_data : PathfindingResultData = get_path_no_dig_from_to_position(from_position, to_position, resolution, get_closest_if_not_full_path)
	if path_data and path_data.path_found:
		return path_data

	var path_data_2 : PathfindingResultData = get_path_dig_from_to_position(from_position, to_position, resolution, get_closest_if_not_full_path)
	if path_data_2:
		return path_data_2

	return path_data
