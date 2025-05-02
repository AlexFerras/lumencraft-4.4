extends TextDatabase

func _initialize():
	add_mandatory_property("level_name", TYPE_STRING)
	add_mandatory_property("description", TYPE_STRING)
	add_mandatory_property("expected_score", TYPE_INT)
	add_valid_property("map_file", TYPE_STRING)
	add_valid_property_with_default("rewards", [])
	add_valid_property_with_default("requirements", [])

func _postprocess_entry(entry: Dictionary):
	var new_rewards: Array
	for reward in entry.rewards:
		if reward in Const.Buildings or reward in Const.Technology:
			new_rewards.append(reward)
		else:
			new_rewards.append({id = Const.ItemIDs.keys().find(reward.get_slice(" ", 0)), amount = reward.get_slice(" ", 1).to_int()})
	entry.rewards = new_rewards
