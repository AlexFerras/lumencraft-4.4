@tool
extends "res://Nodes/Enemies/MegaSwarm/SpiderSwarm.gd"
class_name WormSwarm

var masks_initialized = false

func init_masks():
	var mats_durabilities = Utils.game.map.pixel_map.get_user_materials_durability()
	unit_avoidance_mask &= 0xFFFFFFFF ^ (1 << Const.Materials.DIRT)
	unit_go_through_mask |= 1 << Const.Materials.DIRT

	for m_id in Const.SwappableMaterials:
		if m_id < mats_durabilities.size():
			if mats_durabilities[m_id] <= 6.0:
				unit_avoidance_mask &= 0xFFFFFFFF ^ (1 << m_id)
				unit_go_through_mask |= 1 << m_id

	masks_initialized = true

func get_pathfinding_params():
	if !masks_initialized:
		init_masks()

	return [unit_go_through_mask, getPFMaterialsCosts(), Utils.game.map.pixel_map.getOptimalPFLvlResolution(unit_radius) ]

func pre_ready():
	init_masks()

func additional_setup():
	setEnemyMaxPursuitDistance(unit_radius + (80.0 if just_wander else 40.0))
	setEnemyBuildingMaxPursuitDistance(unit_radius + 12)

func getPFMaterialsCosts():
	var user_materials_cost = Utils.game.map.pixel_map.get_user_materials_durability()
	user_materials_cost[Const.Materials.GATE] = 2.0
	for i in range(user_materials_cost.size()):
		user_materials_cost[i] = user_materials_cost[i]*2.5

	user_materials_cost[Const.Materials.LOW_BUILDING] = 1.0
	user_materials_cost[Const.Materials.TAR] = 2.0
	user_materials_cost[Const.Materials.LAVA] = 20.0

	return user_materials_cost
