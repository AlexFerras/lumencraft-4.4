@tool
extends "res://Nodes/Editor/Buildings/EditorBuilding.gd"

@export var type: String

func _init_data():
	super._init_data()
	defaults.upgrades = {}
	defaults.increase_limit = true

func _configure(editor):
	super._configure(editor)
	
	var upgrades: Array = Const.Buildings[object_name].upgrades
	if upgrades.is_empty():
		return
	else:
		var label := Label.new()
		label.text = "Upgrade Levels"
		label.theme_type_variation = "HeaderLabel"
		editor.add_object_setting(label)
	
	var upgrade_spinboxes: Dictionary
	for upgrade in upgrades:
		if upgrade.name in upgrade_spinboxes:
			upgrade_spinboxes[upgrade.name].max_value += 1
		else:
			var hbox := VBoxContainer.new()
			
			var label := Label.new()
			label.text = Const.UPGRADES[upgrade.name].get_slice("|", 0)
			hbox.add_child(label)
			
			var amount := SpinBox.new()
			amount.max_value = 1
			amount.get_line_edit().add_theme_constant_override("minimum_spaces", 1)
			amount.connect("value_changed", Callable(self, "set_upgrade").bind(upgrade.name))
			hbox.add_child(amount)
			upgrade_spinboxes[upgrade.name] = amount
			
			editor.add_object_setting(hbox)
	
	for upgrade in upgrade_spinboxes:
		var spinbox = upgrade_spinboxes[upgrade]
		spinbox.value = object_data.upgrades.get(upgrade, 0)
	
	create_checkbox(editor, "Increases Turret Limit?", "increase_limit")

func set_upgrade(level: int, upgrade: String):
	if level == 0:
		object_data.upgrades.erase(upgrade)
	else:
		object_data.upgrades[upgrade] = level
	emit_signal("data_changed")
