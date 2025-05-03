@tool
extends PanelContainer

enum {TEXTURE, DRAW, MATERIALS}

const MAX_EDITED_MATERIALS = 31#PixelMapMaterialData.MATERIAL_COUNT

var editable := true
var plugin: EditorPlugin
var editor: RefCounted

var pixel_map: PixelMap

signal tab_changed(tab)

func _ready() -> void:
	for button in $"%ShapeButtons".get_children():
		if not editor.draw_shape:
			set_drawing_shape(button)
		button.connect("pressed", Callable(self, "set_drawing_shape").bind(button))
	
	for button in $"%SizePresets".get_children():
		button.connect("pressed", Callable($"%DrawingSize", "set_value").bind(int(button.text)))
	
	toggle_custom_draw(false)

func set_pixel_map(px: PixelMap):
	if is_instance_valid(pixel_map):
		pixel_map.disconnect("texture_changed", Callable(self, "refresh_texture_preview"))
	
	var material_list: OptionButton = $"%MaterialList"
	var restrict_list: OptionButton = $"%RestrictList"
	
	material_list.clear()
	restrict_list.clear()
	restrict_list.add_item("None")
	
	pixel_map = px
	
	if not pixel_map:
		refresh_texture_preview(null)
		return
	
	refresh_texture_preview(pixel_map.get_texture())
	pixel_map.connect("texture_changed", Callable(self, "refresh_texture_preview"))
	
	for i in MAX_EDITED_MATERIALS:
		var mat := str(i, ":", pixel_map.material_data.get_material_name(i))
		material_list.add_item(mat)
		restrict_list.add_item(mat)

func refresh_texture_preview(new_texture: Texture2D):
	$"%PixelMapTexturePreview".texture = new_texture
	if new_texture:
		$"%PixelMapTextureSize".text = str(new_texture.get_size())

func create_new_texture() -> void:
	var size: float = $"%NewTextureSize".value
	var image := Image.new()
	image.create(size, size, false, Image.FORMAT_RGBA8)
	pixel_map.set_pixel_data(image.get_data(), image.get_size())

func set_current_tab(tab: int) -> void:
	emit_signal("tab_changed", tab)

func toggle_custom_draw(button_pressed: bool) -> void:
	$"%Regular".visible = not button_pressed
	$"%Custom".visible = button_pressed
	set_drawing_parameter(button_pressed, "draw_custom")

func set_drawing_parameter(value, parameter: String):
	editor.set(parameter, value)
	plugin.update_overlays()

func set_drawing_shape(shape_button: Button):
	if shape_button.icon:
		set_drawing_parameter(shape_button.icon, "draw_shape")
		set_drawing_parameter(shape_button.icon.get_data(), "draw_image")
		set_drawing_parameter(shape_button.get_index() == 0, "draw_circle")

func toggle_debug_flag(button_pressed: bool, extra_arg_0: int) -> void:
	if button_pressed:
		pixel_map.debug_flags |= (1 << extra_arg_0)
	else:
		pixel_map.debug_flags &= ~(1 << extra_arg_0)
	pixel_map.update()

func sync_picked_color():
	$"%MaterialList".selected = editor.draw_material
	$"%CustomColor".color = editor.draw_custom_color

#func texture_input(event: InputEvent) -> void:
#	if event is InputEventMouseButton and event.pressed or event is InputEventMouseMotion and Input.is_mouse_button_pressed(BUTTON_LEFT):
#		var map_pos: Vector2 = event.position * (pixel_map.get_texture().get_size() / find_node("InputRect").rect_size)
#		pixel_map.get_viewport().global_canvas_transform.origin = map_pos
