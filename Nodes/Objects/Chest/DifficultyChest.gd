extends "res://Nodes/Objects/Chest/Chest.gd"

@export var difficulted: bool

func _enter_tree() -> void:
	if not difficulted:
		difficulted = true
		pickups.append({id = Const.ItemIDs.LUMEN, amount = Const.DIFFICULTY_STARTING_RESOURCES[Save.data.difficulty]})
		pickups.append({id = Const.ItemIDs.METAL_SCRAP, amount = Const.DIFFICULTY_STARTING_RESOURCES[Save.data.difficulty]})
		
func _ready() -> void:
	if Save.data.difficulty >= Const.Difficulty.NORMAL:
		queue_free()
