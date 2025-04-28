@tool
extends "res://Nodes/Editor/Objects/EditorItemContainer.gd"

@export var enemy_data: Dictionary

func _init() -> void:
	can_rotate = true
	no_item_text = "No loot. Drop a Pickup object on the enemy to add."
	empty_text = "No Loot"

func _init_data():
	enemy_data = Const.Enemies[object_name]
	defaults.overrides = {}
	super._init_data()

func _configure(editor):
	var label := Label.new()
	label.text = "Override Stats"
	editor.add_object_setting(label)
	
	var hbox := HBoxContainer.new()
	
	label = Label.new()
	label.text = "Color"
	hbox.add_child(label)
	
	var color := ColorPickerButton.new()
	color.color = object_data.overrides.get("color", Color.WHITE)
	color.edit_alpha = false
	color.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color.connect("color_changed", Callable(self, "on_color_changed"))
	hbox.add_child(color)
	
	editor.add_object_setting(hbox)
	
	create_field(editor, "Health", "hp", 1)
	create_field(editor, "Damage", "damage", 0)
	
	if "custom_stats" in enemy_data:
		for stat in enemy_data.custom_stats:
			create_field(editor, stat.capitalize(), stat, 0)
	
	super._configure(editor)

func on_color_changed(color: Color):
	if color == Color.WHITE:
		object_data.overrides.erase(color)
	else:
		object_data.overrides.color = color
	icon.modulate = color
	emit_signal("data_changed")

func create_field(editor, field: String, stat: String, mini: int):
	var input := create_numeric_input(editor, field, stat, mini, 9999)
	if stat in enemy_data:
		input.value = object_data.overrides.get(stat, enemy_data[stat])
	else:
		input.value = object_data.overrides.get(stat, enemy_data.custom_stats[stat])

func _set_object_data_callback(value, field: String):
	var default: int
	if field in enemy_data:
		default = enemy_data[field]
	else:
		default = enemy_data.custom_stats[field]
	
	if value == default:
		object_data.overrides.erase(field)
	else:
		object_data.overrides[field] = value
	emit_signal("data_changed")

func get_condition_list() -> Array:
	return ["killed"]

func action_get_events() -> Array:
	return ["die"]
