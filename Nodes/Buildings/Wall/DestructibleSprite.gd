extends Sprite2D

const destroyable_material = preload("res://Nodes/Buildings/Wall/DestructibleSpriteMaterial.tres")

@onready var prev_pos := global_position
@onready var prev_rot := global_rotation
@onready var prev_scale := global_scale
@onready var mask: Image
@onready var mask2: Image
@onready var mask2node: Node2D

@onready var prev_mask_pos := global_position
@onready var prev_mask_rot := global_rotation
@onready var prev_mask_scale := global_scale

@export var mask_region: NodePath: set = setMaskRegion
@export var painting_material= Const.Materials.WALL: set = set_painting_material
@export var terrain_mask_scale= 1.0
@export var paint_force= false

var disabled: bool

func set_painting_material(new_mat):
	painting_material=new_mat
	if material:
		material.set_shader_parameter("masked_material_number", painting_material)

func setMaskRegion(new_mask):
	mask_region=new_mask
	
	if not is_inside_tree():
		await self.ready
	mask2node=get_node(mask_region)
	prev_mask_pos = mask2node.global_position
	prev_mask_rot = mask2node.global_rotation
	prev_mask_scale = mask2node.global_scale	
	mask2=Const.get_cached_image(mask2node.get_texture().resource_path)

func get_pixel_map():
	if not Engine.is_editor_hint():
		return Utils.game.map.pixel_map
	else:
		return get_tree().edited_scene_root.get_node_or_null("PixelMap")

func _ready() -> void:
	refresh_mask()
	use_parent_material = false
	if get_pixel_map():
		set_notify_transform(true)
		material = destroyable_material.duplicate()
		material.set_shader_parameter("map_tex", get_pixel_map().get_texture())
		material.set_shader_parameter("global_transform", global_transform)
		material.set_shader_parameter("masked_material_number", painting_material)
		z_index = max(z_index, 2)

func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		material.set_shader_parameter("global_transform", global_transform)
		clear()
		draw()

func refresh_mask():
	mask = Const.get_cached_image(texture.resource_path)

func destroy():
	set_notify_transform(false)
	clear()

func draw():
	if disabled:
		return
	
	var mas = 1 << Const.Materials.EMPTY
	var typ = painting_material
	
	if painting_material== Const.Materials.STOP:
		mas = -1
		typ=Const.Materials.STOP
#
#	if painting_material== Const.Materials.GATE:
#		mas = -1
#		typ=Const.Materials.GATE
#
	if painting_material== Const.Materials.LOW_BUILDING:
		mas = -1
		typ=Const.Materials.LOW_BUILDING
		
	if painting_material== Const.Materials.WALL or painting_material== Const.Materials.WALL1 or  painting_material== Const.Materials.WALL2 or  painting_material== Const.Materials.WALL3:
		mas = ~Utils.walkable_collision_mask
		
	if paint_force:
		mas = -1

	
	prev_pos = global_position
	prev_rot = global_rotation
	prev_scale = global_scale
	
	if mask_region.is_empty():
		
		#get_pixel_map().update_material_mask_rotated(sprite.global_position, image, Const.Materials.LUMEN, Vector3(sprite.global_scale.x * pixelmap_scale_mul, sprite.global_scale.y * pixelmap_scale_mul, sprite.global_rotation), 1 << Const.Materials.EMPTY, 255)
		get_pixel_map().update_material_mask_rotated(global_position, mask, typ, Vector3(global_scale.x*terrain_mask_scale, global_scale.y*terrain_mask_scale, global_rotation), mas) # 1<<26 to remove ald wall material if exists :#
	else:
		prev_mask_pos =mask2node.global_position
		prev_mask_rot=mask2node.global_rotation
		prev_mask_scale=mask2node.global_scale
		
		var mask1_data = TransformedImageData.new();
		mask1_data.image = mask
		mask1_data.scale = global_scale*terrain_mask_scale
		mask1_data.angle = global_rotation
		mask1_data.center_position = global_position

		var mask2_data = TransformedImageData.new();
		mask2_data.image = mask2
		mask2_data.scale = mask2node.global_scale*terrain_mask_scale
		mask2_data.angle = mask2node.global_rotation
		mask2_data.center_position = mask2node.global_position
		get_pixel_map().update_material_circle_with_rotated_masks(mask2node.global_position, 8000, mask1_data, mask2_data, typ, mas)
		
		
func clear():
	if disabled:
		return
	
	var mas= 1 << painting_material
	var typ= Const.Materials.EMPTY
	
	if painting_material== Const.Materials.STOP:
		mas = -1
		typ=-1
#
#	if painting_material== Const.Materials.GATE:
#		mas = -1
#		typ=Const.Materials.EMPTY
		
	if painting_material== Const.Materials.LOW_BUILDING:
		mas = -1
		typ=Const.Materials.EMPTY
		
	if paint_force:
		mas = -1

		
	if mask_region.is_empty():
		get_pixel_map().update_material_mask_rotated(prev_pos, mask, typ, Vector3(prev_scale.x*terrain_mask_scale, prev_scale.y*terrain_mask_scale, prev_rot), mas)
	else:
		var mask1_data = TransformedImageData.new();
		mask1_data.image = mask
		mask1_data.scale = prev_scale*terrain_mask_scale
		mask1_data.angle = prev_rot
		mask1_data.center_position = prev_pos

		var mask2_data = TransformedImageData.new();
		mask2_data.image = mask2
		mask2_data.scale = prev_mask_scale*terrain_mask_scale
		mask2_data.angle = prev_mask_rot
		mask2_data.center_position = prev_mask_pos
		get_pixel_map().update_material_circle_with_rotated_masks(mask2node.global_position, 8000, mask1_data, mask2_data, typ, mas)
