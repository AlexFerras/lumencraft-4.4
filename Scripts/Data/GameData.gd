extends RefCounted

const DEFAULT_TERRAIN_CONFIG = {terrain = ["Rock", "Ice", "Steel", "Concrete", "Sandstone", "Granite"], upper_floor = ["Biomass", "GlowingBiomass", "Fungus", "Blood"], lower_floor = ["LightDirt", "CoarseDirt", "Steel", "DankDirt"]}

var upgradable_weapons := []
var scout_upgrades := ["health", "speed", "luck", "stamina", "backpack"]

#func get_stat_rename(stat: String):
#	if stat == "luck":
#		return "evasion"
#	else:
#		return stat

func _init() -> void:
	for data in Const.Items.values():
		if "upgrades" in data:
			upgradable_weapons.append(data.item_id)

func get_editor_pickup_list(include_categories := false) -> Array:
	var list := [
		{id = Const.ItemIDs.METAL_SCRAP},
		{id = Const.ItemIDs.LUMEN},
		{id = Const.ItemIDs.SPEAR},
		{id = Const.ItemIDs.MAGNUM},
		{id = Const.ItemIDs.MACHINE_GUN},
		{id = Const.ItemIDs.SHOTGUN},
		{id = Const.ItemIDs.ROCKET_LAUNCHER},
		{id = Const.ItemIDs.FLAMETHROWER},
		{id = Const.ItemIDs.LIGHTNING_GUN},
		{id = Const.ItemIDs.AMMO, data = Const.Ammo.BULLETS},
		{id = Const.ItemIDs.AMMO, data = Const.Ammo.ROCKETS},
		{id = Const.ItemIDs.NAPALM},
		{id = Const.ItemIDs.FLARE},
		{id = Const.ItemIDs.MINE},
		{id = Const.ItemIDs.GRENADE},
		{id = Const.ItemIDs.DYNAMITE},
		{id = Const.ItemIDs.MEDPACK},
		{id = Const.ItemIDs.REPAIR_KIT},
		{id = Const.ItemIDs.FOAM_GUN},
		{id = Const.ItemIDs.DRILL},
		{id = Const.ItemIDs.HOOK},
		{id = Const.ItemIDs.LUMEN_CLUMP},
		{id = Const.ItemIDs.METAL_NUGGET},
		{id = Const.ItemIDs.KEY, data = 0},
		{id = Const.ItemIDs.KEY, data = 1},
		{id = Const.ItemIDs.KEY, data = 2},
		{id = Const.ItemIDs.KEY, data = 3},
		{id = Const.ItemIDs.ARTIFACT, data = 0},
		{id = Const.ItemIDs.ARTIFACT, data = 1},
		{id = Const.ItemIDs.ARTIFACT, data = 2},
	]
	
	if include_categories:
		list.insert(23, {category = "Event"}) # key
		list.insert(21, {category = "Container"}) # lumen clump
		list.insert(17, {category = "Utility"}) # repair kit
		list.insert(9, {category = "Consumable"}) # ammo 1
		list.insert(2, {category = "Weapon"}) # spear
		list.insert(0, {category = "Resource", first = true})
	
	return list

func get_editor_enemy_list(include_categories := false) -> Array:
	var list : Array
	
	var current_category := ""
	for enemy in Const.Enemies.values():
		if "placeholder_sprite" in enemy and not enemy.get("hide_in_editor"):
			if include_categories:
				var category := "Regular"
				if enemy.name in Const.BOSS_ENEMIES:
					category = "Boss"
				elif enemy.is_swarm:
					category = "Swarm"
				
				if category != current_category:
					list.append({category = category, first = current_category.is_empty()})
					current_category = category
			
			if enemy.is_swarm:
				list.append("Swarm/" + enemy.name)
			else:
				list.append(enemy.name)
	
	return list

func get_hidden_editor_enemy_list() -> Array:
	var list : Array
	
	for enemy in Const.Enemies.values():
		if "placeholder_sprite" in enemy:
			if enemy.get("hide_in_editor"):
				if enemy.is_swarm:
					list.append("Swarm/" + enemy.name)
				else:
					list.append(enemy.name)
	
	return list
