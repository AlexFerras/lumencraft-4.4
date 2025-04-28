@tool
extends EditorObject

func _init_data():
	defaults.display_marker = true
	defaults.marker_radius = 100

func _configure(editor):
	create_checkbox(editor, "Display Marker?", "display_marker")
	if object_data.display_marker:
		editor.set_range_control(create_numeric_input(editor, "Marker Radius", "marker_radius", 1, 2048, true))

func _set_object_data_callback(value, field: String):
	super._set_object_data_callback(value, field)
	if field == "display_marker":
		config_dirty = true

func get_data() -> Dictionary:
	if not object_data.display_marker:
		object_data.erase("marker_radius")
	return object_data

func _draw() -> void:
	if object_data.display_marker:
		draw_arc(Vector2(), object_data.marker_radius, 0, TAU, 32, Color(1, 1, 1, 0.25), 2)
