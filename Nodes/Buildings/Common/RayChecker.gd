@tool
extends Node2D
var end: Node2D
@export var checked_material= Const.Materials.WALL
func _ready() -> void:
	if get_child_count() == 1:
		end = get_child(0)
	else:
		get_tree().connect("idle_frame", Callable(self, "create_end").bind(), CONNECT_ONE_SHOT)

func create_end():
	if owner and get_child_count() == 0:
		end = Node2D.new()
		end.name = "End"
		end.position = Vector2.RIGHT * 100
		add_child(end)
		end.owner = owner

func get_raycast() -> RayCastResultData:
	if checked_material == -1:
		return Utils.game.map.pixel_map.rayCastQTFromTo(global_position, end.global_position)
	else:
		return Utils.game.map.pixel_map.rayCastQTFromTo(global_position, end.global_position, 1 << checked_material)
