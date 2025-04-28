@tool
extends "res://Nodes/Enemies/MegaSwarm/SpiderSwarm.gd"
class_name FlyingSwarm


func _init():
	spawn_unit_on_materials_mask |= 1 << Const.Materials.LAVA | 1 << Const.Materials.TAR | 1 << Const.Materials.WATER | Utils.walls_and_gate_mask | 1 << Const.Materials.FOAM | 1 << Const.Materials.FOAM2
	unit_collision_mask &= 0xFFFFFFFF ^ (1 << Const.Materials.LAVA | 1 << Const.Materials.TAR | 1 << Const.Materials.WATER | Utils.walls_and_gate_mask)
	unit_avoidance_mask &= 0xFFFFFFFF ^ (Utils.walls_and_gate_mask | 1 << Const.Materials.LOW_BUILDING | 1 << Const.Materials.FOAM | 1 << Const.Materials.FOAM2 | 1 << Const.Materials.TAR | 1 << Const.Materials.LAVA | 1 << Const.Materials.WATER)
	unit_go_through_mask |= 1 << Const.Materials.TAR | Utils.walls_and_gate_mask | 1 << Const.Materials.LOW_BUILDING | 1 << Const.Materials.DIRT | 1 << Const.Materials.FOAM | 1 << Const.Materials.FOAM2 | 1 << Const.Materials.LAVA | 1 << Const.Materials.WATER

func additional_setup():
	flying=1
	setUserMaterialDamageToUnits(Const.Materials.LAVA, 0.0, 0.0)

	setWalkAnimationMinSpeedFract(0.5)

	setEnemyMaxPursuitDistance(unit_radius + (80.0 if just_wander else 40.0))
	setEnemyBuildingMaxPursuitDistance(unit_radius + 12)
	setUserMaterialUsitsSpeedMultiplier(Const.Materials.WALL3, 0.3);

func _tech_unlocked(tech: String):
	pass

func getPFMaterialsCosts():
	var user_materials_cost=PathFinding.material_cost
	user_materials_cost[Const.Materials.GATE]=0.0
	user_materials_cost[Const.Materials.LOW_BUILDING]=1.0
	user_materials_cost[Const.Materials.WALL]=0.0
	user_materials_cost[Const.Materials.WALL1]=0.0
	user_materials_cost[Const.Materials.WALL2]=0.0
	user_materials_cost[Const.Materials.WALL3]=2.0
	user_materials_cost[Const.Materials.LAVA] = 2.0

	return user_materials_cost
	


func on_damage_callback(position: Vector2, damager: Node, unit_id: int, in_distance_from_focus_check: bool):
	if damager.get_meta("data", {}).has("no_flying"):
		return
	
	super.on_damage_callback(position, damager, unit_id, in_distance_from_focus_check)
