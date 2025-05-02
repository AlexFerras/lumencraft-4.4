extends "res://Resources/Data/CommonStorage.gd"

func _initialize():
	add_mandatory_property("scene", TYPE_STRING)
	add_valid_property("description", TYPE_STRING)
	add_valid_property("category", TYPE_STRING)
	add_valid_property("cost")
	add_valid_property("max_hp", TYPE_INT)
	add_valid_property("requirements", TYPE_ARRAY)
	add_valid_property("upgrades", TYPE_ARRAY)
	add_valid_property_with_default("build_rotate", false)

func _postprocess_entry(entry: Dictionary):
	if "scene" in entry and "category" in entry:
		entry.icon = "res://Nodes/Buildings/Icons/Icon" + entry.scene.get_file()
		assert(Utils.safe_open(Utils.FILE, entry.icon, FileAccess.READ), "Brak ikony dla: " + entry.name)
		
		entry.image_icon = "res://Nodes/Buildings/Icons/BuildMenu".path_join(entry.name) + ".png"
		assert(ResourceLoader.exists(entry.image_icon), "Brak obrazka dla: " + entry.name)
	
	if "cost" in entry:
		if entry.cost is int:
			entry.cost = {Constants.ItemIDs.METAL_SCRAP: entry.cost}
		elif entry.cost is Dictionary:
			var final_cost: Dictionary
			for cost in entry.cost:
				final_cost[Constants.ItemIDs.keys().find(cost)] = entry.cost[cost]
			entry.cost = final_cost
		else:
			assert(false, "Zły koszt")
		
		if "requirements" in entry:
			for req in entry.requirements:
				validate_requirement(req)
	
	var unique_upgrades := {}
	if "upgrades" in entry:
		for upgrade in entry.upgrades:
			assert("name" in upgrade)
			assert("cost" in upgrade)
			
			for rq in upgrade.get("requirements", []):
				validate_requirement(rq)
			
			upgrade.level = unique_upgrades.get(upgrade.name, 0)
			unique_upgrades[upgrade.name] = upgrade.level + 1
			
			var new_costs = []
			for cost in upgrade.cost:
				new_costs.append({id = convert_item_id(cost), amount = upgrade.cost[cost]})
			
			upgrade.cost = new_costs
	
	entry.level1 = unique_upgrades.size()
