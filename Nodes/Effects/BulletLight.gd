extends LightSprite

@export var min_scale: float = 0.1
@export var max_scale: float = 0.2

func _ready() -> void:
	var seq := create_tween().set_loops().tween_method(Callable(self, "random_scale"), 1, 1, 1)
	random_scale(1)

func random_scale(s):
	scale = Vector2.ONE * randf_range(min_scale, max_scale)
