extends "res://Resources/Data/CommonStorage.gd"

var ammos: Array
var aspects: Array

func _initialize():
	entry_name = "item_id"
	
	add_valid_property("default_name", TYPE_STRING)
	add_valid_property("description", TYPE_STRING)
	add_valid_property("icon", TYPE_STRING)
	add_valid_property("ui_icon", TYPE_STRING) ## kill me
	add_valid_property("sprite", TYPE_STRING)
	add_valid_property("cost")
	
	add_valid_property("rarity", TYPE_INT)
	add_valid_property("quality", TYPE_FLOAT)
	
	add_valid_property("shoot_scene", TYPE_STRING)
	add_valid_property("melee_scene", TYPE_STRING)
	add_valid_property("throwable_scene", TYPE_STRING)
	add_valid_property("throw_sprite", TYPE_STRING)
	add_valid_property("cursor", TYPE_STRING)
	
	add_valid_property("ammo", TYPE_STRING)
	add_valid_property("item_ammo", TYPE_STRING)
	add_valid_property("ammo_per_shot", TYPE_INT)
	add_valid_property("ammo_reduction", TYPE_INT)
	add_valid_property("damage", TYPE_INT)
	add_valid_property("aspect", TYPE_STRING)
	add_valid_property("crit_rate", TYPE_FLOAT)
	
	add_valid_property("weapon", TYPE_BOOL)
	add_valid_property("upgrades", TYPE_DICTIONARY)
	add_valid_property("infinite", TYPE_BOOL)
	add_valid_property("autofire", TYPE_BOOL)
	add_valid_property("delay", TYPE_INT)
	add_valid_property("delay_uses", TYPE_INT)
	add_valid_property("recoil", TYPE_FLOAT)
	add_valid_property("reload", TYPE_INT)
	add_valid_property("flame_amount", TYPE_INT)
	add_valid_property("weapon_range", TYPE_FLOAT)
	add_valid_property("stamina_cost", TYPE_INT)
	add_valid_property("reload_time", TYPE_FLOAT)
	add_valid_property("sprite_scale", TYPE_FLOAT)
	add_valid_property("use_gun_audio", TYPE_BOOL)
	
	add_valid_property("throw_all", TYPE_BOOL)
	add_valid_property("variable_throw", TYPE_BOOL)
	add_valid_property("drop_shells", TYPE_BOOL)
	add_valid_property("use_vibration", TYPE_VECTOR3)
	
	add_valid_property_with_default("usable", true, true)
	add_valid_property_with_default("stack_size", 999, true)
	add_valid_property_with_default("animation", "Carry", true)

func _additional_validate(entry: Dictionary, property: String) -> bool:
	match property:
		entry_name:
			return entry[entry_name] in Constants.ItemIDs.keys()
		"cost":
			var value = entry[property]
			return value is Array or value is int or value is float
		"rarity":
			return "quality" in entry
		"quality":
			return "rarity" in entry
		_:
			return true

func _reserve_validate(entry: Dictionary, property: String) -> bool:
	if property.find(".lv") > -1:
		return is_property_valid(entry, property.get_slice(".", 0), entry[property])
	
	if property.ends_with(".fear"):
		return is_property_valid(entry, property.get_slice(".", 0), entry[property])
	
	if property.begins_with("upgrade."):
		return property.count(".") == 2
	
	if property.begins_with("custom_"):
		return true
	
	return false

func _postprocess_entry(entry: Dictionary):
	entry.item_id = convert_item_id(entry.item_id)
	
	if "ammo" in entry:
		entry.ammo = convert_ammo_id(entry.ammo)
	
	if "item_ammo" in entry:
		entry.item_ammo = convert_item_id(entry.item_ammo)
	
	if "aspect" in entry:
		entry.aspect = convert_aspect_id(entry.aspect)
	
	if "reload" in entry and not "reload_time" in entry:
		entry.reload_time = 1
	
	if "cost" in entry and entry.cost is Array:
		for item in entry.cost:
			item.id = convert_item_id(item.id)
	
	if "icon" in entry:
		var file: String = entry.icon.get_file()
		file = (entry.icon.get_base_dir() + "_no_border").path_join(file)
		if ResourceLoader.exists(file):
			entry.ground_icon = file
		else:
#			prints(entry.get("default_name", entry.id), file)
			entry.ground_icon = entry.icon
	
	convert_upgrades(entry, "upgrades")
	convert_upgrades(entry, "custom_upgrades_for_compatibility")
	
#	if "ui_icon" in entry: entry.icon = entry.ui_icon

func convert_upgrades(entry: Dictionary, key: String):
	if not key in entry:
		return
	
	for upgrade in entry[key].values():
		if "requirements" in upgrade:
			for reqs in upgrade.requirements.values():
				for req in reqs:
					validate_requirement(req)
		
		assert("costs" in upgrade)
		var new_costs := []
		for cost in upgrade.costs:
			var level_costs := []
			for id in cost:
				level_costs.append({id = convert_item_id(id), amount = cost[id]})
			new_costs.append(level_costs)
		
		upgrade.costs = new_costs
	
	var new_upgrades := []
	for upgrade in entry[key]:
		var new_upgrade: Dictionary = entry[key][upgrade]
		new_upgrade.name = upgrade
		new_upgrades.append(new_upgrade)
	
	entry[key] = new_upgrades

func convert_ammo_id(id: String) -> int:
	var new_id: int = ammos.find(id)
	assert(new_id >= 0, "Nieprawidłowe ID amunicji: " + id)
	return new_id

func convert_aspect_id(id: String) -> int:
	var new_id: int = aspects.find(id)
	assert(new_id >= 0, "Nieprawidłowe ID aspektu: " + id)
	return new_id
