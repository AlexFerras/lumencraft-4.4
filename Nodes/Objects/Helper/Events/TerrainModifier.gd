extends Node2D

@export var shape: int
@export var size: Vector2
@export var radius: float

var editor = load("res://Nodes/Editor/Objects/EditorTerrainModifier.gd")
var rectangle = preload("res://Resources/Textures/1px.png").get_data()
var circle = preload("res://Scenes/Editor/ShapeCircle.png").get_data()

func execute_action(action: String, data: Dictionary):
	match action:
		"fill":
			match shape:
				editor.RECTANGLE:
					Utils.game.map.pixel_map.update_material_mask_rotated(global_position, rectangle, data.material, Vector3(size.x, size.y, rotation))
				editor.CIRCLE:
					Utils.game.map.pixel_map.update_material_circle(global_position, radius, data.material)
		"erase":
			match shape:
				editor.RECTANGLE:
					Utils.game.map.pixel_map.update_material_mask_rotated(global_position, rectangle, Const.Materials.EMPTY, Vector3(size.x, size.y, rotation))
				editor.CIRCLE:
					Utils.game.map.pixel_map.update_material_mask(global_position, circle, Const.Materials.EMPTY, (radius * 2 + 2) / circle.get_size().x)
