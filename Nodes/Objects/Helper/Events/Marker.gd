extends Node2D

var mode: int

func _ready() -> void:
	if mode & 1:
		add_child(load("res://Nodes/Map/MapMarker/MapMarker.tscn").instantiate())
	
	if mode & 2:
		add_child(load("res://Nodes/Objects/Helper/InGameMarker/InGameMarker.tscn").instantiate())

func execute_action(action: String, data: Dictionary):
	match action:
		"show":
			show()
		"hide":
			hide()
