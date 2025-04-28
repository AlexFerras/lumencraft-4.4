@tool
extends EditorObject

var can_receive_power := true

func _init_data():
	defaults.ignored_by_enemies = false
	defaults.health = Const.Buildings[object_name].max_hp

func _configure(editor):
	create_checkbox(editor, "Ignored by Enemies?", "ignored_by_enemies")
	create_numeric_input(editor, "Health", "health", 1, Const.Buildings[object_name].max_hp)

func _has_point(p: Vector2) -> bool:
	var bounding: Sprite2D = icon.bounding_rect
	var size: Vector2 = bounding.global_scale
	return has_rotated_point(p, Rect2(bounding.global_position - size * 0.5, size), rotation)

func _draw_rect(canvas: CanvasItem, color: Color):
	var bounding: Sprite2D = icon.bounding_rect
	var size: Vector2 = bounding.global_scale
	draw_rotated_rect(canvas, Rect2(bounding.global_position - size * 0.5, size), rotation, color)

func draw_power(power: bool):
	var power_icon := preload("res://Nodes/Editor/Icons/Power.png")
	var power_size := power_icon.get_size() * Vector2(0.5, 1)
	draw_texture_rect_region(power_icon, Rect2(-power_size * 0.25, power_size * 0.5), Rect2(power_size * int(power) * Vector2(1, 0), power_size))

func _draw() -> void:
	if Utils.editor.hide_gizmos:
		return
	
	if object_data.get("ignored_by_enemies", false):
		var ignore := preload("res://Nodes/Editor/Icons/EnemyIgnore.png")
		draw_texture_rect(ignore, Rect2(-ignore.get_size() * 0.25, ignore.get_size() * 0.5), false)

func get_condition_list() -> Array:
	var conditions := super.get_condition_list() + ["destroyed"]
	if can_receive_power:
		conditions.append("power_received*")
	return conditions

func action_get_events() -> Array:
	return ["destroy"]
