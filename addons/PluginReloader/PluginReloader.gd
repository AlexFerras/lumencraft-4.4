@tool
extends EditorPlugin

func _unhandled_key_input(event: InputEvent) -> void:
	if event.keycode == KEY_F12 and event.pressed:
		var plugin_to_toggle = "DataExplorer"
		get_editor_interface().set_plugin_enabled(plugin_to_toggle, false)
		get_editor_interface().set_plugin_enabled(plugin_to_toggle, true)
