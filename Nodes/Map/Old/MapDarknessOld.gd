@tool
extends Node2D

var static_material: Material
var dynamic_material: Material

@export var ambient_color := Color.WHITE: set = set_ambient

@onready var viewport := $SubViewport as SubViewport
@onready var ambient := $SubViewport/Ambient as ColorRect

var editor_loaded: bool
var light_map: Dictionary
var editor_data: Dictionary

var enviro: WorldEnvironment

func _ready() -> void:
	if is_nan(get_viewport_rect().size.y):
		return
		# RECHECK
	#viewport.get_texture().flags = Texture2D.FLAG_FILTER
	viewport.size = get_viewport_rect().size
	create_materials()

func set_ambient(amb: Color):
	ambient_color = amb
	
	if not ambient:
		await self.ready
	
	ambient.color = amb

func create_materials():
	static_material = CanvasItemMaterial.new()
	static_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	dynamic_material = preload("res://Nodes/Lights/LightMaterial.tres")

var first = true

func _process(delta: float):
	if not Engine.is_editor_hint() and not Utils.game.map or not visible:
		return
	
	if Engine.is_editor_hint():
		if not viewport:
			viewport = $SubViewport
			viewport.get_texture().flags = Texture2D.FLAG_FILTER | Texture2D.FLAG_MIPMAPS
		if not ambient:
			ambient = $SubViewport/Ambient
		if not enviro:
			enviro = get_tree().edited_scene_root.get_node_or_null("WorldEnvironment")
		if not static_material:
			create_materials()
		
		if not editor_loaded:
			for light in viewport.get_children():
				if light.get_index() <= 1:
					continue
				
				if not light in light_map.values():
					light.queue_free()
			
			editor_loaded = true
	
		var size := viewport.size
		viewport.size = get_viewport().size / get_canvas_transform().get_scale()
	else:
		viewport.canvas_transform = get_canvas_transform()
	# 25 is offset to make sure the border without the ambient is not visible
		ambient.position = -Vector2.ONE*25 -get_canvas_transform().origin / get_canvas_transform().get_scale()
	ambient.size = viewport.size+Vector2.ONE*50
	
	if first and (not Engine.is_editor_hint() or get_tree().edited_scene_root != self):
		var pixel_map: PixelMap
		if not Engine.is_editor_hint():
			pixel_map = Utils.game.map.pixel_map
		else:
			pixel_map = get_tree().get_edited_scene_root().get_node_or_null("PixelMap")
		
		if pixel_map:
			$Darkness.material.set_shader_parameter("map_texture", pixel_map.get_texture())
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			first = false

	var tr := Transform2D()
	tr.origin = get_canvas_transform().origin/ get_canvas_transform().get_scale()

	for light_source in get_tree().get_nodes_in_group("lights"):
		if Engine.is_editor_hint():
			if light_source in editor_data:
				if editor_data[light_source].hash() != get_editor_data(light_source).hash():
					light_map[light_source].free()
					light_map.erase(light_source)
		
		if light_source in light_map:
			update_light(light_source)
		else:
			create_light(light_source)
	
	var invalid: Array
	for light_source in light_map:
		if not is_instance_valid(light_source) or Engine.is_editor_hint() and not light_source.is_inside_tree():
			invalid.append(light_source)
	
	for light_source in invalid:
		light_map[light_source].free()
		light_map.erase(light_source)

func create_light(light_source: LightSprite):
	var light := Sprite2D.new()
	light.texture = light_source.texture
	light.offset = light_source.offset
	light.scale = light_source.scale
	light.global_position = light_source.global_position
	
	if light_source.drop_shadow:
		light.material = dynamic_material.duplicate()
		var pixel_map: PixelMap
		if not Engine.is_editor_hint():
			pixel_map = Utils.game.map.pixel_map
		else:
			pixel_map = get_tree().get_edited_scene_root().get_node_or_null("PixelMap")
		light.material.set_shader_parameter("map_texture", pixel_map.get_texture())
	else:
		light.material = static_material
	
	viewport.add_child(light)
	light_map[light_source] = light
	update_light(light_source)
	
	if Engine.is_editor_hint():
		editor_data[light_source] = get_editor_data(light_source)

func update_light(light_source: LightSprite):
	var light: Sprite2D = light_map[light_source]
	
	if light_source.is_inside_tree():
		if not light_source.is_visible_in_tree() or light_source.get_viewport() != get_viewport():
			light.hide()
			return
		else:
			light.show()
		
		light.scale = light_source.scale
		light.modulate = light_source.modulate
		
		if Engine.is_editor_hint():
			light.global_position = light_source.global_position + get_canvas_transform().get_origin() / get_canvas_transform().get_scale()
		else:
			light.global_position = light_source.global_position
		
		if light_source.follow_rotation:
			light.global_rotation = light_source.global_rotation
	else:
		light.hide()
		return
	
	if light_source.drop_shadow:
		var light_transform := light_source.transform
		if light_source.follow_rotation:
			light_transform = light_transform.rotated(light_source.global_rotation - light_source.rotation)
		light_transform.origin = light_source.global_transform.origin
		light.material.set_shader_parameter("global_transform", light_transform)

func get_canvas_transform_custom() -> Transform2D:
	if Engine.is_editor_hint():
		return get_viewport().global_canvas_transform
	else:
		return get_viewport().canvas_transform

func get_editor_data(light_source: LightSprite) -> Dictionary:
	return {texture = light_source.texture, offset = light_source.offset, drop_shadow = light_source.drop_shadow, follow_rotation = light_source.follow_rotation}
