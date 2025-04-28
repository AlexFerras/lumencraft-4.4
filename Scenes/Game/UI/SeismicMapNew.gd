extends Node2D

@onready var minimap=get_parent()

func add_indicator(indicator_coordinates: Vector2,indicator_size: float):
	if get_child_count()<50:
		var boom=preload("res://Scenes/Game/UI/seismic_boom.tscn").instantiate()
		indicator_size = max(indicator_size, 16.0)
		boom.scale*=indicator_size*minimap.get_view_scale()
		boom.position=indicator_coordinates*minimap.get_view_scale()
		add_child(boom)
