extends Node2D

const destroyable_material = preload("res://Nodes/Objects/LumenCrystal/LumenCrystal.tres")

@export var pixelmap_scale_mul = 1.0
@export var __done = false

@onready var ray_group := $RayGroup

var prev_pos: Vector2
var prev_rot: float
var prev_scale: Vector2

var next_check = 10.0
var moving: bool

func get_pixel_map():
	if Engine.is_editor_hint():
		return get_tree().edited_scene_root.get_node("PixelMap")
	else:
		return Utils.game.map.pixel_map

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		remove_pixels()

func _ready() -> void:
	var sprite := $Sprite2D as Sprite2D
	sprite.material = destroyable_material.duplicate()
	sprite.material.set_shader_parameter("map_tex", get_pixel_map().get_texture())
	sprite.material.set_shader_parameter("global_transform", sprite.get_global_transform())
	
	set_process_input(false)
	
	prev_pos = sprite.global_position
	prev_rot = sprite.global_rotation
	prev_scale = sprite.global_scale
	
	if Engine.is_editor_hint():
		set_notify_transform(true)
	elif not __done:
		__done = true
		draw_pixels()

func _process(delta):
	if not Engine.is_editor_hint():
		next_check -= delta
		if next_check <= 0.0:
			next_check = randf_range(4.0, 8.0)

			if prev_scale and not ray_group.is_any_ray_solid():
				get_pixel_map().update_material_mask_rotated(prev_pos, Const.get_cached_image($Sprite2D.texture.resource_path), Const.Materials.EMPTY, Vector3(prev_scale.x, prev_scale.y, prev_rot), 1 << Const.Materials.LUMEN)
				var seq := create_tween()
				seq.tween_property(self, "modulate:a", 0.0, 2.0)
				seq.tween_callback(Callable(self, "queue_free"))
	else:
		if is_inside_tree():
			$Sprite2D.material.set_shader_parameter("global_transform", $Sprite2D.get_global_transform())
		
		if moving and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			moving = false
			set_process_input(false)
			draw_pixels()
			get_tree().edited_scene_root.set_meta("save_map_png", true)

func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and is_inside_tree() and prev_scale:
		if not moving and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			moving = true
			set_process_input(true)
			remove_pixels()
			get_tree().edited_scene_root.set_meta("save_map_png", true)
		
		prev_pos = $Sprite2D.global_position
		prev_rot = $Sprite2D.global_rotation
		prev_scale = $Sprite2D.global_scale
	
	if what == NOTIFICATION_POST_ENTER_TREE:
		if Engine.is_editor_hint():
			draw_pixels()

func remove_pixels():
	if not can_draw():
		return
	
	var image: Image = Const.get_cached_image($Sprite2D.texture.resource_path)
	
	get_pixel_map().update_material_mask_rotated(prev_pos, image, Const.Materials.EMPTY, Vector3(prev_scale.x * pixelmap_scale_mul, prev_scale.y * pixelmap_scale_mul, prev_rot), 1 << Const.Materials.LUMEN)

func draw_pixels():
	if not can_draw():
		return
	
	var sprite: Sprite2D = $Sprite2D
	var image: Image = Const.get_cached_image(sprite.texture.resource_path)
	
	get_pixel_map().update_material_mask_rotated(sprite.global_position, image, Const.Materials.LUMEN, Vector3(sprite.global_scale.x * pixelmap_scale_mul, sprite.global_scale.y * pixelmap_scale_mul, sprite.global_rotation), 1 << Const.Materials.EMPTY, 255)

func can_draw() -> bool:
	if not is_inside_tree():
		return false
	
	if not prev_scale:
		return false
	
	if not $Sprite2D.texture:
		return false
	
	if not Const.get_cached_image($Sprite2D.texture.resource_path): # W ogóle możliwe??
		return false
	
	return true
