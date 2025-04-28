@tool
extends EditorObject

func _init_data():
	defaults.autostart = false
	defaults.time = 1.0

func _configure(editor):
	create_numeric_input(editor, "Time (s)", "time")
	
	var checkbox := CheckBox.new()
	editor.add_object_setting(checkbox)
	checkbox.text = "Autostart?"
	checkbox.button_pressed = object_data.get("autostart", false)
	checkbox.connect("toggled", Callable(self, "_set_object_data_callback").bind("autostart"))

func get_condition_list() -> Array:
	return ["finished*"]

func action_get_events() -> Array:
	return ["start", "stop"]
