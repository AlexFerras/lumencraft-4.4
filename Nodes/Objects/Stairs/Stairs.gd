extends Area2D

@export var down: bool
@export var target_map: String
@export var id: int

@onready var label := $Label as Label

var player_in: bool

func _ready() -> void:
	connect("area_entered", Callable(self, "stairs_enter"))
	connect("area_exited", Callable(self, "stairs_exit"))
	
	if down:
		$Sprite2D.frame = 1

func stairs_enter(area: Area2D) -> void:
	if area.has_meta("player"):
		area.get_parent().interactables.append(self)
		
		if area.get_parent().interactables.size() == 1:
			player_in = true

func stairs_exit(area: Area2D) -> void:
	if not is_instance_valid(area):
		return
	
	if area.has_meta("player"):
		area.get_parent().interactables.erase(self)
		player_in = false

func interact():
	Utils.game.call_deferred("goto_map", target_map)
	Utils.game.stairs_id = id
