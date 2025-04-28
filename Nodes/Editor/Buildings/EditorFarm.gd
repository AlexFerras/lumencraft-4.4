@tool
extends "res://Nodes/Editor/Buildings/EditorBuilding.gd"

func _init_data():
	super._init_data()
	defaults.mushrooms = 1
	defaults.speed = 0

func _configure(editor):
	super._configure(editor)
	create_numeric_input(editor, "Mushroom Count", "mushrooms", 1, 4)
	create_numeric_input(editor, "Growth Speed", "speed", 0, 4)
