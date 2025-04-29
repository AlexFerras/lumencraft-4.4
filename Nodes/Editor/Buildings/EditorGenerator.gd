@tool
extends "res://Nodes/Editor/Buildings/EditorPowerBuilding.gd"

func _init_data():
	super._init_data()
	defaults.running = false
	defaults.stored_power = 60
	radius = load("res://Nodes/Buildings/Pylon/Generator.gd").RANGE

func _configure(editor):
	super._configure(editor)
	
	var checkbox := CheckBox.new()
	checkbox.text = "Running?"
	checkbox.button_pressed = object_data.running
	checkbox.connect("toggled", Callable(self, "set_running"))
	editor.add_object_setting(checkbox)
	
	create_numeric_input(editor, "Stored Power\n(-1 = infinite)", "stored_power", -1, 900).suffix = "s"

func set_running(r: bool):
	object_data.running = r
	emit_signal("data_changed")
	queue_redraw()

func _draw() -> void:
	if Utils.editor.hide_gizmos:
		return
	
	draw_power(object_data.running)

func action_get_events() -> Array:
	return ["toggle"] + super.action_get_events()
