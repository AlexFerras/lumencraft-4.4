@tool
extends EditorObject

enum {RECTANGLE, CIRCLE}

var event_terrain_list: OptionButton

func _init() -> void:
	can_rotate = true

func _init_data():
	defaults.shape = RECTANGLE
	defaults.width = 64
	defaults.height = 32
	defaults.radius = 32

func _configure(editor):
	var type_select := OptionButton.new()
	type_select.add_item("Rectangle")
	type_select.add_item("Circle")
	type_select.selected = object_data.shape
	type_select.connect("item_selected", Callable(self, "set_shape"))
	editor.add_object_setting(type_select)
	
	match object_data.shape:
		RECTANGLE:
			create_numeric_input(editor, "Width", "width")
			create_numeric_input(editor, "Height", "height")
		CIRCLE:
			create_numeric_input(editor, "Radius", "radius")

func set_shape(idx: int):
	object_data.shape = idx
	config_dirty = true
	queue_redraw()
	emit_signal("data_changed")

func get_data() -> Dictionary:
	var data := {shape = object_data.shape}
	match object_data.shape:
		RECTANGLE:
			data.width = object_data.width
			data.height = object_data.height
		CIRCLE:
			data.radius = object_data.radius
	return data

func _draw() -> void:
	if Utils.editor.hide_gizmos:
		return
	
	match object_data.shape:
		RECTANGLE:
			draw_rect(Rect2(-object_data.width / 2, -object_data.height / 2, object_data.width, object_data.height), Color.ORANGE, false, 2)
		CIRCLE:
			draw_arc(Vector2(), object_data.radius, 0, TAU, 16, Color.ORANGE, 2)

func action_get_events() -> Array:
	return ["fill", "erase"]

func get_additional_config(editor, condition_action: String) -> Control:
	if condition_action == "fill":
		event_terrain_list = OptionButton.new()
		for mat in Utils.editor.get_terrains():
			event_terrain_list.add_item(mat.name)
			event_terrain_list.set_item_metadata(event_terrain_list.get_item_count() - 1, mat.id)
		editor.register_data("material", Callable(self, "set_selected_material"), Callable(event_terrain_list, "get_selected_metadata"))
		return event_terrain_list
	
	return null

func set_selected_material(mat: int):
	for i in event_terrain_list.get_item_count():
		if event_terrain_list.get_item_metadata(i) == mat:
			event_terrain_list.selected = i
			break
