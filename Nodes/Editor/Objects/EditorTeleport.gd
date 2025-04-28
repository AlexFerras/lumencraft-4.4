@tool
extends EditorObject

func _init_data():
	defaults.color = 0

func _configure(editor):
	create_numeric_input(editor, "Color", "color", 0, 7)

func _refresh():
	icon.modulate.h = object_data.color * 0.125

func action_get_events() -> Array:
	return ["scoop_players"]
