extends RefCounted

var notified_events: Dictionary
var internal_variables: Dictionary

func get_condition_list() -> Array:
	return ["on_start*", "wave_defeated*", "player_has_item", "weapon_upgrade_level", "technology_researched", "compare_custom_variable"]

func action_get_events() -> Array:
	return ["display_message", "display_objective", "kill_player", "lose", "win", "set_ambient_light", "shake_screen", "launch_custom_wave", "change_custom_variable"]

func get_id():
	return -1

func get_target_name() -> String:
	return "Special"

func get_short_target_name() -> String:
	return "Special"

func get_additional_config(editor, condition_action: String) -> Control:
	match condition_action:
		"display_message":
			var vb := VBoxContainer.new()
			var text := TextEdit.new()
			text.custom_minimum_size.y = 200
			text.wrap_enabled = true
			editor.register_data("message", Callable(text, "set_text"), Callable(text, "get_text"))
			vb.add_child(text)
			
			var preview := RichTextLabel.new()
			preview.add_theme_font_override("mono_font", load("res://Resources/Anarchy/Fonts/spacemono_regular_minimal.tres"))
			preview.add_theme_font_override("bold_italics_font", load("res://Resources/Anarchy/Fonts/spacemono_bolditalic_minimal.tres"))
			preview.add_theme_font_override("italic_font", load("res://Resources/Anarchy/Fonts/spacemono_italic_minimal.tres"))
			preview.add_theme_font_override("bold_font", load("res://Resources/Anarchy/Fonts/spacemono_bold_minimal.tres"))
			preview.add_theme_font_override("normal_font", load("res://Resources/Anarchy/Fonts/spacemono_regular_minimal.tres"))
			preview.bbcode_enabled = true
			preview.custom_minimum_size.y = 200
			preview.hide()
			vb.add_child(preview)
			
			var hack = get_script().new()
			vb.set_meta("hack", hack)
			
			var check := CheckButton.new()
			check.text = "Preview"
			check.connect("toggled", Callable(hack, "toggle_message_preview").bind(text, preview))
			vb.add_child(check)
			
			var link := LinkButton.new()
			link.text = "BBCode RefCounted"
			link.connect("pressed", Callable(OS, "shell_open").bind("https://docs.godotengine.org/en/stable/tutorials/ui/bbcode_in_richtextlabel.html"))
			vb.add_child(link)
			return vb
		"display_objective":
			var edit := LineEdit.new()
			edit.placeholder_text = "Objective Text (Empty = Default)"
			editor.register_data("objective", Callable(edit, "set_text"), Callable(edit, "get_text"))
			return edit
		"win", "lose":
			var vb := VBoxContainer.new()
			
			var label := Label.new()
			label.text = "Custom Message"
			
			var text := preload("res://Nodes/Editor/GUI/LineEditWithSetDisabled.gd").new()
			editor.register_data("message", Callable(text, "set_text"), Callable(text, "get_text"))
			
			if condition_action == "win":
				var checkbox := CheckBox.new()
				checkbox.text = "Instant?"
				checkbox.connect("toggled", Callable(text, "set_disabled"))
				editor.register_data("instant", Callable(checkbox, "set_pressed"), Callable(checkbox, "is_pressed"))
				vb.add_child(checkbox)
			
			vb.add_child(label)
			vb.add_child(text)
			
			return vb
		"set_ambient_light":
			var vb := VBoxContainer.new()
			
			var color := ColorPickerButton.new()
			editor.register_data("color", Callable(color, "set_pick_color"), Callable(color, "get_pick_color"))
			vb.add_child(color)
			
			var time := SpinBox.new()
			time.suffix = "s"
			editor.register_data("time", Callable(time, "set_value"), Callable(time, "get_value"))
			vb.add_child(time)
			
			return vb
		"shake_screen":
			var vb := VBoxContainer.new()
			
			var label := Label.new()
			label.text = "Strength"
			vb.add_child(label)
			
			var edit := SpinBox.new()
			edit.step = 0.01
			edit.value = 10
			editor.register_data("attenuation", Callable(edit, "set_value"), Callable(edit, "get_value"))
			vb.add_child(edit)
			
			label = Label.new()
			label.text = "Duration"
			vb.add_child(label)
			
			edit = SpinBox.new()
			edit.step = 0.01
			edit.value = 0.5
			edit.suffix = "s"
			editor.register_data("duration", Callable(edit, "set_value"), Callable(edit, "get_value"))
			vb.add_child(edit)
			
			label = Label.new()
			label.text = "Frequency"
			vb.add_child(label)
			
			edit = SpinBox.new()
			edit.step = 0.01
			edit.value = 30
			editor.register_data("frequency", Callable(edit, "set_value"), Callable(edit, "get_value"))
			vb.add_child(edit)
			
			label = Label.new()
			label.text = "Randomness"
			vb.add_child(label)
			
			edit = SpinBox.new()
			edit.step = 0.01
			edit.max_value = 1
			edit.value = 1
			editor.register_data("randomness", Callable(edit, "set_value"), Callable(edit, "get_value"))
			vb.add_child(edit)
			
			return vb
		"launch_custom_wave":
			var edit := preload("res://Nodes/Editor/GUI/WaveEdit.tscn").instantiate() as Control
			edit.call_deferred("disable_moving")
			editor.register_data("data", Callable(edit, "set_data"), Callable(edit, "get_data"))
			return edit
		"compare_custom_variable":
			var vb := VBoxContainer.new()
			
			var label := Label.new()
			label.text = "Variable"
			vb.add_child(label)
			
			var variable := LineEdit.new()
			editor.register_data("variable", Callable(variable, "set_text"), Callable(variable, "get_text"))
			vb.add_child(variable)
			
			label = Label.new()
			label.text = "Operation"
			vb.add_child(label)
			
			var operation := OptionButton.new()
			operation.add_item("Equal To")
			operation.add_item("Not Equal To")
			operation.add_item("Greater Than")
			operation.add_item("Less Than")
			editor.register_data("operation", Callable(operation, "select"), Callable(operation, "get_selected"))
			vb.add_child(operation)
			
			label = Label.new()
			label.text = "Value"
			vb.add_child(label)
			
			var value := SpinBox.new()
			value.min_value = -999999
			value.max_value = 999999
			editor.register_data("value", Callable(value, "set_value"), Callable(value, "get_value"))
			vb.add_child(value)
			
			return vb
		"change_custom_variable":
			var vb := VBoxContainer.new()
			
			var label := Label.new()
			label.text = "Variable"
			vb.add_child(label)
			
			var variable := LineEdit.new()
			editor.register_data("variable", Callable(variable, "set_text"), Callable(variable, "get_text"))
			vb.add_child(variable)
			
			label = Label.new()
			label.text = "Operation"
			vb.add_child(label)
			
			var operation := OptionButton.new()
			operation.add_item("Set")
			operation.add_item("Add")
			operation.add_item("Subtract")
			editor.register_data("operation", Callable(operation, "select"), Callable(operation, "get_selected"))
			vb.add_child(operation)
			
			label = Label.new()
			label.text = "Value"
			vb.add_child(label)
			
			var value := SpinBox.new()
			value.min_value = -999999
			value.max_value = 999999
			editor.register_data("value", Callable(value, "set_value"), Callable(value, "get_value"))
			vb.add_child(value)
			
			return vb
		"wave_defeated":
			var vb := VBoxContainer.new()
			
			var label := Label.new()
			label.text = "Wave Number (or greater)"
			vb.add_child(label)
			
			var value := SpinBox.new()
			value.min_value = 0
			value.max_value = 999999
			editor.register_data("number", Callable(value, "set_value"), Callable(value, "get_value"), 0)
			vb.add_child(value)
			
			return vb
		"player_has_item":
			var vb := VBoxContainer.new()
			
			var selected_item := OptionButton.new()
			selected_item.set_script(preload("res://Nodes/Editor/GUI/OptionButtonWithSelectMetadata.gd"))
			for item in Const.game_data.get_editor_pickup_list():
				selected_item.add_item(Utils.get_item_name(item))
				selected_item.set_item_metadata(selected_item.get_item_count() - 1, item)
			editor.register_data("item", Callable(selected_item, "select_metadata"), Callable(selected_item, "get_selected_metadata"))
			vb.add_child(selected_item)
			
			var operation := OptionButton.new()
			operation.add_item("Equal To")
			operation.add_item("Greater Than")
			operation.add_item("Less Than")
			editor.register_data("operation", Callable(operation, "select"), Callable(operation, "get_selected"))
			vb.add_child(operation)
			
			var value := SpinBox.new()
			value.min_value = 0
			value.max_value = 9999
			editor.register_data("amount", Callable(value, "set_value"), Callable(value, "get_value"))
			vb.add_child(value)
			
			return vb
		"weapon_upgrade_level":
			var vb := VBoxContainer.new()
			
			var selected_weapon := OptionButton.new()
			selected_weapon.set_script(preload("res://Nodes/Editor/GUI/OptionButtonWithSelectMetadata.gd"))
			for weapon in Const.game_data.upgradable_weapons:
				selected_weapon.add_item(Utils.get_item_name({id = weapon}))
				selected_weapon.set_item_metadata(selected_weapon.get_item_count() - 1, Const.ItemIDs.keys()[weapon])
			editor.register_data("weapon", Callable(selected_weapon, "select_metadata"), Callable(selected_weapon, "get_selected_metadata"))
			vb.add_child(selected_weapon)
			
			selected_upgrade = OptionButton.new()
			selected_upgrade.set_script(preload("res://Nodes/Editor/GUI/OptionButtonWithSelectMetadata.gd"))
			editor.register_data("upgrade", Callable(selected_upgrade, "select_metadata"), Callable(selected_upgrade, "get_selected_metadata"))
			vb.add_child(selected_upgrade)
			
			selected_weapon.set_meta("specref", self)
			selected_weapon.connect("item_selected", Callable(self, "on_weapon_selected").bind(selected_weapon))
			on_weapon_selected(selected_weapon.selected, selected_weapon)
			
			var operation := OptionButton.new()
			operation.add_item("Equal To")
			operation.add_item("Greater Than")
			operation.add_item("Less Than")
			editor.register_data("operation", Callable(operation, "select"), Callable(operation, "get_selected"))
			vb.add_child(operation)
			
			var value := SpinBox.new()
			value.min_value = 0
			value.max_value = 5
			editor.register_data("amount", Callable(value, "set_value"), Callable(value, "get_value"))
			vb.add_child(value)
			
			return vb
		"technology_researched":
			var selected_tech := OptionButton.new()
			selected_tech.set_script(preload("res://Nodes/Editor/GUI/OptionButtonWithSelectMetadata.gd"))
			for tech in Const.Technology.values():
				selected_tech.add_item(tech.name)
				selected_tech.set_item_metadata(selected_tech.get_item_count() - 1, tech.tech)
			editor.register_data("tech", Callable(selected_tech, "select_metadata"), Callable(selected_tech, "get_selected_metadata"))
			return selected_tech
	
	return null

func is_condition_met(condition: String, data: Dictionary) -> bool:
	match condition:
		"on_start":
			return data.events.is_start
		"wave_defeated":
			return "wave_defeated" in notified_events and (data.get("number") == 0 or notified_events["wave_defeated"] >= data.number)
		"compare_custom_variable":
			match data.operation:
				0:
					return internal_variables.get(data.variable, 0) == data.value
				1:
					return internal_variables.get(data.variable, 0) != data.value
				2:
					return internal_variables.get(data.variable, 0) > data.value
				3:
					return internal_variables.get(data.variable, 0) < data.value
		"player_has_item":
			for player in Utils.game.players:
				var count = player.get_item_count(data.item.id, data.item.get("data"))
				match data.operation:
					0:
						if count == data.amount:
							return true
					1:
						if count > data.amount:
							return true
					2:
						if count < data.amount:
							return true
		"weapon_upgrade_level":
			var value = Save.get_unclocked_tech(str(Const.ItemIDs.keys().find(data.weapon), data.upgrade))
			match data.operation:
				0:
					if value == data.amount:
						return true
				1:
					if value > data.amount:
						return true
				2:
					if value < data.amount:
						return true
		"technology_researched":
			return Save.is_tech_unlocked(data.tech)
	return false

func execute_action(action: String, data: Dictionary):
	match action:
		"display_message":
			Utils.game.ui.on_screen_message.add_message(data.message)
		"display_objective":
			if data.objective.is_empty():
				Utils.game.ui.set_objective(0, Utils.game.get_meta("_default_objective_", ""), true)
			else:
				Utils.game.ui.set_objective(0, data.objective, true)
		"kill_player":
			for player in Utils.game.players:
				player.damage({damage = 9999})
		"win":
			if data.instant:
				Utils.game.win("")
				Utils.game.ui.show_result(true)
			else:
				var message: String = data.get("message", "")
				if message.is_empty():
					Utils.game.win()
				else:
					Utils.game.win(message)
		"lose":
			var message: String = data.get("message", "")
			Utils.game.game_over("Owned" if message.is_empty() else message)
		"set_ambient_light":
			Utils.get_tree().create_tween().tween_property(Utils.game.map.get_node("PixelMap/MapDarkness"), "ambient_color", data.color, data.time)
		"shake_screen":
			Utils.game.shake(data.attenuation, data.duration, data.frequency, data.randomness)
		"launch_custom_wave":
			Utils.game.map.wave_manager.launch_wave(data.data)
		"change_custom_variable":
			match data.operation:
				0:
					internal_variables[data.variable] = data.value
				1:
					internal_variables[data.variable] = internal_variables.get(data.variable, 0) + data.value
				2:
					internal_variables[data.variable] = internal_variables.get(data.variable, 0) - data.value

func toggle_message_preview(enable, text, preview):
	text.visible = not enable
	preview.visible = not text.visible
	if preview.visible:
		preview.text = text.text

func notify_event(event: String, data = null):
	notified_events[event] = data

func clear_events():
	notified_events.clear()

var selected_upgrade: OptionButton

func on_weapon_selected(idx: int, optioner: OptionButton):
	assert(is_instance_valid(selected_upgrade))
	
	selected_upgrade.clear()
	for upgrade in Const.Items[Const.ItemIDs.keys().find(optioner.get_item_metadata(idx))].upgrades:
		selected_upgrade.add_item(Const.UPGRADES[upgrade.name].get_slice("|", 0))
		selected_upgrade.set_item_metadata(selected_upgrade.get_item_count() - 1, upgrade.name)
