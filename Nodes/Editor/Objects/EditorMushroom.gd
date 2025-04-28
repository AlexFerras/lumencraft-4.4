@tool
extends EditorObject

var scale_slider: Slider
var max_growth_slider: Slider

func _init_data():
	defaults.random = false
	defaults.scale = 1.0
	defaults.max_growth = 1.0

func _on_placed():
	call_deferred("update_scale")

func _configure(editor):
	var checkbox := CheckBox.new()
	checkbox.text = "Random?"
	checkbox.button_pressed = object_data.random
	checkbox.connect("toggled", Callable(self, "random_toggled"))
	editor.add_object_setting(checkbox)
	
	scale_slider = create_numeric_input(editor, "Scale", "scale", 0.2, 1.5, true)
	scale_slider.step = 0.1
	
	max_growth_slider = create_numeric_input(editor, "Max Growth", "scale", 0.2, 1.5, true)
	max_growth_slider.step = 0.1

func random_toggled(value):
	object_data.random = value
	scale_slider.get_parent().editable = not object_data.random
	max_growth_slider.get_parent().editable = not object_data.random
	emit_signal("data_changed")

func _set_object_data_callback(value, field: String):
	super._set_object_data_callback(value, field)
	update_scale()

func update_scale():
	scale = Vector2.ONE * object_data.scale
	if is_instance_valid(max_growth_slider):
		max_growth_slider.min_value = scale_slider.value
