@tool
extends Node2D

@export var radius: float: set = set_radius
@export var mode: int
var items: Array

func set_radius(rad):
	radius=rad
	update()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2(), radius, 0, TAU, 64, Color.ORANGE, 2)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var scr: Script = preload("res://Nodes/Editor/Objects/EditorItemPlacer.gd")
	var pixel_map := Utils.game.map.pixel_map
	
	items.append_array(get_children())
	
	for item in items:
		var node: Node2D
		
		if item is PackedScene:
			node = item.instantiate()
		elif item is Node2D:
			node = item
		else:
			node = Pickup.instantiate(item.id)
			node.id = item.id
			node.data = item.get("data")
			node.amount = item.amount
		
		for i in 1000:
			node.position = Utils.clamp_to_pixel_map(position + Utils.random_point_in_circle(radius), pixel_map)
			
			match mode:
				scr.BURIED:
					if pixel_map.isCircleSolid(node.position, max(12 - i / 100, 1), Utils.item_placer_mask, false):
						if Utils.game.map.pixel_map.material_data.get_material_durability(Utils.get_pixel_material(pixel_map.get_pixel_at(node.position))) < 50:
							break
				scr.OPEN:
					if not pixel_map.is_pixel_solid(node.position):
						break
				scr.ANY:
					var mat: int = Utils.get_pixel_material(pixel_map.get_pixel_at(node.position))
					if Utils.item_placer_mask & 1 << mat and Utils.game.map.pixel_map.material_data.get_material_durability(mat) < 50:
						break
		
		if node.is_inside_tree():
			Utils.remove_from_tracker(node, false)
			remove_child(node)
		
		Utils.game.map.call_deferred("add_child", node)
		
	queue_free()
