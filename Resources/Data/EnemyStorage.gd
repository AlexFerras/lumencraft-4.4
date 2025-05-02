extends TextDatabase

func _initialize():
	add_mandatory_property("scene", TYPE_STRING)
	add_mandatory_property("hp", TYPE_INT)
	add_mandatory_property("damage", TYPE_INT)
	add_valid_property_with_default("is_swarm", false)
	add_valid_property("description", TYPE_STRING)
	add_valid_property("placeholder_sprite", TYPE_STRING)
	add_valid_property("placeholder_scale", TYPE_FLOAT)
	add_valid_property("evade_heavy", TYPE_BOOL)
	add_valid_property("resist_weak", TYPE_BOOL)
	add_valid_property("threat", TYPE_INT)
	add_valid_property("probability", TYPE_INT)
	add_valid_property("hide_in_editor", TYPE_BOOL)

func _reserve_validate(entry: Dictionary, property: String):
	return property.begins_with("custom.")

func _postprocess_entry(entry):
	var custom: Dictionary
	
	for key in entry:
		if key.begins_with("custom."):
			custom[key.get_slice(".", 1)] = entry[key]
	
	if not custom.is_empty():
		entry.custom_stats = custom
