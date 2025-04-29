@tool
extends "res://Nodes/Editor/Buildings/EditorPowerBuilding.gd"

func _ready() -> void:
	for object in get_parent().get_children():
		if object != self and object.object_name == object_name:
			object.destroy()
			return

func _init_data():
	super._init_data()
	radius = 150
	defaults.running = true
#	defaults.radius = 350
	defaults.disable_zap = false
	defaults.chunk_slots = 0
	defaults.reactor_level = 1
	defaults.enabled_screens = 15

func _configure(editor):
	super._configure(editor)
	
#	var checkbox := CheckBox.new()
#	checkbox.text = "Running?"
#	checkbox.pressed = object_data.running
#	checkbox.connect("toggled", self, "set_running")
#	editor.add_object_setting(checkbox)
	
#	editor.set_range_control(create_numeric_input(editor, "Radius", "radius", 1, 1000, true))
	
	var checkbox := CheckBox.new()
	checkbox.text = "Disable zap?"
	checkbox.button_pressed = object_data.get("disable_zap", false)
	checkbox.connect("toggled", Callable(self, "set_zap"))
	editor.add_object_setting(checkbox)
	
	create_numeric_input(editor, "Reactor Level", "reactor_level", 1, 50)
	create_numeric_input(editor, "Chunk Slots", "chunk_slots", 0, 3)
	
	var hbox := HBoxContainer.new()
	
	var label := Label.new()
	hbox.add_child(label)
	label.text = "Enabled Screens"
	
	for i in 4:
		checkbox = CheckBox.new()
		hbox.add_child(checkbox)
		checkbox.button_pressed = object_data.enabled_screens & (1 << i)
		checkbox.connect("toggled", Callable(self, "set_enabled_screen").bind(i))
	
	editor.add_object_setting(hbox)

func set_running(r: bool):
	object_data.running = r
	emit_signal("data_changed")
	queue_redraw()

func set_enabled_screen(enabled: bool, idx: int):
	if enabled:
		object_data.enabled_screens |= (1 << idx)
	else:
		object_data.enabled_screens &= ~(1 << idx)
	emit_signal("data_changed")

func set_zap(z: bool):
	object_data.disable_zap = z
	emit_signal("data_changed")

func _draw() -> void:
	if Utils.editor.hide_gizmos:
		return
	
	draw_power(object_data.running)

func _set_object_data_callback(value, field: String):
	if not "radius" in object_data and field == "reactor_level":
		radius = 150 + (value - 1) * 40
	super._set_object_data_callback(value, field)

func get_condition_list() -> Array:
	var conditions := super.get_condition_list()
	conditions.append("lumen_chunk_delivered*")
	return conditions
