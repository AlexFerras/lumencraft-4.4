@tool
extends Node2D

@export var radius = 10: set = set_radius
@export var editor_only := false

func _ready() -> void:
	if editor_only and not Engine.is_editor_hint():
		queue_free()

func set_radius(r: int):
	radius = r
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(), radius, Color.WHITE)
