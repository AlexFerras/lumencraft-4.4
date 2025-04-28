extends Node

@onready var map: Map = get_parent()

@export var is_ready: bool

func _ready() -> void:
	assert(map, "Where map")
	set_deferred("is_ready", true)

func _config_map(config: Dictionary):
	pass

## Wykonuje się tylko raz.
func _enter_map():
	pass

func _game_start():
	pass

func _gameplay_start():
	pass

func _try_exit() -> bool:
	return true
