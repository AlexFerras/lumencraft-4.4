@tool
extends "res://Nodes/Editor/Buildings/EditorBuilding.gd"

func _init_data():
	super._init_data()
	defaults.level = 0

func _configure(editor):
	super._configure(editor)
	create_numeric_input(editor, "Upgrade Level", "level", 0, 3)
