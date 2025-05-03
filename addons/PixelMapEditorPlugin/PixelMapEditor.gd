@tool
extends RefCounted

enum {EMPTY, RAW, EXPLOSION}

const IMPORT_OPTIONS = """[remap]
importer=\"image\"
type=\"Image\"
"""

var plugin: EditorPlugin
var dock: Control

var pixel_map: PixelMap

var reverse_scroll: bool
var drawing_enabled: bool

var draw_rotation: float
var draw_size: float = 64
var draw_shape: Texture2D
var draw_image: Image
var draw_circle: bool

var draw_material: int
var draw_restrict: int
var draw_skip_empty: int

var draw_damage_mode: int: set = set_draw_damage_mode
var draw_damage: float = 100
var draw_hardness: float = 1

var draw_custom: bool
var draw_custom_color: Color
var draw_custom_mode: int

var drawing: int
var line_start := Vector2(-1, -1)
var pixel_data_restore: PackedByteArray

var dirty_pixel_maps: Array
var save_pending: bool

func initialize() -> void:
	reverse_scroll = plugin.get_editor_interface().get_editor_settings().get("editors/2d/scroll_to_pan")
	dock.editor = self
	dock.connect("tab_changed", Callable(self, "update_tab"))

func set_pixel_map(px: PixelMap):
	pixel_map = px
	dock.set_pixel_map(pixel_map)

func process(delta: float):
	draw_on_map()

func _apply_changes():
	if save_pending or dirty_pixel_maps.is_empty():
		return
	
	save_pending = true
	call_deferred("_do_save")

func gui_input(event) -> bool:
	if not can_draw():
		return false
	
	var mouse_pos := pixel_map.get_local_mouse_position()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.command:
					if Rect2(Vector2(), pixel_map.get_texture().get_size()).has_point(mouse_pos):
						draw_material = pixel_map.get_pixel_at_safe(mouse_pos).g8
						draw_custom_color = pixel_map.get_pixel_at_safe(mouse_pos)
						dock.sync_picked_color()
				elif event.shift:
					line_start = mouse_pos
				else:
					pixel_data_restore = pixel_map.get_pixel_data()
					drawing = 1
					draw_on_map()
			else:
				if line_start != Vector2(-1, -1):
					pixel_data_restore = pixel_map.get_pixel_data()
					drawing = 1
					var destination := get_line_end_point()
					while not line_start.is_equal_approx(destination): 
						draw_on_map(line_start)
						line_start = line_start.move_toward(destination, 1)
					line_start = Vector2(-1, -1)
				drawing = 0
			
			return true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if event.shift:
					line_start = mouse_pos
				else:
					pixel_data_restore = pixel_map.get_pixel_data()
					drawing = -1
					draw_on_map()
			else:
				if line_start != Vector2(-1, -1):
					pixel_data_restore = pixel_map.get_pixel_data()
					drawing = -1
					var destination := get_line_end_point()
					while not line_start.is_equal_approx(destination): 
						draw_on_map(line_start)
						line_start = line_start.move_toward(destination, 1)
					line_start = Vector2(-1, -1)
				
				drawing = 0
			
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not event.pressed:
				return false
			var sgn := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			var used: bool
			
			if event.shift:
				draw_size += event.factor * 4 * sgn
				plugin.update_overlays()
				used = true
			elif event.command != reverse_scroll:
				draw_rotation = wrapi(draw_rotation + event.factor * 3 * sgn, 0, 360)
				plugin.update_overlays()
				used = true
			
			draw_on_map()
			return used
	
	if event is InputEventMouseMotion:
		plugin.update_overlays()
	
	if event is InputEventKey:
		if event.pressed and event.control:
			if event.keycode == KEY_Z and not pixel_data_restore.is_empty():
				var old_restore := pixel_map.get_pixel_data()
				pixel_map.set_pixel_data(pixel_data_restore, pixel_map.get_texture().get_size())
				pixel_data_restore = old_restore
				plugin.get_viewport().set_input_as_handled()
	
	return false

func draw(overlay: Control):
	if not can_draw():
		return
	
	var draw_scale := Vector2.ONE * draw_size * pixel_map.get_viewport().global_canvas_transform.get_scale().x
	overlay.draw_set_transform(overlay.get_local_mouse_position(), draw_rotation, Vector2.ONE)
	overlay.draw_texture_rect(draw_shape, Rect2(-draw_scale * 0.5, draw_scale), false, Color(0, 0, 1, 0.5))
	
	if line_start != Vector2(-1, -1):
		overlay.draw_set_transform(pixel_map.get_viewport().global_canvas_transform * line_start, draw_rotation, Vector2.ONE)
		overlay.draw_texture_rect(draw_shape, Rect2(-draw_scale * 0.5, draw_scale), false, Color(0, 0, 1, 0.5))
		overlay.draw_set_transform_matrix(Transform2D())
		overlay.draw_line(pixel_map.get_viewport().global_canvas_transform * line_start, pixel_map.get_viewport().global_canvas_transform * get_line_end_point(), Color.BLUE)
	
	overlay.draw_set_transform_matrix(Transform2D())

func draw_on_map(where := Vector2(-1, -1)):
	if not can_draw() or drawing == 0:
		return
	
	if not pixel_map in dirty_pixel_maps:
		dirty_pixel_maps.append(pixel_map)
	
	if where == Vector2(-1, -1):
		where = pixel_map.get_local_mouse_position()
	
	var draw_scale := draw_size / draw_image.get_size().x / pixel_map.scale.x
	var draw_mask := 0xFFFFFFFF
	if draw_restrict > 0:
		draw_mask = 1 << (draw_restrict - 1)
	
	if drawing == 1:
		if draw_custom:
			draw_scale = draw_size / pixel_map.scale.x / 2
			pixel_map.update_data_raw(where, draw_scale, draw_custom_color, draw_hardness, draw_custom_mode)
		else:
			pixel_map.update_material_mask_rotated(where, draw_image, draw_material, Vector3(draw_scale, draw_scale, draw_rotation), draw_mask, 0, draw_skip_empty)
	elif drawing == -1:
		match draw_damage_mode:
			EMPTY:
				pixel_map.update_material_mask_rotated(where, draw_image, -1, Vector3(draw_scale, draw_scale, draw_rotation))
			RAW:
				if draw_circle:
					pixel_map.update_damage_circle(where, draw_size / 2, draw_damage, draw_hardness)
				else:
					pixel_map.update_damage_mask(where, draw_image, draw_damage)
			EXPLOSION:
				pixel_map.update_damage_circle_penetrating_explosive(where, draw_size, draw_damage, 1.0 / draw_hardness)

func update_tab(tab: int):
	drawing_enabled = tab == dock.DRAW
	plugin.update_overlays()

func can_draw() -> bool:
	return drawing_enabled and pixel_map and dock.is_visible_in_tree()

func get_line_end_point() -> Vector2:
	var end_point := pixel_map.get_local_mouse_position()
	
	if Input.is_key_pressed(KEY_CTRL):
		var line_vector := end_point - line_start
		var angle := line_vector.angle()
		angle = deg_to_rad(round(rad_to_deg(angle) / 15) * 15)
		end_point = line_start + Vector2.RIGHT.rotated(angle) * line_vector.length()
	
	return end_point

func _do_save():
	if not save_pending:
		return
	save_pending = false
	
	for pixmap in dirty_pixel_maps:
		if not is_instance_valid(pixmap):
			continue
		
		if pixmap.texture_path:
			export_image(pixmap.texture_path, pixmap)
			plugin.get_editor_interface().get_resource_filesystem().scan()
			print(pixmap.name, ": texture saved")
		
		if not Constants.is_resource_built_in(pixmap.material_data):
			ResourceSaver.save(pixmap.material_data.resource_path, pixmap.material_data)
	
	dirty_pixel_maps.clear()

func export_image(image_name: String, pixmap := pixel_map):
	var image = Image.new()
	var texture_size = pixmap.get_texture().get_size()
	image.create_from_data(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8, pixmap.get_pixel_data())
	image.save_png(image_name)
	
	var file := FileAccess.open(image_name + ".import",FileAccess.READ)
	if not file.file_exists(image_name + ".import"):
		file.open(image_name + ".import", file.WRITE)
		file.store_string(IMPORT_OPTIONS)
	
	pixmap.texture_path = image_name

func set_draw_damage_mode(mode: int):
	draw_damage_mode = mode
	
	var slider := dock.get_node("%DamageValue") as Slider
	match mode:
		EMPTY:
			slider.editable = false
		RAW:
			slider.editable = true
			slider.max_value == 255
			slider.exp_edit == false
		EXPLOSION:
			slider.editable = true
			slider.max_value = 16384
			slider.exp_edit = true
