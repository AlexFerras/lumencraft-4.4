@tool
extends EditorObject

func _init_data():
	defaults.count = 100
	defaults.radius = 50

func _configure(editor):
	create_numeric_input(editor, "Count", "count", 1, 3000, true)
	editor.set_range_control(create_numeric_input(editor, "Radius", "radius", 1, 512, true))

func _refresh():
	queue_redraw()

func _draw() -> void:
	if Utils.editor.hide_gizmos:
		return
	
	var string := str(object_data.count)
	draw_string(preload("res://Resources/Fonts/Font6.tres"),Vector2.LEFT * string.length() * 2, string, 0, -1, 16, Color.RED)
	draw_arc(Vector2(), object_data.radius, 0, TAU, 32, Color.RED, 2)
