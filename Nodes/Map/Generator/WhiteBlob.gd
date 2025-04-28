@tool
extends Sprite2D

@export var material_type= Const.Materials.DIRT: set = set_material_type
@export var mask = ~(0): set = set_material_mask
@export var blue_channel: int = -1

@export var my_seed =0: set = set_seed
@export var use_same_seed =false 
@export var keep_scale =false 
@export var needs_duplicate_texture =false
@export var use_rect_as_size: bool


func set_material_mask(new_mask):
	mask=new_mask
	if material and material.is_class("ShaderMaterial"):
		material.set_shader_parameter("material_mask",new_mask)

func set_material_type(new_type):
	material_type=new_type
	if Const.MaterialColors.has(new_type):
		modulate=Const.MaterialColors[new_type]*10.0
		modulate.a=1.0
		var max_col_len=max(max(modulate.r,modulate.g),modulate.b)
		if max_col_len>1.0:
			modulate.r/=max_col_len
			modulate.g/=max_col_len
			modulate.b/=max_col_len


func set_seed(newseed):
	my_seed=newseed
	if material and material.is_class("ShaderMaterial"):
		material.set_shader_parameter("seed",my_seed)

func _ready():
	set_notify_transform(true)
	


func refresh_scale():
	if material and material.is_class("ShaderMaterial"):
		material.set_shader_parameter("scale",global_scale)
		material.set_shader_parameter("position",global_position)
func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		refresh_scale()
