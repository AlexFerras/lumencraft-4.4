extends Area2D

func _ready() -> void:
	connect("area_entered", Callable(self, "enter"))

func enter(area: Area2D):
	if Player.get_from_area(area):
		Utils.play_sample(Utils.random_sound("res://SFX/Bullets/bullet_flyby_fast_"), self)
		queue_free()
