extends Node2D

var static_light_material: Material
var dynamic_light_material: Material
var shadow_material: Material

@export var ambient_color := Color.WHITE: set = set_ambient

@onready var light_viewport := $ViewportLight as SubViewport
@onready var VP_light_camera := $ViewportLight/Camera2D as Camera2D
@onready var ambient := $ViewportLight/Ambient as ColorRect

@onready var shadow_viewport := $ViewportLight/ViewportShadow as SubViewport
@onready var VP_shadow_camera := $ViewportLight/ViewportShadow/Camera2D as Camera2D

var editor_loaded: bool
var light_map: Dictionary
var shadow_map: Dictionary
var editor_light_data: Dictionary
var editor_shadow_data: Dictionary

var enviro: WorldEnvironment

var timer := 0.0

var run_only_once := true
signal viewports_resized 

func _ready() -> void:
	if Music.is_switch_build():
		return
	
	get_viewport().connect("size_changed", Callable(self, "on_window_resized"))
	#light_viewport.get_texture().flags = Texture2D.FLAG_FILTER
	#shadow_viewport.get_texture().flags = Texture2D.FLAG_FILTER
	on_window_resized()
	create_materials()
	visible = true
	
func set_ambient(amb: Color):
	ambient_color = amb
	if not ambient:
		await self.ready
	
	if ambient:
		ambient.color = amb

func create_materials():
	static_light_material = CanvasItemMaterial.new()
	static_light_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	dynamic_light_material = preload("res://Nodes/Lights/LightMaterial_new.tres")
	shadow_material  = preload("res://Nodes/Lights/ShadowMaterial.tres")

func on_window_resized():
	if is_nan(get_viewport_rect().size.y) or Music.is_switch_build():
		return

	var new_veiport_size = (get_viewport_rect().size + Vector2.ONE * 4)
	light_viewport.size  = new_veiport_size / Save.config.downsample + Vector2.ONE * 4
	shadow_viewport.size = new_veiport_size / Save.config.downsample + Vector2.ONE * 4
		
	update_viewports()
	$Darkness.update_properites()
	$Darkness.queue_redraw()
	emit_signal("viewports_resized")

func only_once():
	if (not Engine.is_editor_hint() or get_tree().edited_scene_root != self):
		var pixel_map: PixelMap
		if not Engine.is_editor_hint():
			pixel_map = Utils.game.map.pixel_map
		else:
			pixel_map = get_tree().get_edited_scene_root().get_node_or_null("PixelMap")
		if pixel_map:
			$Darkness.material.set_shader_parameter("map_texture", pixel_map.get_texture())
			$ViewportLight/ViewportShadow/Map.texture = pixel_map.get_texture()
			
			light_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			run_only_once = false

func only_in_editor():
	if not light_viewport:
		light_viewport = $ViewportLight
		# RECHECK
		#light_viewport.get_texture().flags = Texture2D.FLAG_FILTER | Texture2D.FLAG_MIPMAPS
		VP_light_camera = $ViewportLight/Camera2D
	if not shadow_viewport:
		shadow_viewport = $ViewportShadow
		# RECHECK
		#shadow_viewport.get_texture().flags = Texture2D.FLAG_FILTER | Texture2D.FLAG_MIPMAPS
		VP_shadow_camera = $ViewportShadow/Camera2D
		# no mipmaps in Godot 3.4 yet

	if not ambient:
		ambient = $ViewportLight/Ambient
	if not enviro:
		enviro = get_tree().edited_scene_root.get_node_or_null("WorldEnvironment")
	if not static_light_material:
		create_materials()

	if not editor_loaded:
		for light in light_viewport.get_children():
			if light.get_index() <= 2:
				continue
			
			if not light in light_map.values():
				light.queue_free()
		for shadow in shadow_viewport.get_children():
			if shadow.get_index() <=1:
				continue
			
			if not shadow in shadow_map.values():
				shadow.queue_free()
		editor_loaded = true

#		light_viewport.size = get_viewport().size / get_canvas_transform().get_scale() / Save.config.downsample
#		shadow_viewport.size = get_viewport().size / get_canvas_transform().get_scale() / Save.config.shadow_downsample

	VP_light_camera.global_position = get_canvas_transform().origin + get_viewport().size * 0.5
	VP_light_camera.zoom = VP_light_camera.transform.get_scale()

	VP_shadow_camera.position = shadow_viewport.size * 0.5

func _process(delta: float):
	if not Engine.is_editor_hint() and not Utils.game.map:
		return
		
	if run_only_once:
		only_once()
		update_light_material()
		
	if Engine.is_editor_hint():
		only_in_editor()
	else:
		update_viewports()
	
	process_shadows()
	
	process_lights()

func update_viewports():
#	light_viewport.canvas_transform = get_canvas_transform()
#	shadow_viewport.canvas_transform = get_canvas_transform()
	
	if is_nan(Utils.game.camera.get_screen_center_position().y) or is_nan(get_viewport_rect().size.y):
		return
	VP_light_camera.transform = Utils.game.camera.transform
	VP_light_camera.global_position = Utils.game.camera.get_screen_center_position()
	VP_light_camera.zoom = Utils.game.camera.zoom * Save.config.downsample
	
	VP_shadow_camera.transform = Utils.game.camera.transform
	VP_shadow_camera.global_position = Utils.game.camera.get_screen_center_position() 
	VP_shadow_camera.zoom = Utils.game.camera.zoom * Save.config.downsample

	ambient.position = Utils.game.camera.get_screen_center_position() - get_viewport_rect().size * 0.5 * Utils.game.camera.zoom
	ambient.size = get_viewport_rect().size * Utils.game.camera.zoom

	
func process_shadows():
	for shadow_source in get_tree().get_nodes_in_group("shadow"):
		if Engine.is_editor_hint():
			if shadow_source in editor_shadow_data:
				if editor_shadow_data[shadow_source].hash() != get_editor_shadow_data(shadow_source).hash():
					shadow_map[shadow_source].free()
					shadow_map.erase(shadow_source)

		if shadow_source in shadow_map:
			update_shadow(shadow_source)
		else:
			create_shadow(shadow_source)

	var invalid: Array
	for shadow_source in shadow_map:
		if not is_instance_valid(shadow_source) or Engine.is_editor_hint() and not shadow_source.is_inside_tree():
			invalid.append(shadow_source)
	
	for shadow_source in invalid:
		shadow_map[shadow_source].free()
		shadow_map.erase(shadow_source)
		
func process_lights():
	for light_source in get_tree().get_nodes_in_group("lights"):
		if Engine.is_editor_hint():
			if light_source in editor_light_data:
				if editor_light_data[light_source].hash() != get_editor_light_data(light_source).hash():
					light_map[light_source].free()
					light_map.erase(light_source)
		else:
			if light_source.is_static and not light_source.dirty:
				continue
			light_source.dirty = false

		if light_source in light_map:
			update_light(light_source)
		else:
			create_light(light_source)
	
	var invalid = []
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
	light.global_rotation = light_source.global_rotation

	if light_source.drop_shadow:
		light.material = dynamic_light_material.duplicate()
		var pixel_map: PixelMap
		if not Engine.is_editor_hint():
			pixel_map = Utils.game.map.pixel_map
		else:
			pixel_map = get_tree().get_edited_scene_root().get_node_or_null("PixelMap")
		light.material.set_shader_parameter("map_texture", shadow_viewport.get_texture())
	else:
		light.material = static_light_material
	
	light_viewport.add_child(light)
	light_map[light_source] = light
	update_light(light_source)
	
	if Engine.is_editor_hint():
		editor_light_data[light_source] = get_editor_light_data(light_source)
	
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
		light.self_modulate = light_source.self_modulate
		
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
		light.material.set_shader_parameter("global_transform", light_source.global_transform )

func update_light_material():
	var long:int = Save.config.shadow_render_steps * 4
	var short:int = max( 1, Save.config.shadow_render_steps - 2 ) * 2
	dynamic_light_material.set_shader_parameter("NUM_SAMPLES", long)
	dynamic_light_material.set_shader_parameter("NUM_SAMPLES_SHORT", short)
#	prints(long,short)

func update_lights_materials_render_steps():
	var long:int = Save.config.shadow_render_steps * 4
	var short:int = max( 1, Save.config.shadow_render_steps - 2 ) * 2
	dynamic_light_material.set_shader_parameter("NUM_SAMPLES", long)
	dynamic_light_material.set_shader_parameter("NUM_SAMPLES_SHORT", short)
	
	if light_map.is_empty():
		return
	
	for light in get_tree().get_nodes_in_group("lights"):
		if light.is_static:
			continue
		if light.drop_shadow:
			light_map[light].material.set_shader_parameter("NUM_SAMPLES", long )
			light_map[light].material.set_shader_parameter("NUM_SAMPLES_SHORT", short )

func create_shadow(shadow_source: Shadow):
	var shadow := Sprite2D.new()

	shadow.material = shadow_material
	shadow_viewport.add_child(shadow)
	shadow_map[shadow_source] = shadow
	update_shadow(shadow_source)

	if Engine.is_editor_hint():
		editor_shadow_data[shadow_source] = get_editor_shadow_data(shadow_source)

func update_shadow(shadow_source: Shadow):
	var shadow: Sprite2D = shadow_map[shadow_source]
	
	if shadow_source.is_inside_tree():
		if not shadow_source.is_visible_in_tree() or shadow_source.get_viewport() != get_viewport():
			shadow.hide()
			return
		else:
			shadow.show()
		
		if Engine.is_editor_hint():
			shadow.global_position = shadow_source.global_position + get_canvas_transform().get_origin() / get_canvas_transform().get_scale()
		else:
			shadow.global_position = shadow_source.global_position
		
		shadow.texture = shadow_source.texture
		shadow.offset  = shadow_source.offset
		shadow.scale   = shadow_source.global_scale
		shadow.hframes = shadow_source.hframes
		shadow.vframes = shadow_source.vframes
		shadow.frame   = shadow_source.frame
		shadow.modulate = shadow_source.modulate
		shadow.global_rotation = shadow_source.global_rotation
		shadow.flip_h = shadow_source.flip_h
	else:
		shadow.hide()
		return

func get_canvas_transform_custom() -> Transform2D:
	if Engine.is_editor_hint():
		return get_viewport().global_canvas_transform
	else:
		return get_viewport().canvas_transform

func get_editor_light_data(light_source: LightSprite) -> Dictionary:
	return {texture = light_source.texture, offset = light_source.offset, drop_shadow = light_source.drop_shadow, follow_rotation = light_source.follow_rotation}

func get_editor_shadow_data(shadow_source: Shadow) -> Dictionary:
	return {texture = shadow_source.texture, offset = shadow_source.offset}

func get_light_node_count() -> int:
	return light_viewport.get_child_count() - 3

func get_shadow_node_count() -> int:
	return shadow_viewport.get_child_count() - 2
	
func get_light_node_count_2() -> int:
	return get_tree().get_nodes_in_group("lights").size()

func get_shadow_node_count_2() -> int:
	return get_tree().get_nodes_in_group("shadow").size()

#func get_static_light_node_count() -> int:
#	var static_count := 0
#	for node in light_viewport.get_children():
#		if node is Sprite and node.is_static:
#			static_count +=1
#	return static_count
#
#func get_static_shadow_node_count() -> int:
#	var static_count := 0
#	for node in shadow_viewport.get_children():
#		if node is Sprite and node.is_static:
#			static_count +=1
#	return static_count
