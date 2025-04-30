@tool
extends Node2D

var static_material: Material

@onready var viewport := $SubViewport as SubViewport

var editor_loaded: bool
var light_map: Dictionary
var editor_data: Dictionary

var enviro: WorldEnvironment

func _ready() -> void:
	#viewport.get_texture().flags = Texture2D.FLAG_FILTER
	viewport.size = get_viewport_rect().size
	create_materials()

func create_materials():
	static_material = CanvasItemMaterial.new()
	static_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

var first = true

func _process(delta: float):
	if not Engine.is_editor_hint() and not Utils.game.map:
		return
	
	if Engine.is_editor_hint():
		if not viewport:
			viewport = $SubViewport
			#viewport.get_texture().flags = Texture2D.FLAG_FILTER | Texture2D.FLAG_MIPMAPS
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
		if first:
			var size := viewport.size
			viewport.size = get_viewport().size / get_canvas_transform().get_scale()
	else:
		viewport.canvas_transform = get_canvas_transform()
		
	# 25 is offset to make sure the border without the ambient is not visible
#		ambient.rect_position = -Vector2.ONE*25 -get_canvas_transform().origin / get_canvas_transform().get_scale()
#	ambient.rect_size = viewport.size+Vector2.ONE*50
	
	if first and (not Engine.is_editor_hint() or get_tree().edited_scene_root != self):
		var pixel_map: PixelMap
		if not Engine.is_editor_hint():
			pixel_map = Utils.game.map.pixel_map
		else:
			pixel_map = get_tree().get_edited_scene_root().get_node_or_null("PixelMap")
		
		if pixel_map:
			$LightHalo.material.set_shader_parameter("map_texture", pixel_map.get_texture())
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			first = false

	var tr := Transform2D()
	tr.origin = get_canvas_transform().origin/ get_canvas_transform().get_scale()

	for halo in get_tree().get_nodes_in_group("halo"):
		if Engine.is_editor_hint():
			if halo in editor_data:
				if editor_data[halo].hash() != get_editor_data(halo).hash():
					light_map[halo].free()
					light_map.erase(halo)
		
		if halo in light_map:
			update_light(halo)
		else:
			create_light(halo)
	
	var invalid: Array
	for halo in light_map:
		if not is_instance_valid(halo) or Engine.is_editor_hint() and not halo.is_inside_tree():
			invalid.append(halo)
	
	for halo in invalid:
		light_map[halo].free()
		light_map.erase(halo)

func create_light(halo: LightHalo):
	var light := Sprite2D.new()
	light.texture = halo.texture
	light.offset = halo.offset
	light.scale = halo.scale
	light.global_position = halo.global_position
	light.material = static_material
	
	viewport.add_child(light)
	light_map[halo] = light
	update_light(halo)
	
	if Engine.is_editor_hint():
		editor_data[halo] = get_editor_data(halo)

func update_light(halo: LightHalo):
	var light: Sprite2D = light_map[halo]
	
	if halo.is_inside_tree():
		if not halo.is_visible_in_tree() or halo.get_viewport() != get_viewport():
			light.hide()
			return
		else:
			light.show()
		
		light.scale = halo.scale
		light.modulate = halo.modulate
		
		if Engine.is_editor_hint():
			light.global_position = halo.global_position + get_canvas_transform().get_origin() / get_canvas_transform().get_scale()
		else:
			light.global_position = halo.global_position
		
		if halo.follow_rotation:
			light.global_rotation = halo.global_rotation
	else:
		light.hide()
		return

func get_canvas_transform_custom() -> Transform2D:
	if Engine.is_editor_hint():
		return get_viewport().global_canvas_transform
	else:
		return get_viewport().canvas_transform

func get_editor_data(halo: LightHalo) -> Dictionary:
	return {texture = halo.texture, offset = halo.offset, follow_rotation = halo.follow_rotation}
