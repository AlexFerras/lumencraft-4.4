@tool
extends PixelMap

@export var default_color: Color
@export var textures:Array[Resource] # (Array, Resource)
@export var layer: int = 1

@export var apply_in_editor: bool: set = editor_apply
@export var custom_material: bool

var dirty := true

func _init() -> void:
	if material:
		return
	
	if layer == 1:
		material = preload("res://Resources/Materials/FloorMaterial_4tex.tres").duplicate()
	elif layer == 2:
		material = preload("res://Resources/Materials/FloorMaterial2.tres").duplicate()
	else:
		push_error("Niepoprawna warstwa. Musi być 1 albo 2")

func _ready() -> void:
	if Music.is_switch_build():
		if layer == 1:
			var sprite := TextureRect.new()
			sprite.texture = load("res://Resources/Textures/FloorSprite.png")
			sprite.expand = true
			sprite.stretch_mode = TextureRect.STRETCH_TILE
			sprite.scale = Vector2.ONE * 0.125
			sprite.size = Vector2(8192, 8192) / sprite.scale
			sprite.add_to_group("dont_save")
			RenderingServer.canvas_item_set_z_index(sprite.get_canvas_item(), z_index)
			get_parent().call_deferred("add_child", sprite)
		hide()
		return
	
	textures.resize(4)
	fake_pixel_map = true
	
	if texture_path.is_empty():
		create_texture(1024, 1024, default_color)
	
	if not Engine.is_editor_hint() and not custom_material:
		apply_textures()
	
	if name == "Floor2":
		material.set_shader_parameter("hsvoffset4", Save.config.blood_color.h)

func set_texture_list(list: Array):
	for i in 4:
		if layer == 2 and list[i].is_empty():
			textures[i] = load(str("res://Resources/Terrain/FloorTextures/2Empty.tres"))
		else:
			textures[i] = load(str("res://Resources/Terrain/FloorTextures/", layer, list[i], ".tres"))
	
	dirty = true
	apply_textures()

func editor_apply(b):
	dirty = true
	material = material.duplicate()
	apply_textures()

func apply_textures():
	if not dirty:
		return
	dirty = false
	
	for i in 4:
		if textures[i]:
			var idx: int = i + 1
			material.set_shader_parameter("texture%d" % idx, textures[i].texture)
			material.set_shader_parameter("resolution%d" % idx, textures[i].resolution)
			material.set_shader_parameter("multiply%d" % idx, textures[i].multiply)
			material.set_shader_parameter("wavy%d" % idx, textures[i].wavy)
			material.set_shader_parameter("hsvoffset%d" % idx, textures[i].hsv[0])
			material.set_shader_parameter("hsvsaturation%d" % idx, textures[i].hsv[1])
			material.set_shader_parameter("hsvlight%d" % idx, textures[i].hsv[2])

func _get_save_data() -> Dictionary:
	if custom_material:
		return {custom_material = material}
	
	var mats: Array
	
	for i in 4:
		if textures[i]:
			mats.append(textures[i].resource_path)
		else:
			mats.append("")
	
	return {textures = mats}

func _set_save_data(data: Dictionary):
	if "custom_material" in data:
		custom_material = true
		material = data.custom_material
	else:
		for i in 4:
			if not data.textures[i].is_empty():
				textures[i] = load(data.textures[i])

func hard_reload():
	for i in textures.size():
		var mat = textures[i]
		if mat:
			mat = ResourceLoader.load(mat.resource_path, "", 1)
		
		textures[i] = mat
	
	dirty = true
	apply_textures()
