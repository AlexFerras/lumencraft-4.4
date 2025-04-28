@tool
extends "res://Nodes/Editor/Buildings/EditorBuilding.gd"

func _init_data():
	super._init_data()
	defaults.open = false

func _configure(editor):
	super._configure(editor)
	create_checkbox(editor, "Open?", "open")

func _draw() -> void:
	if Utils.editor.hide_gizmos:
		return
	
	if not object_data.open:
		draw_icon(preload("res://Maps/Campaign/HubNodes/Locked.png"), Vector2(10, 10), Const.UI_MAIN_COLOR)

func action_get_events() -> Array:
	var actions := super.action_get_events()
	actions.append_array(["open", "close"])
	return actions
