extends Area2D
class_name PlayerDetector

@export var once := true

signal player_entered(player)
signal player_exited(player)

func _ready() -> void:
	collision_layer = 0
	collision_mask = Const.PLAYER_COLLISION_LAYER
	connect("area_entered", Callable(self, "on_enter"))
	connect("area_exited", Callable(self, "on_exit"))

func on_enter(area: Area2D):
	var player := Player.get_from_area(area)
	if player:
		emit_signal("player_entered", player)

func on_exit(area: Area2D):
	var player := Player.get_from_area(area)
	if player:
		emit_signal("player_exited", player)
	
	if once:
		queue_free()
