extends Node2D

@export var texture: Texture2D
@export var arrow: Texture2D
@export var max_radius: float
@export var rotate_arrow: bool = true
@export var circle_radius: float =0.0

func _ready() -> void:
	if get_parent() is BaseEnemy:
		get_parent().connect("died", Callable(self, "queue_free"))
