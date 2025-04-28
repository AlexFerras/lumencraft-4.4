@tool
extends "res://Nodes/Editor/Objects/EditorItemContainer.gd"

func _init_data():
	super._init_data()
	defaults.open = false

func _configure(editor):
	create_checkbox(editor, "Open?", "open")
	super._configure(editor)

func get_condition_list() -> Array:
	return ["opened*"]

func action_get_events() -> Array:
	return ["open", "close"]

func _draw() -> void:
	if Utils.editor.hide_gizmos:
		return
	
	if not get_value("open"):
		draw_icon(preload("res://Maps/Campaign/HubNodes/Locked.png"), Vector2(10, 10), Const.UI_MAIN_COLOR)
