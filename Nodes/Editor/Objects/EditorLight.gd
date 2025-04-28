@tool
extends EditorObject

func _init_data():
	defaults.radius = 32
	defaults.color = Color.WHITE
	defaults.shadow = false
	defaults.enabled = true
	defaults.reveal_fog = false

func _configure(editor):
	editor.set_range_control(create_numeric_input(editor, "Radius", "radius", 1, 512, true))
	
	var hbox := HBoxContainer.new()
	
	var label := Label.new()
	label.text = "Color"
	hbox.add_child(label)
	
	var color := ColorPickerButton.new()
	color.color = object_data.color
	color.edit_alpha = false
	color.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color.connect("color_changed", Callable(self, "_set_object_data_callback").bind("color"))
	hbox.add_child(color)
	
	editor.add_object_setting(hbox)
	
	create_checkbox(editor, "Drop shadows?", "shadow")
	create_checkbox(editor, "Enabled?", "enabled")
	create_checkbox(editor, "Reveal Fog of War?", "reveal_fog")

func _draw() -> void:
	if Utils.editor.hide_gizmos:
		icon.hide()
		return
	
	icon.show()
	
	var color = object_data.color
	color.a = 0.5 if object_data.enabled else 0.25
	draw_arc(Vector2(), object_data.radius, 0, TAU, 16, color, 2)

func action_get_events() -> Array:
	return ["toggle"]
