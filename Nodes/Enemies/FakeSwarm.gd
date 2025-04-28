extends Node2D

var scene: String
var amount: int
var radius: int

func _ready() -> void:
	var swarm = Utils.game.map.swarm_manager.request_swarm(scene)
	swarm.spawn_in_radius_with_delay(position, radius, amount, 0)
	queue_free()
