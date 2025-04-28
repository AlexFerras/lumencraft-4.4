@tool
extends EditorObject

var controls = []

func _configure(editor):
	controls.clear()
	
	var type_button := OptionButton.new()
	type_button.add_item("Lab")
	type_button.add_item("Weapon Upgrade")
	type_button.add_item("Scout Upgrade")
	editor.add_object_setting(type_button)
	type_button.connect("item_selected", Callable(self, "set_type"))
	
	var technology_items: Control = preload("res://Nodes/Editor/GUI/CheckboxList.tscn").instantiate()
	technology_items.single_select = true
	
	for tech in Const.Technology.values():
		var metadata: String = tech.tech
		var item = technology_items.add_item(tr(tech.name), metadata)
		
		if "technology" in object_data and object_data.technology == metadata:
			item.button_pressed = true
	
	editor.add_object_setting(technology_items)
	controls.append(technology_items)
	technology_items.connect("item_selected", Callable(self, "technology_selected").bind(0))
	
	if technology_items.get_selected_items().is_empty():
		controls[0].hide()
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	technology_items = preload("res://Nodes/Editor/GUI/CheckboxList.tscn").instantiate()
	technology_items.single_select = true
	
	for id in Const.game_data.upgradable_weapons:
		for upgrade in Const.Items[id].upgrades:
			var metadata: String = str(Const.ItemIDs.keys()[id], "/", upgrade.name)
			var item = technology_items.add_item("%s: %s" % [tr(Utils.get_item_name({id = id})), tr(Const.UPGRADES[upgrade.name].get_slice("|", 0))], metadata)
			
			if "weapon_upgrade" in object_data and object_data.weapon_upgrade == metadata:
				item.button_pressed = true
	
	vbox.add_child(technology_items)
	var numeric := create_numeric_input(editor, "Level", "upgrade_level", 1, 10).get_parent()
	numeric.get_parent().remove_child(numeric)
	vbox.add_child(numeric)
	
	editor.add_object_setting(vbox)
	controls.append(vbox)
	technology_items.connect("item_selected", Callable(self, "technology_selected").bind(1))
	
	if technology_items.get_selected_items().is_empty():
		controls[1].hide()
	else:
		type_button.selected = 1
	
	vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	technology_items = preload("res://Nodes/Editor/GUI/CheckboxList.tscn").instantiate()
	technology_items.single_select = true
	
	for stat in Const.game_data.scout_upgrades:
		var metadata: String = stat
#		var item = technology_items.add_item(tr(Const.game_data.get_stat_rename(stat).capitalize()), metadata)
		var item = technology_items.add_item(tr(stat.capitalize()), metadata)
		
		if "player_upgrade" in object_data and object_data.player_upgrade == metadata:
			item.button_pressed = true
	
	vbox.add_child(technology_items)
	numeric = create_numeric_input(editor, "Level", "level", 1, 10).get_parent()
	numeric.get_parent().remove_child(numeric)
	vbox.add_child(numeric)
	
	editor.add_object_setting(vbox)
	controls.append(vbox)
	technology_items.connect("item_selected", Callable(self, "technology_selected").bind(2))
	
	if technology_items.get_selected_items().is_empty():
		controls[2].hide()
	else:
		type_button.selected = 2
	
	if type_button.selected == 0 and not "technology" in object_data:
		controls[0].show()
		controls[0].get_child(0).button_pressed = true

func set_type(t: int):
	for i in controls.size():
		controls[i].visible = i == t

func technology_selected(idx: int, type: int):
	object_data.clear()
	
	var list: Control
	match type:
		0:
			list = controls[0]
			object_data.technology = list.get_selected_items().front().get_meta("metadata")
		1:
			list = Utils.get_node_by_scene(controls[1], "res://Nodes/Editor/GUI/CheckboxList.tscn")
			object_data.weapon_upgrade = list.get_selected_items().front().get_meta("metadata")
			object_data.upgrade_level = Utils.get_node_by_type(controls[1], SpinBox).value
		2:
			list = Utils.get_node_by_scene(controls[2], "res://Nodes/Editor/GUI/CheckboxList.tscn")
			object_data.player_upgrade = list.get_selected_items().front().get_meta("metadata")
			object_data.level = Utils.get_node_by_type(controls[2], SpinBox).value
		_:
			push_error("Wrong tech type: %s" % type)
	emit_signal("data_changed")
