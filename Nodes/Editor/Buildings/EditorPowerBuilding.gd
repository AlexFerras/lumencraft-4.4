@tool
extends "res://Nodes/Editor/Buildings/EditorBuilding.gd"

@export var radius: float

func _init() -> void:
	can_receive_power = object_name != "Power Expander"

func _draw() -> void:
	if Utils.editor.hide_gizmos:
		return
	
	draw_arc(Vector2(), radius, 0, TAU, 32, Color(1, 1, 0, 0.25), 2)
