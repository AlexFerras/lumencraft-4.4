@tool
extends "res://Nodes/Editor/Objects/EditorItemContainer.gd"

func _init_data():
	defaults.disable_physics = false
	super._init_data()

func _configure(editor):
	create_checkbox(editor, "Disable physics?", "disable_physics")
	super._configure(editor)
