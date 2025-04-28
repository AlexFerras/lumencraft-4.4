@tool
extends "res://Nodes/Editor/Buildings/EditorBuilding.gd"

func _init() -> void:
	can_receive_power = false

func _init_data():
	defaults.level = 0
	update_texture()

func _configure(editor):
	create_numeric_input(editor, "Upgrade Level", "level", 0, 3)

func _set_object_data_callback(value, field: String):
	super._set_object_data_callback(value, field)
	update_texture()

func set_data(data: Dictionary):
	super.set_data(data)
	update_texture()

func update_texture():
	icon.texture = load("res://Nodes/Buildings/Wall/Level%d.png" % (object_data.get("level", 0) + 1))
