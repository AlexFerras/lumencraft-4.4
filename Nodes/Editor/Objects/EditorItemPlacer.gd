@tool
extends "res://Nodes/Editor/Objects/EditorItemContainer.gd"

enum {BURIED, OPEN, ANY}

func _init_data():
	defaults.radius = 30
	defaults.mode = BURIED
	super._init_data()

func _configure(editor):
	editor.set_range_control(create_numeric_input(editor, "Radius", "radius", 1, 1000, true))
	
	var hbox := HBoxContainer.new()
	var label := Label.new()
	label.text = "Mode"
	hbox.add_child(label)
	
	var options := OptionButton.new()
	options.add_item("Buried", BURIED)
	options.add_item("Open Space", OPEN)
	options.add_item("Any", ANY)
	options.select(object_data.mode)
	options.connect("item_selected", Callable(self, "on_selected"))
	hbox.add_child(options)
	
	editor.add_object_setting(hbox)
	editor.add_object_setting(HSeparator.new())
	
	super._configure(editor)

func on_selected(idx: int):
	object_data.mode = idx
	emit_signal("data_changed")

func _refresh():
	queue_redraw()

func _draw() -> void:
	if Utils.editor.hide_gizmos:
		return
	
	draw_arc(Vector2(), object_data.radius, 0, TAU, 32, Color(0, 1, 0, 1), 2)
