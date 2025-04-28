@tool
extends PixelMap

@export var custom_materials # (Array, Resource)
var bedrock_compat_override: Resource

@export var apply_in_editor: bool: set = editor_apply

var particle_manager: Node2D
var flesh_manager: Node2D
var smoke_manager: Node2D
var fire_manager: Node2D
var fog_of_war: FogOfWar 
var world_enviroment: WorldEnvironment
var dirty: bool = true

func _init() -> void:
	if Music.is_game_build():
		debug_flags = 0

	material = preload("res://Resources/Materials/PixelMapMaterial.tres").duplicate()
	if Music.is_switch_build():
		material.gdshader = preload("res://Resources/Materials/PixelMapShaderLow.gdshader")
	material.set_shader_parameter("terrain_texture_mix", get_default_terrain_texture())

func _ready() -> void:
	Utils.monster_path_mask = Utils.default_monster_path_mask
	
	if not Engine.is_editor_hint() and name == "PixelMap":
		if dirty:
			material_data = load("res://Resources/Materials/TerrainMaterials.tres").duplicate()
		var legacy_materials = ["Rock", "Steel", "Concrete", "Ice", "Sandstone", "Granite"]
		
		for i in Const.SwappableMaterials.size():
			if i > custom_materials.size():
				custom_materials.append(null)
			
			if not custom_materials[i]:
				custom_materials[i] = load("res://Resources/Terrain/TerrainTextures/%s.tres" % legacy_materials[i])
	
	setMaterialDefaultBlueChannel(Const.Materials.TAR, 255)
	apply_custom_materials()
	
	if Engine.is_editor_hint() or name != "PixelMap":
		return
	
	if get_tree().current_scene.get("is_editor"):
		return
	
	PathFinding.initialize(self)
	
	var tar_burn_params= FlammableMaterialParams.new()
	tar_burn_params.burning_dmg=123
	tar_burn_params.burning_result_material_type=Const.Materials.EMPTY
	tar_burn_params.burning_radius=3
	setMaterialFlammableData(Const.Materials.TAR, tar_burn_params)
	
	get_parent().initialize_pixel_map(self)
	
#	particle_manager = get_node_or_null("ParticleManager")
	if not particle_manager:
		particle_manager = Node2D.new()
		particle_manager.set_script(preload("res://Nodes/Map/ParticleManager.gd"))
		particle_manager.repel_create=true
		particle_manager.particle_scene = preload("res://Nodes/Map/SmartParticles.tscn")
		particle_manager.z_index = ZIndexer.Indexes.FLAKI
		particle_manager.z_as_relative = false
		add_child(particle_manager)
		
#	flesh_manager = get_node_or_null("ParticleManager")
	if not flesh_manager:
		flesh_manager = Node2D.new()
		flesh_manager.set_script(preload("res://Nodes/Effects/Flesh/FleshManager.gd"))
		flesh_manager.particle_scene = preload("res://Nodes/Effects/Flesh/SmartFlesh.tscn")
		flesh_manager.z_index = ZIndexer.Indexes.FLAKI
		flesh_manager.z_as_relative = false
		add_child(flesh_manager)
	
	if not smoke_manager:
		smoke_manager = Node2D.new()
		smoke_manager.set_script(preload("res://Nodes/Map/ParticleManagerSimple.gd"))
		smoke_manager.particle_scene = preload("res://Nodes/Effects/Smoke/SmartSmoke.tscn")
		smoke_manager.z_index = ZIndexer.Indexes.LIGHTS + 10
		smoke_manager.z_as_relative = false
		add_child(smoke_manager)
		
	if not fire_manager:
		fire_manager = Node2D.new()
		fire_manager.set_script(preload("res://Nodes/Map/ParticleManagerSimple.gd"))
		fire_manager.particle_scene = preload("res://Nodes/Effects/Smoke/SmartFire.tscn")
		fire_manager.z_index = ZIndexer.Indexes.BUILDING_HIGH + 11
		fire_manager.z_as_relative = false
		add_child(fire_manager)
	
	var pixel_map_floor = get_node_or_null("PixelMapFloor")
	if not pixel_map_floor:
		pixel_map_floor = preload("res://Nodes/Map/PixelMapFloor.tscn").instantiate()
		add_child(pixel_map_floor)
	
	if not has_node("%BloodSpawner"):
		var spawner = preload("res://Nodes/Objects/Deco/BloodSpawner.tscn").instantiate()
		add_child(spawner)
		spawner.owner = owner
		spawner.unique_name_in_owner = true
	
#	world_enviroment = get_node_or_null("WorldEnviroment")
#	if not world_enviroment:
#		world_enviroment = preload("res://Nodes/Map/WorldEnvironment.tscn").instance()
#		add_child(world_enviroment)
#
#	var fog_layer := CanvasLayer.new()
#	fog_layer.layer = 2
#	fog_layer.transform = get_canvas_transform()
#	add_child(fog_layer)
	
	rebuild_lava_data_texture()
	
	if Music.is_switch_build():
		return
	
	fog_of_war = get_node_or_null("FogOfWar")
	if not fog_of_war:
		fog_of_war = preload("res://Nodes/UI/FogOfWar/FogOfWar.tscn").instantiate()
		add_child(fog_of_war)

func _on_PixelMap_texture_changed(new_texture):
	var pixel_map_floor= get_node_or_null("PixelMapFloor/PixelMapFloorSprite")
	if pixel_map_floor:
		pixel_map_floor.texture=new_texture

func set_custom_material_list(list: Array):
	for i in Const.SwappableMaterials.size():
		custom_materials[i] = load(str("res://Resources/Terrain/TerrainTextures/", list[i], ".tres"))
	
	dirty = true
	apply_custom_materials()

var lava_data_dirty=false
func rebuild_lava_data_texture():
	lava_data_dirty=true
	call_deferred("force_now_rebuild_lava_data_texture_once")

class LavaIndexSorter:
	var point=Vector2.ZERO
	func sortme(a, b):
		if a.fluid_source_id < b.fluid_source_id:	
			return true
		return false

func force_now_rebuild_lava_data_texture_once():
	if !lava_data_dirty:
		return 
	lava_data_dirty=false
	var lava_data := PackedColorArray()
	var lava_nodes=get_tree().get_nodes_in_group("lava_source")

	lava_nodes.sort_custom(Callable(LavaIndexSorter.new(), "sortme"))
	lava_data.append(Color(0.0,0.0,0.0,0.0))
	if lava_nodes.size()>0:
		lava_data.resize(lava_nodes.back().fluid_source_id+2)
	for i in lava_nodes:
		if i.fluid_source_id>255:
			print("ojoj lava source ma id", i.fluid_source_id)
		elif i.fluid_source_id<0:
			print("ojoj lava source ma id", i.fluid_source_id)
		elif i.fluid_source_id<lava_data.size():
			lava_data[i.fluid_source_id+1]=Color(i.global_position.x,i.global_position.y,float(i.fluid_radius),0.0)
		else:
			print("cos kurwa nie tak z zrodlami lawy")
	var lava_data_texture = Utils.create_emission_mask_from_float_colors(lava_data)
#	var imp=lava_data_texture.get_data()
#	imp.lock()
#	print(imp.get_pixel(1,0))
#	imp.unlock()
	if material:

		material.set_shader_parameter("lava_data", lava_data_texture)
		material.set_shader_parameter("lava_data_count", lava_data.size())


#
#func _physics_process(delta):
#
#	rebuild_lava_data_texture()
#	force_now_rebuild_lava_data_texture_once()
#
func apply_custom_materials():
	for i in Const.SwappableMaterials.size():
		var mat: TerrainMaterial = custom_materials[i]
		if mat and mat.attackable_by_monsters:
			Utils.monster_path_mask |= (1 << Const.SwappableMaterials[i])
	
	if not dirty:
		return
	dirty = false
	
	var texture_array: ModifiableTextureArray = material.get_shader_parameter("terrain_texture_mix")
	for i in Const.SwappableMaterials.size():
		replace_material(texture_array, Const.SwappableMaterials[i], custom_materials[i])
	
	if bedrock_compat_override: # compat
		replace_material(texture_array, Const.Materials.ROCK, bedrock_compat_override)

func replace_material(texture_array: ModifiableTextureArray, idx: int, mat: Resource):
	if not mat:
		return
	
	if not Engine.is_editor_hint():
		material_data.set_material_durability(idx, mat.durability)
	
	var target_image: Image = mat.texture
	target_image.convert(texture_array.get_layer_data(idx).get_format())
	target_image.generate_mipmaps()
	texture_array.modify_texture(idx, target_image, self)

func editor_apply(b):
	if not b:
		return
	dirty = true
	material.set_shader_parameter("terrain_texture_mix", get_default_terrain_texture())
	apply_custom_materials()

func get_custom_material(mat: int) -> TerrainMaterial:
	var idx := Const.SwappableMaterials.find(mat)
	if idx == -1 or idx >= custom_materials.size():
		return null
	
	return custom_materials[idx]

func _get_save_data() -> Dictionary:
	var mats: Array
	
	for i in Const.SwappableMaterials.size():
		if custom_materials[i]:
			mats.append(custom_materials[i].resource_path)
		else:
			mats.append("")
	
	var data = {materials = mats}
	if bedrock_compat_override: #compat
		data.bedrock_compat = bedrock_compat_override.resource_path
	
	var smoke_big_fog_lol = get_node_or_null(@"Smoke")
	if smoke_big_fog_lol:
		data.smoke_big_for_color = smoke_big_fog_lol.modulate
		data.darkness_color = $MapDarkness.modulate
	
	return data

func _set_save_data(data: Dictionary):
#	for i in Const.SwappableMaterials.size():
	for i in min(Const.SwappableMaterials.size(), data.materials.size()): # compat
		if not data.materials[i].is_empty():
			custom_materials[i] = load(data.materials[i])
	
	if "bedrock_compat" in data: # compat
		bedrock_compat_override = load(data.bedrock_compat)
	
	if "smoke_big_for_color" in data:
		$Smoke.modulate = data.smoke_big_for_color
		$MapDarkness.modulate = data.darkness_color

func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		return
	
	if what == NOTIFICATION_PREDELETE:
		custom_materials.fill(null)

class ModifiableTextureArray extends Texture2DArray:
	var modified_by_pixelmap: PixelMap
	
	func modify_texture(idx: int, new_texture: Image, owner: PixelMap):
		set_layer_data(new_texture, idx)
		modified_by_pixelmap = owner

func get_default_terrain_texture():
	var cached_terrain_texture: ModifiableTextureArray
	if not Engine.is_editor_hint():
		cached_terrain_texture = Constants.static_texture_container[0]
	
	if not cached_terrain_texture or cached_terrain_texture.modified_by_pixelmap != self:
		cached_terrain_texture = ModifiableTextureArray.new()
		cached_terrain_texture.create(1024, 1024, 16, Image.FORMAT_RGBA8)
		
		for i in 16:
			if i in Const.DefaultMaterials:
				replace_material(cached_terrain_texture, i, Const.DefaultMaterials[i])
			else:
				var image: Image = Const.MaterialTextures.get(i, preload("res://Resources/Terrain/Images/WallUnused.png"))
				image.convert(Image.FORMAT_RGBA8)
				image.generate_mipmaps()
				cached_terrain_texture.set_layer_data(image, i)
		
		Constants.static_texture_container.clear()
		Constants.static_texture_container.append(cached_terrain_texture)
	
	return cached_terrain_texture
