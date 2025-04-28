@tool
extends Node2D
class_name LightHalo

@export var texture: Texture2D
@export var offset: Vector2
@export var follow_rotation: bool

func _enter_tree() -> void:
	add_to_group("halo")
