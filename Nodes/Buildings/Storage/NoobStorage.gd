extends "res://Nodes/Buildings/Storage/Storage.gd"

@export var difficulted: bool

func _ready() -> void:
	block_excess = true
	
	if not difficulted:
		difficulted = true
		
		stored_lumen = Const.DIFFICULTY_STARTING_RESOURCES[Save.data.difficulty]
		stored_metal = Const.DIFFICULTY_STARTING_RESOURCES[Save.data.difficulty]
		update_fullness()
		update_gui()

func build():
	if Save.data.difficulty >= Const.Difficulty.NORMAL:
		difficulted = true
		queue_free()
		return
	super.build()
