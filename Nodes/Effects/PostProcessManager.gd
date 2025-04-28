@tool

extends Sprite2D
var range_dirty = true: set = set_dirty
var pernament_range_dirty = false

var shock_data : PackedVector2Array
var dirty=true

func set_dirty(d):
	range_dirty = d
	if Utils.game.map.cheap_range:
		Utils.game.map.cheap_range.update()

func _ready() -> void:
	add_to_group("dont_save")
	if Music.is_switch_build():
		set_process(false)
		hide()
	
											#xyz color mul, z =tail speed
func add_shockwave(pos:Vector2, radius:float, col = Color(1,1,1,1)):
	shock_data.append(Vector2(pos.x,pos.y))
	shock_data.append(Vector2(radius,Time.get_ticks_msec()*0.001))
	shock_data.append(Vector2(col[0],col[1]))
	shock_data.append(Vector2(col[2],col[3]))
	get_tree().create_timer(5).connect("timeout", Callable(self, "remove_first"))
	dirty=true
	
func remove_first():
	shock_data.remove(0)
	shock_data.remove(0)
	shock_data.remove(0)
	shock_data.remove(0)
	dirty=true

func get_viewport2() -> SubViewport:
	if Engine.is_editor_hint():
		return get_tree().get_edited_scene_root().get_viewport()
	else:
		return get_viewport()

func get_canvas_transform() -> Transform2D:
	if Engine.is_editor_hint():
		return get_tree().get_edited_scene_root().get_viewport().global_canvas_transform
	else:
		return get_viewport().canvas_transform

var last_reveal_time=0.5
func start_build_mode(reveal_from:Vector2):
	if Utils.game.map.cheap_range:
		Utils.game.map.cheap_range.active = true
		return
	
	pernament_range_dirty=true
	if not material.get_shader_parameter("build_mode"):
		material.set_shader_parameter("reveal_center",reveal_from)
		last_reveal_time=Time.get_ticks_msec()*0.001
		material.set_shader_parameter("reveal_time",last_reveal_time)
		material.set_shader_parameter("build_mode",true)

func stop_build_mode(reveal_from:Vector2):
	if Utils.game.map.cheap_range:
		Utils.game.map.cheap_range.active = false
		return
	
	pernament_range_dirty=false
	if material.get_shader_parameter("build_mode"):
		material.set_shader_parameter("build_mode",false)
		material.set_shader_parameter("reveal_center",reveal_from)
		var reveal_diff=Time.get_ticks_msec()*0.001-last_reveal_time
		material.set_shader_parameter("reveal_time",Time.get_ticks_msec()*0.001+min(reveal_diff*0.3,0.5))#0.3 experimental but smooth

	
func _process(delta):
	if dirty:
		var shock_data_texture=Utils.create_emission_mask_from_points(shock_data)
		material.set_shader_parameter("shock_data",shock_data_texture)
		material.set_shader_parameter("shock_data_count",shock_data.size())
		dirty=false
	
	if range_dirty or pernament_range_dirty:
		if is_nan(Utils.game.camera.get_camera_screen_center().y):
			return
		var range_data: PackedVector2Array
		var screen_center: Vector2 = Utils.game.camera.get_camera_screen_center()
		var screen_zoom: float = Utils.game.camera.zoom.x
		
		for range_drawer in get_tree().get_nodes_in_group("range_draw"):
			if not range_drawer.visible or not range_drawer.has_meta("range_expander_radius"):
				continue
			
			var object_pos: Vector2 = range_drawer.global_position
			var object_radius: float = range_drawer.get_meta("range_expander_radius")
			if range_drawer.get_meta("custom_canvas", false):
				object_pos = get_viewport().canvas_transform.affine_inverse() * (object_pos)
			
			if object_pos.distance_to(screen_center) > Utils.game.screen_diagonal_radius_scaled + object_radius:
				continue
			
			range_data.append(object_pos)
			
			var radius_color = Vector2(object_radius, 0.0)
			if range_drawer.has_meta("range_expander_color"):
				radius_color.y = range_drawer.get_meta("range_expander_color")
			
			range_data.append(radius_color)
		
		var range_data_texture = Utils.create_emission_mask_from_points(range_data)
		material.set_shader_parameter("range_data",range_data_texture)
		material.set_shader_parameter("range_data_count",range_data.size())
		range_dirty=false
		
		
		


		
		
		
		
		
		
	var trans := get_canvas_transform()
	var camera_scale := trans.get_scale()
	var scale_inv = Vector2.ONE / camera_scale

	if Engine.is_editor_hint():
		self.scale=(get_viewport().size ) * scale_inv
	else:
		self.scale=(get_viewport().get_visible_rect().size ) * scale_inv

	global_position= -trans.origin * scale_inv

	material.set_shader_parameter("real_time", Time.get_ticks_msec()*0.001)
	material.set_shader_parameter("global_transform", get_global_transform())
	material.set_shader_parameter("camera_zoom", get_viewport_transform().get_scale())
