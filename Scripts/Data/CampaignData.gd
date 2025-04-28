extends Resource
class_name CampaignData

const END_MAP = "farmission"

@export var completed_levels: Dictionary
@export var level_scores: Dictionary
@export var endless_depth: int

@export var available_buildings: Array
@export var player_upgrades: Dictionary
@export var lab_technologies: Array
@export var resources: Dictionary

@export var current_map: String

var first: bool
var first2: bool
var new_building: String
var last: bool

var coop: bool
var unlock_all: bool

func start():
	first = true
	available_buildings = ["Pistol Workshop", "Machinegun Turret", "Scout Center", "Lab", "Light3D Tower", "Spear Workshop", "Item Rack"]

func complete_current_level(score: float) -> Dictionary:
	level_scores[current_map] = max(score, level_scores.get(current_map, 0))
	
	var prev_ratio: float = completed_levels.get(current_map, 0)
	var new_ratio: float = min(float(score) / Const.CampaignLevels[current_map].expected_score, 1.0) * 0.5
	if Save.map_completed:
		new_ratio = 1.0
		
		if prev_ratio < 1:
			if current_map == END_MAP:
				last = true
			elif current_map == "dig_100":
				first2 = true
	
	var rewards: Dictionary
	
	if new_ratio > prev_ratio:
		completed_levels[current_map] = new_ratio
		
		for reward in Const.CampaignLevels[current_map].rewards:
			if reward is Dictionary:
				rewards[reward.id] = int(round(reward.amount * (new_ratio - prev_ratio)))
				resources[reward.id] = resources.get(reward.id, 0) + rewards[reward.id]
			elif new_ratio == 1:
				rewards[reward] = true
				var prevbs := available_buildings.size()
				
				if reward in Const.Buildings:
					available_buildings.append(reward)
				else:
					lab_technologies.append(reward)
				
				if available_buildings.size() > prevbs:
					new_building = available_buildings.back()
					if new_building == "Range Expander":
						new_building = ""
	
	if Save.map_completed and current_map == "endless":
		endless_depth += 1
		completed_levels[current_map] = 0.0
	
	return rewards

func is_level_completed(level: String):
	return is_equal_approx(completed_levels.get(level, 0), 1) or unlock_all

func get_chunk_count() -> int:
	return int(is_level_completed("drillupgrad")) + int(is_level_completed("explosive_win")) + int(is_level_completed("farmission"))

func configure_map(map: MapFile, data: Dictionary):
	if "start_weapon" in data:
		map.start_config.inventory.append({id = data.start_weapon, amount = 1})
	
	var techs: Dictionary
	for tech in lab_technologies:
		techs[tech] = 1
	merge_max(map.start_config.technology, techs)
	
	var upgrades: Dictionary
	for upgrade in player_upgrades:
		upgrades[upgrade] = player_upgrades[upgrade]
	merge_max(map.start_config.upgrades, upgrades)
	merge_max(map.start_config.weapon_upgrades, upgrades)
	
	var disabled: Array
	for building in Const.Buildings.values():
		if not "category" in building:
			continue
		
		if building.name in map.start_config.disabled_buildings:
			map.start_config.disabled_buildings.erase(building.name)
			continue
		
		if not building.name in available_buildings:
			disabled.append(building.name)
	map.start_config.disabled_buildings = disabled
	
	if not "Machinegun Workshop" in available_buildings:
		map.start_config.technology["machinegun_possible"] = 2
	if not "Rocket Launcher Workshop" in available_buildings:
		map.start_config.technology["rocket_launcher_possible"] = 2
	if not "Shotgun Workshop" in available_buildings:
		map.start_config.technology["shotgun_possible"] = 2
	if not "Flamethrower Workshop" in available_buildings:
		map.start_config.technology["flamethrower_possible"] = 2
	
	if "info_center_map" in data:
		map.objects.append({type = "Custom", name = "Script", script_path = "res://Maps/Campaign/InfoCenterMapScript.gd"})
		
		var i := 0
		var spawner := randi() % 8
		
		for encounter in map.wave_data[0].enemies:
			i += 1
			encounter.spawner = spawner
			
			if i == 2:
				break

func merge_max(to: Dictionary, from: Dictionary):
	for property in from:
		if int(to.get(property, -1)) < int(from[property]):
			to[property] = from[property]
